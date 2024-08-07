import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLModule = buildModule("CCFLModule", (m) => {
  let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
  let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
  let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
  let ccflPool = "0xA116811C722fD6588e230b11fbE49daB0aa6554E";
  let ccflLoan = "0xA7b80B1FF8EBDeCf593f2ff3c529102947418C4A";
  let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
  let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
  const ccfl = m.contract("CCFL", [usdc]);

  return { ccfl };
});

export default CCFLModule;
