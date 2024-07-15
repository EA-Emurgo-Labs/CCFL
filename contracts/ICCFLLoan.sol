// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

struct Loan {
    uint loanId;
    address borrower;
    bool isPaid;
    uint amount;
    uint deadline;
    uint monthlyPayment;
    uint rateLoan;
    uint monthPaid;
    uint amountMonth;
    IERC20 stableCoin;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
interface ICCFLLoan {
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

    event Withdrawal(uint amount, uint when);

    // function supplyLiquidity(address _token, uint256 _amount) external;

    function withdrawLiquidity() external;

    // function getUserAccountData(
    //     address user
    // )
    //     external
    //     view
    //     returns (
    //         uint256 totalCollateralBase,
    //         uint256 totalDebtBase,
    //         uint256 availableBorrowsBase,
    //         uint256 currentLiquidationThreshold,
    //         uint256 ltv,
    //         uint256 healthFactor
    //     );

    function initialize(
        Loan memory _loan,
        IERC20[] memory _collateralTokens,
        IPoolAddressesProvider[] memory _aaveAddressProviders,
        IERC20[] memory _aTokens
    ) external;
}
