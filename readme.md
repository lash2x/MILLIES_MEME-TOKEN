## Project Overview

**MilliesToken** is an ERC-20 token on Binance Smart Chain (BSC) designed with advanced on-chain tax mechanics, anti-bot & Sybil defenses, and integrated liquidity management via PancakeSwap. Its architecture separates concerns across modular libraries and helper contracts, providing both security and upgradability.

### Main Components

| Component                         | Path                                   | Purpose                                                |
|-----------------------------------|----------------------------------------|--------------------------------------------------------|
| **Interfaces**                    | `contracts/Interfaces.sol`             | Standard PancakeSwap router/factory/pair interfaces.   |
| **LiquidityLib**                  | `contracts/LiquidityLib.sol`           | Library for TWAP & liquidity-pool operations.         |
| **TaxLib**                        | `contracts/TaxLib.sol`                 | Library for comprehensive tax calculations.           |
| **MilliesToken**                  | `contracts/MilliesToken.sol`           | Core ERC-20 token with tax, anti-bot, and governance. |
| **MilliesHelper**                 | `contracts/MilliesHelper.sol`          | On-chain logic for tax processing & transfer checks.  |
| **MilliesLens**                   | `contracts/MilliesLens.sol`            | Read-only “lens” for aggregated token & trade data.   |
| **Deploy Script**                 | `scripts/deploy-template.js`           | Deploys libraries & contracts, runs sanity checks.     |
| **Setup Script**                  | `scripts/setup-template.js`            | Configures wallets, fees, cooldowns & anti-bot flags. |

---

## Prerequisites

- **Node.js** ≥ 16.x  
- **npm** or **yarn**  
- **Hardhat** (installed locally in project)  
- **Environment Variables** (in a `.env` file):
  - `PRIVATE_KEY` – deployer’s private key  
  - `BSC_MAINNET_RPC_URL` – BSC Mainnet RPC endpoint  
  - `BSC_TESTNET_RPC_URL` – BSC Testnet RPC endpoint  
  - _Optional:_ `ETHERSCAN_API_KEY` – for contract verification  

---

## Installation

```bash
# 1. Clone repository
git clone https://github.com/your-org/millies-token.git
cd millies-token

# 2. Install dependencies
npm install
# or
yarn

# 3. Prepare environment
cp .env.example .env
# Edit .env and set PRIVATE_KEY, RPC URLs, (and ETHERSCAN_API_KEY)
## Contracts

### `contracts/Interfaces.sol`
**Purpose:** Defines standard PancakeSwap V2 interfaces used across the system.

#### `IUniswapV2Router02`
- `WETH()` – returns wrapped BNB address.  
- `swapExactTokensForETHSupportingFeeOnTransferTokens(...)` – router swap supporting fee-on-transfer tokens.  
- `addLiquidityETH(...)` / `removeLiquidityETHSupportingFeeOnTransferTokens(...)` – liquidity management.

#### `IPancakeFactory`
- `getPair(tokenA, tokenB)` – returns LP pair address.

#### `IPancakePair`
- `token0()` / `token1()` – returns underlying tokens.  
- `getReserves()` – fetches reserves & timestamp.

---

### `contracts/LiquidityLib.sol`
**Purpose:** On-chain library for maintaining liquidity-pool balances & TWAP (time-weighted average price).

**Structs & Constants**
- `LiquidityData` – stores `liquidityPoolBalance`, `liquidityPoolBalanceTWAP`, `lastTWAPUpdate`, `lastTWAPBlock`.  
- `TWAP_PERIOD` – fixed interval (30 min) for TWAP updates.

**Event**
- `LiquidityPoolUpdated(oldBalance, newBalance, timestamp)` – emitted on reset.

**Key Functions**
- `updatePoolBalance(...)` – refreshes stored pool balance.  
- `getLiquidityBalanceForView(...)` – returns current stored balance for view-only callers.  
- `updateTWAPInHook(...)` – computes & updates TWAP if period elapsed.  
- `getLiquidityStats(...)` – returns `(balance, TWAP, lastUpdate, lastBlock)`.  
- `resetTWAPData(...)` – reinitializes TWAP tracking to current reserves.

---

### `contracts/TaxLib.sol`
**Purpose:** Calculates buy/sell taxes based on dump size, time-based rules, and Sybil detection.

**Enums & Constants**
- `TaxCategory` – `{ STANDARD, LIQUIDITY_IMPACT, THREE_DAY_RULE, SYBIL_DEFENSE, OTHER }`.  
- `BASIS_POINTS`, `THREE_DAYS`, dump thresholds.

**Key Functions**
- `calculateLiquidityTax(...)` – tax based on pool impact.  
- `calculate3DayTax(...)` – higher tax if sold within 3 days of purchase.  
- `update3DaySellWindow(...)` – tracks sell timestamps per wallet.  
- `calculateSybilTax(...)` – additional tax for cluster detection.  
- `_calculateIndividualWalletTax(...)` – wallet-specific time tax.  
- `calculateComprehensiveTax(...)` – aggregates multiple tax categories.  
- `taxCategoryToString(...)` – returns category name for logging.  

**Utility**
- `validateTaxThresholds()`, `getTaxThresholds()`, `getTaxRates()`, `safeMul()`, `safePercentage()`, `wouldOverflow()`.

---

### `contracts/MilliesToken.sol`
**Purpose:** Main ERC-20 token with advanced tax & anti-bot features; owner-managed setup & configuration.  
**Inheritance:** `ERC20`, `Ownable`, `Pausable`, `ReentrancyGuard`

**Events**
- `TaxCollected`, `BuyTaxCollected` – when taxes are taken.  
- `TradingToggled`, `FeatureToggled` – toggles for trading/features.  
- `SetupCompleted`, `WalletUpdated`, `WalletFunded` – setup & funding lifecycle.  
- `AddressBlacklisted`, `HelperContractUpdated`, `TradeDetected` – security & monitoring.  
- `DegradedModeActivated` / `Deactivated`, `HelperValidationFailed`.

**Modifiers**
- `onlyBeforeSetup` – restricts pre-setup calls.  
- `validAddress(addr)` – ensures non-zero address.  
- `enhancedBlacklistCheck` – blocks blacklisted wallets.

**Key Functions**
- `validateTransfer(...)` – pre-transfer checks delegated to helper.  
- `processBuy(...)`, `processSell(...)` – hooks into helper for tax & cooldown.  
- `updateLiquidity()` – updates pool metrics via helper.  
- `transfer` / `transferFrom` overrides – enforce tax & reentrancy guard.

**Owner-only**
- **Tax & feature toggles:** `toggleBuyTax()`, `toggleDumpSpikeDetection()`, `toggleSybilDefense()`, `toggleAutoSwapAndLiquify()`.  
- **Setup & trading:** `completeSetup()`, `toggleTrading()`, `activateDegradedMode()`, `deactivateDegradedMode()`.  
- **Contract links & wallets:** `setHelperContract()`, `setAdvertisingWallet()`, `setCommunityWallet()`, `setLiquidityPool()`.  
- **Exclusions:** `excludeFromFees()`, `excludeFromCooldown()`, `setBlacklistStatus()`.  
- **Funding:** `fundAdvertisingWallet()`, `fundCommunityWallet()`.  
- **Emergency controls:** `pause()`, `unpause()`, `emergencyWithdraw()`.

---

### `contracts/MilliesHelper.sol`
**Purpose:** Encapsulates all tax & anti-bot logic; called by `MilliesToken` on transfers.  
**Inheritance:** `Ownable`, `ReentrancyGuard`

**Events**
- `TaxCollected`, `SellProcessed`, `BuyProcessed` – tax flow & net amounts.  
- `CooldownApplied`, `WalletClusterDetected`, `TradeTypeDetected` – cooldowns & Sybil detection.

**Key Functions**
- `validateTransfer(from, to, amount)` – ensures setup complete, trading enabled, no blacklists.  
- `processBuy(buyer, amount)` – applies buy-tax rules & returns net.  
- `processSell(seller, amount)` – applies sell-tax & returns net.  
- `getLiquidityData()` – view helper for pool stats.  
- `getSellWindow(account)`, `getCooldownInfo(account)` – per-wallet limits.  
- **View getters:** e.g. `dumpSpikeDetectionEnabled()`, `sybilDefenseEnabled()`, `autoSwapAndLiquifyEnabled()`, etc.

---

### `contracts/MilliesLens.sol`
**Purpose:** Read-only “lens” contract aggregating data for UIs & dashboards.

**Event**
- `LensError(function_name, error_message, timestamp)` – captures view failures.

**Key Functions**
- `getTokenMetrics()` – returns `(circulating, burned, ownerBalance, reservedTokens, dailyVolume, taxTotal)`.  
- `getTradingStats()` – returns cumulative buy/sell volumes and tax.  
- `getBuyInfo(account)`, `getSellInfo(account)` – detailed per-wallet tax & cooldown info.  
- `getTradingStatus()` – indicates whether trading is enabled & timestamp.  
- `getLiquidityData()` – proxies to helper’s liquidity stats.  
- `getTokenSummary()` – high-level one-call summary of key metrics.

---

## Scripts

### `scripts/deploy-template.js`
**Purpose:** Deploys all libraries & contracts in order, runs basic sanity checks, enforces EIP-170 size limits, and prints addresses & Hardhat-verify commands.  

```bash
# Deploy to BSC Testnet
npx hardhat run scripts/deploy-template.js --network bscTestnet

# Deploy to BSC Mainnet
npx hardhat run scripts/deploy-template.js --network bscMainnet

### `scripts/setup-template.js`
**Purpose:** Configures deployed contracts: sets helper, wallets, fee & cooldown exclusions, anti-bot toggles, and optionally funds advertising/community wallets.

```bash
# Setup on BSC Testnet
npx hardhat run scripts/setup-template.js --network bscTestnet

# Setup on BSC Mainnet
npx hardhat run scripts/setup-template.js --network bscMainnet

```bash
npx hardhat compile

Verify on BscScan
```bash
npx hardhat verify \
  --network bscMainnet \
  <MilliesTokenAddress> "<PancakeRouterAddress>"

npx hardhat verify \
  --network bscMainnet \
  <MilliesHelperAddress> "<MilliesTokenAddress>"

npx hardhat verify \
  --network bscMainnet \
  <MilliesLensAddress> "<MilliesTokenAddress>"

Testing
Run unit & integration tests

```bash
npx hardhat test

Coverage report
(if using solidity-coverage)

```bash
npx hardhat coverage

Security & Audits
Contracts audited internally; leverage OpenZeppelin’s ReentrancyGuard, Pausable, and audited libraries.

Recommended tools:

Slither (trailofbits/slither)

MythX (mythx.io)

Hardhat security plugins

Known limitations:

Token contract approaches EIP-170 size limit (24 KB); ensure library sizes remain within bounds.

Three-day sell rule & Sybil detection are heuristic; monitor for edge cases.

Contributing & Support
Issues & Bugs: File a GitHub issue.

Pull Requests: Fork the repo, branch, implement, and open a PR against main.

Community & Help: Join our Telegram: https://t.me/+5WaxFKW5qjs5OTQx

Code Style: Follow the Solidity Style Guide and run:

bash
npx hardhat lint

License
This project is licensed under the MIT License.