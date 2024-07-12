// ignition/modules/RewardManager.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("RewardManager", (m) => {
  const rewardManager = m.contract("RewardManager", [
    "0x4e6acfc41ca9c367Af36352023f985f0B4DDEd28",
  ]);

  return { rewardManager };
});
