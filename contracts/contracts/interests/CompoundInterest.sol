// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IInterestModel.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CompoundInterest is IInterestModel {
    using SafeMath for uint256;

    uint256 private constant BASIS_POINT = 10000;
    uint256 private constant DECIMALS = 1e18;

    /**
     * @dev Calculates compound interest on a principal over one year.
     * @param principal The principal amount.
     * @param rate The annual interest rate in basis points (1 basis point = 0.01%).
     * @return The total compound interest for the year.
     */
    function calculateInterest(uint256 principal, uint256 rate) external pure override returns (uint256) {
        uint256 ratePerYear = (rate * DECIMALS) / BASIS_POINT; // Convert rate into a decimal equivalent
        uint256 compounded = principal.mul(DECIMALS.add(ratePerYear)).div(DECIMALS);
        return compounded - principal;
    }
}
