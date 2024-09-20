// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "./ICCFLConfig.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLConfig is ICCFLConfig, Initializable {
    // init for clone loan sc
    uint public maxLTV;
    uint public liquidationThreshold;
    IV3SwapRouter swapRouter;
    IUniswapV3Factory public factory;
    IQuoterV2 public quoter;
    address public owner;

    // penalty / 10000
    uint public penaltyPlatform;
    uint public penaltyLiquidator;
    uint public penaltyLender;
    // earn AAVE /10000
    uint public earnPlatform;
    uint public earnBorrower;
    uint public earnLender;
    IPoolAddressesProvider public aaveAddressProvider;

    address public liquidator;
    address public platform;
    bool isEnableETHNative;
    IWETH public wETH;

    mapping(IERC20Standard => mapping(IERC20Standard => uint24))
        public collateralToStableCoinFee;

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.ONLY_THE_OWNER);
        _;
    }

    function initialize(
        uint _maxLTV,
        uint _liquidationThreshold,
        IV3SwapRouter _swapRouter,
        IUniswapV3Factory _factory,
        IQuoterV2 _quoter,
        IPoolAddressesProvider _aaveAddressProvider,
        address _liquidator,
        address _platform,
        bool _isEnableETHNative,
        IWETH _wETH
    )
        external
        // ICCFLLoan _ccflLoan
        initializer
    {
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
        swapRouter = _swapRouter;
        factory = _factory;
        quoter = _quoter;
        aaveAddressProvider = _aaveAddressProvider;
        liquidator = _liquidator;
        platform = _platform;
        isEnableETHNative = _isEnableETHNative;
        wETH = _wETH;
        // ccflLoan = _ccflLoan;
        owner = msg.sender;
    }

    function setEarnShare(
        uint _borrower,
        uint _platform,
        uint _lender
    ) public onlyOwner {
        earnLender = _lender;
        earnBorrower = _borrower;
        earnPlatform = _platform;
    }

    function getEarnShare() public view returns (uint, uint, uint) {
        return (earnLender, earnBorrower, earnPlatform);
    }

    function setAaveProvider(
        IPoolAddressesProvider _aaveAddressProvider
    ) public onlyOwner {
        aaveAddressProvider = _aaveAddressProvider;
    }

    function getAaveProvider() public view returns (IPoolAddressesProvider) {
        return aaveAddressProvider;
    }

    function setThreshold(
        uint _maxLTV,
        uint _liquidationThreshold
    ) public onlyOwner {
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
    }

    function getThreshold() public view returns (uint, uint) {
        return (maxLTV, liquidationThreshold);
    }

    function setPenalty(
        uint _platform,
        uint _liquidator,
        uint _lender
    ) public onlyOwner {
        penaltyLender = _lender;
        penaltyLiquidator = _liquidator;
        penaltyPlatform = _platform;
    }

    function getPenalty() public view returns (uint, uint, uint) {
        return (penaltyLender, penaltyLiquidator, penaltyPlatform);
    }

    function setSwapRouter(
        IV3SwapRouter _swapRouter,
        IUniswapV3Factory _factory,
        IQuoterV2 _quoter
    ) public onlyOwner {
        swapRouter = _swapRouter;
        factory = _factory;
        quoter = _quoter;
    }

    function getSwapRouter()
        public
        view
        returns (IV3SwapRouter, IUniswapV3Factory, IQuoterV2)
    {
        return (swapRouter, factory, quoter);
    }

    function setPlatformAddress(
        address _liquidator,
        address _platform
    ) public onlyOwner {
        liquidator = _liquidator;
        platform = _platform;
    }

    function getPlatformAddress() public view returns (address, address) {
        return (liquidator, platform);
    }

    function setEnableETHNative(bool _isActived) public onlyOwner {
        isEnableETHNative = _isActived;
    }

    function getEnableETHNative() public view returns (bool) {
        return isEnableETHNative;
    }

    function setWETH(IWETH _iWETH) public onlyOwner {
        wETH = _iWETH;
    }

    function getWETH() public view returns (IWETH) {
        return wETH;
    }

    // function setCCFLLoan(ICCFLLoan _loan) public onlyOwner {
    //     ccflLoan = _loan;
    // }

    // function getCCFLLoan() public view returns (ICCFLLoan) {
    //     return ccflLoan;
    // }

    function setCollateralToStableFee(
        IERC20Standard[] memory _collateral,
        IERC20Standard[] memory _stable,
        uint24[] memory _fee
    ) public onlyOwner {
        for (uint i = 0; i < _collateral.length; i++)
            collateralToStableCoinFee[_collateral[i]][_stable[i]] = _fee[i];
    }

    function getCollateralToStableFee(
        IERC20Standard _collateral,
        IERC20Standard _stable
    ) public view returns (uint24) {
        return collateralToStableCoinFee[_collateral][_stable];
    }
}
