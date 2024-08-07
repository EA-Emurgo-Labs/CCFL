import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockAggregatorWBTCModule = buildModule(
  "MockAggregatorWBTCModule",
  (m) => {
    const btc = m.contract("MockAggregator", []);
    return { btc };
  }
);

export default MockAggregatorWBTCModule;
