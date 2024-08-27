const { ethers } = require("hardhat");

let pool = "0x9a858bf4FB0E7bc4971eCd781C2A9FF981B79Aa9";
let ccfl = "0xD8F9AC90175d539E25b808c4CDfbc938e0A39cB1";

let usdc = "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8";
let wbtc = "0x29f2D40B0605204364af54EC677bD022dA425d03";
let wETH = "0xC558DBdd856501FCd9aaF1E62eae57A9F0629a3c";
let aWBTC = "0x1804Bf30507dc2EB3bDEbbbdd859991EAeF6EefF";
let aWETH = "0x5b071b590a59395fE4025A0Ccc1FcC931AAc1830";
let PoolAddressesProviderAave = "0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A";

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

async function repay(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());
  const loanId = BigInt(1);

  const iUsdc = await ethers.getContractAt("ICCFL", ccfl, signer);

  const tx = await iUsdc.repayLoan(loanId, AMOUNT, usdc);
  await tx.wait(1);
  const iUsdc2 = await ethers.getContractAt("ICCFLPool", pool, signer);
  let balance = await iUsdc2.getCurrentLoan(loanId);
  console.log(`Got ${balance}`);
}

async function createLoan() {
  const amountUsdc = ethers.parseUnits("100", 6);
  const amountWbtc = ethers.parseUnits("0.01", 8);
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

  describe("CCFL", () => {
    it("approve wbtc", async () => {
      const AMOUNT = ethers.parseUnits("0.1", 8);
      await approveWBTC(AMOUNT);
    });

    it("create a loan", async () => {
      await createLoan();
    });

    it.only("get current loan", async () => {
      getCurrentLoan(BigInt(1));
    });

    it("approve usdc", async () => {
      const AMOUNT = ethers.parseUnits("100", 6);
      await approveLoanUsdc(AMOUNT);
    });

    it("repay loan", async () => {
      repay(ethers.parseUnits("10", 6));
    });

    it("check health factor", async () => {
      await getHealthFactor(
        ethers.parseUnits("50", 6),
        ethers.parseUnits("0.0005", 8),
        BigInt(1)
      );
    });
  });
});
