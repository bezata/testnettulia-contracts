// ignition/modules/RewardManager.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("RewardManager", (m) => {
  const rewardManager = m.contract("RewardManager", [
    "0x84F2b371A76F1178E5f0560f36b39118FD4aAdb9",
  ]);

  return { rewardManager };
});
