# 🎮 Ready to Test AAKit!

**Status:** All configurations complete! ✅

## 🔧 Configuration Complete

### Deployed Contracts (Sepolia)
```
Factory:    0xeA1880ea125559e52c4159B00dFc98c70C193D99
Paymaster:  0x30E1f3431b28F53Ca7Aec8CFfEe99c91cF049021
Wallet:     0x5a40FC81Ccd07aDFCC77eFD59815B94CEc985E1e
Validator:  0x8d4158eb053379c8FE007497Bf6bD2be663e5067
EntryPoint: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
```

### Bundler
```
Provider: Pimlico
URL: https://api.pimlico.io/v2/sepolia/rpc?apikey=pim_***
Status: ✅ Configured
```

### Demo Apps
```
✅ Demo Wallet - Configured
✅ NFT Minter - Configured
```

---

## 🚀 Test Demo Wallet (Recommended First!)

### Step 1: Start Demo Wallet

```bash
cd examples/demo-wallet
npm install
npm run dev
```

### Step 2: Open in Browser

Open: **http://localhost:5173**

### Step 3: Create Your Passkey Wallet

1. **Enter a username** (anything you want)
2. **Click "Connect with Passkey"**
3. **Approve biometric prompt** (Touch ID, Face ID, Windows Hello, etc.)
4. **Your wallet address will appear!** 🎉

### Step 4: Fund Your Wallet

Copy your wallet address and get Sepolia ETH:
- https://sepoliafaucet.com/
- https://faucet.quicknode.com/ethereum/sepolia
- https://www.alchemy.com/faucets/ethereum-sepolia

Send **0.01-0.05 ETH** to your wallet address.

### Step 5: Send a Transaction

1. **Enter recipient address** (any Sepolia address)
2. **Enter amount** (e.g., 0.001)
3. **Click "Send Transaction"**
4. **Approve with biometric** 🔐
5. **Transaction submitted!** View on Etherscan

---

## 🎨 What You're Testing

### Passkey Authentication
- ✅ Create wallet with biometric (no seed phrases!)
- ✅ Sign transactions with Face ID/Touch ID
- ✅ Hardware-backed security (keys never leave device)

### Smart Wallet Features
- ✅ ERC-4337 account abstraction
- ✅ Counterfactual addresses (address before deployment)
- ✅ First transaction deploys wallet automatically
- ✅ Gasless transactions (if paymaster is used)

### User Experience
- ✅ No MetaMask needed
- ✅ No seed phrases to backup
- ✅ Just biometric authentication
- ✅ Web2-like UX with Web3 security

---

## 🧪 Test NFT Minter (Optional)

### Prerequisites
You'll need to deploy a simple NFT contract first, or use an existing one.

### Quick NFT Deploy (if needed)

```solidity
// Simple NFT for testing
contract SimpleNFT {
    mapping(uint256 => address) public ownerOf;
    
    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
    }
}
```

Then update `NFT_CONTRACT` in `examples/nft-minter/src/config.ts`

### Run NFT Minter

```bash
cd examples/nft-minter
npm install
npm run dev

# Open http://localhost:5174
```

---

## 🔍 Verify on Etherscan

After creating your wallet and sending a transaction:

### View Your Wallet
```
https://sepolia.etherscan.io/address/YOUR_WALLET_ADDRESS
```

### View Factory
```
https://sepolia.etherscan.io/address/0xeA1880ea125559e52c4159B00dFc98c70C193D99
```

### View Your Transactions
All transactions will be visible on Etherscan!

---

## 📊 Expected Flow

### First Time User

```
1. User visits app
   ↓
2. Clicks "Connect with Passkey"
   ↓
3. Device prompts for biometric (Face ID/Touch ID)
   ↓
4. P-256 keypair generated on device
   ↓
5. Smart wallet address calculated (counterfactual)
   ↓
6. Wallet address shown (but not yet deployed!)
   ↓
7. User funds wallet with Sepolia ETH
   ↓
8. User sends first transaction
   ↓
9. Transaction includes wallet deployment + execution
   ↓
10. Biometric prompt to sign
    ↓
11. Transaction submitted to bundler
    ↓
12. Wallet deployed & transaction executed!
    ↓
13. View on Etherscan ✅
```

### Returning User

```
1. User visits app
   ↓
2. Wallet restored from localStorage
   ↓
3. Address displayed (already deployed)
   ↓
4. User sends transaction
   ↓
5. Biometric prompt to sign
   ↓
6. Transaction executed
   ↓
7. Done! ✅
```

---

## 🎯 Test Cases

### Basic Tests

- [ ] Create passkey wallet
- [ ] View wallet address
- [ ] Fund wallet with testnet ETH
- [ ] Send transaction to another address
- [ ] View transaction on Etherscan
- [ ] Verify wallet was deployed on first tx

### Advanced Tests

- [ ] Create multiple wallets (different usernames)
- [ ] Send batch transactions (if implementing)
- [ ] Test gasless transactions (paymaster)
- [ ] Test on different devices/browsers
- [ ] Test biometric cancellation
- [ ] Test with hardware security key

---

## 🐛 Troubleshooting

### Issue: "WebAuthn not supported"

**Solution:** Use Chrome 67+, Firefox 60+, or Safari 13+

### Issue: "No biometric prompt"

**Solution:** 
- Ensure you're on HTTPS or localhost
- Check browser settings for WebAuthn
- Try different browser

### Issue: "Transaction failed"

**Solution:**
- Ensure wallet has sufficient ETH
- Check bundler is responding
- Verify contract addresses are correct
- Check Etherscan for revert reason

### Issue: "Wallet address not showing"

**Solution:**
- Check browser console for errors
- Verify factory address is correct
- Ensure RPC is working

---

## 📸 Expected UI

### Demo Wallet Home
```
┌─────────────────────────────────────┐
│   🔑 AAKit Demo Wallet              │
│   ERC-4337 Smart Wallet with        │
│   Passkey Authentication             │
│                                      │
│   ┌──────────────────────────────┐  │
│   │ Username: [________]         │  │
│   │                              │  │
│   │ [Connect with Passkey]       │  │
│   └──────────────────────────────┘  │
│                                      │
│   💡 What is a Passkey?             │
│   • Stored securely on your device  │
│   • Uses biometric auth             │
│   • More secure than passwords      │
│   • Can't be phished or leaked      │
└─────────────────────────────────────┘
```

### After Connection
```
┌─────────────────────────────────────┐
│   👛 Your Smart Wallet               │
│                                      │
│   Address:                           │
│   0xABC123...DEF456                 │
│                                      │
│   Status: ✅ Deployed                │
│   Balance: 0.05 ETH                 │
│                                      │
│   ┌──────────────────────────────┐  │
│   │ 💸 Send Transaction          │  │
│   │                              │  │
│   │ To:      [0x________]        │  │
│   │ Amount:  [0.001] ETH         │  │
│   │                              │  │
│   │ [🚀 Send Transaction]        │  │
│   └──────────────────────────────┘  │
│                                      │
│   [Disconnect]                       │
└─────────────────────────────────────┘
```

---

## 🎉 Success Criteria

You'll know it's working when:

✅ Biometric prompt appears when creating wallet  
✅ Wallet address is displayed  
✅ Can send ETH to the address  
✅ Can sign transactions with biometric  
✅ Transaction appears on Etherscan  
✅ Wallet is deployed on-chain  

---

## 📞 Need Help?

- **Docs:** `/docs/GETTING_STARTED.md`
- **Troubleshooting:** `/docs/DEPLOYMENT_GUIDE.md`
- **Addresses:** `/deployments/deployment-11155111.json`

---

## 🚀 You're All Set!

Everything is configured and ready to test. Just:

```bash
cd examples/demo-wallet
npm install
npm run dev
```

Then open http://localhost:5173 and create your first passkey wallet! 🎉

---

**Status:** 🟢 Ready to Test  
**Network:** Sepolia Testnet  
**Bundler:** Pimlico (configured)  
**Contracts:** Deployed & Live  

**Let's go!** 🚀
