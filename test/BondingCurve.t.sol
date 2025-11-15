// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {Token} from "../src/Token.sol";
import {WMon} from "../src/WMon.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IBondingCurve} from "../src/interfaces/IBondingCurve.sol";
import "../src/errors/CustomErrors.sol" as CustomErrors;

contract BondingCurveTest is Test {
    BondingCurve public bondingCurve;
    Token public token;
    WMon public wMon;
    address public factory = address(0x123);
    address public gNad = address(0x456);

    uint256 public constant VIRTUAL_NATIVE = 1 ether;
    uint256 public constant VIRTUAL_TOKEN = 1000 ether;
    uint256 public constant K = VIRTUAL_NATIVE * VIRTUAL_TOKEN;
    uint256 public constant LOCKED_TOKEN = 100 ether;
    uint8 public constant FEE_DENOMINATOR = 100;
    uint16 public constant FEE_NUMERATOR = 1;

    function setUp() public {
        wMon = new WMon();
        vm.prank(factory);
        bondingCurve = new BondingCurve(gNad, address(wMon));

        vm.prank(factory);
        token = new Token("Test Token", "TEST", "https://example.com", gNad);

        // Mint tokens to bonding curve
        vm.prank(factory);
        token.mint(address(bondingCurve));

        // Initialize bonding curve
        vm.prank(factory);
        bondingCurve.initialize(
            address(token),
            VIRTUAL_NATIVE,
            VIRTUAL_TOKEN,
            K,
            LOCKED_TOKEN,
            FEE_DENOMINATOR,
            FEE_NUMERATOR
        );
    }

    function test_Initialize() public {
        assertEq(bondingCurve.token(), address(token));
        assertEq(bondingCurve.WMON(), address(wMon));
        assertEq(bondingCurve.getK(), K);
        assertEq(bondingCurve.getLockedToken(), LOCKED_TOKEN);
        assertEq(bondingCurve.getLock(), false);
        assertEq(bondingCurve.getIsListing(), false);

        (uint256 vNative, uint256 vToken) = bondingCurve.getVirtualReserves();
        assertEq(vNative, VIRTUAL_NATIVE);
        assertEq(vToken, VIRTUAL_TOKEN);

        (uint8 denom, uint16 num) = bondingCurve.getFeeConfig();
        assertEq(denom, FEE_DENOMINATOR);
        assertEq(num, FEE_NUMERATOR);
    }

    function test_Initialize_Fails_NonFactory() public {
        vm.expectRevert(bytes(CustomErrors.INVALID_FACTORY_ADDRESS));
        bondingCurve.initialize(
            address(token),
            VIRTUAL_NATIVE,
            VIRTUAL_TOKEN,
            K,
            LOCKED_TOKEN,
            FEE_DENOMINATOR,
            FEE_NUMERATOR
        );
    }

    function test_GetReserves() public {
        (uint256 nativeRes, uint256 tokenRes) = bondingCurve.getReserves();
        assertEq(nativeRes, 0);
        assertEq(tokenRes, 10 ** 27); // Initial mint amount
    }

    function test_GetVirtualReserves() public {
        (uint256 vNative, uint256 vToken) = bondingCurve.getVirtualReserves();
        assertEq(vNative, VIRTUAL_NATIVE);
        assertEq(vToken, VIRTUAL_TOKEN);
    }

    function test_GetK() public {
        assertEq(bondingCurve.getK(), K);
    }

    function test_GetLockedToken() public {
        assertEq(bondingCurve.getLockedToken(), LOCKED_TOKEN);
    }

    function test_GetLock() public {
        assertEq(bondingCurve.getLock(), false);
    }

    function test_GetIsListing() public {
        assertEq(bondingCurve.getIsListing(), false);
    }

    function test_Buy_Fails_NotGNad() public {
        address recipient = address(0x999);
        uint256 amountOut = 10 ether;

        vm.expectRevert(bytes(CustomErrors.INVALID_GNAD_ADDRESS));
        bondingCurve.buy(recipient, amountOut);
    }

    function test_Buy_Fails_InvalidAmountOut() public {
        vm.prank(gNad);
        vm.expectRevert(bytes(CustomErrors.INVALID_AMOUNT_OUT));
        bondingCurve.buy(address(0x999), 0);
    }

    function test_Buy_Fails_InvalidRecipient() public {
        vm.prank(gNad);
        vm.expectRevert(bytes(CustomErrors.INVALID_RECIPIENT));
        bondingCurve.buy(address(wMon), 10 ether);
    }

    function test_Sell_Fails_NotGNad() public {
        vm.expectRevert(bytes(CustomErrors.INVALID_GNAD_ADDRESS));
        bondingCurve.sell(address(0x999), 1 ether);
    }

    function test_Sell_Fails_InvalidAmountOut() public {
        vm.prank(gNad);
        vm.expectRevert(bytes(CustomErrors.INVALID_AMOUNT_OUT));
        bondingCurve.sell(address(0x999), 0);
    }
}

