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
    address[] public lenders;

    mapping(uint => Loan) public loans;
    mapping(address => uint) public withdrawBalance;
    mapping(address => uint) public monthlyPaymentBalance;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

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
        lenderRemainFund[msg.sender] += _amount;
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsdcTokens(uint _amount) public {
        require(
            lenderRemainFund[msg.sender] >= _amount,
            "Balance is not enough"
        );
        emit Withdrawal(_amount, block.timestamp);
        lenderRemainFund[msg.sender] -= _amount;
        usdcAddress.transfer(msg.sender, _amount);
    }

    function lockLoan(uint _loanId, uint _amount, address receiver) public {
        if (_loanId > 0 && !loans[_loanId].isPaid) {
            // calculate lender remain fund
            uint totalRemainFund = 0;
            for (uint i = 0; i < lenders.length; i++) {
                totalRemainFund += lenderRemainFund[lenders[i]];
            }

            uint totalLock = 0;
            uint totalRatios = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (i != lenders.length - 1) {
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
                } else {
                    uint lockFund = _amount - totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].ratios.push(10000 - totalRatios);
                }
            }

            loans[_loanId].isPaid = true;

            withdrawBalance[receiver] += _amount;
        }
    }

    function monthlyPaymentUsdcTokens(
        uint _loanId,
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
        lenderRemainFund[msg.sender] += _amount;
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawLoan() public {
        if (withdrawBalance[msg.sender] > 0) {
            uint amount = withdrawBalance[msg.sender];
            withdrawBalance[msg.sender] = 0;
            usdcAddress.transfer(msg.sender, amount);
        }
    }

    receive() external payable {}
}
