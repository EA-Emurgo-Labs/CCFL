import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ProxyCCFLModule = buildModule("ProxyCCFLModule", (m) => {
  let usdc = "0x0335468fF1BE5F81d0e4d24414ccB314b9820a69";
  let usdt = "0x5d2bf0b5D8590D10eceDf1ade5128BE39BF43432";
  let wbtc = "0x7a4D7c63936b1c0Ea523B13812BD9cdDB45cE956";
  let wETH = "0xC9Dbd9B061cf207341c75FE1934629288B3f93ce";
  let aWBTC = "0x60Da721252146Cc7Bc5b51bF683BcBcC853617F0";
  let aWETH = "0x0CA247Ce1E67A4A3e6c1f168E704D2f43768FDf6";
  let PoolAddressesProviderAave = "0x852BF193870640F06165D4B52b12d19Da38004dA";

  // "MockAggregatorETHModule#eth": "0x6D99daA7A6E44197f38af8BC41aA2fe1B8dA68B7",
  // "MockAggregatorETHModule#usdc": "0xb16C729Ac203876304D368641B465774f3287a7e",
  // "MockAggregatorETHModule#wbtc": "0xD3C7df2DA0736a43f2cbd65DB7fc75280A78832E",
  // "DefaultReserveInterestRateStrategyModule#DefaultReserveInterestRateStrategy": "0x01120927A1d734403404d637753585cA2d0bAe69"

  const ethAggr = m.contractAt(
    "MockAggregator",
    "0x6D99daA7A6E44197f38af8BC41aA2fe1B8dA68B7",
    { id: "ethAggr" }
  );
  const wbtcAggr = m.contractAt(
    "MockAggregator",
    "0xD3C7df2DA0736a43f2cbd65DB7fc75280A78832E",
    { id: "wbtcAggr" }
  );
  const usdcAggr = m.contractAt(
    "MockAggregator",
    "0xb16C729Ac203876304D368641B465774f3287a7e",
    { id: "usdcAggr" }
  );

  const defaultReserveInterestRateStrategy = m.contractAt(
    "DefaultReserveInterestRateStrategy",
    "0x01120927A1d734403404d637753585cA2d0bAe69"
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
    "0xA4AB95a86B02b1F506C9957A3647fa7865f4b937"
  );

  const factoryV3 = m.contractAt(
    "MockFactory",
    "0xD52767f73D3bA8213C96EC517D5Bd8F5c1Aa8C2e"
  );

  const quoterV2 = m.contractAt(
    "IQuoterV2",
    "0xc2cDde6EC7a6BEB5db32a25f54CbdF0b15A45c6b"
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
