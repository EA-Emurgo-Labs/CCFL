import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { assert, parseUnits } from "ethers";

describe("CCFL contract", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  let mockSwap,
    wETH9,
    liquidatorAddress,
    platformAddress,
    mockUniFactory,
    mockUniQuoter;

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
    const wETH9 = await WETH9.deploy();

    const USDC = await hre.ethers.getContractFactory("MyERC20");
    const usdc = await USDC.deploy("USDC", "USDC");

    const USDT = await hre.ethers.getContractFactory("MyERC20");
    const usdt = await USDT.deploy("USDT", "USDT");

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
        BigInt(1000000000e18),
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
        BigInt(1000000000e18),
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
    mockSwap = await MockSwap.deploy();

    const MockAavePool = await hre.ethers.getContractFactory("MockAavePool");
    const mockAavePool = await MockAavePool.deploy();

    const MockPoolAddressesProvider = await hre.ethers.getContractFactory(
      "MockPoolAddressesProvider"
    );
    const mockPoolAddressesProvider = await MockPoolAddressesProvider.deploy();

    console.log("mockAavePool", await mockAavePool.getAddress());
    await mockPoolAddressesProvider.setPool(await mockAavePool.getAddress());

    const MockUniPool = await hre.ethers.getContractFactory("MockPool");
    const mockUniPool = await MockUniPool.deploy();

    const MockUniFactory = await hre.ethers.getContractFactory("MockFactory");
    mockUniFactory = await MockUniFactory.deploy();

    mockUniFactory.setPool(mockUniPool);

    const MockUniQuoter = await hre.ethers.getContractFactory("MockQuoter");
    mockUniQuoter = await MockUniQuoter.deploy();

    const MockSwapWBTC = await hre.ethers.getContractFactory("MockSwapRouter");
    const mockSwapWBTC = await MockSwapWBTC.deploy();

    const CCFLLoan = await hre.ethers.getContractFactory("CCFLLoan");
    const ccflLoan = await CCFLLoan.deploy();

    const CCFLConfig = await hre.ethers.getContractFactory("CCFLConfig");
    const ccflConfig = await hre.upgrades.deployProxy(
      CCFLConfig,
      [
        5000,
        8000,
        await mockSwap.getAddress(),
        await mockUniFactory.getAddress(),
        await mockUniQuoter.getAddress(),
        await mockPoolAddressesProvider.getAddress(""),
        await liquidator.getAddress(),
        await platform.getAddress(),
        true,
        await wETH9.getAddress(),
      ],
      { initializer: "initialize" }
    );
    const CCFL = await hre.ethers.getContractFactory("CCFL");
    const ccfl = await hre.upgrades.deployProxy(
      CCFL,
      [
        [await usdc.getAddress()],
        [await ccflPool.getAddress()],
        await ccflConfig.getAddress(),
        await ccflLoan.getAddress(),
      ],
      { initializer: "initialize" }
    );

    await ccflConfig.setPenalty(BigInt(50), BigInt(100), BigInt(50));
    await ccflConfig.setEarnShare(7000, 2000, 1000);

    await ccflConfig.setCollaterals(
      [await wBTC.getAddress(), await wETH9.getAddress()],
      [await mockAggrWBTC.getAddress(), await mockAggrWETH.getAddress()],
      [await aWBTC.getAddress(), await aWETH.getAddress()]
    );

    await ccflConfig.setPoolCoins(
      [await usdc.getAddress(), await usdt.getAddress()],
      [await mockAggrUSDC.getAddress(), await mockAggrUSDT.getAddress()]
    );

    await ccflConfig.setCollateralToStableFee(
      [
        await wBTC.getAddress(),
        await wBTC.getAddress(),
        await wETH9.getAddress(),
        await wETH9.getAddress(),
      ],
      [
        await usdc.getAddress(),
        await usdt.getAddress(),
        await usdc.getAddress(),
        await usdt.getAddress(),
      ],
      [3000, 3000, 3000, 3000]
    );

    await ccflPool.setCCFL(await ccfl.getAddress());
    await ccflPool2.setCCFL(await ccfl.getAddress());

    await wBTC.transfer(borrower1, BigInt(10000e18));
    await wBTC.transfer(borrower2, BigInt(20000e18));
    await wBTC.transfer(borrower3, BigInt(30000e18));

    await usdc.transfer(lender1, BigInt(10000e18));
    await usdc.transfer(lender2, BigInt(20000e18));
    await usdc.transfer(lender3, BigInt(30000e18));

    await usdc.transfer(borrower1, BigInt(1000e18));
    await usdc.transfer(borrower2, BigInt(2000e18));
    await usdc.transfer(borrower3, BigInt(3000e18));

    return {
      usdc,
      wBTC,
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
      mockAggrWBTC,
      ccflConfig,
    };
  }

  describe("Initialization", () => {
    it("Should initialize correctly", async () => {
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      expect(await ccfl.owner()).to.equal(owner.address);
    });

    it("Should set swap router successfully", async () => {
      // TODO: test method setSwapRouter()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await ccflConfig
        .connect(owner)
        .setSwapRouter(
          await mockSwap.getAddress(),
          await mockUniFactory.getAddress(),
          await mockUniQuoter.getAddress()
        );
    });

    it("Should only allow owner to set swap router", async () => {
      // TODO: test method setSwapRouter()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await expect(
        ccflConfig
          .connect(borrower1)
          .setSwapRouter(
            mockSwap.getAddress(),
            mockUniFactory.getAddress(),
            await mockUniQuoter.getAddress()
          )
      ).to.be.revertedWith("2");
    });

    it("Should set platform address successfully", async () => {
      // TODO: test method setPlatformAddress()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await ccflConfig
        .connect(owner)
        .setPlatformAddress(liquidatorAddress, platformAddress);
    });

    it("Should only allow owner to set platform address", async () => {
      // TODO: test method setPlatformAddress()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await expect(
        ccflConfig
          .connect(borrower1)
          .setPlatformAddress(liquidatorAddress, platformAddress)
      ).to.be.revertedWith("2");
    });

    it("Should set wETH successfully", async () => {
      // TODO: test method setWETH()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await ccflConfig.connect(owner).setWETH(wETH9.getAddress());
    });

    it("Should only allow owner to set wETH", async () => {
      // TODO: test method setWETH()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await expect(
        ccflConfig.connect(borrower1).setWETH(wETH9.getAddress())
      ).to.be.revertedWith("2");
    });
  });

  // describe("Lender Functionality", () => {

  // });

  describe("Borrower Functionality", () => {
    it("Should create loan successfully with yield generating", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          true,
          false
        );

      expect(await ccfl.loandIds()).to.equal(2);
    });

    it("Should create loan successfully without yield generating", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

      expect(await ccfl.loandIds()).to.equal(2);
    });

    it("Should fail to create loan if insufficient collateral", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await expect(
        ccfl
          .connect(borrower1)
          .createLoan(
            BigInt(1000e18),
            await usdc.getAddress(),
            BigInt(1e16),
            await wBTC.getAddress(),
            false,
            false
          )
      ).to.be.revertedWith("7");
    });

    it("Should fail to create loan if insufficient fund in pool", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(500e18));
      await ccflPool.connect(lender1).supply(BigInt(500e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await expect(
        ccfl
          .connect(borrower1)
          .createLoan(
            BigInt(1000e18),
            await usdc.getAddress(),
            BigInt(1000e18),
            await wBTC.getAddress(),
            false,
            false
          )
      ).to.be.revertedWith("8");
    });

    it("Should create loan successfully with collateral is ETH", async () => {
      // TODO: test method createLoan()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
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
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
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
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
    });

    it("Should add collateral successfully", async () => {
      // TODO: test method addCollateral()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1500e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

      await ccfl
        .connect(borrower1)
        .addCollateral(BigInt(1), BigInt(500e18), await wBTC.getAddress());

      expect(await wBTC.balanceOf(await ccfl.getLoanAddress(1))).to.equal(
        BigInt(1500e18)
      );
    });

    it("Should add collateral (ETH) successfully", async () => {
      // TODO: test method addCollateral()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
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
        .addCollateralByETH(BigInt(1), BigInt(500e18), {
          value: BigInt(500e18),
        });

      expect(await wETH9.balanceOf(await ccfl.getLoanAddress(1))).to.equal(
        BigInt(1500e18)
      );
    });

    it("Should fail to add collateral (ETH) if insufficient ETH", async () => {
      // TODO: test method addCollateral()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
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
        ccfl.connect(borrower1).addCollateralByETH(BigInt(1), BigInt(500e18), {
          value: BigInt(100e18),
        })
      ).to.be.revertedWith("6");
    });

    it("Should repay loan succesfully", async () => {
      // TODO: test method repayLoan()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

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
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

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
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

      await usdc.connect(borrower1).approve(ccfl.getAddress(), BigInt(1100e18));

      await ccfl
        .connect(borrower1)
        .repayLoan(1, BigInt(1100e18), await usdc.getAddress());

      // const check = await ccflPool.connect(borrower1).getCurrentLoan(1);
      // console.log('check: ', check);

      await ccfl.connect(borrower1).withdrawAllCollateral(1, false);

      expect(await wBTC.balanceOf(await borrower1.getAddress())).to.equal(
        BigInt(10000e18)
      );
    });

    it("Should withdraw all collateral (ETH) successfully", async () => {
      // TODO: test method withdrawAllCollateral()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
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
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
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
      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1e17),
          await wBTC.getAddress(),
          false,
          false
        );

      expect(BigInt(await usdc.balanceOf(borrower1)).toString()).to.eq(
        BigInt(2000e18)
      );
      await mockAggrWBTC.setPrice(BigInt(9999));

      expect(await ccfl.getHealthFactor(BigInt(1))).to.lessThan(100);

      await aToken.transfer(
        await ccfl.getLoanAddress(BigInt(1)),
        BigInt(60e18)
      );

      await wBTC.transfer(borrower1, BigInt(60e18));
      let loanAddr = await ccfl.getLoanAddress(BigInt(1));
      await usdc.transfer(loanAddr, BigInt(1200e18));
      await ccfl.liquidate(BigInt(1));

      let usdcAmount = await usdc.balanceOf(borrower1.getAddress());
      let linkAmount = await wBTC.balanceOf(borrower1.getAddress());
      // console.log('after: ', usdcAmount, linkAmount);

      expect(usdcAmount).to.equal(BigInt(2000e18));
      expect(linkAmount).to.lt(BigInt(20000e18));
    });
  });

  describe("Get info", () => {
    it("Should get the minimal collateral", async () => {
      // TODO: test method getMinimalCollateral()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      const minimal = await ccfl.checkMinimalCollateralForLoan(
        BigInt(1000e18),
        await usdc.getAddress(),
        await wBTC.getAddress()
      );

      expect(minimal).to.gt(BigInt(0));
    });

    it("Should get the latest price of usdc", async () => {
      // TODO: test method getLatestPrice()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      const latestPrice = await ccflConfig.getLatestPrice(
        await usdc.getAddress(),
        true
      );

      expect(latestPrice).to.eq(1e8);
    });

    it("Should get the latest price of eth", async () => {
      // TODO: test method getLatestPrice()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      const latestPrice = await ccflConfig.getLatestPrice(
        await wETH9.getAddress(),
        false
      );

      expect(latestPrice).to.eq(400000000000);
    });

    it("Should get health factor", async () => {
      // TODO: test method getHealthFactor()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );

      const healthFactor = await ccfl.getHealthFactor(1);
      // console.log('healthFactor: ', healthFactor);

      expect(healthFactor).to.gt(BigInt(100));
    });

    it("Should get loan address", async () => {
      // TODO: test method getLoanAddress()
      const {
        usdc,
        wBTC,
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
        mockAggrWBTC,
        ccflConfig,
      } = await loadFixture(deployFixture);

      await usdc
        .connect(lender1)
        .approve(ccflPool.getAddress(), BigInt(10000e18));
      await ccflPool.connect(lender1).supply(BigInt(10000e18));

      await wBTC.connect(borrower1).approve(ccfl.getAddress(), BigInt(1000e18));
      await ccfl
        .connect(borrower1)
        .createLoan(
          BigInt(1000e18),
          await usdc.getAddress(),
          BigInt(1000e18),
          await wBTC.getAddress(),
          false,
          false
        );
      expect(await ccfl.getLoanAddress(1)).to.not.eq("");
    });
  });
});
