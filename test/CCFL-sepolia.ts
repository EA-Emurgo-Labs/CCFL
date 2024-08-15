const { ethers } = require("hardhat");

async function approveUsdc(AMOUNT: any) {
  const signer = await ethers.provider.getSigner();
  console.log("signer", await signer.getAddress());

  const iUsdc = await ethers.getContractAt(
    "IERC20Standard",
    "0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8",
    signer
  );

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

describe("CCFL Pool", () => {
  it("approve usdc", async () => {
    const AMOUNT = ethers.parseUnits("300", 6);
    await approveUsdc(AMOUNT);
    await allowanceUsdc();
  });

  it.only("supply", async () => {
    const AMOUNT = ethers.parseUnits("200", 6);
    await supplyUsdc(AMOUNT);
  });
});
