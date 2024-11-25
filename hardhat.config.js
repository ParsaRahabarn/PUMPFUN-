require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();

module.exports = {
  defaultNetwork: "Net",
  networks: {
    Net: {
      url: "https://eth-sepolia.g.alchemy.com/v2/Xgx9vAVvsSg0_WzU5njdqOPNJ6QWPESM",
      accounts: [] // Add your private keys here if needed
    },
    localnet: {
      url: "http://127.0.0.1:8545", // Default URL for Hardhat Network
      accounts: [""] // Optional: Add your private keys here if needed
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          }
        }
      }
    ]
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
};
