// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../protocol/TuliaVault.sol";
import "../protocol/TuliaPool.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/IPermit2.sol";

/// @title VaultManager
/// @dev Manages interest payouts and interactions between TuliaPools and their respective TuliaVaults.
contract VaultManager is IVaultManager {
    using SafeERC20 for IERC20;

    // Maps pools to their respective vaults
    mapping(address => address) public poolVaults;

    // Event declarations for tracking state changes
    event InterestPaid(address indexed pool, address indexed to, uint256 amount);
    event VaultDeregistered(address indexed pool);

    /// @notice Links a pool to a vault upon pool creation.
    /// @param pool Address of the pool.
    /// @param vault Address of the vault associated with the pool.
    function registerPoolVault(address pool, address vault) external override {
        require(poolVaults[pool] == address(0), "Vault already registered");
        poolVaults[pool] = vault;
    }

    /// @notice Handles the distribution of interest to a borrower from the vault.
    /// @param pool Address of the pool initiating the interest payout.
    /// @param to Address to which the interest will be paid.
    /// @param amount Amount of interest to be paid.
    function distributeInterest(address pool, address to, uint256 amount) external override {
        address vaultAddress = poolVaults[pool];
        require(vaultAddress != address(0), "No vault registered for this pool");

        TuliaVault vault = TuliaVault(vaultAddress);
        IERC20 underlying = IERC20(vault.asset());
        underlying.safeTransferFrom(vaultAddress, to, amount);
        emit InterestPaid(pool, to, amount);
    }

    /// @notice Deregisters a vault when a loan is closed.
    /// @param pool Address of the pool whose vault is to be deregistered.
    function deregisterVault(address pool) external {
        require(poolVaults[pool] != address(0), "No vault registered for this pool");
        delete poolVaults[pool];
        emit VaultDeregistered(pool);
    }

    /// @notice Calculates the claimable interest for a user based on the loan configuration.
    /// @param pool Address of the pool for which to calculate the interest.
    /// @param user Address of the user (borrower).
    /// @return The calculated interest amount.
    function calculateClaimableInterest(address pool, address user) external view override returns (uint256) {
        TuliaPool tuliaPool = TuliaPool(pool);
        TuliaVault vault = TuliaVault(poolVaults[pool]);

        uint256 loanAmount = tuliaPool.getLoanAmount();
        uint256 interestRate = tuliaPool.getInterestRate();
        uint256 repaymentPeriod = tuliaPool.getRepaymentPeriod();

        uint256 totalCollateral = vault.balanceOf(user);
        uint256 interestDeducted = (loanAmount * interestRate) / 10000; // Assuming interestRate is a percentage in basis points
        uint256 netCollateral = totalCollateral > interestDeducted ? totalCollateral - interestDeducted : 0;

        // Calculates interest per block
        uint256 interestPerBlock = netCollateral / repaymentPeriod;
        uint256 blocksSinceFunded = block.number - tuliaPool.getFundedBlock();

        return interestPerBlock * blocksSinceFunded;
    }
}
