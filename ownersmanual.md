# MilliesToken Owner's Manual
## Complete Guide from Deployment to Maintenance

---

## Table of Contents

1. [Pre-Deployment Setup](#pre-deployment-setup)
2. [Contract Deployment](#contract-deployment)
3. [Initial Configuration](#initial-configuration)
4. [Liquidity Setup](#liquidity-setup)
5. [Trading Activation](#trading-activation)
6. [Ongoing Maintenance](#ongoing-maintenance)
7. [Monitoring & Analytics](#monitoring--analytics)
8. [Emergency Procedures](#emergency-procedures)
9. [Command Reference](#command-reference)
10. [Troubleshooting](#troubleshooting)

---

## Pre-Deployment Setup

### 1. Environment Preparation

**Install Dependencies:**
```bash
npm install
```

**Configure hardhat.config.js:**
```javascript
networks: {
  bscMainnet: {
    url: "https://bsc-dataseed.binance.org/",
    accounts: [process.env.PRIVATE_KEY]
  },
  bscTestnet: {
    url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
    accounts: [process.env.PRIVATE_KEY]
  }
}
```

**Create .env file:**
```
PRIVATE_KEY=your_private_key_here
BSCSCAN_API_KEY=your_bscscan_api_key_here
```

### 2. Pre-Deployment Checklist

**Critical Address Updates Required:**

In `setup-template.js`, update these placeholders:
```javascript
const WALLET_ADDRESSES = {
  advertisingWallet: "0x0000000000000000000000000000000000000000", // ⚠️ UPDATE THIS
  communityWallet: "0x0000000000000000000000000000000000000000",   // ⚠️ UPDATE THIS
  additionalExclusions: [
    // Add any presale contract addresses here
    // Add team wallet addresses here
  ]
};
```

**Why These Matter:**
- **Advertising Wallet**: Receives advertising tax from sells (1.5% by default)
- **Community Wallet**: Receives community tax and can be used for airdrops
- **Additional Exclusions**: Presale contracts, team wallets that should bypass taxes

### 3. Network-Specific Configurations

**BSC Mainnet:**
- Router: `0x10ED43C718714eb63d5aA57B78B54704E256024E`
- Factory: `0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73`
- WBNB: `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c`

**BSC Testnet:**
- Router: `0xD99D1c33F9fC3444f8101754aBC46c52416550D1`
- Factory: `0x6725F303b657a9451d8BA641348b6761A6CC7a17`
- WBNB: `0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd`

---

## Contract Deployment

### 1. Deploy Contracts

**For Testnet (Recommended First):**
```bash
npx hardhat run scripts/deploy-template.js --network bscTestnet
```

**For Mainnet:**
```bash
npx hardhat run scripts/deploy-template.js --network bscMainnet
```

### 2. Understanding the Deployment Process

The deployment script creates 5 contracts in this order:

1. **LiquidityLib** - Library for liquidity pool operations
2. **TaxLib** - Library for tax calculations  
3. **MilliesToken** - Main token contract (1B total supply)
4. **MilliesHelper** - Complex logic handler (links to libraries)
5. **MilliesLens** - Data reading contract for analytics

**Why This Order:**
- Libraries must be deployed first (TaxLib, LiquidityLib)
- MilliesToken is the core contract that mints all tokens to deployer
- MilliesHelper needs the token address in its constructor
- MilliesLens needs the token address for data reading

### 3. Contract Size Verification

The deployment script checks EIP-170 compliance (24KB limit):
```
🏠 MilliesToken: XX,XXX bytes
🔧 MilliesHelper: XX,XXX bytes  
👁️ MilliesLens: XX,XXX bytes
```

**If contracts exceed 24KB:**
- ❌ Deployment will fail on mainnet
- Consider code optimization or splitting functionality

### 4. Save Deployment Addresses (they will be returned in console in the below format)

**CRITICAL:** Save these addresses from deployment output:
```
🏠 MilliesToken:  0x0000000000000000000000000000000000000000
🔧 MilliesHelper: 0x0000000000000000000000000000000000000000
👁️ MilliesLens:   0x0000000000000000000000000000000000000000
📚 LiquidityLib:  0x0000000000000000000000000000000000000000
📚 TaxLib:        0x0000000000000000000000000000000000000000
```

---

## Initial Configuration

### 1. Update Setup Script

In `setup-template.js`, replace placeholder addresses:

```javascript
const DEPLOYED_ADDRESSES = {
  milliesToken: "0x0000000000000000000000000000000000000000",  // From deployment
  milliesHelper: "0x0000000000000000000000000000000000000000", // From deployment
  milliesLens: "0x0000000000000000000000000000000000000000",   // From deployment
  liquidityLib: "0x0000000000000000000000000000000000000000", // From deployment
  taxLib: "0x0000000000000000000000000000000000000000"        // From deployment
};
```

### 2. Run Initial Setup

```bash
npx hardhat run scripts/setup-template.js --network bscTestnet
```

### 3. What the Setup Does

**Step 1: Helper Contract Configuration**
```javascript
await milliesToken.setHelperContract(DEPLOYED_ADDRESSES.milliesHelper);
```
- Links the main token to the helper contract
- Enables complex tax calculations and trade detection
- **Why needed:** Token delegates complex logic to helper for gas optimization

**Step 2: Wallet Configuration**
```javascript
await milliesToken.setAdvertisingWallet(WALLET_ADDRESSES.advertisingWallet);
await milliesToken.setCommunityWallet(WALLET_ADDRESSES.communityWallet);
```
- Sets tax collection wallets
- **Why important:** Without these, tax collection will fail

**Step 3: PancakeSwap Integration**
```javascript
// Router excluded from cooldowns but INCLUDED in fees
await milliesToken.excludeFromCooldown(PANCAKE_ROUTER, true);
await milliesToken.excludeFromFees(PANCAKE_ROUTER, false); // FALSE = INCLUDED!
```
- **Critical:** Router must be included in fees for tax collection to work
- Router excluded from cooldowns to allow immediate trades

**Step 4: System Address Exclusions**
- Helper contract excluded from fees/cooldowns
- Lens contract excluded from fees/cooldowns  
- Advertising/community wallets excluded from fees/cooldowns
- **Why:** System contracts shouldn't pay taxes to themselves

**Step 5: Feature Activation**
```javascript
await milliesToken.toggleDumpSpikeDetection(); // Enables anti-dump protection
await milliesToken.toggleSybilDefense();       // Enables anti-bot clustering
```

### 4. Critical Configuration Verification

The setup script verifies:
```
📊 PancakeSwap Configuration:
  Router excluded from fees: ❌ NO (GOOD!)  ← Must be NO for tax collection
  Router excluded from cooldowns: ✅ YES (GOOD!)
```

**If you see "Router excluded from fees: ✅ YES (BAD!)":**
- Tax collection will NOT work on PancakeSwap
- Fix with: `await token.excludeFromFees(routerAddress, false)`

---

## Liquidity Setup

### 1. Create Liquidity Pool

**Option A: PancakeSwap Interface**
1. Go to PancakeSwap
2. Add Liquidity: MILLIES + BNB
3. Approve token spending
4. Add liquidity (recommend 50%+ of supply)

**Option B: Manual via Hardhat**
```javascript
// Approve router to spend tokens
await token.approve(router.address, tokenAmount);

// Add liquidity
await router.addLiquidityETH(
  token.address,
  tokenAmount,
  0, 0,
  owner.address,
  Math.floor(Date.now()/1000) + 900,
  { value: bnbAmount }
);
```

### 2. Set Liquidity Pool Address

**Get the LP pair address:**
```javascript
const factory = await ethers.getContractAt("IPancakeFactory", PANCAKE_FACTORY);
const pairAddress = await factory.getPair(token.address, WBNB);
console.log("LP Pair Address:", pairAddress);
```

**Set in token contract:**
```javascript
await token.setLiquidityPool(pairAddress);
```

**What this does:**
- Enables trade detection (buy/sell vs transfer)
- Activates tax collection on DEX trades
- **Critical:** LP must be included in fees for tax collection

### 3. Lock Liquidity (Mainnet)

Use platforms like:
- PinkSale (recommended)
- Team Finance
- Unicrypt

**Why lock liquidity:**
- Prevents rug pulls
- Builds investor confidence
- Required by most launchpads

---

## Trading Activation

### 1. Complete Setup Process

```javascript
await token.completeSetup();
```

**What this does:**
- Sets `setupCompleted = true`
- Sets `tradingEnabled = true`
- Records `tradingEnabledTime`
- Enables all anti-bot features by default

### 2. Verify Trading Status

```javascript
await token.tradingEnabled();        // Should return true
await token.setupCompleted();       // Should return true
await token.dumpSpikeDetectionEnabled(); // Should return true
await token.sybilDefenseEnabled();   // Should return true
```

### 3. Test with Small Transactions

**Before announcing trading:**
1. Test small buy (0.01 BNB)
2. Test small sell (100 MILLIES)
3. Verify tax collection in advertising wallet
4. Check burn address balance increases

---

## Ongoing Maintenance

### 1. Feature Management

**Buy Tax Control:**
```javascript
await token.toggleBuyTax();         // Enable/disable buy tax
await token.buyTaxEnabled();        // Check status
```

**Anti-Bot Features:**
```javascript
await token.toggleDumpSpikeDetection(); // Toggle large sell protection
await token.toggleSybilDefense();       // Toggle cluster detection
```

**Emergency Controls:**
```javascript
await token.pause();                 // Pause all transfers
await token.unpause();              // Resume transfers
await token.toggleTrading();        // Toggle trading on/off
```

### 2. Wallet Management

**Fund Project Wallets:**
```javascript
// Fund advertising wallet
await token.fundAdvertisingWallet(ethers.parseEther("1000000")); // 1M tokens

// Fund community wallet  
await token.fundCommunityWallet(ethers.parseEther("2000000"));   // 2M tokens
```

**Airdrop from Community Wallet:**
```javascript
const recipients = ["0xabc...", "0xdef...", "0x123..."];
const amounts = [
  ethers.parseEther("1000"),  // 1K tokens
  ethers.parseEther("2000"),  // 2K tokens
  ethers.parseEther("1500")   // 1.5K tokens
];

await token.airdropToCommunity(recipients, amounts);
```

### 3. Access Control

**Address Exclusions:**
```javascript
// Exclude from fees (marketing wallets, partnerships)
await token.excludeFromFees(address, true);

// Exclude from cooldowns (exchanges, bots)
await token.excludeFromCooldown(address, true);

// Include in fees (remove exclusion)
await token.excludeFromFees(address, false);
```

**Blacklist Management:**
```javascript
// Blacklist malicious addresses
await token.setBlacklistStatus(address, true);

// Remove from blacklist  
await token.setBlacklistStatus(address, false);
```

### 4. Presale Integration

**Before presale launch:**
```javascript
// Exclude presale contract from fees/cooldowns
await token.excludeFromFees(presaleContractAddress, true);
await token.excludeFromCooldown(presaleContractAddress, true);
```

**After presale (before trading):**
```javascript
// Set LP address (created by presale platform)
await token.setLiquidityPool(lpPairAddress);

// Complete setup to enable trading
await token.completeSetup();
```

---

## Monitoring & Analytics

### 1. Using MilliesLens for Data

**Dashboard Overview:**
```javascript
const lens = await ethers.getContractAt("MilliesLens", lensAddress);

const dashboard = await lens.dashboard();
console.log("Contract Token Balance:", ethers.formatEther(dashboard.contractTokenBal));
console.log("Liquidity Balance:", ethers.formatEther(dashboard.liquidityBal));
console.log("Total Burned:", ethers.formatEther(dashboard.totalBurnedTokens));
console.log("Total Tax Collected:", ethers.formatEther(dashboard.totalTaxAmt));
console.log("Daily Volume:", ethers.formatEther(dashboard.dailyVol));
console.log("Circulating Supply:", ethers.formatEther(dashboard.circulatingSupply));
console.log("Total Holders:", dashboard.totalHoldersCount.toString());
```

**Token Metrics:**
```javascript
const metrics = await lens.getTokenMetrics();
console.log("Circulating:", ethers.formatEther(metrics.circulating));
console.log("Burned:", ethers.formatEther(metrics.burned));
console.log("Owner Balance:", ethers.formatEther(metrics.ownerBalance));
console.log("Reserved for LP:", ethers.formatEther(metrics.reservedTokens));
```

**Account Analysis:**
```javascript
const accountInfo = await lens.getAccountInfo(userAddress);
console.log("Balance:", ethers.formatEther(accountInfo.balance));
console.log("Fees Excluded:", accountInfo.feesExcluded);
console.log("Cooldown Excluded:", accountInfo.cooldownExcluded);
console.log("Blacklisted:", accountInfo.blacklisted);
console.log("Can Sell:", accountInfo.canSell);
console.log("Can Buy:", accountInfo.canBuy);
```

### 2. Tax Collection Monitoring

**Check Burn Progress:**
```javascript
const burnAddress = await token.BURN_ADDRESS();
const totalBurned = await token.balanceOf(burnAddress);
console.log("Total Burned:", ethers.formatEther(totalBurned));

// Burn percentage
const totalSupply = await token.totalSupply();
const burnPercentage = (totalBurned * 100n) / totalSupply;
console.log("Burn Percentage:", burnPercentage.toString() + "%");
```

**Tax Collection Wallets:**
```javascript
const advWallet = await token.advertisingWallet();
const commWallet = await token.communityWallet();

const advBalance = await token.balanceOf(advWallet);
const commBalance = await token.balanceOf(commWallet);

console.log("Advertising Wallet:", ethers.formatEther(advBalance));
console.log("Community Wallet:", ethers.formatEther(commBalance));
```

### 3. Health Monitoring

**System Health Check:**
```javascript
const healthCheck = await lens.healthCheck();
console.log("Token Responsive:", healthCheck.tokenResponsive);
console.log("Helper Responsive:", healthCheck.helperResponsive);
console.log("Trading Enabled:", healthCheck.tradingEnabled);
console.log("Emergency Detected:", healthCheck.emergencyDetected);
console.log("Status:", healthCheck.status);
```

---

## Emergency Procedures

### 1. Trading Issues

**If trading fails:**
```javascript
// Check if trading is enabled
await token.tradingEnabled();

// Check if contracts are paused
await token.paused();

// Check if LP is set correctly
await token.liquidityPool();

// Verify router configuration
const router = await token.pancakeRouter();
await token.isExcludedFromFees(router); // Should be FALSE
await token.isExcludedFromCooldown(router); // Should be TRUE
```

**If users can't buy/sell:**
```javascript
// Check for active cooldowns
const cooldownInfo = await token.getCooldownInfo(userAddress);
console.log("Sell Cooldown Remaining:", cooldownInfo.timeRemaining.toString());

// Clear cooldown if needed (owner only)
await helper.clearSellCooldown(userAddress);
```

### 2. Helper Contract Issues

**If helper contract fails:**
```javascript
// Check if degraded mode is active
await token.degradedMode();

// Manually activate degraded mode
await token.activateDegradedMode("Helper contract issues");

// Deploy new helper and update
const newHelper = await ethers.deployContract("MilliesHelper", [tokenAddress]);
await token.setHelperContract(newHelper.address);
```

### 3. Emergency Functions

**Pause System:**
```javascript
await token.pause();    // Stops all transfers
await token.unpause();  // Resumes transfers
```

**Emergency Token Recovery:**
```javascript
// Recover tokens sent to contract by mistake
await token.emergencyWithdraw(ethers.parseEther("1000"));

// Recover other tokens
await token.rescueTokens(otherTokenAddress, amount);

// Recover BNB
await token.rescueBNB();
```

### 4. Tax System Fixes

**If taxes aren't collected:**
```javascript
// Verify router is included in fees
const router = await token.pancakeRouter();
const routerExcluded = await token.isExcludedFromFees(router);
if (routerExcluded) {
  await token.excludeFromFees(router, false); // Include router in fees
}

// Verify LP is included in fees
const lp = await token.liquidityPool();
const lpExcluded = await token.isExcludedFromFees(lp);
if (lpExcluded) {
  await token.excludeFromFees(lp, false); // Include LP in fees
}
```

---

## Command Reference

### Contract Interaction Setup

```javascript
// Connect to deployed contracts
const token = await ethers.getContractAt("MilliesToken", tokenAddress);
const helper = await ethers.getContractAt("MilliesHelper", helperAddress);
const lens = await ethers.getContractAt("MilliesLens", lensAddress);
```

### Essential Read Commands

```javascript
// Basic token info
await token.name();                    // "Millies"
await token.symbol();                  // "MILLIES"
await token.totalSupply();             // 1,000,000,000 * 10^18
await token.decimals();                // 18

// Setup status
await token.setupCompleted();          // true/false
await token.tradingEnabled();          // true/false
await token.owner();                   // Owner address

// Feature status
await token.buyTaxEnabled();           // true/false
await token.dumpSpikeDetectionEnabled(); // true/false
await token.sybilDefenseEnabled();     // true/false

// Contract addresses
await token.helperContract();          // Helper address
await token.liquidityPool();           // LP pair address
await token.advertisingWallet();       // Ad wallet address
await token.communityWallet();         // Community wallet address
```

### Balance and Holder Commands

```javascript
// Check balances
await token.balanceOf(address);        // User balance
await token.getTotalBurned();          // Total burned tokens
await token.getTotalSupplyAfterBurn(); // Circulating supply
await token.getOwnerBalance();         // Owner balance

// Holder stats
await token.totalHolders();            // Total unique holders
await token.isHoldingTokens(address);  // true if holds any tokens
```

### Tax and Trading Info

```javascript
// Tax collection stats  
await token.totalTaxAccumulated();     // Total tax collected
await token.dailyTradingVolume();      // 24h volume

// User trading info
await token.getSellWindow(address);    // 3-day sell tracking
await token.getCooldownInfo(address);  // Buy/sell cooldowns

// Exclusion status
await token.isExcludedFromFees(address);     // Fee exclusion
await token.isExcludedFromCooldown(address); // Cooldown exclusion
await token.isBlacklisted(address);          // Blacklist status
```

### Administrative Commands

```javascript
// Wallet management
await token.setAdvertisingWallet(address);   // Set ad wallet
await token.setCommunityWallet(address);     // Set community wallet
await token.fundAdvertisingWallet(amount);   // Fund ad wallet
await token.fundCommunityWallet(amount);     // Fund community wallet

// Access control
await token.excludeFromFees(address, true);      // Exclude from fees
await token.excludeFromCooldown(address, true);  // Exclude from cooldowns
await token.setBlacklistStatus(address, true);   // Add to blacklist

// Feature toggles
await token.toggleBuyTax();               // Toggle buy tax
await token.toggleDumpSpikeDetection();   // Toggle anti-dump
await token.toggleSybilDefense();         // Toggle anti-bot
await token.toggleTrading();              // Toggle trading

// Emergency functions
await token.pause();                      // Pause transfers
await token.unpause();                    // Resume transfers
await token.emergencyWithdraw(amount);    // Withdraw tokens
await token.rescueBNB();                  // Withdraw BNB
```

### Manual Burn Commands

```javascript
// Direct burn (transfer to burn address)
const burnAddress = await token.BURN_ADDRESS();
await token.transfer(burnAddress, ethers.parseEther("1000000")); // Burn 1M

// Check burn progress
const burned = await token.balanceOf(burnAddress);
console.log("Burned:", ethers.formatEther(burned));
```

### Useful Calculations

```javascript
// Convert between units
ethers.parseEther("1000");        // 1000 tokens to wei
ethers.formatEther(amount);       // Wei to readable tokens

// Percentage calculations
const burnRate = (burned * 100n) / totalSupply;
const ownerPercentage = (ownerBalance * 100n) / totalSupply;

// Time calculations  
const timeRemaining = cooldownEnd - Math.floor(Date.now() / 1000);
const hoursLeft = timeRemaining / 3600;
```

---

## Troubleshooting

### Common Issues

**1. "Setup already completed" Error**
- You can only call `completeSetup()` once
- Check with: `await token.setupCompleted()`

**2. "Trading disabled" Error**
- Trading not enabled yet
- Enable with: `await token.toggleTrading()` or `await token.completeSetup()`

**3. "Buy cooldown active" Error**
- 30-second cooldown between buys
- Wait or exclude user: `await token.excludeFromCooldown(address, true)`

**4. "Sell cooldown active" Error**  
- Cooldown triggered by large/frequent sells
- Clear with: `await helper.clearSellCooldown(address)`

**5. Taxes Not Collected**
- Router excluded from fees: `await token.excludeFromFees(router, false)`
- LP excluded from fees: `await token.excludeFromFees(lp, false)`
- Helper not set: `await token.setHelperContract(helperAddress)`

**6. Users Can't Claim from Presale**
- Presale contract not excluded: `await token.excludeFromFees(presaleContract, true)`

### Diagnostic Commands

```javascript
// Check system configuration
await token.liquidityPool();          // Should not be zero address
await token.helperContract();         // Should not be zero address
await token.advertisingWallet();      // Should not be zero address
await token.communityWallet();        // Should not be zero address

// Check router configuration (CRITICAL)
const router = await token.pancakeRouter();  
await token.isExcludedFromFees(router);      // Should be FALSE
await token.isExcludedFromCooldown(router);  // Should be TRUE

// Check feature status
await token.tradingEnabled();                // Should be TRUE for trading
await token.buyTaxEnabled();                 // Tax setting
await token.dumpSpikeDetectionEnabled();     // Anti-bot setting
await token.sybilDefenseEnabled();           // Anti-bot setting

// Check degraded mode (emergency fallback)
await token.degradedMode();                  // Should be FALSE normally
```

### Recovery Procedures

**If contract becomes unresponsive:**
1. Check if paused: `await token.paused()`
2. Check degraded mode: `await token.degradedMode()`
3. Deploy new helper if needed
4. Use emergency functions to recover funds

**If wrong configuration:**
1. Most settings can be changed by owner
2. Some settings (like LP address) can only be set once
3. Use emergency pause if needed during fixes

---

## Final Notes

### Security Best Practices

1. **Always test on testnet first**
2. **Verify all addresses before mainnet deployment**
3. **Keep private keys secure**
4. **Use multisig for production**
5. **Monitor tax collection regularly**
6. **Have emergency procedures ready**

### Gas Optimization

- Batch operations when possible
- Use read functions before write operations
- Monitor gas usage on complex functions
- Consider gas price for time-sensitive operations

### Monitoring Setup

1. Set up event monitoring for tax collection
2. Monitor burn address balance
3. Track daily volume metrics
4. Set up alerts for emergency situations
5. Regular health checks using lens contract

### Support Resources

- BSCScan for transaction verification
- PancakeSwap analytics for trading data
- Community feedback for user experience
- Regular code reviews for security

---

*This manual covers the complete lifecycle of MilliesToken management. Keep this document updated as the project evolves and new features are added.*