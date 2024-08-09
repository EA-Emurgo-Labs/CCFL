import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLPoolUpgradeModule = buildModule("CCFLPoolUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFL");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0x6aDA90ab012d0E69b8B5b2054D2d2427c3cdBcbB"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x78eAf38cF446f461B09A4F83a5539854C81dF940"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLPoolUpgradeModule;
