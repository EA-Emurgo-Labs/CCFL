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
    bool isClosed;
    bool isLocked;
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

    mapping(uint => Loan) public loans;
    address public CCFL;
    address public BE;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    modifier onlyCCFL() {
        require(CCFL == msg.sender, "only the ccfl");
        _;
    }

    constructor(IERC20 _stableCoinAddress) payable {
        stableCoinAddress = _stableCoinAddress;
        owner = payable(msg.sender);
    }

    function setCCFL(address _ccfl) public onlyOwner {
        CCFL = _ccfl;
    }

    function getRemainingPool() public view returns (uint amount) {
        amount = totalRemainFund;
    }

    // Modifier to check token allowance
    modifier checkUsdAllowance(uint amount) {
        require(
            stableCoinAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function supplyLiquidity(uint _amount) public checkUsdAllowance(_amount) {
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

    function withdrawLiquidity(uint _amount) public {
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
        address _borrower
    ) public onlyCCFL {
        if (
            _loanId > 0 &&
            loans[_loanId].isLocked == false &&
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
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].lockFund.push(lockFund);
                } else if (i == last) {
                    uint lockFund = _amount - totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].lockFund.push(lockFund);
                }
            }

            loans[_loanId].isLocked = true;
            loans[_loanId].amount = _amount;
            totalLockFund += _amount;
            emit LockLoan(_loanId, _amount, _borrower, block.timestamp);
        }
    }

    function closeLoan(
        uint _loanId,
        uint _amount
    ) public onlyCCFL checkUsdAllowance(_amount) {
        require(_amount == loans[_loanId].amount, "Do not enough amount");
        for (uint i = 0; i < loans[_loanId].lenders.length; i++) {
            uint returnAmount = loans[_loanId].lockFund[i];
            lenderLockFund[loans[_loanId].lenders[i]] -= returnAmount;
            lenderRemainFund[loans[_loanId].lenders[i]] += returnAmount;
        }
        loans[_loanId].isClosed = true;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
        emit CloseLoan(_loanId, _amount, msg.sender, block.timestamp);
    }

    function withdrawLoan(address _receiver, uint _loanId) public onlyCCFL {
        require(loans[_loanId].isPaid == false, "Loan is paid");
        loans[_loanId].isPaid = true;
        emit WithdrawLoan(_receiver, loans[_loanId].amount, block.timestamp);
        stableCoinAddress.transfer(_receiver, loans[_loanId].amount);
    }

    receive() external payable {}
}
