/**
 * @file UserOperation builder and utilities
 * @description Functions for building and manipulating ERC-4337 UserOperations
 */

import { type Address, type Hex, encodeAbiParameters, concat, pad, toHex } from 'viem'
import type {
  PackedUserOperation,
  UserOperationParams,
  UserOperationGas,
  PaymasterConfig,
  ExecutionMode,
  Execution,
} from '../types/userOperation'

/**
 * Default gas values for UserOperations
 */
export const DEFAULT_GAS_VALUES = {
  callGasLimit: 100_000n,
  verificationGasLimit: 100_000n,
  preVerificationGas: 21_000n,
  maxFeePerGas: 1_000_000_000n, // 1 gwei
  maxPriorityFeePerGas: 1_000_000_000n, // 1 gwei
} as const

/**
 * Pack gas limits into bytes32
 * @param verificationGasLimit - Gas for validation
 * @param callGasLimit - Gas for execution
 * @returns Packed bytes32
 */
export function packAccountGasLimits(
  verificationGasLimit: bigint,
  callGasLimit: bigint
): Hex {
  return concat([
    pad(toHex(verificationGasLimit), { size: 16 }),
    pad(toHex(callGasLimit), { size: 16 }),
  ])
}

/**
 * Pack gas fees into bytes32
 * @param maxPriorityFeePerGas - Priority fee
 * @param maxFeePerGas - Max fee
 * @returns Packed bytes32
 */
export function packGasFees(maxPriorityFeePerGas: bigint, maxFeePerGas: bigint): Hex {
  return concat([
    pad(toHex(maxPriorityFeePerGas), { size: 16 }),
    pad(toHex(maxFeePerGas), { size: 16 }),
  ])
}

/**
 * Pack initCode from factory address and data
 * @param factory - Factory address
 * @param factoryData - Factory calldata
 * @returns Packed initCode
 */
export function packInitCode(factory?: Address, factoryData?: Hex): Hex {
  if (!factory) return '0x'
  return concat([factory, factoryData || '0x'])
}

/**
 * Pack paymaster and data
 * @param config - Paymaster configuration
 * @returns Packed paymasterAndData
 */
export function packPaymasterAndData(config?: PaymasterConfig): Hex {
  if (!config) return '0x'

  return concat([
    config.address,
    pad(toHex(config.verificationGasLimit), { size: 16 }),
    pad(toHex(config.postOpGasLimit), { size: 16 }),
    config.data || '0x',
  ])
}

/**
 * Build a PackedUserOperation from parameters
 * @param params - UserOperation parameters
 * @returns PackedUserOperation
 */
export function buildUserOperation(params: UserOperationParams): PackedUserOperation {
  const {
    sender,
    nonce,
    factory,
    factoryData,
    callData,
    callGasLimit,
    verificationGasLimit,
    preVerificationGas,
    maxFeePerGas,
    maxPriorityFeePerGas,
    paymaster,
    paymasterVerificationGasLimit,
    paymasterPostOpGasLimit,
    paymasterData,
    signature = '0x',
  } = params

  const paymasterConfig = paymaster
    ? {
        address: paymaster,
        verificationGasLimit: paymasterVerificationGasLimit || 100_000n,
        postOpGasLimit: paymasterPostOpGasLimit || 50_000n,
        data: paymasterData,
      }
    : undefined

  return {
    sender,
    nonce,
    initCode: packInitCode(factory, factoryData),
    callData,
    accountGasLimits: packAccountGasLimits(verificationGasLimit, callGasLimit),
    preVerificationGas,
    gasFees: packGasFees(maxPriorityFeePerGas, maxFeePerGas),
    paymasterAndData: packPaymasterAndData(paymasterConfig),
    signature,
  }
}

/**
 * Encode execution mode
 * @param mode - Execution mode
 * @returns Encoded mode as bytes32
 */
export function encodeExecutionMode(mode: ExecutionMode): Hex {
  const callTypeByte =
    mode.callType === 'call' ? '00' : mode.callType === 'batch' ? '01' : 'ff'

  const execTypeByte = mode.execType === 'revert' ? '00' : '01'

  // Format: callType (1) || execType (1) || unused (4) || modeSelector (4) || modePayload (22)
  return `0x${callTypeByte}${execTypeByte}${'00'.repeat(30)}` as Hex
}

/**
 * Encode single execution calldata
 * @param target - Target address
 * @param value - ETH value
 * @param data - Calldata
 * @returns Encoded calldata
 */
export function encodeSingleExecution(
  target: Address,
  value: bigint,
  data: Hex
): Hex {
  return encodeAbiParameters(
    [
      { type: 'address', name: 'target' },
      { type: 'uint256', name: 'value' },
      { type: 'bytes', name: 'data' },
    ],
    [target, value, data]
  )
}

/**
 * Encode batch execution calldata
 * @param executions - Array of executions
 * @returns Encoded calldata
 */
export function encodeBatchExecution(executions: Execution[]): Hex {
  return encodeAbiParameters(
    [
      {
        type: 'tuple[]',
        name: 'executions',
        components: [
          { type: 'address', name: 'target' },
          { type: 'uint256', name: 'value' },
          { type: 'bytes', name: 'callData' },
        ],
      },
    ],
    [executions.map((e) => ({ target: e.target, value: e.value, callData: e.data }))]
  )
}

/**
 * Estimate gas for UserOperation
 * @param userOp - UserOperation to estimate
 * @returns Estimated gas values
 */
export async function estimateUserOperationGas(
  userOp: PackedUserOperation
): Promise<UserOperationGas> {
  // This would call eth_estimateUserOperationGas via bundler
  // For now, return defaults
  return {
    callGasLimit: 100_000n,
    verificationGasLimit: 100_000n,
    preVerificationGas: 21_000n,
    maxFeePerGas: 1_000_000_000n,
    maxPriorityFeePerGas: 1_000_000_000n,
  }
}

/**
 * Get UserOperation hash
 * @param userOp - UserOperation
 * @param entryPoint - EntryPoint address
 * @param chainId - Chain ID
 * @returns UserOperation hash
 */
export function getUserOperationHash(
  userOp: PackedUserOperation,
  entryPoint: Address,
  chainId: number
): Hex {
  // This would compute the actual hash used by EntryPoint
  // Simplified for now
  const packed = encodeAbiParameters(
    [
      { type: 'address', name: 'sender' },
      { type: 'uint256', name: 'nonce' },
      { type: 'bytes32', name: 'initCodeHash' },
      { type: 'bytes32', name: 'callDataHash' },
    ],
    [userOp.sender, userOp.nonce, toHex(0), toHex(0)]
  )

  return toHex(0) // Placeholder
}
