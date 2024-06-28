// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

interface AggregatorV3Interface {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

struct Loan {
    uint loanId;
    address borrower;
    bool isPaid;
    uint amount;
    uint deadline;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFL {
    address payable public owner;
    IERC20 public usdcAddress;
    IERC20 public linkAddress;
    AggregatorV3Interface public linkPriceFeed;
    mapping(address => uint) public lenderLockFund;
    mapping(address => uint) public lenderRemainFund;
    address[] public lenders;

    mapping(address => Loan[]) public loans;
    mapping(address => uint) public collateralLink;
    uint public loandIds;
    AggregatorV3Interface internal priceFeed;
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
        address _addressProvider,
        address _linkAggretor
    ) payable {
        linkAddress = _linkAddress;
        usdcAddress = _usdcAddress;
        owner = payable(msg.sender);
        loandIds = 1;
        // LINK / USD
        linkPriceFeed = AggregatorV3Interface(_linkAggretor);
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

    function getLatestPrice() public view returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        // for LINK / USD price is scaled up by 10 ** 8
        return price / 1e8;
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

    function depositCollateralLink(
        uint _amount
    ) public checkUsdcAllowance(_amount) {
        collateralLink[msg.sender] += _amount;
        linkAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsdcTokens(uint _amount) public {
        // Uncomment this line, and the import of "hardhat/console.sol", to print a log in your terminal
        // console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);
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
        for (uint i = 0; i < loans[msg.sender].length; i++) {
            if (loans[msg.sender][i].loanId == _loanId) {
                loanIndex = i;
                break;
            }
        }
        if (loanIndex > 0) {
            loans[msg.sender][loanIndex].isPaid = true;
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

    function createLoan(
        address _borrower,
        uint _amount,
        uint _deadline
    ) public {
        Loan memory loan;
        loan.borrower = _borrower;
        loan.deadline = _deadline;
        loan.amount = _amount;
        loan.loanId = loandIds;
        loan.isPaid = false;
        loans[_borrower].push(loan);
        loandIds++;
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
        uint256 _amount
    ) external returns (uint256) {
        address asset = _token;
        address to = address(this);
        uint256 amount = _amount;
        uint256 withdrawn = POOL.withdraw(asset, amount, to);
        emit LiquidityWithdrawn(to, asset, amount);
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

    function approveLINK(
        uint256 _amount,
        address _poolContractAddress
    ) external returns (bool) {
        return link.approve(_poolContractAddress, _amount);
    }

    function allowanceLINK(
        address _poolContractAddress
    ) external view returns (uint256) {
        return link.allowance(address(this), _poolContractAddress);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(owner, token.balanceOf(address(this)));
    }

    receive() external payable {}
}
