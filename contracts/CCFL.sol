// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
}

contract CCFL {
    address payable public owner;
    IERC20 public usdcAddress;
    IERC20 public btcwAddress;
    mapping(address => uint) public lenderDeposit;
    mapping(address => Loan[]) public loans;
    mapping(address => uint) public collateralBTCW;
    uint public loandIds;
    AggregatorV3Interface internal priceFeed;

    event Withdrawal(uint amount, uint when);

    constructor(IERC20 _usdcAddress, IERC20 _btcwAddress) payable {
        usdcAddress = _usdcAddress;
        btcwAddress = _btcwAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        // ETH / USD
        priceFeed = AggregatorV3Interface(
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint amount) {
        require(
            usdcAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // for ETH / USD price is scaled up by 10 ** 8
        return price / 1e8;
    }

    function depositUsdcTokens(
        uint _amount
    ) public checkUsdcAllowance(_amount) {
        lenderDeposit[msg.sender] += _amount;
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function depositCollateralBTCW(
        uint _amount
    ) public checkUsdcAllowance(_amount) {
        collateralBTCW[msg.sender] += _amount;
        btcwAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsdcTokens(uint _amount) public {
        // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);
        require(lenderDeposit[msg.sender] >= _amount, "Balance is not enough");
        emit Withdrawal(_amount, block.timestamp);
        lenderDeposit[msg.sender] -= _amount;
        usdcAddress.transfer(msg.sender, _amount);
    }

    function withdrawalLoan(uint _loanId) public {
        uint loanIndex;
        for (uint i = 0; i < loans[msg.sender].length; i++) {
            if (loans[msg.sender][i].loanId == _loanId) {
                loanIndex = i;
                break;
            }
        }
        if (loanIndex > 0) {
            loans[msg.sender][loanIndex].isPaid = true;
            usdcAddress.transfer(
                msg.sender,
                loans[msg.sender][loanIndex].amount
            );
        }
    }

    function createLoan(
        address _borrower,
        uint _amount,
        uint _deadline
    ) public {
        Loan memory loan;
        loan.borrower = _borrower;
        loan.deadline = _deadline;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loans[_borrower].push(loan);
        loandIds++;
    }
}
