// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./TuliaPool.sol";
import "./TuliaFlashPool.sol";
import "../interfaces/IPoolOrganizer.sol";
import "./TuliaVault.sol";
import "../interfaces/IInterestModel.sol";
import "../interfaces/IRewardManager.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IFlashPoolRewardManager.sol";

/// @title TuliaPoolFactory
/// @dev A factory for creating and managing TuliaPool and TuliaFlashPool contracts.
contract TuliaPoolFactory {
    IPoolOrganizer public poolOrganizer;
    IRewardManager public rewardManager;
    IVaultManager public vaultManager;
    IFlashPoolRewardManager public flashPoolRewardManager;
    mapping(address => TuliaVault) public vaults;

    /// @notice Emitted when a new pool is created.
    /// @param pool The address of the newly created pool.
    /// @param lender The address of the lender initiating the pool.
    /// @param vault The address of the vault associated with the pool.
    /// @param poolType The type of the pool (standard or flash loan).
    event PoolCreated(
        address indexed pool,
        address indexed lender,
        address indexed vault,
        IPoolOrganizer.PoolType poolType
    );

    /// @notice Emitted when a new vault is created.
    /// @param vault The address of the newly created vault.
    /// @param assetToken The address of the asset token used as collateral.
    event VaultCreated(address indexed vault, address assetToken);

    /// @notice Constructs the TuliaPoolFactory contract.
    /// @param _poolOrganizer The address of the Pool Organizer contract.
    /// @param _rewardManager The address of the Reward Manager contract.
    /// @param _vaultManager The address of the Vault Manager contract.
    constructor(
        address _poolOrganizer,
        address _rewardManager,
        address _vaultManager,
        address _flashPoolRewardManager
    ) {
        require(
            _poolOrganizer != address(0),
            "PoolOrganizer cannot be the zero address"
        );
        require(
            _rewardManager != address(0),
            "RewardManager cannot be the zero address"
        );
        require(
            _vaultManager != address(0),
            "VaultManager cannot be the zero address"
        );
         require(
            _flashPoolRewardManager != address(0),
            "FlashPoolRewardManager cannot be the zero address"
        );

        poolOrganizer = IPoolOrganizer(_poolOrganizer);
        rewardManager = IRewardManager(_rewardManager);
        vaultManager = IVaultManager(_vaultManager);
        flashPoolRewardManager = IFlashPoolRewardManager(_flashPoolRewardManager);
    }

    /// @notice Creates a new TuliaPool or TuliaFlashPool depending on the specified pool type.
    /// @param lender Address of the lender initiating the pool.
    /// @param loanTokenAddress ERC20 token address to be loaned.
    /// @param assetToken ERC20 token address used as collateral.
    /// @param repaymentTokenAddress ERC20 token address for repayments.
    /// @param loanAmount Amount of the loan.
    /// @param interestRate Interest rate for the loan.
    /// @param repaymentPeriod Duration over which the loan must be repaid.
    /// @param interestModel Address of the contract calculating interest.
    /// @param poolType Type of the pool to create (standard or flash loan).
    /// @param optionalFlashLoanFeeRate Fee rate for flash loans if applicable.
    /// @return poolAddress Address of the newly created pool.
    /// @return vaultAddress Address of the vault associated with the pool, if applicable.
    function createTuliaPool(
        address lender,
        IERC20 loanTokenAddress,
        IERC20 assetToken,
        IERC20 repaymentTokenAddress,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 repaymentPeriod,
        IInterestModel interestModel,
        IPoolOrganizer.PoolType poolType,
        uint256 optionalFlashLoanFeeRate
    ) external returns (address poolAddress, address vaultAddress) {
        require(lender != address(0) && address(loanTokenAddress) != address(0), "Invalid addresses");

        // Prepare data for potential vault creation
        string memory symbol = string(abi.encodePacked("TV", IERC20Metadata(address(assetToken)).symbol()));
        string memory name = string(abi.encodePacked("TuliaVault", IERC20Metadata(address(assetToken)).symbol()));
        TuliaVault vault;
        bool isStandardPool = (poolType == IPoolOrganizer.PoolType.STANDARD);

        // Create vault if pool type is STANDARD
        if (isStandardPool) {
            vault = new TuliaVault(IERC20(assetToken), name, symbol);
            emit VaultCreated(address(vault), address(assetToken));
        }

        // Handle different pool types
        if (isStandardPool) {
            TuliaPool pool = new TuliaPool(
                lender,
                loanTokenAddress,
                repaymentTokenAddress,
                address(vault),
                loanAmount,
                interestRate,
                repaymentPeriod,
                interestModel,
                address(poolOrganizer),
                address(vaultManager),
                address(rewardManager)
            );
            poolOrganizer.registerPool(
                address(pool),
                lender,
                address(0), 
                address(vault),
                loanTokenAddress,
                assetToken,
                repaymentTokenAddress,
                loanAmount,
                interestRate,
                repaymentPeriod,
                poolType

            );
            poolOrganizer.grantFactoryAccess(address(pool));
            emit PoolCreated(address(pool), lender, address(vault), poolType);
            return (address(pool), address(vault));
        } else if (poolType == IPoolOrganizer.PoolType.FLASH_LOAN) {
            TuliaFlashPool flashPool = new TuliaFlashPool(
                IERC20(loanTokenAddress),
                optionalFlashLoanFeeRate,
                poolOrganizer,
                flashPoolRewardManager,
                loanAmount
            );
            poolOrganizer.registerPool(
                address(flashPool),
                lender,
                address(0),
                address(0), 
                loanTokenAddress,
                assetToken,
                repaymentTokenAddress,
                loanAmount,
                interestRate,
                0,
                poolType
              
            );
            poolOrganizer.grantFactoryAccess(address(flashPool));
            emit PoolCreated(address(flashPool), lender, address(0), poolType);
            return (address(flashPool), address(0));
        }

        revert("Unsupported pool type");
    }
}
