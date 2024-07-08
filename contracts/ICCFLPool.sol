// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Pool contract
/// @author
/// @notice Link/usd
interface ICCFLPool {
    event Withdraw(address user, uint amount, uint when);
    event Deposit(address user, uint amount, uint when);
    event WithdrawLoan(address user, uint amount, uint when);
    event WithdrawMonthlyPayment(address user, uint amount, uint when);
    event LockLoan(uint loanId, uint amount, address borrower, uint when);
    event CloseLoan(uint loanId, uint amount, address borrower, uint when);

    function depositUsdcTokens(uint _amount) external;

    function withdrawUsdcTokens(uint _amount) external;

    function lockLoan(
        uint _loanId,
        uint _amount,
        uint _monthlyPayment,
        address _borrower
    ) external;

    function monthlyPaymentUsdcTokens(uint _loanId, uint _amount) external;

    function withdrawLoan() external;

    function withdrawMonthlyPayment() external;

    function closeLoan(uint _loanId, uint _amount) external;

    function setCCFL(address _ccfl) external;
}
