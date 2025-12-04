# Passkey Authentication Flow

## Overview

This document details how AAKit integrates WebAuthn passkeys for secure, seedless wallet authentication.

## WebAuthn Fundamentals

### What are Passkeys?

Passkeys are FIDO2-compliant credentials that use public-key cryptography:
- **Private key**: Stored securely in device hardware (TPM, Secure Enclave)
- **Public key**: Stored on-chain in the smart wallet
- **Signature algorithm**: P256 (secp256r1) ECDSA

### Benefits

1. **No seed phrases**: Keys never leave the device
2. **Biometric auth**: Face ID, Touch ID, Windows Hello
3. **Phishing resistant**: Domain-bound credentials
4. **Hardware-backed**: TPM/Secure Enclave protection
5. **Cross-platform**: Sync via iCloud, Google Password Manager

## Registration Flow

### 1. User Initiates Wallet Creation

```typescript
// Frontend SDK call
const wallet = await AAKit.createWallet({
  authMethod: 'passkey',
  username: 'alice@example.com'
});
```

### 2. Browser Generates Passkey

```javascript
const credential = await navigator.credentials.create({
  publicKey: {
    challenge: randomChallenge,
    rp: {
      name: "AAKit Wallet",
      id: "app.aakit.io"
    },
    user: {
      id: userIdBytes,
      name: "alice@example.com",
      displayName: "Alice"
    },
    pubKeyCredParams: [{
      type: "public-key",
      alg: -7  // ES256 (P256)
    }],
    authenticatorSelection: {
      authenticatorAttachment: "platform",
      userVerification: "required"
    },
    timeout: 60000,
    attestation: "none"
  }
});
```

### 3. Extract Public Key

```typescript
// Parse authenticator response
const response = credential.response as AuthenticatorAttestationResponse;
const publicKey = parseAuthData(response.authenticatorData);

// Extract P256 coordinates
const { x, y } = publicKey;
```

### 4. Deploy Wallet with Passkey Owner

```solidity
// Factory deploys wallet with passkey as owner
bytes memory passkeyOwner = abi.encodePacked(
    uint256(x),  // 32 bytes
    uint256(y)   // 32 bytes
);

address wallet = factory.createAccount(
    owners: [passkeyOwner],
    nonce: 0
);
```

## Authentication Flow

### 1. Construct UserOperation

```typescript
const userOp = {
  sender: walletAddress,
  nonce: await wallet.getNonce(),
  callData: encodeFunctionData({
    abi: walletABI,
    functionName: 'execute',
    args: [target, value, data]
  }),
  // ... gas fields
  signature: "0x"  // Filled after signing
};
```

### 2. Generate Challenge

```typescript
// Compute userOpHash (what will be signed)
const userOpHash = keccak256(
  defaultAbiCoder.encode(
    ['bytes32', 'address', 'uint256'],
    [
      hashUserOp(userOp),
      entryPointAddress,
      chainId
    ]
  )
);

// Challenge for WebAuthn
const challenge = base64url(userOpHash);
```

### 3. Request Signature from Device

```javascript
const assertion = await navigator.credentials.get({
  publicKey: {
    challenge: challenge,
    rpId: "app.aakit.io",
    allowCredentials: [{
      type: "public-key",
      id: credentialId
    }],
    userVerification: "required",
    timeout: 60000
  }
});
```

### 4. Parse WebAuthn Assertion

```typescript
const response = assertion.response as AuthenticatorAssertionResponse;

const webAuthnAuth = {
  authenticatorData: response.authenticatorData,
  clientDataJSON: response.clientDataJSON,
  challengeIndex: findChallengeIndex(response.clientDataJSON),
  typeIndex: findTypeIndex(response.clientDataJSON),
  r: signature.r,
  s: signature.s
};
```

### 5. Encode Signature for UserOp

```typescript
// SignatureWrapper structure
const signatureWrapper = {
  ownerIndex: 0,  // Index of passkey in wallet's owner list
  signatureData: abiCoder.encode(
    ['bytes', 'bytes', 'uint256', 'uint256', 'uint256', 'uint256'],
    [
      webAuthnAuth.authenticatorData,
      webAuthnAuth.clientDataJSON,
      webAuthnAuth.challengeIndex,
      webAuthnAuth.typeIndex,
      webAuthnAuth.r,
      webAuthnAuth.s
    ]
  )
};

userOp.signature = abiCoder.encode(
  ['uint8', 'bytes'],
  [signatureWrapper.ownerIndex, signatureWrapper.signatureData]
);
```

### 6. Submit to Bundler

```typescript
const userOpHash = await bundler.sendUserOperation(userOp, entryPoint);
await bundler.waitForUserOperationReceipt(userOpHash);
```

## On-Chain Verification

### 1. EntryPoint Calls Wallet

```solidity
// EntryPoint validates the user operation
function handleOps(
    PackedUserOperation[] calldata ops,
    address payable beneficiary
) external {
    for (uint256 i = 0; i < ops.length; i++) {
        uint256 validationData = IAccount(ops[i].sender)
            .validateUserOp(ops[i], userOpHash, missingFunds);
        // ...
    }
}
```

### 2. Wallet Forwards to PasskeyValidator

```solidity
function validateUserOp(
    PackedUserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 missingAccountFunds
) external returns (uint256 validationData) {
    // Decode signature
    (uint8 ownerIndex, bytes memory signatureData) = 
        abi.decode(userOp.signature, (uint8, bytes));
    
    // Get owner public key
    bytes memory owner = getOwnerAtIndex(ownerIndex);
    
    // Validate via PasskeyValidator
    return passkeyValidator.validateUserOp(
        owner,
        userOpHash,
        signatureData
    );
}
```

### 3. PasskeyValidator Verifies P256 Signature

```solidity
contract PasskeyValidator {
    function validateUserOp(
        bytes memory publicKey,
        bytes32 messageHash,
        bytes memory signatureData
    ) external view returns (uint256) {
        // Decode WebAuthn assertion
        WebAuthnAuth memory auth = abi.decode(signatureData, (WebAuthnAuth));
        
        // Reconstruct signed message
        bytes32 clientDataHash = sha256(auth.clientDataJSON);
        bytes memory message = abi.encodePacked(
            auth.authenticatorData,
            clientDataHash
        );
        bytes32 messageToVerify = sha256(message);
        
        // Verify P256 signature
        bool valid = _verifyP256(
            messageToVerify,
            auth.r,
            auth.s,
            publicKey
        );
        
        return valid ? 0 : 1;  // SIG_VALIDATION_FAILED
    }
    
    function _verifyP256(
        bytes32 message,
        uint256 r,
        uint256 s,
        bytes memory publicKey
    ) internal view returns (bool) {
        (uint256 x, uint256 y) = abi.decode(publicKey, (uint256, uint256));
        
        // Try RIP-7212 precompile first
        (bool success, bytes memory result) = P256_VERIFIER.staticcall(
            abi.encode(message, r, s, x, y)
        );
        
        if (success && result.length > 0) {
            return abi.decode(result, (uint256)) == 1;
        }
        
        // Fallback to FreshCryptoLib
        return FCL.ecdsa_verify(message, r, s, x, y);
    }
}
```

## Security Considerations

### WebAuthn Validation Checks

1. **Challenge Verification**
   ```solidity
   bytes32 expectedChallenge = userOpHash;
   bytes32 actualChallenge = extractChallenge(clientDataJSON);
   require(expectedChallenge == actualChallenge);
   ```

2. **Origin Validation**
   ```solidity
   string memory expectedOrigin = "https://app.aakit.io";
   string memory actualOrigin = extractOrigin(clientDataJSON);
   require(keccak256(bytes(actualOrigin)) == keccak256(bytes(expectedOrigin)));
   ```

3. **RP ID Validation**
   ```solidity
   bytes32 expectedRpIdHash = sha256(bytes("app.aakit.io"));
   bytes32 actualRpIdHash = bytes32(authenticatorData[0:32]);
   require(expectedRpIdHash == actualRpIdHash);
   ```

4. **Flags Verification**
   ```solidity
   bytes1 flags = authenticatorData[32];
   require(flags & 0x01 != 0);  // User Present (UP)
   require(flags & 0x04 != 0);  // User Verified (UV)
   ```

### Signature Malleability

P256 signatures can be malleable. Normalize s-values:

```solidity
// Ensure s is in lower half of curve order
uint256 n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
if (s > n / 2) {
    s = n - s;
}
```

### Replay Protection

UserOp includes:
- Unique nonce
- Chain ID (embedded in userOpHash)
- EntryPoint address (embedded in userOpHash)

### Front-Running Protection

UserOps are:
- Committed to bundler mempool
- Executed in deterministic order
- Protected by sender nonce

## Gas Optimization

### Calldata Savings

| Approach | Size | Savings |
|----------|------|---------|
| Full public key in signature | 64 bytes | - |
| Owner index + lookup | 1 byte + storage | ~63 bytes calldata |

At 16 gas/byte on L2, this saves ~1000 gas per transaction.

### Precompile Usage

| Method | Gas Cost |
|--------|----------|
| RIP-7212 precompile | ~3,000 |
| FreshCryptoLib fallback | ~300,000 |

Target chains with RIP-7212 support (Base, Optimism, etc.)

## Error Handling

### Common Errors

1. **InvalidSignature**: P256 verification failed
2. **InvalidChallenge**: Challenge mismatch in clientDataJSON
3. **InvalidOrigin**: Wrong RP ID or origin
4. **InvalidFlags**: Missing UP or UV flags
5. **OwnerNotFound**: Invalid owner index

### Frontend Error Handling

```typescript
try {
  const credential = await navigator.credentials.get(...);
} catch (error) {
  if (error.name === 'NotAllowedError') {
    // User cancelled or timeout
  } else if (error.name === 'NotSupportedError') {
    // Browser doesn't support WebAuthn
  } else {
    // Other error
  }
}
```

## Testing

### Unit Tests

```solidity
function test_PasskeyValidation() public {
    // Setup wallet with passkey owner
    bytes memory owner = abi.encodePacked(publicKeyX, publicKeyY);
    wallet.addOwnerPublicKey(owner);
    
    // Create signed user operation
    bytes32 userOpHash = computeUserOpHash(userOp);
    bytes memory signature = signWithPasskey(userOpHash, privateKey);
    
    // Validate
    uint256 result = wallet.validateUserOp(userOp, userOpHash, 0);
    assertEq(result, 0);  // Success
}
```

### Integration Tests

Test on:
- Chrome with USB security key
- Safari with Touch ID
- Windows with Windows Hello
- Android with fingerprint

## Future Enhancements

1. **Multi-device sync**: iCloud Keychain, Google Password Manager
2. **Backup passkeys**: Multiple credentials per wallet
3. **Conditional UI**: `mediation: 'conditional'` for autofill
4. **Large blob storage**: Store wallet metadata on passkey
5. **Attestation**: Verify authenticator model for high-security

## References

- [WebAuthn Spec](https://www.w3.org/TR/webauthn-2/)
- [FIDO2 CTAP](https://fidoalliance.org/specs/fido-v2.0-ps-20190130/fido-client-to-authenticator-protocol-v2.0-ps-20190130.html)
- [RIP-7212 Precompile](https://github.com/ethereum/RIPs/blob/master/RIPS/rip-7212.md)
- [Base WebAuthn Library](https://github.com/base-org/webauthn-sol)
