// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./ICCFLStake.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLStake is ICCFLStake {
    address payable public owner;
    IERC20 public usdcAddress;
    IERC20 public linkAddress;

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;

    IERC20 public aToken;

    IERC20 private link;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    constructor(
        IERC20 _usdcAddress,
        IERC20 _linkAddress,
        address _addressProvider,
        IERC20 _aToken
    ) payable {
        linkAddress = _linkAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        link = IERC20(linkAddress);
        aToken = _aToken;
    }

    function supplyLiquidity(address _token, uint256 _amount) external {
        address asset = _token;
        uint256 amount = _amount;
        address onBehalfOf = address(this);
        uint16 referralCode = 0;
        POOL.supply(asset, amount, onBehalfOf, referralCode);
        emit LiquiditySupplied(onBehalfOf, asset, amount);
    }

    function withdrawLiquidity(
        uint256 _amount,
        address _to
    ) external returns (uint256) {
        uint256 amount = _amount;
        uint256 withdrawn = POOL.withdraw(address(aToken), amount, _to);
        emit LiquidityWithdrawn(_to, address(aToken), amount);
        return withdrawn;
    }

    function getBalance() external returns (uint) {
        return link.balanceOf(address(this));
    }

    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return POOL.getUserAccountData(user);
    }

    receive() external payable {}
}
