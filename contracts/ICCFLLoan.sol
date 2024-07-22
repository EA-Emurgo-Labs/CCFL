// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./IERC20Standard.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLPool.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

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
    uint rateLoan;
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

    // function getUserAccountData(
    //     address user
    // )
    //     external
    //     view
    //     returns (
    //         uint256 totalCollateralBase,
    //         uint256 totalDebtBase,
    //         uint256 availableBorrowsBase,
    //         uint256 currentLiquidationThreshold,
    //         uint256 ltv,
    //         uint256 healthFactor
    //     );

    function initialize(
        Loan memory _loan,
        IERC20Standard[] memory _collateralTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        IERC20Standard[] memory _aTokens,
        uint[] memory _ltvs,
        uint[] memory _thresholds,
        AggregatorV3Interface[] memory _priceFeeds,
        AggregatorV3Interface _pricePoolFeeds,
        ISwapRouter _swapRouter
    ) external;

    function closeLoan()
        external
        returns (
            IERC20Standard[] memory collateralTokens,
            uint[] memory amount
        );

    function setCCFL(address _ccfl) external;

    function getHealthFactor() external view returns (uint);

    function updateCollateral(IERC20Standard _token, uint amount) external;

    function liquidate() external;

    function getLoanInfo() external view returns (Loan memory);

    function liquidateCloseLoan()
        external
        returns (
            IERC20Standard[] memory _collateralTokens,
            uint[] memory _amount
        );
}
