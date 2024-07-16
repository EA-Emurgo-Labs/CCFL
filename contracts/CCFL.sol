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
    mapping(address => uint) public totalLoans;
    mapping(address => mapping(IERC20 => uint)) public collaterals;
    mapping(address => uint) public stakeAave;
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
        AggregatorV3Interface[] memory _aggregators,
        IERC20[] memory _ccflPoolStableCoin,
        ICCFLPool[] memory _ccflPools,
        ICCFLLoan _ccflLoan,
        IERC20[] memory _aTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        IERC20[] memory _collateralTokens
    ) external initializer {
        ccflPoolStableCoins = _ccflPoolStableCoin;
        owner = payable(msg.sender);
        loandIds = 1;
        for (uint i = 0; i < _ccflPoolStableCoin.length; i++) {
            ccflPools[_ccflPoolStableCoin[i]] = _ccflPools[i];
            priceFeeds[_ccflPoolStableCoin[i]] = _aggregators[i];
        }
        rateLoan = 1200;
        ccflLoan = _ccflLoan;
        aTokens = _aTokens;
        // aaveAddressProviders = _aaveAddressProviders;
        collateralTokens = _collateralTokens;
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
                _amount / getLatestPrice(_stableCoin),
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
        loan.deadline = block.timestamp + time;
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
        totalLoans[_borrower] += _amount;
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        cloneSC.initialize(
            loan,
            collateralTokens,
            aaveAddressProviders,
            aTokens
        );
        loans[loandIds] = cloneSC;
        // transfer collateral
        for (uint i = 0; i < collateralTokens.length; i++) {
            if (collaterals[msg.sender][collateralTokens[i]] > 0) {
                collateralTokens[i].transfer(
                    address(ccflPools[_stableCoin]),
                    collaterals[msg.sender][collateralTokens[i]]
                );
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
        loans[_loanId].closeLoan();
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        _stableCoin.approve(address(ccflPools[_stableCoin]), _amount);
        ccflPools[_stableCoin].closeLoan(_loanId, _amount);
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
        loans[_loanId].withdrawAllCollateral(_to);
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
