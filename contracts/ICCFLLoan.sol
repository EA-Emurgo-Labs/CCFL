// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./IERC20Standard.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

import "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";

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

struct Loan {
    uint loanId;
    address borrower;
    bool isPaid;
    uint amount;
    IERC20Standard stableCoin;
    bool isClosed;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
interface ICCFLLoan {
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

    event Withdrawal(uint amount, uint when);

    function supplyLiquidity() external;

    function withdrawLiquidity() external;

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
        Loan memory _loan,
        IERC20Standard _collateralToken,
        IPoolAddressesProvider _aaveAddressProvider,
        IERC20Standard _aToken,
        uint _ltv,
        uint _threshold,
        AggregatorV3Interface _priceFeed,
        AggregatorV3Interface _pricePoolFeed,
        ISwapRouter _swapRouter,
        address _platform,
        IWETH _iWETH
    ) external;

    function closeLoan() external;

    function setCCFL(address _ccfl) external;

    function getHealthFactor(
        uint currentDebt,
        uint addCollateral
    ) external view returns (uint);

    function updateCollateral(uint _amount) external;

    function liquidate(uint _currentDebt, uint _percent) external;

    function getLoanInfo() external view returns (Loan memory);

    function withdrawAllCollateral(address _receiver, bool _isETH) external;
}
