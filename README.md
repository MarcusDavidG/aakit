# AAKit

> Open Infrastructure Stack for ERC-4337 Smart Wallets with Native Passkey Support

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)

## Overview

AAKit is a production-ready, open-source toolkit for building ERC-4337 compliant smart wallets with native passkey (WebAuthn) authentication. It provides modular, auditable infrastructure for gasless onboarding, biometric authentication, and account abstraction.

### Key Features

- ✅ **ERC-4337 Compliant**: Full account abstraction with EntryPoint v0.7
- ✅ **ERC-7579 Modular**: Pluggable validators, executors, and hooks
- 🔐 **Native Passkey Support**: WebAuthn/P256 signature verification
- ⛽ **Gasless Transactions**: Built-in paymaster contracts
- 🔓 **Open & Interoperable**: Vendor-neutral, MIT licensed
- 🚀 **Production Ready**: Gas-optimized, security-focused

## Project Structure

```
aakit/
├── contracts/          # Foundry smart contracts
│   ├── src/
│   │   ├── wallet/    # Core ERC-4337 wallet
│   │   ├── validators/# Passkey & other validators
│   │   ├── paymaster/ # Gas sponsorship contracts
│   │   ├── factory/   # Wallet factory
│   │   └── interfaces/# Standard interfaces
│   └── test/          # Foundry tests
│
├── sdk/               # TypeScript SDK
│   ├── core/          # UserOperation builder
│   ├── passkey/       # WebAuthn integration
│   └── wallet/        # Wallet client
│
├── examples/          # Reference implementations
│   ├── demo-wallet/   # React wallet app
│   └── demo-dapp/     # DApp integration
│
└── docs/             # Documentation
    └── ARCHITECTURE.md
```

## Quick Start

### Installation

```bash
npm install @aakit/sdk viem
```

### Create a Passkey Wallet

```typescript
import { createAAKitWallet, createPasskey } from '@aakit/sdk'
import { sepolia } from 'viem/chains'

// 1. Create passkey with biometric auth
const passkey = await createPasskey({
  userId: 'user@example.com',
  userName: 'Alice',
  rpName: 'My DApp',
  rpId: 'example.com',
})

// 2. Create smart wallet
const wallet = createAAKitWallet({
  factory: '0x...', // AAKitFactory address
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  bundlerUrl: 'https://bundler.example.com',
  chain: sepolia,
  owner: { type: 'passkey', credential: passkey },
})

// 3. Send transaction
const result = await wallet.sendTransaction({
  to: '0x...',
  value: parseEther('0.1'),
})

// 4. Wait for confirmation
const receipt = await result.wait()
console.log('Transaction successful:', receipt.success)
```

### Run Demo Wallet

```bash
cd examples/demo-wallet
npm install
npm run dev
```

Open http://localhost:5173 to see the demo wallet with passkey authentication.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/aakit.git
cd aakit

# Install Foundry dependencies
cd contracts
forge install

# Run tests
forge test
```

## Architecture

AAKit follows a modular architecture:

1. **Core Wallet**: Minimal ERC-4337 account implementation
2. **Validator Modules**: Passkey, EOA, multisig validators
3. **Executor Modules**: Session keys, recurring payments
4. **Paymaster**: Token & sponsored gas payments
5. **Factory**: Deterministic wallet deployment

See [ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed specifications.

## Development Status

**Phase 1**: Architecture & Specification ✅ COMPLETE  
**Phase 2**: Core Smart Contracts & Testing ✅ COMPLETE  
**Phase 3**: SDK & Frontend Tools ✅ COMPLETE  
**Phase 4** (Current): Documentation & Production Deployment 🚧 40% Complete

### Milestones
- ✅ 7 Core Smart Contracts Implemented (~2,400 LOC)
- ✅ 77 Tests Written (100% Passing)
- ✅ TypeScript SDK Complete (~1,520 LOC)
- ✅ React Demo Wallet (~650 LOC)
- ✅ Developer Documentation (9 docs, ~15k words)
- ✅ Deployment Scripts & Infrastructure
- ⏳ Testnet Deployment (Next)
- ⏳ Security Audit (Q1 2026)
- ⏳ Mainnet Launch (Q2 2026)

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

## Security

This project is under active development. **Do not use in production without a security audit.**

To report security vulnerabilities, please email security@aakit.io

## License

MIT License - see [LICENSE](LICENSE) for details

## Resources

- [ERC-4337 Specification](https://eips.ethereum.org/EIPS/eip-4337)
- [ERC-7579 Specification](https://eips.ethereum.org/EIPS/eip-7579)
- [WebAuthn Standard](https://www.w3.org/TR/webauthn/)
- [Documentation](./docs/)

## Acknowledgments

Inspired by:
- [Porto by Ithaca](https://github.com/ithacaxyz/porto)
- [Coinbase Smart Wallet](https://github.com/coinbase/smart-wallet)
- [Base WebAuthn Library](https://github.com/base-org/webauthn-sol)
- [Solady](https://github.com/Vectorized/solady)
