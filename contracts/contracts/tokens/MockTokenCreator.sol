// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title MockTokenCreator
 * @dev Extension of OpenZeppelin's ERC20 and ERC20Permit contract.
 * Allows for minting and burning of tokens, and includes permit functionality.
 */
contract MockTokenCreator is ERC20, ERC20Permit {
    /**
     * @dev Initializes the contract with the token name and symbol, and sets up permit functionality.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     */
    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
        ERC20Permit(name)
    {}

    /**
     * @notice Mints `amount` tokens to address `to`.
     * @dev Caller must have a role that allows them to mint (not implemented in this simple example).
     * @param to The address of the recipient.
     * @param amount The number of tokens to mint.
     */
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    /**
     * @notice Burns `amount` tokens from the caller’s account.
     * @dev Caller must have at least `amount` tokens.
     * @param amount The number of tokens to burn.
     */
    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}
