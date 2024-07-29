import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { assert, parseUnits } from "ethers";

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
    const ccflPool = await CCFLPool.deploy(
      usdc,
      await defaultReserveInterestRateStrategy.getAddress()
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
      { initializer: "initialize", kind: "uups" }
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

  describe("Lending", function () {
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
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          false
        );

      await time.increase(30 * 24 * 3600);
      // lender deposit USDC
      await usdc
        .connect(lender2)
        .approve(ccflPool.getAddress(), BigInt(20000e18));
      await ccflPool.connect(lender2).supply(BigInt(20000e18));
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
          BigInt(1000e18),
          await link.getAddress(),
          false
        );

      await time.increase(30 * 24 * 3600);

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
  describe("Earn", function () {
    // it("Should get loan fund", async function () {
    //   const {
    //     usdc,
    //     link,
    //     ccflPool,
    //     ccfl,
    //     owner,
    //     borrower1,
    //     borrower2,
    //     borrower3,
    //     lender1,
    //     lender2,
    //     lender3,
    //   } = await loadFixture(deployFixture);
    //   // lender deposit USDC
    //   await usdc
    //     .connect(lender1)
    //     .approve(ccflPool.getAddress(), BigInt(10000e18));
    //   await ccflPool.connect(lender1).depositUsd(BigInt(10000e18));
    //   // borrower lend
    //   await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
    //   await ccfl
    //     .connect(borrower1)
    //     .depositCollateral(BigInt(1000e18), await link.getAddress());
    // });
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

    it.only("Bad Health factor liquidation", async function () {
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
  // describe("Collateral", function () {
  //   it("Should remove liquidity", async function () {
  //     const {
  //       usdc,
  //       link,
  //       ccflPool,
  //       ccflStake,
  //       ccfl,
  //       owner,
  //       borrower1,
  //       borrower2,
  //       borrower3,
  //       lender1,
  //       lender2,
  //       lender3,
  //       mockAggr,
  //       aToken,
  //     } = await loadFixture(deployFixture);
  //     // lender deposit USDC
  //     await usdc
  //       .connect(lender1)
  //       .approve(ccflPool.getAddress(), BigInt(10000e18));
  //     await ccflPool.connect(lender1).depositUsdc(BigInt(10000e18));
  //     // borrower lend
  //     await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
  //     await ccfl.connect(borrower1).depositCollateral(BigInt(1000e18), 50);
  //     expect(await ccfl.aaveStakeAddresses(borrower1)).to.not.equal("");
  //     // console.log(await ccfl.aaveStakeAddresses(borrower1));
  //     // return atoken
  //     await aToken.transfer(
  //       await ccfl.aaveStakeAddresses(borrower1),
  //       BigInt(600e18)
  //     );
  //     // console.log(
  //     //   await ccflStake.getBalanceAToken(
  //     //     await ccfl.aaveStakeAddresses(borrower1)
  //     //   )
  //     // );
  //     await ccfl.connect(borrower1).withdrawLiquidity();
  //     await link.transfer(borrower1, BigInt(600e18));
  //     expect(await ccfl.collateral(borrower1)).to.greaterThan(BigInt(600e18));
  //   });

  //   it("Should withdraw collateral", async function () {
  //     const {
  //       usdc,
  //       link,
  //       ccflPool,
  //       ccflStake,
  //       ccfl,
  //       owner,
  //       borrower1,
  //       borrower2,
  //       borrower3,
  //       lender1,
  //       lender2,
  //       lender3,
  //       mockAggr,
  //       aToken,
  //     } = await loadFixture(deployFixture);
  //     // lender deposit USDC
  //     await usdc
  //       .connect(lender1)
  //       .approve(ccflPool.getAddress(), BigInt(10000e18));
  //     await ccflPool.connect(lender1).depositUsdc(BigInt(10000e18));
  //     // borrower lend
  //     await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
  //     await ccfl.connect(borrower1).depositCollateral(BigInt(1000e18), 50);
  //     expect(await ccfl.aaveStakeAddresses(borrower1)).to.not.equal("");
  //     // console.log(await ccfl.aaveStakeAddresses(borrower1));
  //     // return atoken
  //     await aToken.transfer(
  //       await ccfl.aaveStakeAddresses(borrower1),
  //       BigInt(60e18)
  //     );
  //     // console.log(
  //     //   await ccflStake.getBalanceAToken(
  //     //     await ccfl.aaveStakeAddresses(borrower1)
  //     //   )
  //     // );
  //     await ccfl.connect(borrower1).withdrawLiquidity();
  //     await link.transfer(borrower1, BigInt(60e18));
  //     await ccfl.connect(borrower1).withdrawCollateral(BigInt(60e18));
  //     expect(await ccfl.collateral(borrower1)).to.lessThan(BigInt(9070e18));
  //   });
  // });
});
