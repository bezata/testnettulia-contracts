// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


/// @title IVaultManager
/// @dev Interface for the VaultManager contract.
interface IVaultManager {
    /// @notice Registers a pool's vault upon creation.
    /// @param pool Address of the pool.
    function registerPoolVault(address pool) external;

    /// @notice Deregisters a pool's vault upon loan closure.
    /// @param pool Address of the pool.
    function deregisterVault(address pool) external;

    /// @notice Distributes accrued interest from a vault to a specified recipient.
    /// @param pool Address of the pool initiating the interest payout.
    /// @param to Recipient of the interest payment.
    function distributeInterest(address pool, address to) external;

    /// @notice Calculates the claimable interest for a user based on the pool's loan configuration.
    /// @param pool Address of the pool for which to calculate interest.
    /// @return amount The calculated interest amount.
    function calculateClaimableInterest(address pool) external view returns (uint256);

    /// @notice Refunds any remaining interest to the borrower when the loan is repaid.
    /// @param pool Address of the pool.
    /// @param borrower Address of the borrower.
    function refundRemainingInterest(address pool, address borrower) external;

    /// @notice Accepts deposit of interest for a specific loan pool.
    /// @param pool The address of the loan pool associated with this interest payment.
    /// @param amount The amount of interest being paid.
    function handleInterest(address pool, uint256 amount) external;
    
    /// @notice Handle the default for the lender to get remaining interest.
    /// @param pool The address of the loan pool associated with this interest payment.
    /// @param lender The lender address of that pool.
    function handleDefault(address pool, address lender) external;
}
