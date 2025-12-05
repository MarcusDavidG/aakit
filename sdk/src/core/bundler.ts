/**
 * @file Bundler client for ERC-4337
 * @description Client for interacting with ERC-4337 bundlers
 */

import type { Address, Hex, Transport, Chain } from 'viem'
// import { http } from 'viem' // Unused for now
import type { PackedUserOperation, UserOperationReceipt } from '../types/userOperation'

/**
 * Bundler client configuration
 */
export interface BundlerConfig {
  bundlerUrl: string
  entryPoint: Address
  chain?: Chain
  transport?: Transport
}

/**
 * Bundler RPC methods
 */
export interface BundlerMethods {
  /**
   * Send a UserOperation to the bundler
   */
  sendUserOperation(userOp: PackedUserOperation, entryPoint: Address): Promise<Hex>

  /**
   * Get UserOperation receipt
   */
  getUserOperationReceipt(userOpHash: Hex): Promise<UserOperationReceipt | null>

  /**
   * Get UserOperation by hash
   */
  getUserOperationByHash(userOpHash: Hex): Promise<PackedUserOperation | null>

  /**
   * Get supported EntryPoints
   */
  getSupportedEntryPoints(): Promise<Address[]>

  /**
   * Estimate UserOperation gas
   */
  estimateUserOperationGas(
    userOp: PackedUserOperation,
    entryPoint: Address
  ): Promise<{
    preVerificationGas: bigint
    verificationGasLimit: bigint
    callGasLimit: bigint
  }>
}

/**
 * Create a bundler client
 * @param config - Bundler configuration
 * @returns Bundler client with RPC methods
 */
export function createBundlerClient(config: BundlerConfig): BundlerMethods {
  const { bundlerUrl } = config

  // Create HTTP transport for bundler (unused for now)
  // const transport = http(bundlerUrl)

  /**
   * Make bundler RPC call
   */
  async function bundlerRpc<T>(method: string, params: unknown[]): Promise<T> {
    const response = await fetch(bundlerUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method,
        params,
      }),
    })

    if (!response.ok) {
      throw new Error(`Bundler RPC error: ${response.statusText}`)
    }

    const data = await response.json()

    if (data.error) {
      throw new Error(`Bundler error: ${data.error.message}`)
    }

    return data.result
  }

  return {
    async sendUserOperation(userOp: PackedUserOperation, entryPoint: Address): Promise<Hex> {
      return bundlerRpc<Hex>('eth_sendUserOperation', [userOp, entryPoint])
    },

    async getUserOperationReceipt(
      userOpHash: Hex
    ): Promise<UserOperationReceipt | null> {
      return bundlerRpc<UserOperationReceipt | null>('eth_getUserOperationReceipt', [
        userOpHash,
      ])
    },

    async getUserOperationByHash(
      userOpHash: Hex
    ): Promise<PackedUserOperation | null> {
      return bundlerRpc<PackedUserOperation | null>('eth_getUserOperationByHash', [
        userOpHash,
      ])
    },

    async getSupportedEntryPoints(): Promise<Address[]> {
      return bundlerRpc<Address[]>('eth_supportedEntryPoints', [])
    },

    async estimateUserOperationGas(
      userOp: PackedUserOperation,
      entryPoint: Address
    ): Promise<{
      preVerificationGas: bigint
      verificationGasLimit: bigint
      callGasLimit: bigint
    }> {
      const result = await bundlerRpc<{
        preVerificationGas: Hex
        verificationGasLimit: Hex
        callGasLimit: Hex
      }>('eth_estimateUserOperationGas', [userOp, entryPoint])

      return {
        preVerificationGas: BigInt(result.preVerificationGas),
        verificationGasLimit: BigInt(result.verificationGasLimit),
        callGasLimit: BigInt(result.callGasLimit),
      }
    },
  }
}

/**
 * Wait for UserOperation to be included in a block
 * @param bundler - Bundler client
 * @param userOpHash - UserOperation hash
 * @param options - Polling options
 * @returns UserOperation receipt
 */
export async function waitForUserOperation(
  bundler: BundlerMethods,
  userOpHash: Hex,
  options: {
    timeout?: number
    interval?: number
  } = {}
): Promise<UserOperationReceipt> {
  const { timeout = 30_000, interval = 1_000 } = options
  const startTime = Date.now()

  while (Date.now() - startTime < timeout) {
    const receipt = await bundler.getUserOperationReceipt(userOpHash)

    if (receipt) {
      return receipt
    }

    await new Promise((resolve) => setTimeout(resolve, interval))
  }

  throw new Error(`UserOperation ${userOpHash} not included within ${timeout}ms`)
}
