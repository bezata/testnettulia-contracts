// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IFeeManager.sol";

contract FeeManager is IFeeManager {
    uint256 public tuliaPoolFeeRate;
    uint256 public flashPoolFeeRate;
    uint256 public constant MAX_FEE_RATE = 500; // Maximum fee rate of 5.00%, expressed in basis points

    constructor(uint256 initialtuliaPoolFeeRate, uint256 initialflashPoolFeeRate) {
        require(initialtuliaPoolFeeRate <= MAX_FEE_RATE, "Initial tuliaPool fee rate is too high");
        require(initialflashPoolFeeRate <= MAX_FEE_RATE, "Initial flashPool fee rate is too high");
        tuliaPoolFeeRate = initialtuliaPoolFeeRate;
        flashPoolFeeRate = initialflashPoolFeeRate;
    }

    /// @inheritdoc IFeeManager
    function gettuliaPoolFeeRate() public view override returns (uint256) {
        return tuliaPoolFeeRate;
    }

    /// @inheritdoc IFeeManager
    function settuliaPoolFeeRate(uint256 newFeeRate) public override {
        require(newFeeRate <= MAX_FEE_RATE, "New tuliaPool fee rate is too high");
        tuliaPoolFeeRate = newFeeRate;
        emit tuliaPoolFeeRateUpdated(newFeeRate);
    }

    /// @inheritdoc IFeeManager
    function getflashPoolFeeRate() public view override returns (uint256) {
        return flashPoolFeeRate;
    }

    /// @inheritdoc IFeeManager
    function setflashPoolFeeRate(uint256 newFeeRate) public override {
        require(newFeeRate <= MAX_FEE_RATE, "New flashPool fee rate is too high");
        flashPoolFeeRate = newFeeRate;
        emit flashPoolFeeRateUpdated(newFeeRate);
    }
}
