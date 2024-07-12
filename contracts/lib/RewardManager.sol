// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../protocol/TuliaPool.sol";
import "../interfaces/IRewardManager.sol";
import "../interfaces/IAdvancedAPYManager.sol";
import "../tokens/MockTokenCreator.sol";

/**
 * @title RewardManager
 * @dev Manages dynamic rewards across all active loan pools, incorporating APY adjustments.
 * This contract handles the allocation, accrual, and claiming of rewards based on loan activities and states.
 */
contract RewardManager is IRewardManager, ReentrancyGuard {
    struct RewardDetails {
        IERC20 rewardToken; // The token used for rewards.
        uint256 rewardsAccrued; // Total accrued rewards.
        uint256 lastRewardBlock; // Last block number when rewards were calculated.
        uint256 rewardRate; // Dynamic reward rate based on APY.
        uint256 totalInterestRewards; // Total interest rewards accrued.
        uint256 lenderClaimedRewards; // Amount of rewards claimed by the lender.
        uint256 borrowerClaimedRewards; // Amount of rewards claimed by the borrower.
        address borrower; // The borrower of the loan.
        bool isAccruing; // Flag to indicate if the pool is accruing rewards.
    }

    IAdvancedAPYManager public apyManager; // Reference to the APY Manager for reward calculations.
    mapping(address => RewardDetails) public rewardDetails; // Mapping from pool address to reward details.

    event PoolRegistered(address indexed pool);
    event PoolDeregistered(address indexed pool);
    event BorrowerRegistered(address indexed pool, address indexed borrower);
    event RewardAccrued(address indexed pool, uint256 reward);
    event RewardClaimed(address indexed pool, address claimant, uint256 reward);

    /**
     * @notice Initializes the RewardManager contract with a reference to the APYManager for reward calculations.
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
     */
    function registerPool(
        address pool,
        address rewardToken
    ) external override {
        require(
            pool != address(0) && rewardToken != address(0),
            "Invalid addresses"
        );
        rewardDetails[pool] = RewardDetails({
            rewardToken: IERC20(rewardToken),
            rewardsAccrued: 0,
            lastRewardBlock: block.number,
            rewardRate: 0,
            totalInterestRewards: 0,
            lenderClaimedRewards: 0,
            borrowerClaimedRewards: 0,
            borrower: address(0),
            isAccruing: true // Start accruing rewards immediately upon pool registration
        });
        emit PoolRegistered(pool);
    }

    /**
     * @notice Registers the borrower for a specific pool and updates reward allocation.
     * @param pool The address of the pool.
     * @param borrower The address of the borrower.
     */
    function registerBorrower(address pool, address borrower)
        external
        override
    {
        require(
            pool != address(0) && borrower != address(0),
            "Invalid addresses"
        );
        RewardDetails storage details = rewardDetails[pool];
        require(details.borrower == address(0), "Borrower already registered");

        // Ensure the rewards accrued so far are updated to reflect the new state
        accrueRewards(pool);

        details.borrower = borrower;

        emit BorrowerRegistered(pool, borrower);
    }

    /**
     * @notice Claims rewards for either the lender or borrower from a specific pool.
     * @param pool The address of the TuliaPool.
     * @param isLender True if the lender is claiming, false if the borrower.
     */
    function claimRewards(address pool, bool isLender)
        external
        override
        nonReentrant
    {
        accrueRewards(pool);

        RewardDetails storage details = rewardDetails[pool];
        TuliaPool poolContract = TuliaPool(pool);
        address claimant = isLender
            ? poolContract.getLender()
            : details.borrower;

        require(msg.sender == claimant, "Not authorized to claim rewards");

        uint256 claimableRewards = calculateClaimableRewards(pool, isLender);
        require(claimableRewards > 0, "No rewards to claim");

        if (isLender) {
            details.lenderClaimedRewards += claimableRewards;
        } else {
            details.borrowerClaimedRewards += claimableRewards;
        }

        MockTokenCreator(address(details.rewardToken)).mint(
            claimant,
            claimableRewards
        );
        emit RewardClaimed(pool, claimant, claimableRewards);
    }

    /**
     * @notice Calculates claimable rewards for either the lender or the borrower based on their share of the interest rewards.
     * @param pool The address of the pool.
     * @param isLender True if calculating for the lender, false for the borrower.
     * @return uint256 The amount of rewards that can be claimed.
     */
    function calculateClaimableRewards(address pool, bool isLender)
        public
        view
        returns (uint256)
    {
        RewardDetails storage details = rewardDetails[pool];
        return _calculateClaimableRewards(details, isLender, pool);
    }

    /**
     * @notice Internal function to calculate claimable rewards.
     * @param details The reward details for the pool.
     * @param isLender True if calculating for the lender, false for the borrower.
     * @param pool The address of the pool.
     * @return uint256 The amount of rewards that can be claimed.
     */
    function _calculateClaimableRewards(
        RewardDetails storage details,
        bool isLender,
        address pool
    ) internal view returns (uint256) {
        if (!details.isAccruing) {
            return 0; // Return 0 if the pool is not accruing rewards
        }

        // Calculate rewards dynamically based on the number of blocks passed since the last update
        TuliaPool poolContract = TuliaPool(pool);
        uint256 loanAmount = poolContract.getLoanAmount();
        uint256 loanDuration = poolContract.getRepaymentPeriod();

        uint256 currentAPY = apyManager.calculateAPY(loanAmount, loanDuration);
        uint256 rewardRate = (currentAPY * loanAmount) / 10000 / loanDuration; // Calculate reward rate per second

        uint256 blocksPassed = block.number - details.lastRewardBlock;
        uint256 reward = blocksPassed * rewardRate;

        uint256 totalRewards = details.rewardsAccrued + reward;

        // Calculate claimable rewards
        uint256 lenderTotalRewards;
        uint256 borrowerTotalRewards;

        if (details.borrower == address(0)) {
            // Loan is not activated, all rewards go to the lender
            lenderTotalRewards = totalRewards;
            borrowerTotalRewards = 0;
        } else {
            // Loan is activated, split rewards equally between lender and borrower
            lenderTotalRewards = totalRewards / 2;
            borrowerTotalRewards = totalRewards / 2;
        }

        if (isLender) {
            return lenderTotalRewards - details.lenderClaimedRewards;
        } else {
            return borrowerTotalRewards - details.borrowerClaimedRewards;
        }
    }

    /**
     * @notice Accrues rewards for a specific pool based on the current APY and block difference.
     * @param pool The address of the pool for which to accrue rewards.
     */
    function accrueRewards(address pool) public override {
        RewardDetails storage details = rewardDetails[pool];
        TuliaPool poolContract = TuliaPool(pool);

        if (!details.isAccruing) {
            return; // Exit if the pool is not accruing rewards
        }

        uint256 loanAmount = poolContract.getLoanAmount();
        uint256 loanDuration = poolContract.getRepaymentPeriod();

        uint256 currentAPY = apyManager.calculateAPY(loanAmount, loanDuration);
        uint256 rewardRate = (currentAPY * loanAmount) / 10000 / loanDuration; // Calculate reward rate per second

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
    function deregisterPool(address pool) external override {
        require(pool != address(0), "Invalid pool address");
        delete rewardDetails[pool];
        emit PoolDeregistered(pool);
    }

    function getRewardDetails(address pool)
        external
        view
        returns (RewardDetails memory)
    {
        return rewardDetails[pool];
    }
}
