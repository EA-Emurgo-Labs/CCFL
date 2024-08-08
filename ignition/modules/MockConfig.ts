import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const ETH = m.contractAt("0x");
  const USDC = m.contractAt("0x");
  const WBTC = m.contractAt("0x");

  m.call(ETH, "setPrice", [BigInt(4000e18)]);

  m.call(USDC, "setPrice", [BigInt(1.01e18)]);

  m.call(WBTC, "setPrice", [BigInt(60000e18)]);

  return { ETH, USDC, WBTC };
});

export default ConfigModule;
