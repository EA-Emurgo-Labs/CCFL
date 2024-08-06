import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const proxyCCFLPoolModule = buildModule("ProxyCCFLPoolModule", (m) => {
  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccflPool = m.contract("CCFLPool");

  const data = m.encodeFunctionCall(ccflPool, "initialize", [
    "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    "0x0c216272d22429205B6e82D3E7A3d7f0064A447c",
  ]);

  const proxy = m.contract("TransparentUpgradeableProxy", [
    ccflPool,
    proxyAdminOwner,
    data,
  ]);

  const proxyAdminAddress = m.readEventArgument(
    proxy,
    "AdminChanged",
    "newAdmin"
  );

  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  return { proxyAdmin, proxy };
});

export default proxyCCFLPoolModule;
