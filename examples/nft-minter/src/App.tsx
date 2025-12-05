import { useState, useEffect } from 'react'
import { createAAKitWallet } from '@aakit/sdk/wallet'
import { createPasskey, isWebAuthnSupported } from '@aakit/sdk/passkey'
import { encodeFunctionData, parseAbi, type Address } from 'viem'
import type { AAKitWallet } from '@aakit/sdk/wallet'
import type { PasskeyCredential } from '@aakit/sdk/passkey'
import { CONTRACTS, BUNDLER_URL, CHAIN, APP_CONFIG, NFT_CONTRACT } from './config'

// Simple ERC721 ABI for minting
const NFT_ABI = parseAbi([
  'function mint(address to, uint256 tokenId) external',
  'function ownerOf(uint256 tokenId) view returns (address)',
  'function balanceOf(address owner) view returns (uint256)',
])

function App() {
  const [wallet, setWallet] = useState<AAKitWallet | null>(null)
  const [address, setAddress] = useState<Address | null>(null)
  const [username, setUsername] = useState('')
  const [loading, setLoading] = useState(false)
  const [mintLoading, setMintLoading] = useState(false)
  const [tokenId, setTokenId] = useState('1')
  const [txHash, setTxHash] = useState<string | null>(null)

  // Check for existing session
  useEffect(() => {
    const stored = localStorage.getItem('aakit-nft-passkey')
    if (stored) {
      const passkey: PasskeyCredential = JSON.parse(stored)
      restoreWallet(passkey)
    }
  }, [])

  const restoreWallet = async (passkey: PasskeyCredential) => {
    const w = createAAKitWallet({
      ...CONTRACTS,
      bundlerUrl: BUNDLER_URL,
      chain: CHAIN,
      owner: { type: 'passkey', credential: passkey },
    })

    const addr = await w.getAddress()
    setWallet(w)
    setAddress(addr)
  }

  const handleConnect = async () => {
    if (!username) return

    if (!isWebAuthnSupported()) {
      alert('WebAuthn not supported in this browser')
      return
    }

    setLoading(true)
    try {
      const passkey = await createPasskey({
        userId: username,
        userName: username,
        rpName: APP_CONFIG.rpName,
        rpId: APP_CONFIG.rpId,
      })

      localStorage.setItem('aakit-nft-passkey', JSON.stringify(passkey))
      await restoreWallet(passkey)
    } catch (error) {
      console.error('Failed to create wallet:', error)
      alert('Failed to create wallet. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleDisconnect = () => {
    localStorage.removeItem('aakit-nft-passkey')
    setWallet(null)
    setAddress(null)
  }

  const handleMint = async () => {
    if (!wallet || !address) return

    setMintLoading(true)
    setTxHash(null)

    try {
      // Encode mint function call
      const mintData = encodeFunctionData({
        abi: NFT_ABI,
        functionName: 'mint',
        args: [address, BigInt(tokenId)],
      })

      // Send transaction via AAKit wallet
      const result = await wallet.sendTransaction({
        to: NFT_CONTRACT,
        data: mintData,
      })

      setTxHash(result.userOpHash)

      // Wait for confirmation
      const receipt = await result.wait()

      if (receipt.success) {
        alert(`NFT #${tokenId} minted successfully! 🎉`)
        setTokenId((parseInt(tokenId) + 1).toString())
      } else {
        alert('Transaction failed')
      }
    } catch (error) {
      console.error('Minting failed:', error)
      alert('Failed to mint NFT. Please try again.')
    } finally {
      setMintLoading(false)
    }
  }

  return (
    <div className="app">
      <header>
        <h1>🎨 AAKit NFT Minter</h1>
        <p>Mint NFTs with Passkey Authentication</p>
      </header>

      <main>
        {!wallet ? (
          <div className="card">
            <h2>Connect Your Wallet</h2>
            <p>Create a wallet secured by your device's biometric authentication.</p>

            <div className="form">
              <input
                type="text"
                placeholder="Enter username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                disabled={loading}
              />
              <button onClick={handleConnect} disabled={loading || !username}>
                {loading ? '⏳ Creating Wallet...' : '🔐 Connect with Passkey'}
              </button>
            </div>

            {!isWebAuthnSupported() && (
              <div className="warning">
                ⚠️ WebAuthn not supported. Please use Chrome 67+, Firefox 60+, or
                Safari 13+
              </div>
            )}
          </div>
        ) : (
          <>
            <div className="card">
              <h2>Your Wallet</h2>
              <div className="wallet-info">
                <div className="info-row">
                  <span className="label">Address:</span>
                  <code className="address">{address}</code>
                </div>
              </div>
              <button onClick={handleDisconnect} className="secondary">
                Disconnect
              </button>
            </div>

            <div className="card">
              <h2>Mint NFT</h2>
              <p>
                Mint an NFT to your wallet. This will trigger biometric authentication.
              </p>

              <div className="form">
                <div className="form-group">
                  <label>Token ID</label>
                  <input
                    type="number"
                    value={tokenId}
                    onChange={(e) => setTokenId(e.target.value)}
                    disabled={mintLoading}
                    min="1"
                  />
                </div>

                {txHash && (
                  <div className="tx-hash">
                    <strong>UserOp Hash:</strong> {txHash}
                  </div>
                )}

                <button onClick={handleMint} disabled={mintLoading || !tokenId}>
                  {mintLoading ? '⏳ Minting...' : '✨ Mint NFT'}
                </button>
              </div>

              <div className="info-box">
                <p>
                  💡 <strong>Note:</strong> This will prompt your device's biometric
                  authentication (Face ID, Touch ID, etc.)
                </p>
              </div>
            </div>
          </>
        )}
      </main>

      <footer>
        <p>
          Built with <a href="https://github.com/your-org/aakit">AAKit</a>
        </p>
        <p>ERC-4337 Smart Wallet + WebAuthn Passkey</p>
      </footer>
    </div>
  )
}

export default App
