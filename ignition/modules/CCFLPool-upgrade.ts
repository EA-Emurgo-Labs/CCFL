import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLPoolUpgradeModule = buildModule("CCFLPoolUpgradeModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccflPool = m.contract("CCFLPool");

  const data = "0x";

  const proxy = m.contractAt(
    "TransparentUpgradeableProxy",
    "0xeA6c6a0EBf512Ccea5DBBF5c20718f911fa454df"
  );

  const proxyAdmin = m.contractAt(
    "ProxyAdmin",
    "0xa4E109cf7CbDb63c8C8D215C6bA5e6d63209ad02"
  );

  m.call(proxyAdmin, "upgradeAndCall", [proxy, ccflPool, data]);

  return { proxyAdmin, proxy };
});

export default CCFLPoolUpgradeModule;
