// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";


/// @title TuliaVault
/// @notice Manages the vault where assets are stored and facilitates tokenized shares representing ownership of the underlying assets.
/// @dev Extends ERC4626 for asset management.
contract TuliaVault is ERC4626 {

    constructor(IERC20 asset, string memory name, string memory symbol)
        ERC4626(asset)
        ERC20(name, symbol)
    {}


}
