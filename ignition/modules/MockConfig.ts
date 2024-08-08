import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const MockConfigModule = buildModule("MockConfigModule", (m) => {
  const ETH = m.contractAt(
    "MockAggregator",
    "0x8025377bA919ad0260d7602ecF4880d813FEec8E",
    { id: "ETH" }
  );
  const USDC = m.contractAt(
    "MockAggregator",
    "0x7B6D7447bC758BA262Ea084dF7cd6a347f10C7c8",
    { id: "USDC" }
  );
  const WBTC = m.contractAt(
    "MockAggregator",
    "0x4acd7e6BeF96ff6E76df85D287D27d130Ab69a7F",
    { id: "WBTC" }
  );

  m.call(ETH, "setPrice", [BigInt(4000e18)]);

  m.call(USDC, "setPrice", [BigInt(1.01e18)]);

  m.call(WBTC, "setPrice", [BigInt(60000e18)]);

  return { ETH, USDC, WBTC };
});

export default MockConfigModule;
