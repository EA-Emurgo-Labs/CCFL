// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
import "./IERC20Standard.sol";

library DataTypes {
    struct ReserveData {
        //the liquidity index. Expressed in ray
        uint128 liquidityIndex;
        //the current supply rate. Expressed in ray
        uint128 currentLiquidityRate;
        //variable borrow index. Expressed in ray
        uint128 variableBorrowIndex;
        //the current variable borrow rate. Expressed in ray
        uint128 currentVariableBorrowRate;
        //timestamp of last update
        uint40 lastUpdateTimestamp;
        //the id of the reserve. Represents the position in the list of the active reserves
        uint16 id;
        //address of the interest rate strategy
        address interestRateStrategyAddress;
    }

    struct ReserveCache {
        uint256 currScaledVariableDebt;
        uint256 currLiquidityIndex;
        uint256 nextLiquidityIndex;
        uint256 currVariableBorrowIndex;
        uint256 nextVariableBorrowIndex;
        uint256 currLiquidityRate;
        uint256 currVariableBorrowRate;
        uint40 reserveLastUpdateTimestamp;
    }

    struct CalculateInterestRatesParams {
        uint256 liquidityAdded;
        uint256 liquidityTaken;
        uint256 totalVariableDebt;
        uint256 totalLiquidity;
    }

    struct Loan {
        uint loanId;
        uint amount;
        bool isClosed;
        address borrower;
        bool isLiquidated;
        IERC20Standard stableCoin;
        bool isFinalty;
        bool isFiat;
        uint closedAmount;
    }

    struct UpdateInterestRatesLocalVars {
        uint256 nextLiquidityRate;
        uint256 nextVariableRate;
        uint256 totalVariableDebt;
    }
}
