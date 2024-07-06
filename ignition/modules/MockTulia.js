const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockTulia", (m) => {
  const mockTulia = m.contract("MockTokenCreator", ["MockTulia", "mTulia"]);
  return { mockTulia };
});
