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
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

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
    uint public maxLTV;
    uint public liquidationThreshold;
    mapping(IERC20Standard => AggregatorV3Interface) public priceFeeds;
    mapping(IERC20Standard => AggregatorV3Interface) public pricePoolFeeds;
    ISwapRouter swapRouter;
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
        uint _maxLTV,
        uint _liquidationThreshold,
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
            aTokens[token] = _aTokens[i];
            aaveAddressProviders[token] = _aaveAddressProviders[i];
        }
        rateLoan = 1200;
        ccflLoan = _ccflLoan;
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
    }

    function setSwapRouter(ISwapRouter _swapRouter) public {
        swapRouter = _swapRouter;
    }

    // Modifier to check token allowance
    modifier checkTokenAllowance(IERC20Standard _token, uint _amount) {
        require(
            _token.allowance(msg.sender, address(this)) >= _amount,
            "Error"
        );
        _;
    }

    function makeYieldGenerating(uint _loanId, bool isYield) public {
        ICCFLLoan loan = loans[_loanId];
        if (isYield == true) loan.supplyLiquidity();
        else loan.withdrawLiquidity();
    }

    // create loan
    function createLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountCollateral,
        IERC20Standard _collateral,
        bool isYieldGenerating
    ) public {
        require(
            _amountCollateral * getLatestPrice(_collateral, false) * maxLTV >=
                (_amount * getLatestPrice(_stableCoin, true)) * 10000,
            "Don't have enough collateral"
        );
        // check pool reseve
        require(
            ccflPools[_stableCoin].getRemainingPool() >= _amount,
            "Pool don't have enough fund"
        );

        // make loan ins
        Loan memory loan;
        address _borrower = msg.sender;
        loan.borrower = _borrower;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.rateLoan = rateLoan;
        loan.stableCoin = _stableCoin;
        // lock loan on pool
        ccflPools[_stableCoin].lockLoan(loan.loanId, loan.amount, _borrower);

        AggregatorV3Interface _pricePoolFeeds = pricePoolFeeds[_stableCoin];
        IERC20Standard token = _collateral;
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        cloneSC.initialize(
            loan,
            token,
            aaveAddressProviders[token],
            aTokens[token],
            maxLTV,
            liquidationThreshold,
            priceFeeds[token],
            _pricePoolFeeds,
            swapRouter
        );
        cloneSC.setCCFL(address(this));
        if (isYieldGenerating == true) cloneSC.supplyLiquidity();

        // transfer collateral
        cloneSC.updateCollateral(_amountCollateral);
        // get from user to loan
        _collateral.transferFrom(
            msg.sender,
            address(loanIns),
            _amountCollateral
        );
        loans[loandIds] = cloneSC;
        loandIds++;
    }

    // withdraw loan
    function withdrawLoan(IERC20Standard _stableCoin, uint _loanId) public {
        ccflPools[_stableCoin].withdrawLoan(msg.sender, _loanId);
    }

    // close loan
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
            IERC20Standard returnCollateralToken,
            uint returnAmountCollateral
        ) = loans[_loanId].closeLoan();
        if (returnAmountCollateral > 0) {
            collaterals[msg.sender][
                returnCollateralToken
            ] += returnAmountCollateral;
        }
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

    function getLoanAddress(uint _loanId) public view returns (address) {
        ICCFLLoan loan = loans[_loanId];
        return address(loan);
    }

    function liquidate(uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        Loan memory loanInfo = loan.getLoanInfo();
        loan.liquidate();
        // get back loan
        loanInfo.stableCoin.transferFrom(
            address(loan),
            address(this),
            loanInfo.amount
        );
        // repay for pool
        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            loanInfo.amount
        );
        ccflPools[loanInfo.stableCoin].closeLoan(_loanId, loanInfo.amount);
        // update collateral balance and get back collateral
        (
            IERC20Standard returnCollateralToken,
            uint returnAmountCollateral
        ) = loans[_loanId].liquidateCloseLoan();

        if (returnAmountCollateral > 0) {
            collaterals[msg.sender][
                returnCollateralToken
            ] += returnAmountCollateral;
        }
    }

    receive() external payable {}

    function upgradeTo(address) public {}
}
