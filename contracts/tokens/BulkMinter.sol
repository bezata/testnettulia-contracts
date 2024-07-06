// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./MockTokenCreator.sol"; // Assuming MockTokenCreator is in the same directory

/**
 * @title BulkMinter
 * @dev This contract allows the minting of multiple ERC20 tokens to the caller in a single transaction.
 */
contract BulkMinter is Ownable {
    /// @notice Array to hold the addresses of the deployed ERC20 contracts.
    MockTokenCreator[] public tokens;

    /**
     * @dev Initializes the contract setting the initial owner.
     * @param initialOwner The address of the initial owner.
     */
    constructor(address initialOwner) Ownable(initialOwner) {

    }

    /**
     * @dev Adds a new token contract to the list.
     * @param token The address of the token contract.
     */
    function addToken(address token) external onlyOwner {
        tokens.push(MockTokenCreator(token));
    }

    /**
     * @notice Mints tokens from all the listed contracts to the caller.
     * @dev The `amounts` array must match the length of the `tokens` array.
     * @param amounts An array of amounts to mint from each token contract.
     * The array index corresponds to the token contract index.
     */
    function mintAll(uint256[] calldata amounts) external {
        require(amounts.length == tokens.length, "Amounts array length must match tokens array length.");

        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].mint(msg.sender, amounts[i]);
        }
    }

    /**
     * @notice Gets the number of token contracts added.
     * @return The number of token contracts.
     */
    function getTokenCount() external view returns (uint256) {
        return tokens.length;
    }
}
