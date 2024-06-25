// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CCFL {
    address payable public owner;
    IERC20 public usdcAddress;
    mapping(address => uint) public lenderDeposit;

    event Withdrawal(uint amount, uint when);

    constructor(IERC20 _usdcAddress) payable {
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
    }

    // Modifier to check token allowance
    modifier checkUSDCAllowance(uint amount) {
        require(
            usdcAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function depositUSDCTokens(
        uint _amount
    ) public checkUSDCAllowance(_amount) {
        lenderDeposit[msg.sender] += _amount;
        usdcAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUSDCTokens(uint _amount) public {
        // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);
        require(lenderDeposit[msg.sender] >= _amount, "Balance is not enough");
        emit Withdrawal(_amount, block.timestamp);
        lenderDeposit[msg.sender] -= _amount;
        usdcAddress.transfer(msg.sender, _amount);
    }
}
