import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const liquidator = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const platform = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const ccflPoolAddr = "0xe0c51054586414A7A89bea3E2D56E04f07Bc73c3";
  const ccflAddr = "0x7B7450f910644A4EDe3183B7fCC5313a043f335C";
  const ccflPool = m.contractAt("CCFLPool", ccflPoolAddr);
  const ccfl = m.contractAt("CCFL", ccflAddr);
  const swapRouterV2 = m.contractAt(
    "MockSwapRouter",
    "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E"
  );

  const factoryV3 = m.contractAt(
    "MockFactory",
    "0x0227628f3F023bb0B980b67D528571c95c6DaC1c"
  );

  m.call(ccfl, "setPenalty", [BigInt(5), BigInt(10), BigInt(5)]);

  m.call(ccfl, "setPlatformAddress", [liquidator, platform]);

  m.call(ccflPool, "setCCFL", [ccflAddr]);

  m.call(ccfl, "setSwapRouter", [swapRouterV2, factoryV3]);

  return { ccflPool, ccfl };
});

export default ConfigModule;
