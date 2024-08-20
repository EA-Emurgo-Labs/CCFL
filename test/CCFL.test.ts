import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { assert, parseUnits } from "ethers";

describe("CCFL contract", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  let mockSwap, wETH9, liquidatorAddress, platformAddress, mockUniFactory;

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

    liquidatorAddress = liquidator;
    platformAddress = platform;

    const WETH9 = await hre.ethers.getContractFactory("WETH9");
    wETH9 = await WETH9.deploy();

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

    const MockAggr = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggr = await MockAggr.deploy();

    await mockAggr.setPrice(1e8);

    const MockAggr2 = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggr2 = await MockAggr2.deploy();

    await mockAggr2.setPrice(2e8);

    const MockAggr3 = await hre.ethers.getContractFactory("MockAggregator");
    const mockAggr3 = await MockAggr3.deploy();

    await mockAggr3.setPrice(2e8);

    const MockSwap = await hre.ethers.getContractFactory("MockSwapRouter");
    mockSwap = await MockSwap.deploy();

    const MockAavePool = await hre.ethers.getContractFactory("MockAavePool");
    const mockAavePool = await MockAavePool.deploy();

    const MockPoolAddressesProvider = await hre.ethers.getContractFactory(
      "MockPoolAddressesProvider"
    );
    const mockPoolAddressesProvider = await MockPoolAddressesProvider.deploy(
      await mockAavePool.getAddress()
    );

    const MockUniPool = await hre.ethers.getContractFactory("MockPool");
    const mockUniPool = await MockUniPool.deploy();

    const MockUniFactory = await hre.ethers.getContractFactory("MockFactory");
    mockUniFactory = await MockUniFactory.deploy();

    mockUniFactory.setPool(mockUniPool);

    const CCFLLoan = await hre.ethers.getContractFactory("CCFLLoan");
    const ccflLoan = await CCFLLoan.deploy();

    const CCFL = await hre.ethers.getContractFactory("CCFL");
    const ccfl = await hre.upgrades.deployProxy(
      CCFL,
      [
        [await usdc.getAddress()],
        [await mockAggr.getAddress()],
        [await ccflPool.getAddress()],
        [await link.getAddress(), await wETH9.getAddress()],
        [await mockAggr2.getAddress(), await mockAggr3.getAddress()],
        [await aToken.getAddress(), await aToken.getAddress()],
        await mockPoolAddressesProvider.getAddress(),
        5000,
        8000,
        await ccflLoan.getAddress(),
      ],
      { initializer: "initialize" }
    );
    await ccfl.setOperators([owner], [true]);
    await ccfl.setWETH(await wETH9.getAddress());

    await ccfl.setPlatformAddress(liquidator, platform);
    await ccflPool.setCCFL(await ccfl.getAddress());
    await ccfl.setSwapRouter(
      await mockSwap.getAddress(),
      await mockUniFactory.getAddress()
    );
    await ccfl.setEarnSharePercent(3000);

    await link.transfer(borrower1, BigInt(10000e18));
    await link.transfer(borrower2, BigInt(20000e18));
    await link.transfer(borrower3, BigInt(30000e18));

    await wETH9.deposit({ value: BigInt(6500e18) });
    await wETH9.transfer(borrower1, BigInt(1500e18));
    await wETH9.transfer(borrower2, BigInt(2000e18));
    await wETH9.transfer(borrower3, BigInt(3000e18));

    await usdc.transfer(lender1, BigInt(10000e18));
    await usdc.transfer(lender2, BigInt(20000e18));
    await usdc.transfer(lender3, BigInt(30000e18));

    await usdc.transfer(borrower1, BigInt(1000e18));
    await usdc.transfer(borrower2, BigInt(2000e18));
    await usdc.transfer(borrower3, BigInt(3000e18));

    return {
      usdc,
      link,
      wETH9,
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
      mockAggr3,
    };
  }

  describe("Initialization", () => {
    it("Should initialize correctly", async () => {
      const {
        usdc,
        link,
        wETH9,
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

      expect(await ccfl.owner()).to.equal(owner.address);
    });

    it("Should set swap router successfully", async () => {
      // TODO: test method setSwapRouter()
      const {
        usdc,
        link,
        wETH9,
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

      await ccfl
        .connect(owner)
        .setSwapRouter(mockSwap.getAddress(), mockUniFactory.getAddress());
    });

    it("Should only allow owner to set swap router", async () => {
      // TODO: test method setSwapRouter()
      const {
        usdc,
        link,
        wETH9,
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

      await expect(
        ccfl
          .connect(borrower1)
          .setSwapRouter(mockSwap.getAddress(), mockUniFactory.getAddress())
      ).to.be.revertedWith("18");
    });

    it("Should set platform address successfully", async () => {
      // TODO: test method setPlatformAddress()
      const {
        usdc,
        link,
        wETH9,
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

      await ccfl
        .connect(owner)
        .setPlatformAddress(liquidatorAddress, platformAddress);
    });

    it("Should only allow owner to set platform address", async () => {
      // TODO: test method setPlatformAddress()
      const {
        usdc,
        link,
        wETH9,
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

      await expect(
        ccfl
          .connect(borrower1)
          .setPlatformAddress(liquidatorAddress, platformAddress)
      ).to.be.revertedWith("18");
    });

    it("Should set wETH successfully", async () => {
      // TODO: test method setWETH()
      const {
        usdc,
        link,
        wETH9,
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

      await ccfl.connect(owner).setWETH(wETH9.getAddress());
    });

    it("Should only allow owner to set wETH", async () => {
      // TODO: test method setWETH()
      const {
        usdc,
        link,
        wETH9,
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

      await expect(
        ccfl.connect(borrower1).setWETH(wETH9.getAddress())
      ).to.be.revertedWith("18");
    });
  });

  // describe("Lender Functionality", () => {

  // });

  describe("Borrower Functionality", () => {
    it("Should create loan successfully with yield generating", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await link.getAddress(),
          true,
          false
        );

      expect(await ccfl.loandIds()).to.equal(2);
    });

    it("Should create loan successfully without yield generating", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      expect(await ccfl.loandIds()).to.equal(2);
    });

    it("Should fail to create loan if insufficient collateral", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await expect(
        ccfl
          .connect(borrower1)
          .createLoan(
            BigInt(1000e18),
            await usdc.getAddress(),
            BigInt(500e18),
            await link.getAddress(),
            false,
            false
          )
      ).to.be.revertedWith("7");
    });

    it("Should fail to create loan if insufficient fund in pool", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(500e18));
      await ccflPool.connect(lender1).supply(BigInt(500e18));

      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await expect(
        ccfl
          .connect(borrower1)
          .createLoan(
            BigInt(1000e18),
            await usdc.getAddress(),
            BigInt(1000e18),
            await link.getAddress(),
            false,
            false
          )
      ).to.be.revertedWith("8");
    });

    it("Should create loan successfully with collateral is ETH", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wETH9
        .connect(borrower1)
        .approve(ccfl.getAddress(), BigInt(1000e18));

      await ccfl
        .connect(borrower1)
        .createLoanByETH(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          false,
          false,
          { value: BigInt(1000e18) }
        );

      expect(await ccfl.loandIds()).to.equal(2);
    });

    it("Should fail to create loan (collateral is ETH) if insufficient ETH", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wETH9
        .connect(borrower1)
        .approve(ccfl.getAddress(), BigInt(1000e18));
      await expect(
        ccfl
          .connect(borrower1)
          .createLoanByETH(
            BigInt(1000e18),
            await usdc.getAddress(),
            BigInt(1000e18),
            false,
            false,
            { value: BigInt(500e18) }
          )
      ).to.be.revertedWith("6");
    });

    it("Should withdraw loan successfully", async () => {
      // TODO: test method withdrawLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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
    });

    it("Should fail to withdraw loan", async () => {
      // TODO: test method withdrawLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      await expect(
        ccfl.connect(borrower1).withdrawLoan(await usdc.getAddress(), BigInt(1))
      ).to.be.revertedWith("14");
    });

    it("Should add collateral successfully", async () => {
      // TODO: test method addCollateral()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await link.connect(borrower1).approve(ccfl.getAddress(), BigInt(1500e18));
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
        .addCollateral(
          BigInt(1),
          BigInt(500e18),
          await link.getAddress(),
          false
        );

      expect(await link.balanceOf(await ccfl.getLoanAddress(1))).to.equal(
        BigInt(1500e18)
      );
    });

    it("Should add collateral (ETH) successfully", async () => {
      // TODO: test method addCollateral()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wETH9
        .connect(borrower1)
        .approve(ccfl.getAddress(), BigInt(1500e18));
      await ccfl
        .connect(borrower1)
        .createLoanByETH(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          false,
          false,
          { value: BigInt(1000e18) }
        );

      await ccfl
        .connect(borrower1)
        .addCollateral(
          BigInt(1),
          BigInt(500e18),
          await wETH9.getAddress(),
          true,
          { value: BigInt(500e18) }
        );

      expect(await wETH9.balanceOf(await ccfl.getLoanAddress(1))).to.equal(
        BigInt(1500e18)
      );
    });

    it("Should fail to add collateral (ETH) if insufficient ETH", async () => {
      // TODO: test method addCollateral()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wETH9
        .connect(borrower1)
        .approve(ccfl.getAddress(), BigInt(1500e18));
      await ccfl
        .connect(borrower1)
        .createLoanByETH(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          false,
          false,
          { value: BigInt(1000e18) }
        );

      await expect(
        ccfl
          .connect(borrower1)
          .addCollateral(
            BigInt(1),
            BigInt(500e18),
            await wETH9.getAddress(),
            true,
            { value: BigInt(100e18) }
          )
      ).to.be.revertedWith("6");
    });

    it("Should repay loan succesfully", async () => {
      // TODO: test method repayLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1100e18));

      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(1100e18), await usdc.getAddress());

      expect(await usdc.balanceOf(await borrower1.getAddress())).to.lt(
        BigInt(1000e18)
      );
    });

    it("Should repay loan partially", async () => {
      // TODO: test method repayLoan()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(500e18));

      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(500e18), await usdc.getAddress());

      expect(await usdc.balanceOf(await borrower1.getAddress())).to.equal(
        BigInt(1500e18)
      );
    });

    it("Should withdraw all collateral successfully", async () => {
      // TODO: test method withdrawAllCollateral()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1100e18));

      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(1100e18), await usdc.getAddress());

      // const check = await ccflPool.connect(borrower1).getCurrentLoan(1);
      // console.log('check: ', check);

      await ccfl.connect(borrower1).withdrawAllCollateral(1, false);

      expect(await link.balanceOf(await borrower1.getAddress())).to.equal(
        BigInt(10000e18)
      );
    });

    it("Should withdraw all collateral (ETH) successfully", async () => {
      // TODO: test method withdrawAllCollateral()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wETH9
        .connect(borrower1)
        .approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoanByETH(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          false,
          false,
          { value: BigInt(1000e18) }
        );

      await ccfl
        .connect(borrower1)
        .withdrawLoan(await usdc.getAddress(), BigInt(1));

      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1100e18));

      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(1100e18), await usdc.getAddress());

      // const check = await ccflPool.connect(borrower1).getCurrentLoan(1);
      // console.log('check: ', check);

      await ccfl.connect(borrower1).withdrawAllCollateral(1, true);

      // expect(await wETH9.balanceOf(await borrower1.getAddress())).to.equal(BigInt(1500e18));
    });

    it("Should liquidate loan successfully", async () => {
      // TODO: test method liquidate()
      const {
        usdc,
        link,
        wETH9,
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

      // let usdcAmount0 = await usdc.balanceOf(borrower1.getAddress());
      // let linkAmount0 = await link.balanceOf(borrower1.getAddress());
      // console.log('before: ', usdcAmount0, linkAmount0);

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
      await mockAggr2.setPrice(BigInt(999999));

      expect(await ccfl.getHealthFactor(BigInt(1))).to.lessThan(100);

      await aToken.transfer(
        await ccfl.getLoanAddress(BigInt(1)),
        BigInt(60e18)
      );

      await link.transfer(borrower1, BigInt(60e18));
      let loanAddr = await ccfl.getLoanAddress(BigInt(1));
      await usdc.transfer(loanAddr, BigInt(1200e18));
      await ccfl.liquidate(BigInt(1));

      let usdcAmount = await usdc.balanceOf(borrower1.getAddress());
      let linkAmount = await link.balanceOf(borrower1.getAddress());
      // console.log('after: ', usdcAmount, linkAmount);

      expect(usdcAmount).to.equal(BigInt(2000e18));
      expect(linkAmount).to.lt(BigInt(10000e18));
    });
  });

  describe("Get info", () => {
    it("Should get the minimal collateral", async () => {
      // TODO: test method getMinimalCollateral()
      const {
        usdc,
        link,
        wETH9,
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

      const minimal = await ccfl.getMinimalCollateral(
        BigInt(1000e18),
        await usdc.getAddress(),
        await link.getAddress()
      );

      expect(minimal).to.gt(BigInt(0));
    });

    it("Should get the latest price of usdc", async () => {
      // TODO: test method getLatestPrice()
      const {
        usdc,
        link,
        wETH9,
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

      const latestPrice = await ccfl.getLatestPrice(
        await usdc.getAddress(),
        true
      );

      expect(latestPrice).to.eq(1e8);
    });

    it("Should get the latest price of eth", async () => {
      // TODO: test method getLatestPrice()
      const {
        usdc,
        link,
        wETH9,
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

      const latestPrice = await ccfl.getLatestPrice(
        await wETH9.getAddress(),
        false
      );

      expect(latestPrice).to.eq(2e8);
    });

    it("Should get health factor", async () => {
      // TODO: test method getHealthFactor()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      const healthFactor = await ccfl.getHealthFactor(1);
      // console.log('healthFactor: ', healthFactor);

      expect(healthFactor).to.gt(BigInt(100));
    });

    it("Should get loan address", async () => {
      // TODO: test method getLoanAddress()
      const {
        usdc,
        link,
        wETH9,
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

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

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

      expect(await ccfl.getLoanAddress(1)).to.not.eq("");
    });
  });
});
