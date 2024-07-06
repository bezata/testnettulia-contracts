const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockWBTC", (m) => {
  const mockWBTC = m.contract("MockTokenCreator", ["MockWBTC", "mWBTC"]);
  return { mockWBTC };
});
