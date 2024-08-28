import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
const CCFLLoanModule = buildModule("CCFLLoanModule10", (m) => {
  const loan = m.contract("CCFLLoan", []);

  return { loan };
});

export default CCFLLoanModule;
