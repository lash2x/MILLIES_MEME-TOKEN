# MilliesToken 🚀

> The first meme token with enterprise-grade anti-manipulation protection and a path to AI ownership.

[![BSC Network](https://img.shields.io/badge/Network-BSC-yellow)](https://bscscan.com/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.19-blue)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Security](https://img.shields.io/badge/Security-Multi--Layer-red)](docs/SECURITY.md)

## 🎯 What is MilliesToken?

MilliesToken is a revolutionary meme token that solves the #1 problem in crypto: **dump protection**. While 90%+ of meme tokens get destroyed by bots and whale dumps, MilliesToken uses advanced smart contract technology to detect and punish manipulation while protecting normal traders.

**Our ultimate vision**: Become the first token owned and operated by AI instead of humans.

## ✨ Key Features

- 🛡️ **Multi-Layer Dump Protection** - 45-75% taxes for large dumps and coordinated attacks
- 🧠 **Smart Pattern Detection** - Tracks individual wallets (72h) and clusters (35 days)
- ⚡ **Emergency Protection** - Automatic trading halt when security systems fail
- 🔥 **Deflationary Economics** - Burns 0.2-5.3% depending on trade type
- 🤖 **AI Ownership Roadmap** - Progressive transition from human to AI control
- 📊 **Complete Transparency** - All contracts verified and open source

## 📊 Token Information

| Property | Value |
|----------|-------|
| **Name** | Millies |
| **Symbol** | MILLIES |
| **Total Supply** | 1,000,000,000 (1B) |
| **Network** | Binance Smart Chain (BSC) |
| **Buy Tax** | 2% (0.2% burn, 1.8% liquidity) |
| **Sell Tax** | 7.05% (normal) or 45-75% (dumps) |

## 🚀 Quick Start

### For Traders

1. **Get a Web3 Wallet**: MetaMask, Trust Wallet, etc.
2. **Add BSC Network** to your wallet
3. **Buy on PancakeSwap**: 
   ```
   Contract: 0x54D6442676a2B849a35a36341EB5BaBa7248db7d
   Slippage: 12-15%
   ```
4. **Join Community**: [Telegram](#) | [Twitter](#)

### For Developers

```bash
# Clone the repository
git clone https://github.com/your-org/milliestoken
cd milliestoken

# Install dependencies  
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to testnet
npx hardhat run scripts/deploy.js --network bscTestnet
```

## 🏗️ Architecture

MilliesToken uses a sophisticated 6-contract system:

```
MilliesToken.sol     ← Main token contract with transfer logic
├── MilliesHelper.sol    ← Pattern detection and tax calculation  
├── TaxLib.sol          ← Tax mathematics library
├── LiquidityLib.sol    ← Liquidity monitoring library
├── MilliesLens.sol     ← Public dashboard and metrics
└── Interfaces.sol      ← DEX integration interfaces
```

### How Protection Works

1. **Individual Tracking**: Each wallet monitored over 72-hour windows
2. **Cluster Detection**: Identifies coordinated groups over 35 days  
3. **Instant Impact**: Real-time liquidity impact assessment
4. **Progressive Penalties**: Bigger dumps = higher taxes (up to 75%)

<details>
<summary>📋 <strong>Contract Addresses (BSC Mainnet)</strong></summary>

| Contract | Address | Verified |
|----------|---------|----------|
| **MilliesToken** | `0x54D6442676a2B849a35a36341EB5BaBa7248db7d` | ✅ |
| **MilliesHelper** | `TBD` | ⏳ |
| **MilliesLens** | `TBD` | ⏳ |
| **Marketing Wallet** | `0x5BD594887A6a99b991E56E2541785B61606063bF` | - |
| **Community Wallet** | `0x3c4AA84c1e2177c18420E7F1cE70fa65fBC4Fd59` | - |

</details>

## 🛡️ Security Features

### Always Active Protections
- ✅ Reentrancy protection on all functions
- ✅ Triple blacklist checking (sender, recipient, tx.origin)
- ✅ Safe math with overflow protection
- ✅ Flash loan resistance (30-min TWAP)
- ✅ Degraded mode failsafe

### Configurable Features
- 🎛️ Dump spike detection (45-75% taxes)
- 🎛️ Sybil defense (1% tax for new wallets)
- 🎛️ Auto-swap and liquify
- 🎛️ Emergency pause functionality

<details>
<summary>🔒 <strong>Security Considerations</strong></summary>

**Current Centralization (Temporary)**:
- Owner can update helper contract
- Owner can pause trading in emergencies  
- Owner can manage blacklist
- These controls are necessary for the sophisticated protection system

**Mitigation Strategy**:
- Progressive decentralization over 4 phases
- Community involvement in major decisions
- Eventual transition to AI ownership
- All code is open source and verifiable

</details>

## 📈 Tokenomics

### Tax Distribution

| Scenario | Total Tax | Burn | Liquidity | Marketing | Community |
|----------|-----------|------|-----------|-----------|-----------|
| **Buy** | 2% | 0.2% | 1.8% | 0% | 0% |
| **Normal Sell** | 7.05% | 0.5% | 5% | 1.5% | 0.05% |
| **Medium Dump** | 45% | 3.2% | 41.8% | 0% | 0% |
| **Large Dump** | 52% | 3.7% | 48.3% | 0% | 0% |
| **Extreme Dump** | 75% | 5.3% | 69.7% | 0% | 0% |

### Initial Distribution
- 40% - Presale liquidity
- 20% - Burn reserve (first 24h)
- 14% - Community & marketing
- 12% - Team
- 14% - Contingency reserve

## 🤖 AI Ownership Roadmap

### Phase 1: Launch & Prove 🔍
- ✅ Deploy contracts and establish security
- 🔄 Reach 1,000 holders
- 🔄 Complete initial audit

### Phase 2: Growth & Scale ⚡
- 🔄 Reach 5,000+ holders
- 🔄 Handle $5M+ trading volume
- 🔄 Establish partnerships

### Phase 3: Prepare for AI 🧱
- 🔄 Implement multisig governance
- 🔄 Test AI advisory systems
- 🔄 Launch NFT utilities

### Phase 4: AI Ownership 👁️‍🗨️
- 🔄 Transfer control to AI entity
- 🔄 Automated decision making
- 🔄 Community feedback integration

## 🧪 Development

### Prerequisites
- Node.js 16+
- Hardhat
- MetaMask with BSC testnet setup

### Testing
```bash
# Run all tests
npx hardhat test

# Run specific test
npx hardhat test test/MilliesToken.test.js

# Generate coverage report
npx hardhat coverage
```

### Deployment
```bash
# Deploy to BSC testnet
npx hardhat run scripts/deployManual.js --network bscTestnet

# Verify contracts
npx hardhat verify --network bscTestnet DEPLOYED_ADDRESS

# Complete setup
npx hardhat run scripts/completeSetup.js --network bscTestnet
```

## 📚 Documentation

- 📖 **[White Paper](whitepaper.md)** - Complete technical and economic overview
- 🔧 **[Technical Docs](docs/TECHNICAL.md)** - Contract architecture and APIs
- 🛡️ **[Security Guide](docs/SECURITY.md)** - Security features and best practices
- 🤖 **[AI Roadmap](docs/AI_ROADMAP.md)** - Detailed AI ownership transition plan

## 🌐 Community & Support

- 💬 **Telegram**: [Community Group](#)
- 🐦 **Twitter**: [@MilliesToken](#)
- 🌐 **Website**: [millionaireboys.fun](#)
- 💻 **GitHub**: [Issues](https://github.com/your-org/milliestoken/issues)
- 📧 **Email**: team@milliestoken.com

### Contributing

We welcome contributions! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting PRs.

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -m 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Submit a Pull Request

## ⚠️ Disclaimer

**High Risk Investment**: MilliesToken is experimental technology. You could lose 100% of your investment.

- ❌ Not financial advice
- ❌ No guaranteed returns  
- ❌ Participate at your own risk
- ✅ Only invest what you can afford to lose

## 📄 License

This project is licensed under the MIT License - see the MIT license.

---

**Built with ❤️ by the MilliesToken team | Pioneering the future of autonomous finance**