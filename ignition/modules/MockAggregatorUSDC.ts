import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const MockAggregatorUSDCModule = buildModule("MockAggregatorModule", (m) => {
  const usdc = m.contract("MockAggregator", []);
  return { usdc };
});

export default MockAggregatorUSDCModule;
