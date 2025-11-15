// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {BondingCurveFactory} from "../src/BondingCurveFactory.sol";
import {BondingCurve} from "../src/BondingCurve.sol";
import {Token} from "../src/Token.sol";
import {WMon} from "../src/WMon.sol";
import {IBondingCurveFactory} from "../src/interfaces/IBondingCurveFactory.sol";
import "../src/errors/CustomErrors.sol" as CustomErrors;

contract BondingCurveFactoryTest is Test {
    BondingCurveFactory public factory;
    WMon public wMon;
    address public owner = address(0x123);
    address public gNad = address(0x456);
    address public dexFactory = address(0x789);

    uint256 public constant DEPLOY_FEE = 0.1 ether;
    uint256 public constant LISTING_FEE = 0.05 ether;
    uint256 public constant TOKEN_TOTAL_SUPPLY = 10 ** 27;
    uint256 public constant VIRTUAL_NATIVE = 1 ether;
    uint256 public constant VIRTUAL_TOKEN = 1000 ether;
    uint256 public constant TARGET_TOKEN = 100 ether;
    uint8 public constant FEE_DENOMINATOR = 100;
    uint16 public constant FEE_NUMERATOR = 1;

    function setUp() public {
        wMon = new WMon();
        factory = new BondingCurveFactory(owner, gNad, address(wMon));

        // Initialize factory
        IBondingCurveFactory.InitializeParams memory params = IBondingCurveFactory.InitializeParams({
            deployFee: DEPLOY_FEE,
            listingFee: LISTING_FEE,
            tokenTotalSupply: TOKEN_TOTAL_SUPPLY,
            virtualNative: VIRTUAL_NATIVE,
            virtualToken: VIRTUAL_TOKEN,
            targetToken: TARGET_TOKEN,
            feeNumerator: FEE_NUMERATOR,
            feeDenominator: FEE_DENOMINATOR,
            dexFactory: dexFactory
        });

        vm.prank(owner);
        factory.initialize(params);
    }

    function test_InitialState() public {
        assertEq(factory.WMON(), address(wMon));
        assertEq(factory.getOwner(), owner);
        assertEq(factory.getGNad(), gNad);
        assertEq(factory.getDexFactory(), dexFactory);
    }

    function test_Initialize() public {
        IBondingCurveFactory.Config memory config = factory.getConfig();
        assertEq(config.deployFee, DEPLOY_FEE);
        assertEq(config.listingFee, LISTING_FEE);
        assertEq(config.tokenTotalSupply, TOKEN_TOTAL_SUPPLY);
        assertEq(config.virtualNative, VIRTUAL_NATIVE);
        assertEq(config.virtualToken, VIRTUAL_TOKEN);
        assertEq(config.k, VIRTUAL_NATIVE * VIRTUAL_TOKEN);
        assertEq(config.targetToken, TARGET_TOKEN);
        assertEq(config.feeDenominator, FEE_DENOMINATOR);
        assertEq(config.feeNumerator, FEE_NUMERATOR);
    }

    function test_Initialize_Fails_NonOwner() public {
        IBondingCurveFactory.InitializeParams memory params = IBondingCurveFactory.InitializeParams({
            deployFee: DEPLOY_FEE,
            listingFee: LISTING_FEE,
            tokenTotalSupply: TOKEN_TOTAL_SUPPLY,
            virtualNative: VIRTUAL_NATIVE,
            virtualToken: VIRTUAL_TOKEN,
            targetToken: TARGET_TOKEN,
            feeNumerator: FEE_NUMERATOR,
            feeDenominator: FEE_DENOMINATOR,
            dexFactory: dexFactory
        });

        vm.expectRevert(bytes(CustomErrors.INVALID_BC_FACTORY_OWNER));
        factory.initialize(params);
    }

    function test_Create() public {
        address creator = address(0xABC);
        string memory name = "Test Token";
        string memory symbol = "TEST";
        string memory tokenURI = "https://example.com";

        vm.expectEmit(true, true, true, true);
        emit IBondingCurveFactory.Create(
            creator, address(0), address(0), tokenURI, name, symbol, VIRTUAL_NATIVE, VIRTUAL_TOKEN
        );

        vm.prank(gNad);
        (address bc, address token, uint256 vNative, uint256 vToken) =
            factory.create(creator, name, symbol, tokenURI);

        assertTrue(bc != address(0));
        assertTrue(token != address(0));
        assertEq(vNative, VIRTUAL_NATIVE);
        assertEq(vToken, VIRTUAL_TOKEN);

        // Verify bonding curve exists for token
        assertEq(factory.getBc(token), bc);

        // Verify token was minted to bonding curve
        assertEq(IERC20(token).balanceOf(bc), TOKEN_TOTAL_SUPPLY);
    }

    function test_Create_Fails_NonGNad() public {
        vm.expectRevert(bytes(CustomErrors.INVALID_GNAD));
        factory.create(address(0xABC), "Test", "TEST", "https://example.com");
    }

    function test_GetConfig() public {
        IBondingCurveFactory.Config memory config = factory.getConfig();
        assertEq(config.deployFee, DEPLOY_FEE);
        assertEq(config.listingFee, LISTING_FEE);
    }

    function test_GetK() public {
        assertEq(factory.getK(), VIRTUAL_NATIVE * VIRTUAL_TOKEN);
    }

    function test_GetDelpyFee() public {
        assertEq(factory.getDelpyFee(), DEPLOY_FEE);
    }

    function test_GetListingFee() public {
        assertEq(factory.getListingFee(), LISTING_FEE);
    }

    function test_GetFeeConfig() public {
        (uint8 denominator, uint16 numerator) = factory.getFeeConfig();
        assertEq(denominator, FEE_DENOMINATOR);
        assertEq(numerator, FEE_NUMERATOR);
    }

    function test_SetOwner() public {
        address newOwner = address(0x999);

        vm.prank(owner);
        factory.setOwner(newOwner);

        assertEq(factory.getOwner(), newOwner);
    }

    function test_SetOwner_Fails_NonOwner() public {
        vm.expectRevert(bytes(CustomErrors.INVALID_BC_FACTORY_OWNER));
        factory.setOwner(address(0x999));
    }

    function test_SetGNad() public {
        address newGNad = address(0x888);

        vm.expectEmit(true, false, false, true);
        emit IBondingCurveFactory.SetGNad(newGNad);

        vm.prank(owner);
        factory.setGNad(newGNad);

        assertEq(factory.getGNad(), newGNad);
    }

    function test_SetDexFactory() public {
        address newDexFactory = address(0x777);

        vm.expectEmit(true, false, false, true);
        emit IBondingCurveFactory.SetDexFactory(newDexFactory);

        vm.prank(owner);
        factory.setDexFactory(newDexFactory);

        assertEq(factory.getDexFactory(), newDexFactory);
    }

    function test_MultipleCreates() public {
        vm.startPrank(gNad);

        (address bc1, address token1,,) = factory.create(address(0x1), "Token1", "T1", "uri1");
        (address bc2, address token2,,) = factory.create(address(0x2), "Token2", "T2", "uri2");

        vm.stopPrank();

        assertTrue(bc1 != bc2);
        assertTrue(token1 != token2);
        assertEq(factory.getBc(token1), bc1);
        assertEq(factory.getBc(token2), bc2);
    }
}

