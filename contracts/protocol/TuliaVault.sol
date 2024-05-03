// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IPermit2.sol";

/// @title TuliaVault
/// @notice Manages the vault where assets are stored and facilitates tokenized shares representing ownership of the underlying assets.
/// @dev Extends ERC4626 to utilize a permit system for streamlined deposit operations.
contract TuliaVault is ERC4626, ReentrancyGuard {
    IPermit2 public immutable permitSystem;

    /// @dev Initializes the TuliaVault with necessary details and links to the permit system for handling token operations securely.
    /// @param asset The ERC20 token that this vault will accept.
    /// @param name The name of the vault token.
    /// @param symbol The symbol of the vault token.
    /// @param _permitSystem Address of the Permit2 contract used for ERC20 token operations.
    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol,
        IPermit2 _permitSystem
    ) ERC4626(asset) ERC20(name, symbol) {
        permitSystem = _permitSystem;
    }

    /// @notice Deposits assets into the vault with permit approval, issuing shares of the vault in return.
    /// @param amount The amount of the underlying asset to deposit.
    /// @param permitData Data required for the permit including details about the approval.
    /// @param signature Signature from the token holder approving the deposit.
    /// @param receiver Address receiving the vault shares.
    /// @return shares The number of shares issued to the receiver.
    function depositWithPermit(
        uint256 amount,
        IPermit2.PermitSingle memory permitData,
        bytes calldata signature,
        address receiver
    ) public nonReentrant returns (uint256 shares) {
        // Permit the transfer of tokens to this contract
        permitSystem.permit(msg.sender, permitData, signature);
        // Deposit tokens and mint corresponding shares to the receiver
        shares = deposit(amount, receiver);
        return shares;
    }

    /// @notice Allows batch deposits using multiple permits for efficiency in transactions.
    /// @param permitData Array of permit data for each deposit.
    /// @param signatures Array of signatures corresponding to each permit data.
    /// @param receiver Address receiving the vault shares for all deposits.
    /// @return shares The total number of shares issued to the receiver for all deposits.
    function depositWithBatchPermit(
        IPermit2.PermitBatch[] memory permitData,
        bytes[] calldata signatures,
        address receiver
    ) public nonReentrant returns (uint256 shares) {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < permitData.length; i++) {
            // Validate each permit with corresponding signature
            permitSystem.permit(msg.sender, permitData[i], signatures[i]);

            // Sum up the amounts from each PermitDetails in the PermitBatch
            for (uint256 j = 0; j < permitData[i].details.length; j++) {
                totalAmount += permitData[i].details[j].amount;
            }
        }

        // Deposit the total amount and mint shares to the receiver
        shares = deposit(totalAmount, receiver);
        return shares;
    }
}
