// ignition/modules/DeployAll.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const SimpleInterest = require("./SimpleInterest");
const AdvancedAPYManager = require("./AdvancedAPYManager");
const EmissionManager = require("./EmissionManager");
const RewardManager = require("./RewardManager");
const VaultManager = require("./VaultManager");
const PoolOrganizer = require("./PoolOrganizer");
const BulkMinter = require("./BulkMinter");
const MockDAI = require("./MockDAI");
const MockUSDC = require("./MockUSDC");
const MockUNI = require("./MockUNI");
const MockWBTC = require("./MockWBTC");
const MockETH = require("./MockETH");
const MockARB = require("./MockARB");
const MockTulia = require("./MockTulia");

module.exports = buildModule("DeployAll", (m) => {

  const { rewardManager } = m.useModule(RewardManager);

  return {
    rewardManager,
  };
});
