// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IInterestModel.sol";

contract SimpleInterest is IInterestModel {
    /**
     * @dev Calculate simple interest for a full year upfront, based on an annual interest rate.
     * @param principal The principal amount.
     * @param rate The annual interest rate (in basis points, where 10000 = 100%).
     * @return The total interest for one year.
     */
    function calculateInterest(
        uint256 principal,
        uint256 rate
    ) external pure override returns (uint256) {
        // Since it's for a full year, time = 365 days is implicit.
        uint256 interest = (principal * rate) / 10000;
        return interest;
    }
}
