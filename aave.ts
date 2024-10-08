const { ethers } = require("ethers");
const dotenv = require("dotenv");

dotenv.config();

const provider = new ethers.JsonRpcProvider(process.env.HOLESKY_API_URL);
let wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
wallet = wallet.connect(provider);

import { Pool } from "@aave/contract-helpers";
const pool = new Pool(provider, {
  POOL: "0x24fb37871Ef892a443ADB21E741300009071D722",
  WETH_GATEWAY: "0xa7001d2c519FC5771fdE91C6beA1Ed9Ef7f1E8C7",
});

/*
  - @param `user` The ethereum address that will make the deposit
  - @param `reserve` The ethereum address of the reserve
  - @param `amount` The amount to be deposited
  - @param @optional `onBehalfOf` The ethereum address for which user is depositing. It will default to the user address
  */
// const supplyBundle: ActionBundle = await poolBundle.supplyBundle({
//   user,
//   reserve,
//   amount,
//   onBehalfOf,
// });
