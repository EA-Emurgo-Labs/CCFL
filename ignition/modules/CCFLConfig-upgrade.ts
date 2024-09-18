import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLConfigUpgradeModule = buildModule("CCFLConfigUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFLConfig");

  // const ccfl = m.contractAt(
  //   "CCFL",
  //   "0xe6138F2bcE382A325329bB33dB86b89f7E3fFD31"
  // );

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0x79007D349696AF8D1D5b59696B70b43a27e47f70"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0x902fbDe26B78248969417aB46B0832e08c4d865c"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccfl, data]);

  return { proxyAdmin, proxy };
});

export default CCFLConfigUpgradeModule;
