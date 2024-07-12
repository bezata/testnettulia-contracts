// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlashPoolRewardManager {
    /// @notice Registers a pool to start accruing rewards, initializing the reward mechanism.
    /// @param pool The address of the pool to register.
    /// @param rewardToken The ERC20 token used as the reward token.
    function registerPool(address pool, address rewardToken) external;

    /// @notice Claims rewards for the lender from a specific pool.
    /// @param pool The address of the flash pool.
    function claimRewards(address pool) external;

    /// @notice Calculates claimable interest for the lender.
    /// @param pool The address of the pool.
    /// @return uint256 The amount of interest that can be claimed.
    function calculateClaimableInterest(address pool) external view returns (uint256);

    /// @notice Accrues rewards for a specific pool based on the current APY and block difference.
    /// @param pool The address of the pool for which to accrue rewards.
    function accrueRewards(address pool) external;


    /// @notice Deregisters a pool, stopping it from accruing further rewards.
    /// @param pool The address of the pool to deregister.
    function deregisterPool(address pool) external;

    /// @notice Returns the reward details for a specific pool.
    /// @param pool The address of the pool.
    /// @return rewardToken The token used for rewards.
    /// @return rewardsAccrued Total accrued rewards.
    /// @return lastRewardBlock Last block number when rewards were calculated.
    /// @return rewardRate Dynamic reward rate based on APY.
    /// @return lenderClaimedRewards Amount of rewards claimed by the lender.
    /// @return isAccruing Flag to indicate if the pool is accruing rewards.
    function getRewardDetails(address pool) 
        external 
        view 
        returns (
            address rewardToken,
            uint256 rewardsAccrued,
            uint256 lastRewardBlock,
            uint256 rewardRate,
            uint256 lenderClaimedRewards,
            bool isAccruing
        );
}
