// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRewardManager {
    /// @notice Registers a pool to be eligible for rewards, initializing its reward token.
    /// @param pool The address of the pool to register.
    /// @param rewardToken The ERC20 address for the reward token.
    function registerPool(address pool, address rewardToken) external;

    /// @notice Accrues rewards for a specific pool.
    /// @param pool The address of the pool.
    function accrueRewards(address pool) external;

    /// @notice Claims rewards for either the lender or borrower.
    /// @param pool The address of the pool.
    /// @param isLender True if the lender is claiming, false if the borrower.
    function claimRewards(address pool, bool isLender) external;

    /// @notice Deregisters a pool.
    /// @param pool The address of the pool to deregister.
    function deregisterPool(address pool) external;

    /// @notice Registers borrower
    /// @param pool The address of the pool 
    /// @param borrower The address of the borrower.
    function registerBorrower(address pool, address borrower) external;
}
