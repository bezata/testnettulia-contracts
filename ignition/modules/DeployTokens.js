const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const MockDAI = require("./MockDAI");
const MockUSDC = require("./MockUSDC");
const MockUNI = require("./MockUNI");
const MockWBTC = require("./MockWBTC");
const MockETH = require("./MockETH");
const MockARB = require("./MockARB");
const MockTulia = require("./MockTulia");

module.exports = buildModule("DeployTokens", (m) => {
  const { mockDAI } = m.useModule(MockDAI);
  const { mockUSDC } = m.useModule(MockUSDC);
  const { mockUNI } = m.useModule(MockUNI);
  const { mockWBTC } = m.useModule(MockWBTC);
  const { mockETH } = m.useModule(MockETH);
  const { mockARB } = m.useModule(MockARB);
  const { mockTulia } = m.useModule(MockTulia);

  return {
    mockDAI,
    mockUSDC,
    mockUNI,
    mockWBTC,
    mockETH,
    mockARB,
    mockTulia,
  };
});
