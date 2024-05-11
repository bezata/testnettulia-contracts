// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IInterestModel {
    /**
     * @notice Calculates annual interest on a given principal for a fixed period of one year.
     * @param principal The principal amount.
     * @param rate The annual interest rate, in basis points.
     * @return The amount of interest accrued for one year.
     */
    function calculateInterest(uint256 principal, uint256 rate) external pure returns (uint256);
}
