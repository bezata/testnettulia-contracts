// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "../interfaces/IPaymentModel.sol";

contract MarketBasedInterest is IInterestModel {
    AggregatorV3Interface internal interestRateOracle;

    constructor(address _interestRateOracle) {
        interestRateOracle = AggregatorV3Interface(_interestRateOracle);
    }

    function calculateInterest(uint256 principal, uint256 rate, uint256 time) external view override returns (uint256) {
        (, int256 marketRate, , , ) = interestRateOracle.latestRoundData();
        require(marketRate > 0, "Invalid market rate from oracle");

        uint256 adjustedRate = uint256(marketRate) + rate; // Adjusts market rate with additional rate in basis points
        return (principal * adjustedRate * time) / (365 days * 10000) - principal; // Adjusts for basis points and days, returning only the interest
    }
}
