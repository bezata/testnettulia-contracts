// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TuliaVault.sol";
import "../interfaces/IInterestModel.sol";
import "../interfaces/IPermit2.sol";
import "../interfaces/IPoolOrganizer.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IRewardManager.sol";

/// @title TuliaPool
/// @notice Manages the lifecycle of loans including creation, funding, repayment, and defaults.
/// @dev This contract handles all operations regarding lending processes with integrated safety checks and state management.
contract TuliaPool is ReentrancyGuard {
    IPermit2 public permit2;
    IPoolOrganizer public poolOrganizer;
    IVaultManager public vaultManager;
    IRewardManager public rewardManager;

    /// @dev Stores all relevant details for a loan.
    struct LoanDetails {
        address lender; // The address providing the loan.
        IERC20 loanToken; // The token being loaned.
        IERC20 repaymentToken; // The token in which repayments must be made.
        TuliaVault collateralVault; // Vault where the collateral is stored.
        uint256 loanAmount; // Amount of the loan.
        uint256 interestRate; // Interest rate for the loan.
        uint256 repaymentPeriod; // Duration for repayment.
        IVaultManager vaultManager;
        IInterestModel interestModel; // Contract calculating the interest.
        address borrower; // Borrower of the loan.
        uint256 startBlock; // Block number when the loan starts.
        uint256 fundedBlock; // Block number when the loan is funded.
    }

    /// @dev Enumerates the possible states of a loan.
    enum LoanState {
        CREATED,
        PENDING,
        ACTIVE,
        DEFAULTED,
        REPAID,
        CLOSED
    }

    LoanState public state; // Current state of the loan.
    LoanDetails public loanDetails; // Instance storing loan details.

    /// @notice Emitted when a loan offer is created.
    event LoanOfferCreated(
        address indexed lender,
        uint256 loanAmount,
        IERC20 loanToken,
        IERC20 repaymentToken
    );

    /// @notice Emitted when a loan is activated.
    event LoanActivated(address indexed borrower, uint256 collateralAmount);

    /// @notice Emitted when a loan is funded.
    event LoanFunded(uint256 loanAmount);

    /// @notice Emitted when a loan is repaid.
    event RepaymentMade(uint256 amountRepaid);

    /// @notice Emitted when a loan is closed.
    event LoanClosed();

    /// @notice Emitted when a loan defaults.
    event LoanDefaulted(address indexed borrower);

    event CollateralFunded(uint256 collateralAmount);

    /// @notice Constructs the TuliaPool loan management contract.
    /// @param lender Address of the lender initiating the loan.
    /// @param loanTokenAddress ERC20 token address to be loaned.
    /// @param repaymentTokenAddress Token address for repayments.
    /// @param collateralVaultAddress Address of the vault where collateral is stored.
    /// @param loanAmount Amount of the loan.
    /// @param interestRate Interest rate of the loan.
    /// @param repaymentPeriodInDays Duration over which the loan must be repaid.
    /// @param interestModel Contract for calculating interest.
    /// @param _permit2 Permit2 contract for ERC20 token operations.
    /// @param poolOrganizerAddress Pool Organizer contract for managing pool registrations.
    constructor(
        address lender,
        IERC20 loanTokenAddress,
        IERC20 repaymentTokenAddress,
        address collateralVaultAddress,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 repaymentPeriodInDays,
        IInterestModel interestModel,
        IPermit2 _permit2,
        address poolOrganizerAddress,
        address vaultManagerAddress,
        address rewardManagerAddress
    ) {
        require(
            lender != address(0) &&
                address(loanTokenAddress) != address(0) &&
                collateralVaultAddress != address(0) &&
                address(repaymentTokenAddress) != address(0),
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
            repaymentPeriod: repaymentPeriodInDays * 1 days,
            vaultManager: IVaultManager(vaultManager),
            interestModel: interestModel,
            borrower: address(0),
            startBlock: block.timestamp,
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
        _checkPreconditions();
        _handleCollateral();
        _disburseLoan();
        _finalizeActivation();
    }

    /// @dev Checks preconditions before activating a loan.
    function _checkPreconditions() internal view {
        require(state == LoanState.PENDING, "Loan not ready to activate");
        address borrower = msg.sender;
        require(borrower != address(0), "Invalid borrower address");
        require(borrower != loanDetails.lender, "Lender cannot be borrower");
        uint256 collateralAmount = calculateRequiredCollateral();
        require(
            loanDetails.repaymentToken.allowance(borrower, address(this)) >=
                collateralAmount,
            "Insufficient collateral allowance"
        );
        require(
            loanDetails.loanToken.allowance(
                loanDetails.lender,
                address(this)
            ) >= loanDetails.loanAmount,
            "Insufficient loan allowance"
        );
    }

    /// @dev Handles the transfer and deposit of collateral.
    function _handleCollateral() internal {
        address borrower = msg.sender;
        uint256 collateralAmount = calculateRequiredCollateral();
        uint256 netCollateral = loanDetails.loanAmount; // Collateral without interest
        uint256 netInterest = calculateInterest(); // Collateral interest amount

        // Ensure the borrower has approved the vault to pull the collateral amount
        loanDetails.repaymentToken.transferFrom(
            borrower,
            address(this),
            collateralAmount
        );
        loanDetails.repaymentToken.transferFrom(
            borrower,
            address(vaultManager),
            netInterest
        );
        loanDetails.repaymentToken.approve(
            address(loanDetails.collateralVault),
            netCollateral
        );
        loanDetails.collateralVault.deposit(netCollateral, borrower);
    }

    /// @dev Transfers the loan amount to the borrower.
    function _disburseLoan() internal {
        address borrower = msg.sender;
        loanDetails.loanToken.transfer(borrower, loanDetails.loanAmount);
    }

    /// @dev Finalizes the activation of the loan, updating state and emitting an event.
    function _finalizeActivation() internal {
        address borrower = msg.sender;
        loanDetails.borrower = borrower;
        loanDetails.startBlock = block.timestamp;
        state = LoanState.ACTIVE;
        uint256 collateralAmount = calculateRequiredCollateral();
        vaultManager.registerPoolVault(address(this));
        emit LoanActivated(borrower, collateralAmount);
    }

    function fundLoan() external nonReentrant {
        require(state == LoanState.CREATED, "Loan not in creatable state");
        loanDetails.loanToken.transferFrom(
            loanDetails.lender,
            address(this),
            loanDetails.loanAmount
        );
        loanDetails.fundedBlock = block.timestamp;
        state = LoanState.PENDING;
        rewardManager.registerPool(address(this), address(loanDetails.loanToken), false);
        poolOrganizer.markPoolAsFunded(address(this));
        emit LoanFunded(loanDetails.loanAmount);
    }

    /**
     * @notice Checks if the loan has defaulted and handles the default.
     */
    function checkAndHandleDefault() public {
        require(state == LoanState.ACTIVE, "Loan is not active");
        if (_isPastDue()) {
            state = LoanState.DEFAULTED;
            _handleDefault();
        }
    }
    function _transitionToClosed() private {
        _closeLoan();
        emit LoanDefaulted(loanDetails.borrower);
    }

    function _isPastDue() private view returns (bool) {
        uint256 dueDate = loanDetails.startBlock + loanDetails.repaymentPeriod;
        return block.timestamp >= dueDate;
    }

    function _handleDefault() private {
        _redeemCollateralToLender();
        vaultManager.handleDefault(address(this), loanDetails.lender);
        _transitionToClosed();
    }

    function _redeemCollateralToLender() private {
        uint256 collateralAmount = loanDetails.collateralVault.balanceOf(
            loanDetails.borrower
        );
        uint256 sharesToRedeem = loanDetails.collateralVault.convertToShares(
            collateralAmount
        );
        loanDetails.collateralVault.redeem(
            sharesToRedeem,
            loanDetails.lender,
            loanDetails.borrower
        );
    }

      /**
     * @notice Checks if the loan has defaulted and handles the default.
     */
    function closeDeal() public {
        require(state == LoanState.ACTIVE, "Loan is not active");
            state = LoanState.DEFAULTED;
            _handleDeal();
            _redeemCollateralToBorrower();
            _transitionToClosed();
        }

    function _handleDeal() private {
        _redeemCollateralToLender();
        vaultManager.handleDefault(address(this), loanDetails.borrower);
        _transitionToClosed();
    }

    function _redeemCollateralToBorrower() private {
        uint256 collateralAmount = loanDetails.collateralVault.balanceOf(
            loanDetails.borrower
        );
        uint256 sharesToRedeem = loanDetails.collateralVault.convertToShares(
            collateralAmount
        );
        loanDetails.collateralVault.redeem(
            sharesToRedeem,
            loanDetails.borrower,
            loanDetails.borrower
        );
    }

    

    /**
     * @notice Handles the repayment process, segregating responsibilities into modular functions.
     */
    function repay() external nonReentrant {
        require(
            loanDetails.borrower == msg.sender,
            "Only the borrower can initiate repayment."
        );
        require(
            state == LoanState.ACTIVE,
            "Loan must be active to proceed with repayment."
        );

        uint256 totalRepayment = calculateRequiredCollateral();
        uint256 interestAmount = calculateInterest();
        uint256 principalAmount = totalRepayment - interestAmount;

        _validateRepayment(totalRepayment);
        _transferFunds(msg.sender, principalAmount);
        _refundRemainingInterest();
        _releaseCollateral(principalAmount);
        _updateLoanStateToRepaid();
    }

    /// @dev Ensures that the borrower has enough tokens approved and available for the repayment.
    function _validateRepayment(uint256 totalRepayment) private view {
        require(
            loanDetails.repaymentToken.allowance(msg.sender, address(this)) >=
                totalRepayment,
            "Insufficient token allowance for repayment."
        );
        require(
            loanDetails.repaymentToken.balanceOf(msg.sender) >= totalRepayment,
            "Insufficient token balance for repayment."
        );
    }

    /// @dev Transfers the principal repayment to the lender.
    function _transferFunds(address borrower, uint256 principalAmount) private {
        loanDetails.repaymentToken.transferFrom(
            borrower,
            loanDetails.lender,
            principalAmount
        );
    }

    /// @dev Refunds any remaining interest to the borrower after loan repayment.
    function _refundRemainingInterest() private {
        vaultManager.refundRemainingInterest(address(this), msg.sender);
    }

    /// @dev Releases the collateral from the vault back to the borrower.
    function _releaseCollateral(uint256 principalAmount) private {
        uint256 sharesToRedeem = loanDetails.collateralVault.convertToShares(
            principalAmount
        );
        loanDetails.collateralVault.redeem(
            sharesToRedeem,
            msg.sender,
            msg.sender
        );
        
    }

    /// @dev Updates the state of the loan to REPAID and handles any cleanup.
    function _updateLoanStateToRepaid() private {
        state = LoanState.REPAID;
        loanDetails.repaymentToken.transfer(msg.sender,loanDetails.repaymentToken.balanceOf(address(this))); // Last check if any borrower's collateral remains before loan closed.
        _closeLoan();
        emit RepaymentMade(calculateRequiredCollateral());
    }

    function _closeLoan() internal {
        state = LoanState.CLOSED;
        poolOrganizer.deregisterPool(address(this));
        vaultManager.deregisterVault(address(this));
        rewardManager.deregisterPool(address(this));
        emit LoanClosed();
    }

    /// @notice Calculates the total interest for the full term of the loan using an external interest model.
    function calculateInterest() public view returns (uint256) {
        // Assuming interest is calculated annually on the full loan amount
        return loanDetails.interestModel.calculateInterest(
            loanDetails.loanAmount,
            loanDetails.interestRate
        );
    }

    /// @notice Calculates the required collateral based on the interest and principal.
    function calculateRequiredCollateral() public view returns (uint256) {
        uint256 interestForFullTerm = calculateInterest();
        return loanDetails.loanAmount + interestForFullTerm;
    }

    /// Lens
    /// @notice Provides the block timestamp when the loan was funded.
    function getFundedBlock() public view returns (uint256) {
        return loanDetails.fundedBlock;
    }

    function getLender() public view returns (address) {
        return loanDetails.lender;
    }

    function getBorrower() public view returns (address) {
        return loanDetails.borrower;
    }

    function getRepaymentToken() public view returns (IERC20) {
        return loanDetails.repaymentToken;
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
