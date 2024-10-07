import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLPoolUpgradeModule = buildModule("CCFLPoolUpgradeModule6", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccflPool = m.contract("CCFLPool");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0xeaE813a7eb9A003ba5e8905F977c578c53aea5E5"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0xbBD523544425F8dDc1D97Fe9a8336DAf044c61ca"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccflPool, data]);

  return { proxyAdmin, proxy };
});

export default CCFLPoolUpgradeModule;
