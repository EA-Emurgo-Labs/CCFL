import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLPoolUpgradeModule = buildModule("CCFLPoolUpgradeModule2", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccflPool = m.contract("CCFLPool");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0xe0c51054586414A7A89bea3E2D56E04f07Bc73c3"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x2898A8a68D2657d4841d1Af3320013423E2422A7"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccflPool, data]);

  return { proxyAdmin, proxy };
});

export default CCFLPoolUpgradeModule;
