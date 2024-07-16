// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICCFLPool.sol";

struct Loan {
    uint loanId;
    address[] lenders;
    uint[] lockFund;
    bool isPaid;
    uint amount;
    bool isClosed;
}

/// @title CCFL contract
/// @author
/// @notice Link/usd
contract CCFLPool is ICCFLPool {
    address payable public owner;
    IERC20 public stableCoinAddress;
    mapping(address => uint) public lenderLockFund;
    mapping(address => uint) public lenderRemainFund;
    uint public totalLockFund;
    uint public totalRemainFund;
    address[] public lenders;

    mapping(uint => Loan) public loans;
    mapping(address => uint) public loanBalance;
    address public CCFL;
    address public BE;

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner");
        _;
    }

    modifier onlyCCFL() {
        require(CCFL == msg.sender, "only the ccfl");
        _;
    }

    constructor(IERC20 _stableCoinAddress) payable {
        stableCoinAddress = _stableCoinAddress;
        owner = payable(msg.sender);
    }

    function setCCFL(address _ccfl) public onlyOwner {
        CCFL = _ccfl;
    }

    function getRemainingPool() public view returns (uint amount) {
        amount = totalRemainFund;
    }

    // Modifier to check token allowance
    modifier checkUsdAllowance(uint amount) {
        require(
            stableCoinAddress.allowance(msg.sender, address(this)) >= amount,
            "Error"
        );
        _;
    }

    function depositUsd(uint _amount) public checkUsdAllowance(_amount) {
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
        emit Deposit(msg.sender, _amount, block.timestamp);
        lenderRemainFund[msg.sender] += _amount;
        totalRemainFund += _amount;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
    }

    function withdrawUsd(uint _amount) public {
        require(
            lenderRemainFund[msg.sender] >= _amount,
            "Balance is not enough"
        );
        emit Withdraw(msg.sender, _amount, block.timestamp);
        lenderRemainFund[msg.sender] -= _amount;
        if (
            lenderLockFund[msg.sender] <= 0 && lenderRemainFund[msg.sender] <= 0
        ) {
            uint deleteIndex = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenders[i] == msg.sender) deleteIndex = i;
            }

            if (lenders[deleteIndex] == msg.sender) {
                lenders[deleteIndex] = lenders[lenders.length - 1];
                delete lenders[lenders.length - 1];
            }
        }
        stableCoinAddress.transfer(msg.sender, _amount);
    }

    function lockLoan(
        uint _loanId,
        uint _amount,
        address _borrower
    ) public onlyCCFL {
        if (
            _loanId > 0 && !loans[_loanId].isPaid && totalRemainFund >= _amount
        ) {
            uint totalLock = 0;
            uint[] memory emptyFund = new uint[](lenders.length);
            uint last = 0;
            for (uint i = 0; i < lenders.length; i++) {
                if (lenderRemainFund[lenders[i]] <= 0) {
                    emptyFund[i] = 1;
                } else last = i;
            }

            for (uint i = 0; i < lenders.length; i++) {
                if (i != last && emptyFund[i] != 1) {
                    uint lockFund = (lenderRemainFund[lenders[i]] * _amount) /
                        totalRemainFund;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    totalLock += lockFund;
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].lockFund.push(lockFund);
                } else if (i == last) {
                    uint lockFund = _amount - totalLock;
                    lenderLockFund[lenders[i]] += lockFund;
                    lenderRemainFund[lenders[i]] -= lockFund;
                    loans[_loanId].lenders.push(lenders[i]);
                    loans[_loanId].lockFund.push(lockFund);
                }
            }

            loans[_loanId].isPaid = true;
            loans[_loanId].amount = _amount;
            loanBalance[_borrower] += _amount;
            totalLockFund += _amount;
            emit LockLoan(_loanId, _amount, _borrower, block.timestamp);
        }
    }

    function closeLoan(
        uint _loanId,
        uint _amount
    ) public onlyCCFL checkUsdAllowance(_amount) {
        require(_amount == loans[_loanId].amount, "Do not enough amount");
        for (uint i = 0; i < loans[_loanId].lenders.length; i++) {
            uint returnAmount = loans[_loanId].lockFund[i];
            lenderLockFund[loans[_loanId].lenders[i]] -= returnAmount;
            lenderRemainFund[loans[_loanId].lenders[i]] += returnAmount;
        }
        loans[_loanId].isClosed = true;
        stableCoinAddress.transferFrom(msg.sender, address(this), _amount);
        emit CloseLoan(_loanId, _amount, msg.sender, block.timestamp);
    }

    function withdrawLoan() public {
        if (loanBalance[msg.sender] > 0) {
            uint amount = loanBalance[msg.sender];
            loanBalance[msg.sender] = 0;
            emit WithdrawLoan(msg.sender, amount, block.timestamp);
            stableCoinAddress.transfer(msg.sender, amount);
        }
    }

    function withdrawMonthlyPayment(
        address _signer,
        address _to,
        uint256 _amount,
        string memory _message,
        uint256 _nonce,
        bytes memory _signature
    ) public {
        // TODO: check signature from BE
        require(BE == _signer, "Not BE signature");
        require(
            verify(_signer, _to, _amount, _message, _nonce, _signature),
            "Wrong signature"
        );
        stableCoinAddress.transfer(msg.sender, _amount);
    }

    receive() external payable {}

    /* 1. Unlock MetaMask account
    ethereum.enable()
    */

    /* 2. Get message hash to sign
    getMessageHash(
        0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C,
        123,
        "coffee and donuts",
        1
    )

    hash = "0xcf36ac4f97dc10d91fc2cbb20d718e94a8cbfe0f82eaedc6a4aa38946fb797cd"
    */
    function getMessageHash(
        address _to,
        uint256 _amount,
        string memory _message,
        uint256 _nonce
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_to, _amount, _message, _nonce));
    }

    /* 3. Sign message hash
    # using browser
    account = "copy paste account of signer here"
    ethereum.request({ method: "personal_sign", params: [account, hash]}).then(console.log)

    # using web3
    web3.personal.sign(hash, web3.eth.defaultAccount, console.log)

    Signature will be different for different accounts
    0x993dab3dd91f5c6dc28e17439be475478f5635c92a56e17e82349d3fb2f166196f466c0b4e0c146f285204f0dcb13e5ae67bc33f4b888ec32dfe0a063e8f3f781b
    */
    function getEthSignedMessageHash(
        bytes32 _messageHash
    ) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    _messageHash
                )
            );
    }

    /* 4. Verify signature
    signer = 0xB273216C05A8c0D4F0a4Dd0d7Bae1D2EfFE636dd
    to = 0x14723A09ACff6D2A60DcdF7aA4AFf308FDDC160C
    amount = 123
    message = "coffee and donuts"
    nonce = 1
    signature =
        0x993dab3dd91f5c6dc28e17439be475478f5635c92a56e17e82349d3fb2f166196f466c0b4e0c146f285204f0dcb13e5ae67bc33f4b888ec32dfe0a063e8f3f781b
    */
    function verify(
        address _signer,
        address _to,
        uint256 _amount,
        string memory _message,
        uint256 _nonce,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_to, _amount, _message, _nonce);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) public pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) public pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            /*
            First 32 bytes stores the length of the signature

            add(sig, 32) = pointer of sig + 32
            effectively, skips first 32 bytes of signature

            mload(p) loads next 32 bytes starting at the memory address p into memory
            */

            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }
}
