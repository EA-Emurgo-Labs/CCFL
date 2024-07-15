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
import "./ICCFLLoan.sol";
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

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL is Initializable {
    using Clones for address;
    uint public rateLoan;
    address payable public owner;
    IERC20 public tokenAddress;
    mapping(IERC20 => AggregatorV3Interface) public priceFeeds;
    mapping(address => Loan[]) public loans;
    mapping(address => uint) public totalLoans;
    mapping(address => uint) public collateral;
    mapping(address => uint) public stakeAave;
    uint public loandIds;
    mapping(IERC20 => ICCFLPool) public ccflPools;
    IERC20[] public ccflPoolStableCoins;
    ICCFLLoan ccflLoan;
    IERC20 aToken;

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
        IERC20 _tokenAddress,
        AggregatorV3Interface[] memory _aggregators,
        IERC20[] memory _ccflPoolStableCoin,
        ICCFLPool[] memory _ccflPools,
        IPoolAddressesProvider _poolAddressesProvider,
        ICCFLLoan _ccflLoan,
        IERC20 _aToken
    ) external initializer {
        tokenAddress = _tokenAddress;
        ccflPoolStableCoins = _ccflPoolStableCoin;
        owner = payable(msg.sender);
        loandIds = 1;
        for (uint i = 0; i < _ccflPoolStableCoin.length; i++) {
            ccflPools[_ccflPoolStableCoin[i]] = _ccflPools[i];
            priceFeeds[_ccflPoolStableCoin[i]] = _aggregators[i];
        }
        rateLoan = 1200;
        ccflLoan = _ccflLoan;
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
        // aavePool.supply(_token, _amount, _onBehalfOf, referralCode);
        emit LiquiditySupplied(_onBehalfOf, _token, _amount);
    }

    function depositCollateral(
        uint _amount,
        uint _percent
    ) public checkTokenAllowance(tokenAddress, _amount) {
        // collateral[msg.sender] += (_amount * _percent) / 100;
        // if (_amount - (_amount * _percent) / 100 > 0) {
        //     stakeAave[msg.sender] += _amount - (_amount * _percent) / 100;
        //     if (aaveStakeAddresses[msg.sender] == address(0)) {
        //         // clone an address to save atoken
        //         address aaveStake = address(ccflStake).clone();
        //         ICCFLStake cloneSC = ICCFLStake(aaveStake);
        //         cloneSC.initialize(address(this));
        //         aaveStakeAddresses[msg.sender] = aaveStake;
        //     }
        //     supplyLiquidity(
        //         address(tokenAddress),
        //         _amount - (_amount * _percent) / 100,
        //         aaveStakeAddresses[msg.sender]
        //     );
        // }
        // tokenAddress.transferFrom(msg.sender, address(this), _amount);
    }

    // 2. create loan
    function createLoan(uint _amount, uint _months, IERC20 _stableCoin) public {
        // require(
        //     (collateral[msg.sender] * getLatestPrice(_stableCoin) * LTV) /
        //         1e8 /
        //         10000 >
        //         totalLoans[msg.sender] + _amount,
        //     "Don't have enough collateral"
        // );
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
        ccflPools[_stableCoin].lockLoan(
            loan.loanId,
            loan.amount,
            loan.monthlyPayment,
            _borrower
        );
        totalLoans[_borrower] += _amount;
    }

    // 3. Monthly payment
    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint _amount, IERC20 _stableCoin) {
        require(
            _stableCoin.allowance(msg.sender, address(this)) >= _amount,
            "Error"
        );
        _;
    }

    function depositMonthlyPayment(
        uint _loanId,
        uint _amount,
        IERC20 _stableCoin
    ) public checkUsdcAllowance(_amount, _stableCoin) {
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
        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        _stableCoin.approve(address(ccflPools[_stableCoin]), _amount);
        // ccflPools[_stableCoin].depositMonthlyPayment(_loanId, _amount);
    }

    // 4. close loan
    function closeLoan(
        uint _loanId,
        uint _amount,
        IERC20 _stableCoin
    ) external {
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

        _stableCoin.transferFrom(msg.sender, address(this), _amount);
        _stableCoin.approve(address(ccflPools[_stableCoin]), _amount);
        ccflPools[_stableCoin].closeLoan(_loanId, _amount);
    }

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

    // .6 withdraw Collateral
    function withdrawCollateral(uint _amount, IERC20 _stableCoin) public {
        require(
            _amount <= collateral[msg.sender],
            "Do not have enough collateral"
        );
        collateral[msg.sender] -= _amount;
        // require(
        //     getHealthFactor(msg.sender, _stableCoin) > 100,
        //     "Do not have good health factor"
        // );
        emit Withdraw(msg.sender, _amount, block.timestamp);
        tokenAddress.transfer(msg.sender, _amount);
    }

    receive() external payable {}
}
