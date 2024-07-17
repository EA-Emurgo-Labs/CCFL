// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "./IERC20Standard.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLPool.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLLoan.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL is Initializable {
    using Clones for address;

    address payable public owner;
    mapping(address => mapping(IERC20Standard => uint)) public collaterals;

    uint public loandIds;
    mapping(IERC20Standard => ICCFLPool) public ccflPools;
    IERC20Standard[] public ccflPoolStableCoins;
    ICCFLLoan ccflLoan;
    mapping(uint => ICCFLLoan) loans;

    // init for clone loan sc
    IERC20Standard[] public collateralTokens;
    mapping(IERC20Standard => IPoolAddressesProvider)
        public aaveAddressProviders;
    mapping(IERC20Standard => IERC20Standard) public aTokens;
    mapping(IERC20Standard => uint) public LTV;
    mapping(IERC20Standard => uint) public liquidationThreshold;
    mapping(IERC20Standard => AggregatorV3Interface) public priceFeeds;
    mapping(IERC20Standard => AggregatorV3Interface) public pricePoolFeeds;
    uint public rateLoan;

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

    modifier supportedToken(IERC20Standard _tokenAddress) {
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
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools,
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        uint[] memory _ltvs,
        uint[] memory _thresholds,
        ICCFLLoan _ccflLoan
    ) external initializer {
        ccflPoolStableCoins = _ccflPoolStableCoin;
        owner = payable(msg.sender);
        loandIds = 1;
        for (uint i = 0; i < ccflPoolStableCoins.length; i++) {
            IERC20Standard token = ccflPoolStableCoins[i];
            ccflPools[token] = _ccflPools[i];
            pricePoolFeeds[token] = _poolAggregators[i];
        }
        collateralTokens = _collateralTokens;
        for (uint i = 0; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            priceFeeds[token] = _collateralAggregators[i];
            LTV[token] = _ltvs[i];
            liquidationThreshold[token] = _thresholds[i];
            aTokens[token] = _aTokens[i];
            aaveAddressProviders[token] = _aaveAddressProviders[i];
        }
        rateLoan = 1200;
        ccflLoan = _ccflLoan;
    }

    // create loan
    // 1. deposit
    // Modifier to check token allowance
    modifier checkTokenAllowance(IERC20Standard _token, uint _amount) {
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
        IERC20Standard _tokenAddress
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
    function createLoan(
        uint _amount,
        uint _months,
        IERC20Standard _stableCoin
    ) public {
        // check enough collateral
        uint collateralByUSD = 0;
        for (uint i = 0; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            if (collaterals[msg.sender][token] > 0) {
                collateralByUSD +=
                    (collaterals[msg.sender][token] *
                        getLatestPrice(token, false) *
                        LTV[token]) /
                    10000;
            }
        }

        require(
            collateralByUSD >= _amount * getLatestPrice(_stableCoin, true),
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
        IERC20Standard[] memory _aTokens = new IERC20Standard[](
            collateralTokens.length
        );
        IPoolAddressesProvider[]
            memory _aaveAddressProviders = new IPoolAddressesProvider[](
                collateralTokens.length
            );
        AggregatorV3Interface[]
            memory _priceFeeds = new AggregatorV3Interface[](
                collateralTokens.length
            );
        for (uint i = 0; i < collateralTokens.length; i++) {
            _ltvs[i] = LTV[collateralTokens[i]];
            _thresholds[i] = liquidationThreshold[collateralTokens[i]];
            _aTokens[i] = aTokens[collateralTokens[i]];
            _aaveAddressProviders[i] = aaveAddressProviders[
                collateralTokens[i]
            ];
            _priceFeeds[i] = priceFeeds[collateralTokens[i]];
        }
        AggregatorV3Interface _pricePoolFeeds = pricePoolFeeds[_stableCoin];
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        cloneSC.initialize(
            loan,
            collateralTokens,
            _aaveAddressProviders,
            _aTokens,
            _ltvs,
            _thresholds,
            _priceFeeds,
            _pricePoolFeeds
        );
        ICCFLPool pool = ccflPools[_stableCoin];
        cloneSC.setCCFLPool(pool, address(this));
        loans[loandIds] = cloneSC;
        // transfer collateral
        for (uint i = 0; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            if (collaterals[msg.sender][token] > 0) {
                cloneSC.updateCollateral(token, collaterals[msg.sender][token]);
                uint transferAmount = collaterals[msg.sender][token];
                collaterals[msg.sender][token] = 0;
                token.transfer(address(loanIns), transferAmount);
            }
        }
        loandIds++;
    }

    // 3. Monthly payment
    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint _amount, IERC20Standard _stableCoin) {
        require(
            _stableCoin.allowance(msg.sender, address(this)) >= _amount,
            "Error"
        );
        _;
    }

    function monthlyPayment(
        uint _loanId,
        uint _amount,
        IERC20Standard _stableCoin
    ) public checkUsdcAllowance(_amount, _stableCoin) {
        loans[_loanId].monthlyPayment(_amount);
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        _stableCoin.transfer(address(ccflPools[_stableCoin]), _amount);
    }

    // 4. close loan
    function closeLoan(
        uint _loanId,
        uint _amount,
        IERC20Standard _stableCoin
    ) external {
        // get back loan
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        // repay for pool
        _stableCoin.approve(address(ccflPools[_stableCoin]), _amount);
        ccflPools[_stableCoin].closeLoan(_loanId, _amount);
        // update collateral balance and get back collateral
        (
            IERC20Standard[] memory returnCollateralTokens,
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
    function withdrawCollateral(
        uint _amount,
        IERC20Standard _tokenAddress
    ) public {
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

    function getLatestPrice(
        IERC20Standard _stableCoin,
        bool isPool
    ) public view returns (uint) {
        if (isPool == false) {
            (
                uint80 roundID,
                int256 price,
                uint256 startedAt,
                uint256 timeStamp,
                uint80 answeredInRound
            ) = priceFeeds[_stableCoin].latestRoundData();
            // for LINK / USD price is scaled up by 10 ** 8
            return uint(price);
        } else {
            (
                uint80 roundID,
                int256 price,
                uint256 startedAt,
                uint256 timeStamp,
                uint80 answeredInRound
            ) = pricePoolFeeds[_stableCoin].latestRoundData();
            // for LINK / USD price is scaled up by 10 ** 8
            return uint(price);
        }
    }

    function getHealthFactor(uint _loanId) public view returns (uint) {
        ICCFLLoan loan = loans[_loanId];
        return loan.getHealthFactor();
    }

    receive() external payable {}

    function upgradeTo(address) public {}
}
