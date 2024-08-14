import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLUpgradeModule = buildModule("CCFLUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFL");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0x01120927A1d734403404d637753585cA2d0bAe69"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0xea32E8e27579F8b55442d0e4a0F11cd0e0B5ea1c"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLUpgradeModule;
