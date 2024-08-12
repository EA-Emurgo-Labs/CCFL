import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const liquidator = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const platform = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const ccflPoolAddr = "0x9c8a17014a64d1838991BE5169f1BaE8a84D5AA9";
  const ccflAddr = "0xB4fB9D507d288c879419Ebd92A8fC08b575BB697";
  const ccflPool = m.contractAt("CCFLPool", ccflPoolAddr);
  const ccfl = m.contractAt("CCFL", ccflAddr);
  const mockSwapRouter = m.contract("MockSwapRouter", []);

  m.call(ccfl, "setPenalty", [BigInt(5), BigInt(10), BigInt(5)]);

  m.call(ccfl, "setPlatformAddress", [liquidator, platform]);

  m.call(ccflPool, "setCCFL", [ccflAddr]);

  m.call(ccfl, "setSwapRouter", [mockSwapRouter]);

  return { ccflPool, ccfl };
});

export default ConfigModule;
