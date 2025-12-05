/**
 * @file Configuration for NFT Minter
 */

import { sepolia } from 'viem/chains'
import type { Address } from 'viem'

// AAKit contract addresses (DEPLOYED!)
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032' as Address,
  factory: '0xeA1880ea125559e52c4159B00dFc98c70C193D99' as Address,
  paymaster: '0x30E1f3431b28F53Ca7Aec8CFfEe99c91cF049021' as Address,
}

// Simple NFT contract address (deploy your own or use existing)
// TODO: Deploy a simple NFT contract for testing
export const NFT_CONTRACT = '0x...' as Address

// Bundler configuration (Pimlico)
export const BUNDLER_URL = 'https://api.pimlico.io/v2/sepolia/rpc?apikey=pim_igzXAaZfEN844Ht3TWGfhw'

// Chain configuration
export const CHAIN = sepolia

// App configuration
export const APP_CONFIG = {
  rpName: 'AAKit NFT Minter',
  rpId: window.location.hostname,
}
