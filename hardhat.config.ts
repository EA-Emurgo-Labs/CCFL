import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "solidity-coverage";
import "hardhat-gas-reporter";
require("dotenv").config();
const { API_URL, PRIVATE_KEY, ETHERSCAN_API_KEY, HOLESKY_API_URL } =
  process.env;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    sepolia: {
      url: API_URL,
      accounts: [`0x${PRIVATE_KEY}`],
    },
    holesky: {
      url: HOLESKY_API_URL,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  // gasReporter: {
  //   enabled: true,
  //   currency: "USD", // currency to show
  //   outputFile: "gas-report.txt", // optional
  //   noColors: true, //optional
  //   coinmarketcap: process.env.COINMARKETCAP_API_KEY, //to fetch gas data
  //   gasPriceApi: `https://api.etherscan.io/api?module=proxy&action=eth_gasPrice&apikey=${ETHERSCAN_API_KEY}`,
  //   token: "ETH", // for polygon blockchain(optional).
  // },
  mocha: {
    timeout: 100000000,
  },
};

export default config;
