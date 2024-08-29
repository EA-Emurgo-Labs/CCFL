// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "./ICCFL.sol";
import "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
import "./helpers/Errors.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL is ICCFL, Initializable {
    using Clones for address;

    mapping(address => mapping(IERC20Standard => uint)) public collaterals;
    mapping(address => bool) public operators;

    uint public loandIds;
    mapping(IERC20Standard => ICCFLPool) public ccflPools;
    IERC20Standard[] public ccflPoolStableCoins;
    ICCFLLoan public ccflLoan;
    mapping(uint => ICCFLLoan) loans;

    mapping(IERC20Standard => bool) public ccflActivePoolStableCoins;

    // init for clone loan sc
    IERC20Standard[] public collateralTokens;
    mapping(IERC20Standard => bool) public ccflActiveCollaterals;

    IPoolAddressesProvider public aaveAddressProvider;
    mapping(IERC20Standard => IERC20Standard) public aTokens;
    uint public maxLTV;
    uint public liquidationThreshold;
    mapping(IERC20Standard => AggregatorV3Interface) public priceFeeds;
    mapping(IERC20Standard => AggregatorV3Interface) public pricePoolFeeds;
    ISwapRouter swapRouter;
    IUniswapV3Factory public factory;
    address public liquidator;
    address public platform;
    address public owner;
    IWETH public wETH;
    bool public isPaused;

    mapping(address => uint[]) public userLoans;

    // penalty / 10000
    uint public penaltyPlatform;
    uint public penaltyLiquidator;
    uint public penaltyLender;
    // earn AAVE /10000
    uint public earnPlatform;
    uint public earnBorrower;
    uint public earnLender;

    bool isEnableETHNative;

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.ONLY_THE_OWNER);
        _;
    }

    modifier onlyOperator() {
        require(operators[msg.sender] == true, Errors.ONLY_THE_OPERATOR);
        _;
    }

    modifier supportedPoolToken(IERC20Standard _tokenAddress) {
        require(
            ccflActivePoolStableCoins[_tokenAddress] == true,
            Errors.POOL_TOKEN_IS_NOT_ACTIVED
        );
        _;
    }

    modifier supportedCollateralToken(IERC20Standard _tokenAddress) {
        require(
            ccflActiveCollaterals[_tokenAddress] == true,
            Errors.COLLATERAL_TOKEN_IS_NOT_ACTIVED
        );
        _;
    }

    modifier onlyETHNative() {
        require(isEnableETHNative == true, Errors.ETH_NATIVE_DISABLE);
        _;
    }

    modifier onlyUnpaused() {
        require(isPaused == false, Errors.SC_IS_PAUSED);
        _;
    }

    function checkExistElement(
        IERC20Standard[] memory array,
        IERC20Standard el
    ) public pure returns (bool) {
        bool isExist = false;
        // check _tokenAddress is valid
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == el) {
                isExist = true;
                break;
            }
        }
        return isExist;
    }

    function initialize(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools,
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens,
        IPoolAddressesProvider _aaveAddressProvider,
        uint _maxLTV,
        uint _liquidationThreshold,
        ICCFLLoan _ccflLoan
    ) external initializer {
        ccflPoolStableCoins = _ccflPoolStableCoin;
        loandIds = 1;
        for (uint i = 0; i < ccflPoolStableCoins.length; i++) {
            IERC20Standard token = ccflPoolStableCoins[i];
            ccflPools[token] = _ccflPools[i];
            pricePoolFeeds[token] = _poolAggregators[i];
            ccflActivePoolStableCoins[token] = true;
        }
        collateralTokens = _collateralTokens;
        for (uint i = 0; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            priceFeeds[token] = _collateralAggregators[i];
            aTokens[token] = _aTokens[i];
            ccflActiveCollaterals[token] = true;
        }
        aaveAddressProvider = _aaveAddressProvider;
        ccflLoan = _ccflLoan;
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
        owner = msg.sender;
        operators[msg.sender] = true;
    }

    function setEnableETHNative(bool _isActived) public onlyOperator {
        isEnableETHNative = _isActived;
    }

    function setPaused(bool _paused) public onlyOwner {
        isPaused = _paused;
    }

    function setEarnShare(
        uint _borrower,
        uint _platform,
        uint _lender
    ) public onlyOperator {
        earnLender = _lender;
        earnBorrower = _borrower;
        earnPlatform = _platform;
    }

    function setOperators(
        address[] memory _addresses,
        bool[] memory _isActives
    ) public onlyOwner {
        for (uint i = 0; i < _addresses.length; i++) {
            operators[_addresses[i]] = _isActives[i];
        }
    }

    function setPools(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools
    ) public onlyOperator {
        for (uint i = 0; i < _ccflPoolStableCoin.length; i++) {
            IERC20Standard token = _ccflPoolStableCoin[i];
            if (checkExistElement(ccflPoolStableCoins, token) == false)
                ccflPoolStableCoins.push(token);
            ccflPools[token] = _ccflPools[i];
            pricePoolFeeds[token] = _poolAggregators[i];
            ccflActivePoolStableCoins[token] = true;
        }
    }

    function setCCFLLoan(ICCFLLoan _loan) public onlyOperator {
        ccflLoan = _loan;
    }

    function setCollaterals(
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens
    ) public onlyOperator {
        for (uint i = 0; i < _collateralTokens.length; i++) {
            IERC20Standard token = _collateralTokens[i];
            if (checkExistElement(collateralTokens, token) == false)
                collateralTokens.push(token);
            priceFeeds[token] = _collateralAggregators[i];
            aTokens[token] = _aTokens[i];
            ccflActiveCollaterals[token] = true;
        }
    }

    function setAaveProvider(
        IPoolAddressesProvider _aaveAddressProvider
    ) public onlyOperator {
        aaveAddressProvider = _aaveAddressProvider;
    }

    function setActiveToken(
        IERC20Standard _token,
        bool _isActived,
        bool _isPoolToken
    ) public onlyOperator {
        if (_isPoolToken) {
            require(
                checkExistElement(ccflPoolStableCoins, _token) == true,
                Errors.TOKEN_IS_NOT_EXISTED
            );
            ccflActiveCollaterals[_token] = _isActived;
        } else {
            require(
                checkExistElement(collateralTokens, _token) == true,
                Errors.TOKEN_IS_NOT_EXISTED
            );
            ccflActivePoolStableCoins[_token] = _isActived;
        }
    }

    function setThreshold(
        uint _maxLTV,
        uint _liquidationThreshold
    ) public onlyOperator {
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
    }

    function setPenalty(
        uint _platform,
        uint _liquidator,
        uint _lender
    ) public onlyOperator {
        penaltyLender = _lender;
        penaltyLiquidator = _liquidator;
        penaltyPlatform = _platform;
    }

    function setSwapRouter(
        ISwapRouter _swapRouter,
        IUniswapV3Factory _factory
    ) public onlyOperator {
        swapRouter = _swapRouter;
        factory = _factory;
    }

    function setWETH(IWETH _iWETH) public onlyOperator {
        wETH = _iWETH;
    }

    function setPlatformAddress(
        address _liquidator,
        address _platform
    ) public onlyOperator {
        liquidator = _liquidator;
        platform = _platform;
    }

    // Modifier to check token allowance
    // modifier checkTokenAllowance(IERC20Standard _token, uint _amount) {
    //     require(
    //         _token.allowance(msg.sender, address(this)) >= _amount,
    //         "Error"
    //     );
    //     _;
    // }

    function checkMinimalCollateralForLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        IERC20Standard _collateral
    ) public view returns (uint) {
        return ((((_amount * (10 ** _collateral.decimals()) * maxLTV) *
            getLatestPrice(_stableCoin, true)) /
            (10 ** _stableCoin.decimals())) /
            10000 /
            getLatestPrice(_collateral, false));
    }

    // create loan by ERC20
    function createLoan(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountCollateral,
        IERC20Standard _collateral,
        bool _isYieldGenerating,
        bool _isFiat
    )
        public
        supportedPoolToken(_stableCoin)
        supportedCollateralToken(_collateral)
        onlyUnpaused
    {
        require(
            (_amountCollateral * getLatestPrice(_collateral, false) * maxLTV) /
                (10 ** _collateral.decimals()) >=
                ((_amount * getLatestPrice(_stableCoin, true)) * 10000) /
                    (10 ** _stableCoin.decimals()),
            Errors.DO_NOT_HAVE_ENOUGH_COLLATERAL
        );
        // check pool reseve
        require(
            ccflPools[_stableCoin].getRemainingPool() >= _amount,
            Errors.DO_NOT_HAVE_ENOUGH_LENDING_FUND
        );

        // make loan ins
        DataTypes.Loan memory loan;
        address _borrower = msg.sender;
        loan.borrower = _borrower;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.stableCoin = _stableCoin;
        loan.isFiat = _isFiat;
        // borrow loan on pool
        ccflPools[_stableCoin].borrow(
            loan.loanId,
            loan.amount,
            loan.borrower,
            loan.isFiat
        );

        AggregatorV3Interface _pricePoolFeeds = pricePoolFeeds[_stableCoin];
        IERC20Standard token = _collateral;
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        cloneSC.initialize(
            loan,
            token,
            aaveAddressProvider,
            aTokens[token],
            maxLTV,
            liquidationThreshold,
            priceFeeds[token],
            _pricePoolFeeds,
            platform,
            wETH
        );
        cloneSC.setCCFL(address(this));
        cloneSC.setSwapRouter(swapRouter, factory);
        cloneSC.setEarnShare(earnBorrower, earnPlatform, earnLender);

        // transfer collateral
        cloneSC.updateCollateral(_amountCollateral);
        _collateral.transferFrom(
            msg.sender,
            address(loanIns),
            _amountCollateral
        );

        if (_isYieldGenerating == true) cloneSC.supplyLiquidity();
        loans[loandIds] = cloneSC;
        userLoans[msg.sender].push(loandIds);

        emit CreateLoan(
            msg.sender,
            address(loans[loandIds]),
            loan,
            _amountCollateral,
            _collateral,
            _isYieldGenerating,
            false
        );

        loandIds++;
    }

    // create loan by ETH
    function createLoanByETH(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountETH,
        bool _isYieldGenerating,
        bool _isFiat
    )
        public
        payable
        supportedPoolToken(_stableCoin)
        onlyETHNative
        onlyUnpaused
    {
        require(
            _amountETH <= msg.value,
            Errors.DO_NOT_HAVE_ENOUGH_DEPOSITED_ETH
        );
        wETH.deposit{value: _amountETH}();

        require(
            (_amountETH *
                getLatestPrice(IERC20Standard(address(wETH)), false) *
                maxLTV) /
                (10 ** IERC20Standard(address(wETH)).decimals()) >=
                ((_amount * getLatestPrice(_stableCoin, true)) * 10000) /
                    (10 ** _stableCoin.decimals()),
            Errors.DO_NOT_HAVE_ENOUGH_COLLATERAL
        );
        // check pool reseve
        require(
            ccflPools[_stableCoin].getRemainingPool() >= _amount,
            Errors.DO_NOT_HAVE_ENOUGH_LENDING_FUND
        );

        // make loan ins
        DataTypes.Loan memory loan;
        address _borrower = msg.sender;
        loan.borrower = _borrower;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.stableCoin = _stableCoin;
        loan.isFiat = _isFiat;
        // borrow loan on pool
        ccflPools[_stableCoin].borrow(
            loan.loanId,
            loan.amount,
            loan.borrower,
            loan.isFiat
        );

        AggregatorV3Interface _pricePoolFeeds = pricePoolFeeds[_stableCoin];
        IERC20Standard token = IERC20Standard(address(wETH));
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        cloneSC.initialize(
            loan,
            token,
            aaveAddressProvider,
            aTokens[token],
            maxLTV,
            liquidationThreshold,
            priceFeeds[token],
            _pricePoolFeeds,
            platform,
            wETH
        );
        cloneSC.setCCFL(address(this));
        cloneSC.setSwapRouter(swapRouter, factory);
        cloneSC.setEarnShare(earnBorrower, earnPlatform, earnLender);

        // transfer collateral
        cloneSC.updateCollateral(_amountETH);
        // get from user to loan
        IERC20Standard(address(wETH)).transfer(address(loanIns), _amountETH);

        if (_isYieldGenerating == true) cloneSC.supplyLiquidity();
        loans[loandIds] = cloneSC;
        userLoans[msg.sender].push(loandIds);

        emit CreateLoan(
            msg.sender,
            address(loans[loandIds]),
            loan,
            _amountETH,
            IERC20Standard(address(wETH)),
            _isYieldGenerating,
            true
        );

        loandIds++;
    }

    function addCollateral(
        uint _loanId,
        uint _amountCollateral,
        IERC20Standard _collateral
    ) public supportedCollateralToken(_collateral) onlyUnpaused {
        ICCFLLoan loan = loans[_loanId];

        DataTypes.Loan memory info = loan.getLoanInfo();

        // transfer collateral
        loan.updateCollateral(_amountCollateral);
        // get from user to loan

        _collateral.transferFrom(msg.sender, address(loan), _amountCollateral);

        if (loan.getIsYeild() == true) {
            loan.supplyLiquidity();
        }

        emit AddCollateral(
            msg.sender,
            info,
            _amountCollateral,
            _collateral,
            false
        );
    }

    function addCollateralByETH(
        uint _loanId,
        uint _amountETH
    ) public payable onlyETHNative onlyUnpaused {
        require(
            _amountETH <= msg.value,
            Errors.DO_NOT_HAVE_ENOUGH_DEPOSITED_ETH
        );
        wETH.deposit{value: _amountETH}();

        ICCFLLoan loan = loans[_loanId];

        DataTypes.Loan memory info = loan.getLoanInfo();

        // transfer collateral
        loan.updateCollateral(_amountETH);
        // get from user to loan

        IERC20Standard(address(wETH)).transfer(address(loan), _amountETH);

        if (loan.getIsYeild() == true) {
            loan.supplyLiquidity();
        }

        emit AddCollateral(
            msg.sender,
            info,
            _amountETH,
            IERC20Standard(address(wETH)),
            true
        );
    }

    // withdraw loan
    function withdrawLoan(IERC20Standard _stableCoin, uint _loanId) public {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory info = loan.getLoanInfo();
        require(
            info.borrower == msg.sender && info.isFiat == false,
            Errors.IS_NOT_OWNER_LOAN
        );
        ccflPools[_stableCoin].withdrawLoan(info.borrower, _loanId);
        loan.setPaid();

        emit WithdrawLoan(msg.sender, info);
    }

    function withdrawFiatLoan(
        IERC20Standard _stableCoin,
        uint _loanId
    ) public onlyOperator onlyUnpaused {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory info = loan.getLoanInfo();
        require(info.isFiat == true, Errors.ONLY_FIAT_LOAN);
        ccflPools[_stableCoin].withdrawLoan(msg.sender, _loanId);
        loan.setPaid();

        emit WithdrawLoan(msg.sender, info);
    }

    // repay loan
    function repayLoan(
        uint _loanId,
        uint _amount,
        IERC20Standard _stableCoin
    ) public supportedPoolToken(_stableCoin) onlyUnpaused {
        uint256 payAmount = _amount;
        if (_amount > ccflPools[_stableCoin].getCurrentLoan(_loanId)) {
            payAmount = ccflPools[_stableCoin].getCurrentLoan(_loanId);
        }

        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory info = loan.getLoanInfo();
        // get back loan
        _stableCoin.transferFrom(msg.sender, address(this), payAmount);
        // repay for pool
        _stableCoin.approve(address(ccflPools[_stableCoin]), payAmount);
        ccflPools[_stableCoin].repay(_loanId, payAmount);
        // update collateral balance and get back collateral
        // Todo: if full payment, close loan
        uint _debtRemain = ccflPools[_stableCoin].getCurrentLoan(_loanId);
        if (_debtRemain == 0) {
            uint256 earnLenderBalance = loans[_loanId].closeLoan();
            if (earnLenderBalance > 0)
                ccflPools[_stableCoin].earnStaking(earnLenderBalance);
        }

        emit RepayLoan(msg.sender, info, _amount, _debtRemain);
    }

    function withdrawAllCollateral(
        uint _loanId,
        bool isETH
    ) public onlyUnpaused {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory info = loan.getLoanInfo();
        require(msg.sender == info.borrower, Errors.ONLY_THE_BORROWER);
        loan.withdrawAllCollateral(info.borrower, isETH);

        emit WithdrawAllCollateral(
            msg.sender,
            info,
            loan.getCollateralAmount(),
            loan.getCollateralToken(),
            isETH
        );
    }

    function withdrawAllCollateralByAdmin(
        uint _loanId,
        bool isETH
    ) public onlyOwner {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory info = loan.getLoanInfo();
        loan.withdrawAllCollateral(msg.sender, isETH);

        emit WithdrawAllCollateralByAdmin(
            msg.sender,
            info,
            loan.getCollateralAmount(),
            loan.getCollateralToken(),
            isETH
        );
    }

    function withdrawLiquidityByAdmin(uint _loanId) public onlyOwner {
        ICCFLLoan loan = loans[_loanId];
        loan.withdrawLiquidity();
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
        DataTypes.Loan memory loanInfo = loan.getLoanInfo();
        uint curentDebt = ccflPools[loanInfo.stableCoin].getCurrentLoan(
            _loanId
        );
        return loan.getHealthFactor(curentDebt, 0);
    }

    function repayHealthFactor(
        uint _loanId,
        uint _amount
    ) public view returns (uint) {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory loanInfo = loan.getLoanInfo();
        uint curentDebt = ccflPools[loanInfo.stableCoin].getCurrentLoan(
            _loanId
        );
        return loan.getHealthFactor(curentDebt - _amount, 0);
    }

    function addCollateralHealthFactor(
        uint _loanId,
        uint _amountCollateral
    ) public view returns (uint) {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory loanInfo = loan.getLoanInfo();
        uint curentDebt = ccflPools[loanInfo.stableCoin].getCurrentLoan(
            _loanId
        );
        return loan.getHealthFactor(curentDebt, _amountCollateral);
    }

    function getLoanAddress(uint _loanId) public view returns (address) {
        ICCFLLoan loan = loans[_loanId];
        return address(loan);
    }

    function liquidate(uint _loanId) public onlyUnpaused {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory loanInfo = loan.getLoanInfo();
        uint curentDebt = ccflPools[loanInfo.stableCoin].getCurrentLoan(
            _loanId
        );
        uint256 earnLenderBalance = loan.liquidate(
            curentDebt,
            penaltyLender + penaltyLiquidator + penaltyPlatform
        );
        // get back loan
        loanInfo.stableCoin.transferFrom(
            address(loan),
            address(this),
            (curentDebt *
                (10000 + penaltyLender + penaltyLiquidator + penaltyPlatform)) /
                10000
        );
        // repay for pool
        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            curentDebt
        );
        ccflPools[loanInfo.stableCoin].repay(_loanId, curentDebt);
        // update collateral balance and get back collateral

        loanInfo.stableCoin.transfer(
            platform,
            (curentDebt * penaltyPlatform) / 10000
        );
        loanInfo.stableCoin.transfer(
            liquidator,
            (curentDebt * penaltyLiquidator) / 10000
        );
        // penalty for pool
        uint fundForLender = (curentDebt *
            (10000 + penaltyLender + penaltyLiquidator + penaltyPlatform)) /
            10000 -
            curentDebt -
            (curentDebt * penaltyPlatform) /
            10000 -
            (curentDebt * penaltyLiquidator) /
            10000;

        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            fundForLender
        );
        ccflPools[loanInfo.stableCoin].liquidatePenalty(_loanId, fundForLender);
        ccflPools[loanInfo.stableCoin].earnStaking(earnLenderBalance);
        loans[_loanId].closeLoan();

        emit Liquidate(
            msg.sender,
            loanInfo.borrower,
            loanInfo,
            loan.getCollateralAmount(),
            loan.getCollateralToken()
        );
    }

    function getLoanIds(address borrower) public view returns (uint[] memory) {
        return userLoans[borrower];
    }

    receive() external payable {}
}
