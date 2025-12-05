# AAKit NFT Minter Example

Example DApp demonstrating AAKit integration with NFT minting using passkey authentication.

## Features

- ✅ **Passkey Authentication** - Biometric sign-in
- ✅ **Smart Wallet** - ERC-4337 account abstraction
- ✅ **NFT Minting** - Mint NFTs to your wallet
- ✅ **Gasless Option** - Support for paymaster sponsorship
- ✅ **Clean UI** - Simple, intuitive interface

## Quick Start

```bash
# Install dependencies
npm install

# Update config with deployed addresses
# Edit src/config.ts

# Start dev server
npm run dev
```

Open http://localhost:5173

## How It Works

### 1. User Authentication

User creates a passkey:
```typescript
const passkey = await createPasskey({
  userId: username,
  userName: username,
  rpName: 'AAKit NFT Minter',
  rpId: window.location.hostname,
})
```

### 2. Wallet Creation

AAKit wallet is created:
```typescript
const wallet = createAAKitWallet({
  factory: CONTRACTS.factory,
  entryPoint: CONTRACTS.entryPoint,
  bundlerUrl: BUNDLER_URL,
  chain: sepolia,
  owner: { type: 'passkey', credential: passkey },
})
```

### 3. NFT Minting

User mints NFT with biometric auth:
```typescript
const mintData = encodeFunctionData({
  abi: NFT_ABI,
  functionName: 'mint',
  args: [address, tokenId],
})

const result = await wallet.sendTransaction({
  to: NFT_CONTRACT,
  data: mintData,
})

await result.wait()
```

## Configuration

Edit `src/config.ts` with your deployed addresses:

```typescript
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  factory: '0x...', // Your AAKitFactory
  paymaster: '0x...', // Optional
}

export const NFT_CONTRACT = '0x...' // Your NFT contract
export const BUNDLER_URL = 'https://...' // Your bundler
```

## Architecture

```
User (Biometric)
    ↓
Passkey (Device)
    ↓
AAKit Wallet
    ↓
Bundler
    ↓
EntryPoint
    ↓
NFT Contract (mint)
```

## Development

```bash
npm run dev      # Start dev server
npm run build    # Build for production
npm run preview  # Preview production build
```

## NFT Contract

Deploy a simple ERC721 contract with mint function:

```solidity
function mint(address to, uint256 tokenId) external {
    _mint(to, tokenId);
}
```

Or use an existing NFT contract that supports minting.

## Gasless Minting

To enable gasless minting:

1. Deploy and fund a VerifyingPaymaster
2. Add paymaster address to config
3. Minting will be sponsored!

## Browser Support

Requires WebAuthn support:
- Chrome/Edge 67+
- Firefox 60+
- Safari 13+

## Learn More

- [AAKit Documentation](../../docs/GETTING_STARTED.md)
- [SDK Integration Guide](../../docs/SDK_INTEGRATION.md)
- [DApp Integration Guide](../../docs/DAPP_INTEGRATION.md)

## License

MIT
