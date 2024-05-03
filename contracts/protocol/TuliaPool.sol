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
contract TuliaPool is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IPermit2 public permit2;
    IPoolOrganizer public poolOrganizer;
    IVaultManager public vaultManager;
    IRewardManager public rewardManager;

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

    /// @notice Activates a loan by transferring collateral from the borrower to the vault.
    /// @param borrower The address of the borrower activating the loan.
    /// @param collateralAmount The amount of collateral to be deposited.
    function activateLoan(address borrower, uint256 collateralAmount)
        external
        nonReentrant
    {
        require(state == LoanState.PENDING, "Loan not ready to activate");
        require(borrower != address(0), "Invalid borrower address");
        require(borrower != loanDetails.lender, "Lender cannot be borrower");

        uint256 requiredCollateral = calculateRequiredCollateral();
        require(
            collateralAmount >= requiredCollateral,
            "Insufficient collateral"
        );

        // Increase allowance for the collateral token to the vault
        loanDetails.loanToken.forceApprove(
            address(loanDetails.collateralVault),
            collateralAmount
        );

        // Deposit collateral into the vault and log the activation
        loanDetails.collateralVault.deposit(collateralAmount, borrower);
        loanDetails.borrower = borrower;
        // Transfer tokens
        loanDetails.loanToken.safeTransferFrom(
            address(this),
            borrower,
            loanDetails.loanAmount
        );
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

    function repay(uint256 amount) external nonReentrant {
        require(state == LoanState.ACTIVE, "Loan must be active");
        uint256 totalRepayment = loanDetails.loanAmount + calculateInterest();

        require(amount >= totalRepayment, "Insufficient amount for repayment");

        // Transfer repayment to the lender
        loanDetails.repaymentToken.safeTransferFrom(
            msg.sender,
            loanDetails.lender,
            totalRepayment
        );

        // Calculate any excess payment to be returned to the borrower
        uint256 excessPayment = amount > totalRepayment
            ? amount - totalRepayment
            : 0;

        if (excessPayment > 0) {
            loanDetails.repaymentToken.safeTransfer(msg.sender, excessPayment);
        }

        // Withdraw collateral back to the borrower
        uint256 collateralToReturn = loanDetails.collateralVault.balanceOf(
            address(this)
        );
        loanDetails.collateralVault.withdraw(
            collateralToReturn,
            loanDetails.borrower,
            address(this)
        );

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

    function calculateInterest() public view returns (uint256) {
        uint256 duration = block.number - loanDetails.startBlock;
        return
            loanDetails.interestModel.calculateInterest(
                loanDetails.loanAmount,
                loanDetails.interestRate,
                duration
            );
    }

    function calculateRequiredCollateral() public view returns (uint256) {
        uint256 interestForFullTerm = calculateInterest();
        return loanDetails.loanAmount + interestForFullTerm;
    }

    function getFundedBlock() public view returns (uint256) {
        return loanDetails.fundedBlock;
    }

    function getLoanState() public view returns (LoanState) {
        return state;
    }

    function getLoanAmount() public view returns (uint256) {
        return loanDetails.loanAmount;
    }

    function getInterestRate() public view returns (uint256) {
        return loanDetails.interestRate;
    }

    function getCollateralAmount(address user) public view returns (uint256) {
        return loanDetails.collateralVault.balanceOf(user); 
    }

    function getRepaymentPeriod() public view returns (uint256) {
        return loanDetails.repaymentPeriod;
    }
}
