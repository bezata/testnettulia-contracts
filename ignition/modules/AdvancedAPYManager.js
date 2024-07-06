// ignition/modules/AdvancedAPYManager.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("AdvancedAPYManager", (m) => {
  const advancedAPYManager = m.contract("AdvancedAPYManager");

  return { advancedAPYManager };
});
