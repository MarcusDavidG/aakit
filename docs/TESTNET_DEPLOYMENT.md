# Testnet Deployment Instructions

**Network:** Sepolia  
**Date:** Ready for deployment

## Prerequisites

### 1. Funded Wallet

Get Sepolia ETH from faucets:
- [Sepolia Faucet](https://sepoliafaucet.com/)
- [Alchemy Faucet](https://sepoliafaucet.com/)
- [Infura Faucet](https://www.infura.io/faucet/sepolia)

**Required:** ~0.2 ETH for full deployment

### 2. Environment Setup

```bash
cd contracts
cp .env.example .env

# Edit .env with your keys:
PRIVATE_KEY=your-private-key-here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR-PROJECT-ID
ETHERSCAN_API_KEY=your-etherscan-api-key
```

### 3. Verify Setup

```bash
# Check deployer balance
cast balance $DEPLOYER_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Should show > 0.2 ETH
```

## Deployment Steps

### Step 1: Deploy Contracts

```bash
cd contracts

# Deploy all contracts
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow

# Wait for deployment (2-3 minutes)
```

**Expected Output:**
```
========================================
    AAKit Deployment Summary
========================================
Network: 11155111 (Sepolia)
EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
----------------------------------------
AAKitWallet Implementation: 0x...
AAKitFactory: 0x...
PasskeyValidator: 0x...
VerifyingPaymaster: 0x...
========================================
```

### Step 2: Verify Deployment

```bash
# Check factory deployment
cast call $FACTORY_ADDRESS \
  "walletImplementation()" \
  --rpc-url $SEPOLIA_RPC_URL

# Check paymaster balance
cast call $PAYMASTER_ADDRESS \
  "getDeposit()" \
  --rpc-url $SEPOLIA_RPC_URL
```

### Step 3: Verify on Etherscan

Visit [sepolia.etherscan.io](https://sepolia.etherscan.io) and search for your contract addresses.

**Check:**
- [x] Source code verified
- [x] Contract creation successful
- [x] Constructor arguments correct

If verification failed:
```bash
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/path/Contract.sol:ContractName \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Step 4: Create Test Wallet

```bash
# Set factory address
export FACTORY_ADDRESS=0x...

# Create test wallet
forge script script/CreateWallet.s.sol:CreateWalletScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

**Expected Output:**
```
========================================
    Wallet Created Successfully
========================================
Wallet Address: 0x...
Owner: 0x...
Balance: 0.01 ETH
========================================
```

### Step 5: Update SDK Configuration

```typescript
// sdk/src/config.ts
export const SEPOLIA_CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  factory: '0x...', // From deployment
  paymaster: '0x...', // From deployment
}
```

### Step 6: Update Demo Apps

```typescript
// examples/demo-wallet/src/config.ts
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  factory: '0x...', // Your deployed factory
  paymaster: '0x...', // Your deployed paymaster
}

// examples/nft-minter/src/config.ts
// Update with same addresses
```

## Configure Bundler

### Option 1: Pimlico

```bash
# Sign up at pimlico.io
# Get API key

export BUNDLER_URL="https://api.pimlico.io/v2/sepolia/rpc?apikey=YOUR-API-KEY"
```

### Option 2: Stackup

```bash
# Sign up at stackup.sh
# Get API key

export BUNDLER_URL="https://api.stackup.sh/v1/node/YOUR-API-KEY"
```

### Option 3: Alchemy

```bash
# Sign up at alchemy.com
# Enable Account Abstraction

export BUNDLER_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY"
```

## Testing

### Test 1: Create Wallet via Demo

```bash
cd examples/demo-wallet
npm install
npm run dev

# Open http://localhost:5173
# Create passkey
# Verify wallet address matches factory.getAddress()
```

### Test 2: Send Transaction

```bash
# In demo wallet:
# 1. Fund wallet with Sepolia ETH
# 2. Send test transaction
# 3. Verify on Etherscan
```

### Test 3: NFT Minting

```bash
cd examples/nft-minter

# Deploy test NFT contract first
# Or use existing test NFT

# Update NFT_CONTRACT in config.ts

npm install
npm run dev

# Mint NFT with passkey auth
```

## Monitoring

### Set Up Monitoring

1. **Etherscan Alerts**
   - Add contracts to watchlist
   - Enable email notifications

2. **Tenderly**
   - Import contracts
   - Set up alerts
   - Monitor gas usage

3. **Custom Monitoring**
```typescript
// Monitor wallet events
const wallet = await ethers.getContractAt('AAKitWallet', walletAddress)

wallet.on('Executed', (target, value, data) => {
  console.log('Transaction executed:', { target, value, data })
})
```

## Troubleshooting

### Issue: Deployment Fails

**Check:**
- Sufficient ETH in deployer
- RPC URL is correct
- Network is Sepolia (chainId: 11155111)

**Solution:**
```bash
# Check balance
cast balance $DEPLOYER_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Try with more gas
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --gas-limit 10000000
```

### Issue: Verification Fails

**Solution:**
```bash
# Verify manually
forge verify-contract \
  $CONTRACT_ADDRESS \
  src/wallet/AAKitWallet.sol:AAKitWallet \
  --chain-id 11155111 \
  --constructor-args $(cast abi-encode "constructor(address)" $ENTRYPOINT)
```

### Issue: Test Wallet Creation Fails

**Check:**
- Factory is deployed
- Implementation is deployed
- FACTORY_ADDRESS is correct

### Issue: Transaction Fails

**Check:**
- Wallet has sufficient ETH
- Bundler is configured
- Gas parameters are reasonable
- EntryPoint address is correct

## Post-Deployment Checklist

- [ ] All contracts deployed successfully
- [ ] Contracts verified on Etherscan
- [ ] Test wallet created
- [ ] SDK config updated
- [ ] Demo apps updated
- [ ] Bundler configured
- [ ] Test transaction sent
- [ ] Monitoring set up
- [ ] Documentation updated
- [ ] Team notified

## Deployment Addresses

Save these to `deployments/sepolia.json`:

```json
{
  "chainId": 11155111,
  "network": "sepolia",
  "timestamp": "2025-12-04",
  "deployer": "0x...",
  "contracts": {
    "entryPoint": "0x0000000071727De22E5E9d8BAf0edAc6f37da032",
    "walletImplementation": "0x...",
    "factory": "0x...",
    "passkeyValidator": "0x...",
    "verifyingPaymaster": "0x..."
  },
  "bundlerUrl": "https://...",
  "explorerUrl": "https://sepolia.etherscan.io"
}
```

## Next Steps

1. **Monitor for 2-4 weeks**
   - Watch for any issues
   - Collect user feedback
   - Monitor gas costs

2. **Community Testing**
   - Invite developers
   - Gather feedback
   - Fix bugs

3. **Prepare for Audit**
   - Code freeze
   - Document changes
   - Prepare audit materials

## Support

- **Issues:** [GitHub Issues](https://github.com/your-org/aakit/issues)
- **Discord:** [Join community](https://discord.gg/aakit)
- **Docs:** [docs.aakit.io](https://docs.aakit.io)

---

**Ready to deploy?** Follow the steps above to deploy AAKit to Sepolia testnet! 🚀
