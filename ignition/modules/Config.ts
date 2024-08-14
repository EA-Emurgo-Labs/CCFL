import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const liquidator = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const platform = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const ccflPoolAddr = "0xD5152b26704DBD7038a32a2Ea5ff4Da3A3898382";
  const ccflAddr = "0x01120927A1d734403404d637753585cA2d0bAe69";
  const ccflPool = m.contractAt("CCFLPool", ccflPoolAddr);
  const ccfl = m.contractAt("CCFL", ccflAddr);
  const mockSwapRouter = m.contractAt(
    "MockSwapRouter",
    "0xbe100b88D42D8f549E3CE97305b61b5744d54f94"
  );

  m.call(ccfl, "setPenalty", [BigInt(5), BigInt(10), BigInt(5)]);

  m.call(ccfl, "setPlatformAddress", [liquidator, platform]);

  m.call(ccflPool, "setCCFL", [ccflAddr]);

  m.call(ccfl, "setSwapRouter", [mockSwapRouter]);

  return { ccflPool, ccfl };
});

export default ConfigModule;
