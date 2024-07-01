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
    mapping(address => uint) public collateralLink;
    mapping(address => uint) public stakeAaveLink;
    uint public loandIds;
    AggregatorV3Interface internal priceFeed;
    ICCFLPool public ccflPool;
    IERC20 private link;
    ICCFLStake public ccflStake;

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
        ICCFLPool _ccflPool
    ) payable {
        linkAddress = _linkAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        // LINK / USD
        linkPriceFeed = AggregatorV3Interface(_linkAggretor);
        link = IERC20(linkAddress);
        ccflPool = _ccflPool;
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

    function depositCollateralLink(
        uint _amount,
        uint _percent
    ) public checkLinkAllowance(_amount) {
        collateralLink[msg.sender] += (_amount * _percent) / 100;
        stakeAaveLink[msg.sender] += _amount - (_amount * _percent) / 100;
        linkAddress.transferFrom(msg.sender, address(this), _amount);
        // clone an address to save atoken
        address aaveStake = address(ccflStake).clone();
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

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // for LINK / USD price is scaled up by 10 ** 8
        return price / 1e8;
    }

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
