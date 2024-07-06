const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockUNI", (m) => {
  const mockUNI = m.contract("MockTokenCreator", ["MockUNI", "mUNI"]);
  return { mockUNI };
});
