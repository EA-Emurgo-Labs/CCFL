// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "./ICCFLConfig.sol";
import "./helpers/Errors.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLConfig is ICCFLConfig, Initializable {
    using Clones for address;

    // init for clone loan sc
    uint24 public maxLTV;
    uint24 public liquidationThreshold;
    IV3SwapRouter swapRouter;
    IUniswapV3Factory public factory;
    IQuoterV2 public quoter;
    address public owner;

    // penalty / 10000
    uint24 public penaltyPlatform;
    uint24 public penaltyLiquidator;
    uint24 public penaltyLender;
    // earn AAVE /10000
    uint24 public earnPlatform;
    uint24 public earnBorrower;
    uint24 public earnLender;
    IPoolAddressesProvider public aaveAddressProvider;

    address public liquidator;
    address public platform;

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.ONLY_THE_OWNER);
        _;
    }

    function initialize(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators,
        ICCFLPool[] memory _ccflPools,
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens,
        IPoolAddressesProvider _aaveAddressProvider,
        uint24 _maxLTV,
        uint24 _liquidationThreshold,
        ICCFLLoan _ccflLoan
    ) external initializer {
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
        owner = msg.sender;
    }

    function setEarnShare(
        uint24 _borrower,
        uint24 _platform,
        uint24 _lender
    ) public onlyOwner {
        earnLender = _lender;
        earnBorrower = _borrower;
        earnPlatform = _platform;
    }

    function getEarnShare() public view returns (uint24, uint24, uint24) {
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
        uint24 _maxLTV,
        uint24 _liquidationThreshold
    ) public onlyOwner {
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
    }

    function getThreshold() public view returns (uint24, uint24) {
        return (maxLTV, liquidationThreshold);
    }

    function setPenalty(
        uint24 _platform,
        uint24 _liquidator,
        uint24 _lender
    ) public onlyOwner {
        penaltyLender = _lender;
        penaltyLiquidator = _liquidator;
        penaltyPlatform = _platform;
    }

    function getPenalty() public view returns (uint24, uint24, uint24) {
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
        onlyOwner
        returns (IV3SwapRouter, IUniswapV3Factory, IQuoterV2)
    {
        return (swapRouter, factory, quoter);
    }
}
