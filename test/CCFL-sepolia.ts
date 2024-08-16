const { ethers } = require("hardhat");

async function approveUsdc(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "IERC20Standard",
    "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    signer
  );
  console.log(await iUsdc.getAddress());
  const tx = await iUsdc.approve(
    "0xe0c51054586414A7A89bea3E2D56E04f07Bc73c3",
    AMOUNT
  );
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    "0xe0c51054586414A7A89bea3E2D56E04f07Bc73c3"
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function approveWBTC(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "IERC20Standard",
    "0x29f2D40B0605204364af54EC677bD022dA425d03",
    signer
  );

  const tx = await iUsdc.approve(
    "0x7B7450f910644A4EDe3183B7fCC5313a043f335C",
    AMOUNT
  );
  await tx.wait(1);
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    "0x7B7450f910644A4EDe3183B7fCC5313a043f335C"
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} WBTC.`);
}

async function allowanceUsdc() {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "IERC20Standard",
    "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    signer
  );
  const balance = await iUsdc.allowance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149",
    "0xe0c51054586414A7A89bea3E2D56E04f07Bc73c3"
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function supplyUsdc(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "ICCFLPool",
    "0xe0c51054586414A7A89bea3E2D56E04f07Bc73c3",
    signer
  );

  const tx = await iUsdc.supply(AMOUNT);
  await tx.wait(1);
  const balance = await iUsdc.balance(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${(balance / BigInt(1e6)).toString()} USDC.`);
}

async function createLoan() {
  const amountUsdc = ethers.parseUnits("100", 6);
  const amountWbtc = ethers.parseUnits("0.01", 8);
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "ICCFL",
    "0x7B7450f910644A4EDe3183B7fCC5313a043f335C",
    signer
  );

  const tx = await iUsdc.createLoan(
    amountUsdc,
    "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    amountWbtc,
    "0x29f2D40B0605204364af54EC677bD022dA425d03",
    true,
    false
  );
  await tx.wait(1);
  const ids = await iUsdc.getLoanIds(
    "0x17883e3728E7bB528b542B8AAb354022eD20C149"
  );
  console.log(`Got ${ids}`);
}

async function getHealthFactor(usdcAmount: any, wbtcAmount: any, loanId: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "ICCFL",
    "0x7B7450f910644A4EDe3183B7fCC5313a043f335C",
    signer
  );

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

describe.skip("CCFL Pool", () => {
  it("approve usdc", async () => {
    const AMOUNT = ethers.parseUnits("300", 6);
    await approveUsdc(AMOUNT);
    await allowanceUsdc();
  });

  it("supply", async () => {
    const AMOUNT = ethers.parseUnits("200", 6);
    await supplyUsdc(AMOUNT);
  });

  it("approve wbtc", async () => {
    const AMOUNT = ethers.parseUnits("0.1", 8);
    await approveWBTC(AMOUNT);
  });
});

describe.skip("CCFL Pool", () => {
  it("create a loan", async () => {
    await createLoan();
  });

  it("check health factor", async () => {
    await getHealthFactor(
      ethers.parseUnits("50", 6),
      ethers.parseUnits("0.0005", 8),
      BigInt(1)
    );
  });
});
