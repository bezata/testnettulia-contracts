// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../protocol/TuliaPool.sol";
import "../interfaces/IRewardManager.sol";
import "../interfaces/IAdvancedAPYManager.sol";

/**
 * @title RewardManager
 * @dev Manages dynamic rewards across all active loan pools, incorporating APY adjustments.
 * This contract handles the allocation, accrual, and claiming of rewards based on loan activities and states.
 */
contract RewardManager is IRewardManager, ReentrancyGuard {
    struct RewardDetails {
        IERC20 rewardToken;
        uint256 rewardsAccrued;
        uint256 lastRewardBlock; // Last block number when rewards were calculated
        uint256 rewardRate; // Dynamic reward rate based on APY
        uint256 totalInterestRewards; // Total interest rewards accrued
        uint256 lenderClaimedRewards; // Amount of rewards already claimed by the lender
        uint256 borrowerClaimedRewards; // Amount of rewards already claimed by the borrower
    }

    IAdvancedAPYManager public apyManager;
    mapping(address => RewardDetails) public rewardDetails;

    event PoolRegistered(address indexed pool);
    event PoolDeregistered(address indexed pool);
    event RewardAccrued(address indexed pool, uint256 reward);
    event RewardClaimed(address indexed pool, address claimant, uint256 reward);

    /**
     * @notice Initializes the RewardManager contract with a reference to the APYManager for reward calculations.
     * @param _apyManager The address of the APYManager contract.
     */
    constructor(address _apyManager) {
        apyManager = IAdvancedAPYManager(_apyManager);
    }

    /**
     * @notice Registers a pool to start accruing rewards, initializing the reward mechanism.
     * @param pool The address of the pool to register.
     * @param rewardToken The ERC20 token used as the reward token.
     */
    function registerPool(address pool, address rewardToken) public override {
        require(pool != address(0) && rewardToken != address(0), "Invalid addresses");
        rewardDetails[pool] = RewardDetails({
            rewardToken: IERC20(rewardToken),
            rewardsAccrued: 0,
            lastRewardBlock: block.number,
            rewardRate: 0,  // This will be set during the first accrual
            totalInterestRewards: 0,
            lenderClaimedRewards: 0,
            borrowerClaimedRewards: 0
        });
        emit PoolRegistered(pool);
    }

    /**
     * @notice Claims rewards for either the lender or borrower from a specific pool.
     * @param pool The address of the TuliaPool.
     * @param isLender True if the lender is claiming, false if the borrower.
     */
    function claimRewards(address pool, bool isLender) public override nonReentrant {
        RewardDetails storage details = rewardDetails[pool];
        TuliaPool poolContract = TuliaPool(pool);
        address claimant = isLender ? poolContract.getLender() : poolContract.getBorrower();

        require(msg.sender == claimant, "Not authorized to claim rewards");
        uint256 claimableRewards = calculateClaimableRewards(details, isLender);
        require(claimableRewards > 0, "No rewards to claim");

        if (isLender) {
            details.lenderClaimedRewards += claimableRewards;
        } else {
            details.borrowerClaimedRewards += claimableRewards;
        }

        details.rewardToken.transfer(claimant, claimableRewards);
        emit RewardClaimed(pool, claimant, claimableRewards);
    }

    /**
     * @notice Calculates claimable rewards for either the lender or the borrower based on their share of the interest rewards.
     * @param details The reward details for the pool.
     * @param isLender True if calculating for the lender, false for the borrower.
     * @return uint256 The amount of rewards that can be claimed.
     */
    function calculateClaimableRewards(RewardDetails storage details, bool isLender) internal view returns (uint256) {
        uint256 totalInterest = details.totalInterestRewards / 2; // Split evenly between borrower and lender
        if (isLender) {
            return totalInterest - details.lenderClaimedRewards;
        } else {
            uint256 nonInterestRewards = details.rewardsAccrued - details.totalInterestRewards;
            uint256 totalBorrowerRewards = nonInterestRewards + totalInterest;
            return totalBorrowerRewards - details.borrowerClaimedRewards;
        }
    }
    
    /// @param pool The address of the pool for which to accrue rewards.
    function accrueRewards(address pool) public override {
        RewardDetails storage details = rewardDetails[pool];
        TuliaPool poolContract = TuliaPool(pool);
        uint256 loanAmount = poolContract.getLoanAmount();
        uint256 loanDuration = poolContract.getRepaymentPeriod();

        uint256 currentAPY = apyManager.calculateAPY(loanAmount, loanDuration);
        uint256 rewardRate = currentAPY / 10000; // Convert basis points to a percentage for calculations

        uint256 blocksPassed = block.number - details.lastRewardBlock;
        uint256 reward = blocksPassed * rewardRate;

        details.rewardsAccrued += reward;
        details.lastRewardBlock = block.number;
        details.rewardRate = rewardRate; // Update the reward rate based on current APY

        emit RewardAccrued(pool, reward);
    }
    /**
     * @notice Deregisters a pool, stopping it from accruing further rewards.
     * @param pool The address of the pool to deregister.
     */
    function deregisterPool(address pool) public override {
        require(pool != address(0), "Invalid pool address");
        delete rewardDetails[pool];
        emit PoolDeregistered(pool);
    }
}
