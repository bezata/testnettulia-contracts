// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../protocol/TuliaPool.sol"; 
import "../interfaces/IRewardManager.sol";

/// @title RewardManager
/// @dev Manages rewards across all active loan pools, allowing for dynamic reward tokens.
contract RewardManager is IRewardManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Mapping from pool address to reward details
    struct RewardDetails {
        IERC20 rewardToken;
        uint256 rewardsAccrued;
    }
    
    mapping(address => RewardDetails) public rewardDetails;
    uint256 public constant REWARD_RATE = 100; // Example rate per block

    event RewardAccrued(address indexed pool, uint256 reward);
    event RewardTokenSet(address indexed pool, address rewardToken);
    event RewardClaimed(address indexed pool, uint256 reward);
    event PoolDeregistered(address pool);

    /// @notice Sets the reward token for a specific pool.
    /// @param pool The address of the TuliaPool.
    /// @param rewardToken The reward token for this pool.
    function setRewardToken(address pool, address rewardToken) public {
        require(pool != address(0), "Pool address cannot be zero");
        require(rewardToken != address(0), "Reward token cannot be zero");
        rewardDetails[pool].rewardToken = IERC20(rewardToken);
        emit RewardTokenSet(pool, rewardToken);
    }

    /// @notice Registers a pool to be eligible for rewards, initializing its reward token.
    /// @param pool The address of the TuliaPool to register.
    /// @param rewardToken The reward token for this pool.
    function registerPool(address pool, address rewardToken) public {
        require(pool != address(0) && rewardToken != address(0), "Invalid addresses");
        rewardDetails[pool] = RewardDetails({
            rewardToken: IERC20(rewardToken),
            rewardsAccrued: 0
        });
    }

    /// @notice Accrues rewards for a pool based on its loan amount since the loan was funded.
    /// @param pool The TuliaPool instance.
    function accrueReward(address pool) public {
        TuliaPool tuliaPool = TuliaPool(pool);
        require(tuliaPool.getLoanState() == TuliaPool.LoanState.PENDING, "Pool is not pending");

        uint256 reward = calculateReward(tuliaPool);
        rewardDetails[pool].rewardsAccrued += reward;

        emit RewardAccrued(pool, reward);
    }

    /// @notice Allows a pool to claim its accrued rewards.
    /// @param pool The TuliaPool instance claiming its rewards.
    function claimRewards(address pool) public nonReentrant {
        RewardDetails storage details = rewardDetails[pool];
        uint256 reward = details.rewardsAccrued;
        require(reward > 0, "No rewards to claim");

        details.rewardsAccrued = 0;
        details.rewardToken.safeTransfer(pool, reward);
        emit RewardClaimed(pool, reward);
    }

    /// @notice Retrieves the total accrued rewards for a specified pool.
    /// @param pool The address of the TuliaPool.
    /// @return reward The total accrued rewards for the pool.
    function getAccruedRewards(address pool) public view returns (uint256 reward) {
        return rewardDetails[pool].rewardsAccrued;
    }

    /// @notice Calculates the reward for a pool since the loan was funded.
    /// @param pool The TuliaPool instance for which to calculate the reward.
    /// @return reward The amount of reward.
    function calculateReward(TuliaPool pool) internal view returns (uint256 reward) {
        uint256 fundedBlock = pool.getFundedBlock();
        if (fundedBlock == 0 || block.number <= fundedBlock) return 0;

        uint256 blocksSinceFunded = block.number - fundedBlock;
        uint256 loanAmount = pool.getLoanAmount();
        reward = loanAmount * blocksSinceFunded * REWARD_RATE / 1e18;
        return reward;
    }

    /// @notice Deregisters a pool when a loan is closed.
    /// @param pool Address of the pool whose vault is to be deregistered.
    function deregisterPool(address pool) public {
        require(pool != address(0), "No pool registered for this address");
        delete rewardDetails[pool];
        emit PoolDeregistered(pool);
    }
}
