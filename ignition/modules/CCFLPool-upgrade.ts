import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLPoolUpgradeModule = buildModule("CCFLPoolUpgradeModule6", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccflPool = m.contract("CCFLPool");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0x9a858bf4FB0E7bc4971eCd781C2A9FF981B79Aa9"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x03F87F3830F0C96f70b3cc3c6F66260142411aa9"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccflPool, data]);

  return { proxyAdmin, proxy };
});

export default CCFLPoolUpgradeModule;
