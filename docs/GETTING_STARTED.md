# Getting Started with AAKit

Welcome to AAKit! This guide will help you integrate ERC-4337 smart wallets with passkey authentication into your application.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Core Concepts](#core-concepts)
5. [Integration Steps](#integration-steps)
6. [Common Patterns](#common-patterns)
7. [Troubleshooting](#troubleshooting)
8. [Next Steps](#next-steps)

## Prerequisites

### Required Knowledge
- Basic understanding of Ethereum and smart contracts
- Familiarity with TypeScript/JavaScript
- Basic React knowledge (for frontend integration)
- Understanding of ERC-4337 Account Abstraction (helpful but not required)

### Development Environment
- Node.js v18 or higher
- npm or yarn package manager
- Modern web browser with WebAuthn support
- Ethereum wallet (for testnet deployment)

### Browser Requirements
AAKit uses WebAuthn for passkey authentication. Supported browsers:
- **Chrome/Edge:** Version 67+
- **Firefox:** Version 60+
- **Safari:** Version 13+
- **Opera:** Version 54+

Check support in your app:
```typescript
import { isWebAuthnSupported } from '@aakit/sdk/passkey'

if (!isWebAuthnSupported()) {
  console.error('WebAuthn not supported in this browser')
}
```

## Installation

### Install SDK

```bash
npm install @aakit/sdk viem
```

Or with yarn:
```bash
yarn add @aakit/sdk viem
```

### Install Additional Dependencies (Optional)

For React applications:
```bash
npm install wagmi @tanstack/react-query
```

## Quick Start

### 1. Create a Passkey Wallet

```typescript
import { createAAKitWallet, createPasskey } from '@aakit/sdk'
import { sepolia } from 'viem/chains'
import { parseEther } from 'viem'

// Step 1: Create a passkey with biometric authentication
const passkey = await createPasskey({
  userId: 'user@example.com',
  userName: 'Alice',
  rpName: 'My DApp',
  rpId: window.location.hostname, // Your domain
})

console.log('Passkey created:', {
  id: passkey.id,
  publicKeyX: passkey.publicKeyX,
  publicKeyY: passkey.publicKeyY,
})

// Step 2: Create smart wallet instance
const wallet = createAAKitWallet({
  factory: '0x...', // AAKitFactory contract address
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032', // ERC-4337 v0.7
  bundlerUrl: 'https://sepolia.bundler.example.com',
  chain: sepolia,
  owner: {
    type: 'passkey',
    credential: passkey,
  },
})

// Step 3: Get wallet address (counterfactual)
const address = await wallet.getAddress()
console.log('Wallet address:', address)

// Step 4: Check deployment status
const deployed = await wallet.isDeployed()
console.log('Deployed:', deployed)

// Step 5: Send a transaction
const result = await wallet.sendTransaction({
  to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  value: parseEther('0.01'),
})

console.log('UserOperation hash:', result.userOpHash)

// Step 6: Wait for confirmation
const receipt = await result.wait()
console.log('Transaction successful:', receipt.success)
```

### 2. Build a UserOperation Manually

```typescript
import { buildUserOperation, createBundlerClient } from '@aakit/sdk/core'

// Create bundler client
const bundler = createBundlerClient({
  bundlerUrl: 'https://sepolia.bundler.example.com',
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
})

// Build UserOperation
const userOp = buildUserOperation({
  sender: '0x...', // Your wallet address
  nonce: 0n,
  callData: '0x...', // Encoded function call
  callGasLimit: 100_000n,
  verificationGasLimit: 100_000n,
  preVerificationGas: 21_000n,
  maxFeePerGas: parseGwei('10'),
  maxPriorityFeePerGas: parseGwei('1'),
})

// Send to bundler
const userOpHash = await bundler.sendUserOperation(
  userOp,
  '0x0000000071727De22E5E9d8BAf0edAc6f37da032'
)

console.log('UserOp submitted:', userOpHash)
```

## Core Concepts

### 1. Passkeys (WebAuthn)

Passkeys are cryptographic credentials stored securely on your device:

**Benefits:**
- No passwords to remember
- Biometric authentication (Face ID, Touch ID, etc.)
- Hardware-backed security
- Phishing resistant
- Cross-device sync (via cloud keychain)

**How it works:**
1. User registers a passkey → Device generates P-256 key pair
2. Private key stays on device (never transmitted)
3. Public key becomes wallet owner
4. User signs transactions with biometric auth

### 2. Smart Wallets (ERC-4337)

Smart contract wallets with advanced features:

**Benefits:**
- Gasless transactions (via paymasters)
- Account recovery
- Batch transactions
- Flexible authentication
- Programmable security

**Components:**
- **Wallet Contract:** Your smart contract account
- **EntryPoint:** ERC-4337 singleton contract
- **Bundler:** Service that submits UserOperations
- **Paymaster:** Optional gas sponsor

### 3. UserOperations

Transactions for smart wallets:

```typescript
interface PackedUserOperation {
  sender: Address           // Wallet address
  nonce: bigint            // Anti-replay
  initCode: Hex            // Factory + initialization (for undeployed wallets)
  callData: Hex            // Execution data
  accountGasLimits: Hex    // Packed verification + call gas
  preVerificationGas: bigint // Bundler compensation
  gasFees: Hex             // Packed priority + max fees
  paymasterAndData: Hex    // Paymaster + data (for sponsored txs)
  signature: Hex           // Wallet signature
}
```

### 4. Counterfactual Addresses

Wallet addresses can be calculated before deployment:

```typescript
// Calculate address before deployment
const address = await wallet.getAddress()

// Send funds to address
// ...

// First transaction deploys the wallet
const result = await wallet.sendTransaction({...})
```

## Integration Steps

### Step 1: Set Up Infrastructure

**1. Deploy Contracts (or use existing)**

For testnet:
```bash
cd contracts
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast
```

**2. Set Up Bundler**

Use a bundler service:
- [Pimlico](https://pimlico.io/)
- [Stackup](https://www.stackup.sh/)
- [Alchemy](https://www.alchemy.com/account-abstraction)
- Self-hosted bundler

**3. Configure Your App**

```typescript
// config.ts
export const CONFIG = {
  contracts: {
    entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
    factory: '0x...', // Your AAKitFactory
    paymaster: '0x...', // Optional
  },
  bundlerUrl: 'https://sepolia.bundler.example.com',
  chain: sepolia,
}
```

### Step 2: Implement Passkey Authentication

**Register Passkey:**

```typescript
import { createPasskey } from '@aakit/sdk/passkey'

async function registerPasskey(userId: string, userName: string) {
  try {
    const passkey = await createPasskey({
      userId,
      userName,
      rpName: 'My DApp',
      rpId: window.location.hostname,
      authenticatorAttachment: 'platform', // Use device authenticator
      userVerification: 'required', // Require biometric
    })

    // Store passkey info (not the private key!)
    localStorage.setItem('passkey', JSON.stringify({
      id: passkey.id,
      publicKeyX: passkey.publicKeyX,
      publicKeyY: passkey.publicKeyY,
    }))

    return passkey
  } catch (error) {
    console.error('Failed to create passkey:', error)
    throw error
  }
}
```

**Authenticate with Passkey:**

```typescript
import { authenticateWithPasskey } from '@aakit/sdk/passkey'

async function signWithPasskey(challenge: Uint8Array, credentialId: string) {
  try {
    const assertion = await authenticateWithPasskey({
      rpId: window.location.hostname,
      challenge,
      credentialId,
      userVerification: 'required',
    })

    return assertion
  } catch (error) {
    console.error('Failed to authenticate:', error)
    throw error
  }
}
```

### Step 3: Create Wallet Instance

```typescript
import { createAAKitWallet } from '@aakit/sdk/wallet'

function createWallet(passkey: PasskeyCredential) {
  return createAAKitWallet({
    factory: CONFIG.contracts.factory,
    entryPoint: CONFIG.contracts.entryPoint,
    bundlerUrl: CONFIG.bundlerUrl,
    chain: CONFIG.chain,
    owner: {
      type: 'passkey',
      credential: passkey,
    },
    paymaster: CONFIG.contracts.paymaster ? {
      address: CONFIG.contracts.paymaster,
    } : undefined,
  })
}
```

### Step 4: Implement Transaction Flow

```typescript
async function sendTransaction(
  wallet: AAKitWallet,
  to: Address,
  value: bigint,
  data?: Hex
) {
  try {
    // Send transaction (triggers passkey authentication)
    const result = await wallet.sendTransaction({
      to,
      value,
      data,
    })

    console.log('Transaction submitted:', result.userOpHash)

    // Wait for confirmation
    const receipt = await result.wait()

    if (receipt.success) {
      console.log('Transaction confirmed:', receipt.transactionHash)
      return receipt
    } else {
      throw new Error('Transaction failed')
    }
  } catch (error) {
    console.error('Transaction error:', error)
    throw error
  }
}
```

### Step 5: Handle Batch Transactions

```typescript
async function sendBatch(wallet: AAKitWallet) {
  const result = await wallet.sendBatchTransaction({
    transactions: [
      { to: '0x...', value: parseEther('0.01') },
      { to: '0x...', data: '0x...' },
      { to: '0x...', value: parseEther('0.005'), data: '0x...' },
    ],
  })

  const receipt = await result.wait()
  console.log('Batch executed:', receipt.success)
}
```

## Common Patterns

### Pattern 1: Onboarding Flow

```typescript
async function onboardUser(email: string, username: string) {
  // 1. Check WebAuthn support
  if (!isWebAuthnSupported()) {
    throw new Error('WebAuthn not supported')
  }

  // 2. Create passkey
  const passkey = await createPasskey({
    userId: email,
    userName: username,
    rpName: 'My DApp',
    rpId: window.location.hostname,
  })

  // 3. Create wallet
  const wallet = createWallet(passkey)
  const address = await wallet.getAddress()

  // 4. Store credentials (securely!)
  localStorage.setItem('wallet', JSON.stringify({
    passkeyId: passkey.id,
    address,
  }))

  // 5. Show funding instructions
  return {
    passkey,
    wallet,
    address,
  }
}
```

### Pattern 2: Session Management

```typescript
interface WalletSession {
  wallet: AAKitWallet
  address: Address
  passkeyId: string
}

async function restoreSession(): Promise<WalletSession | null> {
  // Load from storage
  const stored = localStorage.getItem('wallet')
  if (!stored) return null

  const { passkeyId, address } = JSON.parse(stored)

  // Load passkey info
  const passkeyData = localStorage.getItem('passkey')
  if (!passkeyData) return null

  const passkey = JSON.parse(passkeyData)

  // Recreate wallet
  const wallet = createWallet(passkey)

  return { wallet, address, passkeyId }
}
```

### Pattern 3: Gasless Transactions

```typescript
async function sendGaslessTransaction(
  wallet: AAKitWallet,
  to: Address,
  value: bigint
) {
  // Paymaster automatically sponsors gas if configured
  const result = await wallet.sendTransaction({
    to,
    value,
  })

  console.log('Gasless transaction submitted')
  return result.wait()
}
```

### Pattern 4: Error Handling

```typescript
async function robustTransaction(wallet: AAKitWallet, params: TransactionParams) {
  try {
    const result = await wallet.sendTransaction(params)
    const receipt = await result.wait()
    return receipt
  } catch (error) {
    if (error.message.includes('UserOperation reverted')) {
      console.error('Transaction reverted on-chain')
      // Handle revert
    } else if (error.message.includes('insufficient funds')) {
      console.error('Wallet needs funding')
      // Show funding UI
    } else if (error.message.includes('user cancelled')) {
      console.log('User cancelled authentication')
      // Handle cancellation
    } else {
      console.error('Unknown error:', error)
      // Show generic error
    }
    throw error
  }
}
```

## Troubleshooting

### Issue: WebAuthn Not Supported

**Problem:** Browser doesn't support WebAuthn

**Solution:**
```typescript
if (!isWebAuthnSupported()) {
  // Show upgrade message
  alert('Please use a modern browser (Chrome 67+, Firefox 60+, Safari 13+)')
}
```

### Issue: Passkey Creation Fails

**Possible Causes:**
1. **Not HTTPS:** WebAuthn requires HTTPS (or localhost)
2. **User cancelled:** User dismissed biometric prompt
3. **No authenticator:** Device doesn't have biometric hardware

**Solution:**
```typescript
try {
  const passkey = await createPasskey({...})
} catch (error) {
  if (error.name === 'NotAllowedError') {
    console.log('User cancelled passkey creation')
  } else if (error.name === 'NotSupportedError') {
    console.log('No authenticator available')
  } else {
    console.error('Unknown error:', error)
  }
}
```

### Issue: Transaction Fails

**Check:**
1. Wallet has sufficient balance
2. Gas parameters are correct
3. Bundler is reachable
4. Smart contracts are deployed

**Debug:**
```typescript
// Check deployment
const deployed = await wallet.isDeployed()
console.log('Deployed:', deployed)

// Check bundler
const entryPoints = await bundler.getSupportedEntryPoints()
console.log('Supported EntryPoints:', entryPoints)

// Estimate gas
const estimate = await bundler.estimateUserOperationGas(userOp, entryPoint)
console.log('Gas estimate:', estimate)
```

### Issue: Counterfactual Address Wrong

**Problem:** Address doesn't match expected

**Solution:** Ensure consistent salt and owner bytes:
```typescript
// Always use same salt for same owner
const salt = 0n

// Ensure owner bytes are formatted correctly
const ownerBytes = `${passkey.publicKeyX}${passkey.publicKeyY.slice(2)}`
```

## Next Steps

Now that you understand the basics:

1. **Read the Integration Guide:** [SDK_INTEGRATION.md](./SDK_INTEGRATION.md)
2. **Review Security Practices:** [SECURITY_BEST_PRACTICES.md](./SECURITY_BEST_PRACTICES.md)
3. **Explore Examples:** Check `/examples` directory
4. **Join Community:** [GitHub Discussions](https://github.com/your-org/aakit/discussions)

## Additional Resources

- [ERC-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [WebAuthn Guide](https://webauthn.guide/)
- [AAKit Architecture](./ARCHITECTURE.md)
- [API Reference](./API_REFERENCE.md)

## Support

- **GitHub Issues:** [Report bugs](https://github.com/your-org/aakit/issues)
- **Discussions:** [Ask questions](https://github.com/your-org/aakit/discussions)
- **Discord:** [Join community](https://discord.gg/aakit)
- **Twitter:** [@AAKit](https://twitter.com/aakit)

---

**Next:** [SDK Integration Guide →](./SDK_INTEGRATION.md)
