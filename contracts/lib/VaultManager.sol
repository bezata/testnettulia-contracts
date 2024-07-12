// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../protocol/TuliaPool.sol";
import "../interfaces/IVaultManager.sol";

/**
 * @title VaultManager
 * @dev Manages interest accrual and distribution for loans.
 * Handles registration, deregistration of vaults, and interest handling for each loan.
 */
contract VaultManager is IVaultManager {
    struct InterestPaymentInfo {
        uint256 totalInterest; // Total accrued interest for the loan period.
        uint256 paymentStartBlock; // The block number when interest payment started.
        uint256 interestPaid; // Amount of interest that has been paid out.
        bool isAccruing; // Flag to indicate if interest is still accruing.
    }

    mapping(address => InterestPaymentInfo) public interestInfo;

    event InterestPaid(
        address indexed pool,
        address indexed to,
        uint256 amount
    );
    event InterestRefunded(
        address indexed pool,
        address indexed to,
        uint256 amount
    );
    event InterestAccrualToggled(address indexed pool, bool status);
    event InterestDeposited(address indexed pool, uint256 amount);

    /**
     * @notice Registers a vault for a pool and begins interest accrual if the loan is active.
     * @dev Sets up the interest accrual infrastructure when a new loan is activated.
     * @param pool The address of the loan pool.
     */
    function registerPoolVault(address pool) external override {
        require(
            TuliaPool(pool).getLoanState() == TuliaPool.LoanState.ACTIVE,
            "Loan must be active to register"
        );
        require(pool != address(0), "Invalid pool address");
        interestInfo[pool] = InterestPaymentInfo({
            totalInterest: TuliaPool(pool).calculateInterest(),
            paymentStartBlock: block.timestamp,
            interestPaid: 0,
            isAccruing: true
        });
        emit InterestAccrualToggled(pool, true);
    }

    /**
     * @notice Handles the default scenario by securing the collateral and distributing remaining interest.
     * @param pool The address of the loan pool which has defaulted.
     * @param lender The address of the lender.
     */
    function handleDefault(address pool, address lender) external {
        require(pool != address(0), "Invalid pool address");
        require(
            TuliaPool(pool).getLoanState() == TuliaPool.LoanState.DEFAULTED,
            "Loan must be defaulted to handle default"
        );
        require(lender == TuliaPool(pool).getLender(), "Wrong Lender Address");
        InterestPaymentInfo storage info = interestInfo[pool];
        IERC20 repaymentToken = IERC20(TuliaPool(pool).getRepaymentToken());

        // Calculate the total accrued interest
        uint256 accruedInterest = calculateClaimableInterest(pool);

        // Secure the remaining accrued interest for the lender
        if (accruedInterest > info.interestPaid) {
            uint256 remainingInterest = accruedInterest - info.interestPaid;
            if (repaymentToken.balanceOf(address(this)) >= remainingInterest) {
                repaymentToken.transfer(lender, remainingInterest);
                emit InterestPaid(pool, lender, remainingInterest);
            }
        }
        info.isAccruing = false;

        emit InterestAccrualToggled(pool, false);
    }

    /**
     * @notice Deregisters a vault when a loan is closed and stops interest accrual.
     * @param pool The address of the loan pool.
     */
    function deregisterVault(address pool) external override {
        require(pool != address(0), "Invalid pool address");
        require(
            interestInfo[pool].isAccruing,
            "Pool is not active or already deregistered"
        );

        interestInfo[pool].isAccruing = false;
        delete interestInfo[pool];

        emit InterestAccrualToggled(pool, false);
    }

    /// @notice Calculates the claimable interest for a pool at the current block.
    /// @dev Calculates based on the blocks elapsed since the start of interest accrual.
    /// @param pool The address of the loan pool.
    /// @return The amount of interest that can be claimed.
    function calculateClaimableInterest(address pool)
        public
        view
        override
        returns (uint256)
    {
        require(pool != address(0), "Invalid pool address");
        InterestPaymentInfo storage info = interestInfo[pool];
        if (!info.isAccruing) {
            return 0;
        }

        uint256 totalDuration = TuliaPool(pool).getRepaymentPeriod();
        require(totalDuration > 0, "Repayment period must be greater than zero");

        uint256 elapsedTime = block.timestamp - info.paymentStartBlock;
        if (elapsedTime > totalDuration) {
            elapsedTime = totalDuration;
        }

        uint256 accruedInterest = (info.totalInterest * elapsedTime) / totalDuration;
        return
            accruedInterest > info.interestPaid
                ? accruedInterest - info.interestPaid
                : 0;
    }

    /// @notice Distributes accrued interest to the lender if the loan is active.
    /// @param pool The address of the loan pool.
    /// @param to The recipient of the interest payment.
    function distributeInterest(address pool, address to) external override {
        IERC20 repaymentToken = IERC20(TuliaPool(pool).getRepaymentToken());
        require(TuliaPool(pool).getLender() == msg.sender, "Only Lender can request interest");
        uint256 payableInterest = calculateClaimableInterest(pool);
        require(pool != address(0) && to != address(0), "Invalid address");
        require(
            TuliaPool(pool).getLoanState() == TuliaPool.LoanState.ACTIVE,
            "Interest can only be distributed when loan is active"
        );
        require(
            repaymentToken.balanceOf(address(this)) >= payableInterest,
            "Insufficient funds"
        );

        if (payableInterest > 0) {
            repaymentToken.transfer(to, payableInterest);

            InterestPaymentInfo storage info = interestInfo[pool];
            info.interestPaid += payableInterest;
            emit InterestPaid(pool, to, payableInterest);
        }
    }

    /// @notice Refunds all remaining tokens to the borrower, ensuring any unclaimed interest is left for the lender.
    /// @param pool The address of the loan pool.
    /// @param borrower The recipient of the remaining funds.
    function refundRemainingInterest(address pool, address borrower)
        external
        override
    {
        InterestPaymentInfo storage info = interestInfo[pool];
        IERC20 repaymentToken = IERC20(TuliaPool(pool).getRepaymentToken());

        uint256 totalDuration = TuliaPool(pool).getRepaymentPeriod();
        uint256 elapsedTime = block.timestamp - info.paymentStartBlock;

        uint256 accruedInterest = (info.totalInterest * elapsedTime) / totalDuration;
        if (accruedInterest > info.interestPaid) {
            accruedInterest -= info.interestPaid;
        } else {
            accruedInterest = 0;
        }

        uint256 remainingBalance = repaymentToken.balanceOf(address(this)) -
            accruedInterest;

        if (remainingBalance > 0) {
            repaymentToken.transfer(borrower, remainingBalance);
            emit InterestRefunded(pool, borrower, remainingBalance);
        }
    }
}
