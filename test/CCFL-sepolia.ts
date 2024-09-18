import { bigint } from "hardhat/internal/core/params/argumentTypes";

const { ethers } = require("hardhat");

let pool = "0xEF311683AcE00739A23a98d75F95F5c077127B85";
let ccfl = "0x127d9aC363fDE60d3C0caF5b2E7aF2bc7677e0e6";

let usdtPool = "0x7Ba01b146099Dcac43937123f10B5D92A4C3Ea12";

let usdt = "0xaa8e23fb1079ea71e0a56f48a2aa51851d8433d0";
let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
let PoolAddressesProviderAave = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";
let btcAgrr = "0x2B1EdE85Ea8105e638429a9B3Ec621d1A7939597";

async function approveUsdc(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", usdc, signer);
  console.log(await iUsdc.getAddress());
  const tx = await iUsdc.approve(pool, AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    pool
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function approveUsdt(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", usdt, signer);
  console.log(await iUsdc.getAddress());
  const tx = await iUsdc.approve(usdtPool, AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    pool
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDT.`);
}

async function approveLoanUsdc(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", usdc, signer);
  console.log(await iUsdc.getAddress());
  const tx = await iUsdc.approve(ccfl, AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    ccfl
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function approveLoanUsdt(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", usdt, signer);
  console.log(await iUsdc.getAddress());
  const tx = await iUsdc.approve(ccfl, AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    ccfl
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDT.`);
}

async function approveWBTC(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", wbtc, signer);

  const tx = await iUsdc.approve(ccfl, AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    ccfl
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} WBTC.`);
}

async function allowanceUsdc() {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", usdc, signer);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    usdc
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function allowanceUsdt() {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("IERC20Standard", usdt, signer);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    usdc
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDT.`);
}

async function supplyUsdc(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFLPool", pool, signer);

  const tx = await iUsdc.supply(AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.balanceOf(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function supplyUsdt(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFLPool", usdtPool, signer);

  const tx = await iUsdc.supply(AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.balanceOf(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDT.`);
}

async function repay(loanId: any, AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.repayLoan(loanId, AMOUNT, usdc);
  console.log(tx);
  await tx.wait(1);
  const iUsdc2 = await ethers.getContractAt("ICCFLPool", pool, signer);
  let balance = await iUsdc2.getCurrentLoan(loanId);
  console.log(`Got ${balance}`);
}

async function repayUSDT(loanId: any, AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.repayLoan(loanId, AMOUNT, usdt);
  console.log(tx);
  await tx.wait(1);
  const iUsdc2 = await ethers.getContractAt("ICCFLPool", usdtPool, signer);
  let balance = await iUsdc2.getCurrentLoan(loanId);
  console.log(`Got ${balance}`);
}

async function changeWbtcprice(price: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());
  const iUsdc = await ethers.getContractAt("MockAggregator", btcAgrr, signer);
  await iUsdc.setPrice(price);
}

async function createLoan() {
  const amountUsdc = ethers.parseUnits("1", 6);
  const amountWbtc = ethers.parseUnits("0.1", 8);
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.createLoan(
    amountUsdc,
    usdc,
    amountWbtc,
    wbtc,
    true,
    false
  );
  await tx.wait(1);
  const ids = await iUsdc.getLoanIds(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${ids}`);
}

async function createLoanUSDT() {
  const amountUsdc = ethers.parseUnits("1", 6);
  const amountWbtc = ethers.parseUnits("0.1", 8);
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.createLoan(
    amountUsdc,
    usdt,
    amountWbtc,
    wbtc,
    true,
    false
  );
  await tx.wait(1);
  const ids = await iUsdc.getLoanIds(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${ids}`);
}

async function createLoanNoStake() {
  const amountUsdc = ethers.parseUnits("1", 6);
  const amountWbtc = ethers.parseUnits("0.1", 8);
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.createLoan(
    amountUsdc,
    usdc,
    amountWbtc,
    wbtc,
    false,
    false
  );
  await tx.wait(1);
  const ids = await iUsdc.getLoanIds(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${ids}`);
}

async function withdrawCollateral(loanId: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.withdrawAllCollateral(loanId, false);
}

async function liquidate(loanId: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.liquidate(loanId);
}

async function getCurrentLoan(loanId: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFLPool", pool, signer);
  let balance = await iUsdc.getCurrentLoan(loanId);
  console.log(`Got ${balance}`);
}

async function getHealthFactor(usdcAmount: any, wbtcAmount: any, loanId: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const healthFactor = await iUsdc.getHealthFactor(BigInt(loanId));
  console.log(`Got ${healthFactor}`);

  if (usdcAmount) {
    const repayHealthFactor = await iUsdc.repayHealthFactor(
      BigInt(loanId),
      usdcAmount
    );
    console.log(`Got ${repayHealthFactor}`);
  }

  if (wbtcAmount) {
    const addCollateralHealthFactor = await iUsdc.addCollateralHealthFactor(
      BigInt(loanId),
      wbtcAmount
    );
    console.log(`Got ${addCollateralHealthFactor}`);
  }
}

async function getMinimumCollateral(usdcAmount: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const minimal = await iUsdc.checkMinimalCollateralForLoan(
    BigInt(usdcAmount),
    usdc,
    wbtc
  );
  console.log(`Got ${minimal}wBTC`);

  const estimateHeathFactor = await iUsdc.estimateHealthFactor(
    usdc,
    BigInt(1e6),
    wbtc,
    BigInt(3366)
  );
  console.log(`Got ${estimateHeathFactor} health-factor`);
}

describe("sepolia", () => {
  describe("CCFL Pool", () => {
    it("approve usdc", async () => {
      const AMOUNT = ethers.parseUnits("600", 6);
      await approveUsdc(AMOUNT);
      await allowanceUsdc();
    });

    it("supply", async () => {
      const AMOUNT = ethers.parseUnits("600", 6);
      await supplyUsdc(AMOUNT);
    });
  });

  describe("CCFL Pool usdt", () => {
    it("approve usdt", async () => {
      const AMOUNT = ethers.parseUnits("600", 6);
      await approveUsdt(AMOUNT);
      await allowanceUsdt();
    });

    it("supply", async () => {
      const AMOUNT = ethers.parseUnits("600", 6);
      await supplyUsdt(AMOUNT);
    });
  });

  describe("CCFL", () => {
    it("approve wbtc", async () => {
      const AMOUNT = ethers.parseUnits("0.1", 8);
      await approveWBTC(AMOUNT);
    });

    it("create a loan", async () => {
      await createLoan();
    });

    it("create a loan no stake", async () => {
      await createLoanNoStake();
    });

    it("get current loan", async () => {
      getCurrentLoan(BigInt(6));
    });

    it("approve usdc", async () => {
      const AMOUNT = ethers.parseUnits("200", 6);
      await approveLoanUsdc(AMOUNT);
    });

    it("repay loan", async () => {
      repay(BigInt(17), ethers.parseUnits("200", 6));
    });

    it("withdraw collateral", async () => {
      withdrawCollateral(BigInt(17));
    });

    it("check health factor", async () => {
      await getHealthFactor(
        ethers.parseUnits("0.1", 6),
        ethers.parseUnits("0.0005", 8),
        BigInt(14)
      );
    });

    it("liquidate", async () => {
      await liquidate(BigInt(20));
    });

    it("change wbtc price", async () => {
      await changeWbtcprice(60000e8);
      // await changeWbtcprice(10e8);
    });

    it("get minimal wbtc", async () => {
      // await changeWbtcprice(60000e8);
      await getMinimumCollateral(1e6);
    });
  });

  describe("CCFL usdt", () => {
    it("approve wbtc", async () => {
      const AMOUNT = ethers.parseUnits("0.1", 8);
      await approveWBTC(AMOUNT);
    });

    it("create a loan", async () => {
      await createLoanUSDT();
    });

    it("create a loan no stake", async () => {
      await createLoanNoStake();
    });

    it("get current loan", async () => {
      getCurrentLoan(BigInt(6));
    });

    it("approve usdt", async () => {
      const AMOUNT = ethers.parseUnits("200", 6);
      await approveLoanUsdt(AMOUNT);
    });

    it("repay loan", async () => {
      repayUSDT(BigInt(1), ethers.parseUnits("200", 6));
    });

    it("withdraw collateral", async () => {
      withdrawCollateral(BigInt(1));
    });

    it("check health factor", async () => {
      await getHealthFactor(
        ethers.parseUnits("0.1", 6),
        ethers.parseUnits("0.0005", 8),
        BigInt(14)
      );
    });

    it("liquidate", async () => {
      await liquidate(BigInt(20));
    });

    it("change wbtc price", async () => {
      await changeWbtcprice(60000e8);
      // await changeWbtcprice(10e8);
    });
  });
});
