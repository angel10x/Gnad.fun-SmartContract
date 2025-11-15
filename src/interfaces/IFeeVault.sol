// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title IFeeVault
 * @dev Interface for the FeeVault contract that manages WNAD token withdrawals through multisig.
 */
interface IFeeVault {
    // Withdrawal proposal structure
    struct WithdrawalProposal {
        address receiver;
        uint256 amount;
        uint256 signatureCount;
        mapping(address => bool) hasSignedWithdrawal;
        bool executed;
    }
    
    /**
     * @dev Emitted when a new owner is added
     */
    event OwnerAdded(address indexed owner);

    /**
     * @dev Emitted when an owner is removed
     */
    event OwnerRemoved(address indexed owner);

    /**
     * @dev Emitted when a new withdrawal is proposed
     */
    event WithdrawalProposed(uint256 indexed proposalId, address receiver, uint256 amount);

    /**
     * @dev Emitted when an owner signs a withdrawal proposal
     */
    event WithdrawalSigned(uint256 indexed proposalId, address signer);

    /**
     * @dev Emitted when a withdrawal is executed
     */
    event WithdrawalExecuted(uint256 indexed proposalId, address receiver, uint256 amount);

    /**
     * @dev Returns the total balance of WNAD in the vault
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev Proposes a new withdrawal
     * @param receiver Address to receive the withdrawn assets
     * @param amount Amount of WNAD to withdraw
     */
    function proposeWithdrawal(address receiver, uint256 amount) external;

    /**
     * @dev Signs an existing withdrawal proposal
     * @param proposalId ID of the withdrawal proposal
     */
    function signWithdrawal(uint256 proposalId) external;
}
