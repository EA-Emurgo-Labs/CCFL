// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "./IERC20Standard.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
import "./helpers/Errors.sol";

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

    function setPlatformAddress(
        address _liquidator,
        address _platform
    ) external;

    function getPlatformAddress() external view returns (address, address);

    function setEnableETHNative(bool _isActived) external;

    function getEnableETHNative() external view returns (bool);

    function setWETH(IWETH _iWETH) external;

    function getWETH() external view returns (IWETH);

    // function setCCFLLoan(ICCFLLoan _loan) external;

    // function getCCFLLoan() external view returns (ICCFLLoan);

    function setCollateralToStableFee(
        IERC20Standard[] memory _collateral,
        IERC20Standard[] memory _stable,
        uint24[] memory _fee
    ) external;

    function getCollateralToStableFee(
        IERC20Standard _collateral,
        IERC20Standard _stable
    ) external view returns (uint24);

    function getCcflActiveCoins(
        IERC20Standard _tokenAddress
    ) external view returns (bool);

    function getLatestPrice(
        IERC20Standard _stableCoin,
        bool isPool
    ) external view returns (uint);

    function getAtoken(
        IERC20Standard _collateral
    ) external view returns (IERC20Standard);
}
