// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IUniswapV2ERC20} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2ERC20.sol";

import {IToken} from "./interfaces/IToken.sol";
import {IGNad} from "./interfaces/IGNad.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import "./errors/CustomErrors.sol" as CustomErrors;

/**
 * @title BondingCurve
 * @dev Implementation of a bonding curve for token price discovery
 * Manages the relationship between Native and project tokens using a constant product formula
 */
contract BondingCurve is IBondingCurve {
    using SafeERC20 for IERC20;

    // Immutable state variables
    address immutable FACTORY;
    address immutable GNAD;
    address public immutable WMON; // Wrapped Mon token address
    address public token; // Project token address
    address public pair;
    // Virtual reserves for price calculation
    uint256 private virtualNative; // Virtual Native reserve
    uint256 private virtualToken; // Virtual token reserve
    uint256 private k; // Constant product parameter
    uint256 private lockedToken; // Locked token amount for listing

    /**
     * @dev Fee configuration structure
     * @param denominator Fee percentage denominator
     * @param numerator Fee percentage numerator
     */
    struct Fee {
        uint8 denominator;
        uint16 numerator;
    }

    Fee feeConfig;

    // Real reserves tracking actual balances
    uint256 realNativeReserves;
    uint256 realTokenReserves;

    // State flags
    bool public lock; // Locks trading when target is reached
    bool public isListing; // Indicates if token is listed on DEX

    /**
     * @dev Ensures the contract is not locked
     */
    modifier islock() {
        require(!lock, CustomErrors.INVALID_IT_IS_LOCKED);
        _;
    }

    /**
     * @dev Restricts function access to GNAD contract only
     */
    modifier onlyGNad() {
        require(msg.sender == GNAD, CustomErrors.INVALID_GNAD_ADDRESS);
        _;
    }

    /**
     * @dev Constructor sets immutable FACTORY and core addresses
     * @param _gNad Address of the GNAD contract
     * @param _wMon Address of the wMon token
     */
    constructor(address _gNad, address _wMon) {
        FACTORY = msg.sender;
        GNAD = _gNad;
        WMON = _wMon;
    }

    /**
     * @notice Initializes the bonding curve with its parameters
     * @dev Called once by FACTORY during deployment
     * @param _token Project token address
     * @param _virtualNative Initial virtual Native reserve
     * @param _virtualToken Initial virtual token reserve
     * @param _k Constant product parameter
     * @param _lockedToken Locked token amount for DEX listing
     * @param _feeDenominator Fee denominator
     * @param _feeNumerator Fee numerator
     */
    function initialize(
        address _token,
        uint256 _virtualNative,
        uint256 _virtualToken,
        uint256 _k,
        uint256 _lockedToken,
        uint8 _feeDenominator,
        uint16 _feeNumerator
    ) external {
        require(msg.sender == FACTORY, CustomErrors.INVALID_FACTORY_ADDRESS);
        token = _token;
        virtualNative = _virtualNative;
        virtualToken = _virtualToken;

        k = _k;
        realNativeReserves = IERC20(WMON).balanceOf(address(this));
        realTokenReserves = IERC20(_token).balanceOf(address(this));
        lockedToken = _lockedToken;
        feeConfig = Fee({denominator: _feeDenominator, numerator: _feeNumerator});
        isListing = false;
    }

    /**
     * @notice Executes a buy order on the bonding curve
     * @dev Transfers tokens and updates reserves accordingly
     * @param to Recipient address
     * @param amountOut Amount of tokens to buy
     */
    function buy(address to, uint256 amountOut) external islock onlyGNad {
        require(amountOut > 0, CustomErrors.INVALID_AMOUNT_OUT);
        address _wMon = WMON; //gas savings
        address _token = token; //gas savings

        (uint256 _realNativeReserves, uint256 _realTokenReserves) = getReserves();

        // Ensure remaining tokens stay above target
        require(_realTokenReserves - amountOut >= lockedToken, CustomErrors.INVALID_LOCKED_AMOUNT);

        uint256 balanceWNative;

        {
            require(to != _wMon && to != _token, CustomErrors.INVALID_RECIPIENT);
            IERC20(_token).safeTransfer(GNAD, amountOut);

            balanceWNative = IERC20(_wMon).balanceOf(address(this));
        }

        uint256 amountNativeIn = balanceWNative - _realNativeReserves;
        _update(amountNativeIn, amountOut, true);
        require(virtualNative * virtualToken >= k, CustomErrors.INVALID_K);
        emit Buy(to, token, amountNativeIn, amountOut);
        _checkTarget();
    }

    /**
     * @notice Executes a sell order on the bonding curve
     * @dev Transfers tokens and updates reserves accordingly
     * @param to Recipient address
     * @param amountOut Amount of native to receive
     */
    function sell(address to, uint256 amountOut) external islock onlyGNad {
        require(amountOut > 0, CustomErrors.INVALID_AMOUNT_OUT);

        address _wMon = WMON;
        address _token = token;
        (uint256 _realNativeReserves, uint256 _realTokenReserves) = getReserves();
        require(amountOut <= _realNativeReserves, CustomErrors.INVALID_AMOUNT_OUT);

        uint256 balanceToken;

        {
            require(to != _wMon && to != _token, CustomErrors.INVALID_RECIPIENT);
            IERC20(_wMon).safeTransfer(GNAD, amountOut);
            balanceToken = IERC20(_token).balanceOf(address(this));
        }

        uint256 amountTokenIn = balanceToken - _realTokenReserves;

        require(amountTokenIn > 0, CustomErrors.INVALID_AMOUNT_IN);
        _update(amountTokenIn, amountOut, false);
        require(virtualNative * virtualToken >= k, CustomErrors.INVALID_K);
        emit Sell(to, token, amountTokenIn, amountOut);
        _checkTarget();
    }

    /**
     * @notice Lists the token on Uniswap after reaching target
     * @dev Creates trading pair and provides initial liquidity
     */
    function listing() external returns (address) {
        require(lock == true, CustomErrors.INVALID_IT_IS_UNLOCKED);
        require(!isListing, CustomErrors.INVALID_ALREADY_LISTED);
        IBondingCurveFactory _factory = IBondingCurveFactory(FACTORY);
        pair = IUniswapV2Factory(_factory.getDexFactory()).createPair(WMON, token);
        uint256 listingFee = _factory.getListingFee();

        // A token equivalent to the native token consumed as a listing fee is burned.
        // Transfer remaining tokens to the pair
        uint256 burnTokenAmount;
        {
            burnTokenAmount = realTokenReserves - ((realNativeReserves - listingFee) * virtualToken) / virtualNative;
            IToken(token).burn(burnTokenAmount);
            IERC20(WMON).safeTransfer(IGNad(_factory.getGNad()).getFeeVault(), listingFee);
        }

        uint256 listingNativeAmount = IERC20(WMON).balanceOf(address(this));
        uint256 listingTokenAmount = IERC20(token).balanceOf(address(this));
        IERC20(WMON).transfer(pair, listingNativeAmount);
        IERC20(token).transfer(pair, listingTokenAmount);

        // Reset reserves and provide liquidity
        realNativeReserves = 0;
        realTokenReserves = 0;
        uint256 liquidity = IUniswapV2Pair(pair).mint(address(this));

        IUniswapV2ERC20(pair).transfer(address(0), liquidity);
        isListing = true;
        emit Listing(address(this), token, pair, listingNativeAmount, listingTokenAmount, liquidity);
        return pair;
    }

    // Private functions
    /**
     * @dev Updates virtual and real reserves after trades
     * @param amountIn Amount of tokens coming in
     * @param amountOut Amount of tokens going out
     * @param isBuy Whether this update is for a buy order
     */
    function _update(uint256 amountIn, uint256 amountOut, bool isBuy) private {
        realNativeReserves = IERC20(WMON).balanceOf(address(this));
        realTokenReserves = IERC20(token).balanceOf(address(this));

        if (isBuy) {
            virtualNative += amountIn;
            virtualToken -= amountOut;
        } else {
            virtualNative -= amountOut;
            virtualToken += amountIn;
        }

        emit Sync(token, realNativeReserves, realTokenReserves, virtualNative, virtualToken);
    }

    function _checkTarget() private {
        // Lock trading if locked amount is reached
        if (realTokenReserves == getLockedToken()) {
            lock = true;
            emit Lock(token);
        }
    }

    // View functions
    /**
     * @notice Gets the current real token reserves
     * @return nativeReserves The current real Native reserves
     * @return tokenReserves The current real token reserves
     */
    function getReserves() public view override returns (uint256 nativeReserves, uint256 tokenReserves) {
        return (realNativeReserves, realTokenReserves);
    }

    /**
     * @notice Gets the current virtual reserves
     * @return virtualNativeReserve The current virtual Native reserves
     * @return virtualTokenReserve The current virtual token reserves
     */
    function getVirtualReserves()
        public
        view
        override
        returns (uint256 virtualNativeReserve, uint256 virtualTokenReserve)
    {
        return (virtualNative, virtualToken);
    }

    /**
     * @notice Gets the current fee configuration
     * @return denominator The fee denominator
     * @return numerator The fee numerator
     */
    function getFeeConfig() external view returns (uint8 denominator, uint16 numerator) {
        return (feeConfig.denominator, feeConfig.numerator);
    }

    /**
     * @notice Gets the constant product parameter
     */
    function getK() external view override returns (uint256) {
        return k;
    }

    /**
     * @notice Gets the locked token amount for listing
     */
    function getLockedToken() public view returns (uint256) {
        return lockedToken;
    }

    /**
     * @notice Checks if trading is locked
     */
    function getLock() public view returns (bool) {
        return lock;
    }

    /**
     * @notice Checks if token is listed on DEX
     */
    function getIsListing() public view returns (bool) {
        return isListing;
    }
}
