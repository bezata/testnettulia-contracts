const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("MockETH", (m) => {
  const mockETH = m.contract("MockTokenCreator", ["MockETH", "mETH"]);
  return { mockETH };
});
