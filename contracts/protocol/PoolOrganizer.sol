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
    mapping(address => LoanState) private loanStates;

    /**
     * @dev Emitted when a new pool is registered.
     * @param pool The address of the pool.
     * @param lender The address of the lender.
     * @param borrower The address of the borrower.
     * @param vault The address of the vault associated with the pool.
     * @param poolType The type of the pool.
     */
    event PoolRegistered(
        address indexed pool,
        address indexed lender,
        address indexed borrower,
        address vault,
        PoolType poolType
    );

    /**
     * @dev Emitted when a pool is deregistered.
     * @param pool The address of the deregistered pool.
     */
    event PoolDeregistered(address indexed pool);

    /**
     * @dev Emitted when managers are registered.
     * @param vaultManager The address of the vault manager.
     * @param rewardManager The address of the reward manager.
     */
    event ManagerRegistered(address vaultManager, address rewardManager);

    /**
     * @dev Emitted when a vault is registered for a pool.
     * @param pool The address of the pool.
     * @param vault The address of the registered vault.
     */
    event VaultRegistered(address indexed pool, address indexed vault);

    /**
     * @dev Emitted when the loan state of a pool is updated.
     * @param pool The address of the pool.
     * @param oldState The previous state of the loan.
     * @param newState The new state of the loan.
     */
    event LoanStateUpdated(
        address indexed pool,
        LoanState oldState,
        LoanState newState
    );

    /**
     * @dev Constructor that grants the deployer the admin and pool manager roles.
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, 0x4fa390F2f1f74403504d7A490B47F0c2BC0ACE48);
        _grantRole(POOL_MANAGER_ROLE, 0x4fa390F2f1f74403504d7A490B47F0c2BC0ACE48);
    }

    /**
     * @notice Registers a new pool with the specified details.
     * @dev Registers a pool and emits a `PoolRegistered` event.
     * @param pool The address of the pool.
     * @param lender The address of the lender.
     * @param borrower The address of the borrower.
     * @param vault The address of the vault.
     * @param loanToken The ERC20 token for the loan.
     * @param assetToken The ERC20 token for the asset.
     * @param repaymentToken The ERC20 token for the repayment.
     * @param loanAmount The amount of the loan.
     * @param interestRate The interest rate for the loan.
     * @param repaymentPeriod The repayment period for the loan.
     * @param poolType The type of the pool.
     */
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
    ) external {
        require(pool != address(0), "Pool address cannot be zero");
        require(
            poolDetails[pool].lender == address(0),
            "Pool already registered"
        );

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
            funded: false,
            loanState: LoanState.CREATED,
            pool: pool
        });
        lenderPools[lender].push(pool);
        pools.push(pool);
        loanStates[pool] = LoanState.CREATED;
        emit PoolRegistered(pool, lender, borrower, vault, poolType);
    }

    /**
     * @notice Updates the loan state of the specified pool and emits a `LoanStateUpdated` event.
     * @param pool The address of the pool.
     * @param newState The new state of the loan.
     */
    function updateLoanState(address pool, LoanState newState) external {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        LoanState oldState = loanStates[pool];
        loanStates[pool] = newState;
        emit LoanStateUpdated(pool, oldState, newState);
    }

    /**
     * @notice Marks a pool as funded.
     * @dev Marks the specified pool as funded.
     * @param pool The address of the pool to mark as funded.
     */
    function markPoolAsFunded(address pool) external {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        poolDetails[pool].funded = true;
    }

    /**
     * @notice Gets the current loan state of a specific pool.
     * @param pool The address of the pool.
     * @return The current loan state of the pool.
     */
    function getLoanState(address pool) external view returns (LoanState) {
        return loanStates[pool];
    }

    /**
     * @notice Gets the details of all pools associated with a lender.
     * @param lender The address of the lender.
     * @return An array of pool details.
     */
    function getAllLenderPoolDetails(address lender)
        external
        view
        returns (IPoolOrganizer.PoolDetails[] memory)
    {
        address[] memory lenderPoolsArray = lenderPools[lender];
        IPoolOrganizer.PoolDetails[]
            memory details = new IPoolOrganizer.PoolDetails[](
                lenderPoolsArray.length
            );

        for (uint256 i = 0; i < lenderPoolsArray.length; i++) {
            details[i] = poolDetails[lenderPoolsArray[i]];
        }
        return details;
    }

    /**
     * @notice Gets all pools associated with a borrower.
     * @param borrower The address of the borrower.
     * @return An array of pool addresses.
     */
    function getPoolsByBorrower(address borrower)
        external
        view
        returns (address[] memory)
    {
        return borrowerPools[borrower];
    }

    /**
     * @notice Gets the details of all pools associated with a borrower.
     * @param borrower The address of the borrower.
     * @return An array of pool details.
     */
    function getBorrowerPoolDetails(address borrower)
        external
        view
        returns (IPoolOrganizer.PoolDetails[] memory)
    {
        address[] memory borrowerPoolsArray = borrowerPools[borrower];
        IPoolOrganizer.PoolDetails[]
            memory details = new IPoolOrganizer.PoolDetails[](
                borrowerPoolsArray.length
            );

        for (uint256 i = 0; i < borrowerPoolsArray.length; i++) {
            details[i] = poolDetails[borrowerPoolsArray[i]];
        }
        return details;
    }

    /**
     * @notice Deregisters a pool.
     * @dev Deregisters the specified pool and emits a `PoolDeregistered` event.
     * @param pool The address of the pool to deregister.
     */
    function deregisterPool(address pool) external {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        address borrower = poolDetails[pool].borrower;
        address lender = poolDetails[pool].lender;
        _removePoolFromLenderArray(lender, pool);
        _removePoolFromMainArray(pool);
        _removePoolFromBorrowerArray(borrower, pool);

        delete poolDetails[pool];
        delete loanStates[pool];
        emit PoolDeregistered(pool);
    }

    /**
     * @notice Sets the borrower for a specified pool.
     * @param pool The address of the pool.
     * @param newBorrower The address of the new borrower.
     */
    function setBorrowerForPool(address pool, address newBorrower) external {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        require(
            newBorrower != address(0),
            "Borrower cannot be the zero address"
        );

        address currentBorrower = poolDetails[pool].borrower;
        if (currentBorrower != newBorrower) {
            if (currentBorrower != address(0)) {
                _removePoolFromBorrowerArray(currentBorrower, pool);
            }
            borrowerPools[newBorrower].push(pool);
            poolDetails[pool].borrower = newBorrower;
        }
    }

    /**
     * @notice Registers the vault and reward managers.
     * @dev Registers the specified managers and emits a `ManagerRegistered` event.
     * @param _vaultManager The address of the vault manager.
     * @param _rewardManager The address of the reward manager.
     */
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

    /**
     * @notice Gets the addresses of the registered managers.
     * @return The addresses of the vault and reward managers.
     */
    function getManagers() external view returns (address, address) {
        return (address(vaultManager), address(rewardManager));
    }

    /**
     * @notice Gets the total number of registered pools.
     * @return The total number of pools.
     */
    function getTotalPools() external view returns (uint256) {
        return pools.length;
    }

    /**
     * @notice Gets all pools associated with a lender.
     * @param lender The address of the lender.
     * @return An array of pool addresses.
     */
    function getPoolsByLender(address lender)
        external
        view
        returns (address[] memory)
    {
        return lenderPools[lender];
    }

    /**
     * @notice Gets the details of a specified pool.
     * @param pool The address of the pool.
     * @return The details of the pool.
     */
    function getPoolDetails(address pool)
        external
        view
        returns (IPoolOrganizer.PoolDetails memory)
    {
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        return poolDetails[pool];
    }

    /**
     * @notice Gets the vault address associated with a pool.
     * @param pool The address of the pool.
     * @return The address of the vault.
     */
    function getVaultForPool(address pool) external view returns (address) {
        require(
            poolVaults[pool] != address(0),
            "Pool not registered or has no vault"
        );
        return poolVaults[pool];
    }

    /**
     * @notice Gets all registered pool addresses.
     * @return An array of pool addresses.
     */
    function getAllPoolAddresses() external view returns (address[] memory) {
        return pools;
    }

    /**
     * @notice Grants factory access to the specified address.
     * @param factoryAddress The address of the factory.
     */
    function grantFactoryAccess(address factoryAddress) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Caller is not an admin"
        );
        grantRole(POOL_MANAGER_ROLE, factoryAddress);
        grantRole(DEFAULT_ADMIN_ROLE, factoryAddress);
    }

    /**
     * @notice Registers a vault for a specified pool.
     * @dev Registers the specified vault for the pool and emits a `VaultRegistered` event.
     * @param pool The address of the pool.
     * @param vault The address of the vault.
     */
    function registerVault(address pool, address vault) external {
        require(pool != address(0) && vault != address(0), "Invalid addresses");
        require(poolDetails[pool].lender != address(0), "Pool not registered");
        require(
            poolVaults[pool] == address(0),
            "Vault already registered for this pool"
        );

        poolVaults[pool] = vault;
        emit VaultRegistered(pool, vault);
    }

    // Private helper functions

    /**
     * @dev Removes a pool from the lender's array of pools.
     * @param lender The address of the lender.
     * @param pool The address of the pool.
     */
    function _removePoolFromLenderArray(address lender, address pool) private {
        uint256 index = findIndexInArray(lenderPools[lender], pool);
        uint256 lastIndex = lenderPools[lender].length - 1;
        lenderPools[lender][index] = lenderPools[lender][lastIndex];
        lenderPools[lender].pop();
    }

    /**
     * @dev Removes a pool from the main array of pools.
     * @param pool The address of the pool.
     */
    function _removePoolFromMainArray(address pool) private {
        uint256 index = findIndexInArray(pools, pool);
        uint256 lastIndex = pools.length - 1;
        pools[index] = pools[lastIndex];
        pools.pop();
    }

    /**
     * @dev Finds the index of a target address in an array.
     * @param array The array to search.
     * @param target The target address.
     * @return The index of the target address.
     */
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

    /**
     * @dev Removes a pool from the borrower's array of pools.
     * @param borrower The address of the borrower.
     * @param pool The address of the pool.
     */
    function _removePoolFromBorrowerArray(address borrower, address pool)
        private
    {
        uint256 index = findIndexInArray(borrowerPools[borrower], pool);
        if (index < borrowerPools[borrower].length) {
            uint256 lastIndex = borrowerPools[borrower].length - 1;
            borrowerPools[borrower][index] = borrowerPools[borrower][lastIndex];
            borrowerPools[borrower].pop();
        }
    }
}
