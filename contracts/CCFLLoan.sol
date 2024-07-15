// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "./ICCFLLoan.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./ICCFLPool.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLLoan is ICCFLLoan, Initializable {
    address public owner;
    IPoolAddressesProvider[] public aaveAddressProviders;
    IPool[] public aavePools;
    IERC20[] public aTokens;
    ICCFLLoan public ccflLoan;
    IPool public aavePool;
    IUniswapV3Pool uniswapPool;
    ISwapRouter public swapRouter;
    uint24 public constant feeTier = 3000;
    uint public liquidationThreshold;
    uint public LTV;
    uint public uniswapFee;
    mapping(IERC20 => uint) public collaterals;
    bool public isStakeAave;
    Loan public initLoan;
    IERC20[] public collateralTokens;
    mapping(IERC20 => AggregatorV3Interface) public priceFeeds;
    ICCFLPool public ccflPool;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    constructor() {}

    function initialize(
        Loan memory _loan,
        IERC20[] memory _collateralTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        IERC20[] memory _aTokens
    ) external initializer {
        owner = msg.sender;
        initLoan = _loan;
        collateralTokens = _collateralTokens;
        owner = payable(msg.sender);
        aaveAddressProviders = _aaveAddressProviders;
        for (uint i = 0; i < aaveAddressProviders.length; i++) {
            aavePools.push(IPool(aaveAddressProviders[i].getPool()));
        }
        aTokens = _aTokens;
    }

    function supplyLiquidity() public onlyOwner {
        for (uint i; i < collateralTokens.length; i++) {
            IERC20 asset = collateralTokens[i];
            uint amount = asset.balanceOf(address(this));
            address onBehalfOf = address(this);
            uint16 referralCode = 0;
            aavePools[i].supply(
                address(asset),
                amount,
                onBehalfOf,
                referralCode
            );
            emit LiquiditySupplied(onBehalfOf, address(asset), amount);
        }
    }

    function withdrawLiquidity() public {
        for (uint i; i < collateralTokens.length; i++) {
            uint amount = aTokens[i].balanceOf(address(this));
            uint256 withdrawn = aavePools[i].withdraw(
                address(aTokens[i]),
                amount,
                address(this)
            );
            emit LiquidityWithdrawn(address(this), address(aTokens[i]), amount);
        }
    }

    // function getUserAccountData(
    //     address user
    // )
    //     public
    //     view
    //     returns (
    //         uint256 totalCollateralBase,
    //         uint256 totalDebtBase,
    //         uint256 availableBorrowsBase,
    //         uint256 currentLiquidationThreshold,
    //         uint256 ltv,
    //         uint256 healthFactor
    //     )
    // {
    //     return POOL.getUserAccountData(user);
    // }

    function getLatestPrice(IERC20 _stableCoin) public view returns (uint) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeeds[_stableCoin].latestRoundData();
        // for LINK / USD price is scaled up by 10 ** 8
        return uint(price);
    }

    // 5. Liquidation
    // Good > 100, bad < 100
    function getHealthFactor() public view returns (uint) {
        uint stableCoinPrice = getLatestPrice(initLoan.stableCoin);
        uint totalCollaterals = 0;
        for (uint i; i < collateralTokens.length; i++) {
            uint collateralPrice = getLatestPrice(collateralTokens[i]);
            totalCollaterals +=
                collaterals[collateralTokens[i]] *
                collateralPrice;
        }
        uint healthFactor = (((totalCollaterals * liquidationThreshold) /
            10000) * 100) /
            initLoan.amount /
            stableCoinPrice;
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
        IERC20 stableCoin,
        IERC20 tokenAddress
    ) public returns (uint256 amountIn) {
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
        // get all collateral from aave
        if (isStakeAave) withdrawLiquidity();

        // TODO
        // sell collateral on uniswap
        // swapTokenForUSD(initLoan.amount, collateral, _stableCoin);

        // close this loan
        initLoan.stableCoin.approve(address(ccflPool), initLoan.amount);
        ccflPool.closeLoan(initLoan.loanId, initLoan.amount);
    }

    function liquidateMonthlyPayment(
        uint _loanId,
        address _user,
        IERC20 _stableCoin
    ) external {
        require(getHealthFactor() < 100, "Can not liquidate");
        // get all collateral from aave
        if (isStakeAave) withdrawLiquidity();

        // TODO
        // sell collateral on uniswap
        // swapTokenForUSD(initLoan.amount, collateral, _stableCoin);

        // close this loan
        initLoan.stableCoin.approve(address(ccflPool), initLoan.amount);
        ccflPool.closeLoan(initLoan.loanId, initLoan.amount);
    }

    receive() external payable {}
}
