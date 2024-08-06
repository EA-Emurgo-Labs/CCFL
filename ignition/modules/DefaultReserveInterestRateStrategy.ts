import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseUnits } from "ethers";

const DefaultReserveInterestRateStrategy = buildModule(
  "DefaultReserveInterestRateStrategyModule",
  (m) => {
    const defaultReserveInterestRateStrategy = m.contract(
      "DefaultReserveInterestRateStrategy",
      [
        parseUnits("0.80", 27).toString(),
        parseUnits("0.05", 27).toString(),
        parseUnits("0.04", 27).toString(),
        parseUnits("3", 27).toString(),
      ]
    );

    return { defaultReserveInterestRateStrategy };
  }
);

export default DefaultReserveInterestRateStrategy;
