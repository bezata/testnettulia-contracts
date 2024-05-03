// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IRewardManager
/// @dev Interface for managing rewards across all active loan pools, allowing for dynamic reward tokens.
interface IRewardManager {
    /// @notice Sets the reward token for a specific pool.
    /// @param pool The address of the TuliaPool.
    /// @param rewardToken The reward token for this pool.
    function setRewardToken(address pool, address rewardToken) external;

    /// @notice Registers a pool to be eligible for rewards, initializing its reward token.
    /// @param pool The address of the TuliaPool to register.
    /// @param rewardToken The reward token for this pool.
    function registerPool(address pool, address rewardToken) external;

    /// @notice Accrues rewards for a pool based on its loan amount since the loan was funded.
    /// @param pool The TuliaPool instance.
    function accrueReward(address pool) external;

    /// @notice Allows a pool to claim its accrued rewards.
    /// @param pool The TuliaPool instance claiming its rewards.
    function claimRewards(address pool) external;

    /// @notice Retrieves the total accrued rewards for a specified pool.
    /// @param pool The address of the TuliaPool.
    /// @return reward The total accrued rewards for the pool.
    function getAccruedRewards(address pool) external view returns (uint256 reward);

    /// @notice Deregisters a pool when a loan is closed.
    /// @param pool Address of the pool whose vault is to be deregistered.
    function deregisterPool(address pool) external;

 
}
