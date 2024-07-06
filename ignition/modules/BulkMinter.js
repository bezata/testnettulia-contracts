const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("BulkMinter", (m) => {
  const bulkMinter = m.contract("BulkMinter", [
    "0x4fa390F2f1f74403504d7A490B47F0c2BC0ACE48",
  ]);

  return { bulkMinter };
});
