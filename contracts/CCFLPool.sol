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

interface IReserveInterestRateStrategy {
    /**
     * @notice Calculates the interest rates depending on the reserve's state and configurations
     * @param params The parameters needed to calculate interest rates
     * @return liquidityRate The liquidity rate expressed in rays
     * @return stableBorrowRate The stable borrow rate expressed in rays
     * @return variableBorrowRate The variable borrow rate expressed in rays
     */
    function calculateInterestRates(
        DataTypes.CalculateInterestRatesParams memory params
    ) external view returns (uint256, uint256, uint256);
}

struct Loan {
    uint loanId;
    address[] lenders;
    uint[] lockFund;
    bool isPaid;
    uint amount;
    bool isClosed;
    bool isLocked;
}

struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60: asset is paused
    //bit 61: borrowing in isolation mode is enabled
    //bit 62: siloed borrowing enabled
    //bit 63: flashloaning enabled
    //bit 64-79: reserve factor
    //bit 80-115 borrow cap in whole tokens, borrowCap == 0 => no cap
    //bit 116-151 supply cap in whole tokens, supplyCap == 0 => no cap
    //bit 152-167 liquidation protocol fee
    //bit 168-175 eMode category
    //bit 176-211 unbacked mint cap in whole tokens, unbackedMintCap == 0 => minting disabled
    //bit 212-251 debt ceiling for isolation mode with (ReserveConfiguration::DEBT_CEILING_DECIMALS) decimals
    //bit 252-255 unused

    uint256 data;
}

struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    //timestamp of last update
    uint40 lastUpdateTimestamp;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint16 id;
    //stableDebtToken address
    address stableDebtTokenAddress;
    //variableDebtToken address
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
}

struct ReserveCache {
    uint256 currScaledVariableDebt;
    uint256 nextScaledVariableDebt;
    uint256 currPrincipalStableDebt;
    uint256 currAvgStableBorrowRate;
    uint256 currTotalStableDebt;
    uint256 nextAvgStableBorrowRate;
    uint256 nextTotalStableDebt;
    uint256 currLiquidityIndex;
    uint256 nextLiquidityIndex;
    uint256 currVariableBorrowIndex;
    uint256 nextVariableBorrowIndex;
    uint256 currLiquidityRate;
    uint256 currVariableBorrowRate;
    uint256 reserveFactor;
    ReserveConfigurationMap reserveConfiguration;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    uint40 reserveLastUpdateTimestamp;
    uint40 stableDebtLastUpdateTimestamp;
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
    mapping(address => uint) public lenderLockFund;
    mapping(address => uint) public lenderRemainFund;
    uint public totalLockFund;
    uint public totalRemainFund;
    address[] public lenders;

    mapping(uint => Loan) public loans;
    address public CCFL;
    address public BE;

    ReserveData public reserve;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    modifier onlyCCFL() {
        require(CCFL == msg.sender, "only the ccfl");
        _;
    }

    constructor(IERC20 _stableCoinAddress) {
        stableCoinAddress = _stableCoinAddress;
        owner = payable(msg.sender);
    }

    function setCCFL(address _ccfl) public onlyOwner {
        CCFL = _ccfl;
    }

    function getRemainingPool() public view returns (uint amount) {
        amount = totalRemainFund;
    }

    // Modifier to check token allowance
    modifier checkUsdAllowance(uint amount) {
        require(
            stableCoinAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function supplyLiquidity(uint _amount) public checkUsdAllowance(_amount) {
        // check a new lender
        bool existedLender = false;
        for (uint i = 0; i < lenders.length; i++) {
            if (lenders[i] == msg.sender) {
                existedLender = true;
                break;
            }
        }
        if (!existedLender) {
            lenders.push(msg.sender);
        }
        emit Deposit(msg.sender, _amount, block.timestamp);
        lenderRemainFund[msg.sender] += _amount;
        totalRemainFund += _amount;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawLiquidity(uint _amount) public {
        require(
            lenderRemainFund[msg.sender] >= _amount,
            "Balance is not enough"
        );
        emit Withdraw(msg.sender, _amount, block.timestamp);
        lenderRemainFund[msg.sender] -= _amount;
        if (
            lenderLockFund[msg.sender] <= 0 && lenderRemainFund[msg.sender] <= 0
        ) {
            uint deleteIndex = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenders[i] == msg.sender) deleteIndex = i;
            }

            if (lenders[deleteIndex] == msg.sender) {
                lenders[deleteIndex] = lenders[lenders.length - 1];
                delete lenders[lenders.length - 1];
            }
        }
        stableCoinAddress.transfer(msg.sender, _amount);
    }

    function lockLoan(
        uint _loanId,
        uint _amount,
        address _borrower
    ) public onlyCCFL {
        Loan storage loan = loans[_loanId];
        if (
            _loanId > 0 && loan.isLocked == false && totalRemainFund >= _amount
        ) {
            uint totalLock = 0;
            uint[] memory emptyFund = new uint[](lenders.length);
            uint last = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenderRemainFund[lenders[i]] <= 0) {
                    emptyFund[i] = 1;
                } else last = i;
            }

            for (uint i = 0; i < lenders.length; i++) {
                if (i != last && emptyFund[i] != 1) {
                    uint lockFund = (lenderRemainFund[lenders[i]] * _amount) /
                        totalRemainFund;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    totalLock += lockFund;
                    loan.lenders.push(lenders[i]);
                    loan.lockFund.push(lockFund);
                } else if (i == last) {
                    uint lockFund = _amount - totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    loan.lenders.push(lenders[i]);
                    loan.lockFund.push(lockFund);
                }
            }

            loan.isLocked = true;
            loan.amount = _amount;
            totalLockFund += _amount;
            emit LockLoan(_loanId, _amount, _borrower, block.timestamp);
        }
    }

    function closeLoan(
        uint _loanId,
        uint _amount
    ) public onlyCCFL checkUsdAllowance(_amount) {
        Loan storage loan = loans[_loanId];
        require(
            _amount == loan.amount && loan.isClosed == false,
            "Do not enough amount"
        );
        for (uint i = 0; i < loan.lenders.length; i++) {
            uint returnAmount = loan.lockFund[i];
            lenderLockFund[loan.lenders[i]] -= returnAmount;
            lenderRemainFund[loan.lenders[i]] += returnAmount;
        }
        loan.isClosed = true;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
        emit CloseLoan(_loanId, _amount, msg.sender, block.timestamp);
    }

    function withdrawLoan(address _receiver, uint _loanId) public onlyCCFL {
        require(loans[_loanId].isPaid == false, "Loan is paid");
        loans[_loanId].isPaid = true;
        emit WithdrawLoan(_receiver, loans[_loanId].amount, block.timestamp);
        stableCoinAddress.transfer(_receiver, loans[_loanId].amount);
    }

    receive() external payable {}

    function cache() internal view returns (ReserveCache memory) {
        ReserveCache memory reserveCache;

        reserveCache.reserveConfiguration = reserve.configuration;
        // reserveCache.reserveFactor = reserveCache
        //     .reserveConfiguration
        //     .getReserveFactor();
        reserveCache.currLiquidityIndex = reserveCache
            .nextLiquidityIndex = reserve.liquidityIndex;
        reserveCache.currVariableBorrowIndex = reserveCache
            .nextVariableBorrowIndex = reserve.variableBorrowIndex;
        reserveCache.currLiquidityRate = reserve.currentLiquidityRate;
        reserveCache.currVariableBorrowRate = reserve.currentVariableBorrowRate;

        reserveCache.stableDebtTokenAddress = reserve.stableDebtTokenAddress;
        reserveCache.variableDebtTokenAddress = reserve
            .variableDebtTokenAddress;

        reserveCache.reserveLastUpdateTimestamp = reserve.lastUpdateTimestamp;

        // reserveCache.currScaledVariableDebt = reserveCache
        //     .nextScaledVariableDebt = IVariableDebtToken(
        //     reserveCache.variableDebtTokenAddress
        // ).scaledTotalSupply();

        // (
        //     reserveCache.currPrincipalStableDebt,
        //     reserveCache.currTotalStableDebt,
        //     reserveCache.currAvgStableBorrowRate,
        //     reserveCache.stableDebtLastUpdateTimestamp
        // ) = IStableDebtToken(reserveCache.stableDebtTokenAddress)
        //     .getSupplyData();

        // by default the actions are considered as not affecting the debt balances.
        // if the action involves mint/burn of debt, the cache needs to be updated
        reserveCache.nextTotalStableDebt = reserveCache.currTotalStableDebt;
        reserveCache.nextAvgStableBorrowRate = reserveCache
            .currAvgStableBorrowRate;

        return reserveCache;
    }

    function updateState(ReserveCache memory reserveCache) internal {
        // If time didn't pass since last stored timestamp, skip state update
        //solium-disable-next-line
        if (reserve.lastUpdateTimestamp == uint40(block.timestamp)) {
            return;
        }

        _updateIndexes(reserveCache);

        //solium-disable-next-line
        reserve.lastUpdateTimestamp = uint40(block.timestamp);
    }

    function _updateIndexes(ReserveCache memory reserveCache) internal {
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
        uint256 nextStableRate;
        uint256 nextVariableRate;
        uint256 totalVariableDebt;
    }

    function updateInterestRates(
        ReserveCache memory reserveCache,
        uint256 liquidityAdded,
        uint256 liquidityTaken
    ) internal {
        UpdateInterestRatesLocalVars memory vars;

        vars.totalVariableDebt = reserveCache.nextScaledVariableDebt.rayMul(
            reserveCache.nextVariableBorrowIndex
        );

        (
            vars.nextLiquidityRate,
            vars.nextStableRate,
            vars.nextVariableRate
        ) = IReserveInterestRateStrategy(reserve.interestRateStrategyAddress)
            .calculateInterestRates(
                DataTypes.CalculateInterestRatesParams({
                    liquidityAdded: liquidityAdded,
                    liquidityTaken: liquidityTaken,
                    totalVariableDebt: vars.totalVariableDebt,
                    reserveToken: address(stableCoinAddress),
                    pool: address(this)
                })
            );

        reserve.currentLiquidityRate = vars.nextLiquidityRate.toUint128();
        reserve.currentStableBorrowRate = vars.nextStableRate.toUint128();
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
        ReserveCache memory reserveCache = cache();

        updateState(reserveCache);

        updateInterestRates(reserveCache, _amount, 0);

        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }
}
