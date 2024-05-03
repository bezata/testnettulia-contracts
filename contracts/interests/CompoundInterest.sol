// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IInterestModel.sol";

contract CompoundInterest is IInterestModel {
    /**
     * @dev Calculates compound interest on a principal over a period.
     * @param principal The principal amount.
     * @param rate The annual interest rate in basis points.
     * @param time The time period in seconds.
     * @return The amount of compound interest accrued.
     */
    function calculateInterest(uint256 principal, uint256 rate, uint256 time) external pure override returns (uint256) {
        uint256 ratePerPeriod = rate / 10000; // Convert rate from basis points to a decimal.
        uint256 periods = time / 31536000; // Convert time from seconds to years.

        // Calculate the compound interest
        uint256 amount = principal * (1 + ratePerPeriod) ** periods;
        return amount - principal; // Return only the interest accrued, not the total amount.
    }
}
