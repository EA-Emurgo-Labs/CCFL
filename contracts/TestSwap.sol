// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./IERC20Standard.sol";
import "./IV3SwapRouter.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract TestSwap {
    // uniswap config
    IV3SwapRouter public swapRouter =
        IV3SwapRouter(0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E);
    uint24 public constant feeTier = 3000;
    IUniswapV3Factory public factory =
        IUniswapV3Factory(0x0227628f3F023bb0B980b67D528571c95c6DaC1c);

    constructor() {}

    /// @notice swapExactOutputSingle swaps a minimum possible amount of DAI for a fixed amount of WETH.
    /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
    /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
    /// @param amountOut The exact amount of WETH9 to receive from the swap.
    /// @param amountInMaximum The amount of DAI we are willing to spend to receive the specified amount of WETH9.
    /// @return amountIn The amount of DAI actually spent in the swap.
    function swapTokenForUSD(
        uint256 amountOut,
        uint256 amountInMaximum,
        IERC20Standard stableCoin,
        IERC20Standard tokenAddress
    ) public returns (uint256 amountIn) {
        // Approve the router to spend the specifed `amountInMaximum` of DAI.

        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        tokenAddress.approve(address(swapRouter), amountInMaximum);

        address pool = factory.getPool(
            address(tokenAddress),
            address(stableCoin),
            feeTier
        );

        uint24 fee = IUniswapV3Pool(pool).fee();

        uint160 sqrtPriceLimitX96;
        {
            (
                uint160 sqrtPriceX96,
                int24 tick,
                uint16 observationIndex,
                uint16 observationCardinality,
                uint16 observationCardinalityNext,
                uint8 feeProtocol,
                bool unlocked
            ) = IUniswapV3Pool(pool).slot0();
            sqrtPriceLimitX96 = sqrtPriceX96;
        }

        IV3SwapRouter.ExactOutputSingleParams memory params = IV3SwapRouter
            .ExactOutputSingleParams({
                tokenIn: address(tokenAddress),
                tokenOut: address(stableCoin),
                fee: fee,
                recipient: msg.sender,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(
                address(tokenAddress),
                address(swapRouter),
                0
            );
        }
    }

    function swapEarnForUSD(
        uint256 amountIn,
        IERC20Standard stableCoin,
        IERC20Standard tokenAddress
    ) public returns (uint256 amountOut) {
        // Transfer the specified amount of DAI to this contract.
        // TransferHelper.safeTransferFrom(
        //     address(tokenAddress),
        //     msg.sender,
        //     address(this),
        //     amountIn
        // );

        // Approve the router to spend the specifed `amountInMaximum` of DAI.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        TransferHelper.safeApprove(
            address(tokenAddress),
            address(swapRouter),
            amountIn
        );

        address pool = factory.getPool(
            address(tokenAddress),
            address(stableCoin),
            feeTier
        );

        uint24 fee = IUniswapV3Pool(pool).fee();

        // uint160 sqrtPriceLimitX96;
        // {
        //     (
        //         uint160 sqrtPriceX96,
        //         int24 tick,
        //         uint16 observationIndex,
        //         uint16 observationCardinality,
        //         uint16 observationCardinalityNext,
        //         uint8 feeProtocol,
        //         bool unlocked
        //     ) = IUniswapV3Pool(pool).slot0();
        //     sqrtPriceLimitX96 = 0;
        // }

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: address(tokenAddress),
                tokenOut: address(stableCoin),
                fee: fee,
                recipient: msg.sender,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountOut = swapRouter.exactInputSingle(params);
    }

    function approveAll(IERC20Standard tokenAddress, address receiver) public{
        tokenAddress.approve(receiver, tokenAddress.balanceOf(address(this)));
    }

    receive() external payable {}
}
