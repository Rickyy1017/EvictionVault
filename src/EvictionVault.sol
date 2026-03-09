// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EvictionVaultAccounting} from "./eviction/EvictionVaultAccounting.sol";
import {EvictionVaultGovernance} from "./eviction/EvictionVaultGovernance.sol";

contract EvictionVault is EvictionVaultGovernance, EvictionVaultAccounting {
    constructor(address[] memory _owners, uint256 _threshold) payable {
        _initializeOwners(_owners, _threshold);
        totalVaultValue = msg.value;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalVaultValue += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
