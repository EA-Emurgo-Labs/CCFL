import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLUpgradeModule = buildModule("CCFLUpgradeModule6", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFL");

  // const ccfl = m.contractAt(
  //   "CCFL",
  //   "0x9B235A0AaC2F1ba3702ed0846462cC4920aDDeB9"
  // );

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0xc68BDD676FDbeac643baC74bfb08e8254841cF41"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x5072C969aE1806acd898dc6f2622BD7769154937"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
