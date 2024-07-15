require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      viaIR: true,
    },
  },

  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    arbitrumSepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/aHK2851UBjpt0-LHxD3LX4NXnttXhcOL`,
      accounts: [process.env.PRIVATE_KEY],
    },
    polygonAmoy: {
      url: `https://icy-crimson-moon.matic-amoy.quiknode.pro`,
      accounts: [process.env.PRIVATE_KEY],
    },
    ethereumHolesky: {
      url: `https://eth-holesky.g.alchemy.com`,
      accounts: [process.env.PRIVATE_KEY],
    },
    baseSepolia: {
      url: `https://base-sepolia.g.alchemy.com`,
      accounts: [process.env.PRIVATE_KEY],
    },
    avalancheFuji: {
      url: "https://cosmopolitan-sly-glitter.avalanche-testnet.quiknode.pro/",
      accounts: [process.env.PRIVATE_KEY],
    },
    binanceTestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545/`,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
  ignition: {
    strategyConfig: {
      create2: {
        salt: "0xbd8a7ea8cfca7b4e5f5031d8d4b17bc327g5cd42cfbc42066a00cf26b43eb53f",
      },
    },
  },
};
