import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ProxyCCFLModule = buildModule("ProxyCCFLModule", (m) => {
  let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
  let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
  let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
  let ccflPool = "0x6aDA90ab012d0E69b8B5b2054D2d2427c3cdBcbB";
  let ccflLoan = "0xf8E01Ef36e999286a6a4E7300e3A5Bf0d02BD478";
  let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
  let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
  let aggrETH = "0x8025377bA919ad0260d7602ecF4880d813FEec8E";
  let aggrWBTC = "0x4acd7e6BeF96ff6E76df85D287D27d130Ab69a7F";
  let aggrUSDC = "0x7B6D7447bC758BA262Ea084dF7cd6a347f10C7c8";
  let PoolAddressesProviderAave = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";

  const proxyAdminOwner = m.getAccount(0);
  console.log(proxyAdminOwner);

  const ccfl = m.contract("CCFL");

  const data = m.encodeFunctionCall(ccfl, "initialize", [
    [usdc],
    [aggrUSDC],
    [ccflPool],
    [wbtc],
    [aggrWBTC],
    [aWBTC],
    PoolAddressesProviderAave,
    BigInt(5000),
    BigInt(7000),
    ccflLoan,
  ]);

  const proxy = m.contract("TransparentUpgradeableProxy", [
    ccfl,
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

export default ProxyCCFLModule;
