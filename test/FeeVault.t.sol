// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FeeVault} from "../src/FeeVault.sol";
import {WMon} from "../src/WMon.sol";
import {IFeeVault} from "../src/interfaces/IFeeVault.sol";

contract FeeVaultTest is Test {
    FeeVault public vault;
    WMon public wMon;
    address public owner1 = address(0x1);
    address public owner2 = address(0x2);
    address public owner3 = address(0x3);
    address public receiver = address(0x999);

    function setUp() public {
        wMon = new WMon();
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vault = new FeeVault(address(wMon), owners, 2);
    }

    function test_InitialState() public {
        assertTrue(vault.isOwner(owner1));
        assertTrue(vault.isOwner(owner2));
        assertTrue(vault.isOwner(owner3));
        assertEq(vault.ownerCount(), 3);
        assertEq(vault.requiredSignatures(), 2);
        assertEq(vault.proposalCount(), 0);
    }

    function test_Constructor_Fails_InvalidWMON() public {
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        vm.expectRevert("ERR_FEE_VAULT_INVALID_WMON_ADDRESS");
        new FeeVault(address(0), owners, 1);
    }

    function test_Constructor_Fails_NoOwners() public {
        address[] memory owners = new address[](0);

        vm.expectRevert("ERR_FEE_VAULT_NO_OWNERS");
        new FeeVault(address(wMon), owners, 1);
    }

    function test_Constructor_Fails_InvalidSignatures() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;

        vm.expectRevert("ERR_FEE_VAULT_INVALID_SIGNATURES_REQUIRED");
        new FeeVault(address(wMon), owners, 3); // More than owners
    }

    function test_TotalAssets() public {
        uint256 amount = 10 ether;
        vm.deal(address(this), amount);
        wMon.deposit{value: amount}();
        wMon.transfer(address(vault), amount);

        assertEq(vault.totalAssets(), amount);
    }

    function test_ProposeWithdrawal() public {
        uint256 amount = 10 ether;
        vm.deal(address(this), amount);
        wMon.deposit{value: amount}();
        wMon.transfer(address(vault), amount);

        vm.expectEmit(true, false, false, true);
        emit IFeeVault.WithdrawalProposed(0, receiver, amount);

        vm.prank(owner1);
        vault.proposeWithdrawal(receiver, amount);

        // Verify proposal was created by checking that we can sign it
        // (if proposal doesn't exist, signWithdrawal will revert)
        vm.expectEmit(true, false, false, true);
        emit IFeeVault.WithdrawalSigned(0, owner2);
        
        vm.prank(owner2);
        vault.signWithdrawal(0);
        
        // If we get here and no revert, the proposal was created correctly
        // Execution happens automatically when required signatures are met
    }

    function test_ProposeWithdrawal_Fails_NotOwner() public {
        vm.expectRevert("ERR_FEE_VAULT_NOT_OWNER");
        vault.proposeWithdrawal(receiver, 1 ether);
    }

    function test_ProposeWithdrawal_Fails_InvalidReceiver() public {
        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_INVALID_RECEIVER");
        vault.proposeWithdrawal(address(0), 1 ether);
    }

    function test_ProposeWithdrawal_Fails_InvalidAmount() public {
        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_INVALID_AMOUNT");
        vault.proposeWithdrawal(receiver, 0);
    }

    function test_ProposeWithdrawal_Fails_InsufficientBalance() public {
        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_INSUFFICIENT_BALANCE");
        vault.proposeWithdrawal(receiver, 1 ether);
    }

    function test_SignWithdrawal() public {
        uint256 amount = 10 ether;
        vm.deal(address(this), amount);
        wMon.deposit{value: amount}();
        wMon.transfer(address(vault), amount);

        // Propose withdrawal
        vm.prank(owner1);
        vault.proposeWithdrawal(receiver, amount);

        // Sign by second owner
        uint256 receiverBalanceBefore = receiver.balance;

        vm.expectEmit(true, false, false, true);
        emit IFeeVault.WithdrawalSigned(0, owner2);

        vm.prank(owner2);
        vault.signWithdrawal(0);

        // Should execute automatically since we have required signatures (requiredSignatures = 2)
        // Verify execution by checking the receiver received the funds
        assertEq(receiver.balance, receiverBalanceBefore + amount);
        
        // Verify proposal is executed by trying to sign again (should revert)
        vm.prank(owner3);
        vm.expectRevert("ERR_FEE_VAULT_ALREADY_EXECUTED");
        vault.signWithdrawal(0);
    }

    function test_SignWithdrawal_Fails_InvalidProposal() public {
        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_INVALID_PROPOSAL");
        vault.signWithdrawal(999);
    }

    function test_SignWithdrawal_Fails_AlreadyExecuted() public {
        uint256 amount = 10 ether;
        vm.deal(address(this), amount);
        wMon.deposit{value: amount}();
        wMon.transfer(address(vault), amount);

        // Propose and execute
        vm.prank(owner1);
        vault.proposeWithdrawal(receiver, amount);

        vm.prank(owner2);
        vault.signWithdrawal(0);

        // Try to sign again
        vm.prank(owner3);
        vm.expectRevert("ERR_FEE_VAULT_ALREADY_EXECUTED");
        vault.signWithdrawal(0);
    }

    function test_SignWithdrawal_Fails_AlreadySigned() public {
        uint256 amount = 10 ether;
        vm.deal(address(this), amount);
        wMon.deposit{value: amount}();
        wMon.transfer(address(vault), amount);

        vm.prank(owner1);
        vault.proposeWithdrawal(receiver, amount);

        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_ALREADY_SIGNED");
        vault.signWithdrawal(0);
    }

    function test_MultipleProposals() public {
        uint256 amount = 20 ether;
        vm.deal(address(this), amount);
        wMon.deposit{value: amount}();
        wMon.transfer(address(vault), amount);

        // First proposal
        vm.prank(owner1);
        vault.proposeWithdrawal(receiver, 5 ether);

        // Second proposal
        vm.prank(owner2);
        vault.proposeWithdrawal(receiver, 5 ether);

        assertEq(vault.proposalCount(), 2);

        // Verify both proposals exist by trying to sign them
        // First proposal - should succeed (not executed yet)
        vm.prank(owner3);
        vault.signWithdrawal(0);
        
        // Second proposal - should succeed (not executed yet)
        vm.prank(owner3);
        vault.signWithdrawal(1);
        
        // Both proposals should now be executed since we have required signatures (2)
        // Verify by trying to sign again (should revert)
        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_ALREADY_EXECUTED");
        vault.signWithdrawal(0);
        
        vm.prank(owner1);
        vm.expectRevert("ERR_FEE_VAULT_ALREADY_EXECUTED");
        vault.signWithdrawal(1);
    }
}

