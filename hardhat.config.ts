import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "dotenv/config";

const {
  PRIVATE_KEY_OWNER,
  PRIVATE_KEY_ACCOUNT1,
  BSCSCAN_API,
  COINMARKETCAP_API_KEY,
  PRIVATE_KEY_MAIN,
} = process.env;

const RPC_NETWORK = "https://bsc-testnet-rpc.publicnode.com";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    localhost: {
      url: "HTTP://127.0.0.1:8545",
    },
    mainnet: {
      url: "https://bsc-rpc.publicnode.com",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [PRIVATE_KEY_MAIN as string],
    },
    bscTestnet: {
      url: RPC_NETWORK,
      chainId: 97,
      gasPrice: 300000000,
      accounts: [PRIVATE_KEY_ACCOUNT1 as string],
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  etherscan: {
    enabled: true,
    apiKey: {
      bscTestnet: BSCSCAN_API as string,
    },
  },
  sourcify: {
    enabled: true,
  },
  gasReporter: {
    enabled: true,
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
  ignition: {
    requiredConfirmations: 1,
  },
};

export default config;
