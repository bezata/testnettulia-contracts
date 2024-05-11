// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title AdvancedAPYManager
/// @dev Manages APY adjustments based on loan characteristics such as amount and duration.
contract AdvancedAPYManager {


    uint256 public baseAPY = 100; // Default 1% APY in basis points
    uint256[] public riskPremiumThresholds; // Thresholds for loan amounts
    uint256[] public riskPremiumRates; // Corresponding risk premiums

    uint256 public durationBonusFactor = 25; // Duration bonus in basis points per year

    /// @notice Initializes the contract with the lending token.
    constructor() {

    }

    /// @notice Calculates the current APY based on loan amount and duration.
    /// @param loanAmount The amount of the loan.
    /// @param durationSeconds The duration of the loan in seconds.
    /// @return uint256 Calculated APY in basis points.
    function calculateAPY(uint256 loanAmount, uint256 durationSeconds) view external returns (uint256) {
        uint256 riskPremium = calculateRiskPremium(loanAmount);
        uint256 durationBonus = calculateDurationBonus(durationSeconds);

        return baseAPY + riskPremium + durationBonus;
    }

    /// @notice Calculates additional risk premium based on the loan amount using thresholds.
    /// @param loanAmount The amount of the loan.
    /// @return uint256 Additional risk premium in basis points.
    function calculateRiskPremium(uint256 loanAmount) internal view returns (uint256) {
        for (uint256 i = 0; i < riskPremiumThresholds.length; i++) {
            if (loanAmount <= riskPremiumThresholds[i]) {
                return riskPremiumRates[i];
            }
        }
        return 0;
    }

    /// @notice Calculates a bonus based on the loan duration in seconds.
    /// @param durationSeconds The duration of the loan in seconds.
    /// @return uint256 Duration bonus in basis points.
    function calculateDurationBonus(uint256 durationSeconds) internal view returns (uint256) {
        uint256 yearss = durationSeconds / (365 days);
        return yearss * durationBonusFactor;
    }

    /// @notice Sets the risk premium thresholds and rates.
    /// @param _thresholds Array of loan amount thresholds.
    /// @param _rates Array of risk premiums corresponding to the thresholds.
    function setRiskPremiums(uint256[] calldata _thresholds, uint256[] calldata _rates) public  {
        require(_thresholds.length == _rates.length, "Mismatched input lengths");
        riskPremiumThresholds = _thresholds;
        riskPremiumRates = _rates;
    }

    /// @notice Allows the owner to adjust the base APY rate.
    /// @param _baseAPY The new base APY in basis points.
    function setBaseAPY(uint256 _baseAPY) public  {
        baseAPY = _baseAPY;
    }

    /// @notice Allows the owner to adjust the duration bonus factor.
    /// @param _factor The new duration bonus factor in basis points per year.
    function setDurationBonusFactor(uint256 _factor) public  {
        durationBonusFactor = _factor;
    }
}
