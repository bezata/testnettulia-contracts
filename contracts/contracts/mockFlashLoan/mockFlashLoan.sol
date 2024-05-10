// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";

contract MockFlashLoanBorrower is IERC3156FlashBorrower {
    using SafeERC20 for IERC20;

    IERC3156FlashLender public lender;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    // Constructor to set the lender
    constructor(address _lender) {
        lender = IERC3156FlashLender(_lender);
    }

    // Function to initiate a flash loan
    function initiateFlashLoan(address token, uint256 amount) external {
        // Initiating a flash loan
        lender.flashLoan(this, token, amount, bytes("Arbitrary data"));
    }

    // Callback function that runs after receiving the flash loan
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns (bytes32) {
        require(msg.sender == address(lender), "Only lender can call this function");
        require(initiator == address(this), "Untrusted loan initiator");

        // Here you can place your arbitrary logic with the borrowed amount
        // For instance, conducting an arbitrage, performing swaps, or other operations

        // Total amount that needs to be repaid to the flash loan provider
        uint256 totalRepayment = amount + fee;
        IERC20(token).safeIncreaseAllowance(address(lender), totalRepayment);
        IERC20(token).safeTransferFrom(address(this), address(lender), totalRepayment);

        return CALLBACK_SUCCESS;  // Signalling that the flash loan was handled successfully
    }
}
