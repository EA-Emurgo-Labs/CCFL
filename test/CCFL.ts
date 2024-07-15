import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { assert } from "ethers";

describe("CCFL system", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, borrower1, borrower2, borrower3, lender1, lender2, lender3] =
      await hre.ethers.getSigners();

    const USDC = await hre.ethers.getContractFactory("MyERC20");
    const usdc = await USDC.deploy("USDC", "USDC");

    const LINK = await hre.ethers.getContractFactory("MyERC20");
    const link = await LINK.deploy("LINK", "LINK");

    const ATOKEN = await hre.ethers.getContractFactory("MyERC20");
    const aToken = await ATOKEN.deploy("ATOKEN", "ATOKEN");

    const CCFLPool = await hre.ethers.getContractFactory("CCFLPool");
    const ccflPool = await CCFLPool.deploy(usdc);

    const MockAggr = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggr = await MockAggr.deploy();

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
        [await mockAggr.getAddress()],
        [await usdc.getAddress()],
        [await ccflPool.getAddress()],
        await ccflLoan.getAddress(),
        [await aToken.getAddress()],
        [await mockPoolAddressesProvider.getAddress()],
        [await link.getAddress()],
      ],
      { initializer: "initialize", kind: "uups" }
    );

    ccflPool.setCCFL(await ccfl.getAddress());

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
      await ccflPool.connect(lender1).depositUsd(BigInt(10000e18));
      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .depositCollateral(BigInt(1000e18), await link.getAddress());
      await ccfl
        .connect(borrower1)
        .createLoan(BigInt(1000e18), BigInt(1), await usdc.getAddress());
      await ccflPool.connect(borrower1).withdrawLoan();
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      // console.log(await ccfl.loans(borrower1, BigInt(0)));
      // borrower return monthly payment
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(10e18));
      await ccfl
        .connect(borrower1)
        .depositMonthlyPayment(1, BigInt(10e18), await usdc.getAddress());
      // close loan
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .closeLoan(1, BigInt(1000e18), await usdc.getAddress());
      await ccflPool.connect(lender1).withdrawMonthlyPayment();
    });

    // it("multi lender", async function () {
    //   const {
    //     usdc,
    //     link,
    //     ccflPool,
    //     ccflStake,
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
    //   await ccflPool.connect(lender1).depositUsdc(BigInt(10000e18));

    //   await usdc
    //     .connect(lender2)
    //     .approve(ccflPool.getAddress(), BigInt(20000e18));
    //   await ccflPool.connect(lender2).depositUsdc(BigInt(20000e18));

    //   // borrower lend
    //   await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
    //   await ccfl.connect(borrower1).depositCollateral(BigInt(1000e18), 100);
    //   await ccfl.connect(borrower1).createLoan(BigInt(1000e18), BigInt(1));
    //   await ccflPool.connect(borrower1).withdrawLoan();
    //   expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
    //     BigInt(2000e18)
    //   );
    //   // console.log(await ccfl.loans(borrower1, BigInt(0)));
    //   // borrower return monthly payment
    //   await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(10e18));
    //   await ccfl.connect(borrower1).depositMonthlyPayment(1, BigInt(10e18));
    //   // close loan
    //   await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
    //   await ccfl.connect(borrower1).closeLoan(1, BigInt(1000e18));
    //   console.log(
    //     (await ccflPool.monthlyPaymentBalance(lender1)) / BigInt(1e10)
    //   );
    //   await ccflPool.connect(lender1).withdrawMonthlyPayment();
    //   await ccflStake.getUserAccountData(borrower1);
    //   await ccflStake.getBalanceAToken(borrower1);
    // });

    // it("withdraw all USDC", async function () {
    //   const {
    //     usdc,
    //     link,
    //     ccflPool,
    //     ccflStake,
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
    //   await ccflPool.connect(lender1).depositUsdc(BigInt(10000e18));
    //   await ccflPool.connect(lender1).withdrawUsdc(BigInt(10000e18));
    // });

    // it("deposit more USDC", async function () {
    //   const {
    //     usdc,
    //     link,
    //     ccflPool,
    //     ccflStake,
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
    //   await ccflPool.connect(lender1).depositUsdc(BigInt(5000e18));
    //   await ccflPool.connect(lender1).depositUsdc(BigInt(5000e18));
    // });
  });
  // describe("Earn", function () {
  //   it("Should get loan fund", async function () {
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
  //   });
  // });
  // describe("Liquidation", function () {
  //   it("Good Health factor", async function () {
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
  //     } = await loadFixture(deployFixture);
  //     // lender deposit USDC
  //     await usdc
  //       .connect(lender1)
  //       .approve(ccflPool.getAddress(), BigInt(10000e18));
  //     await ccflPool.connect(lender1).depositUsdc(BigInt(10000e18));
  //     // borrower lend
  //     await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
  //     await ccfl.connect(borrower1).depositCollateral(BigInt(1000e18), 50);
  //     await ccfl.connect(borrower1).createLoan(BigInt(1000e18), BigInt(90));
  //     await ccflPool.connect(borrower1).withdrawLoan();
  //     expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
  //       BigInt(2000e18)
  //     );
  //     expect(await ccfl.getHealthFactor(borrower1)).to.greaterThanOrEqual(1000);
  //   });

  //   it("Bad Health factor", async function () {
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
  //     } = await loadFixture(deployFixture);
  //     // lender deposit USDC
  //     await usdc
  //       .connect(lender1)
  //       .approve(ccflPool.getAddress(), BigInt(10000e18));
  //     await ccflPool.connect(lender1).depositUsdc(BigInt(10000e18));
  //     // borrower lend
  //     await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
  //     await ccfl.connect(borrower1).depositCollateral(BigInt(1000e18), 50);
  //     await ccfl.connect(borrower1).createLoan(BigInt(1000e18), BigInt(90));
  //     await ccflPool.connect(borrower1).withdrawLoan();
  //     expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
  //       BigInt(2000e18)
  //     );
  //     await mockAggr.setPrice(BigInt(1023075000));

  //     expect(await ccfl.getHealthFactor(borrower1)).to.lessThan(1000);
  //   });

  //   it("Bad Health factor liquidation", async function () {
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
  //     await ccfl.connect(borrower1).createLoan(BigInt(1000e18), BigInt(90));
  //     await ccflPool.connect(borrower1).withdrawLoan();
  //     expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
  //       BigInt(2000e18)
  //     );
  //     await mockAggr.setPrice(BigInt(123075000));

  //     expect(await ccfl.getHealthFactor(borrower1)).to.lessThan(100);
  //     await aToken.transfer(
  //       await ccfl.aaveStakeAddresses(borrower1),
  //       BigInt(60e18)
  //     );
  //     await link.transfer(borrower1, BigInt(60e18));
  //     await usdc.transfer(await ccfl.getAddress(), BigInt(1000e18));
  //     await ccfl.liquidate(borrower1);
  //   });

  //   it("Good Health factor but not pay monthly payment", async function () {
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
  //     await ccfl.connect(borrower1).createLoan(BigInt(1000e18), BigInt(90));
  //     await ccflPool.connect(borrower1).withdrawLoan();
  //     expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
  //       BigInt(2000e18)
  //     );
  //     expect(await ccfl.getHealthFactor(borrower1)).to.greaterThanOrEqual(100);
  //     await aToken.transfer(
  //       await ccfl.aaveStakeAddresses(borrower1),
  //       BigInt(60e18)
  //     );
  //     await link.transfer(borrower1, BigInt(60e18));
  //     await usdc.transfer(await ccfl.getAddress(), BigInt(1000e18));
  //     await ccfl.liquidateMonthlyPayment(
  //       BigInt("1"),
  //       await borrower1.getAddress()
  //     );
  //   });
  // });
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
