/**
 * @file UserOperation types for ERC-4337
 * @description Type definitions for UserOperations following ERC-4337 v0.7 specification
 */

import type { Address, Hex } from 'viem'

/**
 * PackedUserOperation structure for ERC-4337 v0.7
 */
export interface PackedUserOperation {
  /** The account making the operation */
  sender: Address
  /** Anti-replay parameter */
  nonce: bigint
  /** Account factory and data (or empty) */
  initCode: Hex
  /** The data to pass to the sender during execution */
  callData: Hex
  /** Packed gas limits (verificationGasLimit || callGasLimit) */
  accountGasLimits: Hex
  /** Extra gas to pay the bundler */
  preVerificationGas: bigint
  /** Packed gas fees (maxPriorityFeePerGas || maxFeePerGas) */
  gasFees: Hex
  /** Paymaster address and data (or empty) */
  paymasterAndData: Hex
  /** Data passed to validateUserOp (and paymaster) */
  signature: Hex
}

/**
 * Unpacked UserOperation for easier construction
 */
export interface UserOperationParams {
  sender: Address
  nonce: bigint
  factory?: Address
  factoryData?: Hex
  callData: Hex
  callGasLimit: bigint
  verificationGasLimit: bigint
  preVerificationGas: bigint
  maxFeePerGas: bigint
  maxPriorityFeePerGas: bigint
  paymaster?: Address
  paymasterVerificationGasLimit?: bigint
  paymasterPostOpGasLimit?: bigint
  paymasterData?: Hex
  signature?: Hex
}

/**
 * Gas parameters for UserOperation
 */
export interface UserOperationGas {
  callGasLimit: bigint
  verificationGasLimit: bigint
  preVerificationGas: bigint
  maxFeePerGas: bigint
  maxPriorityFeePerGas: bigint
}

/**
 * Paymaster configuration
 */
export interface PaymasterConfig {
  address: Address
  verificationGasLimit: bigint
  postOpGasLimit: bigint
  data?: Hex
}

/**
 * UserOperation receipt
 */
export interface UserOperationReceipt {
  userOpHash: Hex
  entryPoint: Address
  sender: Address
  nonce: bigint
  paymaster?: Address
  actualGasCost: bigint
  actualGasUsed: bigint
  success: boolean
  logs: readonly Log[]
  receipt: TransactionReceipt
}

/**
 * Log entry
 */
export interface Log {
  address: Address
  topics: readonly Hex[]
  data: Hex
  blockNumber: bigint
  transactionHash: Hex
  logIndex: number
}

/**
 * Transaction receipt
 */
export interface TransactionReceipt {
  transactionHash: Hex
  blockNumber: bigint
  blockHash: Hex
  gasUsed: bigint
  status: 'success' | 'reverted'
}

/**
 * Execution mode structure
 */
export interface ExecutionMode {
  callType: 'call' | 'batch' | 'delegatecall'
  execType: 'revert' | 'try'
}

/**
 * Single execution
 */
export interface Execution {
  target: Address
  value: bigint
  data: Hex
}
