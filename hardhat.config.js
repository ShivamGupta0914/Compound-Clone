require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
    solidity: "0.8.19",
    networks: {
      sepolia: {
        url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.SEPOLIA_API_KEY}`,
        accounts: [process.env.NETWORK_PRIVATE_KEY]
      },
      goerli: {
        url: `https://eth-goerli.g.alchemy.com/v2/${process.env.GOERLI_API_KEY}`,
        accounts: [process.env.NETWORK_PRIVATE_KEY]
      },
      mainnet: {
        url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.MAINNET_API_KEY}`,
        accounts: [process.env.NETWORK_PRIVATE_KEY]
      }
    },
    etherscan: {
      apiKey: process.env.ETHERSCAN_API_KEY
    }
}