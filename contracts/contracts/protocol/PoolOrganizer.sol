// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IPoolOrganizer.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IRewardManager.sol";

/// @title Pool Organizer for managing pools, vaults, and rewards.
/// @dev Implements access control and management for pool lifecycle and integration with external managers.
contract PoolOrganizer is AccessControl, IPoolOrganizer {
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");

    IVaultManager public vaultManager;
    IRewardManager public rewardManager;

    address[] private pools;
    mapping(address => PoolDetails) private poolDetails;
    mapping(address => address[]) private lenderPools;
    mapping(address => address) public poolVaults;

    /// @dev Emitted when a pool is registered.
    event PoolRegistered(
        address indexed pool,
        address indexed lender,
        address indexed borrower,
        address vault,
        PoolType poolType
    );
    /// @dev Emitted when a pool is deregistered.
    event PoolDeregistered(address indexed pool);
    /// @dev Emitted when managers are registered.
    event ManagerRegistered(address vaultManager, address rewardManager);

    event VaultRegistered(address indexed pool, address indexed vault);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
    }

    /// @notice Registers a new pool within the organizer.
    /// @param pool The address of the new pool.
    /// @param lender The address of the lender.
    /// @param borrower The address of the borrower (if known at this point, otherwise zero).
    /// @param vault The address of the vault associated with the pool.
    /// @param loanToken The address of the loan token.
    /// @param assetToken The address of the asset token used as collateral.
    /// @param repaymentToken address of the repaymentToken
    /// @param loanAmount The amount of the loan.
    /// @param interestRate The interest rate of the loan.
    /// @param repaymentPeriod The period over which the loan is to be repaid.
    /// @param poolType The type of the pool (standard or flash).
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
    ) external onlyRole(POOL_MANAGER_ROLE) {
        require(pool != address(0), "Pool address cannot be zero");
        require(
            poolDetails[pool].lender == address(0),
            "Pool already registered"
        );

        poolDetails[pool] = PoolDetails({
            lender: lender,
            borrower: borrower,
            creationTime: block.timestamp,
            vault: vault,
            loanToken: loanToken,
            assetToken: assetToken,
            repaymentToken: repaymentToken,
            loanAmount: loanAmount,
            interestRate: interestRate,
            repaymentPeriod: repaymentPeriod,
            poolType: poolType
        });
        lenderPools[lender].push(pool);
        pools.push(pool);
        emit PoolRegistered(pool, lender, borrower, vault, poolType);
    }

    /// @notice Deregisters a pool from the organizer.
    /// @param pool The address of the pool to deregister.
    function deregisterPool(address pool) external onlyRole(POOL_MANAGER_ROLE) {
        require(poolDetails[pool].lender != address(0), "Pool not registered");

        address lender = poolDetails[pool].lender;
        _removePoolFromLenderArray(lender, pool);
        _removePoolFromMainArray(pool);

        delete poolDetails[pool];
        emit PoolDeregistered(pool);
    }

    /// @notice Registers the manager contracts for managing vaults and rewards.
    /// @param _vaultManager Address of the VaultManager contract.
    /// @param _rewardManager Address of the RewardManager contract.
    function registerManagers(address _vaultManager, address _rewardManager)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _vaultManager != address(0),
            "VaultManager cannot be zero address"
        );
        require(
            _rewardManager != address(0),
            "RewardManager cannot be zero address"
        );

        vaultManager = IVaultManager(_vaultManager);
        rewardManager = IRewardManager(_rewardManager);

        emit ManagerRegistered(_vaultManager, _rewardManager);
    }

    /// @notice Returns the addresses of the VaultManager and RewardManager.
    /// @return A tuple containing the addresses of the VaultManager and RewardManager.
    function getManagers() external view returns (address, address) {
        return (address(vaultManager), address(rewardManager));
    }

    /// @notice Retrieves the total number of registered pools.
    /// @return The total number of pools.
    function getTotalPools() external view returns (uint256) {
        return pools.length;
    }

    /// @notice Retrieves all pools associated with a specific lender.
    /// @param lender The address of the lender.
    /// @return An array of pool addresses.
    function getPoolsByLender(address lender)
        external
        view
        returns (address[] memory)
    {
        return lenderPools[lender];
    }

    /// @notice Retrieves details for a specific pool.
    /// @param pool The address of the pool.
    /// @return Details of the specified pool.
    function getPoolDetails(address pool)
        external
        view
        returns (PoolDetails memory)
    {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        return poolDetails[pool];
    }

    /// @notice Retrieves the vault associated with a specific pool.
    /// @param pool The address of the pool.
    /// @return The address of the vault linked to the pool.
       function getVaultForPool(address pool) external view returns (address) {
        require(
            poolVaults[pool] != address(0),
            "Pool not registered or has no vault"
        );
        return poolVaults[pool];
    }


    /// @notice Grants factory access to manage pools.
    /// @param factoryAddress The address of the factory to be granted access.
    function grantFactoryAccess(address factoryAddress) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not an admin"
        );
        grantRole(POOL_MANAGER_ROLE, factoryAddress);
    }

    // Private helper functions
    function _removePoolFromLenderArray(address lender, address pool) private {
        uint256 index = findIndexInArray(lenderPools[lender], pool);
        uint256 lastIndex = lenderPools[lender].length - 1;
        lenderPools[lender][index] = lenderPools[lender][lastIndex];
        lenderPools[lender].pop();
    }

    function _removePoolFromMainArray(address pool) private {
        uint256 index = findIndexInArray(pools, pool);
        uint256 lastIndex = pools.length - 1;
        pools[index] = pools[lastIndex];
        pools.pop();
    }

    function findIndexInArray(address[] storage array, address target)
        private
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) return i;
        }
        return type(uint256).max; // Indicates not found
    }

    /// @notice Registers a vault for a given pool.
    /// @param pool The address of the pool for which the vault is being registered.
    /// @param vault The address of the newly created vault.
    /// @dev This function can only be called by authorized roles, typically the PoolFactory.
     function registerVault(address pool, address vault)
        external
        onlyRole(POOL_MANAGER_ROLE)
    {
        require(pool != address(0) && vault != address(0), "Invalid addresses");
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        require(
            poolVaults[pool] == address(0),
            "Vault already registered for this pool"
        );

        poolVaults[pool] = vault;
        emit VaultRegistered(pool, vault);
    }
}
