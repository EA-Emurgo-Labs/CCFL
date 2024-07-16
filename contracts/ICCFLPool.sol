// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Pool contract
/// @author
/// @notice usd
interface ICCFLPool {
    event Withdraw(address user, uint amount, uint when);
    event Deposit(address user, uint amount, uint when);
    event WithdrawLoan(address user, uint amount, uint when);
    event WithdrawMonthlyPayment(address user, uint amount, uint when);
    event LockLoan(uint loanId, uint amount, address borrower, uint when);
    event CloseLoan(uint loanId, uint amount, address borrower, uint when);

    function depositUsd(uint _amount) external;

    function withdrawUsd(uint _amount) external;

    function lockLoan(uint _loanId, uint _amount, address _borrower) external;

    function withdrawLoan() external;

    function withdrawMonthlyPayment(
        address _signer,
        address _to,
        uint256 _amount,
        string memory _message,
        uint256 _nonce,
        bytes memory _signature
    ) external;

    function closeLoan(uint _loanId, uint _amount) external;

    function setCCFL(address _ccfl) external;

    function getRemainingPool() external returns (uint amount);
}
