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
    event CreateLoan(
        address indexed borrower,
        uint loanAmount,
        IERC20Standard supply,
        uint collateralAmount,
        IERC20Standard collateral,
        bool isYieldGenerating,
        bool isETH,
        uint loanId,
        uint timestamp
    );

    event AddCollateral(
        address indexed borrower,
        uint loanId,
        uint collateralAmount,
        IERC20Standard collateral,
        bool isETH,
        uint timestamp
    );

    event WithdrawLoan(
        address indexed borrower,
        uint loanId,
        IERC20Standard supply,
        uint timestamp
    );

    event RepayLoan(
        address indexed borrower,
        uint loanId,
        uint amount,
        IERC20Standard supply,
        uint timestamp
    );

    event WithdrawAllCollateral(
        address indexed borrower,
        uint loanId,
        bool isETH,
        uint timestamp
    );

    event Liquidate(address indexed liquidator, uint loanId, uint timestamp);

    function checkExistElement(
        IERC20Standard[] memory array,
        IERC20Standard el
    ) external pure returns (bool);

    function initialize(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools,
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens,
        IPoolAddressesProvider _aaveAddressProvider,
        uint _maxLTV,
        uint _liquidationThreshold,
        ICCFLLoan _ccflLoan
    ) external;

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

    function setSwapRouter(
        ISwapRouter _swapRouter,
        IUniswapV3Factory _factory
    ) external;

    // create loan
    function createLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountCollateral,
        IERC20Standard _collateral,
        bool _isYieldGenerating
    ) external;

    function setWETH(IWETH _iWETH) external;

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

    function addCollateralByETH(uint _loanId, uint _amountETH) external payable;

    function checkMinimalCollateralForLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        IERC20Standard _collateral
    ) external view returns (uint);

    function withdrawAllCollateral(uint _loanId, bool isETH) external;

    function addCollateralHealthFactor(
        uint _loanId,
        uint _amountCollateral
    ) external view returns (uint);

    function repayHealthFactor(
        uint _loanId,
        uint _amount
    ) external view returns (uint);

    function getLoanIds(address borrower) external view returns (uint[] memory);

    function setEarnShare(
        uint _borrower,
        uint _platform,
        uint _lender
    ) external;

    function createLoanByETH(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountETH,
        bool _isYieldGenerating
    ) external payable;
}
