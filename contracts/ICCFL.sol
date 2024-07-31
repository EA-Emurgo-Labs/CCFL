// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "./ICCFLPool.sol";
import "./ICCFLLoan.sol";
import "./IERC20Standard.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
interface ICCFL {
    event LiquiditySupplied(
        address indexed onBehalfOf,
        address indexed _token,
        uint256 indexed _amount
    );
    event LiquidityWithdrawn(
        address indexed to,
        address indexed _token,
        uint256 indexed _amount
    );

    event Withdraw(address borrower, uint amount, uint when);

    function initialize(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools,
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        uint _maxLTV,
        uint _liquidationThreshold,
        ICCFLLoan _ccflLoan
    ) external;

    function setSwapRouter(ISwapRouter _swapRouter) external;

    function makeYieldGenerating(uint _loanId, bool isYield) external;

    // create loan
    function createLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountCollateral,
        IERC20Standard _collateral,
        bool isYieldGenerating
    ) external;

    // withdraw loan
    function withdrawLoan(IERC20Standard _stableCoin, uint _loanId) external;

    // repay loan
    function repayLoan(
        uint _loanId,
        uint _amount,
        IERC20Standard _stableCoin
    ) external;

    function getLatestPrice(
        IERC20Standard _stableCoin,
        bool isPool
    ) external view returns (uint);

    function getHealthFactor(uint _loanId) external view returns (uint);

    function getLoanAddress(uint _loanId) external view returns (address);

    function liquidate(uint _loanId) external;

    function setPlatformAddress(address _liquidator, address _plaform) external;

    function addCollateral(
        uint _loanId,
        uint _amountCollateral,
        IERC20Standard _collateral
    ) external;
}
