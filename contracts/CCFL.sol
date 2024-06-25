// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    mapping(address => uint) public lenderDeposit;
    mapping(address => Loan[]) public loans;

    event Withdrawal(uint amount, uint when);

    constructor(IERC20 _usdcAddress) payable {
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
    }

    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint amount) {
        require(
            usdcAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function depositUsdcTokens(
        uint _amount
    ) public checkUsdcAllowance(_amount) {
        lenderDeposit[msg.sender] += _amount;
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsdcTokens(uint _amount) public {
        // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);
        require(lenderDeposit[msg.sender] >= _amount, "Balance is not enough");
        emit Withdrawal(_amount, block.timestamp);
        lenderDeposit[msg.sender] -= _amount;
        usdcAddress.transfer(msg.sender, _amount);
    }

    function withdrawalLoan() public {
        usdcAddress.transfer(msg.sender, loans[msg.sender][0].amount);
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
        loan.loanId = 1;
        loan.isPaid = false;
        loans[_borrower].push(loan);
    }
}
