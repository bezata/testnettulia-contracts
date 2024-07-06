const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockUSDC", (m) => {
  const mockUSDC = m.contract("MockTokenCreator", ["MockUSDC", "mUSDC"]);
  return { mockUSDC };
});
