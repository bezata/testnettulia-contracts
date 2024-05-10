// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInterestModel {
    /**
     * @dev Calculates interest on a given principal over a period.
     * @param principal The principal amount.
     * @param rate The interest rate, in basis points for simple and compound, or additional adjustment for market-based.
     * @param time The time period in seconds.
     * @return The amount of interest accrued.
     */
    function calculateInterest(uint256 principal, uint256 rate, uint256 time) external pure returns (uint256);
}
