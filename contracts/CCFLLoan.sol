// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "./ICCFLLoan.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLLoan is ICCFLLoan, Initializable {
    address public owner;
    // aave config
    mapping(IERC20Standard => IPoolAddressesProvider)
        public aaveAddressProviders;
    mapping(IERC20Standard => IERC20Standard) public aTokens;
    bool public isStakeAave;
    // uniswap config
    IUniswapV3Pool uniswapPool;
    ISwapRouter public swapRouter;
    uint24 public constant feeTier = 3000;
    // collateral
    mapping(IERC20Standard => uint) public liquidationThreshold;
    mapping(IERC20Standard => uint) public LTV;
    mapping(IERC20Standard => uint) public collaterals;
    IERC20Standard[] public collateralTokens;

    // default loan
    Loan public initLoan;

    // chainlink
    mapping(IERC20Standard => AggregatorV3Interface) public priceFeeds;

    // ccfl pool
    ICCFLPool ccflPool;
    AggregatorV3Interface pricePoolFeeds;

    // ccfl sc
    address ccfl;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    constructor() {}

    function setCCFLPool(ICCFLPool _pool, address _ccfl) public {
        ccflPool = _pool;
        ccfl = _ccfl;
    }

    function initialize(
        Loan memory _loan,
        IERC20Standard[] memory _collateralTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        IERC20Standard[] memory _aTokens,
        uint[] memory _ltvs,
        uint[] memory _thresholds,
        AggregatorV3Interface[] memory _priceFeeds,
        AggregatorV3Interface _pricePoolFeeds
    ) external initializer {
        owner = msg.sender;
        initLoan = _loan;
        collateralTokens = _collateralTokens;
        owner = payable(msg.sender);
        for (uint i = 0; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            aaveAddressProviders[token] = _aaveAddressProviders[i];
            LTV[token] = _ltvs[i];
            liquidationThreshold[token] = _thresholds[i];
            aTokens[token] = _aTokens[i];
            priceFeeds[token] = _priceFeeds[i];
        }
        pricePoolFeeds = _pricePoolFeeds;
    }

    function supplyLiquidity() public onlyOwner {
        for (uint i; i < collateralTokens.length; i++) {
            IERC20Standard asset = collateralTokens[i];
            uint amount = asset.balanceOf(address(this));
            address onBehalfOf = address(this);
            uint16 referralCode = 0;
            IPool aavePool = IPool(
                aaveAddressProviders[collateralTokens[i]].getPool()
            );
            aavePool.supply(address(asset), amount, onBehalfOf, referralCode);
            emit LiquiditySupplied(onBehalfOf, address(asset), amount);
        }
        isStakeAave = true;
    }

    function withdrawLiquidity() public {
        for (uint i; i < collateralTokens.length; i++) {
            uint amount = aTokens[collateralTokens[i]].balanceOf(address(this));
            IPool aavePool = IPool(
                aaveAddressProviders[collateralTokens[i]].getPool()
            );
            aavePool.withdraw(
                address(aTokens[collateralTokens[i]]),
                amount,
                address(this)
            );
            emit LiquidityWithdrawn(
                address(this),
                address(aTokens[collateralTokens[i]]),
                amount
            );
        }
        isStakeAave = false;
    }

    function getUserAccountData(
        address user,
        IERC20Standard collateral
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
        IPool aavePool = IPool(aaveAddressProviders[collateral].getPool());
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
            ) = priceFeeds[_coin].latestRoundData();
            // for LINK / USD price is scaled up by 10 ** 8
            return uint(price);
        } else {
            (
                uint80 roundID,
                int256 price,
                uint256 startedAt,
                uint256 timeStamp,
                uint80 answeredInRound
            ) = pricePoolFeeds.latestRoundData();
            // for LINK / USD price is scaled up by 10 ** 8
            return uint(price);
        }
    }

    // 5. Liquidation
    // Good > 100, bad < 100
    function getHealthFactor() public view returns (uint) {
        uint stableCoinPrice = getLatestPrice(initLoan.stableCoin, true);
        uint totalCollaterals = 0;
        for (uint i; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            if (collaterals[token] > 0) {
                uint collateralPrice = getLatestPrice(token, false);
                totalCollaterals +=
                    (collaterals[token] *
                        collateralPrice *
                        liquidationThreshold[token]) /
                    10000 /
                    (10 ** token.decimals());
            }
        }
        uint totalLoan = (initLoan.amount * stableCoinPrice) /
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

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: address(tokenAddress),
                tokenOut: address(stableCoin),
                fee: feeTier,
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

    function liquidate() external {
        require(getHealthFactor() < 100, "Can not liquidate");
        liquidateStep();
    }

    function liquidateStep() internal {
        // get all collateral from aave
        if (isStakeAave) withdrawLiquidity();
        // calculate ratio
        uint totalCollaterals = 0;
        for (uint i; i < collateralTokens.length; i++) {
            IERC20Standard token = collateralTokens[i];
            uint collateralPrice = getLatestPrice(token, false);
            totalCollaterals +=
                (collaterals[token] * collateralPrice) /
                (10 ** token.decimals());
        }
        uint totalSell = 0;
        for (uint i; i < collateralTokens.length; i++) {
            if (i < collateralTokens.length - 1) {
                swapTokenForUSD(
                    (initLoan.amount *
                        collaterals[collateralTokens[i]] *
                        getLatestPrice(collateralTokens[i], false)) /
                        totalCollaterals,
                    collaterals[collateralTokens[i]],
                    initLoan.stableCoin,
                    collateralTokens[i]
                );
                totalSell +=
                    (initLoan.amount *
                        collaterals[collateralTokens[i]] *
                        getLatestPrice(collateralTokens[i], false)) /
                    totalCollaterals;
            } else {
                swapTokenForUSD(
                    initLoan.amount - totalSell,
                    collaterals[collateralTokens[i]],
                    initLoan.stableCoin,
                    collateralTokens[i]
                );
            }
        }

        // close this loan
        initLoan.stableCoin.approve(address(ccflPool), initLoan.amount);
        ccflPool.closeLoan(initLoan.loanId, initLoan.amount);
    }

    function updateCollateral(IERC20Standard _token, uint amount) external {
        collaterals[_token] += amount;
    }

    function liquidateMonthlyPayment() external {
        require(
            initLoan.monthlyDeadline + (7 days) < block.timestamp,
            "Can not liquidate"
        );
        liquidateStep();
    }

    function monthlyPayment(uint _amount) external {
        require(
            initLoan.monthlyPayment <= _amount,
            "monthly payment does not enough"
        );
        initLoan.monthlyDeadline += 30 * (1 days);
    }

    function closeLoan()
        public
        returns (
            IERC20Standard[] memory _collateralTokens,
            uint[] memory _amount
        )
    {
        require(
            initLoan.deadline <= block.timestamp,
            "Not catch loan deadline"
        );
        initLoan.isClosed = true;
        _amount = new uint[](collateralTokens.length);

        _collateralTokens = collateralTokens;

        // return collateral to ccfl
        for (uint i; i < collateralTokens.length; i++) {
            _amount[i] = (collaterals[collateralTokens[i]]);
            if (collaterals[collateralTokens[i]] > 0) {
                collateralTokens[i].transfer(
                    msg.sender,
                    collaterals[collateralTokens[i]]
                );
                collaterals[collateralTokens[i]] = 0;
            }
        }
    }

    receive() external payable {}
}
