// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "./ICCFL.sol";
import "@aave/core-v3/contracts/misc/interfaces/IWETH.sol";
import "./helpers/Errors.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLConfig is Initializable {
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
    IV3SwapRouter swapRouter;
    IUniswapV3Factory public factory;
    IQuoterV2 public quoter;
    address public liquidator;
    address public platform;
    address public owner;
    IWETH public wETH;
    bool public isPaused;

    mapping(address => uint[]) public userLoans;

    // penalty / 10000
    uint24 public penaltyPlatform;
    uint24 public penaltyLiquidator;
    uint24 public penaltyLender;
    // earn AAVE /10000
    uint24 public earnPlatform;
    uint24 public earnBorrower;
    uint24 public earnLender;

    bool isEnableETHNative;

    mapping(IERC20Standard => mapping(IERC20Standard => uint24))
        public collateralToStableCoinFee;

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
        uint24 _borrower,
        uint24 _platform,
        uint24 _lender
    ) public onlyOperator {
        earnLender = _lender;
        earnBorrower = _borrower;
        earnPlatform = _platform;
    }

    function getEarnShare() public view returns (uint24, uint24, uint24) {
        return (earnLender, earnBorrower, earnPlatform);
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
        uint24 _platform,
        uint24 _liquidator,
        uint24 _lender
    ) public onlyOperator {
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
    ) public onlyOperator {
        swapRouter = _swapRouter;
        factory = _factory;
        quoter = _quoter;
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

    function setCollateralToStableFee(
        IERC20Standard _collateral,
        IERC20Standard _stable,
        uint24 _fee
    ) public onlyOperator {
        collateralToStableCoinFee[_collateral][_stable] = _fee;
    }

    // Modifier to check token allowance
    // modifier checkTokenAllowance(IERC20Standard _token, uint _amount) {
    //     require(
    //         _token.allowance(msg.sender, address(this)) >= _amount,
    //         "Error"
    //     );
    //     _;
    // }
}
