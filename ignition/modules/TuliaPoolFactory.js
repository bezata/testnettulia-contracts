const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("TuliaPoolFactory", (m) => {
  const tuliaPoolFactory = m.contract("TuliaPoolFactory", [
    "0x3AA12ca01c46De5907928F46813351dDA916f54A",
    "0xa5Fe443f5D1e2Af4D62583308Dc428494C19C915",
    "0x8D3520C41d6eca54ab638d85F22a414fB2264114",
  ]);

  return { tuliaPoolFactory };
});
