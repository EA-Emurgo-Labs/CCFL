// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLPool.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLLoan.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

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
contract CCFL is Initializable {
    using Clones for address;
    uint public rateLoan;
    address payable public owner;
    IERC20 public tokenAddress;
    mapping(IERC20 => AggregatorV3Interface) public priceFeeds;
    // mapping(address => Loan[]) public loans;
    // mapping(address => uint) public totalLoans;
    mapping(address => mapping(IERC20 => uint)) public collaterals;
    mapping(address => uint) public stakeAave;
    mapping(IERC20 => uint) public liquidationThreshold;
    uint public loandIds;
    mapping(IERC20 => ICCFLPool) public ccflPools;
    IERC20[] public ccflPoolStableCoins;
    ICCFLLoan ccflLoan;
    mapping(uint => ICCFLLoan) loans;
    IERC20[] public collateralTokens;
    IERC20[] public aTokens;
    IPoolAddressesProvider[] public aaveAddressProviders;
    mapping(IERC20 => uint) public LTV;

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

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    modifier supportedToken(IERC20 _tokenAddress) {
        bool isValid = false;
        // check _tokenAddress is valid
        for (uint i = 0; i < collateralTokens.length; i++) {
            if (collateralTokens[i] == _tokenAddress) {
                isValid = true;
                break;
            }
        }
        require(isValid == true, "Smart contract does not support this token");
        _;
    }

    event Withdraw(address borrower, uint amount, uint when);

    function initialize(
        IERC20[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools,
        IERC20[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20[] memory _aTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        uint[] memory _ltvs,
        uint[] memory _thresholds,
        ICCFLLoan _ccflLoan
    ) external initializer {
        ccflPoolStableCoins = _ccflPoolStableCoin;
        owner = payable(msg.sender);
        loandIds = 1;
        for (uint i = 0; i < ccflPoolStableCoins.length; i++) {
            ccflPools[ccflPoolStableCoins[i]] = _ccflPools[i];
            priceFeeds[ccflPoolStableCoins[i]] = _poolAggregators[i];
            LTV[ccflPoolStableCoins[i]] = _ltvs[i];
            liquidationThreshold[ccflPoolStableCoins[i]] = _thresholds[i];
        }
        collateralTokens = _collateralTokens;
        for (uint i = 0; i < collateralTokens.length; i++) {
            priceFeeds[collateralTokens[i]] = _collateralAggregators[i];
        }
        rateLoan = 1200;
        ccflLoan = _ccflLoan;
        aTokens = _aTokens;
        aaveAddressProviders = _aaveAddressProviders;
    }

    // create loan
    // 1. deposit
    // Modifier to check token allowance
    modifier checkTokenAllowance(IERC20 _token, uint _amount) {
        require(
            _token.allowance(msg.sender, address(this)) >= _amount,
            "Error"
        );
        _;
    }

    // 1.1 add liquidity aave
    function makeYieldGenerating(uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        loan.supplyLiquidity();
    }

    function makeRiskFree(uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        loan.withdrawLiquidity();
    }

    function depositCollateral(
        uint _amount,
        IERC20 _tokenAddress
    )
        public
        checkTokenAllowance(_tokenAddress, _amount)
        supportedToken(_tokenAddress)
    {
        // note collateral
        collaterals[msg.sender][_tokenAddress] += _amount;
        _tokenAddress.transferFrom(msg.sender, address(this), _amount);
    }

    // 2. create loan
    function createLoan(uint _amount, uint _months, IERC20 _stableCoin) public {
        // check enough collateral
        uint collateralByUSD = 0;
        for (uint i = 0; i < collateralTokens.length; i++) {
            if (collaterals[msg.sender][collateralTokens[i]] > 0) {
                collateralByUSD +=
                    collaterals[msg.sender][collateralTokens[i]] *
                    getLatestPrice(collateralTokens[i]);
            }
        }

        require(
            (collateralByUSD * LTV[_stableCoin]) / 10000 >=
                _amount * getLatestPrice(_stableCoin),
            "Don't have enough collateral"
        );
        // check pool reseve
        require(
            ccflPools[_stableCoin].getRemainingPool() >= _amount,
            "Pool don't have enough fund"
        );
        // make loan ins
        Loan memory loan;
        uint time = 30 * (1 days);
        address _borrower = msg.sender;
        loan.borrower = _borrower;
        loan.deadline = block.timestamp + _months * time;
        loan.monthlyDeadline = block.timestamp + time;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.monthlyPayment = (_amount * rateLoan) / 10000 / 12;
        loan.amountMonth = _months;
        loan.monthPaid = 0;
        loan.rateLoan = rateLoan;
        loan.stableCoin = _stableCoin;
        // loans[_borrower].push(loan);
        // lock loan on pool
        ccflPools[_stableCoin].lockLoan(loan.loanId, loan.amount, _borrower);
        // totalLoans[_borrower] += _amount;
        uint[] memory _ltvs = new uint[](collateralTokens.length);
        uint[] memory _thresholds = new uint[](collateralTokens.length);
        for (uint i = 0; i < collateralTokens.length; i++) {
            _ltvs[i] = LTV[collateralTokens[i]];
            _thresholds[i] = liquidationThreshold[collateralTokens[i]];
        }
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        cloneSC.initialize(
            loan,
            collateralTokens,
            aaveAddressProviders,
            aTokens,
            _ltvs,
            _thresholds
        );
        cloneSC.setCCFLPool(ccflPools[_stableCoin], address(this));
        loans[loandIds] = cloneSC;
        // transfer collateral
        for (uint i = 0; i < collateralTokens.length; i++) {
            if (collaterals[msg.sender][collateralTokens[i]] > 0) {
                collateralTokens[i].transfer(
                    address(loanIns),
                    collaterals[msg.sender][collateralTokens[i]]
                );
                collaterals[msg.sender][collateralTokens[i]] = 0;
            }
        }
        loandIds++;
    }

    // 3. Monthly payment
    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint _amount, IERC20 _stableCoin) {
        require(
            _stableCoin.allowance(msg.sender, address(this)) >= _amount,
            "Error"
        );
        _;
    }

    function monthlyPayment(
        uint _loanId,
        uint _amount,
        IERC20 _stableCoin
    ) public checkUsdcAllowance(_amount, _stableCoin) {
        loans[_loanId].monthlyPayment(_amount);
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        _stableCoin.transfer(address(ccflPools[_stableCoin]), _amount);
    }

    // 4. close loan
    function closeLoan(
        uint _loanId,
        uint _amount,
        IERC20 _stableCoin
    ) external {
        // get back loan
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        // repay for pool
        _stableCoin.approve(address(ccflPools[_stableCoin]), _amount);
        ccflPools[_stableCoin].closeLoan(_loanId, _amount);
        // update collateral balance and get back collateral
        (
            IERC20[] memory returnCollateralTokens,
            uint[] memory returnAmountCollateral
        ) = loans[_loanId].closeLoan();
        for (uint i = 0; i < returnCollateralTokens.length; i++) {
            if (returnAmountCollateral[i] > 0) {
                collaterals[msg.sender][
                    returnCollateralTokens[i]
                ] += returnAmountCollateral[i];
            }
        }
    }

    // .6 withdraw Collateral
    function withdrawCollateral(uint _amount, IERC20 _tokenAddress) public {
        require(
            _amount <= collaterals[msg.sender][_tokenAddress],
            "Do not have enough collateral"
        );
        collaterals[msg.sender][_tokenAddress] -= _amount;
        emit Withdraw(msg.sender, _amount, block.timestamp);
        _tokenAddress.transfer(msg.sender, _amount);
    }

    // .6 withdraw Collateral
    function withdrawCollateralOnClosedLoan(uint _loanId, address _to) public {
        // loans[_loanId].withdrawAllCollateral(_to);
    }

    function getLatestPrice(IERC20 _stableCoin) public view returns (uint) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeeds[_stableCoin].latestRoundData();
        // for LINK / USD price is scaled up by 10 ** 8
        return uint(price);
    }

    receive() external payable {}

    function upgradeTo(address) public {}
}
