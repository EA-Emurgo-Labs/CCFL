import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ProxyCCFLModule = buildModule("ProxyCCFLModule", (m) => {
  let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
  let usdt = "0xaa8e23fb1079ea71e0a56f48a2aa51851d8433d0";
  let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
  let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
  let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
  let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
  let PoolAddressesProviderAave = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";

  // "ProxyCCFLModule#DefaultReserveInterestRateStrategy": "0xEC804ffb70aE9aeF7a885bd6C4cAe8a5b65a7C77",
  // "ProxyCCFLModule#ethAggr": "0xB6c04707C7f46E02C7B6546CD26a8b845D448f0a",
  // "ProxyCCFLModule#usdcAggr": "0xeEFaa85D124556d8be8a26e4F44cE090d2e707eD",
  // "ProxyCCFLModule#wbtcAggr": "0x2B1EdE85Ea8105e638429a9B3Ec621d1A7939597",

  const ethAggr = m.contractAt(
    "MockAggregator",
    "0xB6c04707C7f46E02C7B6546CD26a8b845D448f0a",
    { id: "ethAggr" }
  );
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
  const ccflPoolUSDT = m.contract("CCFLPool", [], { id: "ccflPoolUSDT" });

  const dataPool = m.encodeFunctionCall(ccflPool, "initialize", [
    usdc,
    defaultReserveInterestRateStrategy,
    100000000000000,
  ]);

  const dataPoolUSDT = m.encodeFunctionCall(ccflPoolUSDT, "initialize", [
    usdt,
    defaultReserveInterestRateStrategy,
    100000000000000,
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

  const proxyUSDTPool = m.contract(
    "TransparentUpgradeableProxy",
    [ccflPool, proxyAdminOwner, dataPoolUSDT],
    { id: "proxyPoolUSDT" }
  );

  const proxyAdminUSDTAddressPool = m.readEventArgument(
    proxyUSDTPool,
    "AdminChanged",
    "newAdmin",
    { id: "proxyAdminAddressPoolUSDT" }
  );

  const proxyAdminPoolUSDT = m.contractAt(
    "ProxyAdmin",
    proxyAdminUSDTAddressPool,
    {
      id: "proxyAdminPoolUSDT",
    }
  );

  const loan = m.contract("CCFLLoan");

  const swapRouterV2 = m.contractAt(
    "MockSwapRouter",
    "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E"
  );

  const factoryV3 = m.contractAt(
    "MockFactory",
    "0x0227628f3F023bb0B980b67D528571c95c6DaC1c"
  );

  const quoterV2 = m.contractAt(
    "IQuoterV2",
    "0xEd1f6473345F45b75F8179591dd5bA1888cf2FB3"
  );

  const ccflConfig = m.contract("CCFLConfig");

  const dataConfig = m.encodeFunctionCall(ccflConfig, "initialize", [
    BigInt(5000),
    BigInt(7000),
    swapRouterV2,
    factoryV3,
    quoterV2,
    PoolAddressesProviderAave,
    proxyAdminOwner,
    proxyAdminOwner,
    true,
    wETH,
  ]);

  const proxyCCFLConfig = m.contract(
    "TransparentUpgradeableProxy",
    [ccflConfig, proxyAdminOwner, dataConfig],
    { id: "proxyCCFLConfig" }
  );

  const proxyAdminAddressCCFLConfig = m.readEventArgument(
    proxyCCFLConfig,
    "AdminChanged",
    "newAdmin",
    { id: "proxyAdminAddressCCFLConfig" }
  );

  const proxyAdminCCFLConfig = m.contractAt(
    "ProxyAdmin",
    proxyAdminAddressCCFLConfig,
    {
      id: "proxyCCFLConfigadmin",
    }
  );

  const ccflConfigProxyRemap = m.contractAt("CCFLConfig", proxyCCFLConfig, {
    id: "ccflConfigProxyRemap",
  });

  m.call(ccflConfigProxyRemap, "setPenalty", [
    BigInt(50),
    BigInt(100),
    BigInt(50),
  ]);

  m.call(ccflConfigProxyRemap, "setEarnShare", [
    BigInt(7000),
    BigInt(2000),
    BigInt(1000),
  ]);

  m.call(ccflConfigProxyRemap, "setCollaterals", [
    [wbtc, wETH],
    [wbtcAggr, ethAggr],
    [aWBTC, aWETH],
  ]);

  m.call(ccflConfigProxyRemap, "setPoolCoins", [
    [usdc, usdt],
    [usdcAggr, usdcAggr],
  ]);

  m.call(ccflConfigProxyRemap, "setCollateralToStableFee", [
    [wbtc, wbtc, wETH, wETH],
    [usdc, usdt, usdc, usdt],
    [3000, 3000, 3000, 3000],
  ]);

  const ccfl = m.contract("CCFL");

  const data = m.encodeFunctionCall(ccfl, "initialize", [
    [usdc, usdt],
    [proxyPool, proxyUSDTPool],
    proxyCCFLConfig,
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

  const ccflPoolUSDTProxyRemap = m.contractAt("CCFLPool", proxyUSDTPool, {
    id: "ccflPoolUSDTProxyRemap",
  });

  m.call(ccflPoolProxyRemap, "setCCFL", [proxyCCFL]);

  m.call(ccflPoolUSDTProxyRemap, "setCCFL", [proxyCCFL]);

  return {
    proxyAdminCCFL,
    proxyCCFL,
    proxyAdminPool,
    proxyPool,
    proxyUSDTPool,
  };
});

export default ProxyCCFLModule;
