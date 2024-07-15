// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IAdvancedAPYManager.sol";
import "../interfaces/IFlashPoolRewardManager.sol";
import "../tokens/MockTokenCreator.sol";

/**
 * @title FlashPoolRewardManager
 * @dev Manages dynamic rewards specifically for flash loan pools, incorporating APY adjustments.
 * This contract handles the allocation, accrual, and claiming of rewards based on loan activities.
 */
contract FlashPoolRewardManager is ReentrancyGuard, IFlashPoolRewardManager {
    struct RewardDetails {
        IERC20 rewardToken; // The token used for rewards.
        uint256 rewardsAccrued; // Total accrued rewards.
        uint256 lastRewardBlock; // Last block number when rewards were calculated.
        uint256 rewardRate; // Dynamic reward rate based on APY.
        uint256 lenderClaimedRewards; // Amount of rewards claimed by the lender.
        bool isAccruing; // Flag to indicate if the pool is accruing rewards.
    }

    IAdvancedAPYManager public apyManager; // Reference to the APY Manager for reward calculations.
    mapping(address => RewardDetails) public rewardDetails; // Mapping from pool address to reward details.

    event PoolRegistered(address indexed pool);
    event PoolDeregistered(address indexed pool);
    event RewardAccrued(address indexed pool, uint256 reward);
    event RewardClaimed(address indexed pool, address claimant, uint256 reward);

    /**
     * @notice Initializes the FlashPoolRewardManager contract with a reference to the APYManager for reward calculations.
     * @param _apyManager The address of the APYManager contract.
     */
    constructor(address _apyManager) {
        require(_apyManager != address(0), "Invalid APY manager address");
        apyManager = IAdvancedAPYManager(_apyManager);
    }

    /**
     * @notice Registers a pool to start accruing rewards, initializing the reward mechanism.
     * @param pool The address of the pool to register.
     * @param rewardToken The ERC20 token used as the reward token.
     " @param loanAmount The amount of the loan used for reward calculations."
     */
      function registerPool(address pool, address rewardToken, uint256 loanAmount) external override returns (bool) {
        require(pool != address(0) && rewardToken != address(0), "Invalid addresses");
        rewardDetails[pool] = RewardDetails({
            rewardToken: IERC20(rewardToken),
            rewardsAccrued: 0,
            lastRewardBlock: block.number,
            rewardRate: apyManager.calculateAPY(loanAmount, 30 days),
            lenderClaimedRewards: 0,
            isAccruing: true // Start accruing rewards immediately upon pool registration
        });
        emit PoolRegistered(pool);
        return true;
    }


    /**
     * @notice Claims rewards for the lender from a specific pool.
     * @param pool The address of the flash pool.
     */
    function claimRewards(address pool) external override nonReentrant {
        accrueRewards(pool);

        RewardDetails storage details = rewardDetails[pool];
        uint256 claimableRewards = details.rewardsAccrued - details.lenderClaimedRewards;

        require(claimableRewards > 0, "No rewards to claim");

        details.lenderClaimedRewards += claimableRewards;

        MockTokenCreator(address(details.rewardToken)).mint(
            msg.sender,
            claimableRewards
        );
        emit RewardClaimed(pool, msg.sender, claimableRewards);
    }

    /**
     * @notice Calculates claimable interest for the lender.
     * @param pool The address of the pool.
     * @return uint256 The amount of interest that can be claimed.
     */
    function calculateClaimableInterest(address pool)
        public
        view
        override
        returns (uint256)
    {
        RewardDetails storage details = rewardDetails[pool];

        uint256 blocksPassed = block.number - details.lastRewardBlock;
        uint256 reward = blocksPassed * details.rewardRate;
        uint256 totalRewards = details.rewardsAccrued + reward;

        return totalRewards - details.lenderClaimedRewards;
    }

    /**
     * @notice Accrues rewards for a specific pool based on the current APY and block difference.
     * @param pool The address of the pool for which to accrue rewards.
     */
    function accrueRewards(address pool) public override {
        RewardDetails storage details = rewardDetails[pool];

        if (!details.isAccruing) {
            return; // Exit if the pool is not accruing rewards
        }

        uint256 blocksPassed = block.number - details.lastRewardBlock;
        uint256 reward = blocksPassed * details.rewardRate;

        details.rewardsAccrued += reward;
        details.lastRewardBlock = block.number;

        emit RewardAccrued(pool, reward);
    }

    /**
     * @notice Deregisters a pool, stopping it from accruing further rewards.
     * @param pool The address of the pool to deregister.
     */
    function deregisterPool(address pool) external override {
        require(pool != address(0), "Invalid pool address");
        delete rewardDetails[pool];
        emit PoolDeregistered(pool);
    }

    /**
     * @notice Returns the reward details for a specific pool.
     * @param pool The address of the pool.
     * @return rewardToken The token used for rewards.
     * @return rewardsAccrued Total accrued rewards.
     * @return lastRewardBlock Last block number when rewards were calculated.
     * @return rewardRate Dynamic reward rate based on APY.
     * @return lenderClaimedRewards Amount of rewards claimed by the lender.
     * @return isAccruing Flag to indicate if the pool is accruing rewards.
     */
    function getRewardDetails(address pool)
        external
        view
        override
        returns (
            address rewardToken,
            uint256 rewardsAccrued,
            uint256 lastRewardBlock,
            uint256 rewardRate,
            uint256 lenderClaimedRewards,
            bool isAccruing
        )
    {
        RewardDetails storage details = rewardDetails[pool];
        return (
            address(details.rewardToken),
            details.rewardsAccrued,
            details.lastRewardBlock,
            details.rewardRate,
            details.lenderClaimedRewards,
            details.isAccruing
        );
    }
}
