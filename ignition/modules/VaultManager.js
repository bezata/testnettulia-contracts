// ignition/modules/VaultManager.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("VaultManager", (m) => {
  const vaultManager = m.contract("VaultManager");

  return { vaultManager };
});
