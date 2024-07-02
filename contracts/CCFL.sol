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
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL {
    using Clones for address;
    address payable public owner;
    IERC20 public usdcAddress;
    IERC20 public linkAddress;
    AggregatorV3Interface public linkPriceFeed;

    mapping(address => Loan[]) public loans;
    mapping(address => uint) public totalLoans;
    mapping(address => uint) public collateralLink;
    mapping(address => uint) public stakeAaveLink;
    uint public loandIds;
    AggregatorV3Interface internal priceFeed;
    ICCFLPool public ccflPool;
    IERC20 private link;
    ICCFLStake public ccflStake;
    mapping(address => address) public aaveStakeAddresses;
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;
    IUniswapV3Pool uniswapPool;
    ISwapRouter public immutable swapRouter;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint24 public constant feeTier = 3000;

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

    event Withdrawal(uint amount, uint when);

    constructor(
        IERC20 _usdcAddress,
        IERC20 _linkAddress,
        address _linkAggretor,
        ICCFLPool _ccflPool,
        ISwapRouter _swapRouter
    ) payable {
        linkAddress = _linkAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        // LINK / USD
        linkPriceFeed = AggregatorV3Interface(_linkAggretor);
        link = IERC20(linkAddress);
        ccflPool = _ccflPool;
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        swapRouter = _swapRouter;
    }

    // create loan
    // 1. deposit
    // Modifier to check token allowance
    modifier checkLinkAllowance(uint amount) {
        require(
            linkAddress.allowance(msg.sender, address(this)) >= amount,
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

    function depositCollateralLink(
        uint _amount,
        uint _percent
    ) public checkLinkAllowance(_amount) {
        collateralLink[msg.sender] += (_amount * _percent) / 100;
        stakeAaveLink[msg.sender] += _amount - (_amount * _percent) / 100;
        linkAddress.transferFrom(msg.sender, address(this), _amount);
        // clone an address to save atoken
        address aaveStake = address(ccflStake).clone();
        aaveStakeAddresses[msg.sender] = aaveStake;
        supplyLiquidity(
            address(linkAddress),
            _amount - (_amount * _percent) / 100,
            aaveStake
        );
    }

    // 2. create loan
    function createLoan(
        address _borrower,
        uint _amount,
        uint _deadline,
        uint _monthlyPayment
    ) public {
        Loan memory loan;
        loan.borrower = _borrower;
        loan.deadline = _deadline;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loan.monthlyPayment = _monthlyPayment;
        loans[_borrower].push(loan);
        loandIds++;
        ccflPool.lockLoan(loan.loanId, _amount, _monthlyPayment, _borrower);
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
        link.approve(address(ccflPool), _amount);
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
        link.approve(address(ccflPool), _amount);
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
        uint linkPrice = getLatestPrice();
        uint collateral = collateralLink[user];
        uint stake = stakeAaveLink[user];
        uint healthFactor = (linkPrice * (collateral + stake) * 8) /
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
        // TODO:
        // get collateral from aave
        ICCFLStake staker = ICCFLStake(aaveStakeAddresses[_user]);
        uint balance = staker.getBalance();
        uint reward = staker.withdrawLiquidity(balance, address(this));
        uint amountShouldSell = ((totalLoans[_user]) * 105) /
            getLatestPrice() /
            100;

        // sell collateral on uniswap
        swapWETHForDAI(amountShouldSell);
    }

    function liquidateMonthlyPayment(uint _loanId) external {}

    function approveLINK(
        uint256 _amount,
        address _poolContractAddress
    ) external returns (bool) {
        return link.approve(_poolContractAddress, _amount);
    }

    function allowanceLINK(
        address _poolContractAddress
    ) external view returns (uint256) {
        return link.allowance(address(this), _poolContractAddress);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    receive() external payable {}
}
