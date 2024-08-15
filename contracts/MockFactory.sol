// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract MockFactory is IUniswapV3Factory {
    constructor() payable {}

    IUniswapV3Pool public pool;

    function setPool(IUniswapV3Pool _pool) external {
        pool = _pool;
    }

    function owner() external view override returns (address) {}

    function feeAmountTickSpacing(
        uint24 fee
    ) external view override returns (int24) {}

    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view override returns (address) {
        return address(pool);
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override returns (address pool) {}

    function setOwner(address _owner) external override {}

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external override {}
}
