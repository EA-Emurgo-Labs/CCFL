// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLPool.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLStake.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

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

struct Loan {
    uint loanId;
    address borrower;
    bool isPaid;
    uint amount;
    uint deadline;
    uint monthlyPayment;
    uint rateLoan;
    uint monthPaid;
    uint amountMonth;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL is Initializable {
    using Clones for address;
    uint public rateLoan;
    address payable public owner;
    IERC20 public usdcAddress;
    IERC20 public tokenAddress;
    AggregatorV3Interface public priceFeed;
    mapping(address => Loan[]) public loans;
    mapping(address => uint) public totalLoans;
    mapping(address => uint) public collateral;
    mapping(address => uint) public stakeAave;
    uint public loandIds;
    ICCFLPool public ccflPool;
    ICCFLStake public ccflStake;
    mapping(address => address) public aaveStakeAddresses;
    IPoolAddressesProvider public ADDRESSES_PROVIDER;
    IPool public aavePool;
    IUniswapV3Pool uniswapPool;
    ISwapRouter public swapRouter;
    uint24 public constant feeTier = 3000;
    IERC20 public aToken;
    uint public liquidationThreshold;
    uint public LTV;
    uint public uniswapFee;

    event LiquiditySupplied(
        address indexed onBehalfOf,
        address indexed _token,
        uint256 indexed _amount
    );
    event LiquidityWithdrawn(
        address indexed to,
        address indexed _token,
        uint256 indexed _amount
    );

    // modifier onlyOwner() {
    //     require(msg.sender == owner, "only the owner");
    //     _;
    // }

    event Withdraw(address borrower, uint amount, uint when);

    function initialize(
        IERC20 _usdcAddress,
        IERC20 _tokenAddress,
        AggregatorV3Interface _aggregator,
        ICCFLPool _ccflPool,
        ISwapRouter _swapRouter,
        IPoolAddressesProvider _poolAddressesProvider,
        ICCFLStake _ccflStake,
        IERC20 _aToken
    ) external initializer {
        tokenAddress = _tokenAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        // LINK / USD
        priceFeed = _aggregator;
        ccflPool = _ccflPool;
        rateLoan = 1200;
        ccflStake = _ccflStake;
        aToken = _aToken;
        liquidationThreshold = 8000;
        uniswapFee = 2;
        LTV = 6000;
        ADDRESSES_PROVIDER = _poolAddressesProvider;
        aavePool = IPool(ADDRESSES_PROVIDER.getPool());
        swapRouter = ISwapRouter(_swapRouter);
    }

    // create loan
    // 1. deposit
    // Modifier to check token allowance
    modifier checkTokenAllowance(IERC20 _token, uint _amount) {
        require(
            _token.allowance(msg.sender, address(this)) >= _amount,
            "Error"
        );
        _;
    }

    // 1.1 add liquidity aave
    function supplyLiquidity(
        address _token,
        uint256 _amount,
        address _onBehalfOf
    ) internal {
        uint16 referralCode = 0;
        aavePool.supply(_token, _amount, _onBehalfOf, referralCode);
        emit LiquiditySupplied(_onBehalfOf, _token, _amount);
    }

    // 2.1 withdrawn all liquidity aave
    function withdrawLiquidity() public {
        require(
            aaveStakeAddresses[msg.sender] != address(0),
            "Do not have satking acc"
        );
        ICCFLStake staker = ICCFLStake(aaveStakeAddresses[msg.sender]);
        uint256 totalBalance = aToken.balanceOf(aaveStakeAddresses[msg.sender]);
        uint aaveWithdraw = staker.withdrawLiquidity(
            totalBalance,
            address(this)
        );
        collateral[msg.sender] += aaveWithdraw;
    }

    function depositCollateral(
        uint _amount,
        uint _percent
    ) public checkTokenAllowance(tokenAddress, _amount) {
        collateral[msg.sender] += (_amount * _percent) / 100;
        if (_amount - (_amount * _percent) / 100 > 0) {
            stakeAave[msg.sender] += _amount - (_amount * _percent) / 100;
            if (aaveStakeAddresses[msg.sender] == address(0)) {
                // clone an address to save atoken
                address aaveStake = address(ccflStake).clone();
                ICCFLStake cloneSC = ICCFLStake(aaveStake);
                cloneSC.initialize(address(this));
                aaveStakeAddresses[msg.sender] = aaveStake;
            }

            supplyLiquidity(
                address(tokenAddress),
                _amount - (_amount * _percent) / 100,
                aaveStakeAddresses[msg.sender]
            );
        }
        tokenAddress.transferFrom(msg.sender, address(this), _amount);
    }

    // 2. create loan
    function createLoan(uint _amount, uint _months) public {
        require(
            (collateral[msg.sender] * getLatestPrice() * LTV) / 1e8 / 10000 >
                totalLoans[msg.sender] + _amount,
            "Don't have enough collateral"
        );
        Loan memory loan;
        uint time = _months * 30 * (1 days);
        address _borrower = msg.sender;
        loan.borrower = _borrower;
        loan.deadline = block.timestamp + time;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.monthlyPayment = (_amount * rateLoan) / 10000 / 12;
        loan.amountMonth = _months;
        loan.monthPaid = 0;
        loan.rateLoan = rateLoan;
        loans[_borrower].push(loan);
        loandIds++;
        ccflPool.lockLoan(
            loan.loanId,
            loan.amount,
            loan.monthlyPayment,
            _borrower
        );
        totalLoans[_borrower] += _amount;
    }

    // 3. Monthly payment
    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint amount) {
        require(
            usdcAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function depositMonthlyPayment(
        uint _loanId,
        uint _amount
    ) public checkUsdcAllowance(_amount) {
        uint index = 0;
        for (uint i = 0; i < loans[msg.sender].length; i++) {
            if (loans[msg.sender][i].loanId == _loanId) {
                require(
                    _amount == loans[msg.sender][i].monthlyPayment,
                    "Wrong monthly payment"
                );
                index = i;
                break;
            }
        }
        loans[msg.sender][index].monthPaid += 1;
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
        usdcAddress.approve(address(ccflPool), _amount);
        ccflPool.depositMonthlyPayment(_loanId, _amount);
    }

    // 4. close loan
    function closeLoan(uint _loanId, uint _amount) external {
        for (uint i = 0; i < loans[msg.sender].length; i++) {
            if (loans[msg.sender][i].loanId == _loanId) {
                require(
                    _amount == loans[msg.sender][i].amount &&
                        loans[msg.sender][i].monthPaid ==
                        loans[msg.sender][i].amountMonth,
                    "Wrong loan amount or not finish monthly payment"
                );
                break;
            }
        }

        usdcAddress.transferFrom(msg.sender, address(this), _amount);
        usdcAddress.approve(address(ccflPool), _amount);
        ccflPool.closeLoan(_loanId, _amount);
    }

    function getLatestPrice() public view returns (uint) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // for LINK / USD price is scaled up by 10 ** 8
        return uint(price);
    }

    // 5. Liquidation
    // Good > 100, bad < 100
    function getHealthFactor(address user) public view returns (uint) {
        uint tokenPrice = getLatestPrice();
        uint collateralUser = collateral[user];
        uint stake = stakeAave[user];
        if (totalLoans[user] == 0) {
            // no debt always ok
            return 10000;
        }
        uint healthFactor = ((tokenPrice *
            (collateralUser + stake) *
            liquidationThreshold) * 100) /
            10000 /
            totalLoans[user] /
            1e8;
        return healthFactor;
    }

    /// @notice swapExactOutputSingle swaps a minimum possible amount of DAI for a fixed amount of WETH.
    /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
    /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
    /// @param amountOut The exact amount of WETH9 to receive from the swap.
    /// @param amountInMaximum The amount of DAI we are willing to spend to receive the specified amount of WETH9.
    /// @return amountIn The amount of DAI actually spent in the swap.
    function swapTokenForUSDC(
        uint256 amountOut,
        uint256 amountInMaximum
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
                tokenOut: address(usdcAddress),
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

    function liquidate(address _user) external {
        require(getHealthFactor(_user) < 100, "Can not liquidate");
        // get collateral from aave
        ICCFLStake staker = ICCFLStake(aaveStakeAddresses[_user]);
        uint256 balance = aToken.balanceOf(address(staker));
        uint aaveWithdraw = staker.withdrawLiquidity(balance, address(this));
        collateral[_user] += aaveWithdraw;

        // sell collateral on uniswap
        swapTokenForUSDC(totalLoans[_user], collateral[_user]);
        // close all of loans
        for (uint i = 0; i < loans[_user].length; i++) {
            usdcAddress.approve(address(ccflPool), loans[_user][i].amount);
            ccflPool.closeLoan(loans[_user][i].loanId, loans[_user][i].amount);
        }
    }

    function liquidateMonthlyPayment(uint _loanId, address _user) external {
        // check collater enough
        uint indexLoan = 0;
        for (uint i = 0; i < loans[_user].length; i++) {
            if (loans[_user][i].loanId == _loanId) {
                indexLoan = i;
            }
        }
        // if not enough withdraw aave
        if (
            (collateral[_user] * getLatestPrice()) / 1e8 <
            loans[_user][indexLoan].amount
        ) {
            // buffer 2%
            uint balance = (((loans[_user][indexLoan].amount * 102) /
                100 -
                (collateral[_user] * getLatestPrice()) /
                1e8) * 1e8) / getLatestPrice();
            ICCFLStake staker = ICCFLStake(aaveStakeAddresses[_user]);
            uint aaveWithdraw = staker.withdrawLiquidity(
                balance,
                address(this)
            );
            collateral[_user] += aaveWithdraw;
        }

        // sell collateral on uniswap
        swapTokenForUSDC(loans[_user][indexLoan].amount, collateral[_user]);
        // close this loan
        usdcAddress.approve(address(ccflPool), loans[_user][indexLoan].amount);
        ccflPool.closeLoan(
            loans[_user][indexLoan].loanId,
            loans[_user][indexLoan].amount
        );
    }

    // .6 withdraw Collateral
    function withdrawCollateral(uint _amount) public {
        require(
            _amount <= collateral[msg.sender],
            "Do not have enough collateral"
        );
        collateral[msg.sender] -= _amount;
        require(
            getHealthFactor(msg.sender) > 100,
            "Do not have good health factor"
        );
        emit Withdraw(msg.sender, _amount, block.timestamp);
        tokenAddress.transfer(msg.sender, _amount);
    }

    function withdrawLoan() external {
        ccflPool.withdrawLoanByCCFL(msg.sender);
    }

    receive() external payable {}
}
