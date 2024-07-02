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

    IERC20 private link;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    constructor(
        IERC20 _usdcAddress,
        IERC20 _linkAddress,
        address _addressProvider
    ) payable {
        linkAddress = _linkAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        link = IERC20(linkAddress);
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
        address _token,
        uint256 _amount,
        address _to
    ) external returns (uint256) {
        address asset = _token;
        address to = address(this);
        uint256 amount = _amount;
        uint256 withdrawn = POOL.withdraw(asset, amount, _to);
        emit LiquidityWithdrawn(_to, asset, amount);
        return withdrawn;
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
