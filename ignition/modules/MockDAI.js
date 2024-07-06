const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockDAI", (m) => {
  const mockDAI = m.contract("MockTokenCreator", ["MockDAI", "mDAI"]);
  return { mockDAI };
});
