// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IVaultManager
/// @dev Interface for the VaultManager contract.
interface IVaultManager {
    /// @notice Registers a pool's vault upon creation.
    /// @param pool Address of the pool.
    /// @param vault Address of the vault associated with the pool.
    function registerPoolVault(address pool, address vault) external;

    /// @notice Deregisters a pool's vault upon loan closure.
    /// @param pool Address of the pool.
    function deregisterVault(address pool) external;

    /// @notice Distributes accrued interest from a vault to a specified recipient.
    /// @param pool Address of the pool initiating the interest payout.
    /// @param to Recipient of the interest payment.
    /// @param amount Amount of interest to be distributed.
    function distributeInterest(address pool, address to, uint256 amount) external;

    /// @notice Calculates the claimable interest for a user based on the pool's loan configuration.
    /// @param pool Address of the pool for which to calculate interest.
    /// @param user Address of the user (borrower) claiming interest.
    /// @return amount The calculated interest amount.
    function calculateClaimableInterest(address pool, address user) external view returns (uint256);
}
