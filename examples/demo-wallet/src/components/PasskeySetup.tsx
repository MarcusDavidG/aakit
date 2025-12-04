import { useState } from 'react'
import { createPasskey } from '@aakit/sdk/passkey'
import type { PasskeyCredential } from '@aakit/sdk/passkey'

interface PasskeySetupProps {
  onPasskeyCreated: (passkey: PasskeyCredential) => void
}

export function PasskeySetup({ onPasskeyCreated }: PasskeySetupProps) {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [userName, setUserName] = useState('')

  const handleCreatePasskey = async () => {
    if (!userName.trim()) {
      setError('Please enter a username')
      return
    }

    setLoading(true)
    setError(null)

    try {
      const passkey = await createPasskey({
        userId: userName,
        userName,
        rpName: 'AAKit Demo Wallet',
        rpId: window.location.hostname,
        authenticatorAttachment: 'platform',
        userVerification: 'required',
      })

      // Store passkey in localStorage for demo
      localStorage.setItem('aakit-passkey', JSON.stringify(passkey))

      onPasskeyCreated(passkey)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create passkey')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="card">
      <h2>🔐 Setup Your Passkey</h2>
      <p>
        Create a passkey to secure your smart wallet. Your passkey is stored securely on
        your device.
      </p>

      <div className="form">
        <div className="form-group">
          <label htmlFor="username">Username</label>
          <input
            id="username"
            type="text"
            value={userName}
            onChange={(e) => setUserName(e.target.value)}
            placeholder="Enter your username"
            disabled={loading}
          />
        </div>

        {error && <div className="error">{error}</div>}

        <button onClick={handleCreatePasskey} disabled={loading || !userName.trim()}>
          {loading ? '⏳ Creating Passkey...' : '✨ Create Passkey'}
        </button>
      </div>

      <div className="info-box">
        <h3>ℹ️ What is a Passkey?</h3>
        <ul>
          <li>Stored securely on your device (not on servers)</li>
          <li>Uses biometric auth (Face ID, Touch ID, etc.)</li>
          <li>More secure than passwords</li>
          <li>Can't be phished or leaked</li>
        </ul>
      </div>
    </div>
  )
}
