//fileName: deployManual.js - MAINNET READY VERSION WITH DEGRADED MODE MONITORING
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting PRODUCTION deployment...\n");

  // =============================================================================
  // MAINNET CONFIGURATION
  // =============================================================================
  
  // ✅ MAINNET: PancakeSwap router addresses
  const network = await ethers.provider.getNetwork();
  const isMainnet = network.chainId === 56n;
  const isTestnet = network.chainId === 97n;
  
  let ROUTER_ADDRESS;
  if (isMainnet) {
    ROUTER_ADDRESS = "0x10ED43C718714eb63d5aA57B78B54704E256024E"; // ✅ BSC Mainnet PancakeSwap
    console.log("🌐 Deploying to BSC MAINNET");
  } else if (isTestnet) {
    ROUTER_ADDRESS = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // 🧪 BSC Testnet
    console.log("🧪 Deploying to BSC TESTNET");
  } else {
    ROUTER_ADDRESS = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"; // Default to testnet for localhost
    console.log("🏠 Deploying to LOCALHOST (using testnet router)");
  }

  const [deployer] = await ethers.getSigners();
  console.log("📋 Deploying with account:", deployer.address);
  
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "BNB\n");

  // ✅ PRODUCTION: Enhanced balance check for mainnet
  const minimumBalance = isMainnet ? ethers.parseEther("0.5") : ethers.parseEther("0.1");
  if (balance < minimumBalance) {
    console.log(`❌ Insufficient balance! Need at least ${ethers.formatEther(minimumBalance)} BNB for deployment`);
    console.log("💡 For mainnet: Ensure you have extra BNB for initial liquidity and setup");
    return;
  }

  // 🔒 SECURITY: Mainnet deployment confirmation
  if (isMainnet) {
    console.log("⚠️  WARNING: MAINNET DEPLOYMENT");
    console.log("🔴 This will deploy to PRODUCTION on BSC Mainnet");
    console.log("🔴 Ensure all parameters are correct before proceeding\n");
    
    // Add a small delay for manual confirmation
    console.log("⏳ Starting deployment in 3 seconds...");
    await new Promise(resolve => setTimeout(resolve, 3000));
  }

  try {
    // =============================================================================
    // STEP 1: DEPLOY LIBRARIES
    // =============================================================================
    console.log("📚 Deploying libraries...");
    
    // Deploy LiquidityLib
    console.log("  📖 Deploying LiquidityLib...");
    const LiquidityLib = await ethers.deployContract("LiquidityLib", {
      gasLimit: isMainnet ? 2000000 : undefined // ✅ Gas limit for mainnet
    });
    await LiquidityLib.waitForDeployment();
    const liquidityLibAddress = await LiquidityLib.getAddress();
    console.log("  ✅ LiquidityLib deployed:", liquidityLibAddress);

    // Deploy TaxLib
    console.log("  📖 Deploying TaxLib...");
    const TaxLib = await ethers.deployContract("TaxLib", {
      gasLimit: isMainnet ? 2000000 : undefined
    });
    await TaxLib.waitForDeployment();
    const taxLibAddress = await TaxLib.getAddress();
    console.log("  ✅ TaxLib deployed:", taxLibAddress);

    // =============================================================================
    // STEP 2: DEPLOY MAIN TOKEN CONTRACT
    // =============================================================================
    console.log("\n🪙 Deploying MilliesToken...");
    
    const MilliesToken = await ethers.deployContract("MilliesToken", [ROUTER_ADDRESS], {
      gasLimit: isMainnet ? 6000000 : undefined // ✅ Higher gas limit for mainnet
    });
    await MilliesToken.waitForDeployment();
    const tokenAddress = await MilliesToken.getAddress();
    console.log("✅ MilliesToken deployed:", tokenAddress);

    // ✅ PRODUCTION: Verify basic token functionality
    console.log("🧪 Verifying token deployment...");
    const tokenName = await MilliesToken.name();
    const tokenSymbol = await MilliesToken.symbol();
    const totalSupply = await MilliesToken.totalSupply();
    const deployerBalance = await MilliesToken.balanceOf(deployer.address);
    
    console.log(`  📝 Name: ${tokenName}`);
    console.log(`  🔤 Symbol: ${tokenSymbol}`);
    console.log(`  💰 Total Supply: ${ethers.formatEther(totalSupply)}`);
    console.log(`  👤 Deployer Balance: ${ethers.formatEther(deployerBalance)}`);
    
    // Sanity checks
    if (deployerBalance !== totalSupply) {
      throw new Error("Deployer should have full supply");
    }
    if (tokenName !== "Millies" || tokenSymbol !== "MILLIES") {
      throw new Error("Token name/symbol mismatch");
    }

    // ✅ NEW: Check initial degraded mode status
    console.log("🔍 Checking initial system status...");
    try {
      const isDegraded = await MilliesToken.degradedMode();
      if (isDegraded) {
        console.log("⚠️  System deployed in degraded mode (no helper set yet)");
      } else {
        console.log("✅ System deployed in normal mode");
      }
    } catch (error) {
      console.log("⚠️  Could not check degraded mode status:", error.message);
    }

    // =============================================================================
    // STEP 3: DEPLOY HELPER CONTRACT
    // =============================================================================
    console.log("\n🔧 Deploying MilliesHelper...");
    
    const MilliesHelper = await ethers.deployContract("MilliesHelper", [tokenAddress], {
      libraries: {
        LiquidityLib: liquidityLibAddress,
        TaxLib: taxLibAddress,
      },
      gasLimit: isMainnet ? 6000000 : undefined
    });
    await MilliesHelper.waitForDeployment();
    const helperAddress = await MilliesHelper.getAddress();
    console.log("✅ MilliesHelper deployed:", helperAddress);

    // ✅ NEW: Verify helper contract functionality
    console.log("🧪 Verifying helper deployment...");
    try {
      const helperToken = await MilliesHelper.token();
      if (helperToken !== tokenAddress) {
        throw new Error("Helper contract token address mismatch");
      }
      console.log("✅ Helper contract linked to correct token");
    } catch (error) {
      console.log("❌ Helper verification failed:", error.message);
      throw error;
    }

    // =============================================================================
    // STEP 4: DEPLOY LENS CONTRACT
    // =============================================================================
    console.log("\n🔍 Deploying MilliesLens...");
    
    const MilliesLens = await ethers.deployContract("MilliesLens", [tokenAddress], {
      gasLimit: isMainnet ? 3000000 : undefined
    });
    await MilliesLens.waitForDeployment();
    const lensAddress = await MilliesLens.getAddress();
    console.log("✅ MilliesLens deployed:", lensAddress);

    // ✅ NEW: Test lens functionality
    console.log("🧪 Verifying lens deployment...");
    try {
      // Test basic lens functionality
      const totalBurned = await MilliesLens.getTotalBurned();
      console.log(`✅ Lens can read burned tokens: ${ethers.formatEther(totalBurned)}`);
      
      // Test degraded mode reporting
      const degradedInfo = await MilliesLens.getDegradedModeInfo();
      console.log(`✅ Lens degraded mode status: ${degradedInfo[0] ? 'Active' : 'Inactive'}`);
    } catch (error) {
      console.log("❌ Lens verification failed:", error.message);
      throw error;
    }

    // =============================================================================
    // STEP 5: CONTRACT SIZE VERIFICATION
    // =============================================================================
    console.log("\n📏 Verifying contract sizes (EIP-170 compliance)...");
    
    const tokenCode = await deployer.provider.getCode(tokenAddress);
    const helperCode = await deployer.provider.getCode(helperAddress);
    const lensCode = await deployer.provider.getCode(lensAddress);

    const tokenSize = (tokenCode.length - 2) / 2;
    const helperSize = (helperCode.length - 2) / 2;
    const lensSize = (lensCode.length - 2) / 2;

    console.log(`🏠 MilliesToken: ${tokenSize.toLocaleString()} bytes`);
    console.log(`🔧 MilliesHelper: ${helperSize.toLocaleString()} bytes`);
    console.log(`👁️  MilliesLens: ${lensSize.toLocaleString()} bytes`);

    // ✅ PRODUCTION: EIP-170 compliance check (24KB limit)
    const LIMIT = 24576;
    let sizeWarnings = 0;
    
    [
      { name: "MilliesToken", size: tokenSize },
      { name: "MilliesHelper", size: helperSize },
      { name: "MilliesLens", size: lensSize }
    ].forEach(contract => {
      if (contract.size <= LIMIT) {
        const remaining = LIMIT - contract.size;
        console.log(`✅ ${contract.name}: COMPLIANT (${remaining.toLocaleString()} bytes remaining)`);
      } else {
        const excess = contract.size - LIMIT;
        console.log(`❌ ${contract.name}: OVER LIMIT (${excess.toLocaleString()} bytes over)`);
        sizeWarnings++;
      }
    });

    if (sizeWarnings > 0) {
      console.log(`\n⚠️  WARNING: ${sizeWarnings} contract(s) exceed EIP-170 limit!`);
      if (isMainnet) {
        throw new Error("Cannot deploy oversized contracts to mainnet");
      }
    }

    // =============================================================================
    // STEP 6: BASIC INTEGRATION TEST
    // =============================================================================
    console.log("\n🧪 Running basic integration tests...");
    
    // Test helper contract connection
    console.log("  🔗 Testing helper contract integration...");
    try {
      const helperToken = await MilliesHelper.token();
      if (helperToken !== tokenAddress) {
        throw new Error("Helper contract token address mismatch");
      }
      console.log("  ✅ Helper integration verified");
    } catch (error) {
      console.log("  ❌ Helper integration failed:", error.message);
      throw error;
    }

    // Test lens contract integration
    console.log("  🔍 Testing lens contract integration...");
    try {
      const lensMetrics = await MilliesLens.getTokenMetrics();
      console.log(`  📊 Circulating supply: ${ethers.formatEther(lensMetrics[0])}`);
      console.log("  ✅ Lens integration verified");
    } catch (error) {
      console.log("  ❌ Lens integration failed:", error.message);
      throw error;
    }

    // ✅ NEW: Test system health check
    console.log("  🏥 Testing system health check...");
    try {
      const healthCheck = await MilliesLens.healthCheck();
      console.log(`  📈 System status: ${healthCheck[5]}`); // status string
      console.log(`  🔧 Helper responsive: ${healthCheck[1]}`);
      console.log(`  🚫 Degraded mode: ${healthCheck[3]}`);
      console.log("  ✅ Health check verified");
    } catch (error) {
      console.log("  ❌ Health check failed:", error.message);
      throw error;
    }

    // =============================================================================
    // STEP 7: DEPLOYMENT SUMMARY
    // =============================================================================
    console.log("\n" + "=".repeat(80));
    console.log("🎯 DEPLOYMENT COMPLETED SUCCESSFULLY!");
    console.log("=".repeat(80));
    console.log(`🌐 Network: ${isMainnet ? 'BSC Mainnet' : isTestnet ? 'BSC Testnet' : 'Localhost'}`);
    console.log(`🥞 Router: ${ROUTER_ADDRESS}`);
    console.log("=".repeat(80));
    console.log(`🏠 MilliesToken:  ${tokenAddress}`);
    console.log(`🔧 MilliesHelper: ${helperAddress}`);
    console.log(`👁️  MilliesLens:   ${lensAddress}`);
    console.log(`📚 LiquidityLib:  ${liquidityLibAddress}`);
    console.log(`📚 TaxLib:        ${taxLibAddress}`);
    console.log("=".repeat(80));

    // ✅ PRODUCTION: Mainnet-specific next steps
    if (isMainnet) {
      console.log("\n🚀 MAINNET DEPLOYMENT - CRITICAL NEXT STEPS:");
      console.log("1. 🔐 IMMEDIATELY verify contracts on BSCScan");
      console.log("2. 🔧 Run CompleteSetup.js to configure the system");
      console.log("3. 💰 Set advertising and community wallets");
      console.log("4. 🥞 Create PancakeSwap liquidity pool");
      console.log("5. 🔒 Lock liquidity on trusted platform");
      console.log("6. 🎯 Set LP address and complete setup");
      console.log("7. 📊 Test with small transactions first");
      console.log("8. 🔍 Monitor degraded mode status continuously");
      
      console.log("\n⚠️  SECURITY REMINDERS:");
      console.log("• Verify all addresses before sending large amounts");
      console.log("• Test buy/sell with small amounts first");
      console.log("• Monitor tax collection events");
      console.log("• Keep deployment private keys secure");
      console.log("• Monitor for degraded mode activation");
      
    } else {
      console.log("\n🧪 TESTNET DEPLOYMENT - NEXT STEPS:");
      console.log("1. 🔧 Run CompleteSetup.js to configure wallets");
      console.log("2. 🥞 Create testnet LP on PancakeSwap");
      console.log("3. 🧪 Test all tax scenarios thoroughly");
      console.log("4. 📊 Verify anti-bot features work correctly");
      console.log("5. 🔍 Test degraded mode activation/deactivation");
      console.log("6. 🚀 Deploy to mainnet when ready");
    }

    // Contract verification commands
    console.log("\n📋 CONTRACT VERIFICATION COMMANDS:");
    console.log("=".repeat(80));
    console.log("# Verify MilliesToken");
    console.log(`npx hardhat verify --network ${isMainnet ? 'bscMainnet' : 'bscTestnet'} ${tokenAddress} "${ROUTER_ADDRESS}"`);
    console.log("\n# Verify MilliesHelper");
    console.log(`npx hardhat verify --network ${isMainnet ? 'bscMainnet' : 'bscTestnet'} ${helperAddress} "${tokenAddress}"`);
    console.log("\n# Verify MilliesLens");
    console.log(`npx hardhat verify --network ${isMainnet ? 'bscMainnet' : 'bscTestnet'} ${lensAddress} "${tokenAddress}"`);
    console.log("\n# Verify Libraries");
    console.log(`npx hardhat verify --network ${isMainnet ? 'bscMainnet' : 'bscTestnet'} ${liquidityLibAddress}`);
    console.log(`npx hardhat verify --network ${isMainnet ? 'bscMainnet' : 'bscTestnet'} ${taxLibAddress}`);

    // ✅ NEW: Add degraded mode monitoring instructions
    console.log("\n🔍 DEGRADED MODE MONITORING:");
    console.log("=".repeat(80));
    console.log("# Check degraded mode status");
    console.log(`const token = await ethers.getContractAt("MilliesToken", "${tokenAddress}");`);
    console.log("const isDegraded = await token.degradedMode();");
    console.log("console.log('Degraded mode:', isDegraded);");
    console.log("\n# Health check via lens");
    console.log(`const lens = await ethers.getContractAt("MilliesLens", "${lensAddress}");`);
    console.log("const health = await lens.healthCheck();");
    console.log("console.log('System status:', health[5]);");
    console.log("\n# Deactivate degraded mode (if needed)");
    console.log("await token.deactivateDegradedMode(ethers.ZeroAddress);");

    console.log("\n✨ All contracts deployed successfully!");

    // Return deployment info for potential scripting
    return {
      network: isMainnet ? 'mainnet' : isTestnet ? 'testnet' : 'localhost',
      addresses: {
        milliesToken: tokenAddress,
        milliesHelper: helperAddress,
        milliesLens: lensAddress,
        liquidityLib: liquidityLibAddress,
        taxLib: taxLibAddress
      },
      router: ROUTER_ADDRESS,
      deployer: deployer.address
    };

  } catch (error) {
    console.error("\n💥 DEPLOYMENT FAILED:");
    console.error("❌", error.message);
    
    console.log("\n🔍 TROUBLESHOOTING:");
    console.log("1. Check BNB balance for gas fees");
    console.log("2. Verify network connectivity");
    console.log("3. Ensure private key is in .env file");
    console.log("4. Check contract size limits (EIP-170)");
    console.log("5. Verify router address is correct");
    console.log("6. Check for compilation errors");
    
    if (isMainnet) {
      console.log("\n🆘 MAINNET FAILURE - IMMEDIATE ACTIONS:");
      console.log("• Do NOT proceed with any token operations");
      console.log("• Verify deployment environment");
      console.log("• Check gas price and network congestion");
      console.log("• Consider deploying to testnet first");
      console.log("• Ensure all contracts compile without errors");
    }
    
    throw error;
  }
}

// Enhanced error handling for production
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n💥 CRITICAL DEPLOYMENT ERROR:");
    console.error(error);
    
    // ✅ Production error logging
    console.log("\n📝 Error Details:");
    console.log("Timestamp:", new Date().toISOString());
    console.log("Error Type:", error.constructor.name);
    if (error.stack) {
      console.log("Stack Trace:", error.stack);
    }
    
    process.exit(1);
  });