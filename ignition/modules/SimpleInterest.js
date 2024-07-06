// ignition/modules/SimpleInterest.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("SimpleInterest", (m) => {
  const simpleInterest = m.contract("SimpleInterest");

  return { simpleInterest };
});
