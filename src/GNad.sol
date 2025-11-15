// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {IFeeVault} from "./interfaces/IFeeVault.sol";
import {IWMon} from "./interfaces/IWMon.sol";
import {IGNad} from "./interfaces/IGNad.sol";
import {BCLib} from "./lib/BCLib.sol";
import {TransferLib} from "./lib/Transfer.sol";
import "./errors/CustomErrors.sol" as CustomErrors;

/**
 * @title Gnad
 * @notice Main contract for managing bonding curve operations and Native token interactions
 * @dev Handles creation of bonding curves, buying and selling operations with various payment methods
 */
contract GNad is IGNad {
    using SafeERC20 for IERC20;
    /// @notice Address of the bonding curve factory contract

    address public bcFactory;
    /// @notice Address of the wrapped Native token
    address public immutable WMON;
    /// @notice ERC4626 vault contract for fee collection
    IFeeVault public immutable VAULT;
    bool isInitialized = false;

    /**
     * @notice Constructor initializes core contract with essential addresses
     *
     * @param _wMon Address of the Wrapped Mon token
     * @param _vault Address of the fee collection vault
     */
    constructor(address _wMon, address _vault) {
        WMON = _wMon;
        VAULT = IFeeVault(_vault);
    }

    /**
     * @notice Fallback function to receive Native token
     * @dev Only accepts Native token from the WMON contract
     */
    receive() external payable {
        assert(msg.sender == WMON); // only accept WMON via fallback from the WMON contract
    }

    /**
     * @notice Ensures function is called before deadline
     * @param deadline Timestamp before which the function must be called
     */
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, CustomErrors.TIME_EXPIRED);
        _;
    }

    function initialize(address _bcFactory) external {
        require(!isInitialized, CustomErrors.ALREADY_INITIALIZED);
        bcFactory = _bcFactory;
        isInitialized = true;
    }

    /**
     * @notice Validates if the fee amount is correct according to curve parameters
     * @param curve Address of the bonding curve
     * @param amount Base amount for fee calculation
     * @param fee Fee amount to validate
     */
    function checkFee(address curve, uint256 amount, uint256 fee) internal view {
        (uint8 denominator, uint16 numerator) = IBondingCurve(curve).getFeeConfig();
        require(fee >= (amount * denominator) / numerator, CustomErrors.INVALID_FEE);
    }

    /**
     * @notice Sends fee to the vault
     * @param fee Amount of fee to send
     */
    function sendFeeByVault(uint256 fee) internal {
        IERC20(WMON).safeTransfer(address(VAULT), fee);
    }

    /**
     * @notice Creates a new bonding curve with initial liquidity
     * @param creator Address of the bc creator
     * @param name Name of the token
     * @param symbol Symbol of the token
     * @param tokenURI URI for token metadata
     * @param amountIn Initial Native amount
     * @param fee Fee amount for the creation
     * @return bc Address of the created bonding curve
     * @return token Address of the created token
     * @return virtualNative Initial virtual Native reserve
     * @return virtualToken Initial virtual token reserve
     * @return amountOut Amount of tokens received
     */
    function createBc(
        address creator,
        string memory name,
        string memory symbol,
        string memory tokenURI,
        uint256 amountIn,
        uint256 fee
    )
        external
        payable
        returns (address bc, address token, uint256 virtualNative, uint256 virtualToken, uint256 amountOut)
    {
        uint256 _deployFee = IBondingCurveFactory(bcFactory).getDelpyFee();
        require(msg.value >= amountIn + fee + _deployFee, CustomErrors.INVALID_MON_AMOUNT);

        (bc, token, virtualNative, virtualToken) =
            IBondingCurveFactory(bcFactory).create(creator, name, symbol, tokenURI);

        IWMon(WMON).deposit{value: amountIn + fee + _deployFee}();

        if (amountIn > 0) {
            checkFee(bc, amountIn, fee);
            sendFeeByVault(fee + _deployFee);
            uint256 k = virtualNative * virtualToken;
            amountOut = getAmountOut(amountIn, k, virtualNative, virtualToken);
            IERC20(WMON).safeTransfer(bc, amountIn);
            IBondingCurve(bc).buy(creator, amountOut);
            IERC20(token).safeTransfer(creator, amountOut);
            return (bc, token, virtualNative + amountIn, virtualToken - amountOut, amountOut);
        }
        sendFeeByVault(_deployFee);
        emit GNadCreate();
        return (bc, token, virtualNative, virtualToken, amountOut);
    }

    //----------------------------Buy Functions ---------------------------------------------------
    /**
     * @notice Buys tokens from a bonding curve
     * @param amountIn Native amount to spend
     * @param fee Fee amount for the transaction
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function buy(uint256 amountIn, uint256 fee, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        require(msg.value >= amountIn + fee, CustomErrors.INVALID_MON_AMOUNT);
        require(amountIn > 0, CustomErrors.INVALID_AMOUNT_IN);
        require(fee > 0, CustomErrors.INVALID_FEE);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);
        checkFee(bc, amountIn, fee);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualNative, virtualToken);
        {
            IWMon(WMON).deposit{value: amountIn + fee}();

            sendFeeByVault(fee);

            IERC20(WMON).safeTransfer(bc, amountIn);

            IBondingCurve(bc).buy(to, amountOut);

            IERC20(token).safeTransfer(to, amountOut);
        }
        emit GNadBuy();
    }

    /**
     * @notice Buys tokens with slippage protection
     * @param amountIn Native amount to spend
     * @param amountOutMin Minimum amount of tokens to receive
     * @param fee Fee amount for the transaction
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function protectBuy(
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 fee,
        address token,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(msg.value >= amountIn + fee, CustomErrors.INVALID_MON_AMOUNT);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);
        checkFee(bc, amountIn, fee);

        uint256 amountOut = getAmountOut(amountIn, k, virtualNative, virtualToken);

        require(amountOut >= amountOutMin, CustomErrors.INVALID_AMOUNT_OUT);
        {
            IWMon(WMON).deposit{value: amountIn + fee}();

            sendFeeByVault(fee);
            IERC20(WMON).safeTransfer(bc, amountIn);

            IBondingCurve(bc).buy(to, amountOut);
            IERC20(token).safeTransfer(to, amountOut);
        }
        emit GNadBuy();
    }

    /**
     * @notice Buys an exact amount of tokens from a bonding curve
     * @param amountOut Amount of tokens to buy
     * @param amountInMax Maximum Native amount to spend
     * @param token Address of the token to buy
     * @param to Address to receive the bought tokens
     * @param deadline Timestamp before which the transaction must be executed
     */
    function exactOutBuy(uint256 amountInMax, uint256 amountOut, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        require(msg.value >= amountInMax, CustomErrors.INVALID_AMOUNT_OUT);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);
        uint256 amountIn = getAmountIn(amountOut, k, virtualNative, virtualToken);

        (uint8 denominator, uint16 numerator) = IBondingCurve(bc).getFeeConfig();

        uint256 fee = BCLib.getFeeAmount(amountIn, denominator, numerator);

        require(amountIn + fee <= amountInMax, CustomErrors.INVALID_AMOUNT_IN_MAX);
        {
            IWMon(WMON).deposit{value: amountIn + fee}();
            sendFeeByVault(fee);
            IERC20(WMON).safeTransfer(bc, amountIn);
            IBondingCurve(bc).buy(to, amountOut);
            IERC20(token).safeTransfer(to, amountOut);
            uint256 restValue = amountInMax - (amountIn + fee);
            if (restValue > 0) {
                TransferLib.safeTransferNative(msg.sender, restValue);
            }
        }
        emit GNadBuy();
    }

    // //-------------Sell Functions ---------------------------------------------

    /**
     * @notice Market sells tokens at the current bonding curve price. Market orders are executed immediately at the best current price,
     *         without any slippage protection. Use with caution as the execution price may vary from the displayed price.
     * @param amountIn Token amount to market sell
     * @param token Address of the token to sell
     * @param to Address to receive the Native
     * @param deadline Timestamp before which the transaction must be executed
     */
    function sell(uint256 amountIn, address token, address to, uint256 deadline) external ensure(deadline) {
        require(amountIn > 0, CustomErrors.INVALID_AMOUNT_IN);

        require(IERC20(token).allowance(msg.sender, address(this)) >= amountIn, CustomErrors.INVALID_ALLOWANCE);
        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNative);

        (uint8 denominator, uint16 numerator) = IBondingCurve(bc).getFeeConfig();

        uint256 fee = BCLib.getFeeAmount(amountOut, denominator, numerator);
        {
            IERC20(token).safeTransferFrom(msg.sender, bc, amountIn);
            IBondingCurve(bc).sell(to, amountOut);
            sendFeeByVault(fee);
            IWMon(WMON).withdraw(amountOut - fee);

            TransferLib.safeTransferNative(to, amountOut - fee);
        }
    }

    /**
     * @notice Market sells tokens at the current bonding curve price. with permit
     * @param amountIn Token amount to sell
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function sellPermit(
        uint256 amountIn,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(token).permit(from, address(this), amountIn, deadline, v, r, s);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNative);

        (uint8 denominator, uint16 numerator) = IBondingCurve(bc).getFeeConfig();

        uint256 fee = BCLib.getFeeAmount(amountOut, denominator, numerator);
        {
            IERC20(token).safeTransferFrom(from, bc, amountIn);
            IBondingCurve(bc).sell(to, amountOut);
            sendFeeByVault(fee);
            IWMon(WMON).withdraw(amountOut - fee);
            TransferLib.safeTransferNative(to, amountOut - fee);
        }
        emit GNadSell();
    }

    /**
     * @notice Sells tokens with slippage protection
     * @param amountIn Token amount to sell
     * @param amountOutMin Minimum amount of Native to receive (slippage protection)
     * @param token Address of the token to sell
     * @param to Address to receive the Native
     * @param deadline Timestamp before which the transaction must be executed
     */
    function protectSell(uint256 amountIn, uint256 amountOutMin, address token, address to, uint256 deadline)
        external
        ensure(deadline)
    {
        require(amountIn > 0, CustomErrors.INVALID_AMOUNT_IN);
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        require(allowance >= amountIn, CustomErrors.INVALID_ALLOWANCE);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);

        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNative);

        (uint8 denominator, uint16 numerator) = IBondingCurve(bc).getFeeConfig();
        uint256 fee = BCLib.getFeeAmount(amountOut, denominator, numerator);

        require(amountOut - fee >= amountOutMin, CustomErrors.INVALID_AMOUNT_OUT);
        {
            IERC20(token).safeTransferFrom(msg.sender, bc, amountIn);
            IBondingCurve(bc).sell(to, amountOut);
            sendFeeByVault(fee);
            IWMon(WMON).withdraw(amountOut - fee);
            TransferLib.safeTransferNative(to, amountOut - fee);
        }
        emit GNadSell();
    }

    /**
     * @notice Sells tokens with slippage protection with permit
     * @param amountIn Token amount to sell
     * @param amountOutMin Minimum amount of Native to receive
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function protectSellPermit(
        uint256 amountIn,
        uint256 amountOutMin,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external ensure(deadline) {
        // EIP-2612 permit: approve by signature
        require(amountIn > 0, CustomErrors.INVALID_AMOUNT_IN);
        IERC20Permit(token).permit(from, address(this), amountIn, deadline, v, r, s);
        // Safe transfer the token from user to this contract

        // Get bc and reserves
        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);

        // Calculate and verify amountOut
        uint256 amountOut = getAmountOut(amountIn, k, virtualToken, virtualNative);
        (uint8 denominator, uint16 numerator) = IBondingCurve(bc).getFeeConfig();
        uint256 fee = BCLib.getFeeAmount(amountOut, denominator, numerator);

        require(amountOut - fee >= amountOutMin, CustomErrors.INVALID_AMOUNT_OUT);
        {
            IERC20(token).safeTransferFrom(from, bc, amountIn);
            IBondingCurve(bc).sell(to, amountOut);
            sendFeeByVault(fee);
            IWMon(WMON).withdraw(amountOut - fee);
            TransferLib.safeTransferNative(to, amountOut - fee);
        }
        emit GNadSell();
    }

    /**
     * @notice Sells tokens for an exact amount of Native on the bonding curve
     * @param amountOut Exact amount of ETH to receive
     * @param amountInMax Maximum token amount willing to sell
     * @param token Address of the token to sell
     * @param to Address to receive the ETH
     * @param deadline Timestamp before which the transaction must be executed
     */
    function exactOutSell(uint256 amountInMax, uint256 amountOut, address token, address to, uint256 deadline)
        external
        payable
        ensure(deadline)
    {
        require(amountInMax > 0, CustomErrors.INVALID_AMOUNT_IN);

        require(IERC20(token).allowance(msg.sender, address(this)) >= amountInMax, CustomErrors.INVALID_ALLOWANCE);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);

        uint256 fee = msg.value;
        checkFee(bc, amountOut, fee);

        uint256 amountIn = getAmountIn(amountOut, k, virtualToken, virtualNative);

        require(amountIn <= amountInMax, CustomErrors.INVALID_AMOUNT_IN_MAX);
        {
            IWMon(WMON).deposit{value: fee}();
            sendFeeByVault(fee);
            IERC20(token).safeTransferFrom(msg.sender, bc, amountIn);
            IBondingCurve(bc).sell(to, amountOut);
            IWMon(WMON).withdraw(amountOut);
            TransferLib.safeTransferNative(to, amountOut);
        }
        emit GNadSell();
    }

    /**
     * @notice Sells tokens for an exact amount of Native on the bonding curve with permit
     * @param amountOut Amount of Native to receive
     * @param amountInMax Maximum token amount to sell
     * @param token Address of the token to sell
     * @param from Address of the token owner
     * @param to Address to receive the sold tokens
     * @param deadline Timestamp before which the transaction must be executed
     * @param v v parameter of the permit signature
     * @param r r parameter of the permit signature
     * @param s s parameter of the permit signature
     */
    function exactOutSellPermit(
        uint256 amountInMax,
        uint256 amountOut,
        address token,
        address from,
        address to,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable ensure(deadline) {
        require(amountInMax > 0, CustomErrors.INVALID_AMOUNT_IN_MAX);
        IERC20Permit(token).permit(from, address(this), amountInMax, deadline, v, r, s);

        (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k) = getBcData(bcFactory, token);

        uint256 fee = msg.value;
        checkFee(bc, amountOut, fee);

        uint256 amountIn = getAmountIn(amountOut, k, virtualToken, virtualNative);
        require(amountIn <= amountInMax, CustomErrors.INVALID_AMOUNT_IN_MAX);
        {
            IWMon(WMON).deposit{value: fee}();
            sendFeeByVault(fee);
            IERC20(token).safeTransferFrom(msg.sender, bc, 1);
            IBondingCurve(bc).sell(to, amountOut);
            IWMon(WMON).withdraw(amountOut);
            TransferLib.safeTransferNative(to, amountOut);
        }
        emit GNadSell();
    }

    //----------------------------Common Functions ---------------------------------------------------

    /**
     * @notice Gets bc data from the factory
     * @param _factory Factory contract address
     * @param token Token address
     * @return bc Bonding curve address
     * @return virtualNative Virtual Native reserve
     * @return virtualToken Virtual token reserve
     * @return k Constant product value
     */
    function getBcData(address _factory, address token)
        public
        view
        returns (address bc, uint256 virtualNative, uint256 virtualToken, uint256 k)
    {
        (bc, virtualNative, virtualToken, k) = BCLib.getBcData(_factory, token);
    }

    /**
     * @notice Gets bc data directly from a bc contract
     * @param bc Bonding curve address
     * @return virtualNative Virtual Native reserve
     * @return virtualToken Virtual token reserve
     * @return k Constant product value
     */
    function getBcData(address bc) public view returns (uint256 virtualNative, uint256 virtualToken, uint256 k) {
        (virtualNative, virtualToken, k) = BCLib.getBcData(bc);
    }

    /**
     * @notice Calculates the output amount for a given input
     * @param amountIn Input amount
     * @param k Constant product value
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountOut Calculated output amount
     */
    function getAmountOut(uint256 amountIn, uint256 k, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        amountOut = BCLib.getAmountOut(amountIn, k, reserveIn, reserveOut);
    }

    /**
     * @notice Calculates the input amount required for a desired output
     * @param amountOut Desired output amount
     * @param k Constant product value
     * @param reserveIn Input reserve
     * @param reserveOut Output reserve
     * @return amountIn Required input amount
     */
    function getAmountIn(uint256 amountOut, uint256 k, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountIn)
    {
        amountIn = BCLib.getAmountIn(amountOut, k, reserveIn, reserveOut);
    }

    /**
     * @notice Gets the address of the fee collection vault
     * @return Address of the vault
     */
    function getFeeVault() public view returns (address) {
        return address(VAULT);
    }
}
