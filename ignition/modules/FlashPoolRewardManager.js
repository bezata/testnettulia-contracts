    // ignition/modules/FlashPoolRewardManager.js
const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("FlashPoolRewardManager", (m) => {
    const flashPoolRewardManager = m.contract("FlashPoolRewardManager");
    
    return { flashPoolRewardManager };
    }
);