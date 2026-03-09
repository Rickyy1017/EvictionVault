# Eviction Vault (Hardened, Phase 1 Day 1)

This repository now contains a modularized and hardened `EvictionVault` implementation.

## Project Structure

- `src/EvictionVault.sol`
  - Composition root + constructor + `receive()`.
- `src/eviction/EvictionVaultStorage.sol`
  - Shared storage, events, errors, modifiers, owner initialization, and owner getter.
- `src/eviction/EvictionVaultGovernance.sol`
  - Multisig transaction lifecycle, timelock execution, governance actions (`setMerkleRoot`, `pause`, `unpause`, `emergencyWithdrawAll`).
- `src/eviction/EvictionVaultAccounting.sol`
  - User funds flow (`deposit`, `withdraw`, `claim`) and signature verification.
- `test/EvictionVault.t.sol`
  - Positive-path test suite (6 tests).

## Critical Fixes Implemented

1. `setMerkleRoot` callable by anyone
- Fixed by restricting to `onlyVault`.
- Root updates now require multisig proposal + threshold confirmations + timelock + execution.

2. `emergencyWithdrawAll` public drain
- Fixed by changing to `emergencyWithdrawAll(address to)` with `onlyVault` + `whenPaused`.
- Can only execute through timelocked multisig governance flow.

3. `pause` / `unpause` single-owner control
- Fixed by changing both to `onlyVault`.
- Both actions require threshold-based multisig and timelock execution.

4. `receive()` uses `tx.origin`
- Fixed by crediting `balances[msg.sender]` instead of `balances[tx.origin]`.

5. `withdraw` and `claim` use `.transfer`
- Fixed by switching to low-level `.call{value: amount}("")` and success checks.
- Added `nonReentrant` for payout paths.

6. Timelock execution hardening
- Enforced `txExists` checks.
- Enforced `executionTime != 0` and `block.timestamp >= executionTime` before execute.
- Ensured `executionTime` is set for threshold-1 submissions and for threshold attainment in confirmations.

## Additional Safety Improvements

- Constructor owner/threshold validation:
  - no zero owners
  - no duplicate owners
  - `threshold` must be within `1..owners.length`
- Custom errors for tighter revert semantics.
- `getOwners()` view helper.

## Verification Commands

```bash
forge build
forge test
```

Current status after refactor:
- Monolith removed in practice (logic split across dedicated modules).
- Contract compiles cleanly.
- Positive tests pass.

