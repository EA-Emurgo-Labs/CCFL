// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./ICCFLLoan.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./helpers/Errors.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLLoan is ICCFLLoan, Initializable {
    address public owner;

    // aave config
    IPoolAddressesProvider public aaveAddressProvider;
    IERC20Standard public aToken;
    bool public isStakeAave;

    // uniswap config
    ISwapRouter public swapRouter;
    uint24 public constant feeTier = 3000;
    IUniswapV3Factory public factory;

    // collateral
    uint public liquidationThreshold;
    uint public LTV;
    uint public collateralAmount;
    IERC20Standard public collateralToken;

    // default loan
    DataTypes.Loan public initLoan;

    // chainlink
    AggregatorV3Interface public priceFeed;
    AggregatorV3Interface public pricePoolFeed;

    // ccfl sc
    address public ccfl;
    address public platform;
    IWETH public wETH;

    // earn AAVE /10000
    uint public earnPlatform;
    uint public earnBorrower;
    uint public earnLender;

    modifier onlyOwner() {
        require(msg.sender == owner, Errors.ONLY_THE_OWNER);
        _;
    }

    constructor() {}

    function setCCFL(address _ccfl) public onlyOwner {
        ccfl = _ccfl;
    }

    function setSwapRouter(
        ISwapRouter _swapRouter,
        IUniswapV3Factory _factory
    ) public onlyOwner {
        swapRouter = _swapRouter;
        factory = _factory;
    }

    function initialize(
        DataTypes.Loan memory _loan,
        IERC20Standard _collateralToken,
        IPoolAddressesProvider _aaveAddressProvider,
        IERC20Standard _aToken,
        uint _ltv,
        uint _threshold,
        AggregatorV3Interface _priceFeed,
        AggregatorV3Interface _pricePoolFeed,
        address _platform,
        IWETH _iWETH
    ) external initializer {
        owner = msg.sender;
        initLoan = _loan;
        collateralToken = _collateralToken;
        aaveAddressProvider = _aaveAddressProvider;
        LTV = _ltv;
        liquidationThreshold = _threshold;
        aToken = _aToken;
        priceFeed = _priceFeed;
        pricePoolFeed = _pricePoolFeed;
        platform = _platform;
        wETH = _iWETH;
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

    function supplyLiquidity() public onlyOwner {
        IERC20Standard asset = collateralToken;
        uint amount = asset.balanceOf(address(this));
        require(amount > 0, Errors.DO_NOT_HAVE_ASSETS);
        address onBehalfOf = address(this);
        uint16 referralCode = 0;
        IPool aavePool = IPool(aaveAddressProvider.getPool());
        asset.approve(address(aavePool), amount);
        aavePool.supply(address(asset), amount, onBehalfOf, referralCode);
        emit LiquiditySupplied(onBehalfOf, address(asset), amount);
        isStakeAave = true;
    }

    function setPaid() public onlyOwner {
        initLoan.isPaid = true;
    }

    function withdrawLiquidity() public onlyOwner returns (uint256) {
        uint amount = aToken.balanceOf(address(this));
        if (amount > 0) {
            IPool aavePool = IPool(aaveAddressProvider.getPool());
            aToken.approve(address(aavePool), amount);
            aavePool.withdraw(address(aToken), amount, address(this));
            emit LiquidityWithdrawn(address(this), address(aToken), amount);
        }

        isStakeAave = false;
        // share 30% for platform;
        uint currentCollateral = collateralToken.balanceOf(address(this));
        if (currentCollateral - collateralAmount > 0) {
            uint earn = ((currentCollateral - collateralAmount) *
                (earnBorrower)) / 10000;
            uint outUSD = swapEarnForUSD(
                (currentCollateral - collateralAmount) - earn,
                initLoan.stableCoin,
                collateralToken
            );
            initLoan.stableCoin.transfer(
                platform,
                (outUSD * (earnPlatform)) / (earnLender + earnPlatform)
            );
            initLoan.stableCoin.approve(
                ccfl,
                outUSD - (outUSD * (earnPlatform)) / (earnLender + earnPlatform)
            );
            return
                outUSD -
                (outUSD * (earnPlatform)) /
                (earnLender + earnPlatform);
        }
        return 0;
    }

    function getUserAccountData(
        address user
    )
        public
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        IPool aavePool = IPool(aaveAddressProvider.getPool());
        return aavePool.getUserAccountData(user);
    }

    function getLatestPrice(
        IERC20Standard _coin,
        bool isPool
    ) public view returns (uint) {
        if (isPool == false) {
            (
                uint80 roundID,
                int256 price,
                uint256 startedAt,
                uint256 timeStamp,
                uint80 answeredInRound
            ) = priceFeed.latestRoundData();
            // for LINK / USD price is scaled up by 10 ** 8
            return uint(price);
        } else {
            (
                uint80 roundID,
                int256 price,
                uint256 startedAt,
                uint256 timeStamp,
                uint80 answeredInRound
            ) = pricePoolFeed.latestRoundData();
            // for LINK / USD price is scaled up by 10 ** 8
            return uint(price);
        }
    }

    // 5. Liquidation
    // Good > 100, bad < 100
    function getHealthFactor(
        uint currentDebt,
        uint addCollateral
    ) public view returns (uint) {
        uint stableCoinPrice = getLatestPrice(initLoan.stableCoin, true);
        uint totalCollaterals = 0;

        uint collateralAmountNew = collateralAmount + addCollateral;

        IERC20Standard token = collateralToken;
        if (collateralAmountNew > 0) {
            uint collateralPrice = getLatestPrice(token, false);
            totalCollaterals +=
                (collateralAmountNew * collateralPrice * liquidationThreshold) /
                10000 /
                (10 ** token.decimals());
        }

        uint totalLoan = (currentDebt * stableCoinPrice) /
            (10 ** initLoan.stableCoin.decimals());

        uint healthFactor = (totalCollaterals * 100) / totalLoan;
        return healthFactor;
    }

    /// @notice swapExactOutputSingle swaps a minimum possible amount of DAI for a fixed amount of WETH.
    /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
    /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
    /// @param amountOut The exact amount of WETH9 to receive from the swap.
    /// @param amountInMaximum The amount of DAI we are willing to spend to receive the specified amount of WETH9.
    /// @return amountIn The amount of DAI actually spent in the swap.
    function swapTokenForUSD(
        uint256 amountOut,
        uint256 amountInMaximum,
        IERC20Standard stableCoin,
        IERC20Standard tokenAddress
    ) internal returns (uint256 amountIn) {
        // Approve the router to spend the specifed `amountInMaximum` of DAI.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        TransferHelper.safeApprove(
            address(tokenAddress),
            address(swapRouter),
            amountInMaximum
        );

        address pool = factory.getPool(
            address(tokenAddress),
            address(stableCoin),
            feeTier
        );

        uint24 fee = IUniswapV3Pool(pool).fee();

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: address(tokenAddress),
                tokenOut: address(stableCoin),
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(
                address(tokenAddress),
                address(swapRouter),
                0
            );
        }
    }

    function swapEarnForUSD(
        uint256 amountIn,
        IERC20Standard stableCoin,
        IERC20Standard tokenAddress
    ) internal returns (uint256 amountOut) {
        // Approve the router to spend the specifed `amountInMaximum` of DAI.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        TransferHelper.safeApprove(
            address(tokenAddress),
            address(swapRouter),
            amountIn
        );

        address pool = factory.getPool(
            address(tokenAddress),
            address(stableCoin),
            feeTier
        );

        uint24 fee = IUniswapV3Pool(pool).fee();

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(tokenAddress),
                tokenOut: address(stableCoin),
                fee: fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountOut = swapRouter.exactInputSingle(params);
    }

    function liquidate(
        uint _currentDebt,
        uint _percent
    ) public onlyOwner returns (uint256) {
        require(
            getHealthFactor(_currentDebt, 0) < 100,
            Errors.CAN_NOT_LIQUIDATE
        );
        // get all collateral from aave
        uint256 earnLenderBalance = 0;
        if (isStakeAave) earnLenderBalance = withdrawLiquidity();

        IERC20Standard token = collateralToken;

        swapTokenForUSD(
            (_currentDebt * (10000 + _percent)) / 10000,
            collateralToken.balanceOf(address(this)),
            initLoan.stableCoin,
            token
        );

        initLoan.isLiquidated = true;

        // close this loan
        initLoan.stableCoin.approve(
            ccfl,
            (_currentDebt * (10000 + _percent)) / 10000
        );

        return earnLenderBalance;
    }

    function updateCollateral(uint amount) external onlyOwner {
        collateralAmount += amount;
    }

    function closeLoan() public returns (uint256) {
        initLoan.isClosed = true;
        if (isStakeAave) return withdrawLiquidity();
        return 0;
    }

    function withdrawAllCollateral(
        address _receiver,
        bool _isETH
    ) public onlyOwner {
        require(
            initLoan.isClosed == true && initLoan.isFinalty == false,
            Errors.LOAN_IS_NOT_CLOSED_OR_FINALTY
        );
        if (_isETH) {
            wETH.withdraw(collateralToken.balanceOf(address(this)));
            payable(_receiver).transfer(
                collateralToken.balanceOf(address(this))
            );
        } else {
            collateralToken.transfer(
                _receiver,
                collateralToken.balanceOf(address(this))
            );
        }
        initLoan.isFinalty = true;
    }

    function getLoanInfo() public view returns (DataTypes.Loan memory) {
        return initLoan;
    }

    function getYieldEarned() public view returns (uint) {
        uint current = aToken.balanceOf(address(this));
        uint earned = current - collateralAmount;
        return (earned * earnBorrower) / 10000;
    }

    function getIsYeild() public view returns (bool) {
        return isStakeAave;
    }

    function getCollateralAmount() public view returns (uint) {
        return collateralAmount;
    }

    function getCollateralToken() public view returns (IERC20Standard) {
        return collateralToken;
    }

    receive() external payable {}
}
