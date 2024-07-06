// ignition/modules/PoolOrganizer.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("PoolOrganizer", (m) => {
  const poolOrganizer = m.contract("PoolOrganizer");

  return { poolOrganizer };
});
