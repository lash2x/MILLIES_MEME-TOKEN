//fileName: Interfaces.sol - ENHANCED VERSION WITH DEGRADED MODE SUPPORT
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Interfaces
 * @dev Enhanced interfaces for MilliesToken ecosystem with degraded mode support
 * @notice Compatible with BSC mainnet PancakeSwap contracts
 */

// ✅ MAINNET COMPATIBLE: Standard PancakeSwap V2 Router interface (unchanged)
interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

// ✅ MAINNET COMPATIBLE: Standard PancakeSwap V2 Factory interface (unchanged)
interface IPancakeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// ✅ MAINNET COMPATIBLE: Standard PancakeSwap V2 Pair interface (unchanged)
interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

// ✅ ENHANCED: Updated MilliesHelper interface with new systems
interface IMilliesHelper {
    // Core functions (unchanged)
    function validateTransfer(address from, address to, uint256 amount) external;
    function processSell(address seller, uint256 amount) external returns (uint256);
    function processBuy(address buyer, uint256 amount) external returns (uint256);
    function updateLiquidity() external;
    function calculateTaxDistribution(address seller, uint256 amount) external view returns (uint256, uint256, uint256, uint256, bool);
    function isTradeTransaction(address from, address to) external view returns (bool isBuy, bool isSell);
    
    // Legacy view functions (adapted for compatibility)
    function getSellWindow(address account) external view returns (uint256, uint256, uint256, uint256, uint256);
    function getCooldownInfo(address account) external view returns (uint256, uint256, bool, uint256, bool);
    function getBuyInfo(address account) external view returns (uint256, uint256, uint256, uint256);
    
    // Financial tracking (unchanged)
    function totalTaxAccumulated() external view returns (uint256);
    function reservedLiquidityTokens() external view returns (uint256);
    function totalBurned() external view returns (uint256);
    function dailyTradingVolume() external view returns (uint256);
    function getLiquidityData() external view returns (uint256, uint256, uint256, uint256);
    function getTradingStats() external view returns (uint256, uint256, uint256, uint256, uint256);
    
    // NEW: Enhanced view functions for new systems
    function getIndividualSellWindow(address account) external view returns (
        uint256 totalSold,
        uint256 windowStart,
        uint256 cumulativeLPImpact,
        uint256 sellCount,
        uint256 timeRemaining
    );
    
    function getDistributorData(address account) external view returns (
        bool isDistributor,
        uint256 distributorFlagTime,
        uint256 transferCount,
        uint256 totalTransferred,
        uint256 recipientCount
    );
    
    function getWalletLineage(address account) external view returns (
        address parent,
        uint256 receivedTime,
        bool isClusterLinked,
        address rootDistributor
    );
    
    function getClusterSellData(address rootDistributor) external view returns (
        uint256 totalClusterSold,
        uint256 clusterWindowStart,
        uint256 cumulativeClusterLPImpact,
        uint256 clusterSellCount,
        bool isActive,
        uint256 timeRemaining
    );
}

// ✅ ENHANCED: Updated MilliesToken interface with degraded mode support
interface IMilliesToken {
    // Standard ERC20 functions
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    
    // Token specific functions
    function owner() external view returns (address);
    function liquidityPool() external view returns (address);
    function advertisingWallet() external view returns (address);
    function communityWallet() external view returns (address);
    function helperContract() external view returns (address);
    function pancakeRouter() external view returns (IUniswapV2Router02);
    
    // Feature flags
    function isExcludedFromFees(address account) external view returns (bool);
    function isExcludedFromCooldown(address account) external view returns (bool);
    function dumpSpikeDetectionEnabled() external view returns (bool);
    function sybilDefenseEnabled() external view returns (bool);
    function autoSwapAndLiquifyEnabled() external view returns (bool);
    function buyTaxEnabled() external view returns (bool);
    function tradingEnabled() external view returns (bool);
    function tradingEnabledTime() external view returns (uint256);
    
    // ✅ NEW: Degraded mode functions
    function degradedMode() external view returns (bool);
    function degradedModeActivated() external view returns (uint256);
    function activateDegradedMode(string calldata reason) external;
    function deactivateDegradedMode(address newHelper) external;
    function emergencyTransfer(address to, uint256 amount) external;
    
    // Legacy view functions (for compatibility)
    function getSellWindow(address account) external view returns (uint256, uint256, uint256, uint256, uint256);
    function getCooldownInfo(address account) external view returns (uint256, uint256, bool, uint256, bool);
    function getTotalBurned() external view returns (uint256);
    function totalTaxAccumulated() external view returns (uint256);
    function dailyTradingVolume() external view returns (uint256);
    function reservedLiquidityTokens() external view returns (uint256);
    
    // NEW: Enhanced view functions  
    function getIndividualSellWindow(address account) external view returns (uint256, uint256, uint256, uint256, uint256);
    function getDistributorData(address account) external view returns (bool, uint256, uint256, uint256, uint256);
    function getWalletLineage(address account) external view returns (address, uint256, bool, address);
    function getClusterSellData(address rootDistributor) external view returns (uint256, uint256, uint256, uint256, bool, uint256);
    function getAccountAnalysis(address account) external view returns (uint256, bool, bool, address, uint256, uint256, bool, bool);
    function getTaxConfiguration() external pure returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);
    
    // Status functions
    function isExcluded(address account) external view returns (bool, bool, bool);
    function getTradingStatus() external view returns (bool, uint256, uint256, uint256);
}

// ✅ NEW: TaxLib interface for external access
interface ITaxLib {
    // Structs (for reference - cannot be returned directly)
    // struct IndividualSellWindow { uint256 totalSold; uint256 windowStart; uint256 cumulativeLPImpact; uint256 sellCount; }
    // struct DistributorData { bool isDistributor; uint256 distributorFlagTime; uint256 transferCount; uint256 totalTransferred; uint256 lastTransferTime; address[] recipients; }
    // struct LineageData { address parent; uint256 receivedTime; bool isClusterLinked; address rootDistributor; }
    // struct ClusterSellData { uint256 totalClusterSold; uint256 clusterWindowStart; uint256 cumulativeClusterLPImpact; uint256 clusterSellCount; bool isActive; }
    
    enum TaxCategory { STANDARD, LIQUIDITY_IMPACT, INDIVIDUAL_SELL_LIMIT, CLUSTER_PENALTY, SYBIL_DEFENSE, OTHER }
    
    // Pure calculation functions
    function calculateLiquidityTax(uint256 sellAmount, uint256 liquidityBalance) external pure returns (uint256);
    function calculateProgressiveTax(uint256 cumulativeImpact) external pure returns (uint256);
    function calculateClusterTax(uint256 cumulativeClusterImpact) external pure returns (uint256);
    function calculateSybilTax(bool sybilDefenseEnabled, address seller, mapping(address => uint256) storage walletCreationTime) external view returns (uint256);
    
    // Configuration functions
    function getTaxConfiguration() external pure returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256);
    function validateTaxThresholds() external pure returns (bool);
    function taxCategoryToString(TaxCategory category) external pure returns (string memory);
    
    // Utility functions
    function safeMul(uint256 a, uint256 b) external pure returns (uint256);
    function safePercentage(uint256 amount, uint256 total) external pure returns (uint256);
}

// ✅ MilliesLens interface (enhanced with degraded mode support)
interface IMilliesLens {
    // Dashboard functions - ✅ UPDATED: Added degradedModeActive bool
    function dashboard() external view returns (
        uint256, uint256, uint256, uint256, uint256, uint256, uint256, 
        bool, uint256, uint256, uint256, uint256, uint256, uint256, bool  // ✅ Added bool for degradedMode
    );
    function getTokenMetrics() external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function getAutoSwapInfo() external view returns (bool, uint256, uint256, uint256, uint256, uint256);
    function getContractStats() external view returns (uint256, uint256, uint256, uint256, uint256, uint256);
    
    // Account analysis
    function getAccountInfo(address account) external view returns (uint256, bool, bool, bool, uint256, uint256, bool, uint256, bool);
    function getSellWindowInfo(address account) external view returns (uint256, uint256, uint256, uint256, uint256);
    function getBuyInfo(address account) external view returns (uint256, uint256, uint256, uint256);
    function getTradingInfo() external view returns (bool, uint256, uint256, uint256);
    function getTradingStats() external view returns (uint256, uint256, uint256, uint256, uint256, bool);
    
    // Utility functions
    function getTotalBurned() external view returns (uint256);
    function getTotalSupplyAfterBurn() external view returns (uint256);
    function getOwnerBalance() external view returns (uint256);
    function getMarketCapData() external view returns (uint256, uint256, address, uint256, bool);
    
    // ✅ UPDATED: Added degradedModeActive bool to healthCheck
    function healthCheck() external view returns (bool, bool, bool, bool, bool, string memory);
    
    // ✅ NEW: Degraded mode specific functions
    function getDegradedModeInfo() external view returns (bool, uint256, uint256, string memory);
}