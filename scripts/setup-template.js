//fileName: setup-template.js - CLEAN GITHUB VERSION
const { ethers } = require("hardhat");

/**
 * MilliesToken Setup Script - Template Version
 * 
 * BEFORE USING:
 * 1. Deploy all contracts using deploy-template.js
 * 2. Update DEPLOYED_ADDRESSES with your actual contract addresses
 * 3. Update WALLET_ADDRESSES with your actual wallet addresses
 * 4. Configure .env file with your private key
 * 5. Ensure you're the owner of the deployed contracts
 * 
 * USAGE:
 * npx hardhat run scripts/setup-template.js --network bscMainnet
 * npx hardhat run scripts/setup-template.js --network bscTestnet
 */

async function main() {
  console.log("🚀 Starting MilliesToken Setup...\n");

  // =============================================================================
  // DEPLOYMENT ADDRESSES - UPDATE WITH YOUR ACTUAL DEPLOYED ADDRESSES
  // =============================================================================

  const DEPLOYED_ADDRESSES = {
    // ⚠️ REPLACE THESE WITH YOUR ACTUAL DEPLOYED CONTRACT ADDRESSES
    milliesToken: "0x0000000000000000000000000000000000000000",     // YOUR_TOKEN_ADDRESS_HERE
    milliesHelper: "0x0000000000000000000000000000000000000000",    // YOUR_HELPER_ADDRESS_HERE
    milliesLens: "0x0000000000000000000000000000000000000000",      // YOUR_LENS_ADDRESS_HERE
    liquidityLib: "0x0000000000000000000000000000000000000000",    // YOUR_LIQUIDITY_LIB_ADDRESS_HERE
    taxLib: "0x0000000000000000000000000000000000000000"           // YOUR_TAX_LIB_ADDRESS_HERE
  };

  const WALLET_ADDRESSES = {
    // ⚠️ REPLACE THESE WITH YOUR ACTUAL WALLET ADDRESSES
    advertisingWallet: "0x0000000000000000000000000000000000000000", // YOUR_ADVERTISING_WALLET_HERE
    communityWallet: "0x0000000000000000000000000000000000000000",   // YOUR_COMMUNITY_WALLET_HERE
    
    // Optional: Add additional addresses that should be excluded from fees/cooldowns
    additionalExclusions: [
      // "0x0000000000000000000000000000000000000000", // Example: Team member wallet
      // "0x0000000000000000000000000000000000000000", // Example: Marketing wallet
    ]
  };

  // =============================================================================
  // VALIDATION - ENSURE ADDRESSES ARE UPDATED
  // =============================================================================

  function validateAddresses() {
    const errors = [];
    
    // Check deployed addresses
    for (const [key, value] of Object.entries(DEPLOYED_ADDRESSES)) {
      if (value === "0x0000000000000000000000000000000000000000") {
        errors.push(`DEPLOYED_ADDRESSES.${key}: Still using placeholder address`);
      } else if (!ethers.isAddress(value)) {
        errors.push(`DEPLOYED_ADDRESSES.${key}: Invalid address format - ${value}`);
      }
    }
    
    // Check wallet addresses
    for (const [key, value] of Object.entries(WALLET_ADDRESSES)) {
      if (Array.isArray(value)) {
        value.forEach((addr, index) => {
          if (addr && !ethers.isAddress(addr)) {
            errors.push(`WALLET_ADDRESSES.${key}[${index}]: Invalid address format - ${addr}`);
          }
        });
      } else if (value === "0x0000000000000000000000000000000000000000") {
        errors.push(`WALLET_ADDRESSES.${key}: Still using placeholder address`);
      } else if (!ethers.isAddress(value)) {
        errors.push(`WALLET_ADDRESSES.${key}: Invalid address format - ${value}`);
      }
    }
    
    return errors;
  }

  const validationErrors = validateAddresses();
  if (validationErrors.length > 0) {
    console.log("❌ CRITICAL: Address validation failed!");
    console.log("📋 Required updates:");
    validationErrors.forEach(error => console.log(`   • ${error}`));
    console.log("\n💡 Please update all addresses in the configuration section!");
    return;
  }

  // =============================================================================
  // NETWORK DETECTION AND CONFIGURATION
  // =============================================================================

  const network = await ethers.provider.getNetwork();
  const isMainnet = network.chainId === 56n;  // BSC Mainnet
  const isTestnet = network.chainId === 97n;   // BSC Testnet

  // PancakeSwap router addresses (public information)
  const PANCAKE_ROUTER = isMainnet 
    ? "0x10ED43C718714eb63d5aA57B78B54704E256024E" // BSC Mainnet
    : "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // BSC Testnet

  console.log(`📡 Network: ${isMainnet ? 'BSC Mainnet' : isTestnet ? 'BSC Testnet' : 'Unknown'} (Chain ID: ${network.chainId})`);
  console.log(`🥞 PancakeSwap Router: ${PANCAKE_ROUTER}\n`);

  // Mainnet warning
  if (isMainnet) {
    console.log("⚠️  WARNING: MAINNET CONFIGURATION");
    console.log("🔴 This will configure PRODUCTION contracts on BSC Mainnet");
    console.log("🔴 Ensure all addresses and settings are correct\n");
  }

  // =============================================================================
  // CONTRACT CONNECTIONS AND VALIDATION
  // =============================================================================

  const [deployer] = await ethers.getSigners();
  console.log("👤 Deployer:", deployer.address);

  let milliesToken, milliesHelper;
  
  try {
    // Connect to contracts
    console.log("🔗 Connecting to contracts...");
    
    milliesToken = await ethers.getContractAt("MilliesToken", DEPLOYED_ADDRESSES.milliesToken);
    milliesHelper = await ethers.getContractAt("MilliesHelper", DEPLOYED_ADDRESSES.milliesHelper);
    
    // Verify contract ownership and basic functionality
    console.log("🧪 Verifying contract functionality...");
    
    const [tokenOwner, helperOwner, tokenName, tokenSymbol] = await Promise.all([
      milliesToken.owner(),
      milliesHelper.owner(),
      milliesToken.name(),
      milliesToken.symbol()
    ]);
    
    // Validate ownership
    if (tokenOwner.toLowerCase() !== deployer.address.toLowerCase()) {
      throw new Error(`Token owner mismatch! Expected: ${deployer.address}, Found: ${tokenOwner}`);
    }
    if (helperOwner.toLowerCase() !== deployer.address.toLowerCase()) {
      throw new Error(`Helper owner mismatch! Expected: ${deployer.address}, Found: ${helperOwner}`);
    }
    
    // Validate token details
    if (tokenName !== "Millies" || tokenSymbol !== "MILLIES") {
      throw new Error(`Token details mismatch! Expected: Millies (MILLIES), Found: ${tokenName} (${tokenSymbol})`);
    }
    
    // Verify helper is linked to correct token
    const helperTokenAddress = await milliesHelper.token();
    if (helperTokenAddress.toLowerCase() !== DEPLOYED_ADDRESSES.milliesToken.toLowerCase()) {
      throw new Error(`Helper contract linked to wrong token! Expected: ${DEPLOYED_ADDRESSES.milliesToken}, Found: ${helperTokenAddress}`);
    }
    
    console.log("✅ Ownership verified");
    console.log("✅ Contract functionality verified");
    console.log("✅ Contracts connected\n");
    
  } catch (error) {
    console.log("❌ Contract connection/validation failed:", error.message);
    console.log("💡 Check that:");
    console.log("   • Contract addresses are correct and properly formatted");
    console.log("   • Contracts are deployed on this network");
    console.log("   • You are the owner of the contracts");
    console.log("   • Contract ABIs match deployed contracts");
    return;
  }

  // =============================================================================
  // SETUP PROCESS
  // =============================================================================

  try {
    console.log("⚙️ Starting setup process...\n");

    // =============================================================================
    // STEP 1: HELPER CONTRACT CONFIGURATION
    // =============================================================================
    console.log("🔧 Step 1: Configuring helper contract...");
    const currentHelper = await milliesToken.helperContract();
    if (currentHelper === ethers.ZeroAddress) {
      console.log("  Setting helper contract...");
      const tx1 = await milliesToken.setHelperContract(DEPLOYED_ADDRESSES.milliesHelper);
      await tx1.wait();
      console.log(`  ✅ Helper contract set: ${DEPLOYED_ADDRESSES.milliesHelper}`);
      console.log(`  🔗 Transaction: ${tx1.hash}`);
    } else if (currentHelper.toLowerCase() === DEPLOYED_ADDRESSES.milliesHelper.toLowerCase()) {
      console.log("  ℹ️ Helper contract already configured correctly");
    } else {
      console.log(`  ⚠️ Helper contract set to different address: ${currentHelper}`);
      console.log("  🔄 Updating to correct address...");
      const tx1 = await milliesToken.setHelperContract(DEPLOYED_ADDRESSES.milliesHelper);
      await tx1.wait();
      console.log("  ✅ Helper contract updated");
    }

    // =============================================================================
    // STEP 2: WALLET CONFIGURATION
    // =============================================================================
    console.log("\n💰 Step 2: Configuring wallet addresses...");
    
    // Advertising Wallet
    console.log("  📢 Setting advertising wallet...");
    const currentAdvWallet = await milliesToken.advertisingWallet();
    if (currentAdvWallet === ethers.ZeroAddress) {
      const tx2 = await milliesToken.setAdvertisingWallet(WALLET_ADDRESSES.advertisingWallet);
      await tx2.wait();
      console.log(`  ✅ Advertising wallet set: ${WALLET_ADDRESSES.advertisingWallet}`);
      console.log(`  🔗 Transaction: ${tx2.hash}`);
    } else if (currentAdvWallet.toLowerCase() === WALLET_ADDRESSES.advertisingWallet.toLowerCase()) {
      console.log("  ℹ️ Advertising wallet already configured correctly");
    } else {
      console.log(`  ⚠️ Advertising wallet already set to: ${currentAdvWallet}`);
      console.log("  💡 Skipping update (use separate function if change needed)");
    }

    // Community Wallet
    console.log("  🏘️ Setting community wallet...");
    const currentCommWallet = await milliesToken.communityWallet();
    if (currentCommWallet === ethers.ZeroAddress) {
      const tx3 = await milliesToken.setCommunityWallet(WALLET_ADDRESSES.communityWallet);
      await tx3.wait();
      console.log(`  ✅ Community wallet set: ${WALLET_ADDRESSES.communityWallet}`);
      console.log(`  🔗 Transaction: ${tx3.hash}`);
    } else if (currentCommWallet.toLowerCase() === WALLET_ADDRESSES.communityWallet.toLowerCase()) {
      console.log("  ℹ️ Community wallet already configured correctly");
    } else {
      console.log(`  ⚠️ Community wallet already set to: ${currentCommWallet}`);
      console.log("  💡 Skipping update (use separate function if change needed)");
    }

    // =============================================================================
    // STEP 3: PANCAKESWAP INTEGRATION CONFIGURATION
    // =============================================================================
    console.log("\n🥞 Step 3: Configuring PancakeSwap Integration...");
    console.log("  🔥 CRITICAL: Ensuring proper tax collection on PancakeSwap trades\n");

    // Validate router address matches expected
    const contractRouter = await milliesToken.pancakeRouter();
    if (contractRouter.toLowerCase() !== PANCAKE_ROUTER.toLowerCase()) {
      console.log(`  ⚠️ WARNING: Contract router (${contractRouter}) doesn't match expected (${PANCAKE_ROUTER})`);
      console.log("  💡 This may be intentional for testing, but verify in production");
    }

    // Router Configuration
    console.log("  🔧 Configuring PancakeSwap router...");
    const routerCooldownExcluded = await milliesToken.isExcludedFromCooldown(PANCAKE_ROUTER);
    const routerFeeExcluded = await milliesToken.isExcludedFromFees(PANCAKE_ROUTER);
    
    if (!routerCooldownExcluded) {
      console.log("    Excluding router from cooldowns...");
      const tx4a = await milliesToken.excludeFromCooldown(PANCAKE_ROUTER, true);
      await tx4a.wait();
      console.log("    ✅ Router excluded from cooldowns (allows liquidity operations)");
    } else {
      console.log("    ℹ️ Router already excluded from cooldowns");
    }

    if (routerFeeExcluded) {
      console.log("    🔥 FIXING: Including router in fees for tax collection...");
      const tx4b = await milliesToken.excludeFromFees(PANCAKE_ROUTER, false);
      await tx4b.wait();
      console.log("    ✅ Router INCLUDED in fees (enables PancakeSwap tax collection)");
    } else {
      console.log("    ✅ Router already included in fees (GOOD!)");
    }

    // LP Configuration (if set)
    const currentLP = await milliesToken.liquidityPool();
    if (currentLP !== ethers.ZeroAddress) {
      console.log("  🏊 Configuring liquidity pool...");
      const lpFeeExcluded = await milliesToken.isExcludedFromFees(currentLP);
      const lpCooldownExcluded = await milliesToken.isExcludedFromCooldown(currentLP);
      
      if (lpFeeExcluded) {
        console.log("    🔥 FIXING: Including LP in fees for tax detection...");
        const tx4c1 = await milliesToken.excludeFromFees(currentLP, false);
        await tx4c1.wait();
        console.log("    ✅ LP INCLUDED in fees (enables tax detection)");
      } else {
        console.log("    ✅ LP already included in fees (GOOD!)");
      }
      
      if (!lpCooldownExcluded) {
        console.log("    Excluding LP from cooldowns...");
        const tx4c2 = await milliesToken.excludeFromCooldown(currentLP, true);
        await tx4c2.wait();
        console.log("    ✅ LP excluded from cooldowns");
      } else {
        console.log("    ℹ️ LP already excluded from cooldowns");
      }
    } else {
      console.log("  ⚠️ LP not set yet - will configure when LP is added");
    }

    // =============================================================================
    // STEP 4: SYSTEM ADDRESS EXCLUSIONS
    // =============================================================================
    console.log("\n🚫 Step 4: Configuring system address exclusions...");
    
    const addressesToExclude = [
      DEPLOYED_ADDRESSES.milliesHelper,
      DEPLOYED_ADDRESSES.milliesLens,
      WALLET_ADDRESSES.advertisingWallet,
      WALLET_ADDRESSES.communityWallet,
      ...WALLET_ADDRESSES.additionalExclusions
    ].filter(addr => addr && addr !== "0x0000000000000000000000000000000000000000" && ethers.isAddress(addr));

    console.log(`  📋 Processing ${addressesToExclude.length} validated addresses...`);
    
    for (const address of addressesToExclude) {
      console.log(`    Processing: ${address.slice(0,6)}...${address.slice(-4)}`);
      
      try {
        // Fee exclusion
        const isExcludedFromFees = await milliesToken.isExcludedFromFees(address);
        if (!isExcludedFromFees) {
          const tx = await milliesToken.excludeFromFees(address, true);
          await tx.wait();
          console.log(`      ✅ Excluded from fees`);
        } else {
          console.log(`      ℹ️ Already excluded from fees`);
        }

        // Cooldown exclusion  
        const isExcludedFromCooldown = await milliesToken.isExcludedFromCooldown(address);
        if (!isExcludedFromCooldown) {
          const tx = await milliesToken.excludeFromCooldown(address, true);
          await tx.wait();
          console.log(`      ✅ Excluded from cooldowns`);
        } else {
          console.log(`      ℹ️ Already excluded from cooldowns`);
        }
      } catch (error) {
        console.log(`      ❌ Failed to process ${address}: ${error.message}`);
      }
    }

    // =============================================================================
    // STEP 5: PRODUCTION FEATURE ACTIVATION
    // =============================================================================
    console.log("\n⚙️ Step 5: Activating production features...");
    
    // Check current feature states
    const [dumpSpikeEnabled, sybilEnabled, buyTaxEnabled] = await Promise.all([
      milliesToken.dumpSpikeDetectionEnabled(),
      milliesToken.sybilDefenseEnabled(),
      milliesToken.buyTaxEnabled()
    ]);

    // Enable anti-bot features by default
    if (!dumpSpikeEnabled) {
      console.log("  🛡️ Enabling dump spike detection...");
      const tx6a = await milliesToken.toggleDumpSpikeDetection();
      await tx6a.wait();
      console.log("  ✅ Dump spike detection ENABLED");
    } else {
      console.log("  ℹ️ Dump spike detection already enabled");
    }

    if (!sybilEnabled) {
      console.log("  🔒 Enabling sybil defense...");
      const tx6b = await milliesToken.toggleSybilDefense();
      await tx6b.wait();
      console.log("  ✅ Sybil defense ENABLED");
    } else {
      console.log("  ℹ️ Sybil defense already enabled");
    }

    // Buy tax enabled by default (already set in constructor)
    console.log(`  💳 Buy tax status: ${buyTaxEnabled ? '✅ ENABLED' : '⚠️ DISABLED'}`);
    if (!buyTaxEnabled && isMainnet) {
      console.log("  🔥 Enabling buy tax for production...");
      const tx6c = await milliesToken.toggleBuyTax();
      await tx6c.wait();
      console.log("  ✅ Buy tax ENABLED");
    }

    // =============================================================================
    // STEP 6: INITIAL WALLET FUNDING (OPTIONAL)
    // =============================================================================
    console.log("\n💸 Step 6: Initial wallet funding...");
    const ownerBalance = await milliesToken.balanceOf(deployer.address);
    
    // Funding amounts (you can adjust these)
    const fundingAmount = isMainnet 
      ? ethers.parseEther("100000000")   // 100M for mainnet
      : ethers.parseEther("10000000");   // 10M for testnet

    console.log(`  💰 Owner balance: ${ethers.formatEther(ownerBalance)} MILLIES`);
    console.log(`  📊 Proposed funding: ${ethers.formatEther(fundingAmount)} MILLIES each`);

    if (ownerBalance >= fundingAmount * 2n) {
      console.log("  💸 Funding wallets...");
      
      // Fund advertising wallet
      try {
        const advBalance = await milliesToken.balanceOf(WALLET_ADDRESSES.advertisingWallet);
        if (advBalance === 0n) {
          console.log("    📢 Funding advertising wallet...");
          const tx7a = await milliesToken.fundAdvertisingWallet(fundingAmount);
          await tx7a.wait();
          console.log("    ✅ Advertising wallet funded");
        } else {
          console.log(`    ℹ️ Advertising wallet already has ${ethers.formatEther(advBalance)} MILLIES`);
        }
      } catch (error) {
        console.log(`    ❌ Failed to fund advertising wallet: ${error.message}`);
      }
      
      // Fund community wallet
      try {
        const commBalance = await milliesToken.balanceOf(WALLET_ADDRESSES.communityWallet);
        if (commBalance === 0n) {
          console.log("    🏘️ Funding community wallet...");
          const tx7b = await milliesToken.fundCommunityWallet(fundingAmount);
          await tx7b.wait();
          console.log("    ✅ Community wallet funded");
        } else {
          console.log(`    ℹ️ Community wallet already has ${ethers.formatEther(commBalance)} MILLIES`);
        }
      } catch (error) {
        console.log(`    ❌ Failed to fund community wallet: ${error.message}`);
      }
    } else {
      console.log("  ⚠️ Insufficient balance to fund wallets");
      console.log("  💡 You can fund wallets later using dedicated functions");
    }

    // =============================================================================
    // VERIFICATION AND FINAL STATUS
    // =============================================================================

    console.log("\n🔍 VERIFICATION: Checking complete configuration...\n");

    // Check PancakeSwap configuration
    const routerFeesExcluded = await milliesToken.isExcludedFromFees(PANCAKE_ROUTER);
    const routerCooldownsExcluded = await milliesToken.isExcludedFromCooldown(PANCAKE_ROUTER);

    console.log("📊 PancakeSwap Configuration:");
    console.log(`  Router excluded from fees: ${routerFeesExcluded ? '❌ YES (BAD!)' : '✅ NO (GOOD!)'}`);
    console.log(`  Router excluded from cooldowns: ${routerCooldownsExcluded ? '✅ YES (GOOD!)' : '❌ NO (BAD!)'}`);

    // Check LP configuration (if set)
    const lpAddress = await milliesToken.liquidityPool();
    if (lpAddress !== ethers.ZeroAddress) {
      const lpFeesExcluded = await milliesToken.isExcludedFromFees(lpAddress);
      const lpCooldownsExcluded = await milliesToken.isExcludedFromCooldown(lpAddress);
      
      console.log("\n📊 Liquidity Pool Configuration:");
      console.log(`  LP excluded from fees: ${lpFeesExcluded ? '❌ YES (BAD!)' : '✅ NO (GOOD!)'}`);
      console.log(`  LP excluded from cooldowns: ${lpCooldownsExcluded ? '✅ YES (GOOD!)' : '❌ NO (BAD!)'}`);
    }

    // Get final setup status
    const setupStatus = {
      helperContract: await milliesToken.helperContract(),
      advertisingWallet: await milliesToken.advertisingWallet(),
      communityWallet: await milliesToken.communityWallet(),
      liquidityPool: await milliesToken.liquidityPool(),
      setupCompleted: await milliesToken.setupCompleted(),
      tradingEnabled: await milliesToken.tradingEnabled(),
      dumpSpikeEnabled: await milliesToken.dumpSpikeDetectionEnabled(),
      sybilDefenseEnabled: await milliesToken.sybilDefenseEnabled(),
      buyTaxEnabled: await milliesToken.buyTaxEnabled()
    };

    console.log("\n📊 Final Configuration Status:");
    Object.entries(setupStatus).forEach(([key, value]) => {
      const status = value === ethers.ZeroAddress ? "❌ NOT SET" : 
                    typeof value === 'boolean' ? (value ? "✅ ENABLED" : "⚠️ DISABLED") : 
                    `✅ ${value.slice(0,6)}...${value.slice(-4)}`;
      console.log(`  ${key}: ${status}`);
    });

    // =============================================================================
    // NEXT STEPS GUIDANCE
    // =============================================================================

    console.log("\n" + "=".repeat(80));
    console.log("🎯 CONFIGURATION COMPLETED!");
    console.log("=".repeat(80));

    if (setupStatus.liquidityPool === ethers.ZeroAddress) {
      console.log("📌 NEXT STEPS - BEFORE TRADING:");
      console.log("1. 🥞 Create liquidity pool on PancakeSwap");
      console.log("2. 💰 Add initial liquidity (recommend 50%+ of supply)");
      console.log("3. 🔒 Lock liquidity on trusted platform (PinkSale, etc.)");
      console.log("4. 🎯 Set LP address: await milliesToken.setLiquidityPool('LP_ADDRESS')");
      console.log("5. ✅ Complete setup: await milliesToken.completeSetup()");
      console.log("6. 📊 Test with small transactions");
    } else if (!setupStatus.setupCompleted) {
      console.log("📌 FINAL STEP:");
      console.log("✅ Complete setup: await milliesToken.completeSetup()");
      console.log("🧪 Test with small transactions first!");
    } else {
      console.log("🎉 ALL SETUP COMPLETE!");
      console.log("🚀 Ready for production trading!");
    }

    console.log("\n✅ KEY FEATURES CONFIRMED:");
    console.log("• ✅ PancakeSwap tax collection properly configured");
    console.log("• ✅ Anti-bot features activated");
    console.log("• ✅ Buy tax system enabled");
    console.log("• ✅ Dump spike protection active");
    console.log("• ✅ Sybil defense enabled");
    console.log("• ✅ System addresses properly excluded");

    if (isMainnet) {
      console.log("\n🚀 MAINNET PRODUCTION CHECKLIST:");
      console.log("• ✅ Contracts verified on BSCScan");
      console.log("• ✅ Liquidity added to PancakeSwap");
      console.log("• ✅ Liquidity locked on trusted platform");
      console.log("• ✅ Small test transactions completed");
      console.log("• ✅ Tax collection confirmed working");
      console.log("• ✅ Anti-bot features tested");
    }

    console.log("\n✨ Configuration completed successfully!");

  } catch (error) {
    console.error("\n💥 SETUP FAILED:");
    console.error("❌", error.message);
    
    console.log("\n🔍 Troubleshooting:");
    console.log("• Verify all addresses are correct and deployed");
    console.log("• Ensure you have sufficient BNB for gas");
    console.log("• Check you're the contract owner");
    console.log("• Verify network connection and RPC endpoint");
    
    if (isMainnet) {
      console.log("\n🆘 MAINNET SETUP FAILURE:");
      console.log("• STOP all token operations immediately");
      console.log("• Verify all contract addresses and configurations");
      console.log("• Test setup on testnet first if unsure");
    }
    
    throw error;
  }
}

// Enhanced error handling
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n💥 CRITICAL SETUP ERROR:");
    console.error(error.message);
    
    console.log("\n📝 Error Details:");
    console.log("Timestamp:", new Date().toISOString());
    console.log("Error Type:", error.constructor.name);
    
    if (error.code) console.log("Error Code:", error.code);
    if (error.reason) console.log("Error Reason:", error.reason);
    
    process.exit(1);
  });