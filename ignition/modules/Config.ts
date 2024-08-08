import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const liquidator = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const platform = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const ccflPool = m.contractAt(
    "CCFLPool",
    "0x6aDA90ab012d0E69b8B5b2054D2d2427c3cdBcbB"
  );
  const ccfl = m.contractAt(
    "CCFL",
    "0x4d3CcFF382e8E1Fb26e39297b6b9ec6b2F535Da1"
  );
  const mockSwapRouter = "0xDbE1483db9a2E6e60d57b2A089368d4c5EF83e83";

  m.call(ccfl, "setPenalty", [BigInt(5), BigInt(10), BigInt(5)]);

  m.call(ccfl, "setPlatformAddress", [liquidator, platform]);

  m.call(ccflPool, "setCCFL", ["0x4d3CcFF382e8E1Fb26e39297b6b9ec6b2F535Da1"]);

  m.call(ccfl, "setSwapRouter", [mockSwapRouter]);

  return { ccflPool, ccfl };
});

export default ConfigModule;
