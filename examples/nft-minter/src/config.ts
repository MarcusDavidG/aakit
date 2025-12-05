/**
 * @file Configuration for NFT Minter
 */

import { sepolia } from 'viem/chains'
import type { Address } from 'viem'

// AAKit contract addresses (update after deployment)
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032' as Address,
  factory: '0x...' as Address, // Update with deployed factory
  paymaster: '0x...' as Address, // Optional: for gasless minting
}

// Simple NFT contract address (deploy your own or use existing)
export const NFT_CONTRACT = '0x...' as Address

// Bundler configuration
export const BUNDLER_URL = 'https://sepolia.bundler.example.com'

// Chain configuration
export const CHAIN = sepolia

// App configuration
export const APP_CONFIG = {
  rpName: 'AAKit NFT Minter',
  rpId: window.location.hostname,
}
