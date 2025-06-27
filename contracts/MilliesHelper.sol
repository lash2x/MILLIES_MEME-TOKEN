//fileName: MilliesHelper.sol - ENHANCED VERSION WITH NEW SYSTEMS (NO DEGRADED MODE CHANGES NEEDED)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Interfaces.sol";
import "./TaxLib.sol";
import "./LiquidityLib.sol";

interface IMilliesToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
    function owner() external view returns (address);
    function liquidityPool() external view returns (address);
    function advertisingWallet() external view returns (address);
    function communityWallet() external view returns (address);
    function pancakeRouter() external view returns (IUniswapV2Router02);
    function isExcludedFromFees(address account) external view returns (bool);
    function isExcludedFromCooldown(address account) external view returns (bool);
    function dumpSpikeDetectionEnabled() external view returns (bool);
    function sybilDefenseEnabled() external view returns (bool);
    function autoSwapAndLiquifyEnabled() external view returns (bool);
    function buyTaxEnabled() external view returns (bool);
    function tradingEnabledTime() external view returns (uint256);
}

/**
 * @title MilliesHelper - Enhanced Version
 * @dev Comprehensive helper with individual sell tracking and cluster detection
 * @notice Implements whale dump protection and sophisticated lineage-based clustering
 * @notice NO DEGRADED MODE CHANGES NEEDED - Main token handles degraded mode logic
 */
contract MilliesHelper is Ownable, ReentrancyGuard {
    using TaxLib for TaxLib.IndividualSellWindow;
    using TaxLib for TaxLib.DistributorData;
    using TaxLib for TaxLib.LineageData;
    using TaxLib for TaxLib.ClusterSellData;
    using LiquidityLib for LiquidityLib.LiquidityData;

    // =============================================================================
    // CONSTANTS
    // =============================================================================

    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_TAX = 7500;
    uint256 private constant BUY_COOLDOWN = 30 seconds;
    
    // Standard tax rates (unchanged)
    uint256 private constant STANDARD_BURN_TAX = 50;   
    uint256 private constant STANDARD_LIQUIDITY_TAX = 500;
    uint256 private constant STANDARD_ADVERTISING_TAX = 150;
    uint256 private constant STANDARD_COMMUNITY_TAX = 5;    
    uint256 private constant TOTAL_STANDARD_TAX = 705;
    
    // Buy tax rates
    uint256 private constant BUY_TAX_RATE = 200; // 2%
    uint256 private constant EARLY_BUY_TAX_RATE = 500; // 5%

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // =============================================================================
    // STATE VARIABLES - ENHANCED WITH NEW SYSTEMS
    // =============================================================================

    IMilliesToken public immutable token;
    LiquidityLib.LiquidityData private liquidityData;

    // Basic trading controls (unchanged)
    mapping(address => uint256) public lastBuyTime;
    mapping(address => uint256) public lastBuyBlock;
    mapping(address => uint256) public lastSellTime;
    mapping(address => uint256) public sellCooldownEnd;

    // NEW: Individual sell tracking (replaces old 3-day rule)
    mapping(address => TaxLib.IndividualSellWindow) public individualSellWindows;

    // NEW: Distributor detection and tracking
    mapping(address => TaxLib.DistributorData) public distributorData;
    
    // NEW: Wallet lineage tracking
    mapping(address => TaxLib.LineageData) public walletLineage;
    
    // NEW: Cluster-wide sell tracking (keyed by root distributor)
    mapping(address => TaxLib.ClusterSellData) public clusterSellData;

    // Legacy systems (simplified)
    mapping(address => uint256) public walletCreationTime;

    // Buy tracking (unchanged)
    mapping(address => uint256) public totalBuyVolume;
    mapping(address => uint256) public buyCount;

    // Financial tracking (unchanged)
    uint256 public totalTaxAccumulated;
    uint256 public totalBuyTaxAccumulated;
    uint256 public reservedLiquidityTokens;
    uint256 public totalBurned;

    // Volume tracking (unchanged)
    uint256 public dailyTradingVolume;
    uint256 public lastVolumeResetTime;

    // =============================================================================
    // EVENTS - ENHANCED FOR NEW SYSTEMS
    // =============================================================================

    event SellProcessed(address indexed seller, uint256 amount, uint256 taxRate, uint256 netAmount, TaxLib.TaxCategory reason, uint256 timestamp);
    event BuyProcessed(address indexed buyer, uint256 amount, uint256 taxRate, uint256 netAmount, uint256 timestamp);
    event CooldownApplied(address indexed wallet, uint256 cooldownEnd, string reason, uint256 timestamp);
    
    // NEW: Enhanced events for new systems
    event DistributorDetected(address indexed distributor, uint256 recipients, uint256 totalTransferred, uint256 timestamp);
    event LineageTracked(address indexed wallet, address indexed parent, address indexed rootDistributor, uint256 timestamp);
    event ClusterSellTracked(address indexed rootDistributor, address indexed seller, uint256 amount, uint256 clusterTotal, uint256 timestamp);
    event IndividualSellTracked(address indexed seller, uint256 amount, uint256 windowTotal, uint256 cumulativeImpact, uint256 timestamp);
    event TradeTypeDetected(address indexed from, address indexed to, bool isBuy, bool isSell, string reason, uint256 timestamp);

    // =============================================================================
    // CUSTOM ERRORS
    // =============================================================================
    
    error OnlyTokenContract();
    error BuyTaxDisabled();
    error InsufficientBalance(uint256 requested, uint256 available);

    // =============================================================================
    // CONSTRUCTOR
    // =============================================================================

    constructor(address _token) {
        require(_token != address(0), "Invalid token address");
        token = IMilliesToken(_token);
        lastVolumeResetTime = block.timestamp;
        liquidityData.lastTWAPUpdate = block.timestamp;
        liquidityData.lastTWAPBlock = block.number;
    }

    // =============================================================================
    // ENHANCED TRADE DETECTION (UNCHANGED)
    // =============================================================================

    function isTradeTransaction(address from, address to) external view returns (bool isBuy, bool isSell) {
        address liquidityPool = token.liquidityPool();
        IUniswapV2Router02 router = token.pancakeRouter();
        
        if (liquidityPool == address(0)) {
            return (false, false);
        }
        
        // Direct LP trades
        if (from == liquidityPool) {
            return (true, false); // Buy
        }
        
        if (to == liquidityPool) {
            return (false, true); // Sell
        }
        
        // Router-mediated trades
        if (address(router) != address(0)) {
            address routerAddr = address(router);
            bool fromExcluded = token.isExcludedFromFees(from);
            bool toExcluded = token.isExcludedFromFees(to);
            
            if (from == routerAddr && !toExcluded) {
                return (true, false); // Buy
            }
            
            if (to == routerAddr && !fromExcluded) {
                return (false, true); // Sell
            }
        }
        
        (bool multiHopBuy, bool multiHopSell) = _detectMultiHopTrades(from, to, liquidityPool, address(router));
        if (multiHopBuy || multiHopSell) {
            return (multiHopBuy, multiHopSell);
        }
        
        return (false, false);
    }

    function _detectMultiHopTrades(
        address from, 
        address to, 
        address liquidityPool, 
        address router
    ) internal view returns (bool isBuy, bool isSell) {
        bool fromIsTrader = !token.isExcludedFromFees(from) && from != liquidityPool && from != router;
        bool toIsTrader = !token.isExcludedFromFees(to) && to != liquidityPool && to != router;
        
        if (fromIsTrader && (to == liquidityPool || to == router)) {
            return (false, true);
        }
        
        if (toIsTrader && (from == liquidityPool || from == router)) {
            return (true, false);
        }
        
        return (false, false);
    }

    // =============================================================================
    // ENHANCED VALIDATION WITH NEW SYSTEMS
    // =============================================================================

    function validateTransfer(address from, address to, uint256 amount) external {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        
        address liquidityPool = token.liquidityPool();
        bool fromExcludedCooldown = token.isExcludedFromCooldown(from);
        bool toExcludedCooldown = token.isExcludedFromCooldown(to);
        bool toExcludedFees = token.isExcludedFromFees(to);
        bool fromExcludedFees = token.isExcludedFromFees(from);

        // Skip validation for excluded addresses
        if (fromExcludedCooldown || toExcludedCooldown) {
            return;
        }

        // Enhanced trade detection
        (bool isBuy, bool isSell) = this.isTradeTransaction(from, to);
        
        // Buy validation (unchanged)
        if (isBuy && !toExcludedFees) {
            require(block.number > lastBuyBlock[to], "One buy per block");
            lastBuyBlock[to] = block.number;

            require(
                block.timestamp >= lastBuyTime[to] + BUY_COOLDOWN &&
                block.timestamp >= lastBuyTime[tx.origin] + BUY_COOLDOWN,
                "Buy cooldown active"
            );
            lastBuyTime[to] = block.timestamp;
            if (to != tx.origin) {
                lastBuyTime[tx.origin] = block.timestamp;
            }
        }

        // Sell cooldown enforcement
        if (sellCooldownEnd[from] > block.timestamp) {
            revert("Sell cooldown active");
        }

        // Track wallet creation time
        if (walletCreationTime[to] == 0 && to != liquidityPool && !toExcludedFees) {
            walletCreationTime[to] = block.timestamp;
        }

        // NEW: Enhanced transfer tracking for distributor detection
        if (!isBuy && !isSell && // Regular transfers (not trades)
            !fromExcludedFees && !toExcludedFees &&
            amount > 0) {
            
            // Update distributor tracking for sender
            uint256 liquidityBalance = liquidityData.liquidityPoolBalance;
            bool becameDistributor = TaxLib.updateDistributorTracking(
                distributorData[from],
                to,
                amount,
                liquidityBalance
            );
            
            if (becameDistributor) {
                emit DistributorDetected(
                    from, 
                    distributorData[from].recipients.length,
                    distributorData[from].totalTransferred,
                    block.timestamp
                );
            }
            
            // NEW: Update lineage tracking for recipient
            TaxLib.updateWalletLineage(
                walletLineage[to],
                from,
                distributorData
            );
            
            if (walletLineage[to].isClusterLinked) {
                emit LineageTracked(
                    to,
                    from,
                    walletLineage[to].rootDistributor,
                    block.timestamp
                );
            }
        }

        // Update daily volume for trades
        if ((isBuy || isSell) && !fromExcludedFees && !toExcludedFees) {
            _updateDailyVolume(amount);
        }
    }

    // =============================================================================
    // BUY PROCESSING (UNCHANGED)
    // =============================================================================

    function processBuy(address buyer, uint256 amount) external nonReentrant returns (uint256) {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        if (!token.buyTaxEnabled()) revert BuyTaxDisabled();
        
        uint256 taxRate = BUY_TAX_RATE;
        
        uint256 tradingEnabledTime = token.tradingEnabledTime();
        if (tradingEnabledTime > 0 && block.timestamp < tradingEnabledTime + 1 days) {
            taxRate = EARLY_BUY_TAX_RATE;
        }
        
        uint256 taxAmount = (amount * taxRate) / BASIS_POINTS;
        uint256 transferAmount = amount - taxAmount;
        
        totalBuyVolume[buyer] += amount;
        buyCount[buyer] += 1;
        totalBuyTaxAccumulated += taxAmount;
        lastBuyTime[buyer] = block.timestamp;
        
        emit BuyProcessed(buyer, amount, taxRate, transferAmount, block.timestamp);
        
        return transferAmount;
    }

    // =============================================================================
    // ENHANCED SELL PROCESSING WITH NEW SYSTEMS
    // =============================================================================

    function processSell(address seller, uint256 amount) external nonReentrant returns (uint256) {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        
        uint256 preSellBalance = token.balanceOf(seller);
        if (preSellBalance < amount) revert InsufficientBalance(amount, preSellBalance);

        uint256 liquidityBalance = liquidityData.liquidityPoolBalance;
        
        // NEW: Update individual sell window (replaces old 3-day rule)
        uint256 individualTax = TaxLib.updateIndividualSellWindow(
            individualSellWindows[seller],
            amount,
            liquidityBalance
        );
        
        emit IndividualSellTracked(
            seller,
            amount,
            individualSellWindows[seller].totalSold,
            individualSellWindows[seller].cumulativeLPImpact,
            block.timestamp
        );

        // NEW: Check if seller is part of a cluster
        (address rootDistributor, bool isClusterMember) = TaxLib.traceLineageToRoot(
            seller,
            walletLineage,
            distributorData
        );
        
        uint256 clusterTax = 0;
        if (isClusterMember && rootDistributor != address(0)) {
            // Update cluster sell tracking
            clusterTax = TaxLib.updateClusterSellTracking(
                clusterSellData[rootDistributor],
                amount,
                liquidityBalance
            );
            
            emit ClusterSellTracked(
                rootDistributor,
                seller,
                amount,
                clusterSellData[rootDistributor].totalClusterSold,
                block.timestamp
            );
        }

        // Calculate comprehensive tax
        (
            uint256 finalTaxRate,
            TaxLib.TaxCategory taxCategory,
            uint256 liquidityTax,
            uint256 individualTaxCalc,
            uint256 clusterTaxCalc,
            uint256 sybilTax
        ) = TaxLib.calculateComprehensiveTax(
            amount,
            liquidityBalance,
            individualSellWindows[seller],
            isClusterMember,
            clusterSellData[rootDistributor],
            token.sybilDefenseEnabled(),
            token.dumpSpikeDetectionEnabled(),
            seller,
            walletCreationTime
        );

        // Cap tax at maximum
        if (finalTaxRate > MAX_TAX) {
            finalTaxRate = MAX_TAX;
        }
        
        // Apply minimum standard tax if no other tax applies
        if (finalTaxRate == 0) {
            finalTaxRate = TOTAL_STANDARD_TAX;
            taxCategory = TaxLib.TaxCategory.STANDARD;
        }

        // Calculate final amounts
        uint256 taxAmount = (amount * finalTaxRate) / BASIS_POINTS;
        uint256 transferAmount = amount - taxAmount;

        // Update state
        lastSellTime[seller] = block.timestamp;
        totalTaxAccumulated += taxAmount;

        emit SellProcessed(seller, amount, finalTaxRate, transferAmount, taxCategory, block.timestamp);

        return transferAmount;
    }

    /**
     * @dev Enhanced tax distribution calculation 
     */
    function calculateTaxDistribution(
        address seller, 
        uint256 amount
    ) external view returns (uint256 burnAmount, uint256 advertisingAmount, uint256 liquidityAmount, uint256 communityAmount, bool isHighImpact) {
        bool dumpSpikeEnabled = token.dumpSpikeDetectionEnabled();
        bool sybilEnabled = token.sybilDefenseEnabled();
        
        uint256 liquidityBalance = liquidityData.liquidityPoolBalance;
        
        // Check if seller is part of cluster
        (address rootDistributor, bool isClusterMember) = TaxLib.traceLineageToRoot(
            seller,
            walletLineage,
            distributorData
        );

        // Calculate comprehensive tax
        (
            uint256 finalTaxRate,
            TaxLib.TaxCategory taxCategory,
            ,,,
        ) = TaxLib.calculateComprehensiveTax(
            amount,
            liquidityBalance,
            individualSellWindows[seller],
            isClusterMember,
            clusterSellData[rootDistributor],
            sybilEnabled,
            dumpSpikeEnabled,
            seller,
            walletCreationTime
        );

        // Determine if high impact
        isHighImpact = (taxCategory == TaxLib.TaxCategory.LIQUIDITY_IMPACT ||
                       taxCategory == TaxLib.TaxCategory.INDIVIDUAL_SELL_LIMIT ||
                       taxCategory == TaxLib.TaxCategory.CLUSTER_PENALTY);

        // Apply minimum tax if needed
        if (finalTaxRate == 0) {
            finalTaxRate = TOTAL_STANDARD_TAX;
        }
        if (finalTaxRate > MAX_TAX) {
            finalTaxRate = MAX_TAX;
        }

        uint256 taxAmount = (amount * finalTaxRate) / BASIS_POINTS;
        
        // Tax distribution
        burnAmount = (taxAmount * STANDARD_BURN_TAX) / TOTAL_STANDARD_TAX;
        
        if (isHighImpact) {
            // High impact: All non-burn tax goes to LP
            liquidityAmount = taxAmount - burnAmount;
            advertisingAmount = 0;
            communityAmount = 0;
        } else {
            // Standard distribution
            advertisingAmount = (taxAmount * STANDARD_ADVERTISING_TAX) / TOTAL_STANDARD_TAX;
            liquidityAmount = (taxAmount * STANDARD_LIQUIDITY_TAX) / TOTAL_STANDARD_TAX;
            communityAmount = (taxAmount * STANDARD_COMMUNITY_TAX) / TOTAL_STANDARD_TAX;
        }
        
        return (burnAmount, advertisingAmount, liquidityAmount, communityAmount, isHighImpact);
    }

    // =============================================================================
    // LIQUIDITY MANAGEMENT (UNCHANGED)
    // =============================================================================

    function updateLiquidity() external {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        address liquidityPool = token.liquidityPool();
        if (liquidityPool != address(0)) {
            liquidityData.updatePoolBalance(liquidityPool, address(token));
        }
    }

    function _updateDailyVolume(uint256 amount) private {
        unchecked {
            if (block.timestamp >= lastVolumeResetTime + 1 days) {
                dailyTradingVolume = amount;
                lastVolumeResetTime = block.timestamp;
            } else {
                dailyTradingVolume += amount;
            }
        }
    }

    // =============================================================================
    // ENHANCED VIEW FUNCTIONS
    // =============================================================================

    function getIndividualSellWindow(address account) external view returns (
        uint256 totalSold,
        uint256 windowStart,
        uint256 cumulativeLPImpact,
        uint256 sellCount,
        uint256 timeRemaining
    ) {
        TaxLib.IndividualSellWindow memory window = individualSellWindows[account];
        uint256 timeLeft = 0;
        if (window.windowStart > 0 && block.timestamp < window.windowStart + 72 hours) {
            timeLeft = (window.windowStart + 72 hours) - block.timestamp;
        }
        return (
            window.totalSold,
            window.windowStart,
            window.cumulativeLPImpact,
            window.sellCount,
            timeLeft
        );
    }

    function getDistributorData(address account) external view returns (
        bool isDistributor,
        uint256 distributorFlagTime,
        uint256 transferCount,
        uint256 totalTransferred,
        uint256 recipientCount
    ) {
        TaxLib.DistributorData memory data = distributorData[account];
        return (
            data.isDistributor,
            data.distributorFlagTime,
            data.transferCount,
            data.totalTransferred,
            data.recipients.length
        );
    }

    function getWalletLineage(address account) external view returns (
        address parent,
        uint256 receivedTime,
        bool isClusterLinked,
        address rootDistributor
    ) {
        TaxLib.LineageData memory lineage = walletLineage[account];
        return (
            lineage.parent,
            lineage.receivedTime,
            lineage.isClusterLinked,
            lineage.rootDistributor
        );
    }

    function getClusterSellData(address rootDistributor) external view returns (
        uint256 totalClusterSold,
        uint256 clusterWindowStart,
        uint256 cumulativeClusterLPImpact,
        uint256 clusterSellCount,
        bool isActive,
        uint256 timeRemaining
    ) {
        TaxLib.ClusterSellData memory data = clusterSellData[rootDistributor];
        uint256 timeLeft = 0;
        if (data.isActive && data.clusterWindowStart > 0 && 
            block.timestamp < data.clusterWindowStart + 35 days) {
            timeLeft = (data.clusterWindowStart + 35 days) - block.timestamp;
        }
        return (
            data.totalClusterSold,
            data.clusterWindowStart,
            data.cumulativeClusterLPImpact,
            data.clusterSellCount,
            data.isActive,
            timeLeft
        );
    }

    // Legacy view functions (adapted)
    function getSellWindow(address account) external view returns (
        uint256 totalSold,
        uint256 windowStart,
        uint256 initialHoldings,
        uint256 sellCount,
        uint256 timeRemaining
    ) {
        // Adapt to new individual sell window
        (uint256 sold, uint256 start, , uint256 count, uint256 remaining) = this.getIndividualSellWindow(account);
        return (sold, start, 0, count, remaining); // initialHoldings no longer tracked
    }

    function getCooldownInfo(address account) external view returns (
        uint256 sellCooldownEndTimestamp,
        uint256 timeRemaining,
        bool canSell,
        uint256 lastBuy,
        bool canBuy
    ) {
        uint256 cooldownEnd = sellCooldownEnd[account];
        uint256 timeLeft = (cooldownEnd > block.timestamp) ? cooldownEnd - block.timestamp : 0;
        bool sellAllowed = (block.timestamp >= cooldownEnd);
        uint256 lastBuyLocal = lastBuyTime[account];
        bool buyAllowed = (block.timestamp >= lastBuyLocal + BUY_COOLDOWN);

        return (cooldownEnd, timeLeft, sellAllowed, lastBuyLocal, buyAllowed);
    }

    function getBuyInfo(address account) external view returns (
        uint256 totalBought,
        uint256 buyCountTotal,
        uint256 lastBuyTimestamp,
        uint256 averageBuySize
    ) {
        uint256 totalVol = totalBuyVolume[account];
        uint256 count = buyCount[account];
        uint256 avgSize = count > 0 ? totalVol / count : 0;
        
        return (totalVol, count, lastBuyTime[account], avgSize);
    }

    function getLiquidityData() external view returns (
        uint256 liquidityPoolBalance,
        uint256 liquidityPoolBalanceTWAP,
        uint256 lastTWAPUpdate,
        uint256 lastTWAPBlock
    ) {
        return (
            liquidityData.liquidityPoolBalance,
            liquidityData.liquidityPoolBalanceTWAP,
            liquidityData.lastTWAPUpdate,
            liquidityData.lastTWAPBlock
        );
    }

    function getTradingStats() external view returns (
        uint256 totalSellTax,
        uint256 totalBuyTax,
        uint256 dailyVolume,
        uint256 reservedTokens,
        uint256 lastVolumeReset
    ) {
        return (
            totalTaxAccumulated,
            totalBuyTaxAccumulated,
            dailyTradingVolume,
            reservedLiquidityTokens,
            lastVolumeResetTime
        );
    }

    // =============================================================================
    // ADMIN FUNCTIONS - ENHANCED FOR NEW SYSTEMS
    // =============================================================================

    function clearSellCooldown(address account) external onlyOwner {
        require(sellCooldownEnd[account] > block.timestamp, "No active cooldown");
        sellCooldownEnd[account] = 0;
        emit CooldownApplied(account, 0, "owner_cleared", block.timestamp);
    }

    function clearDistributorFlag(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        delete distributorData[account];
        emit DistributorDetected(account, 0, 0, block.timestamp);
    }

    function clearWalletLineage(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        delete walletLineage[account];
        emit LineageTracked(account, address(0), address(0), block.timestamp);
    }

    function clearClusterData(address rootDistributor) external onlyOwner {
        require(rootDistributor != address(0), "Invalid address");
        delete clusterSellData[rootDistributor];
        emit ClusterSellTracked(rootDistributor, address(0), 0, 0, block.timestamp);
    }

    function resetIndividualSellWindow(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        delete individualSellWindows[account];
        emit IndividualSellTracked(account, 0, 0, 0, block.timestamp);
    }

    function batchClearCooldowns(address[] calldata accounts) external onlyOwner {
        unchecked {
            for (uint256 i = 0; i < accounts.length; i++) {
                if (sellCooldownEnd[accounts[i]] > block.timestamp) {
                    sellCooldownEnd[accounts[i]] = 0;
                    emit CooldownApplied(accounts[i], 0, "batch_cleared", block.timestamp);
                }
            }
        }
    }
}