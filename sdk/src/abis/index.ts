/**
 * @file Contract ABIs
 * @description Exported contract ABIs for use with viem
 */

import AAKitWalletABI from './AAKitWallet.json'
import AAKitFactoryABI from './AAKitFactory.json'
import PasskeyValidatorABI from './PasskeyValidator.json'
import VerifyingPaymasterABI from './VerifyingPaymaster.json'
import IERC4337ABI from './IERC4337.json'
import IERC7579ABI from './IERC7579.json'

export const abis = {
  AAKitWallet: AAKitWalletABI,
  AAKitFactory: AAKitFactoryABI,
  PasskeyValidator: PasskeyValidatorABI,
  VerifyingPaymaster: VerifyingPaymasterABI,
  IERC4337: IERC4337ABI,
  IERC7579: IERC7579ABI,
} as const

// Re-export for convenience
export {
  AAKitWalletABI,
  AAKitFactoryABI,
  PasskeyValidatorABI,
  VerifyingPaymasterABI,
  IERC4337ABI,
  IERC7579ABI,
}

// Type-safe ABI access
export type ABI = typeof abis
export type ABIName = keyof ABI
