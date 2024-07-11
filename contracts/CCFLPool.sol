// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICCFLPool.sol";

struct Loan {
    uint loanId;
    address[] lenders;
    uint[] lockFund;
    bool isPaid;
    uint amount;
    uint monthlyPayment;
    bool isClosed;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLPool is ICCFLPool {
    address payable public owner;
    IERC20 public stableCoinAddress;
    mapping(address => uint) public lenderLockFund;
    mapping(address => uint) public lenderRemainFund;
    uint public totalLockFund;
    uint public totalRemainFund;
    address[] public lenders;

    mapping(address => mapping(uint => Loan)) public loans;
    mapping(address => uint) public loanBalance;
    mapping(address => uint) public monthlyPaymentBalance;
    mapping(address => bool) public CCFLs;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    modifier onlyCCFL() {
        require(true == CCFLs[msg.sender], "only the ccfl");
        _;
    }

    constructor(IERC20 _stableCoinAddress) payable {
        stableCoinAddress = _stableCoinAddress;
        owner = payable(msg.sender);
    }

    function setCCFL(address _ccfl, bool active) public onlyOwner {
        CCFLs[_ccfl] = active;
    }

    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint amount) {
        require(
            stableCoinAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function depositUsdc(uint _amount) public checkUsdcAllowance(_amount) {
        // check a new lender
        bool existedLender = false;
        for (uint i = 0; i < lenders.length; i++) {
            if (lenders[i] == msg.sender) {
                existedLender = true;
                break;
            }
        }
        if (!existedLender) {
            lenders.push(msg.sender);
        }
        emit Deposit(msg.sender, _amount, block.timestamp);
        lenderRemainFund[msg.sender] += _amount;
        totalRemainFund += _amount;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsdc(uint _amount) public {
        require(
            lenderRemainFund[msg.sender] >= _amount,
            "Balance is not enough"
        );
        emit Withdraw(msg.sender, _amount, block.timestamp);
        lenderRemainFund[msg.sender] -= _amount;
        if (
            lenderLockFund[msg.sender] <= 0 && lenderRemainFund[msg.sender] <= 0
        ) {
            uint deleteIndex = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenders[i] == msg.sender) deleteIndex = i;
            }

            if (lenders[deleteIndex] == msg.sender) {
                lenders[deleteIndex] = lenders[lenders.length - 1];
                delete lenders[lenders.length - 1];
            }
        }
        stableCoinAddress.transfer(msg.sender, _amount);
    }

    function lockLoan(
        uint _loanId,
        uint _amount,
        uint _monthlyPayment,
        address _borrower
    ) public onlyCCFL {
        if (
            _loanId > 0 &&
            !loans[msg.sender][_loanId].isPaid &&
            totalRemainFund >= _amount
        ) {
            uint totalLock = 0;
            uint[] memory emptyFund = new uint[](lenders.length);
            uint last = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenderRemainFund[lenders[i]] <= 0) {
                    emptyFund[i] = 1;
                } else last = i;
            }

            for (uint i = 0; i < lenders.length; i++) {
                if (i != last && emptyFund[i] != 1) {
                    uint lockFund = (lenderRemainFund[lenders[i]] * _amount) /
                        totalRemainFund;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    totalLock += lockFund;
                    loans[msg.sender][_loanId].lenders.push(lenders[i]);
                    loans[msg.sender][_loanId].lockFund.push(lockFund);
                } else if (i == last) {
                    uint lockFund = _amount - totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    loans[msg.sender][_loanId].lenders.push(lenders[i]);
                    loans[msg.sender][_loanId].lockFund.push(lockFund);
                }
            }

            loans[msg.sender][_loanId].isPaid = true;
            loans[msg.sender][_loanId].amount = _amount;
            loans[msg.sender][_loanId].monthlyPayment = _monthlyPayment;
            loanBalance[_borrower] += _amount;
            totalLockFund += _amount;
            emit LockLoan(_loanId, _amount, _borrower, block.timestamp);
        }
    }

    function depositMonthlyPayment(
        uint _loanId,
        uint _amount
    ) public onlyCCFL checkUsdcAllowance(_amount) {
        require(
            _amount == loans[msg.sender][_loanId].monthlyPayment,
            "Do not enough amount"
        );
        uint pay = 0;
        for (uint i = 0; i < loans[msg.sender][_loanId].lenders.length; i++) {
            if (i != loans[msg.sender][_loanId].lenders.length - 1) {
                uint returnAmount = (loans[msg.sender][_loanId].monthlyPayment *
                    loans[msg.sender][_loanId].lockFund[i]) /
                    loans[msg.sender][_loanId].amount;
                monthlyPaymentBalance[
                    loans[msg.sender][_loanId].lenders[i]
                ] += returnAmount;
                pay += returnAmount;
            } else {
                monthlyPaymentBalance[loans[msg.sender][_loanId].lenders[i]] +=
                    loans[msg.sender][_loanId].monthlyPayment -
                    pay;
            }
        }
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function closeLoan(
        uint _loanId,
        uint _amount
    ) public onlyCCFL checkUsdcAllowance(_amount) {
        require(
            _amount == loans[msg.sender][_loanId].amount,
            "Do not enough amount"
        );
        for (uint i = 0; i < loans[msg.sender][_loanId].lenders.length; i++) {
            uint returnAmount = loans[msg.sender][_loanId].lockFund[i];
            lenderLockFund[
                loans[msg.sender][_loanId].lenders[i]
            ] -= returnAmount;
            lenderRemainFund[
                loans[msg.sender][_loanId].lenders[i]
            ] += returnAmount;
        }
        loans[msg.sender][_loanId].isClosed = true;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
        emit CloseLoan(_loanId, _amount, msg.sender, block.timestamp);
    }

    function withdrawLoan() public {
        if (loanBalance[msg.sender] > 0) {
            uint amount = loanBalance[msg.sender];
            loanBalance[msg.sender] = 0;
            emit WithdrawLoan(msg.sender, amount, block.timestamp);
            stableCoinAddress.transfer(msg.sender, amount);
        }
    }

    function withdrawLoanByCCFL(address claimer) public onlyCCFL {
        if (loanBalance[claimer] > 0) {
            uint amount = loanBalance[msg.sender];
            loanBalance[claimer] = 0;
            emit WithdrawLoan(claimer, amount, block.timestamp);
            stableCoinAddress.transfer(claimer, amount);
        }
    }

    function withdrawMonthlyPayment() public {
        if (monthlyPaymentBalance[msg.sender] > 0) {
            uint amount = monthlyPaymentBalance[msg.sender];
            monthlyPaymentBalance[msg.sender] = 0;
            emit WithdrawMonthlyPayment(msg.sender, amount, block.timestamp);
            stableCoinAddress.transfer(msg.sender, amount);
        }
    }

    receive() external payable {}
}
