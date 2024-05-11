// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAdvancedAPYManager
/// @dev Interface for the AdvancedAPYManager contract to manage APY adjustments.
interface IAdvancedAPYManager {
    /// @notice Gets the current total APY considering both base rate and additional risk premium.
    /// @return The current total APY in basis points.
    function getCurrentAPY() external view returns (uint256);

    function calculateAPY(uint256 loanAmount, uint256 durationSeconds) external view returns (uint256);

    /// @notice Updates the APY based on the latest rates from mock data feeds.
    function updateAPY() external;
}
