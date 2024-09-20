import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ProxyAddMorePoolCCFLModule = buildModule(
  "ProxyAddMorePoolCCFLModule",
  (m) => {
    let ccfl = "0xDD20c2e2cf399Cc3c688a0A73241B8e8eA7b6F78";

    // "ProxyCCFLModule#DefaultReserveInterestRateStrategy": "0xEC804ffb70aE9aeF7a885bd6C4cAe8a5b65a7C77",
    let usdt = "0xaa8e23fb1079ea71e0a56f48a2aa51851d8433d0";
    const usdtAggr = m.contractAt(
      "MockAggregator",
      "0xeEFaa85D124556d8be8a26e4F44cE090d2e707eD",
      { id: "usdtAggr" }
    );

    const defaultReserveInterestRateStrategy = m.contractAt(
      "DefaultReserveInterestRateStrategy",
      "0xEC804ffb70aE9aeF7a885bd6C4cAe8a5b65a7C77"
    );

    const proxyAdminOwner = m.getAccount(0);

    const ccflPool = m.contract("CCFLPool");

    const dataPool = m.encodeFunctionCall(ccflPool, "initialize", [
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

    const proxyCCFL = m.contractAt("TransparentUpgradeableProxy", ccfl, {
      id: "proxyCCFL",
    });

    const ccflPoolProxyRemap = m.contractAt("CCFLPool", proxyPool, {
      id: "ccflPoolProxyRemap",
    });
    const ccflProxyRemap = m.contractAt("CCFL", proxyCCFL, {
      id: "ccflproxyRemap",
    });

    m.call(ccflPoolProxyRemap, "setCCFL", [ccflProxyRemap]);

    m.call(ccflProxyRemap, "setPools", [
      [usdt],
      [usdtAggr],
      [ccflPoolProxyRemap],
    ]);

    return { proxyCCFL, proxyAdminPool, proxyPool };
  }
);

export default ProxyAddMorePoolCCFLModule;
