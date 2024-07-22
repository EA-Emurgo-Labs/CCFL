// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "./ICCFLLoan.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

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
    // collateral
    uint public liquidationThreshold;
    uint public LTV;
    uint public collateralAmount;
    IERC20Standard public collateralToken;

    // default loan
    Loan public initLoan;

    // chainlink
    AggregatorV3Interface public priceFeed;
    AggregatorV3Interface public pricePoolFeed;

    // ccfl sc
    address ccfl;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    constructor() {}

    function setCCFL(address _ccfl) public {
        ccfl = _ccfl;
    }

    function initialize(
        Loan memory _loan,
        IERC20Standard _collateralToken,
        IPoolAddressesProvider _aaveAddressProvider,
        IERC20Standard _aToken,
        uint _ltv,
        uint _threshold,
        AggregatorV3Interface _priceFeed,
        AggregatorV3Interface _pricePoolFeed,
        ISwapRouter _swapRouter
    ) external initializer {
        owner = msg.sender;
        initLoan = _loan;
        collateralToken = _collateralToken;
        owner = payable(msg.sender);

        aaveAddressProvider = _aaveAddressProvider;
        LTV = _ltv;
        liquidationThreshold = _threshold;
        aToken = _aToken;
        priceFeed = _priceFeed;
        pricePoolFeed = _pricePoolFeed;
        swapRouter = _swapRouter;
    }

    function supplyLiquidity() public onlyOwner {
        IERC20Standard asset = collateralToken;
        uint amount = asset.balanceOf(address(this));
        address onBehalfOf = address(this);
        uint16 referralCode = 0;
        IPool aavePool = IPool(aaveAddressProvider.getPool());
        aavePool.supply(address(asset), amount, onBehalfOf, referralCode);
        emit LiquiditySupplied(onBehalfOf, address(asset), amount);
        isStakeAave = true;
    }

    function withdrawLiquidity() public {
        uint amount = aToken.balanceOf(address(this));
        IPool aavePool = IPool(aaveAddressProvider.getPool());
        aavePool.withdraw(address(aToken), amount, address(this));
        emit LiquidityWithdrawn(address(this), address(aToken), amount);
        isStakeAave = false;
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
    function getHealthFactor() public view returns (uint) {
        uint stableCoinPrice = getLatestPrice(initLoan.stableCoin, true);
        uint totalCollaterals = 0;

        IERC20Standard token = collateralToken;
        if (collateralAmount > 0) {
            uint collateralPrice = getLatestPrice(token, false);
            totalCollaterals +=
                (collateralAmount * collateralPrice * liquidationThreshold) /
                10000 /
                (10 ** token.decimals());
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

    function liquidate() public {
        require(getHealthFactor() < 100, "Can not liquidate");
        // get all collateral from aave
        if (isStakeAave) withdrawLiquidity();

        IERC20Standard token = collateralToken;

        swapTokenForUSD(
            initLoan.amount,
            collateralAmount,
            initLoan.stableCoin,
            token
        );

        // close this loan
        initLoan.stableCoin.approve(ccfl, initLoan.amount);
    }

    function updateCollateral(uint amount) external {
        collateralAmount += amount;
    }

    function closeLoan(address _receiver) public {
        initLoan.isClosed = true;
        collateralToken.transfer(_receiver, collateralAmount);
        collateralAmount = 0;
    }

    function getLoanInfo() public view returns (Loan memory) {
        return initLoan;
    }

    receive() external payable {}
}
