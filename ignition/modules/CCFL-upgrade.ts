import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLUpgradeModule = buildModule("CCFLUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFL");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0x4d3CcFF382e8E1Fb26e39297b6b9ec6b2F535Da1"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x7F2cbEF45048aeC149B2FAB44e891458d947fD9d"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
