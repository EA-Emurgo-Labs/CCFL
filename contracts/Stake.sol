// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract Stake {
    address payable public owner;
    IERC20 public usdcAddress;
    IERC20 public linkAddress;
    mapping(address => uint) public lenderLockFund;
    mapping(address => uint) public lenderRemainFund;
    address[] public lenders;

    mapping(address => uint) public collateralLink;
    uint public loandIds;
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;

    IERC20 private link;

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

    constructor(
        IERC20 _usdcAddress,
        IERC20 _linkAddress,
        address _addressProvider
    ) payable {
        linkAddress = _linkAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        link = IERC20(linkAddress);
    }

    // Modifier to check token allowance
    modifier checkUsdcAllowance(uint amount) {
        require(
            usdcAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function supplyLiquidity(address _token, uint256 _amount) external {
        address asset = _token;
        uint256 amount = _amount;
        address onBehalfOf = address(this);
        uint16 referralCode = 0;
        POOL.supply(asset, amount, onBehalfOf, referralCode);
        emit LiquiditySupplied(onBehalfOf, asset, amount);
    }

    receive() external payable {}
}
