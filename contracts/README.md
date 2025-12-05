# AAKit Smart Contracts

Production-ready ERC-4337 smart wallet contracts with passkey support.

## Overview

This directory contains the core smart contracts for AAKit:

- **AAKitWallet** - ERC-4337 + ERC-7579 compliant smart wallet
- **AAKitFactory** - Deterministic wallet deployment
- **PasskeyValidator** - P256 signature verification module
- **VerifyingPaymaster** - Gas sponsorship contract
- **MultiOwnable** - Multi-owner management
- **ERC4337Account** - Base account abstraction logic

## Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/)
- Solidity 0.8.23+
- Git

### Install Dependencies

```bash
forge install
```

### Compile Contracts

```bash
forge build
```

### Run Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-contract AAKitWalletTest

# Run with gas report
forge test --gas-report
```

## Deployment

### Local Development

1. Start local node:
```bash
anvil
```

2. Deploy contracts:
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url localhost --broadcast
```

### Testnet (Sepolia)

1. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your keys
```

2. Deploy to Sepolia:
```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

3. Verify deployment:
```bash
cast call $FACTORY_ADDRESS "walletImplementation()" --rpc-url $SEPOLIA_RPC_URL
```

### Mainnet

**⚠️ WARNING: Only deploy to mainnet after:**
- Complete security audit
- Extensive testnet testing (3+ months)
- Bug bounty program
- Community review

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow  # Use slower but more reliable broadcasting
```

## Contract Addresses

### Sepolia Testnet
```
EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
AAKitFactory: (deploy first)
AAKitWallet Implementation: (deploy first)
PasskeyValidator: (deploy first)
VerifyingPaymaster: (deploy first)
```

### Mainnet
```
EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
AAKitFactory: (not yet deployed)
AAKitWallet Implementation: (not yet deployed)
PasskeyValidator: (not yet deployed)
VerifyingPaymaster: (not yet deployed)
```

## Architecture

```
┌────────────────────────────────────┐
│         User / DApp                │
└────────────┬───────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│         Bundler                    │
└────────────┬───────────────────────┘
             │
             ▼
┌────────────────────────────────────┐
│         EntryPoint                 │  ◄── ERC-4337 v0.7
└────────────┬───────────────────────┘
             │
       ┌─────┴──────┐
       │            │
       ▼            ▼
┌──────────┐  ┌────────────┐
│ Paymaster│  │ AAKitWallet│
└──────────┘  └─────┬──────┘
                    │
              ┌─────┴──────┐
              │            │
              ▼            ▼
         ┌─────────┐  ┌────────┐
         │ Modules │  │ Owners │
         └─────────┘  └────────┘
```

## Security

### Audits
- [ ] Trail of Bits (Pending)
- [ ] OpenZeppelin (Pending)
- [ ] Certora (Formal Verification - Pending)

### Bug Bounty
Not yet launched. Please report security issues to: security@aakit.io

### Known Issues
None currently. See [SECURITY.md](../docs/SECURITY.md) for best practices.

## Gas Benchmarks

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| Wallet Creation | 185,000 | via Factory |
| Add Owner (EOA) | 99,000 | 20-byte address |
| Add Owner (Passkey) | 124,000 | 64-byte pubkey |
| Validate UserOp | 97,000 | with EOA signature |
| Execute Single | 79,000 | simple transfer |
| Execute Batch (2) | 94,000 | two transfers |
| Module Install | 74,000 | validator module |

## Development

### Project Structure

```
contracts/
├── src/
│   ├── interfaces/      # Standard interfaces
│   ├── utils/          # Base contracts
│   ├── wallet/         # Core wallet
│   ├── validators/     # Validator modules
│   ├── factory/        # Wallet factory
│   └── paymaster/      # Gas sponsorship
│
├── test/
│   ├── base/          # Test fixtures
│   ├── mocks/         # Mock contracts
│   ├── utils/         # Test utilities
│   └── *.t.sol        # Test files
│
├── script/
│   └── Deploy.s.sol   # Deployment scripts
│
└── deployments/       # Deployment artifacts
```

### Adding a New Module

1. Create contract in `src/validators/`, `src/executors/`, etc.
2. Implement IERC7579Module interface
3. Add tests in `test/`
4. Update documentation
5. Submit PR

### Running Static Analysis

```bash
# Slither
slither .

# Mythril (slower)
myth analyze src/wallet/AAKitWallet.sol
```

## Scripts

### Deploy Everything
```bash
forge script script/Deploy.s.sol:DeployScript --broadcast
```

### Create Test Wallet
```bash
forge script script/CreateWallet.s.sol:CreateWalletScript --broadcast
```

### Verify Contracts
```bash
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/wallet/AAKitWallet.sol:AAKitWallet \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --chain sepolia
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](../LICENSE)
