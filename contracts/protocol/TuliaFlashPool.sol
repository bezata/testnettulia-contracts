// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../interfaces/IPoolOrganizer.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IFlashPoolRewardManager.sol";

/// @title TuliaFlashPool
/// @dev Implements flash loan functionalities with integrated fee management.
/// This contract allows issuing flash loans backed by ERC20 tokens.
contract TuliaFlashPool is IERC3156FlashLender, ReentrancyGuard, AccessControl {


    /// @notice ERC20 asset used for flash loans
    IERC20 public asset;
    uint256 public loanAmount;
    IPoolOrganizer public poolOrganizer;
    IFlashPoolRewardManager public flashPoolRewardManager;

    bytes32 public constant LENDER_ROLE = keccak256("LENDER_ROLE");
    address public lender; // Address of the lender who funded the pool

    /// @notice Initial fee rate for flash loans issued by this pool
    uint256 public flashLoanFeeRate;

    /// @notice Event emitted when a flash loan is executed
    /// @param receiver The borrower contract
    /// @param token The ERC20 token for the loan
    /// @param amount The loan amount
    /// @param fee The loan fee
    event FlashLoanExecuted(
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );

    /// @dev Enumerates the possible states of a loan.
    enum FlashLoanState {
        UNINITIALIZED,
        FUNDED,
        CLOSED
    }

    FlashLoanState public state; // Current state of the loan.

    /// @notice Event emitted when a loan is funded
    /// @param lender The address of the lender
    /// @param amount The amount of the loan
    event LoanFunded(address indexed lender, uint256 amount);
    event LoanClosed(address indexed lender, uint256 amount);

    /// @notice Constructs the TuliaFlashPool lending pool
    /// @param _asset The ERC20 token asset used for flash loans
    /// @param _flashLoanFeeRate The initial fee rate for flash loans issued by this pool
    /// @param _poolOrganizer The Pool Organizer contract
    /// @param _flashPoolRewardManager The FlashPool Reward Manager contract
    /// @param _loanAmount The amount of the loan to be funded
    constructor(
        IERC20 _asset,
        uint256 _flashLoanFeeRate,
        IPoolOrganizer _poolOrganizer,
        IFlashPoolRewardManager _flashPoolRewardManager,
        uint256 _loanAmount
    ) {
        asset = _asset;
        flashLoanFeeRate = _flashLoanFeeRate;
        poolOrganizer = _poolOrganizer;
        flashPoolRewardManager = _flashPoolRewardManager;   
        
        loanAmount = _loanAmount;
        state = FlashLoanState.UNINITIALIZED;
    }

    /// @notice Allows a lender to fund the pool directly with the specified loan amount
    function fundLoan() external nonReentrant {
        require(state == FlashLoanState.UNINITIALIZED, "Loan is already funded");
        lender = msg.sender;

        // Check if lender has enough balance
        require(asset.balanceOf(msg.sender) >= loanAmount, "Insufficient balance to fund the loan");

        // Check if the contract is allowed to transfer tokens
        require(asset.allowance(msg.sender, address(this)) >= loanAmount, "Allowance not set for this contract");

        // Transfer tokens to the contract
        asset.transferFrom(msg.sender, address(this), loanAmount);

        // Register the pool
        flashPoolRewardManager.registerPool(address(this), address(asset), loanAmount);

        // Grant role
        _grantRole(LENDER_ROLE, msg.sender);
        // Update state
        state = FlashLoanState.FUNDED;

        emit LoanFunded(msg.sender, loanAmount);
    }

    /// @notice Returns the maximum loanable amount of the asset
    /// @param token The ERC20 token address for which the max loan amount is queried
    /// @return The maximum amount available for a flash loan
    function maxFlashLoan(address token)
        public
        view
        override
        returns (uint256)
    {
        return token == address(asset) ? asset.balanceOf(address(this)) : 0;
    }

    /// @notice Calculates the flash loan fee for a given loan amount
    /// @param token The ERC20 token for which the fee is calculated
    /// @param amount The amount of the loan
    /// @return The calculated fee amount
    function flashFee(address token, uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        require(token == address(asset), "Unsupported token");
        uint256 userFee = (amount * flashLoanFeeRate) / 10000;
        return userFee;
    }

    /// @notice Initiates a flash loan transaction
    /// @param receiver The borrower contract that must implement the IERC3156FlashBorrower interface
    /// @param token The ERC20 token to be borrowed
    /// @param amount The amount of tokens to borrow
    /// @param data Arbitrary data passed to the borrower's `onFlashLoan` method
    /// @return true if the flash loan is paid back successfully within the same transaction
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override nonReentrant returns (bool) {
        require(state == FlashLoanState.FUNDED, "Pool not funded");
        return _executeFlashLoan(receiver, token, amount, data);
    }

    /// @notice Allows the lender to close the loan and withdraw their funds if no active flash loans are present
    function closeLoan() external nonReentrant {
        require(hasRole(LENDER_ROLE, msg.sender), "Caller is not the lender");
        require(
            state == FlashLoanState.FUNDED,
            "Loan is not in a funded state"
        );

        uint256 amount = asset.balanceOf(address(this));
        require(amount > 0, "No funds to withdraw");

        state = FlashLoanState.CLOSED;
        poolOrganizer.updateLoanState(
            address(this),
            IPoolOrganizer.LoanState.CLOSED
        );
        poolOrganizer.deregisterPool(address(this));

        asset.transfer(lender, amount);

        emit LoanClosed(lender, amount);
    }

    /// @dev Internal function to execute a flash loan transaction
    /// Handles the lifecycle of a flash loan including fee calculation, asset transfer, and repayment check
    /// @param receiver The borrower contract
    /// @param token The ERC20 token for the loan
    /// @param amount The loan amount
    /// @param data Data payload for the borrower
    /// @return true if the transaction is successful
    function _executeFlashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) internal returns (bool) {
        require(token == address(asset), "Unsupported token");

        uint256 totalFee = flashFee(token, amount);
        uint256 balanceBefore = asset.balanceOf(address(this));

        asset.transfer(address(receiver), amount);

        require(
            receiver.onFlashLoan(msg.sender, token, amount, totalFee, data) ==
                keccak256("ERC3156FlashBorrower.onFlashLoan"),
            "Flash loan failed"
        );

        uint256 amountOwed = amount + totalFee;
        asset.transferFrom(address(receiver), address(this), amountOwed);

        require(
            asset.balanceOf(address(this)) >= balanceBefore,
            "Flash loan repayment failed"
        );

        // Transfer the repaid amount and fee back to the lender
        asset.transfer(lender, totalFee);

        emit FlashLoanExecuted(address(receiver), token, amount, totalFee);
        return true;
    }

    /// @notice Returns the current state of the flash loan
    /// @return The current state of the flash loan
    function getFlashLoanState() external view returns (FlashLoanState) {
        return state;
    }
}
