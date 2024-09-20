// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract MockQuoter is IQuoterV2 {
    constructor() payable {}

    function quoteExactInput(
        bytes memory path,
        uint256 amountIn
    )
        external
        override
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        )
    {}

    function quoteExactInputSingle(
        QuoteExactInputSingleParams memory params
    )
        external
        override
        returns (
            uint256 amountOut,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {}

    function quoteExactOutput(
        bytes memory path,
        uint256 amountOut
    )
        external
        override
        returns (
            uint256 amountIn,
            uint160[] memory sqrtPriceX96AfterList,
            uint32[] memory initializedTicksCrossedList,
            uint256 gasEstimate
        )
    {}

    function quoteExactOutputSingle(
        QuoteExactOutputSingleParams memory params
    )
        external
        override
        returns (
            uint256 amountIn,
            uint160 sqrtPriceX96After,
            uint32 initializedTicksCrossed,
            uint256 gasEstimate
        )
    {}
}
