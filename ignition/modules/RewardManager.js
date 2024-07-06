// ignition/modules/RewardManager.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const AdvancedAPYManager = require("./AdvancedAPYManager");

module.exports = buildModule("RewardManager", (m) => {
  const { advancedAPYManager } = m.useModule(AdvancedAPYManager);
  const rewardManager = m.contract("RewardManager", [advancedAPYManager]);

  return { rewardManager };
});
