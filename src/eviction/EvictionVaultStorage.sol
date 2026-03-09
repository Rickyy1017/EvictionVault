// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract EvictionVaultStorage is ReentrancyGuard {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 submissionTime;
        uint256 executionTime;
    }

    address[] internal owners;
    mapping(address => bool) public isOwner;

    uint256 public threshold;

    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(uint256 => Transaction) public transactions;

    uint256 public txCount;

    mapping(address => uint256) public balances;

    bytes32 public merkleRoot;

    mapping(address => bool) public claimed;

    uint256 public constant TIMELOCK_DURATION = 1 hours;

    uint256 public totalVaultValue;

    bool public paused;

    event Deposit(address indexed depositor, uint256 amount);
    event Withdrawal(address indexed withdrawer, uint256 amount);
    event Submission(uint256 indexed txId);
    event Confirmation(uint256 indexed txId, address indexed owner);
    event Execution(uint256 indexed txId);
    event MerkleRootSet(bytes32 indexed newRoot);
    event Claim(address indexed claimant, uint256 amount);
    event Paused();
    event Unpaused();
    event EmergencyWithdraw(address indexed to, uint256 amount);

    error NotOwner();
    error InvalidThreshold();
    error InvalidOwner();
    error DuplicateOwner();
    error VaultPaused();
    error VaultNotPaused();
    error InvalidTransaction();
    error AlreadyConfirmed();
    error AlreadyExecuted();
    error InsufficientConfirmations();
    error TimelockNotReady();
    error InsufficientBalance();
    error TransferFailed();
    error AlreadyClaimed();
    error InvalidMerkleProof();
    error OnlyVault();

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    modifier onlyVault() {
        _onlyVault();
        _;
    }

    modifier whenNotPaused() {
        _whenNotPaused();
        _;
    }

    modifier whenPaused() {
        _whenPaused();
        _;
    }

    modifier txExists(uint256 txId) {
        _txExists(txId);
        _;
    }

    function _onlyOwner() internal view {
        if (!isOwner[msg.sender]) revert NotOwner();
    }

    function _onlyVault() internal view {
        if (msg.sender != address(this)) revert OnlyVault();
    }

    function _whenNotPaused() internal view {
        if (paused) revert VaultPaused();
    }

    function _whenPaused() internal view {
        if (!paused) revert VaultNotPaused();
    }

    function _txExists(uint256 txId) internal view {
        if (txId >= txCount) revert InvalidTransaction();
    }

    function _initializeOwners(address[] memory _owners, uint256 _threshold) internal {
        if (_owners.length == 0) revert InvalidOwner();
        if (_threshold == 0 || _threshold > _owners.length) revert InvalidThreshold();

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert InvalidOwner();
            if (isOwner[owner]) revert DuplicateOwner();

            isOwner[owner] = true;
            owners.push(owner);
        }

        threshold = _threshold;
    }

    function getOwners() external view returns (address[] memory) {
        return owners;
    }
}
