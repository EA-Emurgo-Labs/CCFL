// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Loan {
    uint loanId;
    address[] lenders;
    uint[] ratio;
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

    function withdrawalLoan(uint _loanId) public {
        uint loanIndex;

        if (loanIndex > 0) {
            loans[loanIndex].isPaid = true;
            // calculate lender remain fund
            uint totalRemainFund = 0;
            for (uint i = 0; i < lenders.length; i++) {
                totalRemainFund += lenderRemainFund[lenders[i]];
            }

            uint totalLock = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (i != lenders.length - 1) {
                    uint lockFund = (lenderRemainFund[lenders[i]] /
                        totalRemainFund) * loans[msg.sender][loanIndex].amount;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    totalLock += lockFund;
                } else {
                    uint lockFund = loans[msg.sender][loanIndex].amount -
                        totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                }
            }

            usdcAddress.transfer(
                msg.sender,
                loans[msg.sender][loanIndex].amount
            );
        }
    }

    receive() external payable {}
}
