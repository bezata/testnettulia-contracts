// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./TuliaPool.sol";
import "./TuliaFlashPool.sol";
import "../interfaces/IPoolOrganizer.sol";
import "./TuliaVault.sol";
import "../interfaces/IInterestModel.sol";
import "../interfaces/IPermit2.sol";
import "../interfaces/IFeeManager.sol";
import "../interfaces/IRewardManager.sol";
import "../interfaces/IVaultManager.sol";

/// @title TuliaPoolFactory
/// @dev A factory for creating and managing TuliaPool and TuliaFlashPool contracts.
contract TuliaPoolFactory {
    IPoolOrganizer public poolOrganizer;
    IPermit2 public permit2;
    IFeeManager public feeManager;
    IRewardManager public rewardManager;
    IVaultManager public vaultManager;
    mapping(address => TuliaVault) public vaults;

    event PoolCreated(
        address indexed pool,
        address indexed lender,
        address indexed vault,
        IPoolOrganizer.PoolType poolType
    );
    event VaultCreated(address indexed vault, address assetToken);

    constructor(
        address _poolOrganizer,
        address _permit2,
        address _feeManager,
        address _rewardManager,
        address _vaultManager
    ) {
        require(
            _poolOrganizer != address(0),
            "PoolOrganizer cannot be the zero address"
        );
        require(_permit2 != address(0), "Permit2 cannot be the zero address");
        require(
            _feeManager != address(0),
            "FeeManager cannot be the zero address"
        );
        require(
            _rewardManager != address(0),
            "RewardManager cannot be the zero address"
        );
        require(
            _vaultManager != address(0),
            "VaultManager cannot be the zero address"
        );

        poolOrganizer = IPoolOrganizer(_poolOrganizer);
        permit2 = IPermit2(_permit2);
        feeManager = IFeeManager(_feeManager);
        rewardManager = IRewardManager(_rewardManager);
        vaultManager = IVaultManager(_vaultManager);
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
        address loanTokenAddress,
        IERC20 assetToken,
        address repaymentTokenAddress,
        uint256 loanAmount,
        uint256 interestRate,
        uint256 repaymentPeriod,
        IInterestModel interestModel,
        IPoolOrganizer.PoolType poolType,
        uint256 optionalFlashLoanFeeRate
    ) external returns (address poolAddress, address vaultAddress) {
        require(
            lender != address(0) && loanTokenAddress != address(0),
            "Invalid addresses"
        );
        poolOrganizer.registerManagers(
            address(vaultManager),
            address(rewardManager)
        );
        if (poolType == IPoolOrganizer.PoolType.STANDARD) {
            string memory name = string(
                abi.encodePacked(
                    "TuliaVault",
                    IERC20Metadata(address(assetToken)).symbol()
                )
            );
            string memory symbol = string(
                abi.encodePacked(
                    "TV",
                    IERC20Metadata(address(assetToken)).symbol()
                )
            );
            TuliaVault vault = new TuliaVault(
                assetToken,
                name,
                symbol,
                permit2
            );
            emit VaultCreated(address(vault), address(assetToken));

            TuliaPool pool = new TuliaPool(
                lender,
                loanTokenAddress,
                repaymentTokenAddress,
                address(vault),
                loanAmount,
                interestRate,
                repaymentPeriod,
                interestModel,
                permit2,
                address(poolOrganizer),
                address(rewardManager),
                address(vaultManager)
            );

            poolOrganizer.registerPool(
                address(pool),
                lender,
                address(0),
                address(vault),
                loanTokenAddress,
                address(assetToken),
                loanAmount,
                interestRate,
                repaymentPeriod,
                poolType
            );
            vaultManager.registerPoolVault(address(pool), address(vault));
            rewardManager.registerPool(address(pool), loanTokenAddress);
            rewardManager.setRewardToken(address(pool), loanTokenAddress);
            poolOrganizer.registerVault(address(pool), address(vault));
            emit PoolCreated(address(pool), lender, address(vault), poolType);
            return (address(pool), address(vault));
        } else if (poolType == IPoolOrganizer.PoolType.FLASH_LOAN) {
            TuliaFlashPool pool = new TuliaFlashPool(
                IERC20(loanTokenAddress),
                permit2,
                feeManager,
                optionalFlashLoanFeeRate
            );

            poolOrganizer.registerPool(
                address(pool),
                lender,
                address(0),
                address(0),
                loanTokenAddress,
                address(assetToken),
                loanAmount,
                interestRate,
                repaymentPeriod,
                poolType
            );
            vaultManager.registerPoolVault(address(pool), address(0));
            rewardManager.setRewardToken(address(pool), loanTokenAddress);
            rewardManager.registerPool(address(pool), loanTokenAddress);

            emit PoolCreated(address(pool), lender, address(0), poolType);
            return (address(pool), address(0));
        }

        revert("Unsupported pool type");
    }
}
