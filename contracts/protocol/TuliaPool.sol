// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TuliaVault.sol";
import "../interfaces/IInterestModel.sol";
import "../interfaces/IPoolOrganizer.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IRewardManager.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title TuliaPool
/// @notice Manages the lifecycle of loans including creation, funding, repayment, and defaults.
/// @dev This contract handles all operations regarding lending processes with integrated safety checks and state management.
contract TuliaPool is ReentrancyGuard, AccessControl {
    IPoolOrganizer public poolOrganizer;
    IVaultManager public vaultManager;
    IRewardManager public rewardManager;

    // Role definitions
    bytes32 public constant LENDER_ROLE = keccak256("LENDER_ROLE");
    bytes32 public constant BORROWER_ROLE = keccak256("BORROWER_ROLE");

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
    /// @param lender The address of the lender.
    /// @param loanAmount The amount of the loan.
    /// @param loanToken The token being loaned.
    /// @param repaymentToken The token for repayment.
    event LoanOfferCreated(
        address indexed lender,
        uint256 loanAmount,
        IERC20 loanToken,
        IERC20 repaymentToken
    );

    /// @notice Emitted when a loan is activated.
    /// @param borrower The address of the borrower.
    /// @param collateralAmount The amount of collateral.
    event LoanActivated(address indexed borrower, uint256 collateralAmount);

    /// @notice Emitted when a loan is funded.
    /// @param loanAmount The amount of the loan.
    event LoanFunded(uint256 loanAmount);

    /// @notice Emitted when a loan is repaid.
    /// @param amountRepaid The amount repaid.
    event RepaymentMade(uint256 amountRepaid);

    /// @notice Emitted when a loan is closed.
    event LoanClosed();

    /// @notice Emitted when a loan defaults.
    /// @param borrower The address of the borrower.
    event LoanDefaulted(address indexed borrower);

    /// @notice Emitted when collateral is funded.
    /// @param collateralAmount The amount of collateral.
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
    /// @param poolOrganizerAddress Pool Organizer contract for managing pool registrations.
    /// @param vaultManagerAddress Vault Manager contract address.
    /// @param rewardManagerAddress Reward Manager contract address.
    constructor(
        address lender,
        IERC20 loanTokenAddress,
        IERC20 repaymentTokenAddress,
        address collateralVaultAddress,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 repaymentPeriodInDays,
        IInterestModel interestModel,
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
        _grantRole(DEFAULT_ADMIN_ROLE, lender);
        _grantRole(LENDER_ROLE, lender);
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

    /**
     * @notice Activates a loan by transferring collateral from the borrower to the vault and transferring the loan amount to the borrower.
     */
    function activateLoan() external nonReentrant {
        _checkPreconditions();
        _handleCollateral();
        _disburseLoan();
        _finalizeActivation();
        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.ACTIVE
        );
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
        rewardManager.registerBorrower(address(this), borrower);
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
        _grantRole(BORROWER_ROLE, borrower);
        poolOrganizer.setBorrowerForPool(address(this), address(borrower));
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

    /// @notice Funds the loan by transferring the loan amount from the lender to the contract.
    function fundLoan() external nonReentrant {
        require(state == LoanState.CREATED, "Loan not in creatable state");
        require(hasRole(LENDER_ROLE, msg.sender), "Invalid Role");
        loanDetails.loanToken.transferFrom(
            loanDetails.lender,
            address(this),
            loanDetails.loanAmount
        );
        loanDetails.fundedBlock = block.timestamp;
        state = LoanState.PENDING;
        rewardManager.registerPool(
            address(this),
            address(loanDetails.loanToken)
        );
        poolOrganizer.markPoolAsFunded(address(this));
        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.PENDING
        );
        emit LoanFunded(loanDetails.loanAmount);
    }

    /// @notice Checks if the loan has defaulted and handles the default.
    function checkAndHandleDefault() public {
        require(state == LoanState.ACTIVE, "Loan is not active");
        if (_isPastDue()) {
            state = LoanState.DEFAULTED;
            poolOrganizer.updateLoanState(
                address(this),
                IPoolOrganizer.LoanState.DEFAULTED
            );
            _handleDefault();
        }
    }

    /// @dev Transitions the loan to closed state and emits the LoanDefaulted event.
    function _transitionToClosed() private {
        _closeLoan();
        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.CLOSED
        );
        emit LoanDefaulted(loanDetails.borrower);
    }

    /// @dev Checks if the loan repayment period has passed.
    /// @return Returns true if the loan is past due, false otherwise.
    function _isPastDue() private view returns (bool) {
        uint256 dueDate = loanDetails.startBlock + loanDetails.repaymentPeriod;
        return block.timestamp >= dueDate;
    }

    /**
     * @dev Handles the default by redeeming collateral to the lender and updating state.
     */
    function _handleDefault() private {
        _redeemCollateralToLender();
        vaultManager.handleDefault(address(this), loanDetails.lender);
        _transitionToClosed();
    }

    /**
     * @dev Redeems collateral to the lender in case of default.
     */
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
        uint256 principalAmount = loanDetails.loanAmount;

        // Validate repayment amount and allowances
        _validateRepayment(totalRepayment);

        // Transfer the principal repayment to the lender
        _transferFunds(msg.sender, principalAmount);

        // Refund any remaining interest to the borrower
        _refundRemainingInterest();

        // Release the collateral from the vault back to the borrower
        _releaseCollateral();

        // Update the loan state to REPAID and handle cleanup
        _updateLoanStateToRepaid();

        // Close the loan
        _closeLoan();
    }

    /**
     * @dev Ensures that the borrower has enough tokens approved and available for the repayment.
     * @param totalRepayment The total amount required for repayment.
     */
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

    /**
     * @dev Transfers the principal repayment to the lender.
     * @param borrower The address of the borrower.
     * @param principalAmount The amount of the principal.
     */
    function _transferFunds(address borrower, uint256 principalAmount) private {
        loanDetails.repaymentToken.transferFrom(
            borrower,
            loanDetails.lender,
            principalAmount
        );
    }

    /**
     * @dev Refunds any remaining interest to the borrower after loan repayment.
     */
    function _refundRemainingInterest() private {
        vaultManager.refundRemainingInterest(address(this), msg.sender);
    }

    /**
     * @dev Releases the collateral from the vault back to the borrower.
     */
    function _releaseCollateral() private {
        uint256 collateralBalance = loanDetails.collateralVault.balanceOf(
            loanDetails.borrower
        );
        uint256 sharesToRedeem = loanDetails.collateralVault.convertToShares(
            collateralBalance
        );
        loanDetails.collateralVault.redeem(
            sharesToRedeem,
            msg.sender,
            msg.sender
        );
    }

    /**
     * @dev Updates the state of the loan to REPAID and handles any cleanup.
     */
    function _updateLoanStateToRepaid() private {
        state = LoanState.REPAID;
        uint256 remainingBalance = loanDetails.repaymentToken.balanceOf(
            address(this)
        );
        if (remainingBalance > 0) {
            loanDetails.repaymentToken.transfer(msg.sender, remainingBalance);
        }

        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.REPAID
        );

        emit RepaymentMade(calculateRequiredCollateral());
    }

    /**
     * @dev Closes the loan, deregistering it from various managers and updating state.
     */
    function _closeLoan() internal {
        state = LoanState.CLOSED;
        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.CLOSED
        );

        vaultManager.deregisterVault(address(this));
        rewardManager.deregisterPool(address(this));
        poolOrganizer.deregisterPool(address(this));

        emit LoanClosed();
    }

    /// @notice Allows the lender to reclaim the loan amount and close the pool if the borrower does not exist.
    function reclaimLoanAndClosePool() external nonReentrant {
        require(
            hasRole(LENDER_ROLE, msg.sender),
            "Only the lender can reclaim the loan"
        );
        require(state == LoanState.PENDING, "Loan must be in a pending state");
        require(loanDetails.borrower == address(0), "Borrower already exists");

        // Transfer the loan amount back to the lender
        loanDetails.loanToken.transfer(
            loanDetails.lender,
            loanDetails.loanAmount
        );

        // Close the loan
        state = LoanState.CLOSED;
        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.CLOSED
        );
        poolOrganizer.deregisterPool(address(this));
        rewardManager.deregisterPool(address(this));

        emit LoanClosed();
    }

    /// @notice Calculates the total interest for the full term of the loan using an external interest model.
    /// @return The total interest amount.
    function calculateInterest() public view returns (uint256) {
        return
            loanDetails.interestModel.calculateInterest(
                loanDetails.loanAmount,
                loanDetails.interestRate
            );
    }

    /// @notice Calculates the required collateral based on the interest and principal.
    /// @return The total required collateral amount.
    function calculateRequiredCollateral() public view returns (uint256) {
        uint256 interestForFullTerm = calculateInterest();
        return loanDetails.loanAmount + interestForFullTerm;
    }

    /// @notice Provides the block timestamp when the loan was funded.
    /// @return The block timestamp when the loan was funded.
    function getFundedBlock() public view returns (uint256) {
        return loanDetails.fundedBlock;
    }

    /// @notice Retrieves the lender's address.
    /// @return The lender's address.
    function getLender() public view returns (address) {
        return loanDetails.lender;
    }

    /// @notice Retrieves the borrower's address.
    /// @return The borrower's address.
    function getBorrower() public view returns (address) {
        return loanDetails.borrower;
    }

    /// @notice Retrieves the repayment token.
    /// @return The ERC20 token used for repayment.
    function getRepaymentToken() public view returns (IERC20) {
        return loanDetails.repaymentToken;
    }

    /// @notice Retrieves the current state of the loan.
    /// @return The current state of the loan.
    function getLoanState() public view returns (LoanState) {
        return state;
    }

    /// @notice Retrieves the total loan amount.
    /// @return The total loan amount.
    function getLoanAmount() public view returns (uint256) {
        return loanDetails.loanAmount;
    }

    /// @notice Retrieves the interest rate of the loan.
    /// @return The interest rate of the loan.
    function getInterestRate() public view returns (uint256) {
        return loanDetails.interestRate;
    }

    /// @notice Retrieves the amount of collateral stored for a specific user.
    /// @param user The address of the user.
    /// @return The amount of collateral stored for the user.
    function getCollateralAmount(address user) public view returns (uint256) {
        return loanDetails.collateralVault.balanceOf(user);
    }

    /// @notice Retrieves the repayment period of the loan.
    /// @return The repayment period of the loan.
    function getRepaymentPeriod() public view returns (uint256) {
        return loanDetails.repaymentPeriod;
    }

    /**
     * @notice Calculates the remaining repayment period of the loan in seconds.
     * @dev Returns 0 if the loan is past due or if it has not yet been activated.
     * @return The remaining repayment period in seconds.
     */
    function getRemainingRepaymentPeriod() public view returns (uint256) {
        if (state != LoanState.ACTIVE) {
            return 0;
        }

        uint256 endBlock = loanDetails.startBlock + loanDetails.repaymentPeriod;
        if (block.timestamp >= endBlock) {
            return 0;
        }

        return endBlock - block.timestamp;
    }
}
