import { useState } from 'react'
import { sepolia } from 'viem/chains'
import { isWebAuthnSupported, type PasskeyCredential } from '@aakit/sdk'
import { PasskeySetup } from './components/PasskeySetup'
import { WalletDashboard } from './components/WalletDashboard'
import { CONTRACTS, BUNDLER_URL } from './config'

function App() {
  const [passkey, setPasskey] = useState<PasskeyCredential | null>(null)

  const isSupported = isWebAuthnSupported()

  if (!isSupported) {
    return (
      <div className="app">
        <div className="error-card">
          <h2>❌ WebAuthn Not Supported</h2>
          <p>
            Your browser doesn't support WebAuthn/Passkeys. Please use a modern browser:
          </p>
          <ul>
            <li>Chrome/Edge 67+</li>
            <li>Firefox 60+</li>
            <li>Safari 13+</li>
          </ul>
        </div>
      </div>
    )
  }

  return (
    <div className="app">
      <header>
        <h1>🔑 AAKit Demo Wallet</h1>
        <p>ERC-4337 Smart Wallet with Passkey Authentication</p>
      </header>

      <main>
        {!passkey ? (
          <PasskeySetup onPasskeyCreated={setPasskey} />
        ) : (
          <WalletDashboard
            passkey={passkey}
            config={{
              factory: CONTRACTS.factory,
              entryPoint: CONTRACTS.entryPoint,
              bundlerUrl: BUNDLER_URL,
              chain: sepolia,
            }}
          />
        )}
      </main>

      <footer>
        <p>
          Built with <a href="https://github.com/your-org/aakit">AAKit</a>
        </p>
      </footer>
    </div>
  )
}

export default App
