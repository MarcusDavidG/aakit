# AAKit Demo Wallet

React-based demo wallet showcasing AAKit SDK with passkey authentication.

## Features

- ✅ **Passkey Creation** - Register new passkeys using WebAuthn
- ✅ **Smart Wallet** - ERC-4337 account abstraction
- ✅ **Biometric Auth** - Face ID, Touch ID, Windows Hello
- ✅ **Send Transactions** - Sign with passkey
- ✅ **Wallet Dashboard** - View address, balance, deployment status

## Quick Start

```bash
# Install dependencies
npm install

# Start dev server
npm run dev
```

Open http://localhost:5173

## How It Works

### 1. Passkey Setup

User creates a passkey which generates a P-256 key pair:
- Private key: Stored securely on device (never leaves)
- Public key: Used as smart wallet owner

### 2. Smart Wallet Creation

SDK calculates counterfactual wallet address:
- Factory + Owner public key + Salt → Address
- Wallet deployed on first transaction

### 3. Transaction Signing

User initiates transaction:
1. SDK builds UserOperation
2. Passkey signs with biometric auth
3. Bundler submits to EntryPoint
4. Transaction executes on-chain

## Architecture

```
User
  ↓ (Biometric)
Passkey (Device)
  ↓ (Signature)
AAKit SDK
  ↓ (UserOp)
Bundler
  ↓ (on-chain)
EntryPoint → Smart Wallet → Target
```

## Configuration

Edit `src/config.ts`:

```typescript
export const CONTRACTS = {
  entryPoint: '0x...', // ERC-4337 v0.7
  factory: '0x...',    // AAKitFactory
  paymaster: '0x...',  // Optional
}

export const BUNDLER_URL = 'https://...'
```

## Browser Support

Requires WebAuthn support:
- Chrome/Edge 67+
- Firefox 60+
- Safari 13+

## Development

```bash
npm run dev      # Start dev server
npm run build    # Build for production
npm run preview  # Preview production build
```

## Learn More

- [AAKit Documentation](../../README.md)
- [ERC-4337](https://eips.ethereum.org/EIPS/eip-4337)
- [WebAuthn](https://webauthn.guide/)
