/**
 * @file AAKit wallet client
 * @description High-level client for interacting with AAKit smart wallets
 */

import {
  type Address,
  type Hex,
  type PublicClient,
  createPublicClient,
  http,
  encodeFunctionData,
  parseAbi,
} from 'viem'
import { createBundlerClient, waitForUserOperation } from '../core/bundler'
import {
  buildUserOperation,
  encodeExecutionMode,
  encodeSingleExecution,
  encodeBatchExecution,
  DEFAULT_GAS_VALUES,
} from '../core/userOp'
import { authenticateWithPasskey } from '../passkey/webauthn'
import type {
  AAKitWalletConfig,
  TransactionParams,
  BatchTransactionParams,
  SendTransactionResult,
  DeploymentStatus,
} from './types'
import type { PackedUserOperation } from '../types/userOperation'

/**
 * AAKit wallet client
 */
export class AAKitWallet {
  private config: AAKitWalletConfig
  private publicClient: PublicClient
  private bundler: ReturnType<typeof createBundlerClient>
  private _address: Address | null = null
  private _deployed: boolean = false

  constructor(config: AAKitWalletConfig) {
    this.config = config
    this._address = config.address || null

    // Create public client
    this.publicClient = createPublicClient({
      chain: config.chain,
      transport: http(),
    })

    // Create bundler client
    this.bundler = createBundlerClient({
      bundlerUrl: config.bundlerUrl,
      entryPoint: config.entryPoint,
      chain: config.chain,
    })
  }

  /**
   * Get wallet address
   */
  async getAddress(): Promise<Address> {
    if (this._address) {
      return this._address
    }

    // Calculate counterfactual address
    this._address = await this.calculateAddress()
    return this._address
  }

  /**
   * Calculate wallet address (counterfactual)
   */
  private async calculateAddress(): Promise<Address> {
    // Call factory.getAddress(ownerBytes, salt)
    const ownerBytes = this.getOwnerBytes()
    const salt = 0n

    const address = await this.publicClient.readContract({
      address: this.config.factory,
      abi: parseAbi([
        'function getAddress(bytes calldata ownerBytes, uint256 salt) view returns (address)',
      ]),
      functionName: 'getAddress',
      args: [ownerBytes, salt],
    })

    return address as Address
  }

  /**
   * Check if wallet is deployed
   */
  async isDeployed(): Promise<boolean> {
    const address = await this.getAddress()
    const code = await this.publicClient.getBytecode({ address })
    this._deployed = code !== undefined && code !== '0x'
    return this._deployed
  }

  /**
   * Get deployment status
   */
  async getDeploymentStatus(): Promise<DeploymentStatus> {
    const address = await this.getAddress()
    const deployed = await this.isDeployed()

    return {
      deployed,
      address,
    }
  }

  /**
   * Send a transaction
   */
  async sendTransaction(params: TransactionParams): Promise<SendTransactionResult> {
    const { to, value = 0n, data = '0x' } = params

    // Build execution calldata
    const mode = encodeExecutionMode({ callType: 'call', execType: 'revert' })
    const executionData = encodeSingleExecution(to, value, data)

    // Create execute calldata for wallet
    const callData = encodeFunctionData({
      abi: parseAbi([
        'function execute(bytes32 mode, bytes calldata executionCalldata) external',
      ]),
      functionName: 'execute',
      args: [mode, executionData],
    })

    // Build UserOperation
    const userOp = await this.buildUserOperation(callData)

    // Sign UserOperation
    const signedUserOp = await this.signUserOperation(userOp)

    // Send to bundler
    const userOpHash = await this.bundler.sendUserOperation(
      signedUserOp,
      this.config.entryPoint
    )

    return {
      userOpHash,
      wait: async () => {
        const receipt = await waitForUserOperation(this.bundler, userOpHash)
        return {
          transactionHash: receipt.receipt.transactionHash,
          blockNumber: receipt.receipt.blockNumber,
          gasUsed: receipt.actualGasUsed,
          success: receipt.success,
        }
      },
    }
  }

  /**
   * Send a batch of transactions
   */
  async sendBatchTransaction(
    params: BatchTransactionParams
  ): Promise<SendTransactionResult> {
    const { transactions } = params

    // Build batch execution calldata
    const mode = encodeExecutionMode({ callType: 'batch', execType: 'revert' })
    const executions = transactions.map((tx) => ({
      target: tx.to,
      value: tx.value || 0n,
      data: tx.data || '0x',
    }))
    const executionData = encodeBatchExecution(executions)

    // Create execute calldata for wallet
    const callData = encodeFunctionData({
      abi: parseAbi([
        'function execute(bytes32 mode, bytes calldata executionCalldata) external',
      ]),
      functionName: 'execute',
      args: [mode, executionData],
    })

    // Build UserOperation
    const userOp = await this.buildUserOperation(callData)

    // Sign UserOperation
    const signedUserOp = await this.signUserOperation(userOp)

    // Send to bundler
    const userOpHash = await this.bundler.sendUserOperation(
      signedUserOp,
      this.config.entryPoint
    )

    return {
      userOpHash,
      wait: async () => {
        const receipt = await waitForUserOperation(this.bundler, userOpHash)
        return {
          transactionHash: receipt.receipt.transactionHash,
          blockNumber: receipt.receipt.blockNumber,
          gasUsed: receipt.actualGasUsed,
          success: receipt.success,
        }
      },
    }
  }

  /**
   * Build UserOperation
   */
  private async buildUserOperation(callData: Hex): Promise<PackedUserOperation> {
    const address = await this.getAddress()
    const deployed = await this.isDeployed()

    // Get nonce
    const nonce = await this.getNonce()

    // Build initCode if not deployed
    let factory: Address | undefined
    let factoryData: Hex | undefined

    if (!deployed) {
      factory = this.config.factory
      const ownerBytes = this.getOwnerBytes()
      factoryData = encodeFunctionData({
        abi: parseAbi([
          'function createAccount(bytes calldata ownerBytes, uint256 salt) returns (address)',
        ]),
        functionName: 'createAccount',
        args: [ownerBytes, 0n],
      })
    }

    // Estimate gas
    const gasEstimate = await this.bundler.estimateUserOperationGas(
      buildUserOperation({
        sender: address,
        nonce,
        factory,
        factoryData,
        callData,
        ...DEFAULT_GAS_VALUES,
      }),
      this.config.entryPoint
    )

    // Build final UserOperation
    return buildUserOperation({
      sender: address,
      nonce,
      factory,
      factoryData,
      callData,
      callGasLimit: gasEstimate.callGasLimit,
      verificationGasLimit: gasEstimate.verificationGasLimit,
      preVerificationGas: gasEstimate.preVerificationGas,
      maxFeePerGas: DEFAULT_GAS_VALUES.maxFeePerGas,
      maxPriorityFeePerGas: DEFAULT_GAS_VALUES.maxPriorityFeePerGas,
      paymaster: this.config.paymaster?.address,
    })
  }

  /**
   * Sign UserOperation
   */
  private async signUserOperation(
    userOp: PackedUserOperation
  ): Promise<PackedUserOperation> {
    if (this.config.owner.type === 'eoa') {
      // EOA signing
      const { signer } = this.config.owner
      const userOpHash = await this.getUserOpHash(userOp)

      // Sign with EOA
      const signature = await signer.signMessage({
        message: { raw: userOpHash },
      })

      return {
        ...userOp,
        signature,
      }
    } else {
      // Passkey signing
      const userOpHash = await this.getUserOpHash(userOp)

      // Sign with passkey
      const assertion = await authenticateWithPasskey({
        rpId: window.location.hostname,
        challenge: Buffer.from(userOpHash.slice(2), 'hex'),
        credentialId: this.config.owner.credential.id,
      })

      // Encode WebAuthnAuth struct
      const signature = encodeFunctionData({
        abi: parseAbi([
          'struct WebAuthnAuth { bytes authenticatorData; bytes clientDataJSON; uint256 challengeIndex; uint256 typeIndex; uint256 r; uint256 s; }',
        ]),
        functionName: 'dummy', // Not used, just for encoding
        args: [
          {
            authenticatorData: assertion.authenticatorData,
            clientDataJSON: assertion.clientDataJSON,
            challengeIndex: BigInt(assertion.challengeIndex),
            typeIndex: BigInt(assertion.typeIndex),
            r: assertion.r,
            s: assertion.s,
          },
        ],
      })

      return {
        ...userOp,
        signature,
      }
    }
  }

  /**
   * Get UserOperation hash
   */
  private async getUserOpHash(userOp: PackedUserOperation): Promise<Hex> {
    // Call EntryPoint.getUserOpHash
    const hash = await this.publicClient.readContract({
      address: this.config.entryPoint,
      abi: parseAbi([
        'function getUserOpHash(tuple(address sender, uint256 nonce, bytes initCode, bytes callData, bytes32 accountGasLimits, uint256 preVerificationGas, bytes32 gasFees, bytes paymasterAndData, bytes signature) userOp) view returns (bytes32)',
      ]),
      functionName: 'getUserOpHash',
      args: [userOp],
    })

    return hash as Hex
  }

  /**
   * Get nonce
   */
  private async getNonce(): Promise<bigint> {
    const address = await this.getAddress()

    const nonce = await this.publicClient.readContract({
      address: this.config.entryPoint,
      abi: parseAbi([
        'function getNonce(address sender, uint192 key) view returns (uint256)',
      ]),
      functionName: 'getNonce',
      args: [address, 0n],
    })

    return nonce as bigint
  }

  /**
   * Get owner bytes
   */
  private getOwnerBytes(): Hex {
    if (this.config.owner.type === 'eoa') {
      // Address owner (20 bytes padded to 32)
      return this.config.owner.address
    } else {
      // Passkey owner (64 bytes: x || y)
      const { publicKeyX, publicKeyY } = this.config.owner.credential
      return `${publicKeyX}${publicKeyY.slice(2)}` as Hex
    }
  }
}

/**
 * Create AAKit wallet client
 * @param config - Wallet configuration
 * @returns AAKit wallet instance
 */
export function createAAKitWallet(config: AAKitWalletConfig): AAKitWallet {
  return new AAKitWallet(config)
}
