// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IInterestModel.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CompoundInterest
 * @dev A simple interest model contract implementing compound interest calculation.
 */
contract CompoundInterest is IInterestModel {
    using SafeMath for uint256;

    uint256 private constant YEAR = 365 days;
    uint256 private constant BASIS_POINT = 10000;
    uint256 private constant DECIMALS = 1e18;

    /**
     * @dev Calculates compound interest on a principal over a period.
     * @param principal The principal amount.
     * @param rate The annual interest rate in basis points (1 basis point = 0.01%).
     * @param time The time period in seconds.
     * @return The amount of compound interest accrued.
     */
    function calculateInterest(uint256 principal, uint256 rate, uint256 time) external pure override returns (uint256) {
        uint256 ratePerPeriod = (rate.mul(DECIMALS)).div(BASIS_POINT);
        uint256 periods = time.div(YEAR);
        uint256 amount = principal.mul((DECIMALS.add(ratePerPeriod)).div(DECIMALS) ** periods);
        return amount.sub(principal).div(DECIMALS); 
    }
}
