require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    coreTestnet: {
      url: process.env.CORE_RPC_URL || "https://rpc.testnet.coredao.org",
      chainId: 1115,
      accounts: process.env.PRIVATE_KEY ? [`0x${process.env.PRIVATE_KEY}`] : []
    }
  }
};
