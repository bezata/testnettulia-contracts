// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TuliaVault.sol";
import "../interfaces/IInterestModel.sol";
import "../interfaces/IPermit2.sol";
import "../interfaces/IPoolOrganizer.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IRewardManager.sol";

/// @title TuliaPool
/// @dev Manages the lifecycle of loans including creation, funding, repayment, and defaults.
/// This contract handles all operations regarding lending processes, with integrated safety checks and state management.
contract TuliaPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IPermit2 public permit2;
    IPoolOrganizer public poolOrganizer;
    IVaultManager public vaultManager;
    IRewardManager public rewardManager;

    /// @dev Struct to store all relevant loan details
    struct LoanDetails {
        address lender;
        IERC20 loanToken;
        IERC20 repaymentToken;
        TuliaVault collateralVault;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 repaymentPeriod;
        IInterestModel interestModel;
        address borrower;
        uint256 startBlock;
        uint256 fundedBlock;
    }

    /// @dev Enum to manage the loan's current state
    enum LoanState {
        CREATED,
        PENDING,
        ACTIVE,
        CLOSED,
        DEFAULTED
    }

    LoanState public state;
    LoanDetails public loanDetails;

    event LoanOfferCreated(
        address indexed lender,
        uint256 loanAmount,
        address loanToken,
        address repaymentToken
    );
    event LoanActivated(address indexed borrower, uint256 collateralAmount);
    event LoanFunded(uint256 loanAmount);
    event RepaymentMade(uint256 amountRepaid);
    event LoanClosed();
    event LoanDefaulted(address indexed borrower);

    /// @notice Creates a new loan offer
    /// @param lender The address of the lender
    /// @param loanTokenAddress The address of the token to be loaned
    /// @param repaymentTokenAddress The token address in which repayments are to be made
    /// @param collateralVaultAddress The address of the vault where collateral will be stored
    /// @param loanAmount The amount of the loan
    /// @param interestRate The interest rate
    /// @param repaymentPeriod The duration over which the loan must be repaid
    /// @param interestModel The contract that calculates interest
    /// @param _permit2 The Permit2 contract for ERC20 token operations
    /// @param poolOrganizerAddress The Pool Organizer contract for managing pool registrations
    constructor(
        address lender,
        address loanTokenAddress,
        address repaymentTokenAddress,
        address collateralVaultAddress,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 repaymentPeriod,
        IInterestModel interestModel,
        IPermit2 _permit2,
        address poolOrganizerAddress,
        address vaultManagerAddress,
        address rewardManagerAddress
    ) {
        require(
            lender != address(0) &&
                loanTokenAddress != address(0) &&
                collateralVaultAddress != address(0) &&
                repaymentTokenAddress != address(0),
            "Invalid input addresses"
        );
        permit2 = _permit2;
        poolOrganizer = IPoolOrganizer(poolOrganizerAddress);
        vaultManager = IVaultManager(vaultManagerAddress);
        rewardManager = IRewardManager(rewardManagerAddress);
        loanDetails = LoanDetails({
            lender: lender,
            loanToken: IERC20(loanTokenAddress),
            repaymentToken: IERC20(repaymentTokenAddress),
            collateralVault: TuliaVault(collateralVaultAddress),
            loanAmount: loanAmount,
            interestRate: interestRate,
            repaymentPeriod: repaymentPeriod,
            interestModel: interestModel,
            borrower: address(0),
            startBlock: block.number,
            fundedBlock: 0
        });
        state = LoanState.CREATED;
        emit LoanOfferCreated(
            lender,
            loanAmount,
            loanTokenAddress,
            repaymentTokenAddress
        );
    }

    /// @notice Activates a loan by transferring collateral from the borrower to the vault and transferring the loan amount to the borrower.
    function activateLoan() external nonReentrant {
        address borrower = msg.sender;
        uint256 collateralAmount = calculateRequiredCollateral();

        require(state == LoanState.PENDING, "Loan not ready to activate");
        require(borrower != address(0), "Invalid borrower address");
        require(borrower != loanDetails.lender, "Lender cannot be borrower");
        require(
            collateralAmount <=
                IERC20(loanDetails.collateralVault.asset()).allowance(
                    borrower,
                    address(this)
                ),
            "Insufficient collateral allowance"
        );
        require(
            loanDetails.loanToken.allowance(borrower, address(this)) >=
                loanDetails.loanAmount,
            "Insufficient loan allowance"
        );

        loanDetails.loanToken.safeIncreaseAllowance(
            address(loanDetails.collateralVault),
            collateralAmount
        );
        loanDetails.collateralVault.deposit(collateralAmount, borrower);
        loanDetails.loanToken.safeTransfer(
            borrower,
            loanDetails.loanToken.balanceOf(address(this))
        );

        loanDetails.borrower = borrower;
        state = LoanState.ACTIVE;

        emit LoanActivated(borrower, collateralAmount);
    }

    function fundLoan() external nonReentrant {
        require(state == LoanState.CREATED, "Loan not in creatable state");
        loanDetails.loanToken.safeTransferFrom(
            loanDetails.lender,
            address(this),
            loanDetails.loanAmount
        );
        loanDetails.fundedBlock = block.number;
        state = LoanState.PENDING;
        emit LoanFunded(loanDetails.loanAmount);
    }

    /**
     * @notice Checks if the loan has defaulted based on repayment conditions and handles the default by claiming the collateral.
     */
    function checkAndHandleDefault() public {
        require(state == LoanState.ACTIVE, "Loan is not active");
        require(
            block.number >=
                loanDetails.startBlock + loanDetails.repaymentPeriod,
            "Repayment period has not yet ended"
        );

        uint256 totalRepayment = loanDetails.loanAmount + calculateInterest();
        uint256 currentBalance = loanDetails.repaymentToken.balanceOf(
            loanDetails.lender
        );

        if (currentBalance < totalRepayment) {
            state = LoanState.DEFAULTED;

            // Calculate the shares of the vault that correspond to the entire balance the pool contract holds
            uint256 sharesToRedeem = loanDetails
                .collateralVault
                .convertToShares(
                    loanDetails.collateralVault.balanceOf(address(this))
                );

            // Redeem the shares for the underlying collateral to the lender
            loanDetails.collateralVault.redeem(
                sharesToRedeem,
                loanDetails.lender, // Sending the collateral directly to the lender
                address(this)
            );

            emit LoanDefaulted(loanDetails.borrower);
            _closeLoan();
        }
    }

    /**
     * @notice Repays the loan and releases collateral back to the borrower.
     */
    function repay() external nonReentrant {
        require(state == LoanState.ACTIVE, "Loan must be active");

        uint256 totalRepayment = loanDetails.loanAmount + calculateInterest();

        // Ensuring the borrower has enough tokens and has allowed the contract to move them
        require(
            loanDetails.repaymentToken.allowance(msg.sender, address(this)) >=
                totalRepayment,
            "Insufficient token allowance for repayment"
        );
        require(
            loanDetails.repaymentToken.balanceOf(msg.sender) >= totalRepayment,
            "Insufficient token balance for repayment"
        );

        // Transfer the repayment amount from the borrower to the lender
        loanDetails.repaymentToken.safeTransferFrom(
            msg.sender,
            loanDetails.lender,
            totalRepayment
        );

        // Handling collateral withdrawal from the ERC4626 vault
        uint256 sharesToRedeem = loanDetails.collateralVault.convertToShares(
            loanDetails.collateralVault.balanceOf(address(this))
        );
        loanDetails.collateralVault.redeem(
            sharesToRedeem,
            msg.sender, // Sending the collateral directly back to the borrower
            address(this)
        );

        // Updating the loan state to closed
        _closeLoan();
        emit RepaymentMade(totalRepayment);
    }

    function _closeLoan() internal {
        state = LoanState.CLOSED;
        poolOrganizer.deregisterPool(address(this));
        vaultManager.deregisterVault(address(this));
        rewardManager.deregisterPool(address(this));
        emit LoanClosed();
    }

    /// @notice Calculates the accrued interest based on the loan details.
    function calculateInterest() public view returns (uint256) {
        uint256 duration = block.number - loanDetails.startBlock;
        return
            loanDetails.interestModel.calculateInterest(
                loanDetails.loanAmount,
                loanDetails.interestRate,
                duration
            );
    }

    /// @notice Calculates the required collateral based on the interest and principal.
    function calculateRequiredCollateral() public view returns (uint256) {
        uint256 interestForFullTerm = calculateInterest();
        return loanDetails.loanAmount + interestForFullTerm;
    }

    /// @notice Provides the block number when the loan was funded.
    function getFundedBlock() public view returns (uint256) {
        return loanDetails.fundedBlock;
    }

    /// @notice Retrieves the current state of the loan.
    function getLoanState() public view returns (LoanState) {
        return state;
    }

    /// @notice Retrieves the total loan amount.
    function getLoanAmount() public view returns (uint256) {
        return loanDetails.loanAmount;
    }

    /// @notice Retrieves the interest rate of the loan.
    function getInterestRate() public view returns (uint256) {
        return loanDetails.interestRate;
    }

    /// @notice Retrieves the amount of collateral stored for a specific user.
    function getCollateralAmount(address user) public view returns (uint256) {
        return loanDetails.collateralVault.balanceOf(user);
    }

    /// @notice Retrieves the repayment period of the loan.
    function getRepaymentPeriod() public view returns (uint256) {
        return loanDetails.repaymentPeriod;
    }
}
