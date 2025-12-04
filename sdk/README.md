# @aakit/sdk

TypeScript SDK for AAKit ERC-4337 smart wallets with native passkey support.

## Features

- ✅ **UserOperation Builder** - Easy construction of ERC-4337 UserOperations
- ✅ **Bundler Client** - Full support for bundler RPC methods
- ✅ **WebAuthn Integration** - Native passkey creation and authentication
- ✅ **Type-Safe** - Full TypeScript support with strict typing
- ✅ **Modular** - Import only what you need
- ✅ **Viem-Based** - Built on top of viem for Ethereum interactions

## Installation

```bash
npm install @aakit/sdk viem
```

## Quick Start

### Creating a UserOperation

```typescript
import { buildUserOperation, encodeExecutionMode, encodeSingleExecution } from '@aakit/sdk/core'
import { parseEther } from 'viem'

// Build execution calldata
const mode = encodeExecutionMode({ callType: 'call', execType: 'revert' })
const executionData = encodeSingleExecution(
  '0x...',  // target
  parseEther('0.1'),  // value
  '0x'  // data
)

// Create UserOperation
const userOp = buildUserOperation({
  sender: '0x...',  // Your smart wallet address
  nonce: 0n,
  callData: executionData,
  callGasLimit: 100_000n,
  verificationGasLimit: 100_000n,
  preVerificationGas: 21_000n,
  maxFeePerGas: parseGwei('10'),
  maxPriorityFeePerGas: parseGwei('1'),
})
```

### Using the Bundler Client

```typescript
import { createBundlerClient, waitForUserOperation } from '@aakit/sdk/core'

const bundler = createBundlerClient({
  bundlerUrl: 'https://bundler.example.com',
  entryPoint: '0x...',  // EntryPoint address
})

// Send UserOperation
const userOpHash = await bundler.sendUserOperation(userOp, entryPoint)

// Wait for inclusion
const receipt = await waitForUserOperation(bundler, userOpHash)

console.log('UserOp included:', receipt.success)
```

### Creating a Passkey

```typescript
import { createPasskey } from '@aakit/sdk/passkey'

const passkey = await createPasskey({
  userId: 'user@example.com',
  userName: 'Alice',
  rpName: 'My DApp',
  rpId: 'example.com',
})

console.log('Passkey created:', {
  id: passkey.id,
  publicKeyX: passkey.publicKeyX,
  publicKeyY: passkey.publicKeyY,
})
```

### Authenticating with Passkey

```typescript
import { authenticateWithPasskey } from '@aakit/sdk/passkey'

const challenge = crypto.getRandomValues(new Uint8Array(32))

const assertion = await authenticateWithPasskey({
  rpId: 'example.com',
  challenge,
  credentialId: passkey.id,
})

// Use assertion.r, assertion.s for signature
console.log('Authenticated:', {
  r: assertion.r,
  s: assertion.s,
})
```

## API Reference

### Core Module (`@aakit/sdk/core`)

#### UserOperation Builder

- `buildUserOperation(params)` - Build a PackedUserOperation
- `packAccountGasLimits(verification, call)` - Pack gas limits
- `packGasFees(priority, max)` - Pack gas fees
- `encodeExecutionMode(mode)` - Encode execution mode
- `encodeSingleExecution(target, value, data)` - Encode single call
- `encodeBatchExecution(executions)` - Encode batch calls

#### Bundler Client

- `createBundlerClient(config)` - Create bundler client
- `waitForUserOperation(bundler, hash, options)` - Wait for inclusion

### Passkey Module (`@aakit/sdk/passkey`)

#### WebAuthn Functions

- `createPasskey(options)` - Create a new passkey
- `authenticateWithPasskey(options)` - Authenticate with passkey
- `isWebAuthnSupported()` - Check WebAuthn support
- `parsePublicKey(bytes)` - Parse COSE public key
- `parseSignature(bytes)` - Parse DER signature
- `normalizeS(s)` - Normalize signature s value

## Examples

See the `/examples` directory for complete implementations:

- `/examples/demo-wallet` - React wallet with passkey auth
- `/examples/demo-dapp` - DApp integration example

## Browser Compatibility

WebAuthn/Passkeys require modern browsers:
- Chrome/Edge 67+
- Firefox 60+
- Safari 13+

Check support with `isWebAuthnSupported()`.

## Development

```bash
# Install dependencies
npm install

# Build SDK
npm run build

# Run tests
npm test

# Type check
npm run typecheck
```

## License

MIT
