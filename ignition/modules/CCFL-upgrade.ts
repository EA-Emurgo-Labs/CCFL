import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLUpgradeModule = buildModule("CCFLUpgradeModule", (m) => {
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
    "0x5f761F256ECf4c005593066D078E51837Ee80B30"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x337a2bF1AdEEb63d6a8354E3DDd3BB990D30cEB0"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
