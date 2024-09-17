// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./IERC20Standard.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "./IV3SwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
import "./DataTypes.sol";
import "./IQuoterV2.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
interface ICCFLLoan {
    event LiquiditySupplied(
        address indexed onBehalfOf,
        address indexed _token,
        uint _amount
    );
    event LiquidityWithdrawn(
        address indexed to,
        address indexed _token,
        uint _amount
    );

    function supplyLiquidity() external;

    function withdrawLiquidity(
        uint _earnPlatform,
        uint _earnBorrower,
        uint _earnLender
    ) external;

    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function initialize(
        DataTypes.Loan memory _loan,
        IERC20Standard _collateralToken,
        IPoolAddressesProvider _aaveAddressProvider,
        IERC20Standard _aToken,
        uint _ltv,
        uint _threshold,
        AggregatorV3Interface _priceFeed,
        AggregatorV3Interface _pricePoolFeed,
        IWETH _iWETH
    ) external;

    function closeLoan() external returns (uint256, uint256);

    function setCCFL(address _ccfl) external;

    function getHealthFactor(
        uint currentDebt,
        uint addCollateral
    ) external view returns (uint);

    function updateCollateral(uint _amount) external;

    function liquidate(
        uint _currentDebt
    ) external returns (uint256, uint256, uint256, uint256);

    function getLoanInfo() external view returns (DataTypes.Loan memory);

    function withdrawAllCollateral(address _receiver, bool _isETH) external;

    function setSwapRouter(
        IV3SwapRouter _swapRouter,
        IUniswapV3Factory _factory,
        IQuoterV2 _quoter
    ) external;

    function setPaid() external;

    function setEarnShare(
        uint24 _borrower,
        uint24 _platform,
        uint24 _lender
    ) external;

    function getYieldEarned(uint _earnBorrower) external view returns (uint);

    function getIsYeild() external view returns (bool);

    function getCollateralAmount() external view returns (uint);

    function getCollateralToken() external view returns (IERC20Standard);

    function setPenalty(
        uint _platform,
        uint _liquidator,
        uint _lender
    ) external;

    function setUniFee(uint24 _uniFee) external;
}
