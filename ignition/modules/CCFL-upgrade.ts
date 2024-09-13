import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLUpgradeModule = buildModule("CCFLUpgradeModule1", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFL");

  // const ccfl = m.contractAt(
  //   "CCFL",
  //   "0xe6138F2bcE382A325329bB33dB86b89f7E3fFD31"
  // );

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0x847B9D52d563fdF6a8cbc761c6B429741d59F6E1"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0xdcAcfeA818cD4191415E91a81d4CE0f45ab5Be24"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
