import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseUnits } from "ethers";
const ProxyCCFLModule = buildModule("ProxyCCFLModule", (m) => {
  let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
  let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
  let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
  let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
  let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
  let PoolAddressesProviderAave = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";

  const ethAggr = m.contract("MockAggregator", [], { id: "ethAggr" });
  const wbtcAggr = m.contract("MockAggregator", [], { id: "wbtcAggr" });
  const usdcAggr = m.contract("MockAggregator", [], { id: "usdcAggr" });

  m.call(ethAggr, "setPrice", [BigInt(4000e8)]);

  m.call(usdcAggr, "setPrice", [BigInt(1.01e8)]);

  m.call(wbtcAggr, "setPrice", [BigInt(60000e8)]);

  const defaultReserveInterestRateStrategy = m.contract(
    "DefaultReserveInterestRateStrategy",
    [
      parseUnits("0.80", 27).toString(),
      parseUnits("0.05", 27).toString(),
      parseUnits("0.04", 27).toString(),
      parseUnits("3", 27).toString(),
    ]
  );

  const proxyAdminOwner = m.getAccount(0);

  const ccflPool = m.contract("CCFLPool");

  const dataPool = m.encodeFunctionCall(ccflPool, "initialize", [
    usdc,
    defaultReserveInterestRateStrategy,
  ]);

  const proxyPool = m.contract(
    "TransparentUpgradeableProxy",
    [ccflPool, proxyAdminOwner, dataPool],
    { id: "proxyPool" }
  );

  const proxyAdminAddressPool = m.readEventArgument(
    proxyPool,
    "AdminChanged",
    "newAdmin",
    { id: "proxyAdminAddressPool" }
  );

  const proxyAdminPool = m.contractAt("ProxyAdmin", proxyAdminAddressPool, {
    id: "proxyAdminPool",
  });

  const loan = m.contract("CCFLLoan", []);

  const ccfl = m.contract("CCFL");

  const data = m.encodeFunctionCall(ccfl, "initialize", [
    [usdc],
    [usdcAggr],
    [proxyPool],
    [wbtc],
    [wbtcAggr],
    [aWBTC],
    PoolAddressesProviderAave,
    BigInt(5000),
    BigInt(7000),
    loan,
  ]);

  const proxyCCFL = m.contract(
    "TransparentUpgradeableProxy",
    [ccfl, proxyAdminOwner, data],
    { id: "proxyCCFL" }
  );

  const proxyAdminAddressCCFL = m.readEventArgument(
    proxyCCFL,
    "AdminChanged",
    "newAdmin",
    { id: "proxyAdminAddressCCFL" }
  );

  const proxyAdminCCFL = m.contractAt("ProxyAdmin", proxyAdminAddressCCFL);

  return { proxyAdminCCFL, proxyCCFL, proxyAdminPool, proxyPool };
});

export default ProxyCCFLModule;
