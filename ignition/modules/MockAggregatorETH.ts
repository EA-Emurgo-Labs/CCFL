import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockAggregatorETHModule = buildModule("MockAggregatorETHModule", (m) => {
  const eth = m.contract("MockAggregator", [], { id: "eth" });
  return { eth };
});

export default MockAggregatorETHModule;
