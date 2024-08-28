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
    "0xD8F9AC90175d539E25b808c4CDfbc938e0A39cB1"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0xfdFe2FcDD1B44caAa7E9b455909a881E656aaAF6"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
