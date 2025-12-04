# AAKit Architecture Specification

## Version 1.0 - Phase 1

**Date:** December 4, 2025  
**Status:** Draft

## Table of Contents

1. [Overview](#overview)
2. [Core Components](#core-components)
3. [Smart Contract Architecture](#smart-contract-architecture)
4. [Passkey Authentication Flow](#passkey-authentication-flow)
5. [Gas Sponsorship & Paymaster](#gas-sponsorship--paymaster)
6. [Security Model](#security-model)
7. [Module System](#module-system)

## Overview

AAKit is an open-source ERC-4337 smart wallet infrastructure stack with native passkey (WebAuthn) support. It provides:

- **ERC-4337 Compliance**: Full account abstraction support via EntryPoint v0.7
- **ERC-7579 Modularity**: Pluggable validator, executor, and hook modules
- **Native Passkey Support**: P256 (secp256r1) signature verification for WebAuthn
- **Gasless Transactions**: Paymaster contracts for sponsored user operations
- **Vendor Neutrality**: Open, interoperable infrastructure

### Design Principles

1. **Minimal & Modular**: Core wallet is lightweight; features added via modules
2. **Security First**: Formal verification targets, comprehensive testing
3. **Interoperable**: Works across wallets, dapps, and module ecosystems
4. **Developer Friendly**: Clear interfaces, extensive documentation
5. **Production Ready**: Audited, gas-optimized, battle-tested patterns

## Core Components

### 1. Smart Wallet Contract (`AAKitWallet.sol`)

**Responsibilities:**
- ERC-4337 `IAccount` interface implementation
- ERC-7579 modular account interface
- Execution management (single, batch, delegatecall)
- Module installation/uninstallation
- Nonce management with key-based sequences

**Key Features:**
- Multiple concurrent owners (address + passkey)
- Cross-chain replayable signatures for owner management
- Upgradeable via UUPS pattern
- Gas-optimized for L2 deployment

**Inheritance:**
```
AAKitWallet
  ├─ ERC4337Account (core AA logic)
  ├─ ERC7579Account (modular interface)
  ├─ MultiOwnable (owner management)
  └─ UUPSUpgradeable (upgradeability)
```

### 2. Passkey Validator Module (`PasskeyValidator.sol`)

**Responsibilities:**
- P256 signature verification for WebAuthn authentication
- ERC-1271 signature validation
- Challenge-response authentication

**Implementation Details:**
- Uses RIP-7212 precompile (P256VERIFY) when available
- Falls back to FreshCryptoLib for chains without precompile
- Validates WebAuthn assertion structure
- Handles authenticatorData and clientDataJSON parsing

**Interface:**
```solidity
interface IPasskeyValidator {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (uint256 validationData);
    
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata signature
    ) external view returns (bytes4);
}
```

### 3. Wallet Factory (`AAKitFactory.sol`)

**Responsibilities:**
- Deterministic wallet deployment via CREATE2
- Address prediction before deployment
- Batch deployment optimization

**Features:**
- Singleton pattern for implementation
- Counterfactual address generation
- Initialization with initial owners

### 4. Paymaster Contracts

#### a. `VerifyingPaymaster.sol`
- Off-chain signature verification
- Developer-sponsored transactions
- Rate limiting and spending caps

#### b. `ERC20Paymaster.sol`
- Pay gas with ERC-20 tokens
- Automated token-to-ETH conversion
- Price oracle integration

## Smart Contract Architecture

### Account Structure

```
┌─────────────────────────────────────┐
│         AAKitWallet                 │
│  (ERC-4337 + ERC-7579 Compliant)   │
├─────────────────────────────────────┤
│ Core Functions:                     │
│ - execute()                         │
│ - executeBatch()                    │
│ - validateUserOp()                  │
│ - installModule()                   │
│ - uninstallModule()                 │
└─────────────────────────────────────┘
         │
         ├─► Validators (modular)
         │   ├─ PasskeyValidator
         │   ├─ EOAValidator
         │   └─ MultisigValidator
         │
         ├─► Executors (modular)
         │   ├─ SessionKeyExecutor
         │   └─ RecurringPaymentExecutor
         │
         └─► Hooks (optional)
             ├─ SpendingLimitHook
             └─ AllowlistHook
```

### Module Types (ERC-7579)

| Type | ID | Purpose | Examples |
|------|----|---------| ---------|
| Validator | 1 | Signature validation | PasskeyValidator, EOAValidator |
| Executor | 2 | Execution permissions | SessionKey, AutoPay |
| Fallback | 3 | Extended functionality | TokenReceiver, NFTHandler |
| Hook | 4 | Pre/post execution logic | SpendingLimit, 2FA |

### Execution Flow

```
User → UserOperation
  ↓
Bundler → EntryPoint.handleOps()
  ↓
EntryPoint → Wallet.validateUserOp()
  ↓
Wallet → PasskeyValidator.validateUserOp()
  ↓
PasskeyValidator → P256 Verify (RIP-7212)
  ↓
EntryPoint → Wallet.execute() / executeFromExecutor()
  ↓
Target Contract
```

## Passkey Authentication Flow

### WebAuthn Integration

**Registration Flow:**
1. User initiates wallet creation
2. Browser generates passkey via `navigator.credentials.create()`
3. Public key (P256) extracted and stored in wallet
4. Wallet deployed with passkey as initial owner

**Authentication Flow:**
1. User initiates transaction
2. SDK constructs UserOperation with challenge
3. Browser signs challenge via `navigator.credentials.get()`
4. WebAuthn assertion includes:
   - Signature (r, s)
   - AuthenticatorData
   - ClientDataJSON
5. PasskeyValidator verifies:
   - Signature validity
   - Challenge matches
   - Origin/RP ID correct
   - Flags valid (UP, UV)

### Signature Format

```solidity
struct WebAuthnAuth {
    bytes authenticatorData;
    bytes clientDataJSON;
    uint256 challengeIndex;
    uint256 typeIndex;
    uint256 r;
    uint256 s;
}
```

### P256 Verification

**Method 1: RIP-7212 Precompile (Preferred)**
```solidity
// Precompile at 0x0000...0100
(bool success, bytes memory result) = 
    P256_VERIFIER.staticcall(
        abi.encode(message, r, s, x, y)
    );
```

**Method 2: FreshCryptoLib Fallback**
- Pure Solidity implementation
- Higher gas cost (~300k vs ~3k gas)
- Used on chains without RIP-7212

## Gas Sponsorship & Paymaster

### Paymaster Architecture

```
User Operation
  ↓
paymasterAndData = abi.encodePacked(
    paymasterAddress,      // 20 bytes
    verificationGasLimit,  // 16 bytes
    postOpGasLimit,        // 16 bytes
    paymasterData          // variable
)
  ↓
EntryPoint → Paymaster.validatePaymasterUserOp()
  ↓
Paymaster validates & returns context
  ↓
EntryPoint executes UserOp
  ↓
Paymaster.postOp() (if needed)
```

### Paymaster Modes

1. **Developer Sponsorship**
   - App pays gas for users
   - Signature-based authorization
   - Spending limits per user/app

2. **Token Payment**
   - User pays in ERC-20 tokens
   - Paymaster swaps to ETH
   - Price oracle for fair exchange

3. **Subscription**
   - Monthly gas allowance
   - Flat fee model
   - Auto-renewal logic

## Security Model

### Threat Model

**Assumptions:**
- EntryPoint contract is trusted (canonical deployment)
- P256 cryptography is secure (NIST standard)
- WebAuthn protocol is secure (FIDO2 certified)

**Attack Vectors Mitigated:**

1. **Replay Attacks**
   - Nonce management per ERC-4337
   - Chain ID validation in userOpHash
   - Signature includes EntryPoint address

2. **Signature Malleability**
   - Normalized s-values for ECDSA
   - WebAuthn assertion uniqueness

3. **Phishing**
   - Origin validation in WebAuthn
   - RP ID enforcement
   - User presence (UP) required

4. **Unauthorized Execution**
   - Only EntryPoint can call execution functions
   - Module authorization checks
   - Hook-based spending limits

5. **Front-running**
   - UserOp mempool with first-seen priority
   - Bundler reputation system

### Access Control

```
┌────────────────────────────────────────┐
│  Function Access Control Matrix        │
├────────────────┬───────────────────────┤
│ execute()      │ onlyEntryPointOrSelf  │
│ validateUserOp │ onlyEntryPoint        │
│ installModule  │ onlyEntryPointOrSelf  │
│ addOwner       │ onlySelf              │
│ upgradeToNew   │ onlySelf              │
└────────────────┴───────────────────────┘
```

### Recovery Mechanisms

1. **Social Recovery** (optional module)
   - Guardian-based recovery
   - Threshold signatures
   - Time-delayed execution

2. **Passkey Rotation**
   - Add new passkey while old one active
   - Remove old passkey after verification
   - Cross-chain replayable

## Module System

### Module Lifecycle

```
Install Module
  ↓
Wallet.installModule(moduleTypeId, module, initData)
  ↓
Module.onInstall(initData)
  ↓
Module active
  ↓
Wallet.uninstallModule(moduleTypeId, module, deInitData)
  ↓
Module.onUninstall(deInitData)
```

### Standard Modules (Phase 2+)

1. **PasskeyValidator** - Primary authentication
2. **SessionKeyValidator** - Temporary permissions
3. **RecoveryModule** - Social recovery
4. **SpendingLimitHook** - Transaction limits
5. **AllowlistHook** - Approved addresses only

### Module Interface (ERC-7579)

```solidity
interface IERC7579Module {
    function onInstall(bytes calldata data) external;
    function onUninstall(bytes calldata data) external;
    function isModuleType(uint256 moduleTypeId) 
        external view returns (bool);
}
```

## Gas Optimization

### Strategies

1. **Calldata Optimization**
   - Owner index instead of full public key
   - Packed structs for paymasterAndData
   - Minimal signature encoding

2. **Storage Optimization**
   - Bitmap for owner tracking
   - Single slot for common config
   - Immutable variables where possible

3. **Execution Optimization**
   - Batch operations support
   - Delegate to MultiCall for complex logic
   - Precompile usage (P256VERIFY)

### Gas Benchmarks (Target)

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Passkey UserOp Validation | ~60k | With RIP-7212 |
| EOA UserOp Validation | ~45k | ECDSA verification |
| Simple ETH Transfer | ~25k | Execution only |
| ERC-20 Transfer | ~50k | Execution only |
| Batch (3 transfers) | ~85k | Amortized cost |

## Cross-Chain Considerations

### Replayable Operations

For certain operations (owner management, upgrades), signatures should work across chains:

```solidity
// Exclude chain ID from hash
function executeWithoutChainIdValidation(
    bytes calldata data
) external onlyEntryPoint {
    bytes4 selector = bytes4(data[0:4]);
    require(canSkipChainIdValidation(selector));
    _call(address(this), 0, data);
}
```

**Allowed Selectors:**
- `addOwnerAddress()`
- `addOwnerPublicKey()`
- `removeOwnerAtIndex()`
- `upgradeToAndCall()`

### Multi-Chain Deployment

- Same factory address via Safe Singleton Factory
- Deterministic wallet addresses across chains
- Synchronized owner state via relayer

## Next Steps (Phase 2)

1. Implement core smart contracts
2. Deploy to testnet
3. Build PasskeyValidator module
4. Integrate P256 verification
5. Develop paymaster contracts
6. Comprehensive Foundry test suite
7. Gas profiling and optimization
8. Security audit preparation

## References

- [ERC-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [ERC-7579 Specification](https://eips.ethereum.org/EIPS/eip-7579)
- [RIP-7212: P256 Precompile](https://github.com/ethereum/RIPs/blob/master/RIPS/rip-7212.md)
- [WebAuthn Spec](https://www.w3.org/TR/webauthn/)
- [Porto by Ithaca](https://github.com/ithacaxyz/porto)
- [Coinbase Smart Wallet](https://github.com/coinbase/smart-wallet)
- [Base WebAuthn Library](https://github.com/base-org/webauthn-sol)
