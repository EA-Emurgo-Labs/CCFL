// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "./ICCFLPool.sol";
import "./ICCFLLoan.sol";
import "./IERC20Standard.sol";
import "./IV3SwapRouter.sol";
import "./IQuoterV2.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
interface ICCFLConfig {
    function setAaveProvider(
        IPoolAddressesProvider _aaveAddressProvider
    ) external;

    function getAaveProvider() external view returns (IPoolAddressesProvider);

    function setThreshold(uint _maxLTV, uint _liquidationThreshold) external;

    function getThreshold() external view returns (uint, uint);

    function setSwapRouter(
        IV3SwapRouter _swapRouter,
        IUniswapV3Factory _factory,
        IQuoterV2 _quoter
    ) external;

    function getSwapRouter()
        external
        view
        returns (IV3SwapRouter, IUniswapV3Factory, IQuoterV2);

    function setEarnShare(
        uint _borrower,
        uint _platform,
        uint _lender
    ) external;

    function getEarnShare() external view returns (uint, uint, uint);

    function setPenalty(
        uint _platform,
        uint _liquidator,
        uint _lender
    ) external;

    function getPenalty() external view returns (uint, uint, uint);
}
