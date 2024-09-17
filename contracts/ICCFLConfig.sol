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
    function checkExistElement(
        IERC20Standard[] memory array,
        IERC20Standard el
    ) external pure returns (bool);

    function setPools(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools
    ) external;

    function setCCFLLoan(ICCFLLoan _loan) external;

    function setCollaterals(
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens
    ) external;

    function setAaveProvider(
        IPoolAddressesProvider _aaveAddressProvider
    ) external;

    function setActiveToken(
        IERC20Standard _token,
        bool _isActived,
        bool _isPoolToken
    ) external;

    function setThreshold(uint _maxLTV, uint _liquidationThreshold) external;

    function setPenalty(
        uint _platform,
        uint _liquidator,
        uint _lender
    ) external;

    function getPenalty() external view returns (uint24, uint24, uint24);

    function setSwapRouter(
        IV3SwapRouter _swapRouter,
        IUniswapV3Factory _factory,
        IQuoterV2 _quoter
    ) external;

    function setWETH(IWETH _iWETH) external;

    function setPlatformAddress(address _liquidator, address _plaform) external;

    function checkMinimalCollateralForLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        IERC20Standard _collateral
    ) external view returns (uint);

    function addCollateralHealthFactor(
        uint _loanId,
        uint _amountCollateral
    ) external view returns (uint);

    function setEarnShare(
        uint24 _borrower,
        uint24 _platform,
        uint24 _lender
    ) external;

    function getEarnShare() external view returns (uint24, uint24, uint24);
}
