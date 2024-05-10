// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeManager {
    /// @notice Get the current tuliaPool fee rate
    /// @return The tuliaPool fee rate in basis points
    function gettuliaPoolFeeRate() external view returns (uint256);

    /// @notice Set the tuliaPool fee rate
    /// @param newFeeRate The new tuliaPool fee rate in basis points
    function settuliaPoolFeeRate(uint256 newFeeRate) external;

    /// @notice Get the current flashPool fee rate
    /// @return The flashPool fee rate in basis points
    function getflashPoolFeeRate() external view returns (uint256);

    /// @notice Set the flashPool fee rate
    /// @param newFeeRate The new flashPool fee rate in basis points
    function setflashPoolFeeRate(uint256 newFeeRate) external;

    /// @notice Event emitted when the tuliaPool fee rate is updated
    /// @param newFeeRate The new tuliaPool fee rate that has been set
    event tuliaPoolFeeRateUpdated(uint256 newFeeRate);

    /// @notice Event emitted when the flashPool fee rate is updated
    /// @param newFeeRate The new flashPool fee rate that has been set
    event flashPoolFeeRateUpdated(uint256 newFeeRate);
}
