// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Loan {
    uint loanId;
    address[] lenders;
    uint[] ratios;
    bool isPaid;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract Pool {
    address payable public owner;
    IERC20 public usdcAddress;
    mapping(address => uint) public lenderLockFund;
    mapping(address => uint) public lenderRemainFund;
    uint public totalLockFund;
    uint public totalRemainFund;
    address[] public lenders;

    mapping(uint => Loan) public loans;
    mapping(address => uint) public loanBalance;
    mapping(address => uint) public monthlyPaymentBalance;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    event Withdraw(address user, uint amount, uint when);
    event Deposit(address user, uint amount, uint when);
    event WithdrawLoan(address user, uint amount, uint when);
    event LockLoan(uint loanId, uint amount, address borrower, uint when);

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
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsdcTokens(uint _amount) public {
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
        usdcAddress.transfer(msg.sender, _amount);
    }

    function lockLoan(uint _loanId, uint _amount, address _borrower) public {
        if (
            _loanId > 0 && !loans[_loanId].isPaid && totalRemainFund >= _amount
        ) {
            uint totalLock = 0;
            uint totalRatios = 0;
            uint[] memory emptyFund = new uint[](lenders.length);
            uint last = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenderRemainFund[lenders[i]] <= 0) {
                    emptyFund[i] = 1;
                } else last = i;
            }

            for (uint i = 0; i < lenders.length; i++) {
                if (i != last && emptyFund[i] != 1) {
                    uint lockFund = (lenderRemainFund[lenders[i]] /
                        totalRemainFund) * _amount;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    totalLock += lockFund;
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].ratios.push(
                        (lenderRemainFund[lenders[i]] / totalRemainFund) * 10000
                    );
                    totalRatios =
                        (lenderRemainFund[lenders[i]] / totalRemainFund) *
                        10000;
                } else if (i == last) {
                    uint lockFund = _amount - totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].ratios.push(10000 - totalRatios);
                }
            }

            loans[_loanId].isPaid = true;

            loanBalance[_borrower] += _amount;
            totalLockFund += _amount;
            emit LockLoan(_loanId, _amount, _borrower, block.timestamp);
        }
    }

    function monthlyPaymentUsdcTokens(
        uint _loanId,
        uint _amount
    ) public checkUsdcAllowance(_amount) {
        // TODO
        // // check a new lender
        // bool existedLender = false;
        // for (uint i = 0; i < lenders.length; i++) {
        //     if (lenders[i] == msg.sender) {
        //         existedLender = true;
        //         break;
        //     }
        // }
        // if (!existedLender) {
        //     lenders.push(msg.sender);
        // }
        // lenderRemainFund[msg.sender] += _amount;
        // usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawLoan() public {
        if (loanBalance[msg.sender] > 0) {
            uint amount = loanBalance[msg.sender];
            loanBalance[msg.sender] = 0;
            emit WithdrawLoan(msg.sender, amount, block.timestamp);
            usdcAddress.transfer(msg.sender, amount);
        }
    }

    receive() external payable {}
}
