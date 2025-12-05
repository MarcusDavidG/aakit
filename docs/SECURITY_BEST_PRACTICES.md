# Security Best Practices for AAKit

This document outlines security best practices for developing and deploying applications using AAKit smart wallets with passkey authentication.

## Table of Contents

1. [Smart Contract Security](#smart-contract-security)
2. [Passkey Security](#passkey-security)
3. [Frontend Security](#frontend-security)
4. [Backend Security](#backend-security)
5. [Operational Security](#operational-security)
6. [Incident Response](#incident-response)

## Smart Contract Security

### 1. Pre-Deployment Checklist

**Before deploying to mainnet:**

- [ ] Complete professional security audit (2+ firms recommended)
- [ ] Run static analysis tools (Slither, Mythril)
- [ ] Perform formal verification (if critical)
- [ ] Test on testnet for 3+ months
- [ ] Implement timelocks for upgrades
- [ ] Set up monitoring and alerts
- [ ] Prepare incident response plan
- [ ] Verify all contract addresses
- [ ] Test deployment scripts thoroughly
- [ ] Document all admin functions

### 2. Access Control

**Owner Management:**

```solidity
// ✅ GOOD: Check ownership properly
function execute(address target, uint256 value, bytes calldata data) external {
    _checkOwner(); // Reverts if not owner
    // ... execute
}

// ❌ BAD: No access control
function execute(address target, uint256 value, bytes calldata data) external {
    // Anyone can call!
}
```

**Best Practices:**
- Always use access control modifiers
- Validate msg.sender in critical functions
- Use multi-sig for admin functions
- Implement timelocks for sensitive operations
- Never use tx.origin for authentication

### 3. Signature Verification

**UserOperation Validation:**

```solidity
// ✅ GOOD: Proper signature verification
function validateUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash
) external returns (uint256 validationData) {
    // Verify EntryPoint caller
    require(msg.sender == address(entryPoint), "Only EntryPoint");
    
    // Verify nonce
    _checkNonce(userOp.nonce);
    
    // Verify signature
    if (!_validateSignature(userOpHash, userOp.signature)) {
        return SIG_VALIDATION_FAILED;
    }
    
    return 0;
}

// ❌ BAD: No verification
function validateUserOp(...) external returns (uint256) {
    return 0; // Always succeeds!
}
```

**Best Practices:**
- Always verify EntryPoint caller
- Check nonce to prevent replay
- Validate signature format
- Use EIP-191 or EIP-712 for signing
- Prevent signature malleability

### 4. Reentrancy Protection

**Execute Function:**

```solidity
// ✅ GOOD: Checks-Effects-Interactions pattern
function execute(address target, uint256 value, bytes calldata data) 
    external 
    payable
{
    _checkOwner();
    
    // Checks
    require(address(this).balance >= value, "Insufficient balance");
    
    // Effects (state changes before external call)
    emit Executed(target, value, data);
    
    // Interactions (external calls last)
    (bool success, bytes memory result) = target.call{value: value}(data);
    require(success, string(result));
}
```

**Best Practices:**
- Use Checks-Effects-Interactions pattern
- Update state before external calls
- Use ReentrancyGuard when needed
- Be cautious with delegatecall
- Limit gas for external calls

### 5. Integer Overflow/Underflow

**Solidity 0.8+ protects automatically:**

```solidity
// ✅ Safe in Solidity 0.8+
function add(uint256 a, uint256 b) internal pure returns (uint256) {
    return a + b; // Reverts on overflow
}

// For Solidity < 0.8, use SafeMath
using SafeMath for uint256;

function add(uint256 a, uint256 b) internal pure returns (uint256) {
    return a.add(b);
}
```

### 6. Gas Limit Concerns

**Be careful with loops:**

```solidity
// ❌ BAD: Unbounded loop
function removeAllOwners() external {
    for (uint256 i = 0; i < ownerCount; i++) {
        delete owners[i]; // Could run out of gas!
    }
}

// ✅ GOOD: Bounded operations
function removeOwnerAt(uint256 index) external {
    _checkOwner();
    require(index < ownerCount, "Invalid index");
    delete owners[index];
    ownerCount--;
}
```

## Passkey Security

### 1. Credential Storage

**DO:**
```typescript
// ✅ Store only public information
localStorage.setItem('passkey', JSON.stringify({
  id: passkey.id,              // Credential ID (public)
  publicKeyX: passkey.publicKeyX, // Public key X (public)
  publicKeyY: passkey.publicKeyY, // Public key Y (public)
}))
```

**DON'T:**
```typescript
// ❌ Never store private keys!
localStorage.setItem('privateKey', privateKey) // NEVER DO THIS
```

**Best Practices:**
- Store only credential ID and public key
- Never store private keys (device handles them)
- Use secure storage APIs when available
- Clear sensitive data on logout
- Implement session timeouts

### 2. Relying Party Configuration

**Secure Configuration:**

```typescript
// ✅ GOOD: Strict RP configuration
const passkey = await createPasskey({
  rpId: window.location.hostname,  // Exact domain
  rpName: 'My DApp',
  userVerification: 'required',    // Require biometric
  authenticatorAttachment: 'platform', // Device authenticator
  timeout: 60000,                  // 60 second timeout
})

// ❌ BAD: Loose configuration
const passkey = await createPasskey({
  rpId: '*',                       // Too permissive!
  userVerification: 'discouraged', // No biometric required
})
```

**Best Practices:**
- Use exact domain for rpId
- Require user verification (biometric)
- Use platform authenticators when possible
- Set reasonable timeouts
- Validate origin on server

### 3. Challenge Generation

**Secure Challenges:**

```typescript
// ✅ GOOD: Cryptographically secure random
const challenge = crypto.getRandomValues(new Uint8Array(32))

const assertion = await authenticateWithPasskey({
  challenge,
  rpId: window.location.hostname,
})

// ❌ BAD: Predictable challenge
const challenge = new Uint8Array([1, 2, 3, 4]) // Don't!
```

**Best Practices:**
- Use crypto.getRandomValues()
- Generate fresh challenge for each authentication
- Use at least 32 bytes of entropy
- Verify challenge server-side
- Don't reuse challenges

### 4. Signature Verification

**On-Chain Verification:**

```solidity
// ✅ GOOD: Proper P-256 verification
function verifyPasskey(
    bytes32 hash,
    bytes memory signature,
    bytes32 publicKeyX,
    bytes32 publicKeyY
) internal view returns (bool) {
    // Extract r, s from signature
    (uint256 r, uint256 s) = abi.decode(signature, (uint256, uint256));
    
    // Normalize s to prevent malleability
    if (s > P256_N_DIV_2) {
        s = P256_N - s;
    }
    
    // Use RIP-7212 precompile or fallback
    return _verifyP256(hash, r, s, publicKeyX, publicKeyY);
}
```

**Best Practices:**
- Normalize signature s value
- Use RIP-7212 precompile when available
- Verify authenticator flags
- Check clientDataJSON format
- Validate origin and challenge

## Frontend Security

### 1. HTTPS Required

**WebAuthn requires secure context:**

```typescript
// Check secure context
if (!window.isSecureContext) {
  throw new Error('HTTPS required for WebAuthn')
}

// Development exception: localhost
const isDevelopment = window.location.hostname === 'localhost'
```

**Best Practices:**
- Always use HTTPS in production
- Use localhost for development
- Implement Content Security Policy
- Enable HSTS headers
- Use SRI for CDN resources

### 2. Input Validation

**Validate all inputs:**

```typescript
// ✅ GOOD: Validate addresses
import { isAddress } from 'viem'

function sendTransaction(to: string, value: string) {
  // Validate address
  if (!isAddress(to)) {
    throw new Error('Invalid address')
  }
  
  // Validate amount
  const amount = parseFloat(value)
  if (isNaN(amount) || amount <= 0) {
    throw new Error('Invalid amount')
  }
  
  // Proceed with transaction
  return wallet.sendTransaction({
    to: to as Address,
    value: parseEther(value),
  })
}

// ❌ BAD: No validation
function sendTransaction(to: string, value: string) {
  return wallet.sendTransaction({
    to: to as Address,
    value: parseEther(value), // Could fail or send to wrong address
  })
}
```

**Best Practices:**
- Validate all user inputs
- Sanitize data before display
- Use TypeScript for type safety
- Implement checksums for addresses
- Verify amounts before sending

### 3. Error Handling

**Secure error messages:**

```typescript
// ✅ GOOD: Generic user-facing errors
try {
  await wallet.sendTransaction({...})
} catch (error) {
  // Log detailed error securely
  console.error('Transaction failed:', error)
  
  // Show generic message to user
  showError('Transaction failed. Please try again.')
}

// ❌ BAD: Expose sensitive info
catch (error) {
  alert(error.message) // Could expose private data
}
```

**Best Practices:**
- Show generic errors to users
- Log detailed errors securely
- Don't expose internal state
- Implement error boundaries
- Monitor error rates

### 4. Session Management

**Secure sessions:**

```typescript
// ✅ GOOD: Secure session management
class WalletSession {
  private static readonly SESSION_TIMEOUT = 30 * 60 * 1000 // 30 min
  private lastActivity: number = Date.now()
  
  isExpired(): boolean {
    return Date.now() - this.lastActivity > WalletSession.SESSION_TIMEOUT
  }
  
  refresh() {
    this.lastActivity = Date.now()
  }
  
  logout() {
    // Clear sensitive data
    this.wallet = null
    localStorage.removeItem('wallet')
    sessionStorage.clear()
  }
}
```

**Best Practices:**
- Implement session timeouts
- Clear data on logout
- Refresh on user activity
- Use sessionStorage for sensitive data
- Implement "remember me" securely

### 5. Content Security Policy

**Example CSP header:**

```typescript
// ✅ GOOD: Strict CSP
const csp = `
  default-src 'self';
  script-src 'self' 'unsafe-inline' 'unsafe-eval';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  font-src 'self' data:;
  connect-src 'self' https://sepolia.bundler.example.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
`
```

**Best Practices:**
- Use strict CSP headers
- Whitelist only necessary origins
- Avoid 'unsafe-inline' when possible
- Use nonces for inline scripts
- Monitor CSP violations

## Backend Security

### 1. Bundler Security

**Secure bundler configuration:**

```typescript
// ✅ GOOD: Authenticated bundler requests
const bundler = createBundlerClient({
  bundlerUrl: process.env.BUNDLER_URL!,
  headers: {
    'Authorization': `Bearer ${process.env.BUNDLER_API_KEY}`,
    'Content-Type': 'application/json',
  },
})
```

**Best Practices:**
- Use API keys for bundler access
- Implement rate limiting
- Validate UserOperations server-side
- Monitor bundler health
- Use reputable bundler services

### 2. Paymaster Security

**Secure paymaster configuration:**

```solidity
// ✅ GOOD: Secure paymaster verification
function validatePaymasterUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 maxCost
) external returns (bytes memory context, uint256 validationData) {
    // Verify signer
    require(_verifySignature(userOpHash, userOp.signature), "Invalid signature");
    
    // Check spending limits
    uint256 spent = spentAmount[userOp.sender];
    require(spent + maxCost <= spendingLimit, "Exceeds limit");
    
    // Update spent amount
    spentAmount[userOp.sender] = spent + maxCost;
    
    return ("", 0);
}
```

**Best Practices:**
- Verify signatures off-chain
- Implement spending limits
- Use time-based limits
- Monitor paymaster balance
- Implement emergency pause

### 3. API Security

**Secure API endpoints:**

```typescript
// ✅ GOOD: Authenticated & rate-limited API
app.post('/api/userOp',
  authenticate,           // Verify user
  rateLimit({            // Rate limiting
    windowMs: 15 * 60 * 1000,
    max: 100
  }),
  validateInput,         // Validate request
  async (req, res) => {
    // Process UserOperation
    const userOp = req.body
    
    // Additional validation
    if (!isValidUserOp(userOp)) {
      return res.status(400).json({ error: 'Invalid UserOp' })
    }
    
    // Submit to bundler
    const hash = await bundler.sendUserOperation(userOp)
    res.json({ hash })
  }
)
```

**Best Practices:**
- Implement authentication
- Use rate limiting
- Validate all inputs
- Use HTTPS only
- Implement CORS properly
- Monitor API usage

## Operational Security

### 1. Key Management

**Admin Keys:**
- Use hardware wallets for admin keys
- Implement multi-sig for critical operations
- Rotate keys regularly
- Use separate keys for different environments
- Never commit keys to git

**Example .env.example:**
```bash
# ✅ GOOD: Environment variables
PRIVATE_KEY=your-private-key-here
BUNDLER_API_KEY=your-api-key-here
PAYMASTER_SIGNER=your-signer-key-here

# Never commit actual .env file!
```

### 2. Monitoring

**Set up monitoring:**

```typescript
// Log critical events
contract.on('OwnerAdded', (owner) => {
  logger.info('Owner added:', owner)
  alertAdmin('New owner added')
})

contract.on('LargeTransfer', (from, to, amount) => {
  if (amount > threshold) {
    logger.warn('Large transfer detected')
    alertAdmin(`Large transfer: ${amount}`)
  }
})
```

**Monitor:**
- Unusual transaction patterns
- Failed transactions
- Gas price spikes
- Admin function calls
- Paymaster balance
- Error rates

### 3. Incident Response

**Prepare for incidents:**

1. **Detection:**
   - Set up alerts
   - Monitor dashboards
   - Review logs regularly

2. **Response Plan:**
   - Define roles and responsibilities
   - Document escalation procedures
   - Prepare communication templates
   - Test incident response

3. **Recovery:**
   - Implement emergency pause
   - Prepare upgrade procedures
   - Document recovery steps
   - Test recovery procedures

**Example Emergency Pause:**

```solidity
// Emergency pause functionality
bool public paused;
address public guardian;

modifier whenNotPaused() {
    require(!paused, "Contract paused");
    _;
}

function pause() external {
    require(msg.sender == guardian, "Only guardian");
    paused = true;
    emit Paused();
}
```

## Security Checklist

### Pre-Launch
- [ ] Complete security audit
- [ ] Run static analysis tools
- [ ] Test on testnet (3+ months)
- [ ] Review all admin functions
- [ ] Verify contract addresses
- [ ] Test deployment scripts
- [ ] Set up monitoring
- [ ] Prepare incident response
- [ ] Document security procedures
- [ ] Train team on security

### Post-Launch
- [ ] Monitor contracts 24/7
- [ ] Review logs daily
- [ ] Update dependencies
- [ ] Conduct regular security reviews
- [ ] Run bug bounty program
- [ ] Maintain incident response plan
- [ ] Communicate with users
- [ ] Keep documentation updated

## Resources

- [ConsenSys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/security)
- [OWASP Cryptographic Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html)
- [WebAuthn Security Considerations](https://www.w3.org/TR/webauthn-2/#sctn-security-considerations)

## Reporting Security Issues

If you discover a security vulnerability:

1. **DO NOT** open a public issue
2. Email: security@aakit.io
3. Include detailed description
4. Provide steps to reproduce
5. Suggest a fix if possible

We will respond within 24 hours and work with you to resolve the issue.

---

**Security is everyone's responsibility. Stay vigilant!**
