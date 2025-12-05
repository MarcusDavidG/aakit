# AAKit Deployment Guide

Complete guide for deploying AAKit contracts to various networks.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Deployment](#local-deployment)
3. [Testnet Deployment](#testnet-deployment)
4. [Mainnet Deployment](#mainnet-deployment)
5. [Post-Deployment](#post-deployment)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Foundry** - Smart contract development framework
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

- **Git** - Version control
  ```bash
  git --version
  ```

- **Node.js** - For SDK testing (v18+)
  ```bash
  node --version
  ```

### Required Accounts

1. **Deployer Wallet**
   - Funded with native token (ETH)
   - Private key exported
   - **Security:** Use hardware wallet for mainnet!

2. **Etherscan API Key** (for verification)
   - Get from [etherscan.io/myapikey](https://etherscan.io/myapikey)

3. **RPC Provider** (Infura, Alchemy, etc.)
   - Get API key from provider
   - Configure RPC URLs

### Initial Setup

```bash
# Clone repository
git clone https://github.com/your-org/aakit.git
cd aakit/contracts

# Install dependencies
forge install

# Create .env file
cp .env.example .env

# Edit .env with your keys (NEVER COMMIT THIS FILE!)
nano .env
```

**Example .env:**
```bash
PRIVATE_KEY=0x... # Your deployer private key
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR-PROJECT-ID
ETHERSCAN_API_KEY=YOUR-ETHERSCAN-API-KEY
PAYMASTER_SIGNER=0x... # Address that signs paymaster operations
PAYMASTER_SPENDING_CAP=1000000000000000000 # 1 ETH
```

## Local Deployment

### Step 1: Start Local Node

```bash
# Terminal 1: Start Anvil
anvil
```

Anvil provides:
- 10 pre-funded accounts
- Instant mining
- Fork mainnet (optional)

### Step 2: Deploy Contracts

```bash
# Terminal 2: Deploy to local node
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url http://localhost:8545 \
  --broadcast

# Output will show deployed addresses
```

### Step 3: Verify Deployment

```bash
# Check factory deployment
cast call $FACTORY_ADDRESS \
  "walletImplementation()" \
  --rpc-url http://localhost:8545

# Create test wallet
forge script script/CreateWallet.s.sol:CreateWalletScript \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --slow
```

### Step 4: Test with SDK

```bash
cd ../sdk

# Update config with local addresses
# sdk/src/config.ts:
# factory: '0x...' (from deployment)

npm run dev
```

## Testnet Deployment

### Supported Testnets

- **Sepolia** (Recommended)
- Base Sepolia
- Optimism Sepolia
- Arbitrum Sepolia

### Step 1: Fund Deployer

Get testnet ETH:
- Sepolia: [sepoliafaucet.com](https://sepoliafaucet.com/)
- Multi-chain: [faucet.quicknode.com](https://faucet.quicknode.com/)

Verify balance:
```bash
cast balance $DEPLOYER_ADDRESS --rpc-url $SEPOLIA_RPC_URL
```

Need at least: **0.2 ETH** for deployment

### Step 2: Deploy to Sepolia

```bash
# Deploy contracts
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow

# Wait for verification (can take 1-2 minutes)
```

**Expected Gas Costs:**
```
PasskeyValidator:       ~800k gas
AAKitWallet (impl):    ~3.2M gas
AAKitFactory:          ~1.5M gas
VerifyingPaymaster:    ~1.8M gas
Total:                 ~7.3M gas (~0.15 ETH at 20 gwei)
```

### Step 3: Save Deployment Info

Deployment addresses are automatically saved to `deployments/deployment-11155111.json`:

```json
{
  "chainId": 11155111,
  "entryPoint": "0x0000000071727De22E5E9d8BAf0edAc6f37da032",
  "walletImplementation": "0x...",
  "factory": "0x...",
  "passkeyValidator": "0x...",
  "verifyingPaymaster": "0x..."
}
```

### Step 4: Verify on Etherscan

Check contracts on Sepolia Etherscan:
- [sepolia.etherscan.io](https://sepolia.etherscan.io/)

If verification failed during deployment:
```bash
forge verify-contract \
  $FACTORY_ADDRESS \
  src/factory/AAKitFactory.sol:AAKitFactory \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address,address)" $WALLET_IMPL $ENTRYPOINT)
```

### Step 5: Create Test Wallet

```bash
# Set factory address in .env
echo "FACTORY_ADDRESS=0x..." >> .env

# Create wallet
forge script script/CreateWallet.s.sol:CreateWalletScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### Step 6: Test with Demo App

```bash
cd ../examples/demo-wallet

# Update config with testnet addresses
# src/config.ts:
export const CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  factory: '0x...', # Your deployed factory
  paymaster: '0x...', # Your deployed paymaster
}

export const BUNDLER_URL = 'https://sepolia.bundler.example.com'

# Start demo
npm install
npm run dev
```

## Mainnet Deployment

### ⚠️ Critical Prerequisites

**DO NOT deploy to mainnet until:**

- [ ] **Security Audit Complete** (2+ firms)
  - Audit reports reviewed
  - All critical/high issues fixed
  - Auditors approve fixes

- [ ] **Extensive Testing** (3+ months on testnet)
  - No critical bugs found
  - All features tested
  - Gas costs optimized
  - Load testing completed

- [ ] **Code Freeze**
  - No changes after audit
  - Final commit tagged
  - Build reproducible

- [ ] **Emergency Procedures**
  - Pause mechanism tested
  - Upgrade procedure documented
  - Recovery plan prepared
  - Team trained

- [ ] **Insurance/Multisig**
  - Admin functions behind multisig
  - Consider insurance (Nexus Mutual, etc.)
  - Treasury secured

- [ ] **Community Review**
  - Open source published
  - Community audit period
  - Bug bounty active

### Step 1: Final Preparation

```bash
# Verify build
forge build
forge test --gas-report

# Check deployment gas costs
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL

# Tag release
git tag -a v1.0.0 -m "Production release"
git push origin v1.0.0
```

### Step 2: Fund Deployer

**Mainnet deployment needs:**
- **~0.3 ETH** for contract deployment
- **~0.1 ETH** for paymaster funding
- **Buffer** for gas price spikes

**Security:**
- Use hardware wallet (Ledger, Trezor)
- Verify addresses multiple times
- Use Gnosis Safe for admin functions

### Step 3: Deploy to Mainnet

```bash
# Deploy with extra care
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --slow \
  --gas-price 20000000000 # Set appropriate gas price

# WAIT for confirmations (recommend 10+ blocks)
```

### Step 4: Verify Everything

```bash
# Verify all contracts on Etherscan
# Verify source code matches audited version
# Verify constructor arguments
# Verify implementation contracts

# Test with small amounts first!
```

### Step 5: Set Up Monitoring

- **Contract Monitoring:**
  - [Tenderly](https://tenderly.co/)
  - [OpenZeppelin Defender](https://defender.openzeppelin.com/)
  
- **Alerts:**
  - Large transactions
  - Admin function calls
  - Unusual patterns
  - Gas price spikes

### Step 6: Gradual Rollout

1. **Week 1:** Internal testing only
2. **Week 2:** Limited beta (100 users)
3. **Week 3:** Expanded beta (1000 users)
4. **Week 4:** Public launch

Monitor closely at each stage!

## Post-Deployment

### 1. Update Documentation

```bash
# Update README with deployed addresses
# contracts/README.md:

## Mainnet Addresses

EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
AAKitFactory: 0x...
AAKitWallet Implementation: 0x...
PasskeyValidator: 0x...
VerifyingPaymaster: 0x...
```

### 2. Update SDK Configuration

```typescript
// sdk/src/config.ts
export const MAINNET_CONTRACTS = {
  entryPoint: '0x0000000071727De22E5E9d8BAf0edAc6f37da032',
  factory: '0x...',
  paymaster: '0x...',
}
```

### 3. Set Up Bundler

Configure production bundler:
- Use reliable bundler service (Pimlico, Stackup, Alchemy)
- Set up monitoring
- Configure rate limiting
- Implement fee strategy

### 4. Configure Paymaster

```bash
# Fund paymaster
cast send $PAYMASTER_ADDRESS \
  --value 10ether \
  --rpc-url $MAINNET_RPC_URL \
  --private-key $PRIVATE_KEY

# Verify deposit
cast call $PAYMASTER_ADDRESS \
  "getDeposit()" \
  --rpc-url $MAINNET_RPC_URL
```

### 5. Set Up Multisig

**For admin functions, use Gnosis Safe:**

```bash
# Create Safe on mainnet
# Add team members as signers
# Set threshold (e.g., 3 of 5)
# Transfer ownership to Safe

cast send $PAYMASTER_ADDRESS \
  "transferOwnership(address)" \
  $SAFE_ADDRESS \
  --rpc-url $MAINNET_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 6. Launch Bug Bounty

Use platforms like:
- [Immunefi](https://immunefi.com/)
- [HackerOne](https://www.hackerone.com/)
- [Code4rena](https://code4rena.com/)

**Suggested Rewards:**
- Critical: $50,000 - $100,000
- High: $10,000 - $50,000
- Medium: $1,000 - $10,000
- Low: $500 - $1,000

## Troubleshooting

### Issue: Deployment Runs Out of Gas

**Solution:**
```bash
# Increase gas limit
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --gas-limit 10000000
```

### Issue: Verification Fails

**Solutions:**

1. **Check compiler settings match:**
```bash
forge verify-contract $ADDRESS \
  src/path/Contract.sol:ContractName \
  --chain-id $CHAIN_ID \
  --compiler-version v0.8.23+commit.f704f362
```

2. **Verify manually on Etherscan:**
- Copy flattened source: `forge flatten src/Contract.sol`
- Paste in Etherscan verification form
- Set correct compiler version
- Enable optimization (200 runs)

### Issue: Transaction Reverts

**Debug:**
```bash
# Simulate transaction
cast call $CONTRACT \
  "functionName(args)" \
  --from $SENDER \
  --rpc-url $RPC_URL

# Check with trace
cast run $TX_HASH --rpc-url $RPC_URL --debug
```

### Issue: Nonce Too Low

**Solution:**
```bash
# Check nonce
cast nonce $ADDRESS --rpc-url $RPC_URL

# Reset if needed (local only!)
cast rpc anvil_setNonce $ADDRESS 0
```

## Deployment Checklist

### Pre-Deployment
- [ ] Contracts compiled successfully
- [ ] All tests passing (forge test)
- [ ] Gas report reviewed
- [ ] Deployment script tested locally
- [ ] Sufficient funds in deployer wallet
- [ ] .env file configured correctly
- [ ] Etherscan API key set

### During Deployment
- [ ] Deployment transaction confirmed
- [ ] All contracts deployed successfully
- [ ] Deployment addresses saved
- [ ] Contracts verified on explorer
- [ ] Test wallet created successfully

### Post-Deployment
- [ ] Documentation updated with addresses
- [ ] SDK configuration updated
- [ ] Bundler configured
- [ ] Paymaster funded
- [ ] Monitoring set up
- [ ] Team notified
- [ ] Users can create wallets
- [ ] Transactions working correctly

## Security Notes

1. **Never commit .env file**
2. **Use hardware wallet for mainnet**
3. **Verify addresses multiple times**
4. **Test with small amounts first**
5. **Monitor contracts 24/7**
6. **Have incident response plan**
7. **Keep private keys secure**
8. **Use multisig for admin functions**
9. **Gradual rollout recommended**
10. **Complete audit before mainnet**

## Support

- **Issues:** [GitHub Issues](https://github.com/your-org/aakit/issues)
- **Discussions:** [GitHub Discussions](https://github.com/your-org/aakit/discussions)
- **Security:** security@aakit.io
- **Discord:** [Join community](https://discord.gg/aakit)

---

**Next Steps:**
- [Integration Guide](./SDK_INTEGRATION.md)
- [Security Best Practices](./SECURITY_BEST_PRACTICES.md)
- [API Reference](./API_REFERENCE.md)
