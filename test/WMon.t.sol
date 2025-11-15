// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {WMon} from "../src/WMon.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract WMonTest is Test {
    WMon public wMon;
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    event Deposit(address indexed account, uint256 amount);
    event Withdrawal(address indexed account, uint256 amount);

    function setUp() public {
        wMon = new WMon();
    }

    function test_InitialState() public {
        assertEq(wMon.name(), "Wrapped Monad Token");
        assertEq(wMon.symbol(), "WMon");
        assertEq(wMon.decimals(), 18);
        assertEq(wMon.totalSupply(), 0);
    }

    function test_Deposit() public {
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, amount);

        vm.prank(user1);
        wMon.deposit{value: amount}();

        assertEq(wMon.balanceOf(user1), amount);
        assertEq(wMon.totalSupply(), amount);
        assertEq(address(wMon).balance, amount);
    }

    function test_Receive() public {
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, amount);

        vm.prank(user1);
        (bool success,) = address(wMon).call{value: amount}("");
        assertTrue(success);

        assertEq(wMon.balanceOf(user1), amount);
        assertEq(wMon.totalSupply(), amount);
    }

    function test_Fallback() public {
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        vm.expectEmit(true, false, false, true);
        emit Deposit(user1, amount);

        vm.prank(user1);
        (bool success,) = address(wMon).call{value: amount}("");
        assertTrue(success);

        assertEq(wMon.balanceOf(user1), amount);
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 0.5 ether;
        vm.deal(user1, depositAmount);

        // First deposit
        vm.prank(user1);
        wMon.deposit{value: depositAmount}();

        uint256 balanceBefore = address(user1).balance;

        vm.expectEmit(true, false, false, true);
        emit Withdrawal(user1, withdrawAmount);

        vm.prank(user1);
        wMon.withdraw(withdrawAmount);
        console.log("balance of user", wMon.balanceOf(user1));
        console.log("wMon.totalSupply()", wMon.totalSupply());
        console.log("address(user1).balance", address(user1).balance);
        console.log("depositAmount", depositAmount);
        console.log("withdrawAmount", withdrawAmount);

        assertEq(wMon.balanceOf(user1), depositAmount - withdrawAmount);
        assertEq(wMon.totalSupply(), depositAmount - withdrawAmount);
        assertEq(address(user1).balance, balanceBefore + withdrawAmount);
    }

    function test_Withdraw_Fails_InsufficientBalance() public {
        uint256 depositAmount = 1 ether;
        uint256 withdrawAmount = 2 ether;
        vm.deal(user1, depositAmount);

        vm.prank(user1);
        wMon.deposit{value: depositAmount}();

        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        wMon.withdraw(withdrawAmount);
    }

    function test_PermitTypeHash() public {
        bytes32 expectedHash = keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );
        assertEq(wMon.permitTypeHash(), expectedHash);
    }

    function test_Nonces() public {
        assertEq(wMon.nonces(user1), 0);
    }

    function test_MultipleDeposits() public {
        vm.deal(user1, 10 ether);

        vm.prank(user1);
        wMon.deposit{value: 1 ether}();
        assertEq(wMon.balanceOf(user1), 1 ether);

        vm.prank(user1);
        wMon.deposit{value: 2 ether}();
        assertEq(wMon.balanceOf(user1), 3 ether);
        assertEq(wMon.totalSupply(), 3 ether);
    }

    function test_Transfer() public {
        uint256 amount = 1 ether;
        vm.deal(user1, amount);

        vm.prank(user1);
        wMon.deposit{value: amount}();

        vm.prank(user1);
        assertTrue(wMon.transfer(user2, 0.5 ether));

        assertEq(wMon.balanceOf(user1), 0.5 ether);
        assertEq(wMon.balanceOf(user2), 0.5 ether);
    }
}

