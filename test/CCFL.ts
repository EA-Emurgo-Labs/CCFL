import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { assert } from "ethers";

describe("CCFL", function () {
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
    const ccflPool = await CCFLPool.deploy(usdc.getAddress());

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

    const CCFLStake = await hre.ethers.getContractFactory("CCFLStake");
    const ccflStake = await CCFLStake.deploy(
      await usdc.getAddress(),
      await link.getAddress(),
      await mockPoolAddressesProvider.getAddress(),
      await aToken.getAddress()
    );

    const CCFL = await hre.ethers.getContractFactory("CCFL");
    const ccfl = await CCFL.deploy(
      await usdc.getAddress(),
      await link.getAddress(),
      await mockAggr.getAddress(),
      await ccflPool.getAddress(),
      await mockSwap.getAddress(),
      await mockPoolAddressesProvider.getAddress()
    );

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
      ccflStake,
      ccfl,
      owner,
      borrower1,
      borrower2,
      borrower3,
      lender1,
      lender2,
      lender3,
    };
  }

  describe("Lending", function () {
    it("Should get loan fund", async function () {
      const {
        usdc,
        link,
        ccflPool,
        ccflStake,
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
      await ccflPool.connect(lender1).depositUsdcTokens(BigInt(10000e18));
      // borrower lend
      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl.connect(borrower1).depositCollateralLink(BigInt(1000e18), 100);
      await ccfl.connect(borrower1).createLoan(BigInt(1000e18), BigInt(90));
      await ccflPool.connect(borrower1).withdrawLoan();
      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      // console.log(await ccfl.loans(borrower1, BigInt(0)));
      // borrower return monthly payment
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(10e18));
      await ccfl.connect(borrower1).depositMonthlyPayment(1, BigInt(10e18));
      // close loan
      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl.connect(borrower1).closeLoan(1, BigInt(1000e18));
    });
  });
  describe("Earn", function () {});
  describe("Liquidation", function () {});
  describe("Collateral", function () {});

  // describe("Deployment", function () {
  //   it("Should set the right unlockTime", async function () {
  //     const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture);

  //     expect(await lock.unlockTime()).to.equal(unlockTime);
  //   });

  //   it("Should set the right owner", async function () {
  //     const { lock, owner } = await loadFixture(deployOneYearLockFixture);

  //     expect(await lock.owner()).to.equal(owner.address);
  //   });

  //   it("Should receive and store the funds to lock", async function () {
  //     const { lock, lockedAmount } = await loadFixture(
  //       deployOneYearLockFixture
  //     );

  //     expect(await hre.ethers.provider.getBalance(lock.target)).to.equal(
  //       lockedAmount
  //     );
  //   });

  //   it("Should fail if the unlockTime is not in the future", async function () {
  //     // We don't use the fixture here because we want a different deployment
  //     const latestTime = await time.latest();
  //     const Lock = await hre.ethers.getContractFactory("Lock");
  //     await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
  //       "Unlock time should be in the future"
  //     );
  //   });
  // });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployOneYearLockFixture);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       // Transactions are sent using the first signer by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployOneYearLockFixture
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  // });
  // });
});
