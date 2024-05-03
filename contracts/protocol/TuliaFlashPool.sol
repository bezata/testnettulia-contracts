// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "../interfaces/IPermit2.sol";
import "../interfaces/IFeeManager.sol";  

/// @title TuliaFlashPool
/// @dev Implements flash loan functionalities with integrated fee management.
/// This contract allows issuing flash loans backed by ERC20 tokens.
contract TuliaFlashPool is IERC3156FlashLender, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice ERC20 asset used for flash loans
    IERC20 public asset;

    /// @notice Permit2 contract utilized for permissioned token transfers
    IPermit2 public permit2;

    /// @notice Contract managing the fee rates for flash loans
    IFeeManager public feeManager;

    /// @notice Initial fee rate for flash loans issued by this pool
    uint256 public flashLoanFeeRate;

    /// @notice Enum representing the state of the pool
    enum PoolState { IDLE, AWAITING_BORROWER, ACTIVE }
    PoolState public state;

    /// @notice Constructs the TuliaFlashPool lending pool
    /// @param _asset The ERC20 token asset used for flash loans
    /// @param _permit2 The Permit2 contract utilized for permissioned token transfers
    /// @param _feeManager The contract managing the fee rates for the flash loans
    /// @param _flashLoanFeeRate The initial fee rate for flash loans issued by this pool
    constructor(
        IERC20 _asset, 
        IPermit2 _permit2, 
        IFeeManager _feeManager,
        uint256 _flashLoanFeeRate
    ) {
        asset = _asset;
        permit2 = _permit2;
        feeManager = _feeManager;
        flashLoanFeeRate = _flashLoanFeeRate;
        state = PoolState.IDLE;
    }

    /// @notice Returns the maximum loanable amount of the asset
    /// @param token The ERC20 token address for which the max loan amount is queried
    /// @return The maximum amount available for a flash loan
    function maxFlashLoan(address token) public view override returns (uint256) {
        return token == address(asset) ? asset.balanceOf(address(this)) : 0;
    }

    /// @notice Calculates the flash loan fee for a given loan amount
    /// @param token The ERC20 token for which the fee is calculated
    /// @param amount The amount of the loan
    /// @return The calculated fee amount
    function flashFee(address token, uint256 amount) public view override returns (uint256) {
        require(token == address(asset), "Unsupported token");
        uint256 userFee = (amount * flashLoanFeeRate) / 10000;
        uint256 protocolFee = (amount * feeManager.getflashPoolFeeRate()) / 10000;
        return userFee + protocolFee;
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
        return _executeFlashLoan(receiver, token, amount, data);
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
        require(state == PoolState.IDLE, "Flash loan not available");

        uint256 totalFee = flashFee(token, amount);
        uint256 balanceBefore = asset.balanceOf(address(this));

        asset.safeTransfer(address(receiver), amount);

        require(
            receiver.onFlashLoan(msg.sender, token, amount, totalFee, data) == keccak256("ERC3156FlashBorrower.onFlashLoan"),
            "Flash loan failed"
        );

        uint256 amountOwed = amount + totalFee;
        asset.safeTransferFrom(address(receiver), address(this), amountOwed);

        require(asset.balanceOf(address(this)) >= balanceBefore, "Flash loan repayment failed");
        state = PoolState.IDLE;

        return true;
    }
}
