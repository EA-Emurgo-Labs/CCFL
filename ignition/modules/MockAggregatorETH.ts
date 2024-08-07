import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockAggregatorETHModule = buildModule("MockAggregatorETHModule", (m) => {
  const eth = m.contract("MockAggregator", []);
  return { eth };
});

export default MockAggregatorETHModule;
