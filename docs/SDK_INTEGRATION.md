# SDK Integration Guide

Advanced guide for integrating AAKit SDK into your application.

## Table of Contents

1. [Installation](#installation)
2. [Basic Setup](#basic-setup)
3. [Advanced UserOperations](#advanced-useroperations)
4. [Batch Transactions](#batch-transactions)
5. [Gas Management](#gas-management)
6. [Error Handling](#error-handling)
7. [Custom Modules](#custom-modules)
8. [Production Tips](#production-tips)

## Installation

```bash
npm install @aakit/sdk viem
```

## Basic Setup

### 1. Initialize Configuration

```typescript
import { createAAKitWallet } from '@aakit/sdk/wallet'
import { sepolia } from 'viem/chains'

const config = {
  factory: '0x...', // Your AAKitFactory address
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  bundlerUrl: 'https://sepolia.bundler.example.com',
  chain: sepolia,
}
```

### 2. Create Wallet Instance

```typescript
// With passkey
const wallet = createAAKitWallet({
  ...config,
  owner: {
    type: 'passkey',
    credential: passkeyCredential,
  },
})

// With EOA
const wallet = createAAKitWallet({
  ...config,
  owner: {
    type: 'eoa',
    address: '0x...',
    signer: walletClient,
  },
})
```

## Advanced UserOperations

### Manual UserOp Construction

```typescript
import {
  buildUserOperation,
  encodeExecutionMode,
  encodeSingleExecution,
} from '@aakit/sdk/core'
import { encodeFunctionData, parseAbi } from 'viem'

// 1. Encode your contract call
const callData = encodeFunctionData({
  abi: parseAbi(['function mint(address to, uint256 tokenId)']),
  functionName: 'mint',
  args: ['0x...', 1n],
})

// 2. Encode execution
const mode = encodeExecutionMode({ callType: 'call', execType: 'revert' })
const executionData = encodeSingleExecution(
  '0x...', // NFT contract
  0n,      // No ETH
  callData
)

// 3. Build UserOp
const userOp = buildUserOperation({
  sender: await wallet.getAddress(),
  nonce: await wallet.getNonce(),
  callData: executionData,
  callGasLimit: 200_000n,
  verificationGasLimit: 150_000n,
  preVerificationGas: 50_000n,
  maxFeePerGas: parseGwei('20'),
  maxPriorityFeePerGas: parseGwei('2'),
})
```

### Gas Estimation

```typescript
import { createBundlerClient } from '@aakit/sdk/core'

const bundler = createBundlerClient({
  bundlerUrl: config.bundlerUrl,
  entryPoint: config.entryPoint,
})

// Estimate gas for UserOp
const gasEstimate = await bundler.estimateUserOperationGas(
  userOp,
  config.entryPoint
)

console.log('Gas estimate:', {
  callGasLimit: gasEstimate.callGasLimit,
  verificationGasLimit: gasEstimate.verificationGasLimit,
  preVerificationGas: gasEstimate.preVerificationGas,
})

// Update UserOp with estimates
userOp.callGasLimit = gasEstimate.callGasLimit
userOp.verificationGasLimit = gasEstimate.verificationGasLimit
userOp.preVerificationGas = gasEstimate.preVerificationGas
```

## Batch Transactions

### Simple Batch

```typescript
const result = await wallet.sendBatchTransaction({
  transactions: [
    { to: '0x...', value: parseEther('0.1') },
    { to: '0x...', value: parseEther('0.05') },
    { to: '0x...', data: '0x...' },
  ],
})

await result.wait()
```

### Complex Batch with Contract Calls

```typescript
import { encodeFunctionData } from 'viem'

// Approve + Transfer in one transaction
const approveCall = encodeFunctionData({
  abi: erc20Abi,
  functionName: 'approve',
  args: ['0xSpenderAddress', parseEther('100')],
})

const transferCall = encodeFunctionData({
  abi: erc20Abi,
  functionName: 'transfer',
  args: ['0xRecipient', parseEther('50')],
})

const result = await wallet.sendBatchTransaction({
  transactions: [
    { to: tokenAddress, data: approveCall },
    { to: tokenAddress, data: transferCall },
  ],
})

const receipt = await result.wait()
console.log('Batch executed:', receipt.success)
```

## Gas Management

### Dynamic Gas Pricing

```typescript
import { formatGwei } from 'viem'

async function getOptimalGasPrices(publicClient) {
  // Get current gas price
  const gasPrice = await publicClient.getGasPrice()
  
  // Add 10% buffer for priority
  const maxFeePerGas = (gasPrice * 11n) / 10n
  const maxPriorityFeePerGas = parseGwei('2')
  
  console.log('Gas prices:', {
    base: formatGwei(gasPrice),
    maxFee: formatGwei(maxFeePerGas),
    priority: formatGwei(maxPriorityFeePerGas),
  })
  
  return { maxFeePerGas, maxPriorityFeePerGas }
}
```

### Gas Sponsorship with Paymaster

```typescript
const wallet = createAAKitWallet({
  ...config,
  paymaster: {
    address: '0x...', // VerifyingPaymaster
  },
})

// Transactions are now gasless!
const result = await wallet.sendTransaction({
  to: '0x...',
  value: parseEther('0.1'),
})
```

## Error Handling

### Comprehensive Error Handling

```typescript
async function sendTransactionWithRetry(
  wallet: AAKitWallet,
  params: TransactionParams,
  maxRetries = 3
) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const result = await wallet.sendTransaction(params)
      const receipt = await result.wait()
      
      if (receipt.success) {
        return receipt
      } else {
        throw new Error('Transaction reverted')
      }
    } catch (error) {
      console.error(`Attempt ${attempt + 1} failed:`, error)
      
      if (error.message.includes('insufficient funds')) {
        throw new Error('Wallet needs funding')
      }
      
      if (error.message.includes('nonce too low')) {
        // Wait and retry with new nonce
        await new Promise(resolve => setTimeout(resolve, 1000))
        continue
      }
      
      if (error.message.includes('user cancelled')) {
        throw new Error('User cancelled authentication')
      }
      
      if (attempt === maxRetries - 1) {
        throw error
      }
      
      // Exponential backoff
      await new Promise(resolve => 
        setTimeout(resolve, 1000 * Math.pow(2, attempt))
      )
    }
  }
}
```

### Transaction Status Monitoring

```typescript
import { waitForUserOperation } from '@aakit/sdk/core'

async function monitorTransaction(bundler, userOpHash: Hex) {
  console.log('Monitoring transaction:', userOpHash)
  
  const startTime = Date.now()
  
  try {
    const receipt = await waitForUserOperation(
      bundler,
      userOpHash,
      {
        timeout: 60_000, // 60 seconds
        interval: 2_000,  // Check every 2 seconds
      }
    )
    
    const duration = Date.now() - startTime
    
    console.log('Transaction confirmed:', {
      hash: receipt.receipt.transactionHash,
      gasUsed: receipt.actualGasUsed,
      duration: `${duration}ms`,
      success: receipt.success,
    })
    
    return receipt
  } catch (error) {
    console.error('Transaction failed:', error)
    throw error
  }
}
```

## Custom Modules

### Installing a Validator Module

```typescript
import { encodeFunctionData } from 'viem'

// Install PasskeyValidator module
const moduleAddress = '0x...' // PasskeyValidator
const moduleType = 1 // Validator

const installData = encodeFunctionData({
  abi: parseAbi([
    'function installModule(uint256 moduleTypeId, address module, bytes calldata initData)',
  ]),
  functionName: 'installModule',
  args: [moduleType, moduleAddress, '0x'],
})

const result = await wallet.sendTransaction({
  to: await wallet.getAddress(), // Self-call
  data: installData,
})

await result.wait()
console.log('Module installed')
```

### Querying Installed Modules

```typescript
import { createPublicClient, http } from 'viem'

const publicClient = createPublicClient({
  chain: sepolia,
  transport: http(),
})

const isInstalled = await publicClient.readContract({
  address: await wallet.getAddress(),
  abi: parseAbi([
    'function isModuleInstalled(uint256 moduleTypeId, address module, bytes calldata additionalContext) view returns (bool)',
  ]),
  functionName: 'isModuleInstalled',
  args: [1, moduleAddress, '0x'],
})

console.log('Module installed:', isInstalled)
```

## Production Tips

### 1. Wallet State Management

```typescript
class WalletManager {
  private wallet: AAKitWallet | null = null
  private address: Address | null = null
  
  async initialize(passkey: PasskeyCredential) {
    this.wallet = createAAKitWallet({
      ...config,
      owner: { type: 'passkey', credential: passkey },
    })
    
    this.address = await this.wallet.getAddress()
    
    // Check deployment
    const deployed = await this.wallet.isDeployed()
    if (!deployed) {
      console.warn('Wallet not deployed yet')
    }
    
    return this.wallet
  }
  
  async sendTransaction(params: TransactionParams) {
    if (!this.wallet) throw new Error('Wallet not initialized')
    return this.wallet.sendTransaction(params)
  }
  
  getAddress() {
    return this.address
  }
  
  cleanup() {
    this.wallet = null
    this.address = null
  }
}
```

### 2. Transaction Queue

```typescript
class TransactionQueue {
  private queue: TransactionParams[] = []
  private processing = false
  
  add(tx: TransactionParams) {
    this.queue.push(tx)
    this.process()
  }
  
  async process() {
    if (this.processing || this.queue.length === 0) return
    
    this.processing = true
    
    while (this.queue.length > 0) {
      const tx = this.queue.shift()!
      
      try {
        const result = await wallet.sendTransaction(tx)
        await result.wait()
        console.log('Transaction completed')
      } catch (error) {
        console.error('Transaction failed:', error)
        // Optionally re-queue
      }
    }
    
    this.processing = false
  }
}
```

### 3. Caching

```typescript
class WalletCache {
  private cache = new Map<string, any>()
  private ttl = 60_000 // 60 seconds
  
  async get(key: string, fetcher: () => Promise<any>) {
    const cached = this.cache.get(key)
    
    if (cached && Date.now() - cached.timestamp < this.ttl) {
      return cached.value
    }
    
    const value = await fetcher()
    
    this.cache.set(key, {
      value,
      timestamp: Date.now(),
    })
    
    return value
  }
  
  invalidate(key: string) {
    this.cache.delete(key)
  }
  
  clear() {
    this.cache.clear()
  }
}

// Usage
const cache = new WalletCache()

const address = await cache.get('wallet-address', () =>
  wallet.getAddress()
)

const deployed = await cache.get('wallet-deployed', () =>
  wallet.isDeployed()
)
```

### 4. Event Monitoring

```typescript
import { createPublicClient, http, parseEventLogs } from 'viem'

async function monitorWalletEvents(walletAddress: Address) {
  const publicClient = createPublicClient({
    chain: sepolia,
    transport: http(),
  })
  
  // Watch for Executed events
  const unwatch = publicClient.watchEvent({
    address: walletAddress,
    event: parseAbi([
      'event Executed(address indexed target, uint256 value, bytes data)',
    ])[0],
    onLogs: (logs) => {
      console.log('Transaction executed:', logs)
      
      // Handle event
      logs.forEach(log => {
        console.log('Target:', log.args.target)
        console.log('Value:', log.args.value)
      })
    },
  })
  
  // Cleanup
  return unwatch
}
```

### 5. Performance Optimization

```typescript
// Parallel operations
const [address, deployed, nonce] = await Promise.all([
  wallet.getAddress(),
  wallet.isDeployed(),
  wallet.getNonce(),
])

// Batch UserOps instead of sequential
const result = await wallet.sendBatchTransaction({
  transactions: [
    // Multiple operations in one UserOp
  ],
})
```

## Best Practices

1. **Always validate inputs**
2. **Handle errors gracefully**
3. **Cache when possible**
4. **Monitor gas prices**
5. **Test on testnet first**
6. **Use batch transactions**
7. **Implement retry logic**
8. **Monitor wallet events**
9. **Keep SDK updated**
10. **Follow security guidelines**

## Examples

See `/examples` directory for complete implementations:
- `demo-wallet` - React wallet with passkey auth
- `demo-dapp` - DApp integration example

## Resources

- [API Reference](./API_REFERENCE.md)
- [Security Best Practices](./SECURITY_BEST_PRACTICES.md)
- [Getting Started](./GETTING_STARTED.md)

---

**Need help?** [Join our Discord](https://discord.gg/aakit)
