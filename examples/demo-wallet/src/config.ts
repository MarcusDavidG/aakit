/**
 * @file Configuration for demo wallet
 */

import { createConfig, http } from 'wagmi'
import { sepolia } from 'wagmi/chains'
import type { Address } from 'viem'

// AAKit contract addresses on Sepolia (DEPLOYED!)
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032' as Address, // ERC-4337 v0.7
  factory: '0xeA1880ea125559e52c4159B00dFc98c70C193D99' as Address,
  paymaster: '0x30E1f3431b28F53Ca7Aec8CFfEe99c91cF049021' as Address,
}

// Bundler configuration (Pimlico)
export const BUNDLER_URL = 'https://api.pimlico.io/v2/sepolia/rpc?apikey=pim_igzXAaZfEN844Ht3TWGfhw'

// Wagmi configuration with Infura RPC
export const config = createConfig({
  chains: [sepolia],
  transports: {
    [sepolia.id]: http('https://sepolia.infura.io/v3/1b98a5f34e8c495d989b39cdb459ae9e'),
  },
})
