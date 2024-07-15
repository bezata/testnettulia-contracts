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
const FlashPoolRewardManager = require("./FlashPoolRewardManager");

module.exports = buildModule("DeployAll", (m) => {

  const { rewardManager } = m.useModule(RewardManager);
  const { advancedAPYManager } = m.useModule(AdvancedAPYManager);
  const { emissionManager } = m.useModule(EmissionManager);
  const { simpleInterest } = m.useModule(SimpleInterest);
  const { vaultManager } = m.useModule(VaultManager);
  const { poolOrganizer } = m.useModule(PoolOrganizer);
  const { bulkMinter } = m.useModule(BulkMinter);
  const { mockDAI } = m.useModule(MockDAI);
  const { mockUSDC } = m.useModule(MockUSDC);
  const { mockUNI } = m.useModule(MockUNI);
  const { mockWBTC } = m.useModule(MockWBTC);
  const { mockETH } = m.useModule(MockETH);
  const { mockARB } = m.useModule(MockARB);
  const { mockTulia } = m.useModule(MockTulia);
  const { flashPoolRewardManager } = m.useModule(FlashPoolRewardManager);


  return {
    rewardManager,
    advancedAPYManager,
    emissionManager,
    simpleInterest,
    vaultManager,
    poolOrganizer,
    bulkMinter,
    mockDAI,
    mockUSDC,
    mockUNI,
    mockWBTC,
    mockETH,
    mockARB,
    mockTulia,
    flashPoolRewardManager
  };
});
