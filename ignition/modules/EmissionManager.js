const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("EmissionManager", (m) => {
  const emissionManager = m.contract("FeeManager", [100, 100]); // Adjust initial fee rates as needed

  return { emissionManager };
});
