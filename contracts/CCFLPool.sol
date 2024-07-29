// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICCFLPool.sol";
import {MathUtils} from "./math/MathUtils.sol";
import {WadRayMath} from "./math/WadRayMath.sol";
import {PercentageMath} from "./math/PercentageMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {DataTypes} from "./DataTypes.sol";
import {IReserveInterestRateStrategy} from "./IReserveInterestRateStrategy.sol";

struct Loan {
    uint loanId;
    bool isPaid;
    uint amount;
    bool isClosed;
    bool isLocked;
    address borrower;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLPool is ICCFLPool {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using SafeCast for uint256;

    address payable public owner;
    IERC20 public stableCoinAddress;
    address[] public lenders;

    mapping(uint => Loan) public loans;
    address public CCFL;
    address public BE;

    DataTypes.ReserveData public reserve;
    mapping(address => uint) public share;
    mapping(uint => uint) public debt;

    uint public totalSupply;
    uint public totalDebt;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    modifier onlyCCFL() {
        require(CCFL == msg.sender, "only the ccfl");
        _;
    }

    constructor(
        IERC20 _stableCoinAddress,
        address interestRateStrategyAddress
    ) {
        stableCoinAddress = _stableCoinAddress;
        reserve.interestRateStrategyAddress = interestRateStrategyAddress;
        owner = payable(msg.sender);
    }

    function setCCFL(address _ccfl) public onlyOwner {
        CCFL = _ccfl;
    }

    function getRemainingPool() public view returns (uint amount) {
        return totalSupply - totalDebt;
    }

    // Modifier to check token allowance
    modifier checkUsdAllowance(uint amount) {
        require(
            stableCoinAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function withdrawLoan(address _receiver, uint _loanId) public onlyCCFL {
        require(loans[_loanId].isPaid == false, "Loan is paid");
        loans[_loanId].isPaid = true;
        emit WithdrawLoan(_receiver, loans[_loanId].amount, block.timestamp);
        stableCoinAddress.transfer(_receiver, loans[_loanId].amount);
    }

    receive() external payable {}

    function cache() internal view returns (DataTypes.ReserveCache memory) {
        DataTypes.ReserveCache memory reserveCache;

        reserveCache.reserveConfiguration = reserve.configuration;
        reserveCache.currLiquidityIndex = reserveCache
            .nextLiquidityIndex = reserve.liquidityIndex;
        reserveCache.currVariableBorrowIndex = reserveCache
            .nextVariableBorrowIndex = reserve.variableBorrowIndex;
        reserveCache.currLiquidityRate = reserve.currentLiquidityRate;
        reserveCache.currVariableBorrowRate = reserve.currentVariableBorrowRate;

        reserveCache.reserveLastUpdateTimestamp = reserve.lastUpdateTimestamp;
        reserveCache.currScaledVariableDebt = totalDebt;

        return reserveCache;
    }

    function updateState(DataTypes.ReserveCache memory reserveCache) internal {
        // If time didn't pass since last stored timestamp, skip state update
        //solium-disable-next-line
        if (reserve.lastUpdateTimestamp == uint40(block.timestamp)) {
            return;
        }

        _updateIndexes(reserveCache);

        //solium-disable-next-line
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function _updateIndexes(
        DataTypes.ReserveCache memory reserveCache
    ) internal {
        // Only cumulating on the supply side if there is any income being produced
        // The case of Reserve Factor 100% is not a problem (currentLiquidityRate == 0),
        // as liquidity index should not be updated
        if (reserveCache.currLiquidityRate != 0) {
            uint256 cumulatedLiquidityInterest = MathUtils
                .calculateLinearInterest(
                    reserveCache.currLiquidityRate,
                    reserveCache.reserveLastUpdateTimestamp
                );
            reserveCache.nextLiquidityIndex = cumulatedLiquidityInterest.rayMul(
                reserveCache.currLiquidityIndex
            );
            reserve.liquidityIndex = reserveCache
                .nextLiquidityIndex
                .toUint128();
        }

        // Variable borrow index only gets updated if there is any variable debt.
        // reserveCache.currVariableBorrowRate != 0 is not a correct validation,
        // because a positive base variable rate can be stored on
        // reserveCache.currVariableBorrowRate, but the index should not increase
        if (reserveCache.currScaledVariableDebt != 0) {
            uint256 cumulatedVariableBorrowInterest = MathUtils
                .calculateCompoundedInterest(
                    reserveCache.currVariableBorrowRate,
                    reserveCache.reserveLastUpdateTimestamp
                );
            reserveCache
                .nextVariableBorrowIndex = cumulatedVariableBorrowInterest
                .rayMul(reserveCache.currVariableBorrowIndex);
            reserve.variableBorrowIndex = reserveCache
                .nextVariableBorrowIndex
                .toUint128();
        }
    }

    struct UpdateInterestRatesLocalVars {
        uint256 nextLiquidityRate;
        uint256 nextVariableRate;
        uint256 totalVariableDebt;
    }

    function updateInterestRates(
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        UpdateInterestRatesLocalVars memory vars;
        (
            vars.nextLiquidityRate,
            vars.nextVariableRate
        ) = IReserveInterestRateStrategy(reserve.interestRateStrategyAddress)
            .calculateInterestRates(
                DataTypes.CalculateInterestRatesParams({
                    liquidityAdded: liquidityAdded,
                    liquidityTaken: liquidityTaken,
                    totalVariableDebt: totalDebt,
                    totalSupply: totalSupply
                })
            );

        reserve.currentLiquidityRate = vars.nextLiquidityRate.toUint128();
        reserve.currentVariableBorrowRate = vars.nextVariableRate.toUint128();

        // emit ReserveDataUpdated(
        //     reserveAddress,
        //     vars.nextLiquidityRate,
        //     vars.nextStableRate,
        //     vars.nextVariableRate,
        //     reserveCache.nextLiquidityIndex,
        //     reserveCache.nextVariableBorrowIndex
        // );
    }

    function supply(uint256 _amount) public {
        DataTypes.ReserveCache memory reserveCache = cache();

        updateState(reserveCache);

        updateInterestRates(_amount, 0);

        uint256 amountScaled = 0;
        if (reserve.liquidityIndex > 0) {
            amountScaled = WadRayMath.wadToRay(_amount).rayDiv(
                reserve.liquidityIndex
            );
            amountScaled = WadRayMath.rayToWad(amountScaled);
        } else {
            amountScaled = _amount;
        }
        uint256 total = share[msg.sender] + amountScaled;
        totalSupply += amountScaled;

        share[msg.sender] = total;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) public {
        DataTypes.ReserveCache memory reserveCache = cache();

        updateState(reserveCache);

        updateInterestRates(0, _amount);

        uint256 amountScaled = 0;
        if (reserve.liquidityIndex > 0) {
            amountScaled = WadRayMath.wadToRay(_amount).rayDiv(
                reserve.liquidityIndex
            );
            amountScaled = WadRayMath.rayToWad(amountScaled);
        } else {
            amountScaled = _amount;
        }
        uint256 total = share[msg.sender] - amountScaled;
        totalSupply -= amountScaled;

        share[msg.sender] = total;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function borrow(
        uint _loanId,
        uint256 _amount,
        address _borrower
    ) public onlyCCFL {
        DataTypes.ReserveCache memory reserveCache = cache();

        updateState(reserveCache);

        updateInterestRates(0, _amount);

        uint256 amountScaled = 0;
        if (reserve.variableBorrowIndex > 0) {
            amountScaled = WadRayMath.wadToRay(_amount).rayDiv(
                reserve.variableBorrowIndex
            );
            amountScaled = WadRayMath.rayToWad(amountScaled);
        } else {
            amountScaled = _amount;
        }
        uint256 total = debt[_loanId] + amountScaled;
        totalDebt += amountScaled;

        Loan storage loan = loans[_loanId];

        debt[_loanId] = total;
        loan.loanId = _loanId;
        loan.amount = _amount;
        loan.borrower = _borrower;
    }

    function repay(uint _loanId, uint256 _amount) public onlyCCFL {
        DataTypes.ReserveCache memory reserveCache = cache();

        updateState(reserveCache);

        updateInterestRates(_amount, 0);

        uint256 amountScaled = 0;
        if (reserve.variableBorrowIndex > 0) {
            amountScaled = WadRayMath.wadToRay(_amount).rayDiv(
                reserve.variableBorrowIndex
            );
            amountScaled = WadRayMath.rayToWad(amountScaled);
        } else {
            amountScaled = _amount;
        }
        if (debt[_loanId] < amountScaled) {
            totalDebt -= debt[_loanId];

            debt[_loanId] = 0;
            amountScaled = WadRayMath.wadToRay(debt[_loanId]).rayMul(
                reserve.variableBorrowIndex
            );
            amountScaled = WadRayMath.rayToWad(amountScaled);
            stableCoinAddress.transferFrom(
                msg.sender,
                address(this),
                amountScaled
            );
        } else {
            uint256 total = debt[_loanId] - amountScaled;
            totalDebt -= amountScaled;

            debt[_loanId] = total;
            stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
        }
    }

    function getCurrentLoan(uint _loanId) public view returns (uint256) {
        DataTypes.ReserveCache memory reserveCache = cache();

        uint256 cumulatedVariableBorrowInterest = MathUtils
            .calculateCompoundedInterest(
                reserveCache.currVariableBorrowRate,
                reserveCache.reserveLastUpdateTimestamp
            );
        reserveCache.nextVariableBorrowIndex = cumulatedVariableBorrowInterest
            .rayMul(reserveCache.currVariableBorrowIndex);
        return
            WadRayMath.rayToWad(
                WadRayMath.wadToRay(debt[_loanId]).rayMul(
                    reserveCache.nextVariableBorrowIndex
                )
            );
    }

    function getCurrentRate() public view returns (uint256, uint256) {
        return (
            reserve.currentVariableBorrowRate,
            reserve.currentLiquidityRate
        );
    }
}
