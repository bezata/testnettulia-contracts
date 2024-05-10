// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IInterestModel.sol";

contract SimpleInterest is  IInterestModel {

    constructor() {

    }
    /**
     * @dev Calculate simple interest.
     * @param principal The principal amount.
     * @param rate The annual interest rate (in basis points, where 10000 = 100%).
     * @param time The time in days for which the interest is calculated.
     * @return The interest amount.
     */
    function calculateInterest(
        uint256 principal,
        uint256 rate,
        uint256 time
    ) external pure override returns (uint256) {
        uint256 interest = (principal * rate * time) / (365 days * 10000);
        return interest;
    }


}
