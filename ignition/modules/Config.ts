import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const liquidator = "0x";
  const platform = "0x";
  const ccflPool = m.contractAt("0x");
  const ccfl = m.contractAt("0x");

  m.call(ccfl, "setPenalty", [BigInt(5), BigInt(10), BigInt(5)]);

  m.call(ccfl, "setPlatformAddress", [liquidator, platform]);

  m.call(ccflPool, "setCCFL", ["0x"]);

  return { ccflPool, ccfl };
});

export default ConfigModule;
