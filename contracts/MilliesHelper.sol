//fileName: MilliesHelper.sol - SECURITY FIXED VERSION
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // FIXED: L1 - Use fixed pragma instead of floating

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
 * @title MilliesHelper
 * @dev Production-ready helper contract with enhanced trade detection and security
 * @notice Mainnet deployment with comprehensive anti-bot features and gas optimizations - SECURITY FIXED VERSION
 */
contract MilliesHelper is Ownable, ReentrancyGuard {
    using TaxLib for TaxLib.SellWindow;
    using LiquidityLib for LiquidityLib.LiquidityData;

    // =============================================================================
    // CONSTANTS - PRODUCTION TUNED
    // =============================================================================

    uint256 private constant BASIS_POINTS = 10000;
    uint256 private constant MAX_TAX = 7500;
    uint256 private constant BUY_COOLDOWN = 30 seconds;
    uint256 private constant THREE_DAYS = 3 days;
    uint256 private constant SEVEN_DAYS = 7 days;
    
    // Standard tax rates (in basis points)
    uint256 private constant STANDARD_BURN_TAX = 50;   // 7% of tax = ~0.5% of sell
    uint256 private constant STANDARD_LIQUIDITY_TAX = 500;
    uint256 private constant STANDARD_ADVERTISING_TAX = 150;
    uint256 private constant STANDARD_COMMUNITY_TAX = 5;    // Reduced to maintain 705 total
    uint256 private constant TOTAL_STANDARD_TAX = 705;
    
    // Buy tax rates
    uint256 private constant BUY_TAX_RATE = 200; // 2% default buy tax
    uint256 private constant EARLY_BUY_TAX_RATE = 500; // 5% for early buyers (first 24h)

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    IMilliesToken public immutable token;
    LiquidityLib.LiquidityData private liquidityData;

    // Trading controls - Gas optimized storage layout
    mapping(address => uint256) public lastBuyTime;
    mapping(address => uint256) public lastBuyBlock;
    mapping(address => uint256) public lastSellTime;
    mapping(address => uint256) public sellCooldownEnd;

    // Sell tracking
    mapping(address => TaxLib.SellWindow) public sellWindows;
    mapping(address => uint256) public totalSellVolume;

    // Buy tracking
    mapping(address => uint256) public totalBuyVolume;
    mapping(address => uint256) public buyCount;

    // Sybil defense
    mapping(address => address) public walletClusters;
    mapping(address => uint256) public walletCreationTime;

    // Financial tracking
    uint256 public totalTaxAccumulated;
    uint256 public totalBuyTaxAccumulated;
    uint256 public reservedLiquidityTokens;
    uint256 public totalBurned;

    // Volume tracking
    uint256 public dailyTradingVolume;
    uint256 public lastVolumeResetTime;

    // =============================================================================
    // EVENTS - ENHANCED FOR PRODUCTION MONITORING
    // =============================================================================

    event TaxCollected(address indexed from, address indexed to, uint256 amount, string indexed taxType, uint256 timestamp);
    event SellProcessed(address indexed seller, uint256 amount, uint256 taxRate, uint256 netAmount, TaxLib.TaxCategory reason, uint256 timestamp);
    event BuyProcessed(address indexed buyer, uint256 amount, uint256 taxRate, uint256 netAmount, uint256 timestamp);
    event CooldownApplied(address indexed wallet, uint256 cooldownEnd, string reason, uint256 timestamp);
    event WalletClusterDetected(address indexed wallet, address indexed clusterParent, uint256 timestamp);
    event TradeTypeDetected(address indexed from, address indexed to, bool isBuy, bool isSell, string reason, uint256 timestamp);

    // =============================================================================
    // CUSTOM ERRORS - FIXED: Add for better error handling
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
    // ENHANCED TRADE DETECTION - FIXED: M2 - Trade detection bug fix
    // =============================================================================

    /**
     * @dev Comprehensive trade detection for mainnet PancakeSwap
     * FIXED: M2 - Properly handle return values from multi-hop detection
     */
    function isTradeTransaction(address from, address to) external view returns (bool isBuy, bool isSell) {
        // Cache frequently accessed values
        address liquidityPool = token.liquidityPool();
        IUniswapV2Router02 router = token.pancakeRouter();
        
        // Early return if no LP set
        if (liquidityPool == address(0)) {
            return (false, false);
        }
        
        // Method 1: Direct LP trades (most common, check first)
        if (from == liquidityPool) {
            return (true, false); // Buy: LP → User
        }
        
        if (to == liquidityPool) {
            return (false, true); // Sell: User → LP
        }
        
        // Method 2: Router-mediated trades (PancakeSwap standard)
        if (address(router) != address(0)) {
            address routerAddr = address(router);
            
            // Batch exclusion checks to reduce external calls
            bool fromExcluded = token.isExcludedFromFees(from);
            bool toExcluded = token.isExcludedFromFees(to);
            
            // Buy: Router → User (router buying from LP and sending to user)
            if (from == routerAddr && !toExcluded) {
                return (true, false);
            }
            
            // Sell: User → Router (user selling to router, router will send to LP)
            if (to == routerAddr && !fromExcluded) {
                return (false, true);
            }
        }
        
        // FIXED: Method 3 - Use return values from multi-hop detection
        (bool multiHopBuy, bool multiHopSell) = _detectMultiHopTrades(from, to, liquidityPool, address(router));
        if (multiHopBuy || multiHopSell) {
            return (multiHopBuy, multiHopSell);
        }
        
        return (false, false);
    }

    // FIXED: Internal function to properly detect multi-hop trades
    function _detectMultiHopTrades(
        address from, 
        address to, 
        address liquidityPool, 
        address router
    ) internal view returns (bool isBuy, bool isSell) {
        bool fromIsTrader = !token.isExcludedFromFees(from) && from != liquidityPool && from != router;
        bool toIsTrader = !token.isExcludedFromFees(to) && to != liquidityPool && to != router;
        
        // Sell pattern: Regular wallet → System component
        if (fromIsTrader && (to == liquidityPool || to == router)) {
            return (false, true);
        }
        
        // Buy pattern: System component → Regular wallet  
        if (toIsTrader && (from == liquidityPool || from == router)) {
            return (true, false);
        }
        
        return (false, false);
    }

    // =============================================================================
    // VALIDATION FUNCTIONS - ENHANCED SECURITY
    // =============================================================================

    function validateTransfer(address from, address to, uint256 amount) external {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        
        // Cache values to reduce SLOAD operations
        address liquidityPool = token.liquidityPool();
        bool fromExcludedCooldown = token.isExcludedFromCooldown(from);
        bool toExcludedCooldown = token.isExcludedFromCooldown(to);
        bool toExcludedFees = token.isExcludedFromFees(to);

        // Skip validation for excluded addresses
        if (fromExcludedCooldown || toExcludedCooldown) {
            return;
        }

        // Enhanced trade detection
        (bool isBuy, bool isSell) = this.isTradeTransaction(from, to);
        
        // Buy validation with enhanced security
        if (isBuy && !toExcludedFees) {
            // One buy per block protection
            require(block.number > lastBuyBlock[to], "One buy per block");
            lastBuyBlock[to] = block.number;

            // 30-second cooldown with tx.origin protection
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

        // Track wallet creation time for sybil detection
        if (walletCreationTime[to] == 0 && to != liquidityPool && !toExcludedFees) {
            walletCreationTime[to] = block.timestamp;
        }

        // Enhanced sybil clustering detection
        bool isClusterCandidate = (
            !isBuy && !isSell && // Regular transfers, not trades
            !token.isExcludedFromFees(from) && !toExcludedFees &&
            walletCreationTime[to] != 0 &&
            walletCreationTime[to] > block.timestamp - SEVEN_DAYS &&
            lastSellTime[from] > block.timestamp - SEVEN_DAYS
        );
        
        if (token.sybilDefenseEnabled() && isClusterCandidate && walletClusters[to] == address(0)) {
            walletClusters[to] = from;
            emit WalletClusterDetected(to, from, block.timestamp);
        }

        // Update daily volume for trades
        if ((isBuy || isSell) && !token.isExcludedFromFees(from) && !toExcludedFees) {
            _updateDailyVolume(amount);
        }
    }

    // =============================================================================
    // BUY PROCESSING - PRODUCTION READY
    // =============================================================================

    /**
     * @dev Enhanced buy processing with early buyer penalties
     */
    function processBuy(address buyer, uint256 amount) external nonReentrant returns (uint256) {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        if (!token.buyTaxEnabled()) revert BuyTaxDisabled();
        
        // Calculate buy tax rate with early buyer penalty
        uint256 taxRate = BUY_TAX_RATE;
        
        // Early buyer penalty (first 24 hours after trading enabled)
        uint256 tradingEnabledTime = token.tradingEnabledTime();
        if (tradingEnabledTime > 0 && block.timestamp < tradingEnabledTime + 1 days) {
            taxRate = EARLY_BUY_TAX_RATE;
        }
        
        // Calculate amounts with overflow protection
        uint256 taxAmount = (amount * taxRate) / BASIS_POINTS;
        uint256 transferAmount = amount - taxAmount;
        
        // Update state before external interactions
        totalBuyVolume[buyer] += amount;
        buyCount[buyer] += 1;
        totalBuyTaxAccumulated += taxAmount;
        lastBuyTime[buyer] = block.timestamp;
        
        emit BuyProcessed(buyer, amount, taxRate, transferAmount, block.timestamp);
        
        return transferAmount;
    }

    // =============================================================================
    // SELL PROCESSING - ENHANCED SECURITY
    // =============================================================================

    /**
     * @dev Enhanced sell processing with proper reentrancy protection
     */
    function processSell(address seller, uint256 amount) external nonReentrant returns (uint256) {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        
        uint256 preSellBalance = token.balanceOf(seller);
        if (preSellBalance < amount) revert InsufficientBalance(amount, preSellBalance);

        // Update 3-day sell window (gas optimized)
        sellWindows[seller].update3DaySellWindow(amount, preSellBalance);

        // Cache tax rates to reduce redundant calculations
        uint256 standardRate = TOTAL_STANDARD_TAX;
        uint256 liquidityRate = 0;
        uint256 threeDayRate = TaxLib.calculate3DayTax(sellWindows[seller], 0);
        uint256 sybilRate = TaxLib.calculateSybilTax(
            token.sybilDefenseEnabled(),
            seller,
            walletClusters,
            walletCreationTime
        );

        // Calculate liquidity-based tax if dump spike detection enabled
        if (token.dumpSpikeDetectionEnabled()) {
            uint256 effectiveBalance = liquidityData.liquidityPoolBalanceTWAP > 0 
                ? liquidityData.liquidityPoolBalanceTWAP 
                : liquidityData.liquidityPoolBalance;
            liquidityRate = TaxLib.calculateLiquidityTax(amount, effectiveBalance);
        }

        // Determine final tax rate and category
        uint256 baseRate = standardRate;
        TaxLib.TaxCategory taxCategory = TaxLib.TaxCategory.STANDARD;
        
        if (liquidityRate > baseRate) {
            baseRate = liquidityRate;
            taxCategory = TaxLib.TaxCategory.LIQUIDITY_IMPACT;
        }
        if (threeDayRate > baseRate) {
            baseRate = threeDayRate;
            taxCategory = TaxLib.TaxCategory.THREE_DAY_RULE;
        }

        uint256 taxRate = baseRate + sybilRate;
        if (sybilRate > 0) {
            taxCategory = TaxLib.TaxCategory.SYBIL_DEFENSE;
        }
        if (taxRate == 0) {
            taxRate = standardRate;
            taxCategory = TaxLib.TaxCategory.STANDARD;
        }
        if (taxRate > MAX_TAX) {
            taxRate = MAX_TAX;
        }

        // Calculate amounts
        uint256 taxAmount = (amount * taxRate) / BASIS_POINTS;
        uint256 transferAmount = amount - taxAmount;

        // Update state before emitting events
        lastSellTime[seller] = block.timestamp;
        totalSellVolume[seller] += amount;
        totalTaxAccumulated += taxAmount;

        emit SellProcessed(seller, amount, taxRate, transferAmount, taxCategory, block.timestamp);

        return transferAmount;
    }

    /**
     * @dev Gas optimized tax distribution calculation - FIXED TO MATCH WHITEPAPER
     */
    function calculateTaxDistribution(
        address seller, 
        uint256 amount
    ) external view returns (uint256 burnAmount, uint256 advertisingAmount, uint256 liquidityAmount, uint256 communityAmount, bool isHighImpact) {
        // Cache frequently accessed values
        bool dumpSpikeEnabled = token.dumpSpikeDetectionEnabled();
        bool sybilEnabled = token.sybilDefenseEnabled();
        
        // Calculate tax rates using optimized logic
        uint256 standardRate = TOTAL_STANDARD_TAX;
        uint256 liquidityRate = 0;
        uint256 threeDayRate = TaxLib.calculate3DayTax(sellWindows[seller], amount);
        uint256 sybilRate = TaxLib.calculateSybilTax(
            sybilEnabled,
            seller,
            walletClusters,
            walletCreationTime
        );

        if (dumpSpikeEnabled) {
            uint256 effectiveBalance = liquidityData.liquidityPoolBalanceTWAP > 0 
                ? liquidityData.liquidityPoolBalanceTWAP 
                : liquidityData.liquidityPoolBalance;
            liquidityRate = TaxLib.calculateLiquidityTax(amount, effectiveBalance);
        }

        // Determine final tax rate and impact level
        uint256 baseRate = standardRate;
        isHighImpact = false;
        
        if (liquidityRate > baseRate) {
            baseRate = liquidityRate;
            isHighImpact = true;
        }
        if (threeDayRate > baseRate) {
            baseRate = threeDayRate;
            isHighImpact = true;
        }

        uint256 taxRate = baseRate + sybilRate;
        if (sybilRate > 0) {
            isHighImpact = true;
        }
        if (taxRate == 0) {
            taxRate = standardRate;
        }
        if (taxRate > MAX_TAX) {
            taxRate = MAX_TAX;
        }

        // Calculate tax distribution - FIXED TO MATCH WHITEPAPER
        uint256 taxAmount = (amount * taxRate) / BASIS_POINTS;
        
        // FIXED: Use proper percentage distribution
        burnAmount = (taxAmount * STANDARD_BURN_TAX) / TOTAL_STANDARD_TAX;
        
        if (isHighImpact) {
            // High impact: All non-burn tax goes to LP
            liquidityAmount = taxAmount - burnAmount;
            advertisingAmount = 0;
            communityAmount = 0;
        } else {
            // FIXED: Use the actual constants for proper distribution
            advertisingAmount = (taxAmount * STANDARD_ADVERTISING_TAX) / TOTAL_STANDARD_TAX;  // 21%
            liquidityAmount = (taxAmount * STANDARD_LIQUIDITY_TAX) / TOTAL_STANDARD_TAX;     // 71%  
            communityAmount = (taxAmount * STANDARD_COMMUNITY_TAX) / TOTAL_STANDARD_TAX;    // 7%
        }
        
        return (burnAmount, advertisingAmount, liquidityAmount, communityAmount, isHighImpact);
    }

    // =============================================================================
    // LIQUIDITY MANAGEMENT
    // =============================================================================

    function updateLiquidity() external {
        if (msg.sender != address(token)) revert OnlyTokenContract();
        address liquidityPool = token.liquidityPool();
        if (liquidityPool != address(0)) {
            liquidityData.updatePoolBalance(liquidityPool, address(token));
        }
    }

    // Gas optimized daily volume tracking
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
    // VIEW FUNCTIONS - ENHANCED FOR PRODUCTION
    // =============================================================================

    function getSellWindow(address account) external view returns (
        uint256 totalSold,
        uint256 windowStart,
        uint256 initialHoldings,
        uint256 sellCount,
        uint256 timeRemaining
    ) {
        TaxLib.SellWindow memory window = sellWindows[account];
        uint256 timeLeft = 0;
        if (window.windowStart > 0 && block.timestamp < window.windowStart + THREE_DAYS) {
            timeLeft = (window.windowStart + THREE_DAYS) - block.timestamp;
        }
        return (
            window.totalSold,
            window.windowStart,
            window.initialHoldings,
            window.sellCount,
            timeLeft
        );
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

    /**
     * @dev Comprehensive buy statistics
     */
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

    /**
     * @dev Enhanced trading statistics for monitoring
     */
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
    // ADMIN FUNCTIONS - PRODUCTION SECURED
    // =============================================================================

    function clearSellCooldown(address account) external onlyOwner {
        require(sellCooldownEnd[account] > block.timestamp, "No active cooldown");
        sellCooldownEnd[account] = 0;
        emit CooldownApplied(account, 0, "owner_cleared", block.timestamp);
    }

    function clearWalletCluster(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        walletClusters[account] = address(0);
        emit WalletClusterDetected(account, address(0), block.timestamp);
    }

    /**
     * @dev Reset trading stats with owner protection
     */
    function resetTradingStats(address account) external onlyOwner {
        require(account != address(0), "Invalid address");
        delete totalBuyVolume[account];
        delete totalSellVolume[account];
        delete buyCount[account];
        delete sellWindows[account];
    }

    /**
     * @dev Batch operations for gas efficiency
     */
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