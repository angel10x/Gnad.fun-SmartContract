// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";  

contract BondingCurve {
    using SafeERC20 for IERC20;

    // Immutable state variables
    address immutable factory;
    address immutable core;
    address public immutable wMon; // Wrapped Monad Token address
    
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
    bool public lock;

    constructor(address _core, address _wMon) {
        factory = msg.sender;
        core = _core;
        wMon = _wMon;
    }
}
