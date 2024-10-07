const { Token } = require("@uniswap/sdk-core");

const WETH = new Token(
  17000,
  "0xC9Dbd9B061cf207341c75FE1934629288B3f93ce",
  18,
  "WETH",
  "Wrapped Ether"
);
const USDC = new Token(
  17000,
  "0x0335468fF1BE5F81d0e4d24414ccB314b9820a69",
  6,
  "USDC",
  "USDC"
);
const USDT = new Token(
  17000,
  "0x5d2bf0b5D8590D10eceDf1ade5128BE39BF43432",
  6,
  "USDT",
  "Tether USD"
);

const WBTC = new Token(
  17000,
  "0x7a4D7c63936b1c0Ea523B13812BD9cdDB45cE956",
  8,
  "WBTC",
  "Wrapped BTC"
);

const {
  Position,
  Pool,
  nearestUsableTick,
  NonfungiblePositionManager,
} = require("@uniswap/v3-sdk");
const { ethers } = require("ethers");
const dotenv = require("dotenv");
const { Percent } = require("@uniswap/sdk-core");
// const {
//   abi: INonfungiblePositionManagerABI,
// } = require("@uniswap/v3-periphery/artifacts/contracts/interfaces/INonfungiblePositionManager.sol/INonfungiblePositionManager.json");

const {
  abi: IUniswapV3PoolABI,
} = require("@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json");

dotenv.config();

const provider = new ethers.JsonRpcProvider(process.env.HOLESKY_API_URL);
let wallet = new ethers.Wallet(process.env.PRIVATE_KEY);
wallet = wallet.connect(provider);

async function mintPosition() {
  const WBTC_USDC_ADDRESS = "0xFabe6E085aA36fef4AF2673E376a73E359a51ea7";
  const [POOL, immutables, state] = await getPool(
    USDC,
    WBTC,
    WBTC_USDC_ADDRESS
  );

  const newPosition = Position.fromAmount0({
    pool: POOL,
    tickLower:
      nearestUsableTick(state.tick, immutables.tickSpacing) -
      immutables.tickSpacing * 10,
    tickUpper:
      nearestUsableTick(state.tick, immutables.tickSpacing) +
      immutables.tickSpacing * 10,
    amount0: ethers.parseUnits("0.001", WBTC.decimals).toString(),
    useFullPrecision: true,
  });

  console.log(newPosition);
  console.log(newPosition.amount0);
  console.log(
    ethers.formatUnits(newPosition.amount0.quotient.toString(), WBTC.decimals)
  );
  console.log(
    ethers.formatUnits(newPosition.amount1.quotient.toString(), WETH.decimals)
  );

  const blockNumber = await provider.getBlockNumber();

  const { calldata, value } = NonfungiblePositionManager.addCallParameters(
    newPosition,
    {
      slippageTolerance: new Percent(50, 1000),
      recipient: wallet.address,
      deadline: 1728289608 + 20000000,
    }
  );

  const NFPManagerAddress = "0x13cBDAaC52f7BC245DC69E6C9b691b86BC4DF1b7";

  let txn = {
    to: NFPManagerAddress,
    data: calldata,
    value,
  };

  const gasPrice = await (await provider.getFeeData()).gasPrice;

  console.log(calldata);

  const tx = await wallet.sendTransaction({
    ...txn,
    gasPrice,
    gasLimit: 3000000,
  });

  console.log(tx);
}

//MARK: Helpers

async function getPool(tokenA, tokenB, poolAddress) {
  const POOL = new Pool(
    tokenA,
    tokenB,
    3000,
    "3234476190304153300000000000",
    0,
    -63973
  );

  let immutables = {};
  let state = {};

  immutables.tickSpacing = 60;
  state.tick = -63973;

  return [POOL, immutables, state];
}

mintPosition();
