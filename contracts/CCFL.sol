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
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL {
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
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;
    IUniswapV3Pool uniswapPool;
    ISwapRouter public immutable swapRouter;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint24 public constant feeTier = 3000;
    IERC20 public aToken;

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

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    event Withdraw(address borrower, uint amount, uint when);

    constructor(
        IERC20 _usdcAddress,
        IERC20 _tokenAddress,
        AggregatorV3Interface _aggregator,
        ICCFLPool _ccflPool,
        ISwapRouter _swapRouter,
        IPoolAddressesProvider _poolAddressesProvider,
        ICCFLStake _ccflStake,
        IERC20 _aToken
    ) {
        tokenAddress = _tokenAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        // LINK / USD
        priceFeed = _aggregator;
        ccflPool = _ccflPool;
        ADDRESSES_PROVIDER = _poolAddressesProvider;
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        swapRouter = ISwapRouter(_swapRouter);
        rateLoan = 1200;
        ccflStake = _ccflStake;
        aToken = _aToken;
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
        POOL.supply(_token, _amount, _onBehalfOf, referralCode);
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
    function createLoan(uint _amount, uint _days) public {
        Loan memory loan;
        uint time = _days * (1 days);
        address _borrower = msg.sender;
        loan.borrower = _borrower;
        loan.deadline = block.timestamp + time;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.monthlyPayment = (_amount * rateLoan) / 10000 / 12;
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
        for (uint i = 0; i < loans[msg.sender].length; i++) {
            if (loans[msg.sender][i].loanId == _loanId) {
                require(
                    _amount == loans[msg.sender][i].monthlyPayment,
                    "Wrong monthly payment"
                );
                break;
            }
        }
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
        usdcAddress.approve(address(ccflPool), _amount);
        ccflPool.monthlyPaymentUsdcTokens(_loanId, _amount);
    }

    // 4. close loan
    function closeLoan(uint _loanId, uint _amount) external {
        for (uint i = 0; i < loans[msg.sender].length; i++) {
            if (loans[msg.sender][i].loanId == _loanId) {
                require(
                    _amount == loans[msg.sender][i].amount,
                    "Wrong loan amount"
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
    function getHealthFactor(address user) public view returns (uint) {
        uint tokenPrice = getLatestPrice();
        uint collateralUser = collateral[user];
        uint stake = stakeAave[user];
        uint healthFactor = (tokenPrice * (collateralUser + stake) * 8) /
            10 /
            totalLoans[user] /
            1e6;
        return healthFactor;
    }

    function swapWETHForDAI(
        uint256 amountIn
    ) public returns (uint256 amountOut) {
        // Transfer the specified amount of WETH9 to this contract.
        TransferHelper.safeTransferFrom(
            WETH9,
            msg.sender,
            address(this),
            amountIn
        );
        // Approve the router to spend WETH9.
        TransferHelper.safeApprove(WETH9, address(swapRouter), amountIn);
        // Note: To use this example, you should explicitly set slippage limits, omitting for simplicity
        uint256 minOut = /* Calculate min output */ 0;
        uint160 priceLimit = /* Calculate price limit */ 0;
        // Create the params that will be used to execute the swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH9,
                tokenOut: DAI,
                fee: feeTier,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: priceLimit
            });
        // The call to `exactInputSingle` executes the swap.
        amountOut = swapRouter.exactInputSingle(params);
    }

    function liquidate(address _user) external {
        require(getHealthFactor(_user) < 100, "Can not liquidate");
        // get collateral from aave
        ICCFLStake staker = ICCFLStake(aaveStakeAddresses[_user]);
        uint256 balance = aToken.balanceOf(address(staker));
        staker.withdrawLiquidity(balance, address(this));
        uint amountShouldSell = ((totalLoans[_user]) * 105) /
            getLatestPrice() /
            100;

        // sell collateral on uniswap
        swapWETHForDAI(amountShouldSell);
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
            collateral[_user] * getLatestPrice() <
            loans[_user][indexLoan].amount
        ) {
            uint balance = ((loans[_user][indexLoan].amount -
                collateral[_user] *
                getLatestPrice()) * 105) /
                getLatestPrice() /
                100;
            ICCFLStake staker = ICCFLStake(aaveStakeAddresses[_user]);
            uint aaveWithdraw = staker.withdrawLiquidity(
                balance,
                address(this)
            );
            collateral[_user] += aaveWithdraw;
        }

        // sell collateral on uniswap
        swapWETHForDAI(collateral[_user]);
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
        emit Withdraw(msg.sender, _amount, block.timestamp);
        tokenAddress.transfer(msg.sender, _amount);
    }

    function approveToken(
        IERC20 _token,
        uint256 _amount,
        address _poolContractAddress
    ) external returns (bool) {
        return _token.approve(_poolContractAddress, _amount);
    }

    function allowanceToken(
        IERC20 _token,
        address _poolContractAddress
    ) external view returns (uint256) {
        return _token.allowance(address(this), _poolContractAddress);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    receive() external payable {}
}
