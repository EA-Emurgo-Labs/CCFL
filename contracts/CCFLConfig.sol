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

    IERC20Standard[] public ccflPoolStableCoins;

    mapping(IERC20Standard => bool) public ccflActiveCoins;

    // init for clone loan sc
    IERC20Standard[] public collateralTokens;

    mapping(IERC20Standard => IERC20Standard) public aTokens;
    mapping(IERC20Standard => AggregatorV3Interface) public priceFeeds;
    mapping(IERC20Standard => AggregatorV3Interface) public pricePoolFeeds;

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
    ) external initializer {
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
        owner = msg.sender;
    }

    // function addPoolCollateral(
    //     IERC20Standard[] memory _ccflPoolStableCoin,
    //     AggregatorV3Interface[] memory _poolAggregators,
    //     IERC20Standard[] memory _collateralTokens,
    //     AggregatorV3Interface[] memory _collateralAggregators,
    //     IERC20Standard[] memory _aTokens
    // ) public {
    //     ccflPoolStableCoins = _ccflPoolStableCoin;
    //     for (uint i = 0; i < ccflPoolStableCoins.length; i++) {
    //         IERC20Standard token = ccflPoolStableCoins[i];
    //         pricePoolFeeds[token] = _poolAggregators[i];
    //         ccflActiveCoins[token] = true;
    //     }
    //     collateralTokens = _collateralTokens;
    //     for (uint i = 0; i < collateralTokens.length; i++) {
    //         IERC20Standard token = collateralTokens[i];
    //         priceFeeds[token] = _collateralAggregators[i];
    //         aTokens[token] = _aTokens[i];
    //         ccflActiveCoins[token] = true;
    //     }
    // }

    function getCcflActiveCoins(
        IERC20Standard _tokenAddress
    ) public view returns (bool) {
        return ccflActiveCoins[_tokenAddress];
    }

    function setActiveToken(
        IERC20Standard _token,
        bool _isActived,
        bool _isPoolToken
    ) public onlyOwner {
        if (_isPoolToken) {
            require(
                checkExistElement(ccflPoolStableCoins, _token) == true,
                Errors.TOKEN_IS_NOT_EXISTED
            );
            ccflActiveCoins[_token] = _isActived;
        } else {
            require(
                checkExistElement(collateralTokens, _token) == true,
                Errors.TOKEN_IS_NOT_EXISTED
            );
            ccflActiveCoins[_token] = _isActived;
        }
    }

    function setCollaterals(
        IERC20Standard[] memory _collateralTokens,
        AggregatorV3Interface[] memory _collateralAggregators,
        IERC20Standard[] memory _aTokens
    ) public onlyOwner {
        for (uint i = 0; i < _collateralTokens.length; i++) {
            IERC20Standard token = _collateralTokens[i];
            if (checkExistElement(collateralTokens, token) == false)
                collateralTokens.push(token);
            priceFeeds[token] = _collateralAggregators[i];
            aTokens[token] = _aTokens[i];
            ccflActiveCoins[token] = true;
        }
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

    function setPoolCoins(
        IERC20Standard[] memory _ccflPoolStableCoin,
        AggregatorV3Interface[] memory _poolAggregators
    ) public onlyOwner {
        for (uint i = 0; i < _ccflPoolStableCoin.length; i++) {
            IERC20Standard token = _ccflPoolStableCoin[i];
            if (checkExistElement(ccflPoolStableCoins, token) == false)
                ccflPoolStableCoins.push(token);
            pricePoolFeeds[token] = _poolAggregators[i];
            ccflActiveCoins[token] = true;
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

    function getAtoken(
        IERC20Standard _collateral
    ) public view returns (IERC20Standard) {
        return aTokens[_collateral];
    }
}
