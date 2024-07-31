// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "./ICCFL.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL is ICCFL, UUPSUpgradeable, OwnableUpgradeable {
    using Clones for address;

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
    address public liquidator;
    address public platform;

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
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        ccflPoolStableCoins = _ccflPoolStableCoin;
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
        ccflLoan = _ccflLoan;
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
    }

    function setSwapRouter(ISwapRouter _swapRouter) public {
        swapRouter = _swapRouter;
    }

    function setPlatformAddress(address _liquidator, address _plaform) public {
        liquidator = _liquidator;
        platform = _plaform;
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
            (_amountCollateral * getLatestPrice(_collateral, false) * maxLTV) /
                (10 ** _collateral.decimals()) >=
                ((_amount * getLatestPrice(_stableCoin, true)) * 10000) /
                    (10 ** _stableCoin.decimals()),
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
        loan.stableCoin = _stableCoin;
        // borrow loan on pool
        ccflPools[_stableCoin].borrow(loan.loanId, loan.amount, loan.borrower);

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
            swapRouter,
            platform
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

    function addCollateral(
        uint _loanId,
        uint _amountCollateral,
        IERC20Standard _collateral
    ) public {
        ICCFLLoan loan = loans[_loanId];
        // transfer collateral
        loan.updateCollateral(_amountCollateral);
        // get from user to loan
        _collateral.transferFrom(msg.sender, address(loan), _amountCollateral);
    }

    // withdraw loan
    function withdrawLoan(IERC20Standard _stableCoin, uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        Loan memory info = loan.getLoanInfo();
        ccflPools[_stableCoin].withdrawLoan(info.borrower, _loanId);
    }

    // repay loan
    function repayLoan(
        uint _loanId,
        uint _amount,
        IERC20Standard _stableCoin
    ) public {
        // get back loan
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        // repay for pool
        _stableCoin.approve(address(ccflPools[_stableCoin]), _amount);
        ccflPools[_stableCoin].repay(_loanId, _amount);
        // update collateral balance and get back collateral
        // Todo: if full payment, close loan
        if (ccflPools[_stableCoin].getCurrentLoan(_loanId) == 0) {
            loans[_loanId].closeLoan();
        }
    }

    function withdrawAllCollateral(uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        Loan memory info = loan.getLoanInfo();
        loan.withdrawAllCollateral(info.borrower);
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
        Loan memory loanInfo = loan.getLoanInfo();
        uint curentDebt = ccflPools[loanInfo.stableCoin].getCurrentLoan(
            _loanId
        );
        return loan.getHealthFactor(curentDebt);
    }

    function getLoanAddress(uint _loanId) public view returns (address) {
        ICCFLLoan loan = loans[_loanId];
        return address(loan);
    }

    function liquidate(uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        Loan memory loanInfo = loan.getLoanInfo();
        uint curentDebt = ccflPools[loanInfo.stableCoin].getCurrentLoan(
            _loanId
        );
        loan.liquidate(curentDebt);
        // get back loan
        loanInfo.stableCoin.transferFrom(
            address(loan),
            address(this),
            (curentDebt * 102) / 100
        );
        // repay for pool
        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            curentDebt
        );
        ccflPools[loanInfo.stableCoin].repay(_loanId, curentDebt);
        // update collateral balance and get back collateral

        loanInfo.stableCoin.transfer(platform, (curentDebt * 5) / 1000);
        loanInfo.stableCoin.transfer(liquidator, (curentDebt * 10) / 1000);
        // penalty for pool
        uint fundForLender = (curentDebt * 102) /
            100 -
            curentDebt -
            (curentDebt * 5) /
            1000 -
            (curentDebt * 10) /
            1000;

        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            fundForLender
        );
        ccflPools[loanInfo.stableCoin].liquidatePenalty(fundForLender);

        loans[_loanId].closeLoan();
    }

    receive() external payable {}

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}
}
