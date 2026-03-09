// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {EvictionVaultStorage} from "./EvictionVaultStorage.sol";

abstract contract EvictionVaultAccounting is EvictionVaultStorage {
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        if (balances[msg.sender] < amount) revert InsufficientBalance();

        balances[msg.sender] -= amount;
        totalVaultValue -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawal(msg.sender, amount);
    }

    function claim(bytes32[] calldata proof, uint256 amount) external nonReentrant whenNotPaused {
        if (claimed[msg.sender]) revert AlreadyClaimed();

        bytes32 leaf = _leafHash(msg.sender, amount);
        bytes32 computed = MerkleProof.processProof(proof, leaf);
        if (computed != merkleRoot) revert InvalidMerkleProof();
        if (totalVaultValue < amount) revert InsufficientBalance();

        claimed[msg.sender] = true;
        totalVaultValue -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Claim(msg.sender, amount);
    }

    function verifySignature(
        address signer,
        bytes32 messageHash,
        bytes memory signature
    ) external pure returns (bool) {
        return ECDSA.recover(messageHash, signature) == signer;
    }

    function _leafHash(address account, uint256 amount) internal pure returns (bytes32 leaf) {
        assembly {
            mstore(0x00, shl(96, account))
            mstore(0x14, amount)
            leaf := keccak256(0x00, 0x34)
        }
    }
}
