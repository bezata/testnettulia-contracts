// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockDataFeed
/// @dev Simulates an external data feed by allowing manual updates of rates.
contract MockDataFeed {
    int256 private rate;

    /// @notice Updates the stored rate value.
    /// @param _rate New rate to store.
    function updateRate(int256 _rate) public {
        rate = _rate;
    }

    /// @notice Retrieves the current stored rate.
    /// @return The current rate.
    function getRate() public view returns (int256) {
        return rate;
    }
}
