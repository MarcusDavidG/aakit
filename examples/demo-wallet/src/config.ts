/**
 * @file Configuration for demo wallet
 */

import { createConfig, http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import type { Address } from 'viem'

// AAKit contract addresses on Sepolia (example)
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032' as Address, // v0.7
  factory: '0x...' as Address, // Deploy factory first
  paymaster: '0x...' as Address, // Optional
}

// Bundler configuration
export const BUNDLER_URL = 'https://sepolia.bundler.example.com'

// Wagmi configuration
export const config = createConfig({
  chains: [sepolia],
  transports: {
    [sepolia.id]: http(),
  },
})
