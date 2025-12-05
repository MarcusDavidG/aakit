# DApp Integration Guide

Learn how to integrate AAKit smart wallets with passkey authentication into your decentralized application.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Integration Steps](#integration-steps)
4. [User Onboarding](#user-onboarding)
5. [Transaction Flow](#transaction-flow)
6. [Common Patterns](#common-patterns)
7. [Testing](#testing)
8. [Production Checklist](#production-checklist)

## Overview

AAKit enables your DApp users to:
- **Sign in with biometrics** (no passwords)
- **Send gasless transactions** (via paymasters)
- **Batch multiple operations** (save gas)
- **Recover accounts** (via social recovery)

## Prerequisites

### Your DApp Needs

1. **Smart Contracts** - Your existing contracts
2. **Frontend** - React, Vue, or vanilla JS
3. **Web3 Library** - viem or ethers.js
4. **Bundler Service** - Pimlico, Stackup, or Alchemy

### User Requirements

1. **Modern Browser** - Chrome 67+, Firefox 60+, Safari 13+
2. **Biometric Device** - Touch ID, Face ID, or Windows Hello
3. **HTTPS Connection** - Required for WebAuthn

## Integration Steps

### Step 1: Install Dependencies

```bash
npm install @aakit/sdk viem
```

### Step 2: Configure AAKit

```typescript
// config/aakit.ts
import { sepolia } from 'viem/chains'

export const aakitConfig = {
  contracts: {
    entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
    factory: '0x...', // Your deployed AAKitFactory
    paymaster: '0x...', // Optional: for gasless txs
  },
  bundlerUrl: 'https://sepolia.bundler.pimlico.io/v2/YOUR-API-KEY',
  chain: sepolia,
  rpId: window.location.hostname,
  rpName: 'My DApp',
}
```

### Step 3: Create Wallet Context

```typescript
// contexts/WalletContext.tsx
import { createContext, useContext, useState, useEffect } from 'react'
import { createAAKitWallet } from '@aakit/sdk/wallet'
import { createPasskey, isWebAuthnSupported } from '@aakit/sdk/passkey'
import type { AAKitWallet } from '@aakit/sdk/wallet'
import type { PasskeyCredential } from '@aakit/sdk/passkey'
import { aakitConfig } from '../config/aakit'

interface WalletContextType {
  wallet: AAKitWallet | null
  address: string | null
  isConnected: boolean
  isDeployed: boolean
  connect: (username: string) => Promise<void>
  disconnect: () => void
  sendTransaction: (to: string, value: bigint) => Promise<string>
}

const WalletContext = createContext<WalletContextType | null>(null)

export function WalletProvider({ children }: { children: React.ReactNode }) {
  const [wallet, setWallet] = useState<AAKitWallet | null>(null)
  const [address, setAddress] = useState<string | null>(null)
  const [isDeployed, setIsDeployed] = useState(false)

  // Check for existing session
  useEffect(() => {
    const storedPasskey = localStorage.getItem('aakit-passkey')
    if (storedPasskey) {
      const passkey = JSON.parse(storedPasskey)
      restoreWallet(passkey)
    }
  }, [])

  const restoreWallet = async (passkey: PasskeyCredential) => {
    const w = createAAKitWallet({
      ...aakitConfig.contracts,
      bundlerUrl: aakitConfig.bundlerUrl,
      chain: aakitConfig.chain,
      owner: { type: 'passkey', credential: passkey },
    })

    const addr = await w.getAddress()
    const deployed = await w.isDeployed()

    setWallet(w)
    setAddress(addr)
    setIsDeployed(deployed)
  }

  const connect = async (username: string) => {
    // Check WebAuthn support
    if (!isWebAuthnSupported()) {
      throw new Error('WebAuthn not supported in this browser')
    }

    // Create passkey
    const passkey = await createPasskey({
      userId: username,
      userName: username,
      rpName: aakitConfig.rpName,
      rpId: aakitConfig.rpId,
    })

    // Store passkey info (not private key!)
    localStorage.setItem('aakit-passkey', JSON.stringify(passkey))

    // Create wallet
    await restoreWallet(passkey)
  }

  const disconnect = () => {
    localStorage.removeItem('aakit-passkey')
    setWallet(null)
    setAddress(null)
    setIsDeployed(false)
  }

  const sendTransaction = async (to: string, value: bigint) => {
    if (!wallet) throw new Error('Wallet not connected')

    const result = await wallet.sendTransaction({
      to: to as `0x${string}`,
      value,
    })

    const receipt = await result.wait()
    return receipt.transactionHash
  }

  return (
    <WalletContext.Provider
      value={{
        wallet,
        address,
        isConnected: !!wallet,
        isDeployed,
        connect,
        disconnect,
        sendTransaction,
      }}
    >
      {children}
    </WalletContext.Provider>
  )
}

export const useWallet = () => {
  const context = useContext(WalletContext)
  if (!context) throw new Error('useWallet must be used within WalletProvider')
  return context
}
```

### Step 4: Add Connect Button

```typescript
// components/ConnectButton.tsx
import { useState } from 'react'
import { useWallet } from '../contexts/WalletContext'

export function ConnectButton() {
  const { isConnected, address, connect, disconnect } = useWallet()
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)

  const handleConnect = async () => {
    if (!username) return

    setLoading(true)
    try {
      await connect(username)
    } catch (error) {
      console.error('Failed to connect:', error)
      alert('Failed to create wallet. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  if (isConnected) {
    return (
      <div>
        <span>
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </span>
        <button onClick={disconnect}>Disconnect</button>
      </div>
    )
  }

  return (
    <div>
      <input
        type="text"
        placeholder="Enter username"
        value={username}
        onChange={(e) => setUsername(e.target.value)}
        disabled={loading}
      />
      <button onClick={handleConnect} disabled={loading || !username}>
        {loading ? 'Creating wallet...' : 'Connect with Passkey'}
      </button>
    </div>
  )
}
```

### Step 5: Interact with Your Contracts

```typescript
// hooks/useNFTMint.ts
import { useState } from 'react'
import { useWallet } from '../contexts/WalletContext'
import { encodeFunctionData, parseAbi } from 'viem'

export function useNFTMint(nftContractAddress: string) {
  const { wallet } = useWallet()
  const [minting, setMinting] = useState(false)

  const mint = async (to: string, tokenId: number) => {
    if (!wallet) throw new Error('Wallet not connected')

    setMinting(true)
    try {
      // Encode mint function call
      const mintData = encodeFunctionData({
        abi: parseAbi(['function mint(address to, uint256 tokenId)']),
        functionName: 'mint',
        args: [to as `0x${string}`, BigInt(tokenId)],
      })

      // Send transaction
      const result = await wallet.sendTransaction({
        to: nftContractAddress as `0x${string}`,
        data: mintData,
      })

      // Wait for confirmation
      const receipt = await result.wait()

      if (receipt.success) {
        console.log('NFT minted:', receipt.transactionHash)
        return receipt.transactionHash
      } else {
        throw new Error('Transaction failed')
      }
    } finally {
      setMinting(false)
    }
  }

  return { mint, minting }
}

// Usage in component
function MintButton() {
  const { address } = useWallet()
  const { mint, minting } = useNFTMint('0x...')

  const handleMint = async () => {
    try {
      const txHash = await mint(address!, 1)
      alert(`NFT minted! TX: ${txHash}`)
    } catch (error) {
      alert('Failed to mint NFT')
    }
  }

  return (
    <button onClick={handleMint} disabled={minting}>
      {minting ? 'Minting...' : 'Mint NFT'}
    </button>
  )
}
```

## User Onboarding

### Complete Onboarding Flow

```typescript
// components/OnboardingFlow.tsx
import { useState } from 'react'
import { useWallet } from '../contexts/WalletContext'

type Step = 'intro' | 'create-passkey' | 'fund-wallet' | 'complete'

export function OnboardingFlow() {
  const [step, setStep] = useState<Step>('intro')
  const { connect, address } = useWallet()

  const handleCreatePasskey = async (username: string) => {
    await connect(username)
    setStep('fund-wallet')
  }

  return (
    <div>
      {step === 'intro' && (
        <div>
          <h2>Welcome to My DApp!</h2>
          <p>Create your wallet in seconds with biometric authentication.</p>
          <button onClick={() => setStep('create-passkey')}>
            Get Started
          </button>
        </div>
      )}

      {step === 'create-passkey' && (
        <PasskeyCreation onSuccess={handleCreatePasskey} />
      )}

      {step === 'fund-wallet' && (
        <div>
          <h2>Fund Your Wallet</h2>
          <p>Your wallet address:</p>
          <code>{address}</code>
          <p>Send some ETH to get started!</p>
          <button onClick={() => setStep('complete')}>Continue</button>
        </div>
      )}

      {step === 'complete' && (
        <div>
          <h2>You're All Set!</h2>
          <p>Your wallet is ready to use.</p>
        </div>
      )}
    </div>
  )
}
```

## Transaction Flow

### Gasless Transaction Flow

```typescript
// With paymaster configured, transactions are automatically gasless
const result = await wallet.sendTransaction({
  to: contractAddress,
  data: encodedFunctionCall,
})
```

### Batch Transaction Flow

```typescript
// Multiple operations in one transaction
import { encodeFunctionData } from 'viem'

const approve = encodeFunctionData({
  abi: erc20Abi,
  functionName: 'approve',
  args: [spender, amount],
})

const swap = encodeFunctionData({
  abi: dexAbi,
  functionName: 'swap',
  args: [tokenIn, tokenOut, amount],
})

const result = await wallet.sendBatchTransaction({
  transactions: [
    { to: tokenAddress, data: approve },
    { to: dexAddress, data: swap },
  ],
})
```

## Common Patterns

### Pattern 1: Token Approval + Transfer

```typescript
async function approveAndTransfer(
  tokenAddress: string,
  spender: string,
  amount: bigint
) {
  const approveData = encodeFunctionData({
    abi: erc20Abi,
    functionName: 'approve',
    args: [spender, amount],
  })

  const transferData = encodeFunctionData({
    abi: erc20Abi,
    functionName: 'transfer',
    args: [recipient, amount],
  })

  return wallet.sendBatchTransaction({
    transactions: [
      { to: tokenAddress, data: approveData },
      { to: tokenAddress, data: transferData },
    ],
  })
}
```

### Pattern 2: Multi-Step DeFi Interaction

```typescript
async function supplyAndBorrow(
  protocolAddress: string,
  supplyAmount: bigint,
  borrowAmount: bigint
) {
  const supply = encodeFunctionData({
    abi: lendingAbi,
    functionName: 'supply',
    args: [collateralToken, supplyAmount],
  })

  const borrow = encodeFunctionData({
    abi: lendingAbi,
    functionName: 'borrow',
    args: [borrowToken, borrowAmount],
  })

  return wallet.sendBatchTransaction({
    transactions: [
      { to: protocolAddress, data: supply },
      { to: protocolAddress, data: borrow },
    ],
  })
}
```

### Pattern 3: NFT Batch Minting

```typescript
async function batchMintNFTs(
  nftContract: string,
  recipients: string[],
  tokenIds: number[]
) {
  const transactions = recipients.map((recipient, i) => ({
    to: nftContract,
    data: encodeFunctionData({
      abi: parseAbi(['function mint(address,uint256)']),
      functionName: 'mint',
      args: [recipient, BigInt(tokenIds[i])],
    }),
  }))

  return wallet.sendBatchTransaction({ transactions })
}
```

## Testing

### Test on Testnet First

```typescript
// Use Sepolia for testing
const testConfig = {
  contracts: {
    entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
    factory: '0x...', // Sepolia deployment
  },
  bundlerUrl: 'https://sepolia.bundler.pimlico.io/...',
  chain: sepolia,
}
```

### Mock Wallet for Development

```typescript
// For local development without WebAuthn
class MockWallet {
  async sendTransaction(params: TransactionParams) {
    console.log('Mock transaction:', params)
    return {
      userOpHash: '0x123...',
      wait: async () => ({
        success: true,
        transactionHash: '0xabc...',
      }),
    }
  }
}

const wallet = isDevelopment ? new MockWallet() : createAAKitWallet(...)
```

## Production Checklist

### Pre-Launch

- [ ] Test all transaction flows on testnet
- [ ] Verify WebAuthn works on all target browsers
- [ ] Test with different biometric devices
- [ ] Implement error handling for all scenarios
- [ ] Add loading states and user feedback
- [ ] Test wallet recovery flow
- [ ] Verify gas estimation accuracy
- [ ] Test batch transactions
- [ ] Implement analytics/monitoring
- [ ] Prepare user documentation

### Security

- [ ] Use HTTPS in production
- [ ] Validate all user inputs
- [ ] Implement rate limiting
- [ ] Monitor for suspicious activity
- [ ] Have incident response plan
- [ ] Regular security audits
- [ ] Keep dependencies updated
- [ ] Follow AAKit security guidelines

### User Experience

- [ ] Clear onboarding flow
- [ ] Helpful error messages
- [ ] Loading indicators
- [ ] Transaction confirmations
- [ ] Wallet address display
- [ ] Balance updates
- [ ] Transaction history
- [ ] Help/support links

## Example DApps

See `/examples` directory:
- `demo-dapp` - Complete DApp integration
- `demo-wallet` - Standalone wallet

## Troubleshooting

### Issue: WebAuthn Not Working

**Check:**
1. Using HTTPS (or localhost)
2. Browser supports WebAuthn
3. User has biometric hardware
4. rpId matches domain

### Issue: Transaction Fails

**Check:**
1. Wallet is deployed
2. Wallet has sufficient funds
3. Gas parameters are correct
4. Contract call is valid
5. Bundler is responding

### Issue: Passkey Not Found

**Check:**
1. Passkey was created successfully
2. Same device being used
3. Passkey not deleted
4. rpId hasn't changed

## Resources

- [SDK Integration Guide](./SDK_INTEGRATION.md)
- [Security Best Practices](./SECURITY_BEST_PRACTICES.md)
- [Getting Started](./GETTING_STARTED.md)
- [API Reference](./API_REFERENCE.md)

## Support

- **GitHub:** [Issues & Discussions](https://github.com/your-org/aakit)
- **Discord:** [Join Community](https://discord.gg/aakit)
- **Docs:** [docs.aakit.io](https://docs.aakit.io)

---

**Ready to integrate?** Start with our [Quick Start Guide](./GETTING_STARTED.md)
