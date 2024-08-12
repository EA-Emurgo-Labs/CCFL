import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const ConfigModule = buildModule("ConfigModule", (m) => {
  const liquidator = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const platform = "0x17883e3728E7bB528b542B8AAb354022eD20C149";
  const ccflPool = m.contractAt(
    "CCFLPool",
    "0xD6483bb4aBEfc87812E5eb5a601Cfe70cD84F419"
  );
  const ccfl = m.contractAt(
    "CCFL",
    "0x2cfFd7F87039bbAC3c42C1739513aa03A3b39654"
  );
  const mockSwapRouter = "0xDbE1483db9a2E6e60d57b2A089368d4c5EF83e83";

  m.call(ccfl, "setPenalty", [BigInt(5), BigInt(10), BigInt(5)]);

  m.call(ccfl, "setPlatformAddress", [liquidator, platform]);

  m.call(ccflPool, "setCCFL", ["0x2cfFd7F87039bbAC3c42C1739513aa03A3b39654"]);

  m.call(ccfl, "setSwapRouter", [mockSwapRouter]);

  return { ccflPool, ccfl };
});

export default ConfigModule;
