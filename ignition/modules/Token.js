const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockTokenCreator", (m, args, secondargs) => {
  const mockTokenCreator = m.contract("MockTokenCreator", [args, secondargs]);

  return { mockTokenCreator };
});
