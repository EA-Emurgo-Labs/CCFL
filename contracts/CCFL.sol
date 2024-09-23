// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "./ICCFL.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL is ICCFL, Initializable {
    using Clones for address;
    mapping(address => bool) public operators;
    uint public loandIds;
    address public owner;
    bool public isPaused;
    mapping(address => uint[]) public userLoans;
    ICCFLConfig public ccflConfig;
    ICCFLLoan public ccflLoan;
    mapping(IERC20Standard => ICCFLPool) public ccflPools;
    mapping(uint => ICCFLLoan) loans;

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
            ccflConfig.getCcflActiveCoins(_tokenAddress) == true,
            Errors.POOL_TOKEN_IS_NOT_ACTIVED
        );
        _;
    }

    modifier supportedCollateralToken(IERC20Standard _tokenAddress) {
        require(
            ccflConfig.getCcflActiveCoins(_tokenAddress) == true,
            Errors.COLLATERAL_TOKEN_IS_NOT_ACTIVED
        );
        _;
    }

    modifier onlyETHNative() {
        require(
            ccflConfig.getEnableETHNative() == true,
            Errors.ETH_NATIVE_DISABLE
        );
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
        ICCFLPool[] memory _ccflPools,
        ICCFLConfig _ccflConfig,
        ICCFLLoan _ccflLoan
    ) external initializer {
        for (uint i = 0; i < _ccflPools.length; i++) {
            ccflPools[_ccflPoolStableCoin[i]] = _ccflPools[i];
        }
        loandIds = 1;
        owner = msg.sender;
        operators[msg.sender] = true;
        ccflConfig = _ccflConfig;
        ccflLoan = _ccflLoan;
    }

    function setPools(
        IERC20Standard[] memory _ccflPoolStableCoin,
        ICCFLPool[] memory _ccflPools
    ) public onlyOperator {
        for (uint i = 0; i < _ccflPools.length; i++) {
            ccflPools[_ccflPoolStableCoin[i]] = _ccflPools[i];
        }
    }

    function setCCFLLoan(ICCFLLoan _loan) public onlyOwner {
        ccflLoan = _loan;
    }

    function setPaused(bool _paused) public onlyOwner {
        isPaused = _paused;
    }

    function setOperators(
        address[] memory _addresses,
        bool[] memory _isActives
    ) public onlyOwner {
        for (uint i = 0; i < _addresses.length; i++) {
            operators[_addresses[i]] = _isActives[i];
        }
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
        (uint maxLTV, uint liquidationThreshold) = ccflConfig.getThreshold();
        return ((((_amount * (10 ** _collateral.decimals()) * 10000) *
            ccflConfig.getLatestPrice(_stableCoin, true)) /
            (10 ** _stableCoin.decimals())) /
            maxLTV /
            ccflConfig.getLatestPrice(_collateral, false));
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
        (uint maxLTV, uint liquidationThreshold) = ccflConfig.getThreshold();
        require(
            (_amountCollateral *
                ccflConfig.getLatestPrice(_collateral, false) *
                maxLTV) /
                (10 ** _collateral.decimals()) >=
                ((_amount * ccflConfig.getLatestPrice(_stableCoin, true)) *
                    10000) /
                    (10 ** _stableCoin.decimals()),
            Errors.DO_NOT_HAVE_ENOUGH_COLLATERAL
        );
        createLoanCore(
            _amount,
            _stableCoin,
            _amountCollateral,
            _collateral,
            _isYieldGenerating,
            _isFiat,
            false
        );
    }

    function estimateHealthFactor(
        IERC20Standard _stableCoin,
        uint _amount,
        IERC20Standard _collateralToken,
        uint _amountCollateral
    ) public view returns (uint) {
        uint stableCoinPrice = ccflConfig.getLatestPrice(_stableCoin, true);
        uint collateralPrice = ccflConfig.getLatestPrice(
            _collateralToken,
            false
        );
        (uint maxLTV, uint liquidationThreshold) = ccflConfig.getThreshold();
        uint totalCollaterals = (_amountCollateral *
            collateralPrice *
            liquidationThreshold) /
            10000 /
            (10 ** _collateralToken.decimals());

        uint totalLoan = (_amount * stableCoinPrice) /
            (10 ** _stableCoin.decimals());

        uint healthFactor = (totalCollaterals * 100) / totalLoan;
        return healthFactor;
    }

    function createLoanCore(
        uint _amount,
        IERC20Standard _stableCoin,
        uint _amountCollateral,
        IERC20Standard _collateral,
        bool _isYieldGenerating,
        bool _isFiat,
        bool _isETH
    ) internal {
        // check pool reseve
        require(
            ccflPools[_stableCoin].getRemainingPool() >= _amount,
            Errors.DO_NOT_HAVE_ENOUGH_LENDING_FUND
        );

        // make loan ins
        DataTypes.Loan memory loan;
        loan.borrower = msg.sender;
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

        IERC20Standard token = _collateral;
        // clone a loan SC
        address loanIns = address(ccflLoan).clone();
        ICCFLLoan cloneSC = ICCFLLoan(loanIns);
        {
            (uint maxLTV, uint liquidationThreshold) = ccflConfig
                .getThreshold();
            cloneSC.initialize(loan, token, ccflConfig);
        }
        cloneSC.setCCFL(address(this));

        {
            uint24 fee = ccflConfig.getCollateralToStableFee(
                token,
                _stableCoin
            );
            cloneSC.setUniFee(fee);
        }

        if (_isETH == false) {
            // transfer collateral
            _collateral.transferFrom(
                msg.sender,
                address(this),
                _amountCollateral
            );

            _collateral.approve(address(loanIns), _amountCollateral);

            cloneSC.updateCollateral(_amountCollateral);
        } else {
            // transfer collateral
            // get from user to loan
            IWETH wETH = ccflConfig.getWETH();
            IERC20Standard(address(wETH)).approve(
                address(loanIns),
                _amountCollateral
            );

            cloneSC.updateCollateral(_amountCollateral);
        }

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
            !_isETH
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
        IWETH wETH = ccflConfig.getWETH();
        wETH.deposit{value: _amountETH}();
        (uint maxLTV, uint liquidationThreshold) = ccflConfig.getThreshold();
        require(
            (_amountETH *
                ccflConfig.getLatestPrice(
                    IERC20Standard(address(wETH)),
                    false
                ) *
                maxLTV) /
                (10 ** IERC20Standard(address(wETH)).decimals()) >=
                ((_amount * ccflConfig.getLatestPrice(_stableCoin, true)) *
                    10000) /
                    (10 ** _stableCoin.decimals()),
            Errors.DO_NOT_HAVE_ENOUGH_COLLATERAL
        );

        createLoanCore(
            _amount,
            _stableCoin,
            _amountETH,
            IERC20Standard(address(wETH)),
            _isYieldGenerating,
            _isFiat,
            false
        );
    }

    function addCollateral(
        uint _loanId,
        uint _amountCollateral,
        IERC20Standard _collateral
    ) public supportedCollateralToken(_collateral) onlyUnpaused {
        ICCFLLoan loan = loans[_loanId];

        DataTypes.Loan memory info = loan.getLoanInfo();

        // get from user to loan
        _collateral.transferFrom(msg.sender, address(this), _amountCollateral);

        // transfer collateral
        _collateral.approve(address(loan), _amountCollateral);
        loan.updateCollateral(_amountCollateral);

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
        IWETH wETH = ccflConfig.getWETH();
        wETH.deposit{value: _amountETH}();

        ICCFLLoan loan = loans[_loanId];

        DataTypes.Loan memory info = loan.getLoanInfo();

        // transfer collateral
        IERC20Standard(address(wETH)).approve(address(loan), _amountETH);
        loan.updateCollateral(_amountETH);

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
            (uint256 usdLender, uint256 usdPlatform) = loans[_loanId]
                .closeLoan();
            if (usdLender > 0) {
                _stableCoin.transferFrom(
                    address(loans[_loanId]),
                    address(ccflPools[_stableCoin]),
                    usdLender
                );
                ccflPools[_stableCoin].earnStaking(usdLender);
            }
            (address liquidator, address platform) = ccflConfig
                .getPlatformAddress();
            if (usdPlatform > 0)
                _stableCoin.transferFrom(
                    address(loans[_loanId]),
                    platform,
                    usdPlatform
                );
        }

        emit RepayLoan(msg.sender, info, _amount, _debtRemain);
    }

    function withdrawAllCollateral(
        uint _loanId,
        bool _isETH
    ) public onlyUnpaused {
        ICCFLLoan loan = loans[_loanId];
        DataTypes.Loan memory info = loan.getLoanInfo();
        require(msg.sender == info.borrower, Errors.ONLY_THE_BORROWER);
        loan.withdrawAllCollateral(info.borrower, _isETH);

        emit WithdrawAllCollateral(
            msg.sender,
            info,
            loan.getCollateralAmount(),
            loan.getCollateralToken(),
            _isETH
        );
    }

    function withdrawAllCollateralByAdmin(
        uint _loanId,
        bool isETH
    ) public onlyOwner {
        ICCFLLoan loan = loans[_loanId];
        loan.withdrawAllCollateral(msg.sender, isETH);
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
        if (_amount >= curentDebt) {
            return 99999;
        }
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
        (
            uint256 usdLiquidatedLender,
            uint256 usdEarnLender,
            uint256 usdPlatform,
            uint256 usdLiquidator
        ) = loan.liquidate(curentDebt);
        // get back loan
        loanInfo.stableCoin.transferFrom(
            address(loan),
            address(this),
            curentDebt + usdLiquidatedLender + usdEarnLender
        );
        // repay for pool
        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            curentDebt
        );
        ccflPools[loanInfo.stableCoin].repay(_loanId, curentDebt);
        // update collateral balance and get back collateral

        (address liquidator, address platform) = ccflConfig
            .getPlatformAddress();

        loanInfo.stableCoin.transferFrom(address(loan), platform, usdPlatform);

        loanInfo.stableCoin.transferFrom(
            address(loan),
            liquidator,
            usdLiquidator
        );

        loanInfo.stableCoin.approve(
            address(ccflPools[loanInfo.stableCoin]),
            usdLiquidatedLender + usdEarnLender
        );

        ccflPools[loanInfo.stableCoin].liquidatePenalty(
            _loanId,
            usdLiquidatedLender
        );

        if (usdEarnLender > 0)
            ccflPools[loanInfo.stableCoin].earnStaking(usdEarnLender);

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
