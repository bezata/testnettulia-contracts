// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IPoolOrganizer.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IRewardManager.sol";

/**
 * @title Pool Organizer for managing pools, vaults, and rewards.
 * @dev Implements access control and management for pool lifecycle and integration with external managers.
 */
contract PoolOrganizer is AccessControl, IPoolOrganizer {
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");

    IVaultManager public vaultManager;
    IRewardManager public rewardManager;

    address[] private pools;
    mapping(address => IPoolOrganizer.PoolDetails) private poolDetails;
    mapping(address => address[]) private lenderPools;
    mapping(address => address) public poolVaults;
    mapping(address => address[]) private borrowerPools;

    event PoolRegistered(
        address indexed pool,
        address indexed lender,
        address indexed borrower,
        address vault,
        PoolType poolType
    );
    event PoolDeregistered(address indexed pool);
    event ManagerRegistered(address vaultManager, address rewardManager);
    event VaultRegistered(address indexed pool, address indexed vault);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
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
        PoolType poolType
    ) external onlyRole(POOL_MANAGER_ROLE) {
        require(pool != address(0), "Pool address cannot be zero");
        require(poolDetails[pool].lender == address(0), "Pool already registered");

        poolDetails[pool] = IPoolOrganizer.PoolDetails({
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
            poolType: poolType,
            funded: false
        });
        lenderPools[lender].push(pool);
        pools.push(pool);
        emit PoolRegistered(pool, lender, borrower, vault, poolType);
    }

    function markPoolAsFunded(address pool) external onlyRole(POOL_MANAGER_ROLE) {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        poolDetails[pool].funded = true;
    }

    function getAllLenderPoolDetails(address lender) external view returns (IPoolOrganizer.PoolDetails[] memory) {
        address[] memory lenderPoolsArray = lenderPools[lender];
        IPoolOrganizer.PoolDetails[] memory details = new IPoolOrganizer.PoolDetails[](lenderPoolsArray.length);

        for (uint256 i = 0; i < lenderPoolsArray.length; i++) {
            details[i] = poolDetails[lenderPoolsArray[i]];
        }
        return details;
    }

    function deregisterPool(address pool) external onlyRole(POOL_MANAGER_ROLE) {
        require(poolDetails[pool].lender != address(0), "Pool not registered");

        address lender = poolDetails[pool].lender;
        _removePoolFromLenderArray(lender, pool);
        _removePoolFromMainArray(pool);

        delete poolDetails[pool];
        emit PoolDeregistered(pool);
    }

    function setBorrowerForPool(address pool, address newBorrower) external onlyRole(POOL_MANAGER_ROLE) {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        require(newBorrower != address(0), "Borrower cannot be the zero address");

        address currentBorrower = poolDetails[pool].borrower;
        if (currentBorrower != newBorrower) {
            if (currentBorrower != address(0)) {
                _removePoolFromBorrowerArray(currentBorrower, pool);
            }
            borrowerPools[newBorrower].push(pool);
            poolDetails[pool].borrower = newBorrower;
        }
    }

    function _removePoolFromBorrowerArray(address borrower, address pool) private {
        uint256 index = findIndexInArray(borrowerPools[borrower], pool);
        if (index < borrowerPools[borrower].length) {
            uint256 lastIndex = borrowerPools[borrower].length - 1;
            borrowerPools[borrower][index] = borrowerPools[borrower][lastIndex];
            borrowerPools[borrower].pop();
        }
    }

    function getAllBorrowerPoolDetails(address borrower) external view returns (IPoolOrganizer.PoolDetails[] memory) {
        address[] memory borrowerPoolsArray = borrowerPools[borrower];
        IPoolOrganizer.PoolDetails[] memory details = new IPoolOrganizer.PoolDetails[](borrowerPoolsArray.length);

        for (uint256 i = 0; i < borrowerPoolsArray.length; i++) {
            details[i] = poolDetails[borrowerPoolsArray[i]];
        }
        return details;
    }

    function registerManagers(address _vaultManager, address _rewardManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_vaultManager != address(0), "VaultManager cannot be zero address");
        require(_rewardManager != address(0), "RewardManager cannot be zero address");

        vaultManager = IVaultManager(_vaultManager);
        rewardManager = IRewardManager(_rewardManager);

        emit ManagerRegistered(_vaultManager, _rewardManager);
    }

    function getManagers() external view returns (address, address) {
        return (address(vaultManager), address(rewardManager));
    }

    function getTotalPools() external view returns (uint256) {
        return pools.length;
    }

    function getPoolsByLender(address lender) external view returns (address[] memory) {
        return lenderPools[lender];
    }

    function getPoolDetails(address pool) external view returns (IPoolOrganizer.PoolDetails memory) {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        return poolDetails[pool];
    }

    function getVaultForPool(address pool) external view returns (address) {
        require(poolVaults[pool] != address(0), "Pool not registered or has no vault");
        return poolVaults[pool];
    }

    function grantFactoryAccess(address factoryAddress) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Caller is not an admin");
        grantRole(POOL_MANAGER_ROLE, factoryAddress);
        grantRole(DEFAULT_ADMIN_ROLE, factoryAddress);
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

    function findIndexInArray(address[] storage array, address target) private view returns (uint256) {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == target) return i;
        }
        return type(uint256).max; // Indicates not found
    }

    function registerVault(address pool, address vault) external onlyRole(POOL_MANAGER_ROLE) {
        require(pool != address(0) && vault != address(0), "Invalid addresses");
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        require(poolVaults[pool] == address(0), "Vault already registered for this pool");

        poolVaults[pool] = vault;
        emit VaultRegistered(pool, vault);
   
    }
}