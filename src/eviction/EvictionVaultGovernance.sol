// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultStorage} from "./EvictionVaultStorage.sol";

abstract contract EvictionVaultGovernance is EvictionVaultStorage {
    function submitTransaction(address to, uint256 value, bytes calldata data) external onlyOwner {
        uint256 id = txCount++;
        uint256 executionTime = threshold == 1 ? block.timestamp + TIMELOCK_DURATION : 0;

        transactions[id] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            confirmations: 1,
            submissionTime: block.timestamp,
            executionTime: executionTime
        });

        confirmed[id][msg.sender] = true;
        emit Submission(id);
    }

    function confirmTransaction(uint256 txId) external onlyOwner txExists(txId) {
        Transaction storage txn = transactions[txId];
        if (txn.executed) revert AlreadyExecuted();
        if (confirmed[txId][msg.sender]) revert AlreadyConfirmed();

        confirmed[txId][msg.sender] = true;
        txn.confirmations++;

        if (txn.confirmations >= threshold && txn.executionTime == 0) {
            txn.executionTime = block.timestamp + TIMELOCK_DURATION;
        }

        emit Confirmation(txId, msg.sender);
    }

    function executeTransaction(uint256 txId) external txExists(txId) nonReentrant {
        Transaction storage txn = transactions[txId];

        if (txn.executed) revert AlreadyExecuted();
        if (txn.confirmations < threshold) revert InsufficientConfirmations();
        if (txn.executionTime == 0 || block.timestamp < txn.executionTime) revert TimelockNotReady();

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (!success) revert TransferFailed();

        emit Execution(txId);
    }

    function setMerkleRoot(bytes32 root) external onlyVault {
        merkleRoot = root;
        emit MerkleRootSet(root);
    }

    function pause() external onlyVault {
        paused = true;
        emit Paused();
    }

    function unpause() external onlyVault {
        paused = false;
        emit Unpaused();
    }

    function emergencyWithdrawAll(address to) external onlyVault whenPaused {
        uint256 amount = address(this).balance;
        totalVaultValue = 0;

        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit EmergencyWithdraw(to, amount);
    }
}
