//fileName: TaxLib.sol - COMPREHENSIVE OVERHAUL VERSION (NO CHANGES NEEDED)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title TaxLib
 * @dev Enhanced tax calculation library with individual sell tracking and cluster detection
 * @notice Implements whale dump protection and sophisticated lineage-based clustering
 * @notice NO CHANGES NEEDED - Library functions remain unchanged for degraded mode fix
 */
library TaxLib {
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant SELL_WINDOW_DURATION = 72 hours; // Individual sell tracking window
    uint256 internal constant CLUSTER_WINDOW_DURATION = 35 days; // Cluster sell tracking window
    uint256 internal constant DISTRIBUTOR_DETECTION_WINDOW = 24 hours; // Distributor burst detection
    
    // Enhanced liquidity impact thresholds and taxes
    uint256 internal constant MEDIUM_DUMP_THRESHOLD = 1200; // 12%
    uint256 internal constant LARGE_DUMP_THRESHOLD = 2000; // 20%
    uint256 internal constant EXTREME_DUMP_THRESHOLD = 3000; // 30%
    
    // Enhanced tax rates for new system
    uint256 internal constant MEDIUM_DUMP_TAX = 4500; // 45%
    uint256 internal constant LARGE_DUMP_TAX = 5200; // 52%
    uint256 internal constant EXTREME_DUMP_TAX = 7500; // 75%
    
    // Distributor detection thresholds
    uint256 internal constant MIN_DISTRIBUTOR_RECIPIENTS = 3;
    uint256 internal constant DISTRIBUTOR_LP_THRESHOLD = 650; // 6.5% of LP
    
    /**
     * @dev Individual wallet sell tracking (replaces old 3-day rule)
     */
    struct IndividualSellWindow {
        uint256 totalSold;           // Total amount sold in current window
        uint256 windowStart;         // Start time of current window
        uint256 cumulativeLPImpact;  // Cumulative LP impact percentage (basis points)
        uint256 sellCount;           // Number of sells in window
    }
    
    /**
     * @dev Distributor detection and lineage tracking
     */
    struct DistributorData {
        bool isDistributor;              // Is this wallet flagged as distributor
        uint256 distributorFlagTime;     // When distributor flag was set
        uint256 transferCount;           // Number of transfers in detection window
        uint256 totalTransferred;       // Total amount transferred in detection window
        uint256 lastTransferTime;       // Last transfer timestamp
        address[] recipients;            // List of recipients (for distributor detection)
    }
    
    /**
     * @dev Wallet lineage tracking
     */
    struct LineageData {
        address parent;                  // Direct parent (who sent tokens to this wallet)
        uint256 receivedTime;           // When tokens were received from parent
        bool isClusterLinked;           // Is this wallet part of a flagged cluster
        address rootDistributor;        // Root distributor in the lineage chain
    }
    
    /**
     * @dev Cluster-wide sell tracking (35-day window)
     */
    struct ClusterSellData {
        uint256 totalClusterSold;       // Total sold by entire cluster
        uint256 clusterWindowStart;     // Start of 35-day cluster window
        uint256 cumulativeClusterLPImpact; // Cluster's cumulative LP impact
        uint256 clusterSellCount;       // Total sells by cluster members
        bool isActive;                  // Is cluster tracking active
    }
    
    enum TaxCategory { 
        STANDARD, 
        LIQUIDITY_IMPACT, 
        INDIVIDUAL_SELL_LIMIT,
        CLUSTER_PENALTY,
        SYBIL_DEFENSE,
        OTHER 
    }

    // Custom errors
    error OverflowInTaxCalculation(uint256 sellAmount, uint256 basis);
    error InvalidLiquidityBalance();
    error InvalidSellAmount();

    /**
     * @dev Enhanced liquidity-based tax calculation (same logic, updated rates)
     */
    function calculateLiquidityTax(
        uint256 sellAmount,
        uint256 liquidityBalance
    ) public pure returns (uint256) {
        if (liquidityBalance == 0 || sellAmount == 0) {
            return 0;
        }

        // Check for overflow before multiplication
        if (sellAmount > type(uint256).max / BASIS_POINTS) {
            return EXTREME_DUMP_TAX;
        }

        uint256 impactPercentage;
        unchecked {
            impactPercentage = (sellAmount * BASIS_POINTS) / liquidityBalance;
        }

        // Apply enhanced tax rates
        if (impactPercentage >= EXTREME_DUMP_THRESHOLD) {
            return EXTREME_DUMP_TAX; // 75%
        }
        if (impactPercentage >= LARGE_DUMP_THRESHOLD) {
            return LARGE_DUMP_TAX; // 52%
        }
        if (impactPercentage >= MEDIUM_DUMP_THRESHOLD) {
            return MEDIUM_DUMP_TAX; // 45%
        }
        
        return 0;
    }
    
    /**
     * @dev NEW: Individual sell window tracking (replaces 3-day rule)
     * Aggregates sells over 72 hours and applies progressive taxes
     */
    function updateIndividualSellWindow(
        IndividualSellWindow storage window,
        uint256 amount,
        uint256 liquidityBalance
    ) external returns (uint256 applicableTax) {
        if (amount == 0) revert InvalidSellAmount();
        
        // Check if window has expired or needs initialization
        if (block.timestamp > window.windowStart + SELL_WINDOW_DURATION || window.windowStart == 0) {
            // Reset window with new sell
            window.windowStart = block.timestamp;
            window.totalSold = amount;
            window.sellCount = 1;
            
            // Calculate LP impact for this sell
            if (liquidityBalance > 0) {
                window.cumulativeLPImpact = (amount * BASIS_POINTS) / liquidityBalance;
            } else {
                window.cumulativeLPImpact = 0;
            }
        } else {
            // Update existing window with overflow protection
            uint256 newTotalSold;
            if (window.totalSold > type(uint256).max - amount) {
                newTotalSold = type(uint256).max;
            } else {
                unchecked {
                    newTotalSold = window.totalSold + amount;
                }
            }
            
            window.totalSold = newTotalSold;
            
            // Update cumulative LP impact
            if (liquidityBalance > 0) {
                uint256 newImpact = (amount * BASIS_POINTS) / liquidityBalance;
                if (window.cumulativeLPImpact <= type(uint256).max - newImpact) {
                    window.cumulativeLPImpact += newImpact;
                } else {
                    window.cumulativeLPImpact = type(uint256).max;
                }
            }
            
            // Safe increment for sell count
            unchecked {
                if (window.sellCount < type(uint256).max) {
                    window.sellCount += 1;
                }
            }
        }
        
        // Apply progressive tax based on cumulative LP impact
        return calculateProgressiveTax(window.cumulativeLPImpact);
    }
    
    /**
     * @dev Calculate progressive tax based on cumulative impact
     */
    function calculateProgressiveTax(uint256 cumulativeImpact) public pure returns (uint256) {
        if (cumulativeImpact >= EXTREME_DUMP_THRESHOLD) {
            return EXTREME_DUMP_TAX; // 75%
        }
        if (cumulativeImpact >= LARGE_DUMP_THRESHOLD) {
            return LARGE_DUMP_TAX; // 52%
        }
        if (cumulativeImpact >= MEDIUM_DUMP_THRESHOLD) {
            return MEDIUM_DUMP_TAX; // 45%
        }
        return 0;
    }
    
    /**
     * @dev NEW: Distributor detection based on transfer patterns
     */
    function updateDistributorTracking(
        DistributorData storage distributorData,
        address recipient,
        uint256 amount,
        uint256 liquidityBalance
    ) external returns (bool becameDistributor) {
        // Reset tracking if outside detection window
        if (block.timestamp > distributorData.lastTransferTime + DISTRIBUTOR_DETECTION_WINDOW) {
            // Clear old data
            delete distributorData.recipients;
            distributorData.transferCount = 0;
            distributorData.totalTransferred = 0;
        }
        
        // Update transfer data
        distributorData.lastTransferTime = block.timestamp;
        distributorData.transferCount += 1;
        distributorData.totalTransferred += amount;
        
        // Add recipient if not already in list
        bool recipientExists = false;
        for (uint256 i = 0; i < distributorData.recipients.length; i++) {
            if (distributorData.recipients[i] == recipient) {
                recipientExists = true;
                break;
            }
        }
        
        if (!recipientExists) {
            distributorData.recipients.push(recipient);
        }
        
        // Check if qualifies as distributor
        bool qualifiesAsDistributor = false;
        
        if (distributorData.recipients.length >= MIN_DISTRIBUTOR_RECIPIENTS && liquidityBalance > 0) {
            // Check if total transferred exceeds threshold
            uint256 transferImpact = (distributorData.totalTransferred * BASIS_POINTS) / liquidityBalance;
            if (transferImpact >= DISTRIBUTOR_LP_THRESHOLD) {
                qualifiesAsDistributor = true;
            }
        }
        
        // Flag as distributor if criteria met and not already flagged
        if (qualifiesAsDistributor && !distributorData.isDistributor) {
            distributorData.isDistributor = true;
            distributorData.distributorFlagTime = block.timestamp;
            return true;
        }
        
        return false;
    }
    
    /**
     * @dev NEW: Update wallet lineage when receiving from distributor
     */
    function updateWalletLineage(
        LineageData storage lineage,
        address sender,
        mapping(address => DistributorData) storage distributorMap
    ) external {
        // Only track lineage if sender is a flagged distributor
        if (distributorMap[sender].isDistributor) {
            lineage.parent = sender;
            lineage.receivedTime = block.timestamp;
            lineage.isClusterLinked = true;
            
            // Trace to find root distributor
            address current = sender;
            while (lineage.rootDistributor == address(0) && current != address(0)) {
                if (distributorMap[current].isDistributor) {
                    lineage.rootDistributor = current;
                    break;
                }
                // Move up the chain
                current = lineage.parent;
            }
            
            if (lineage.rootDistributor == address(0)) {
                lineage.rootDistributor = sender; // Fallback to direct sender
            }
        }
    }
    
    /**
     * @dev NEW: Multi-hop lineage tracing to find root distributor
     */
    function traceLineageToRoot(
        address wallet,
        mapping(address => LineageData) storage lineageMap,
        mapping(address => DistributorData) storage distributorMap
    ) external view returns (address rootDistributor, bool isClusterMember) {
        address current = wallet;
        uint256 hops = 0;
        uint256 maxHops = 10; // Prevent infinite loops
        
        while (current != address(0) && hops < maxHops) {
            LineageData memory lineage = lineageMap[current];
            
            // If current wallet has a parent, check if parent is distributor
            if (lineage.parent != address(0)) {
                if (distributorMap[lineage.parent].isDistributor) {
                    return (lineage.parent, true);
                }
                // Move to parent
                current = lineage.parent;
            } else {
                // No parent, check if current wallet is distributor
                if (distributorMap[current].isDistributor) {
                    return (current, true);
                }
                break;
            }
            
            hops++;
        }
        
        return (address(0), false);
    }
    
    /**
     * @dev NEW: Update cluster sell tracking (35-day window)
     */
    function updateClusterSellTracking(
        ClusterSellData storage clusterData,
        uint256 amount,
        uint256 liquidityBalance
    ) external returns (uint256 clusterTax) {
        // Initialize or reset cluster window if expired
        if (!clusterData.isActive || 
            block.timestamp > clusterData.clusterWindowStart + CLUSTER_WINDOW_DURATION) {
            
            clusterData.clusterWindowStart = block.timestamp;
            clusterData.totalClusterSold = amount;
            clusterData.clusterSellCount = 1;
            clusterData.isActive = true;
            
            if (liquidityBalance > 0) {
                clusterData.cumulativeClusterLPImpact = (amount * BASIS_POINTS) / liquidityBalance;
            } else {
                clusterData.cumulativeClusterLPImpact = 0;
            }
        } else {
            // Update existing cluster window
            clusterData.totalClusterSold += amount;
            clusterData.clusterSellCount += 1;
            
            if (liquidityBalance > 0) {
                uint256 sellImpact = (amount * BASIS_POINTS) / liquidityBalance;
                clusterData.cumulativeClusterLPImpact += sellImpact;
            }
        }
        
        // Apply cluster-wide tax based on total impact
        return calculateClusterTax(clusterData.cumulativeClusterLPImpact);
    }
    
    /**
     * @dev Calculate cluster-wide tax penalties
     */
    function calculateClusterTax(uint256 cumulativeClusterImpact) public pure returns (uint256) {
        if (cumulativeClusterImpact >= EXTREME_DUMP_THRESHOLD) {
            return EXTREME_DUMP_TAX; // 75%
        }
        if (cumulativeClusterImpact >= LARGE_DUMP_THRESHOLD) {
            return LARGE_DUMP_TAX; // 52%
        }
        if (cumulativeClusterImpact >= MEDIUM_DUMP_THRESHOLD) {
            return MEDIUM_DUMP_TAX; // 45%
        }
        return 0;
    }
    
    /**
     * @dev Enhanced sybil defense (simplified version)
     */
    function calculateSybilTax(
        bool sybilDefenseEnabled,
        address seller,
        mapping(address => uint256) storage walletCreationTime
    ) public view returns (uint256) {
        if (!sybilDefenseEnabled) return 0;

        uint256 creationTime = walletCreationTime[seller];
        
        // New wallet penalty (created within 24 hours)
        if (creationTime > 0 && block.timestamp < creationTime + 1 days) {
            return 100; // 1% new wallet tax
        }
        return 0;
    }
    
    /**
     * @dev Comprehensive tax calculation with new systems
     */
    function calculateComprehensiveTax(
        uint256 sellAmount,
        uint256 liquidityBalance,
        IndividualSellWindow memory sellWindow,
        bool isClusterMember,
        ClusterSellData memory clusterData,
        bool sybilDefenseEnabled,
        bool dumpSpikeDetectionEnabled,
        address seller,
        mapping(address => uint256) storage walletCreationTime
    ) external view returns (
        uint256 finalTaxRate,
        TaxCategory category,
        uint256 liquidityTax,
        uint256 individualTax,
        uint256 clusterTax,
        uint256 sybilTax
    ) {
        // Calculate individual tax components
        liquidityTax = dumpSpikeDetectionEnabled 
            ? calculateLiquidityTax(sellAmount, liquidityBalance) 
            : 0;
        
        individualTax = calculateProgressiveTax(sellWindow.cumulativeLPImpact);
        
        clusterTax = isClusterMember 
            ? calculateClusterTax(clusterData.cumulativeClusterLPImpact)
            : 0;
        
        sybilTax = calculateSybilTax(
            sybilDefenseEnabled,
            seller,
            walletCreationTime
        );

        // Determine highest applicable tax
        finalTaxRate = 0;
        category = TaxCategory.STANDARD;
        
        if (clusterTax > finalTaxRate) {
            finalTaxRate = clusterTax;
            category = TaxCategory.CLUSTER_PENALTY;
        }
        
        if (individualTax > finalTaxRate) {
            finalTaxRate = individualTax;
            category = TaxCategory.INDIVIDUAL_SELL_LIMIT;
        }
        
        if (liquidityTax > finalTaxRate) {
            finalTaxRate = liquidityTax;
            category = TaxCategory.LIQUIDITY_IMPACT;
        }

        // Add sybil tax (additive)
        if (sybilTax > 0) {
            if (finalTaxRate <= type(uint256).max - sybilTax) {
                finalTaxRate += sybilTax;
            } else {
                finalTaxRate = type(uint256).max;
            }
            if (category == TaxCategory.STANDARD) {
                category = TaxCategory.SYBIL_DEFENSE;
            }
        }

        return (finalTaxRate, category, liquidityTax, individualTax, clusterTax, sybilTax);
    }
    
    /**
     * @dev Convert tax category to string for events
     */
    function taxCategoryToString(TaxCategory category) external pure returns (string memory) {
        if (category == TaxCategory.STANDARD) return "standard";
        if (category == TaxCategory.LIQUIDITY_IMPACT) return "liquidity_impact";
        if (category == TaxCategory.INDIVIDUAL_SELL_LIMIT) return "individual_sell_limit";
        if (category == TaxCategory.CLUSTER_PENALTY) return "cluster_penalty";
        if (category == TaxCategory.SYBIL_DEFENSE) return "sybil_defense";
        return "other";
    }
    
    /**
     * @dev Get enhanced tax thresholds and rates
     */
    function getTaxConfiguration() external pure returns (
        uint256 mediumThreshold,
        uint256 largeThreshold,
        uint256 extremeThreshold,
        uint256 mediumTax,
        uint256 largeTax,
        uint256 extremeTax,
        uint256 sellWindowDuration,
        uint256 clusterWindowDuration
    ) {
        return (
            MEDIUM_DUMP_THRESHOLD,
            LARGE_DUMP_THRESHOLD,
            EXTREME_DUMP_THRESHOLD,
            MEDIUM_DUMP_TAX,
            LARGE_DUMP_TAX,
            EXTREME_DUMP_TAX,
            SELL_WINDOW_DURATION,
            CLUSTER_WINDOW_DURATION
        );
    }
    
    /**
     * @dev Validate enhanced tax thresholds
     */
    function validateTaxThresholds() external pure returns (bool) {
        return (MEDIUM_DUMP_THRESHOLD < LARGE_DUMP_THRESHOLD) &&
               (LARGE_DUMP_THRESHOLD < EXTREME_DUMP_THRESHOLD) &&
               (EXTREME_DUMP_THRESHOLD <= BASIS_POINTS);
    }
    
    // Safe math helpers
    function safeMul(uint256 a, uint256 b) external pure returns (uint256) {
        if (a == 0) return 0;
        if (a > type(uint256).max / b) {
            revert OverflowInTaxCalculation(a, b);
        }
        return a * b;
    }

    function safePercentage(uint256 amount, uint256 total) external pure returns (uint256) {
        if (total == 0) return 0;
        if (amount > type(uint256).max / BASIS_POINTS) {
            return BASIS_POINTS; // 100%
        }
        return (amount * BASIS_POINTS) / total;
    }
}