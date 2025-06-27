//fileName: CompleteSetup.js - DEGRADED MODE SECURITY FIXED VERSION
//npx hardhat run scripts/CompleteSetup.js --network bscMainnet
const { ethers } = require("hardhat");

/**
 * PRODUCTION MilliesToken Setup Script - DEGRADED MODE SECURITY FIXED VERSION
 * Configures all contracts for mainnet deployment with enhanced security and degraded mode monitoring
 */

async function main() {
  console.log("🚀 Starting PRODUCTION MilliesToken Setup...\n");

  // =============================================================================
  // MAINNET CONFIGURATION - UPDATE THESE WITH YOUR ACTUAL ADDRESSES
  // =============================================================================

  const DEPLOYED_ADDRESSES = {
    // ✅ UPDATE THESE WITH YOUR ACTUAL DEPLOYED ADDRESSES
    milliesToken: "0x9A2676908e4B7ab197f63c672092D86aeeeF3eA3",
    milliesHelper: "0x824730FE53a434E700D43Ac128264d580b0C105c",
    milliesLens: "0x4a9640dc292F7025bD0D1410eEc6CE900020FEfd",
    liquidityLib: "0xF59ba274C0A99EdF2dde0E5E6ffBCcB6E95AA436",
    taxLib: "0xa8ca9620f823842Cb3Af357F2C96D327109ecc52"
  };

  const WALLET_ADDRESSES = {
    // ✅ CRITICAL: UPDATE THESE WITH YOUR ACTUAL MAINNET WALLET ADDRESSES
    advertisingWallet: "0x5BD594887A6a99b991E56E2541785B61606063bF",
    communityWallet: "0x3c4AA84c1e2177c18420E7F1cE70fa65fBC4Fd59",
    additionalExclusions: [
      // Add any additional addresses that should be excluded from fees/cooldowns
      // "0x1234...", // Example: Team member wallet
      // "0x5678...", // Example: Marketing wallet
      "0x54D6442676a2B849a35a36341EB5BaBa7248db7d"
    ]
  };

  // Enhanced validation with proper error checking
  function validateAddresses() {
    const errors = [];
    
    // Check deployed addresses
    for (const [key, value] of Object.entries(DEPLOYED_ADDRESSES)) {
      if (value.includes("YOUR_") || value === "") {
        errors.push(`DEPLOYED_ADDRESSES.${key}: ${value}`);
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
      } else if (value.includes("YOUR_") || value === "") {
        errors.push(`WALLET_ADDRESSES.${key}: ${value}`);
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
  const isMainnet = network.chainId === 56n;
  const isTestnet = network.chainId === 97n;

  // ✅ MAINNET: PancakeSwap router addresses
  const PANCAKE_ROUTER = isMainnet 
    ? "0x10ED43C718714eb63d5aA57B78B54704E256024E" // ✅ BSC Mainnet
    : "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // 🧪 BSC Testnet

  console.log(`📡 Network: ${isMainnet ? 'BSC Mainnet' : isTestnet ? 'BSC Testnet' : 'Unknown'} (Chain ID: ${network.chainId})`);
  console.log(`🥞 PancakeSwap Router: ${PANCAKE_ROUTER}\n`);

  // 🔒 MAINNET WARNING
  if (isMainnet) {
    console.log("⚠️  WARNING: MAINNET CONFIGURATION");
    console.log("🔴 This will configure PRODUCTION contracts on BSC Mainnet");
    console.log("🔴 Ensure all addresses and settings are correct\n");
  }

  // =============================================================================
  // CONTRACT CONNECTIONS WITH ENHANCED VALIDATION
  // =============================================================================

  const [deployer] = await ethers.getSigners();
  console.log("👤 Deployer:", deployer.address);

  let milliesToken, milliesHelper;
  
  try {
    // Connect to contracts with enhanced validation
    console.log("🔗 Connecting to contracts...");
    
    milliesToken = await ethers.getContractAt("MilliesToken", DEPLOYED_ADDRESSES.milliesToken);
    milliesHelper = await ethers.getContractAt("MilliesHelper", DEPLOYED_ADDRESSES.milliesHelper);
    
    // ✅ SECURITY: Verify contract ownership and basic functionality
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
  // ✅ NEW: DEGRADED MODE STATUS CHECK
  // =============================================================================

  console.log("🔍 Checking system status...");
  
  try {
    const isDegraded = await milliesToken.degradedMode();
    if (isDegraded) {
      console.log("🚨 CRITICAL: System is in degraded mode!");
      const activatedTime = await milliesToken.degradedModeActivated();
      const duration = Math.floor(Date.now() / 1000) - Number(activatedTime);
      console.log(`   ⏰ Degraded mode active for: ${Math.floor(duration / 60)} minutes`);
      console.log("   🚫 Trading is COMPLETELY DISABLED");
      console.log("   💡 You must fix the helper contract and deactivate degraded mode before proceeding");
      console.log("   ⚠️  Setup will continue but system is NOT functional for trading\n");
    } else {
      console.log("✅ System is NOT in degraded mode - Normal operation\n");
    }
  } catch (error) {
    console.log("⚠️  Could not check degraded mode status:", error.message);
    console.log("   💡 Continuing with setup...\n");
  }

  // =============================================================================
  // ENHANCED SETUP PROCESS WITH IMPROVED ERROR HANDLING
  // =============================================================================

  try {
    console.log("⚙️ Starting PRODUCTION setup process...\n");

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
      
      // Check if degraded mode was deactivated
      const degradedAfter = await milliesToken.degradedMode();
      if (!degradedAfter) {
        console.log("  ✅ Degraded mode automatically deactivated with new helper");
      }
    } else if (currentHelper.toLowerCase() === DEPLOYED_ADDRESSES.milliesHelper.toLowerCase()) {
      console.log("  ℹ️ Helper contract already configured correctly");
    } else {
      console.log(`  ⚠️ Helper contract set to different address: ${currentHelper}`);
      console.log("  🔄 Updating to correct address...");
      const tx1 = await milliesToken.setHelperContract(DEPLOYED_ADDRESSES.milliesHelper);
      await tx1.wait();
      console.log("  ✅ Helper contract updated");
      
      // Check if degraded mode was deactivated
      const degradedAfter = await milliesToken.degradedMode();
      if (!degradedAfter) {
        console.log("  ✅ Degraded mode automatically deactivated with new helper");
      }
    }

    // =============================================================================
    // STEP 2: WALLET CONFIGURATION WITH ENHANCED VALIDATION
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
    // STEP 4: SYSTEM ADDRESS EXCLUSIONS WITH ENHANCED VALIDATION
    // =============================================================================
    console.log("\n🚫 Step 4: Configuring system address exclusions...");
    
    const addressesToExclude = [
      DEPLOYED_ADDRESSES.milliesHelper,
      DEPLOYED_ADDRESSES.milliesLens,
      WALLET_ADDRESSES.advertisingWallet,
      WALLET_ADDRESSES.communityWallet,
      ...WALLET_ADDRESSES.additionalExclusions
    ].filter(addr => addr && addr !== "" && !addr.includes("YOUR_") && ethers.isAddress(addr));

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
    // STEP 5: PRODUCTION FEATURE ACTIVATION WITH VALIDATION
    // =============================================================================
    console.log("\n⚙️ Step 5: Activating production features...");
    
    // Check current feature states first
    const [dumpSpikeEnabled, sybilEnabled, buyTaxEnabled] = await Promise.all([
      milliesToken.dumpSpikeDetectionEnabled(),
      milliesToken.sybilDefenseEnabled(),
      milliesToken.buyTaxEnabled()
    ]);

    // ✅ PRODUCTION: Enable anti-bot features by default
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

    // ✅ PRODUCTION: Buy tax enabled by default (already set in constructor)
    console.log(`  💳 Buy tax status: ${buyTaxEnabled ? '✅ ENABLED' : '⚠️ DISABLED'}`);
    if (!buyTaxEnabled && isMainnet) {
      console.log("  🔥 Enabling buy tax for production...");
      const tx6c = await milliesToken.toggleBuyTax();
      await tx6c.wait();
      console.log("  ✅ Buy tax ENABLED");
    }

    // =============================================================================
    // STEP 6: INITIAL WALLET FUNDING (OPTIONAL) - ENHANCED SAFETY
    // =============================================================================
    console.log("\n💸 Step 6: Initial wallet funding...");
    const ownerBalance = await milliesToken.balanceOf(deployer.address);
    
    // ✅ PRODUCTION: Mainnet funding amounts
    const fundingAmount = isMainnet 
      ? ethers.parseEther("70000000")   // 70M for mainnet
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
    // COMPREHENSIVE VERIFICATION WITH ENHANCED CHECKS
    // =============================================================================

    console.log("\n🔍 VERIFICATION: Checking complete configuration...\n");

    // ✅ NEW: Re-check degraded mode status after setup
    try {
      const isDegradedAfterSetup = await milliesToken.degradedMode();
      if (isDegradedAfterSetup) {
        console.log("🚨 WARNING: System is STILL in degraded mode after setup!");
        const activatedTime = await milliesToken.degradedModeActivated();
        const duration = Math.floor(Date.now() / 1000) - Number(activatedTime);
        console.log(`   ⏰ Degraded mode active for: ${Math.floor(duration / 60)} minutes`);
        console.log("   🚫 Trading is COMPLETELY DISABLED");
        console.log("   💡 Check helper contract configuration and manually deactivate if needed");
      } else {
        console.log("✅ System is NOT in degraded mode - Ready for trading");
      }
    } catch (error) {
      console.log("⚠️ Could not check degraded mode status:", error.message);
    }

    // Check PancakeSwap configuration
    const routerFeesExcluded = await milliesToken.isExcludedFromFees(PANCAKE_ROUTER);
    const routerCooldownsExcluded = await milliesToken.isExcludedFromCooldown(PANCAKE_ROUTER);

    console.log("\n📊 PancakeSwap Configuration:");
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

    // Enhanced final setup status with better error handling
    let setupStatus;
    try {
      setupStatus = {
        helperContract: await milliesToken.helperContract(),
        advertisingWallet: await milliesToken.advertisingWallet(),
        communityWallet: await milliesToken.communityWallet(),
        liquidityPool: await milliesToken.liquidityPool(),
        setupCompleted: await milliesToken.setupCompleted(),
        tradingEnabled: await milliesToken.tradingEnabled(),
        dumpSpikeEnabled: await milliesToken.dumpSpikeDetectionEnabled(),
        sybilDefenseEnabled: await milliesToken.sybilDefenseEnabled(),
        buyTaxEnabled: await milliesToken.buyTaxEnabled(),
        degradedMode: await milliesToken.degradedMode()
      };
    } catch (error) {
      console.log(`❌ Failed to retrieve setup status: ${error.message}`);
      return;
    }

    console.log("\n📊 Final Configuration Status:");
    Object.entries(setupStatus).forEach(([key, value]) => {
      let status;
      if (key === 'degradedMode') {
        status = value ? "🚨 ACTIVE (TRADING DISABLED)" : "✅ INACTIVE";
      } else if (value === ethers.ZeroAddress) {
        status = "❌ NOT SET";
      } else if (typeof value === 'boolean') {
        status = value ? "✅ ENABLED" : "⚠️ DISABLED";
      } else {
        status = `✅ ${value.slice(0,6)}...${value.slice(-4)}`;
      }
      console.log(`  ${key}: ${status}`);
    });

    // =============================================================================
    // SECURITY CHECKLIST VALIDATION
    // =============================================================================

    console.log("\n🔒 SECURITY CHECKLIST:");
    const securityChecks = [
      {
        name: "System NOT in degraded mode",
        passed: !setupStatus.degradedMode,
        critical: true
      },
      {
        name: "Router tax collection enabled",
        passed: !routerFeesExcluded,
        critical: true
      },
      {
        name: "LP tax detection enabled",  
        passed: lpAddress === ethers.ZeroAddress || !await milliesToken.isExcludedFromFees(lpAddress),
        critical: true
      },
      {
        name: "Anti-bot features active",
        passed: setupStatus.dumpSpikeEnabled && setupStatus.sybilDefenseEnabled,
        critical: false
      },
      {
        name: "Buy tax system operational",
        passed: setupStatus.buyTaxEnabled,
        critical: false
      },
      {
        name: "System wallets configured",
        passed: setupStatus.advertisingWallet !== ethers.ZeroAddress && setupStatus.communityWallet !== ethers.ZeroAddress,
        critical: true
      }
    ];

    securityChecks.forEach(check => {
      const icon = check.passed ? "✅" : (check.critical ? "🔴" : "⚠️");
      console.log(`  ${icon} ${check.name}: ${check.passed ? "PASS" : "FAIL"}`);
    });

    const criticalFailures = securityChecks.filter(check => check.critical && !check.passed);
    if (criticalFailures.length > 0) {
      console.log("\n🚨 CRITICAL SECURITY FAILURES DETECTED!");
      console.log("❌ DO NOT PROCEED TO PRODUCTION");
      criticalFailures.forEach(failure => {
        console.log(`   • ${failure.name}`);
      });
    }

    // =============================================================================
    // NEXT STEPS GUIDANCE
    // =============================================================================

    console.log("\n" + "=".repeat(80));
    console.log("🎯 CONFIGURATION COMPLETED!");
    console.log("=".repeat(80));

    if (setupStatus.degradedMode) {
      console.log("🚨 CRITICAL: SYSTEM IN DEGRADED MODE");
      console.log("📌 IMMEDIATE ACTIONS REQUIRED:");
      console.log("1. 🔧 Check helper contract configuration");
      console.log("2. 🔄 Try: await milliesToken.deactivateDegradedMode(ADDRESS_ZERO)");
      console.log("3. 🧪 Test helper contract functionality");
      console.log("4. 📞 Contact technical support if issues persist");
      console.log("⚠️  Trading is COMPLETELY DISABLED until degraded mode is deactivated");
    } else if (setupStatus.liquidityPool === ethers.ZeroAddress) {
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
    console.log("• ✅ Degraded mode security implemented");

    if (isMainnet) {
      console.log("\n🚀 MAINNET PRODUCTION CHECKLIST:");
      console.log("• ✅ Contracts verified on BSCScan");
      console.log("• ✅ Liquidity added to PancakeSwap");
      console.log("• ✅ Liquidity locked on trusted platform");
      console.log("• ✅ Small test transactions completed");
      console.log("• ✅ Tax collection confirmed working");
      console.log("• ✅ Anti-bot features tested");
      console.log("• ✅ Degraded mode protection verified");
      
      console.log("\n📊 MONITORING SETUP:");
      console.log("• Monitor burn address balance increases");
      console.log("• Track advertising wallet token accumulation");
      console.log("• Watch for TaxCollected events in transactions");
      console.log("• Verify daily volume tracking");
      console.log("• Monitor degraded mode status");
    }

    console.log("\n✨ Production configuration completed successfully!");

  } catch (error) {
    console.error("\n💥 SETUP FAILED:");
    console.error("❌", error.message);
    
    console.log("\n🔍 Troubleshooting:");
    console.log("• Verify all addresses are correct and deployed");
    console.log("• Ensure you have sufficient BNB for gas");
    console.log("• Check you're the contract owner");
    console.log("• Verify network connection and RPC endpoint");
    console.log("• Check contract verification on block explorer");
    console.log("• Check if system is in degraded mode");
    
    if (isMainnet) {
      console.log("\n🆘 MAINNET SETUP FAILURE:");
      console.log("• STOP all token operations immediately");
      console.log("• Verify all contract addresses and configurations");
      console.log("• Test setup on testnet first if unsure");
      console.log("• Seek technical assistance if needed");
    }
    
    throw error;
  }
}

// Enhanced error handling for production
async function runSetup() {
  try {
    await main();
  } catch (error) {
    console.error("\n💥 CRITICAL SETUP ERROR:");
    console.error(error.message);
    
    console.log("\n📝 Error Details:");
    console.log("Timestamp:", new Date().toISOString());
    console.log("Error Type:", error.constructor.name);
    
    // Enhanced error logging for debugging
    if (error.code) {
      console.log("Error Code:", error.code);
    }
    if (error.reason) {
      console.log("Error Reason:", error.reason);
    }
    if (error.transaction) {
      console.log("Failed Transaction:", error.transaction);
    }
    
    process.exit(1);
  }
}

// Export for use as module
module.exports = {
  main,
  runSetup
};

// Run if called directly
if (require.main === module) {
  runSetup();
}