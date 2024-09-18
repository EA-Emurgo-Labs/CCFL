import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { assert, parseUnits } from "ethers";

describe.skip("CCFLLoan contract", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [
      owner,
      borrower1,
      borrower2,
      borrower3,
      lender1,
      lender2,
      lender3,
      liquidator,
      platform,
    ] = await hre.ethers.getSigners();

    const USDC = await hre.ethers.getContractFactory("MyERC20");
    const usdc = await USDC.deploy("USDC", "USDC");

    const LINK = await hre.ethers.getContractFactory("MyERC20");
    const link = await LINK.deploy("LINK", "LINK");

    const ATOKEN = await hre.ethers.getContractFactory("MyERC20");
    const aToken = await ATOKEN.deploy("ATOKEN", "ATOKEN");

    const DefaultReserveInterestRateStrategy =
      await hre.ethers.getContractFactory("DefaultReserveInterestRateStrategy");
    const defaultReserveInterestRateStrategy =
      await DefaultReserveInterestRateStrategy.deploy(
        parseUnits("0.80", 27).toString(),
        parseUnits("0.05", 27).toString(),
        parseUnits("0.04", 27).toString(),
        parseUnits("3", 27).toString()
      );

    const CCFLPool = await hre.ethers.getContractFactory("CCFLPool");
    const ccflPool = await hre.upgrades.deployProxy(
      CCFLPool,
      [
        await usdc.getAddress(),
        await defaultReserveInterestRateStrategy.getAddress(),
      ],
      { initializer: "initialize" }
    );

    console.log(
      "pool implement",
      await hre.upgrades.erc1967.getImplementationAddress(
        await ccflPool.getAddress()
      ),
      "pool proxy",
      await ccflPool.getAddress()
    );

    const MockAggr = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggr = await MockAggr.deploy();

    await mockAggr.setPrice(1e8);

    const MockAggr2 = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggr2 = await MockAggr2.deploy();

    const MockSwap = await hre.ethers.getContractFactory("MockSwapRouter");
    const mockSwap = await MockSwap.deploy();

    const MockAavePool = await hre.ethers.getContractFactory("MockAavePool");
    const mockAavePool = await MockAavePool.deploy();

    const MockPoolAddressesProvider = await hre.ethers.getContractFactory(
      "MockPoolAddressesProvider"
    );
    const mockPoolAddressesProvider = await MockPoolAddressesProvider.deploy(
      await mockAavePool.getAddress()
    );

    const CCFLLoan = await hre.ethers.getContractFactory("CCFLLoan");
    const ccflLoan = await CCFLLoan.deploy();

    const CCFL = await hre.ethers.getContractFactory("CCFL");
    const ccfl = await hre.upgrades.deployProxy(
      CCFL,
      [
        [await usdc.getAddress()],
        [await mockAggr.getAddress()],
        [await ccflPool.getAddress()],
        [await link.getAddress()],
        [await mockAggr2.getAddress()],
        [await aToken.getAddress()],
        [await mockPoolAddressesProvider.getAddress()],
        7000,
        7500,
        await ccflLoan.getAddress(),
      ],
      { initializer: "initialize" }
    );

    await ccfl.setPlatformAddress(liquidator, platform);
    await ccflPool.setCCFL(await ccfl.getAddress());
    await ccfl.setSwapRouter(await mockSwap.getAddress());

    await link.transfer(borrower1, BigInt(10000e18));
    await link.transfer(borrower2, BigInt(20000e18));
    await link.transfer(borrower3, BigInt(30000e18));

    await usdc.transfer(lender1, BigInt(10000e18));
    await usdc.transfer(lender2, BigInt(20000e18));
    await usdc.transfer(lender3, BigInt(30000e18));

    await usdc.transfer(borrower1, BigInt(1000e18));
    await usdc.transfer(borrower2, BigInt(2000e18));
    await usdc.transfer(borrower3, BigInt(3000e18));

    return {
      usdc,
      link,
      ccflPool,
      ccfl,
      owner,
      borrower1,
      borrower2,
      borrower3,
      lender1,
      lender2,
      lender3,
      mockAggr,
      aToken,
      mockAggr2,
    };
  }

  describe("Initialization", () => {
    it("Should initialize correctly", async () => {
      // TODO: test method initialize()
    });

    it("Should only allow owner to set CCFL address", async () => {
      // TODO: test method setCCFL()
    });
  });

  describe("Functionality", () => {
    it("Should supply liquidity successfully", async () => {
      // TODO: test method supplyLiquidity()
    });

    it("Should withdraw liquidity successfully", async () => {
      // TODO: test method withdrawLiquidity()
    });

    it("Should swap token for usd successfully", async () => {
      // TODO: test method swapTokenForUSD()
    });

    it("Should liquidate successfully", async () => {
      // TODO: test method liquidate()
    });

    it("Should update collateral successfully", async () => {
      // TODO: test method updateCollateral()
    });

    it("Should close loan successfully", async () => {
      // TODO: test method closeLoan()
    });

    it("Should withdraw all collateral successfully", async () => {
      // TODO: test method withdrawAllCollateral()
    });
  });

  describe("Get info", () => {
    it("Should get user account data", async () => {
      // TODO: test method getUserAccountData()
    });

    it("Should get latest price", async () => {
      // TODO: test method getLatestPrice()
    });

    it("Should get health factor", async () => {
      // TODO: test method getHealthFactor()
    });

    it("Should get loan info", async () => {
      // TODO: test method getLoanInfo()
    });
  });
});
