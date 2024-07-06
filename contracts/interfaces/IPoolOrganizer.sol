// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IPoolOrganizer interface
/// @notice Interface for the Pool Organizer contract managing pools, vaults, and rewards.
interface IPoolOrganizer {
    enum PoolType { STANDARD, FLASH_LOAN }

    enum LoanState {
        CREATED,
        PENDING,
        ACTIVE,
        DEFAULTED,
        REPAID,
        CLOSED,
        FUNDED
    }

 
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
        PoolType poolType;
        bool funded;
        LoanState loanState;
        address pool;
    }

    /// @notice Registers a new pool
    /// @param pool The address of the pool contract
    /// @param lender The address of the lender
    /// @param borrower The address of the borrower
    /// @param vault The address of the vault associated with the pool
    /// @param loanToken The token to be loaned
    /// @param assetToken The token used as collateral
    /// @param repaymentToken The token used for loan repayment
    /// @param loanAmount The amount of the loan
    /// @param interestRate The interest rate of the loan
    /// @param repaymentPeriod The loan repayment period
    /// @param poolType The type of the pool (standard or flash loan)
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
        PoolType poolType
    
    ) external;

    /// @notice Deregisters a pool
    /// @param pool The address of the pool to deregister
    function deregisterPool(address pool) external;

    /// @notice Gets the total number of registered pools
    /// @return The total number of registered pools
    function getTotalPools() external view returns (uint256);

    /// @notice Retrieves all pool addresses associated with a specific lender
    /// @param lender The address of the lender
    /// @return An array of pool addresses
    function getPoolsByLender(address lender) external view returns (address[] memory);

    /// @notice Retrieves the loan state of a specific pool
    /// @param pool The address of the pool
    /// @return The loan state of the specified pool
    function getLoanState(address pool) external view returns (LoanState);

    /// @notice Updates the loan state of a specific pool
    /// @param pool The address of the pool
    /// @param newState The new state of the loan
    function updateLoanState(address pool, LoanState newState) external;

    /// @notice Retrieves detailed information about a specific pool
    /// @param pool The address of the pool
    /// @return The details of the specified pool
    function getPoolDetails(address pool) external view returns (PoolDetails memory);

    /// @notice Retrieves the associated vault address for a given pool
    /// @param pool The address of the pool
    /// @return The address of the linked vault
    function getVaultForPool(address pool) external view returns (address);

    /// @notice Grants factory access to manage pools
    /// @param factoryAddress The address of the factory to be granted access
    function grantFactoryAccess(address factoryAddress) external;

    /// @notice Registers a vault for a specific pool
    /// @param pool The address of the pool
    /// @param vault The address of the vault
    function registerVault(address pool, address vault) external;

    /// @notice Registers manager contracts for managing vaults and rewards
    /// @param _vaultManager The address of the VaultManager contract
    /// @param _rewardManager The address of the RewardManager contract
    function registerManagers(address _vaultManager, address _rewardManager) external;

    /// @notice Marks a pool as funded
    /// @param pool The address of the pool to mark as funded
    function markPoolAsFunded(address pool) external;
     
    /// @notice Sets the borrower for a specified pool
    /// @param pool The address of the pool
    /// @param newBorrower The address of the new borrower
    function setBorrowerForPool(address pool, address newBorrower) external;
}
