/**
 * @file WebAuthn passkey integration
 * @description Functions for creating and authenticating with passkeys
 */

import { toHex, fromBytes, bytesToHex } from 'viem'
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
      challenge,
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
      challenge,
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
  // COSE key format parsing
  // This is a simplified version - production should use cbor library
  const bytes = new Uint8Array(publicKeyBytes)

  // For P-256, x and y are 32 bytes each
  // Simplified extraction (assumes specific COSE format)
  let xOffset = -1
  let yOffset = -1

  // Find x and y coordinates in COSE structure
  // Label -2 (x-coordinate) and -3 (y-coordinate)
  for (let i = 0; i < bytes.length - 33; i++) {
    if (bytes[i] === 0x21 && xOffset === -1) {
      // Label -2 encoded as 0x21
      xOffset = i + 2 // Skip label and size byte
    }
    if (bytes[i] === 0x22 && yOffset === -1) {
      // Label -3 encoded as 0x22
      yOffset = i + 2
    }
  }

  if (xOffset === -1 || yOffset === -1) {
    throw new Error('Failed to parse public key coordinates')
  }

  const x = bytes.slice(xOffset, xOffset + 32)
  const y = bytes.slice(yOffset, yOffset + 32)

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
