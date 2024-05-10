// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockPriceFeed {
    int256 private price;

    // Sets the initial price for testing
    constructor(int256 _initialPrice) {
        price = _initialPrice;
    }

    // Simulates the latestRoundData function from Chainlink AggregatorV3Interface
    function latestRoundData() external view returns (
        uint80 roundID, 
        int256 answer, 
        uint256 startedAt, 
        uint256 updatedAt, 
        uint80 answeredInRound
    ) {
        return (0, price, 0, block.timestamp, 0);
    }

    // Allows updating the price for different test scenarios
    function setPrice(int256 _newPrice) external {
        price = _newPrice;
    }
}
