// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./DataTypes.sol";
import "./ICCFLConfig.sol";

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
        ICCFLConfig _iCCFLConfig
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

    function getYieldEarned(uint _earnBorrower) external view returns (uint);

    function getIsYeild() external view returns (bool);

    function getCollateralAmount() external view returns (uint);

    function getCollateralToken() external view returns (IERC20Standard);

    function setUniFee(uint24 _uniFee) external;
}
