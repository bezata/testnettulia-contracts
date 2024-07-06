require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      viaIR: true,
    },
    optimizer: {
      enabled: true,
      runs: 100,
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
      url: `https://arb-sepolia.g.alchemy.com`,
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
        salt: "0xdc142284f7fc139c7852357d1c36ad97c4df5ddc95f883b8f849f9b34de1d017",
      },
    },
  },
};
