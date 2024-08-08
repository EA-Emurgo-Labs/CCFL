import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const mockSwapRouter = buildModule("MockSwapRouterModule", (m) => {
  const mockSwapRouter = m.contract("MockSwapRouter", []);
  return { mockSwapRouter };
});

export default mockSwapRouter;
