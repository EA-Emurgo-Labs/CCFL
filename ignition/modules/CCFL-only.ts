import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseUnits } from "ethers";
const ProxyCCFLModule = buildModule("ProxyCCFLModule", (m) => {
  let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
  let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
  let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
  let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
  let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
  let PoolAddressesProviderAave = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";

  // "ProxyCCFLModule#DefaultReserveInterestRateStrategy": "0xEC804ffb70aE9aeF7a885bd6C4cAe8a5b65a7C77",
  // "ProxyCCFLModule#ethAggr": "0xB6c04707C7f46E02C7B6546CD26a8b845D448f0a",
  // "ProxyCCFLModule#usdcAggr": "0xeEFaa85D124556d8be8a26e4F44cE090d2e707eD",
  // "ProxyCCFLModule#wbtcAggr": "0x2B1EdE85Ea8105e638429a9B3Ec621d1A7939597",

  // const ethAggr = m.contractAt(
  //   "MockAggregator",
  //   "0xB6c04707C7f46E02C7B6546CD26a8b845D448f0a",
  //   { id: "ethAggr" }
  // );
  const wbtcAggr = m.contractAt(
    "MockAggregator",
    "0x2B1EdE85Ea8105e638429a9B3Ec621d1A7939597",
    { id: "wbtcAggr" }
  );
  const usdcAggr = m.contractAt(
    "MockAggregator",
    "0xeEFaa85D124556d8be8a26e4F44cE090d2e707eD",
    { id: "usdcAggr" }
  );

  const defaultReserveInterestRateStrategy = m.contractAt(
    "DefaultReserveInterestRateStrategy",
    "0xEC804ffb70aE9aeF7a885bd6C4cAe8a5b65a7C77"
  );

  const proxyAdminOwner = m.getAccount(0);

  const ccflPool = m.contract("CCFLPool");

  const dataPool = m.encodeFunctionCall(ccflPool, "initialize", [
    usdc,
    defaultReserveInterestRateStrategy,
  ]);

  const proxyPool = m.contract(
    "TransparentUpgradeableProxy",
    [ccflPool, proxyAdminOwner, dataPool],
    { id: "proxyPool" }
  );

  const proxyAdminAddressPool = m.readEventArgument(
    proxyPool,
    "AdminChanged",
    "newAdmin",
    { id: "proxyAdminAddressPool" }
  );

  const proxyAdminPool = m.contractAt("ProxyAdmin", proxyAdminAddressPool, {
    id: "proxyAdminPool",
  });

  const loan = m.contract("CCFLLoan", []);

  const ccfl = m.contract("CCFL");

  const data = m.encodeFunctionCall(ccfl, "initialize", [
    [usdc],
    [usdcAggr],
    [proxyPool],
    [wbtc],
    [wbtcAggr],
    [aWBTC],
    PoolAddressesProviderAave,
    BigInt(5000),
    BigInt(7000),
    loan,
  ]);

  const proxyCCFL = m.contract(
    "TransparentUpgradeableProxy",
    [ccfl, proxyAdminOwner, data],
    { id: "proxyCCFL" }
  );

  const proxyAdminAddressCCFL = m.readEventArgument(
    proxyCCFL,
    "AdminChanged",
    "newAdmin",
    { id: "proxyAdminAddressCCFL" }
  );

  const proxyAdminCCFL = m.contractAt("ProxyAdmin", proxyAdminAddressCCFL, {
    id: "proxyCCFLadmin",
  });

  const ccflPoolProxyRemap = m.contractAt("CCFLPool", proxyPool, {
    id: "ccflPoolProxyRemap",
  });
  const ccflProxyRemap = m.contractAt("CCFL", proxyCCFL, {
    id: "ccflproxyRemap",
  });
  const swapRouterV2 = m.contractAt(
    "MockSwapRouter",
    "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E"
  );

  const factoryV3 = m.contractAt(
    "MockFactory",
    "0x0227628f3F023bb0B980b67D528571c95c6DaC1c"
  );

  m.call(ccflProxyRemap, "setPenalty", [BigInt(50), BigInt(100), BigInt(50)]);

  m.call(ccflProxyRemap, "setPlatformAddress", [
    proxyAdminOwner,
    proxyAdminOwner,
  ]);

  m.call(ccflPoolProxyRemap, "setCCFL", [ccflProxyRemap]);

  m.call(ccflProxyRemap, "setSwapRouter", [swapRouterV2, factoryV3]);

  m.call(ccflProxyRemap, "setEarnShare", [
    BigInt(7000),
    BigInt(2000),
    BigInt(1000),
  ]);

  m.call(ccflProxyRemap, "setEnableETHNative", [true]);

  return { proxyAdminCCFL, proxyCCFL, proxyAdminPool, proxyPool };
});

export default ProxyCCFLModule;
