// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MathUtils} from "./math/MathUtils.sol";
import {WadRayMath} from "./math/WadRayMath.sol";
import {PercentageMath} from "./math/PercentageMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {DataTypes} from "./DataTypes.sol";
import {IReserveInterestRateStrategy} from "./IReserveInterestRateStrategy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IERC20Standard.sol";

/// @title Pool contract
/// @author
/// @notice usd
interface ICCFLPool {
    event Withdraw(address user, uint amount, uint when);
    event Deposit(address user, uint amount, uint when);
    event WithdrawLoan(address user, uint amount, uint when);
    event CloseLoan(uint loanId, uint amount, address borrower, uint when);

    function withdrawLoan(address _receiver, uint _loanId) external;

    function setCCFL(address _ccfl) external;

    function getRemainingPool() external view returns (uint amount);

    function getDebtPool() external view returns (uint amount);

    function borrow(uint _loanId, uint256 _amount, address _borrower) external;

    function supply(uint256 _amount) external;

    function withdraw(uint256 _amount) external;

    function repay(uint _loanId, uint256 _amount) external;

    function getCurrentLoan(uint _loanId) external view returns (uint256);

    function getCurrentRate()
        external
        view
        returns (uint256, uint256, uint256, uint256);

    function liquidatePenalty(uint256 _amount) external;

    function initialize(
        IERC20Standard _stableCoinAddress,
        address interestRateStrategyAddress
    ) external;

    function getTotalSupply() external view returns (uint256);

    function getMaxWidthdraw() external view returns (uint256);
}
