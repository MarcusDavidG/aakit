import { useEffect, useState } from 'react'
import { formatEther, parseEther, type Address } from 'viem'
import { createAAKitWallet, type PasskeyCredential, type AAKitWalletConfig } from '@aakit/sdk'

interface WalletDashboardProps {
  passkey: PasskeyCredential
  config: Omit<AAKitWalletConfig, 'owner'>
}

export function WalletDashboard({ passkey, config }: WalletDashboardProps) {
  const [wallet] = useState(() =>
    createAAKitWallet({
      ...config,
      owner: {
        type: 'passkey',
        credential: passkey,
      },
    })
  )

  const [address, setAddress] = useState<Address | null>(null)
  const [deployed, setDeployed] = useState(false)
  const [balance] = useState<bigint>(0n)
  const [loading, setLoading] = useState(true)

  // Send transaction form
  const [sendTo, setSendTo] = useState('')
  const [sendAmount, setSendAmount] = useState('')
  const [sending, setSending] = useState(false)
  const [txHash, setTxHash] = useState<string | null>(null)

  useEffect(() => {
    loadWalletInfo()
  }, [])

  const loadWalletInfo = async () => {
    setLoading(true)
    try {
      console.log('Loading wallet info...')
      const addr = await wallet.getAddress()
      console.log('Got address:', addr)
      setAddress(addr)

      const status = await wallet.getDeploymentStatus()
      console.log('Deployment status:', status)
      setDeployed(status.deployed)

      // TODO: Fetch balance from chain
      // const bal = await publicClient.getBalance({ address: addr })
      // setBalance(bal)
    } catch (err) {
      console.error('Failed to load wallet info:', err)
      alert(`Error loading wallet: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setLoading(false)
    }
  }

  const handleSendTransaction = async () => {
    if (!sendTo || !sendAmount) return

    setSending(true)
    setTxHash(null)

    try {
      const result = await wallet.sendTransaction({
        to: sendTo as Address,
        value: parseEther(sendAmount),
      })

      setTxHash(result.userOpHash)

      // Wait for transaction
      const receipt = await result.wait()

      if (receipt.success) {
        alert('✅ Transaction successful!')
        // Reload balance
        await loadWalletInfo()
      } else {
        alert('❌ Transaction failed')
      }
    } catch (err) {
      alert(`Error: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setSending(false)
    }
  }

  if (loading) {
    return (
      <div className="card">
        <p>⏳ Loading wallet...</p>
      </div>
    )
  }

  return (
    <div className="dashboard">
      <div className="card">
        <h2>👛 Your Smart Wallet</h2>

        <div className="wallet-info">
          <div className="info-row">
            <span className="label">Address:</span>
            <code className="address">
              {address || 'Loading...'}
            </code>
            {address && (
              <button
                onClick={() => {
                  navigator.clipboard.writeText(address)
                  alert('Address copied to clipboard!')
                }}
                style={{ marginLeft: '10px', padding: '4px 8px', fontSize: '12px' }}
              >
                Copy
              </button>
            )}
          </div>

          <div className="info-row">
            <span className="label">Status:</span>
            <span className={deployed ? 'status deployed' : 'status undeployed'}>
              {deployed ? '✅ Deployed' : '⚠️ Not Deployed'}
            </span>
          </div>

          <div className="info-row">
            <span className="label">Balance:</span>
            <span className="balance">{formatEther(balance)} ETH</span>
          </div>

          <div className="info-row">
            <span className="label">Passkey:</span>
            <span className="passkey-id">{passkey.id.slice(0, 20)}...</span>
          </div>
        </div>
      </div>

      <div className="card">
        <h3>💸 Send Transaction</h3>

        <div className="form">
          <div className="form-group">
            <label>To Address</label>
            <input
              type="text"
              value={sendTo}
              onChange={(e) => setSendTo(e.target.value)}
              placeholder="0x..."
              disabled={sending}
            />
          </div>

          <div className="form-group">
            <label>Amount (ETH)</label>
            <input
              type="text"
              value={sendAmount}
              onChange={(e) => setSendAmount(e.target.value)}
              placeholder="0.1"
              disabled={sending}
            />
          </div>

          {txHash && (
            <div className="tx-hash">
              <strong>UserOp Hash:</strong> {txHash}
            </div>
          )}

          <button
            onClick={handleSendTransaction}
            disabled={sending || !sendTo || !sendAmount}
          >
            {sending ? '⏳ Signing with Passkey...' : '🚀 Send Transaction'}
          </button>
        </div>

        <div className="info-box">
          <p>
            💡 <strong>Note:</strong> This will trigger your device's biometric
            authentication (Face ID, Touch ID, etc.)
          </p>
        </div>
      </div>
    </div>
  )
}
