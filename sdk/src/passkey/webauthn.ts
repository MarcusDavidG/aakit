/**
 * @file WebAuthn passkey integration
 * @description Functions for creating and authenticating with passkeys
 */

import { bytesToHex } from 'viem'
import type {
  PasskeyCredential,
  PasskeyCreationOptions,
  PasskeyAuthenticationOptions,
  WebAuthnAssertion,
  ParsedPublicKey,
  ClientDataJSON,
} from './types'

/**
 * Check if WebAuthn is supported
 * @returns True if WebAuthn is available
 */
export function isWebAuthnSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.PublicKeyCredential !== undefined &&
    typeof window.PublicKeyCredential === 'function'
  )
}

/**
 * Create a new passkey credential
 * @param options - Passkey creation options
 * @returns Passkey credential
 */
export async function createPasskey(
  options: PasskeyCreationOptions
): Promise<PasskeyCredential> {
  if (!isWebAuthnSupported()) {
    throw new Error('WebAuthn is not supported in this browser')
  }

  const {
    userId,
    userName,
    rpName,
    rpId,
    challenge = crypto.getRandomValues(new Uint8Array(32)),
    timeout = 60_000,
    authenticatorAttachment = 'platform',
    userVerification = 'required',
  } = options

  const credential = await navigator.credentials.create({
    publicKey: {
      challenge: challenge as BufferSource,
      rp: {
        name: rpName,
        id: rpId,
      },
      user: {
        id: new TextEncoder().encode(userId),
        name: userName,
        displayName: userName,
      },
      pubKeyCredParams: [
        {
          type: 'public-key',
          alg: -7, // ES256 (P-256)
        },
      ],
      authenticatorSelection: {
        authenticatorAttachment,
        userVerification,
        requireResidentKey: true,
      },
      timeout,
      attestation: 'none',
    },
  })

  if (!credential || credential.type !== 'public-key') {
    throw new Error('Failed to create passkey credential')
  }

  const pkCredential = credential as PublicKeyCredential
  const response = pkCredential.response as AuthenticatorAttestationResponse

  // Parse public key from attestation
  const publicKey = parsePublicKey(response.getPublicKey()!)

  return {
    id: pkCredential.id,
    rawId: pkCredential.rawId,
    publicKeyX: bytesToHex(publicKey.x),
    publicKeyY: bytesToHex(publicKey.y),
    algorithm: publicKey.algorithm,
  }
}

/**
 * Authenticate with a passkey
 * @param options - Authentication options
 * @returns WebAuthn assertion
 */
export async function authenticateWithPasskey(
  options: PasskeyAuthenticationOptions
): Promise<WebAuthnAssertion> {
  if (!isWebAuthnSupported()) {
    throw new Error('WebAuthn is not supported in this browser')
  }

  const {
    rpId,
    challenge,
    credentialId,
    timeout = 60_000,
    userVerification = 'required',
  } = options

  const credential = await navigator.credentials.get({
    publicKey: {
      challenge: challenge as BufferSource,
      rpId,
      allowCredentials: credentialId
        ? [
            {
              type: 'public-key',
              id: base64UrlToBuffer(credentialId),
            },
          ]
        : [],
      userVerification,
      timeout,
    },
  })

  if (!credential || credential.type !== 'public-key') {
    throw new Error('Failed to authenticate with passkey')
  }

  const pkCredential = credential as PublicKeyCredential
  const response = pkCredential.response as AuthenticatorAssertionResponse

  // Parse signature (DER format)
  const signature = parseSignature(new Uint8Array(response.signature))

  // Get client data JSON
  const clientDataJSON = new Uint8Array(response.clientDataJSON)
  const clientData: ClientDataJSON = JSON.parse(
    new TextDecoder().decode(clientDataJSON)
  )

  // Find challenge and type indices in JSON
  const jsonString = new TextDecoder().decode(clientDataJSON)
  const challengeIndex = jsonString.indexOf(clientData.challenge)
  const typeIndex = jsonString.indexOf(clientData.type)

  return {
    authenticatorData: bytesToHex(new Uint8Array(response.authenticatorData)),
    clientDataJSON: bytesToHex(clientDataJSON),
    r: signature.r,
    s: signature.s,
    challengeIndex,
    typeIndex,
  }
}

/**
 * Parse public key from COSE format
 * @param publicKeyBytes - Public key bytes
 * @returns Parsed public key
 */
export function parsePublicKey(publicKeyBytes: ArrayBuffer): ParsedPublicKey {
  const bytes = new Uint8Array(publicKeyBytes)
  
  // Check if this is X.509 SubjectPublicKeyInfo format (starts with 0x30)
  if (bytes[0] === 0x30) {
    return parseX509PublicKey(bytes)
  }
  
  // Otherwise, assume COSE key format (CBOR-encoded)
  // We need to find the x (-2) and y (-3) coordinates
  // In CBOR, negative integers are encoded as: 0x20 + (value - 1)
  // So -2 is 0x21 and -3 is 0x22
  
  let xCoord: Uint8Array | null = null
  let yCoord: Uint8Array | null = null
  
  let i = 0
  while (i < bytes.length) {
    // Look for label -2 (x-coordinate): 0x21
    if (bytes[i] === 0x21) {
      i++ // Move past label
      // Next byte should be 0x58 (byte string) followed by length 0x20 (32 bytes)
      if (i < bytes.length && bytes[i] === 0x58 && i + 1 < bytes.length && bytes[i + 1] === 0x20) {
        i += 2 // Skip 0x58 and length
        if (i + 32 <= bytes.length) {
          xCoord = bytes.slice(i, i + 32)
          i += 32
        }
      }
      continue
    }
    
    // Look for label -3 (y-coordinate): 0x22
    if (bytes[i] === 0x22) {
      i++ // Move past label
      // Next byte should be 0x58 (byte string) followed by length 0x20 (32 bytes)
      if (i < bytes.length && bytes[i] === 0x58 && i + 1 < bytes.length && bytes[i + 1] === 0x20) {
        i += 2 // Skip 0x58 and length
        if (i + 32 <= bytes.length) {
          yCoord = bytes.slice(i, i + 32)
          i += 32
        }
      }
      continue
    }
    
    i++
  }
  
  if (!xCoord || !yCoord) {
    // Fallback: try simple byte search
    console.warn('Using fallback COSE parsing')
    const xIndex = bytes.indexOf(0x21)
    const yIndex = bytes.indexOf(0x22)
    
    if (xIndex !== -1 && yIndex !== -1 && xIndex < yIndex) {
      // Try to extract 32 bytes after markers
      let xStart = xIndex + 3 // Skip label + type + length
      let yStart = yIndex + 3
      
      if (xStart + 32 <= bytes.length && yStart + 32 <= bytes.length) {
        xCoord = bytes.slice(xStart, xStart + 32)
        yCoord = bytes.slice(yStart, yStart + 32)
      }
    }
  }
  
  if (!xCoord || !yCoord) {
    throw new Error('Failed to parse public key coordinates. Raw bytes: ' + bytesToHex(bytes))
  }

  return {
    x: xCoord,
    y: yCoord,
    algorithm: -7, // ES256
  }
}

/**
 * Parse X.509 SubjectPublicKeyInfo format public key
 * @param bytes - Public key bytes in X.509 format
 * @returns Parsed public key
 */
function parseX509PublicKey(bytes: Uint8Array): ParsedPublicKey {
  // X.509 format: SEQUENCE { SEQUENCE { OID, OID }, BIT STRING }
  // For P-256 uncompressed point, the BIT STRING contains:
  // 0x04 (uncompressed point marker) + 32 bytes x + 32 bytes y
  
  // Find the BIT STRING tag (0x03)
  let bitStringIndex = -1
  for (let i = 0; i < bytes.length - 65; i++) {
    if (bytes[i] === 0x03) {
      // Next byte is the length, then 0x00 (unused bits), then 0x04 (uncompressed)
      if (i + 3 < bytes.length && bytes[i + 2] === 0x00 && bytes[i + 3] === 0x04) {
        bitStringIndex = i + 4 // Skip to after the 0x04 marker
        break
      }
    }
  }
  
  if (bitStringIndex === -1 || bitStringIndex + 64 > bytes.length) {
    throw new Error('Invalid X.509 public key format')
  }
  
  // Extract x and y coordinates (32 bytes each)
  const x = bytes.slice(bitStringIndex, bitStringIndex + 32)
  const y = bytes.slice(bitStringIndex + 32, bitStringIndex + 64)
  
  return {
    x,
    y,
    algorithm: -7, // ES256
  }
}

/**
 * Parse ECDSA signature from DER format
 * @param signatureBytes - Signature in DER format
 * @returns Parsed r and s values
 */
export function parseSignature(signatureBytes: Uint8Array): { r: bigint; s: bigint } {
  // DER format: 0x30 [total-length] 0x02 [r-length] [r] 0x02 [s-length] [s]
  let offset = 0

  // Check sequence tag
  if (signatureBytes[offset++] !== 0x30) {
    throw new Error('Invalid DER signature format')
  }

  // Skip total length
  offset++

  // Parse r
  if (signatureBytes[offset++] !== 0x02) {
    throw new Error('Invalid DER signature: r value')
  }

  const rLength = signatureBytes[offset++]
  const rBytes = signatureBytes.slice(offset, offset + rLength)
  offset += rLength

  // Parse s
  if (signatureBytes[offset++] !== 0x02) {
    throw new Error('Invalid DER signature: s value')
  }

  const sLength = signatureBytes[offset++]
  const sBytes = signatureBytes.slice(offset, offset + sLength)

  // Convert to bigint
  const r = BigInt('0x' + bytesToHex(rBytes).slice(2))
  const s = BigInt('0x' + bytesToHex(sBytes).slice(2))

  return { r, s }
}

/**
 * Convert base64url string to ArrayBuffer
 * @param base64url - Base64url encoded string
 * @returns ArrayBuffer
 */
export function base64UrlToBuffer(base64url: string): ArrayBuffer {
  // Convert base64url to base64
  const base64 = base64url.replace(/-/g, '+').replace(/_/g, '/')
  const padding = '='.repeat((4 - (base64.length % 4)) % 4)
  const base64Padded = base64 + padding

  // Decode base64
  const binary = atob(base64Padded)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }

  return bytes.buffer
}

/**
 * Convert ArrayBuffer to base64url string
 * @param buffer - ArrayBuffer
 * @returns Base64url encoded string
 */
export function bufferToBase64Url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i])
  }

  const base64 = btoa(binary)
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

/**
 * Normalize s value to prevent signature malleability
 * @param s - S value
 * @returns Normalized s value
 */
export function normalizeS(s: bigint): bigint {
  // P-256 curve order
  const n = BigInt(
    '0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551'
  )

  // If s > n/2, return n - s
  if (s > n / 2n) {
    return n - s
  }

  return s
}
