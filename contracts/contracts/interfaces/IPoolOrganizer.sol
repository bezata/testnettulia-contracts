// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolOrganizer {
    enum PoolType { STANDARD, FLASH_LOAN }

    struct PoolDetails {
        address lender;
        address borrower;
        uint256 creationTime;
        address vault;
        IERC20 loanToken;
        IERC20 assetToken;
        IERC20 repaymentToken;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 repaymentPeriod;
        PoolType poolType; // New field to specify the type of pool
    }

    function registerPool(
        address pool,
        address lender,
        address borrower,
        address vault,
        IERC20 loanToken,
        IERC20 assetToken,
        IERC20 repaymentToken,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 repaymentPeriod,
        PoolType poolType  // Include pool type in registration
    ) external;

    function deregisterPool(address pool) external;
    function getTotalPools() external view returns (uint256);
    function getPoolsByLender(address lender) external view returns (address[] memory);
    function getPoolDetails(address pool) external view returns (PoolDetails memory);
    function getVaultForPool(address pool) external view returns (address);
    function grantFactoryAccess(address factoryAddress) external;
    function registerVault(address pool,address vault) external;
    function registerManagers(address _vaultManager, address _rewardManager) external;
}
