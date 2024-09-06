import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLUpgradeModule = buildModule("CCFLUpgradeModule8", (m) => {
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
    "0xC5095DEaAb52F0f788158790244BEBCa5b590368"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x6777fc5cFf74426f036bFc4C657F875e76EEDE74"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
