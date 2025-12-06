/**
 * @file Wallet client types
 * @description Type definitions for AAKit wallet client
 */

import type { Address, Hex, Chain, WalletClient } from 'viem'
import type { PasskeyCredential } from '../passkey/types'

/**
 * AAKit wallet configuration
 */
export interface AAKitWalletConfig {
  /** Smart wallet address (if already deployed) */
  address?: Address
  /** Factory address (for deployment) */
  factory: Address
  /** EntryPoint address */
  entryPoint: Address
  /** Bundler URL */
  bundlerUrl: string
  /** Chain configuration */
  chain: Chain
  /** Paymaster configuration (optional) */
  paymaster?: PaymasterConfig
  /** Owner configuration */
  owner: OwnerConfig
}

/**
 * Owner configuration (EOA or Passkey)
 */
export type OwnerConfig =
  | {
      type: 'eoa'
      address: Address
      signer: WalletClient
    }
  | {
      type: 'passkey'
      credential: PasskeyCredential
    }

/**
 * Paymaster configuration
 */
export interface PaymasterConfig {
  /** Paymaster address */
  address: Address
  /** Signing key for verification */
  signingKey?: Hex
}

/**
 * Transaction parameters
 */
export interface TransactionParams {
  /** Target address */
  to: Address
  /** ETH value */
  value?: bigint
  /** Calldata */
  data?: Hex
}

/**
 * Batch transaction parameters
 */
export interface BatchTransactionParams {
  transactions: TransactionParams[]
}

/**
 * Send transaction result
 */
export interface SendTransactionResult {
  /** UserOperation hash */
  userOpHash: Hex
  /** Wait for transaction to be mined */
  wait: () => Promise<TransactionReceipt>
}

/**
 * Transaction receipt
 */
export interface TransactionReceipt {
  /** Transaction hash */
  transactionHash: Hex
  /** Block number */
  blockNumber: bigint
  /** Gas used */
  gasUsed: bigint
  /** Success status */
  success: boolean
}

/**
 * Wallet deployment status
 */
export interface DeploymentStatus {
  /** Is wallet deployed */
  deployed: boolean
  /** Predicted address */
  address: Address
  /** Deployment transaction hash (if deployed) */
  deploymentHash?: Hex
}
