import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const MockAggregatorETHModule = buildModule("MockAggregatorETHModule", (m) => {
  const eth = m.contract("MockAggregator", [], { id: "eth" });
  const wbtc = m.contract("MockAggregator", [], { id: "wbtc" });
  const usdc = m.contract("MockAggregator", [], { id: "usdc" });

  m.call(eth, "setPrice", [BigInt(4000e8)]);

  m.call(usdc, "setPrice", [BigInt(1.01e8)]);

  m.call(wbtc, "setPrice", [BigInt(60000e8)]);

  return { eth, wbtc, usdc };
});

export default MockAggregatorETHModule;
