/**
 * @file WebAuthn/Passkey types
 * @description Type definitions for WebAuthn passkey integration
 */

import type { Hex } from 'viem'

/**
 * Passkey credential for wallet
 */
export interface PasskeyCredential {
  /** Credential ID (base64url) */
  id: string
  /** Raw credential ID (bytes) */
  rawId: ArrayBuffer
  /** Public key X coordinate */
  publicKeyX: Hex
  /** Public key Y coordinate */
  publicKeyY: Hex
  /** Algorithm used (-7 for ES256/P-256) */
  algorithm: number
}

/**
 * WebAuthn authentication assertion
 */
export interface WebAuthnAssertion {
  /** Authenticator data */
  authenticatorData: Hex
  /** Client data JSON */
  clientDataJSON: Hex
  /** Signature r value */
  r: bigint
  /** Signature s value */
  s: bigint
  /** Index of challenge in clientDataJSON */
  challengeIndex: number
  /** Index of type in clientDataJSON */
  typeIndex: number
}

/**
 * Passkey creation options
 */
export interface PasskeyCreationOptions {
  /** User identifier */
  userId: string
  /** User display name */
  userName: string
  /** Relying party name */
  rpName: string
  /** Relying party ID (domain) */
  rpId: string
  /** Challenge (will be generated if not provided) */
  challenge?: Uint8Array
  /** Timeout in milliseconds */
  timeout?: number
  /** Authenticator attachment */
  authenticatorAttachment?: 'platform' | 'cross-platform'
  /** User verification requirement */
  userVerification?: 'required' | 'preferred' | 'discouraged'
}

/**
 * Passkey authentication options
 */
export interface PasskeyAuthenticationOptions {
  /** Relying party ID */
  rpId: string
  /** Challenge to sign */
  challenge: Uint8Array
  /** Credential ID (if known) */
  credentialId?: string
  /** Timeout in milliseconds */
  timeout?: number
  /** User verification requirement */
  userVerification?: 'required' | 'preferred' | 'discouraged'
}

/**
 * Parsed public key from authenticator
 */
export interface ParsedPublicKey {
  /** X coordinate (32 bytes) */
  x: Uint8Array
  /** Y coordinate (32 bytes) */
  y: Uint8Array
  /** Algorithm identifier */
  algorithm: number
}

/**
 * Client data JSON structure
 */
export interface ClientDataJSON {
  type: string
  challenge: string
  origin: string
  crossOrigin?: boolean
}
