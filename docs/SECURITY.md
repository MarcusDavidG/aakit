# Security Model & Threat Analysis

## Overview

This document outlines AAKit's security model, threat analysis, and mitigation strategies.

## Trust Assumptions

### Trusted Components

1. **EntryPoint Contract (ERC-4337)**
   - Canonical deployment at known address
   - Audited and battle-tested
   - Handles all user operation execution
   - **Risk**: If compromised, entire AA ecosystem at risk
   - **Mitigation**: Use official EntryPoint; verify address

2. **P256 Cryptography (NIST Curve)**
   - secp256r1 ECDSA signatures
   - Widely used in TLS, government standards
   - **Risk**: Quantum computers could break in future
   - **Mitigation**: Plan for post-quantum migration path

3. **WebAuthn Protocol (FIDO2)**
   - W3C standard for web authentication
   - Hardware-backed credential storage
   - **Risk**: Browser implementation bugs
   - **Mitigation**: Feature detection, graceful degradation

4. **User's Device**
   - TPM/Secure Enclave protects private keys
   - Operating system integrity
   - **Risk**: Device compromise, malware
   - **Mitigation**: Multi-factor options, spending limits

### Untrusted Components

1. **Bundlers**: Can censor but not steal funds
2. **Paymasters**: Can refuse to pay but not steal
3. **Modules**: User-installed, must be audited
4. **Frontend**: Can be phished, verify origin
5. **RPC Nodes**: Can lie about state, use multiple

## Threat Model

### Threat Categories

1. **Signature Forgery**: Attacker creates valid signature
2. **Replay Attacks**: Reuse valid signatures
3. **Phishing**: Trick user into signing malicious ops
4. **Front-running**: MEV bots exploit pending userOps
5. **DoS**: Flood network with invalid userOps
6. **Unauthorized Access**: Bypass owner checks
7. **Reentrancy**: Call back into wallet during execution
8. **Upgrade Attacks**: Malicious implementation upgrade

## Attack Vectors & Mitigations

### 1. Signature Forgery

**Attack**: Attacker attempts to forge a valid passkey signature

**Risk Level**: CRITICAL

**Mitigations**:
- ✅ P256 signatures require knowledge of private key
- ✅ Private key never leaves device hardware
- ✅ Signature verification on-chain via precompile
- ✅ Malleability protection (normalize s-values)

**Detection**:
```solidity
function validateSignature(
    bytes32 message,
    uint256 r,
    uint256 s,
    bytes memory publicKey
) internal view returns (bool) {
    // Prevent malleability
    uint256 n = P256_CURVE_ORDER;
    if (s > n / 2) revert MalleableSignature();
    
    return _verifyP256(message, r, s, publicKey);
}
```

### 2. Replay Attacks

**Attack**: Reuse a valid userOp on same/different chain

**Risk Level**: CRITICAL

**Mitigations**:
- ✅ Nonce-based replay protection (ERC-4337)
- ✅ Chain ID included in userOpHash
- ✅ EntryPoint address included in userOpHash
- ✅ Time-based validity windows (optional)

**Code**:
```solidity
bytes32 userOpHash = keccak256(abi.encode(
    hashUserOp(userOp),
    entryPoint,
    chainId
));
```

**Cross-Chain Considerations**:
- Some operations (owner management) are deliberately replayable
- Use `executeWithoutChainIdValidation` with whitelisted selectors

### 3. Phishing Attacks

**Attack**: Malicious site tricks user into signing bad transaction

**Risk Level**: HIGH

**Mitigations**:
- ✅ WebAuthn origin validation (RP ID)
- ✅ Clear transaction preview before signing
- ✅ Domain-bound credentials
- ✅ User presence (UP) flag required
- ✅ User verification (UV) flag required

**WebAuthn Protection**:
```javascript
// Credential is bound to origin
const credential = await navigator.credentials.get({
  publicKey: {
    // Only works on registered origin
    rpId: "app.aakit.io",
    // User must confirm on device
    userVerification: "required"
  }
});
```

**Smart Contract Checks**:
```solidity
// Verify RP ID hash in authenticatorData
bytes32 rpIdHash = bytes32(authenticatorData[0:32]);
require(rpIdHash == sha256(bytes("app.aakit.io")));

// Verify origin in clientDataJSON
require(extractOrigin(clientDataJSON) == "https://app.aakit.io");
```

### 4. Front-running / MEV

**Attack**: Miner/searcher sees pending userOp and frontruns it

**Risk Level**: MEDIUM

**Mitigations**:
- ✅ UserOp nonces prevent direct front-running
- ✅ Private bundler mempools available
- ✅ Flashbots-style bundles for sensitive ops
- ✅ Commit-reveal schemes for high-value txs

**Note**: Some MEV (sandwich attacks) still possible on application layer

### 5. Denial of Service

**Attack**: Flood bundlers with invalid userOps

**Risk Level**: MEDIUM

**Mitigations**:
- ✅ Bundler validation before mempool inclusion
- ✅ Reputation system for accounts/paymasters
- ✅ Stake requirements for paymasters
- ✅ Gas price minimums
- ✅ Rate limiting per account

**Validation Rules**:
```solidity
// Bundler checks before accepting userOp
1. Valid signature
2. Sufficient gas limits
3. Paymaster has deposit (if used)
4. Account has deposit or paymaster
5. No banned storage access
6. Gas price above minimum
```

### 6. Unauthorized Execution

**Attack**: Call wallet functions without proper authorization

**Risk Level**: CRITICAL

**Mitigations**:
- ✅ `onlyEntryPoint` modifier on validateUserOp
- ✅ `onlyEntryPointOrSelf` on execute functions
- ✅ Owner validation in signature verification
- ✅ Module authorization checks

**Access Control**:
```solidity
modifier onlyEntryPoint() {
    require(msg.sender == entryPoint);
    _;
}

modifier onlyEntryPointOrSelf() {
    require(msg.sender == entryPoint || msg.sender == address(this));
    _;
}

function execute(
    address target,
    uint256 value,
    bytes calldata data
) external onlyEntryPointOrSelf {
    // Execute transaction
}
```

### 7. Reentrancy Attacks

**Attack**: Malicious contract calls back into wallet during execution

**Risk Level**: HIGH

**Mitigations**:
- ✅ Checks-effects-interactions pattern
- ✅ Reentrancy guards on critical functions
- ✅ Read-only reentrancy protection
- ✅ EntryPoint's reentrancy protection

**Example**:
```solidity
bool private _locked;

modifier nonReentrant() {
    require(!_locked);
    _locked = true;
    _;
    _locked = false;
}

function execute(...) external onlyEntryPoint nonReentrant {
    // Safe execution
}
```

### 8. Malicious Upgrades

**Attack**: Upgrade wallet to malicious implementation

**Risk Level**: CRITICAL

**Mitigations**:
- ✅ UUPS pattern (upgrade logic in implementation)
- ✅ `onlySelf` modifier on upgrade function
- ✅ Timelock for upgrades (optional)
- ✅ Multi-sig approval (optional)

**Code**:
```solidity
function upgradeToAndCall(
    address newImplementation,
    bytes calldata data
) external onlySelf {
    _authorizeUpgrade(newImplementation);
    _upgradeToAndCallUUPS(newImplementation, data);
}

modifier onlySelf() {
    require(msg.sender == address(this));
    _;
}
```

**Best Practice**: Upgrades should be initiated via `executeWithoutChainIdValidation` for cross-chain consistency

## Module Security

### Module Installation

**Risk**: Malicious modules can drain wallet

**Mitigations**:
1. Curated module registry (Phase 4)
2. Module audits by reputable firms
3. Permission scoping (ERC-7579)
4. Installation requires owner signature
5. Emergency module removal

```solidity
function installModule(
    uint256 moduleTypeId,
    address module,
    bytes calldata initData
) external onlyEntryPointOrSelf {
    // Validate module implements correct interface
    require(IERC7579Module(module).isModuleType(moduleTypeId));
    
    // Check not already installed
    require(!isModuleInstalled(moduleTypeId, module));
    
    // Call module initialization
    IERC7579Module(module).onInstall(initData);
    
    // Store as installed
    _installModule(moduleTypeId, module);
}
```

### Module Types & Risks

| Type | Risk | Mitigation |
|------|------|------------|
| Validator | Can authorize any transaction | Audit carefully, limit to trusted |
| Executor | Can execute on behalf of wallet | Scope permissions, spending limits |
| Hook | Can block all transactions | Emergency disable mechanism |
| Fallback | Can add unexpected behavior | Minimal fallback handlers |

### Module Audit Checklist

- [ ] No self-destruct or delegatecall to untrusted
- [ ] No storage collisions with wallet
- [ ] Proper access control (check msg.sender)
- [ ] No reentrancy vulnerabilities
- [ ] Gas-efficient (no DoS via OOG)
- [ ] Upgradeable only by wallet owner
- [ ] Emergency pause mechanism

## Paymaster Security

### Paymaster DoS Protection

**Attack**: Drain paymaster deposit via gas-heavy operations

**Mitigations**:
- ✅ Gas limit enforcement in validatePaymasterUserOp
- ✅ Stake requirements for paymaster reputation
- ✅ Per-account rate limiting
- ✅ Spending caps per period

```solidity
function validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 maxCost
) external returns (bytes memory context, uint256 validationData) {
    // Check sender hasn't exceeded rate limit
    require(checkRateLimit(userOp.sender));
    
    // Verify paymaster has sufficient deposit
    require(getDeposit() >= maxCost);
    
    // Check spending cap for this account
    require(spentThisPeriod[userOp.sender] + maxCost <= accountCap);
    
    // Update spent amount
    spentThisPeriod[userOp.sender] += maxCost;
    
    return ("", 0);  // Valid
}
```

### ERC-20 Paymaster Risks

**Attack**: Price oracle manipulation

**Mitigations**:
- ✅ Chainlink/UMA price feeds
- ✅ TWAP oracles for manipulation resistance
- ✅ Min/max exchange rates
- ✅ Slippage protection

## Storage Access Restrictions

### ERC-4337 Storage Rules

Contracts accessed during validation MUST NOT:
1. Use any storage except:
   - Sender's storage
   - Storage of associated contracts (factory, paymaster)
2. Read external contracts' storage
3. Use block variables (timestamp, number) for validation logic

**Why?**: Prevents DoS via state invalidation

```solidity
// GOOD: Reading sender's storage
function validateUserOp(...) external view returns (uint256) {
    bytes memory owner = owners[ownerIndex];  // OK
    return validateSignature(...);
}

// BAD: Reading external state
function validateUserOp(...) external view returns (uint256) {
    uint256 balance = IERC20(token).balanceOf(sender);  // NOT ALLOWED
    require(balance > threshold);
}
```

## Gas Griefing

**Attack**: Force high gas usage during validation

**Mitigations**:
- ✅ EntryPoint enforces verificationGasLimit
- ✅ Bundler simulates before inclusion
- ✅ Reputation penalties for gas griefing
- ✅ Paymaster spending caps

## Recovery Mechanisms

### Social Recovery (Optional Module)

**Setup**:
- User designates N guardians
- Threshold M-of-N required for recovery
- Time delay before execution

**Process**:
1. User loses access to passkey
2. Guardians initiate recovery
3. M guardians approve new owner
4. Timelock delay (e.g., 3 days)
5. New owner added, old owner removed

**Security**:
- Guardians should be diverse (email, SMS, trusted contacts)
- Timelock allows cancellation if unauthorized
- Owner can cancel any pending recovery

```solidity
function initiateRecovery(
    address newOwner
) external onlyGuardian {
    bytes32 recoveryId = keccak256(abi.encodePacked(newOwner, block.timestamp));
    recoveries[recoveryId] = Recovery({
        newOwner: newOwner,
        approvals: 1,
        timestamp: block.timestamp
    });
}

function executeRecovery(
    bytes32 recoveryId
) external {
    Recovery memory recovery = recoveries[recoveryId];
    require(recovery.approvals >= threshold);
    require(block.timestamp >= recovery.timestamp + delay);
    
    addOwner(recovery.newOwner);
    // Old owner can be removed separately
}
```

## Incident Response

### Emergency Procedures

1. **Suspected Key Compromise**
   - Immediately add new owner (via existing owner)
   - Remove compromised owner
   - Monitor for unauthorized transactions
   - Rotate any API keys used with wallet

2. **Malicious Module**
   - Uninstall module via `uninstallModule`
   - If blocked, use emergency admin (if configured)
   - Analyze on-chain activity
   - Report to community

3. **Smart Contract Bug**
   - Pause wallet operations (if pausable)
   - Upgrade to patched implementation
   - Publish post-mortem
   - Coordinate with affected users

### Monitoring & Alerts

Recommend users set up:
- Transaction amount alerts
- New owner addition alerts
- Module installation alerts
- Unusual activity detection

## Formal Verification Targets

### Properties to Verify

1. **Authorization Correctness**
   - Only owner-signed userOps can execute
   - Only EntryPoint can call validateUserOp

2. **Nonce Monotonicity**
   - Nonces strictly increase per key
   - No nonce reuse possible

3. **Fund Safety**
   - No unauthorized ETH withdrawals
   - No unauthorized token approvals

4. **Module Isolation**
   - Modules cannot bypass owner checks
   - Module removal always possible

### Tools

- **Certora**: Formal verification of invariants
- **Mythril**: Symbolic execution for vulns
- **Slither**: Static analysis
- **Echidna**: Fuzzing

## Audit Scope

### Critical Contracts (Priority 1)

- AAKitWallet.sol
- PasskeyValidator.sol
- AAKitFactory.sol

### Important Contracts (Priority 2)

- VerifyingPaymaster.sol
- ERC20Paymaster.sol
- MultiOwnable.sol

### Module Contracts (Priority 3)

- SessionKeyValidator.sol
- RecoveryModule.sol
- SpendingLimitHook.sol

## Security Checklist

Before mainnet deployment:

- [ ] Complete security audit by 2+ firms
- [ ] Formal verification of core properties
- [ ] Bug bounty program launched
- [ ] Testnet deployment for 3+ months
- [ ] Mainnet deployment with low limits initially
- [ ] Monitoring and alerting infrastructure
- [ ] Incident response plan documented
- [ ] Insurance coverage explored
- [ ] Post-deployment surveillance

## Responsible Disclosure

**Security Vulnerabilities**: security@aakit.io

**Bug Bounty**: TBD (Phase 4)

**Response Time**:
- Critical: 24 hours
- High: 48 hours
- Medium: 1 week

## References

- [ERC-4337 Security Considerations](https://eips.ethereum.org/EIPS/eip-4337#security-considerations)
- [OWASP Smart Contract Security](https://owasp.org/www-project-smart-contract-top-10/)
- [ConsenSys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Trail of Bits Security Guide](https://github.com/crytic/building-secure-contracts)
