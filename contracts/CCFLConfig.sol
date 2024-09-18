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
        uint _maxLTV,
        uint _liquidationThreshold,
        ICCFLLoan _ccflLoan
    ) external initializer {
        maxLTV = _maxLTV;
        liquidationThreshold = _liquidationThreshold;
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
        onlyOwner
        returns (IV3SwapRouter, IUniswapV3Factory, IQuoterV2)
    {
        return (swapRouter, factory, quoter);
    }
}
