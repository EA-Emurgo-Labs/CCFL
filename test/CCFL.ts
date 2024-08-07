import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { parseUnits } from "ethers";

describe("CCFL system", function () {
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

    const WETH9 = await hre.ethers.getContractFactory("WETH9");
    const wETH9 = await WETH9.deploy();

    const USDC = await hre.ethers.getContractFactory("MyERC20");
    const usdc = await USDC.deploy("USDC", "USDC");

    const USDT = await hre.ethers.getContractFactory("MyERC20");
    const usdt = await USDT.deploy("USDT", "USDT");

    const LINK = await hre.ethers.getContractFactory("MyERC20");
    const link = await LINK.deploy("LINK", "LINK");

    const WBTC = await hre.ethers.getContractFactory("MyERC20");
    const wBTC = await WBTC.deploy("WBTC", "WBTC");

    const ATOKEN = await hre.ethers.getContractFactory("MyERC20");
    const aToken = await ATOKEN.deploy("ATOKEN", "ATOKEN");

    const AWBTC = await hre.ethers.getContractFactory("MyERC20");
    const aWBTC = await AWBTC.deploy("AWBTC", "AWBTC");

    const AWETH = await hre.ethers.getContractFactory("MyERC20");
    const aWETH = await AWETH.deploy("AWETH", "AWETH");

    const DefaultReserveInterestRateStrategy =
      await hre.ethers.getContractFactory("DefaultReserveInterestRateStrategy");
    const defaultReserveInterestRateStrategy =
      await DefaultReserveInterestRateStrategy.deploy(
        parseUnits("0.80", 27).toString(),
        parseUnits("0.05", 27).toString(),
        parseUnits("0.04", 27).toString(),
        parseUnits("3", 27).toString()
      );

    console.log(
      await defaultReserveInterestRateStrategy.getBaseVariableBorrowRate(),
      await defaultReserveInterestRateStrategy.getVariableRateSlope1(),
      await defaultReserveInterestRateStrategy.getVariableRateSlope2(),
      await defaultReserveInterestRateStrategy.getMaxVariableBorrowRate()
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

    const CCFLPool2 = await hre.ethers.getContractFactory("CCFLPool");
    const ccflPool2 = await hre.upgrades.deployProxy(
      CCFLPool2,
      [
        await usdt.getAddress(),
        await defaultReserveInterestRateStrategy.getAddress(),
      ],
      { initializer: "initialize" }
    );

    const MockAggrUSDC = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggrUSDC = await MockAggrUSDC.deploy();

    await mockAggrUSDC.setPrice(1e8);

    const MockAggrUSDT = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggrUSDT = await MockAggrUSDT.deploy();

    await mockAggrUSDT.setPrice(1.1e8);

    const MockAggrWBTC = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggrWBTC = await MockAggrWBTC.deploy();

    await mockAggrWBTC.setPrice(60000e8);

    const MockAggrWETH = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggrWETH = await MockAggrWETH.deploy();

    await mockAggrWETH.setPrice(4000e8);

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

    const MockSwapWBTC = await hre.ethers.getContractFactory("MockSwapRouter");
    const mockSwapWBTC = await MockSwapWBTC.deploy();

    const CCFLLoan = await hre.ethers.getContractFactory("CCFLLoan");
    const ccflLoan = await CCFLLoan.deploy();

    const CCFL = await hre.ethers.getContractFactory("CCFL");
    const ccfl = await hre.upgrades.deployProxy(
      CCFL,
      [
        [await usdc.getAddress()],
        [await mockAggrUSDC.getAddress()],
        [await ccflPool.getAddress()],
        [await link.getAddress()],
        [await mockAggr2.getAddress()],
        [await aToken.getAddress()],
        await mockPoolAddressesProvider.getAddress(),
        7000,
        7500,
        await ccflLoan.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await ccfl.setWETH(await wETH9.getAddress());
    await ccfl.setPenalty(BigInt(5), BigInt(10), BigInt(5));

    await ccfl.setPlatformAddress(liquidator, platform);
    await ccflPool.setCCFL(await ccfl.getAddress());
    await ccfl.setSwapRouter(await mockSwap.getAddress());

    await ccfl.setPools(
      [await usdt.getAddress()],
      [await mockAggrUSDT.getAddress()],
      [await ccflPool2.getAddress()]
    );

    await ccfl.setCollaterals(
      [await wBTC.getAddress()],
      [await mockAggrWBTC.getAddress()],
      [await aWBTC.getAddress()]
    );

    await ccfl.setCollaterals(
      [await wETH9.getAddress()],
      [await mockAggrWETH.getAddress()],
      [await aWETH.getAddress()]
    );

    await ccfl.setActiveToken(await usdt.getAddress(), true, true);
    await ccfl.setActiveToken(await link.getAddress(), true, false);
    await ccfl.setThreshold(7000, 7500);

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
      mockAggrUSDC,
      aToken,
      mockAggr2,
      wETH9,
    };
  }

  describe("Lending", function () {
    it("Should get loan fund at over 80% pool", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(1100e18));
      await ccflPool.connect(lender1).supply(BigInt(1100e18));
      await time.increase(30 * 24 * 3600);
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      // borrower
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(500e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(950e18),
          await usdc.getAddress(),
          BigInt(500e18),
          await link.getAddress(),
          false,
          false
        );
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );

      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      await time.increase(300 * 24 * 3600);
      // borrower
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(300e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(80e18),
          await usdc.getAddress(),
          BigInt(300e18),
          await link.getAddress(),
          false,
          false
        );

      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(200e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(40e18),
          await usdc.getAddress(),
          BigInt(200e18),
          await link.getAddress(),
          false,
          false
        );
    });

    it("Should get loan fund", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      await time.increase(30 * 24 * 3600);
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      // borrower
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false,
          false
        );
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );

      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      await time.increase(300 * 24 * 3600);
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      // lender deposit USDC
      await usdc
        .connect(lender2)
        .approve(ccflPool.getAddress(), BigInt(20000e18));
      await ccflPool.connect(lender2).supply(BigInt(20000e18));
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      await time.increase(90 * 24 * 3600);
      // borrower
      await link.connect(borrower2).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower2)
        .createLoan(
          BigInt(2000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false,
          false
        );
      await time.increase(180 * 24 * 3600);
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      // borrower
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(10e18));
      await time.increase(30 * 24 * 3600);
      // close loan
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(2000e18));
      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(2000e18), await usdc.getAddress());
      // console.log("remain", (await ccflPool.getRemainingPool()) / BigInt(1e18));
      // console.log(
      //   "total supply",
      //   (await ccflPool.getTotalSupply()) / BigInt(1e18)
      // );
      // console.log(
      //   "coin in sc",
      //   (await usdc.balanceOf(await ccflPool.getAddress())) / BigInt(1e18)
      // );
      // console.log("debt", (await ccflPool.getDebtPool()) / BigInt(1e18));
      // console.log("rate", await ccflPool.getCurrentRate());
      await ccfl.connect(borrower1).withdrawAllCollateral(BigInt(1), false);
    });

    it("Should get back collateral", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(900e18),
          await link.getAddress(),
          false,
          false
        );

      await time.increase(30 * 24 * 3600);

      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );

      await ccfl
        .connect(borrower1)
        .addCollateral(
          BigInt(1),
          BigInt(100e18),
          await link.getAddress(),
          false
        );
      // borrower return monthly payment
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(10e18));
      await time.increase(30 * 24 * 3600);
      // close loan
      let debt = await ccflPool.getCurrentLoan(BigInt(1));
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1100e18));
      await ccfl
        .connect(borrower1)
        .repayLoan(
          1,
          (BigInt(debt) * BigInt(101)) / BigInt(100),
          await usdc.getAddress()
        );
      let debt1 = await ccflPool.getCurrentLoan(BigInt(1));
      expect(debt1 == BigInt(0), "Can not close loan");
    });

    it("multi lender", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await usdc
        .connect(lender2)
        .approve(ccflPool.getAddress(), BigInt(20000e18));
      await ccflPool.connect(lender2).supply(BigInt(20000e18));

      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false,
          false
        );
      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );

      // borrower return monthly payment
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(10e18));
      await time.increase(30 * 24 * 3600);
      // close loan
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(1000e18), await usdc.getAddress());
    });

    it("withdraw all USDC", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      await ccflPool.connect(lender1).withdraw(BigInt(10000e18));
    });

    it("deposit more USDC", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(5000e18));
      await ccflPool.connect(lender1).supply(BigInt(5000e18));
    });
  });
  describe("ETH", function () {
    it("Should get loan fund", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(950e18),
          await usdc.getAddress(),
          BigInt(500e18),
          await link.getAddress(),
          true,
          false
        );
    });

    it("Should get loan fund by ETH", async function () {
      const {
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
        mockAggrUSDC,
        aToken,
        mockAggr2,
        wETH9,
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      // borrower lend
      // await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(5e18),
          await wETH9.getAddress(),
          true,
          true,
          { value: parseUnits("5", 18).toString() }
        );

      await ccfl.addCollateral(
        BigInt(1),
        BigInt(2e18),
        await wETH9.getAddress(),
        true,
        { value: parseUnits("2", 18).toString() }
      );

      console.log(
        await ccflPool.getTotalSupply(),
        await ccflPool.getDebtPool(),
        await ccflPool.getCurrentRate()
      );
    });
  });
  describe("Liquidation", function () {
    it("Good Health factor", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false,
          false
        );
      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      // console.log(await ccfl.getHealthFactor(BigInt(1)));
      expect(await ccfl.getHealthFactor(BigInt(1))).to.greaterThanOrEqual(100);
    });

    it("Bad Health factor", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false,
          false
        );
      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      await mockAggr2.setPrice(BigInt(13075000));

      expect(await ccfl.getHealthFactor(BigInt(1))).to.lessThan(100);
    });

    it("Bad Health factor liquidation", async function () {
      const {
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
      } = await loadFixture(deployFixture);
      // lender deposit USDC
      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));
      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false,
          false
        );
      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      await mockAggr2.setPrice(BigInt(103075000));

      // expect(await ccfl.getHealthFactor(BigInt(1))).to.lessThan(100);

      await aToken.transfer(
        await ccfl.getLoanAddress(BigInt(1)),
        BigInt(60e18)
      );
      await link.transfer(borrower1, BigInt(60e18));
      let loanAddr = await ccfl.getLoanAddress(BigInt(1));
      await usdc.transfer(loanAddr, BigInt(1200e18));
      await ccfl.liquidate(BigInt(1));
    });
  });
});
