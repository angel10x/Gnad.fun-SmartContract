// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {GNad} from "../src/GNad.sol";
import {IGNad} from "../src/interfaces/IGNad.sol";
import {BondingCurveFactory} from "../src/BondingCurveFactory.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {Token} from "../src/Token.sol";
import {WMon} from "../src/WMon.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IBondingCurveFactory} from "../src/interfaces/IBondingCurveFactory.sol";
import "../src/errors/CustomErrors.sol" as CustomErrors;

contract GNadTest is Test {
    GNad public gNad;
    BondingCurveFactory public factory;
    WMon public wMon;
    FeeVault public vault;
    BondingCurve public bondingCurve;

    address public owner = address(0x123);
    address public user = address(0x456);
    address public creator = address(0x789);
    address public receiver = address(0xABC);

    uint256 public constant DEPLOY_FEE = 0.1 ether;
    uint256 public constant LISTING_FEE = 0.05 ether;
    uint256 public constant TOKEN_TOTAL_SUPPLY = 10 ** 27;
    uint256 public constant VIRTUAL_NATIVE = 1 ether;
    uint256 public constant VIRTUAL_TOKEN = 1000 ether;
    uint256 public constant TARGET_TOKEN = 100 ether;
    uint8 public constant FEE_DENOMINATOR = 100;
    uint16 public constant FEE_NUMERATOR = 1;
    address public constant DEX_FACTORY = address(0x999);

    function setUp() public {
        // Deploy WMon
        wMon = new WMon();

        // Deploy FeeVault
        address[] memory owners = new address[](1);
        owners[0] = owner;
        vault = new FeeVault(address(wMon), owners, 1);

        // Deploy GNad
        gNad = new GNad(address(wMon), address(vault));

        // Deploy Factory
        factory = new BondingCurveFactory(owner, address(gNad), address(wMon));

        // Initialize Factory
        IBondingCurveFactory.InitializeParams memory params = IBondingCurveFactory.InitializeParams({
            deployFee: DEPLOY_FEE,
            listingFee: LISTING_FEE,
            tokenTotalSupply: TOKEN_TOTAL_SUPPLY,
            virtualNative: VIRTUAL_NATIVE,
            virtualToken: VIRTUAL_TOKEN,
            targetToken: TARGET_TOKEN,
            feeNumerator: FEE_NUMERATOR,
            feeDenominator: FEE_DENOMINATOR,
            dexFactory: DEX_FACTORY
        });

        vm.prank(owner);
        factory.initialize(params);

        // Initialize GNad
        gNad.initialize(address(factory));
    }

    function test_InitialState() public {
        assertEq(gNad.WMON(), address(wMon));
        assertEq(gNad.bcFactory(), address(factory));
    }

    function test_Initialize() public {
        GNad newGNad = new GNad(address(wMon), address(vault));
        
        assertEq(newGNad.WMON(), address(wMon));
        
        newGNad.initialize(address(factory));
        
        assertEq(newGNad.bcFactory(), address(factory));
    }

    function test_Initialize_Fails_AlreadyInitialized() public {
        vm.expectRevert(bytes(CustomErrors.ALREADY_INITIALIZED));
        gNad.initialize(address(factory));
    }

    function test_CreateBc_WithInitialBuy() public {
        uint256 amountIn = 1 ether;
        uint256 fee = 0.01 ether;
        uint256 totalValue = amountIn + fee + DEPLOY_FEE;

        vm.deal(creator, totalValue);

        vm.expectEmit(false, false, false, false);
        emit IGNad.GNadCreate();

        vm.prank(creator);
        (address bc, address token, uint256 vNative, uint256 vToken, uint256 amountOut) = gNad
            .createBc{value: totalValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            amountIn,
            fee
        );

        assertTrue(bc != address(0));
        assertTrue(token != address(0));
        assertTrue(amountOut > 0);

        // Verify token was transferred to creator
        assertEq(IERC20(token).balanceOf(creator), amountOut);
    }

    function test_CreateBc_WithoutInitialBuy() public {
        uint256 totalValue = DEPLOY_FEE;

        vm.deal(creator, totalValue);

        vm.expectEmit(false, false, false, false);
        emit IGNad.GNadCreate();

        vm.prank(creator);
        (address bc, address token, uint256 vNative, uint256 vToken, uint256 amountOut) = gNad
            .createBc{value: totalValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        assertTrue(bc != address(0));
        assertTrue(token != address(0));
        assertEq(amountOut, 0);
    }

    function test_CreateBc_Fails_InsufficientValue() public {
        uint256 amountIn = 1 ether;
        uint256 fee = 0.01 ether;
        uint256 totalValue = amountIn + fee; // Missing deploy fee

        vm.deal(creator, totalValue);

        vm.prank(creator);
        vm.expectRevert(bytes(CustomErrors.INVALID_MON_AMOUNT));
        gNad.createBc{value: totalValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            amountIn,
            fee
        );
    }

    function test_Buy() public {
        // First create a bonding curve
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        // Setup for buy
        uint256 amountIn = 1 ether;
        uint256 fee = 0.01 ether;
        uint256 totalValue = amountIn + fee;

        vm.deal(user, totalValue);
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectEmit(false, false, false, false);
        emit IGNad.GNadBuy();

        vm.prank(user);
        gNad.buy{value: totalValue}(amountIn, fee, token, receiver, deadline);

        // Verify tokens were received
        assertGt(IERC20(token).balanceOf(receiver), 0);
    }

    function test_Buy_Fails_ExpiredDeadline() public {
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        uint256 amountIn = 1 ether;
        uint256 fee = 0.01 ether;
        uint256 totalValue = amountIn + fee;
        uint256 deadline = block.timestamp - 1; // Expired

        vm.deal(user, totalValue);

        vm.prank(user);
        vm.expectRevert(bytes(CustomErrors.TIME_EXPIRED));
        gNad.buy{value: totalValue}(amountIn, fee, token, receiver, deadline);
    }

    function test_Buy_Fails_InsufficientValue() public {
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        uint256 amountIn = 1 ether;
        uint256 fee = 0.01 ether;
        uint256 totalValue = amountIn; // Missing fee

        vm.deal(user, totalValue);
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(user);
        vm.expectRevert(bytes(CustomErrors.INVALID_MON_AMOUNT));
        gNad.buy{value: totalValue}(amountIn, fee, token, receiver, deadline);
    }

    function test_Sell() public {
        // Setup: Create BC and buy tokens first
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        // Buy tokens
        uint256 buyAmountIn = 2 ether;
        uint256 buyFee = 0.02 ether;
        uint256 buyTotal = buyAmountIn + buyFee;
        vm.deal(user, buyTotal);

        vm.prank(user);
        gNad.buy{value: buyTotal}(buyAmountIn, buyFee, token, user, block.timestamp + 1 hours);

        uint256 tokenBalance = IERC20(token).balanceOf(user);
        assertGt(tokenBalance, 0);

        // Approve tokens
        vm.prank(user);
        IERC20(token).approve(address(gNad), tokenBalance);

        // Sell tokens
        uint256 deadline = block.timestamp + 1 hours;
        uint256 receiverBalanceBefore = receiver.balance;

        vm.prank(user);
        gNad.sell(tokenBalance, token, receiver, deadline);

        assertGt(receiver.balance, receiverBalanceBefore);
    }

    function test_Sell_Fails_ExpiredDeadline() public {
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        // Buy tokens first
        uint256 buyAmountIn = 1 ether;
        uint256 buyFee = 0.01 ether;
        vm.deal(user, buyAmountIn + buyFee);

        vm.prank(user);
        gNad.buy{value: buyAmountIn + buyFee}(
            buyAmountIn,
            buyFee,
            token,
            user,
            block.timestamp + 1 hours
        );

        uint256 tokenBalance = IERC20(token).balanceOf(user);
        vm.prank(user);
        IERC20(token).approve(address(gNad), tokenBalance);

        uint256 deadline = block.timestamp - 1; // Expired

        vm.prank(user);
        vm.expectRevert(bytes(CustomErrors.TIME_EXPIRED));
        gNad.sell(tokenBalance, token, receiver, deadline);
    }

    function test_Sell_Fails_InvalidAllowance() public {
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(user);
        vm.expectRevert(bytes(CustomErrors.INVALID_ALLOWANCE));
        gNad.sell(1 ether, token, receiver, deadline);
    }

    function test_ProtectBuy() public {
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        uint256 amountIn = 1 ether;
        uint256 fee = 0.01 ether;
        uint256 totalValue = amountIn + fee;
        uint256 deadline = block.timestamp + 1 hours;

        vm.deal(user, totalValue);

        vm.prank(user);
        gNad.protectBuy{value: totalValue}(amountIn, 0, fee, token, receiver, deadline);

        assertGt(IERC20(token).balanceOf(receiver), 0);
    }

    function test_ProtectSell() public {
        // Setup
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        // Buy tokens
        uint256 buyAmountIn = 2 ether;
        uint256 buyFee = 0.02 ether;
        vm.deal(user, buyAmountIn + buyFee);

        vm.prank(user);
        gNad.buy{value: buyAmountIn + buyFee}(
            buyAmountIn,
            buyFee,
            token,
            user,
            block.timestamp + 1 hours
        );

        uint256 tokenBalance = IERC20(token).balanceOf(user);
        vm.prank(user);
        IERC20(token).approve(address(gNad), tokenBalance);

        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(user);
        gNad.protectSell(tokenBalance, 0, token, receiver, deadline);

        assertGt(receiver.balance, 0);
    }

    function test_GetBc() public {
        uint256 deployValue = DEPLOY_FEE;
        vm.deal(creator, deployValue);

        vm.prank(creator);
        (address bc, address token,,,) = gNad.createBc{value: deployValue}(
            creator,
            "Test Token",
            "TEST",
            "https://example.com",
            0,
            0
        );

        assertEq(factory.getBc(token), bc);
    }

    function test_GetFeeVault() public {
        assertEq(gNad.getFeeVault(), address(vault));
    }
}

