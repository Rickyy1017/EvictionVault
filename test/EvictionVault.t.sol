// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {EvictionVault} from "../src/EvictionVault.sol";

interface IVaultGovernanceActions {
    function setMerkleRoot(bytes32 root) external;
    function pause() external;
    function unpause() external;
    function emergencyWithdrawAll(address to) external;
}

contract Forwarder {
    function forward(address vault) external payable {
        (bool success, ) = payable(vault).call{value: msg.value}("");
        require(success, "forward failed");
    }
}

contract GasHeavyReceiver {
    uint256 public receiveCount;

    receive() external payable {
        receiveCount++;
    }

    function depositToVault(address payable vault) external payable {
        EvictionVault(vault).deposit{value: msg.value}();
    }

    function withdrawFromVault(address payable vault, uint256 amount) external {
        EvictionVault(vault).withdraw(amount);
    }
}

contract Claimant {
    receive() external payable {}

    function claim(EvictionVault vault, bytes32[] calldata proof, uint256 amount) external {
        vault.claim(proof, amount);
    }
}

contract EvictionVaultTest is Test {
    EvictionVault internal vault;

    address internal owner1 = address(0xA11CE);
    address internal owner2 = address(0xB0B);
    address internal owner3 = address(0xC0DE);

    function setUp() public {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        vault = new EvictionVault{value: 10 ether}(owners, 2);
    }

    function testReceiveCreditsMsgSenderNotOrigin() public {
        Forwarder forwarder = new Forwarder();
        vm.deal(address(forwarder), 1 ether);

        forwarder.forward{value: 1 ether}(address(vault));

        assertEq(vault.balances(address(forwarder)), 1 ether);
        assertEq(vault.balances(address(this)), 0);
    }

    function testWithdrawUsesCallAndSucceedsForContractReceiver() public {
        GasHeavyReceiver receiver = new GasHeavyReceiver();
        vm.deal(address(receiver), 2 ether);

        vm.prank(address(receiver));
        receiver.depositToVault{value: 1 ether}(payable(address(vault)));

        vm.prank(address(receiver));
        receiver.withdrawFromVault(payable(address(vault)), 1 ether);

        assertEq(vault.balances(address(receiver)), 0);
        assertEq(receiver.receiveCount(), 1);
    }

    function testMerkleRootSetViaTimelockedMultisig() public {
        bytes32 root = keccak256("root");
        _queueAndExecute(abi.encodeCall(IVaultGovernanceActions.setMerkleRoot, (root)));

        assertEq(vault.merkleRoot(), root);
    }

    function testPauseAndUnpauseRequireMultisigExecution() public {
        _queueAndExecute(abi.encodeCall(IVaultGovernanceActions.pause, ()));
        assertTrue(vault.paused());

        _queueAndExecute(abi.encodeCall(IVaultGovernanceActions.unpause, ()));
        assertTrue(!vault.paused());
    }

    function testClaimPayoutSucceedsWithValidProof() public {
        Claimant claimant = new Claimant();
        uint256 amount = 0.4 ether;

        bytes32 leaf = keccak256(abi.encodePacked(address(claimant), amount));
        _queueAndExecute(abi.encodeCall(IVaultGovernanceActions.setMerkleRoot, (leaf)));

        bytes32[] memory proof = new bytes32[](0);
        claimant.claim(vault, proof, amount);

        assertEq(address(claimant).balance, amount);
        assertTrue(vault.claimed(address(claimant)));
    }

    function testEmergencyWithdrawAllRequiresPausedMultisigPath() public {
        _queueAndExecute(abi.encodeCall(IVaultGovernanceActions.pause, ()));

        address recipient = address(0xBEEF);
        uint256 vaultBalanceBefore = address(vault).balance;

        _queueAndExecute(abi.encodeCall(IVaultGovernanceActions.emergencyWithdrawAll, (recipient)));

        assertEq(address(vault).balance, 0);
        assertEq(vault.totalVaultValue(), 0);
        assertEq(recipient.balance, vaultBalanceBefore);
    }

    function _queueAndExecute(bytes memory data) internal {
        uint256 txId = vault.txCount();

        vm.prank(owner1);
        vault.submitTransaction(address(vault), 0, data);

        vm.prank(owner2);
        vault.confirmTransaction(txId);

        vm.warp(block.timestamp + vault.TIMELOCK_DURATION());
        vault.executeTransaction(txId);
    }
}
