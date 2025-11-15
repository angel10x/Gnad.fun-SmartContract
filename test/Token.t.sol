// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TokenTest is Test {
    Token public token;
    address public factory = address(0x123);
    address public gNad = address(0x456);
    address public curve = address(0x789);

    string public constant TOKEN_NAME = "Test Token";
    string public constant TOKEN_SYMBOL = "TEST";
    string public constant TOKEN_URI = "https://example.com/token";

    function setUp() public {
        vm.prank(factory);
        token = new Token(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_URI, gNad);
    }

    function test_InitialState() public {
        assertEq(token.name(), TOKEN_NAME);
        assertEq(token.symbol(), TOKEN_SYMBOL);
        assertEq(token.tokenURI(), TOKEN_URI);
        assertEq(token.totalSupply(), 0);
        assertEq(token.decimals(), 18);
    }

    function test_Mint() public {
        vm.prank(factory);
        token.mint(curve);

        assertEq(token.totalSupply(), 10 ** 27); // 1B tokens
        assertEq(token.balanceOf(curve), 10 ** 27);
    }

    function test_Mint_Fails_NonFactory() public {
        vm.expectRevert("Invalid token factory address");
        token.mint(curve);
    }

    function test_Mint_Fails_AlreadyMinted() public {
        vm.prank(factory);
        token.mint(curve);

        vm.prank(factory);
        vm.expectRevert("Invalid: Token can mint only one time");
        token.mint(curve);
    }

    function test_Mint_Fails_NonZeroSupply() public {
        vm.prank(factory);
        token.mint(curve);

        // Try to mint again
        vm.prank(factory);
        vm.expectRevert("Invalid: Token can mint only one time");
        token.mint(curve);
    }

    function test_Burn() public {
        address burner = address(0xABC);
        vm.prank(factory);
        token.mint(curve);

        // Transfer some tokens to burner
        vm.prank(curve);
        token.transfer(burner, 1000);

        uint256 balanceBefore = token.balanceOf(burner);
        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(burner);
        token.burn(500);

        assertEq(token.balanceOf(burner), balanceBefore - 500);
        assertEq(token.totalSupply(), totalSupplyBefore - 500);
    }

    function test_PermitTypeHash() public {
        bytes32 expectedHash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        assertEq(token.permitTypeHash(), expectedHash);
    }

    function test_Nonces() public {
        address owner = address(0xDEF);
        assertEq(token.nonces(owner), 0);
    }

    function test_Transfer() public {
        address recipient = address(0x999);
        vm.prank(factory);
        token.mint(curve);

        uint256 transferAmount = 1000;

        vm.prank(curve);
        assertTrue(token.transfer(recipient, transferAmount));

        assertEq(token.balanceOf(curve), 10 ** 27 - transferAmount);
        assertEq(token.balanceOf(recipient), transferAmount);
    }

    function test_FullBurn() public {
        address burner = address(0xABC);
        vm.prank(factory);
        token.mint(curve);

        uint256 burnAmount = 10 ** 27;

        // Transfer all tokens to burner
        vm.prank(curve);
        token.transfer(burner, burnAmount);

        vm.prank(burner);
        token.burn(burnAmount);

        assertEq(token.balanceOf(burner), 0);
        assertEq(token.totalSupply(), 0);
    }
}

