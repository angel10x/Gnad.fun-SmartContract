// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IToken} from "./interfaces/IToken.sol";
import {IGNad} from "./interfaces/IGNad.sol";
import {IBondingCurveFactory} from "./interfaces/IBondingCurveFactory.sol";
import {IBondingCurve} from "./interfaces/IBondingCurve.sol";
import {TransferLib} from "./lib/Transfer.sol";
import {BCLib} from "./lib/BCLib.sol";
import "./errors/CustomErrors.sol";

/**
 * @title BondingCurve
 * @dev Implementation of a bonding curve for token price discovery
 * Manages the relationship between Native and project tokens using a constant product formula
 */
contract BondingCurve is IBondingCurve {
    using SafeERC20 for IERC20;

    // Immutable state variables
    address immutable factory;
    address immutable core;
    address public immutable wNative; // Wrapped Native token address
    address public token; // Project token address
    address public pair;
    // Virtual reserves for price calculation
    uint256 private virtualNative; // Virtual Native reserve
    uint256 private virtualToken; // Virtual token reserve
    uint256 private k; // Constant product parameter
    uint256 private targetToken; // Target token amount for listing

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
     * @dev Constructor sets immutable factory and core addresses
     * @param _core Address of the core contract
     * @param _wNative Address of the WNATIVE token
     */
    constructor(address _core, address _wNative) {
        factory = msg.sender;
        core = _core;
        wNative = _wNative;
    }

    /**
     * @notice Initializes the bonding curve with its parameters
     * @dev Called once by factory during deployment
     * @param _token Project token address
     * @param _virtualNative Initial virtual Native reserve
     * @param _virtualToken Initial virtual token reserve
     * @param _k Constant product parameter
     * @param _targetToken Target token amount for DEX listing
     * @param _feeDenominator Fee denominator
     * @param _feeNumerator Fee numerator
     */
    function initialize(
        address _token,
        uint256 _virtualNative,
        uint256 _virtualToken,
        uint256 _k,
        uint256 _targetToken,
        uint8 _feeDenominator,
        uint16 _feeNumerator
    ) external {
        require(msg.sender == factory, INVALID_FACTORY_ADDRESS);
        token = _token;
        virtualNative = _virtualNative;
        virtualToken = _virtualToken;

        k = _k;
        realNativeReserves = IERC20(wNative).balanceOf(address(this));
        realTokenReserves = IERC20(_token).balanceOf(address(this));
        targetToken = _targetToken;
        feeConfig = Fee(_feeDenominator, _feeNumerator);
        isListing = false;
    }
}
