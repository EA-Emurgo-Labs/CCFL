// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Aave
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 */
library Errors {
    string public constant INVALID_OPTIMAL_USAGE_RATIO = "1"; // 'Invalid optimal usage ratio'
    string public constant ONLY_THE_OWNER = "2";
    string public constant POOL_TOKEN_IS_NOT_ACTIVED = "3";
    string public constant COLLATERAL_TOKEN_IS_NOT_ACTIVED = "4";
    string public constant TOKEN_IS_NOT_EXISTED = "5";
    string public constant DO_NOT_HAVE_ENOUGH_DEPOSITED_ETH = "6";
    string public constant DO_NOT_HAVE_ENOUGH_COLLATERAL = "7";
    string public constant DO_NOT_HAVE_ENOUGH_LENDING_FUND = "8";
    string public constant IS_NOT_OWNER_LOAN = "9";
    string public constant DO_NOT_HAVE_ASSETS = "10";
    string public constant CAN_NOT_LIQUIDATE = "11";
    string public constant LOAN_IS_NOT_CLOSED_OR_FINALTY = "12";
    string public constant ONLY_THE_CCFL = "13";
    string public constant THE_LOAN_IS_PAID = "14";
    string public constant DO_NOT_HAVE_ENOUGH_LIQUIDITY = "15";
    string public constant IT_IS_CLOSED = "16";
    string public constant IT_IS_LIQUIDATED = "17";
    string public constant ONLY_THE_OPERATOR = "18";
    string public constant ONLY_FIAT_LOAN = "19";
    string public constant ETH_NATIVE_DISABLE = "20";
    string public constant SC_IS_PAUSED = "21";
    string public constant ONLY_THE_BORROWER = "22";
}
