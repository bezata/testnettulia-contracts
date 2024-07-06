const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockARB", (m) => {
  const mockARB = m.contract("MockTokenCreator", ["MockARB", "mARB"]);
  return { mockARB };
});
