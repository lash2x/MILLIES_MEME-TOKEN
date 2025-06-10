//fileName: TaxLib.sol - SECURITY FIXED VERSION
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // FIXED: L1 - Use fixed pragma instead of floating

/**
 * @title TaxLib
 * @dev Production-ready library for tax calculation utilities
 * @notice Enhanced with overflow protection and gas optimizations for mainnet deployment - SECURITY FIXED VERSION
 */
library TaxLib {
    uint256 internal constant BASIS_POINTS = 10000;
    uint256 internal constant THREE_DAYS = 3 days;
    
    // Optimized tax thresholds (in basis points)
    uint256 internal constant EXTREME_DUMP_THRESHOLD = 3000; // 30%
    uint256 internal constant LARGE_DUMP_THRESHOLD = 2000; // 20%
    uint256 internal constant MEDIUM_DUMP_THRESHOLD = 1200; // 12%
    uint256 internal constant THREE_DAY_RULE_THRESHOLD = 5700; // 57%
    
    // Corresponding tax rates
    uint256 internal constant EXTREME_DUMP_TAX = 7500; // 75%
    uint256 internal constant LARGE_DUMP_TAX = 5200; // 52%
    uint256 internal constant MEDIUM_DUMP_TAX = 4500; // 45%
    uint256 internal constant THREE_DAY_RULE_TAX = 2700; // 27%
    
    struct SellWindow {
        uint256 totalSold;
        uint256 windowStart;
        uint256 initialHoldings;
        uint256 sellCount;
    }
    
    enum TaxCategory { 
        STANDARD, 
        LIQUIDITY_IMPACT, 
        THREE_DAY_RULE, 
        SYBIL_DEFENSE, 
        OTHER 
    }

    // FIXED: Add custom errors for better error handling
    error OverflowInTaxCalculation(uint256 sellAmount, uint256 basis);
    error InvalidLiquidityBalance();
    error InvalidSellAmount();

    /**
     * @dev Calculates liquidity-based tax without state mutations
     * FIXED: H2 - Add overflow protection before multiplication
     */
    function calculateLiquidityTax(
        uint256 sellAmount,
        uint256 liquidityBalance
    ) external pure returns (uint256) {
        // Early return for edge cases
        if (liquidityBalance == 0 || sellAmount == 0) {
            return 0;
        }

        // FIXED: Check for overflow before multiplication
        if (sellAmount > type(uint256).max / BASIS_POINTS) {
            // For extremely large amounts, return maximum tax
            return EXTREME_DUMP_TAX;
        }

        // Safe multiplication now that we've checked for overflow
        uint256 impactPercentage;
        unchecked {
            // Safe because we checked for overflow above
            impactPercentage = (sellAmount * BASIS_POINTS) / liquidityBalance;
        }

        // Gas optimized threshold checking with early returns
        if (impactPercentage >= EXTREME_DUMP_THRESHOLD) {
            return EXTREME_DUMP_TAX;
        }
        if (impactPercentage >= LARGE_DUMP_THRESHOLD) {
            return LARGE_DUMP_TAX;
        }
        if (impactPercentage >= MEDIUM_DUMP_THRESHOLD) {
            return MEDIUM_DUMP_TAX;
        }
        
        return 0; // No liquidity-based tax applied
    }
    
    /**
     * @dev Calculates 3-day rule tax with enhanced validation
     */
    function calculate3DayTax(
        SellWindow memory window,
        uint256 additionalSell
    ) external view returns (uint256) {
        // Early return if window not active or no initial holdings
        if (window.initialHoldings == 0 || window.windowStart == 0) {
            return 0;
        }

        // Check if still within 3-day window
        if (block.timestamp > window.windowStart + THREE_DAYS) {
            return 0;
        }

        // FIXED: Enhanced overflow protection in total calculation
        uint256 totalWouldSell;
        
        // Check for overflow in addition
        if (window.totalSold > type(uint256).max - additionalSell) {
            // If overflow would occur, assume maximum impact
            return THREE_DAY_RULE_TAX;
        }
        
        unchecked {
            totalWouldSell = window.totalSold + additionalSell;
        }

        // Check if selling entire holdings
        if (totalWouldSell >= window.initialHoldings) {
            return THREE_DAY_RULE_TAX;
        }

        // FIXED: Additional overflow check for percentage calculation
        if (totalWouldSell > type(uint256).max / BASIS_POINTS) {
            // For extremely large amounts, apply tax
            return THREE_DAY_RULE_TAX;
        }

        // Gas optimized percentage calculation
        uint256 sellPercentage;
        unchecked {
            // Safe because we checked for overflow above and totalWouldSell < initialHoldings
            sellPercentage = (totalWouldSell * BASIS_POINTS) / window.initialHoldings;
        }

        // Apply tax if above threshold
        if (sellPercentage >= THREE_DAY_RULE_THRESHOLD) {
            return THREE_DAY_RULE_TAX;
        }

        return 0;
    }
    
    /**
     * @dev Updates 3-day sell window with enhanced safety checks
     */
    function update3DaySellWindow(
        SellWindow storage window,
        uint256 amount,
        uint256 balanceBeforeSell
    ) external {
        if (amount == 0) revert InvalidSellAmount();
        require(balanceBeforeSell >= amount, "TaxLib: Insufficient balance");

        // Check if window has expired or needs initialization
        if (block.timestamp > window.windowStart + THREE_DAYS || window.windowStart == 0) {
            // Initialize new window
            window.windowStart = block.timestamp;
            window.totalSold = amount;
            window.initialHoldings = balanceBeforeSell;
            window.sellCount = 1;
        } else {
            // Update existing window with overflow protection
            uint256 newTotalSold;
            
            // FIXED: Enhanced overflow check before addition
            if (window.totalSold > type(uint256).max - amount) {
                // If overflow would occur, cap at maximum
                newTotalSold = type(uint256).max;
            } else {
                unchecked {
                    newTotalSold = window.totalSold + amount;
                }
            }
            
            window.totalSold = newTotalSold;
            
            // Safe increment for sell count
            unchecked {
                if (window.sellCount < type(uint256).max) {
                    window.sellCount += 1;
                }
            }
        }
    }
    
    /**
     * @dev Converts tax category to string for events and debugging
     */
    function taxCategoryToString(TaxCategory category) external pure returns (string memory) {
        // Use if-else chain instead of array lookup for gas efficiency
        if (category == TaxCategory.STANDARD) return "standard";
        if (category == TaxCategory.LIQUIDITY_IMPACT) return "liquidity_impact";
        if (category == TaxCategory.THREE_DAY_RULE) return "three_day_rule";
        if (category == TaxCategory.SYBIL_DEFENSE) return "sybil_defense";
        return "other";
    }
    
    /**
     * @dev Calculates Sybil defense tax with enhanced detection logic
     */
    function calculateSybilTax(
        bool sybilDefenseEnabled,
        address seller,
        mapping(address => address) storage walletClusters,
        mapping(address => uint256) storage walletCreationTime
    ) external view returns (uint256) {
        // Early return if feature disabled
        if (!sybilDefenseEnabled) return 0;

        // Cache storage reads to reduce SLOAD operations
        address clusterParent = walletClusters[seller];
        uint256 creationTime = walletCreationTime[seller];
        
        // Check if wallet is part of a cluster
        if (clusterParent != address(0)) {
            // Check if cluster penalty has expired (7 days)
            if (creationTime > 0 && block.timestamp > creationTime + 7 days) {
                // Cluster expired, treat as individual wallet
                return _calculateIndividualWalletTax(creationTime);
            } else {
                // Active cluster - apply cluster penalty
                return 1000; // 10% cluster tax
            }
        }
        
        // Individual wallet tax based on age
        return _calculateIndividualWalletTax(creationTime);
    }

    /**
     * @dev Internal function to calculate individual wallet tax
     */
    function _calculateIndividualWalletTax(uint256 creationTime) internal view returns (uint256) {
        // New wallet penalty (created within 24 hours)
        if (creationTime > 0 && block.timestamp < creationTime + 1 days) {
            return 100; // 1% new wallet tax
        }
        return 0;
    }

    /**
     * @dev Comprehensive tax calculation helper
     * Combines all tax types for efficient single-call calculation
     * FIXED: Enhanced with better overflow protection throughout
     */
    function calculateComprehensiveTax(
        uint256 sellAmount,
        uint256 liquidityBalance,
        SellWindow memory sellWindow,
        bool sybilDefenseEnabled,
        bool dumpSpikeDetectionEnabled,
        address seller,
        mapping(address => address) storage walletClusters,
        mapping(address => uint256) storage walletCreationTime
    ) external view returns (
        uint256 finalTaxRate,
        TaxCategory category,
        uint256 liquidityTax,
        uint256 threeDayTax,
        uint256 sybilTax
    ) {
        // Calculate individual tax components with enhanced safety
        liquidityTax = dumpSpikeDetectionEnabled 
            ? calculateLiquidityTax(sellAmount, liquidityBalance) 
            : 0;
        
        threeDayTax = calculate3DayTax(sellWindow, 0);
        
        sybilTax = calculateSybilTax(
            sybilDefenseEnabled,
            seller,
            walletClusters,
            walletCreationTime
        );

        // Determine highest base tax and category
        if (liquidityTax > threeDayTax) {
            finalTaxRate = liquidityTax;
            category = TaxCategory.LIQUIDITY_IMPACT;
        } else if (threeDayTax > 0) {
            finalTaxRate = threeDayTax;
            category = TaxCategory.THREE_DAY_RULE;
        } else {
            finalTaxRate = 0;
            category = TaxCategory.STANDARD;
        }

        // FIXED: Add sybil tax with overflow protection
        if (sybilTax > 0) {
            // Check for overflow before adding sybil tax
            if (finalTaxRate <= type(uint256).max - sybilTax) {
                finalTaxRate += sybilTax;
            } else {
                // Cap at maximum value if overflow would occur
                finalTaxRate = type(uint256).max;
            }
            category = TaxCategory.SYBIL_DEFENSE;
        }

        return (finalTaxRate, category, liquidityTax, threeDayTax, sybilTax);
    }

    /**
     * @dev Tax threshold validation helper
     */
    function validateTaxThresholds() external pure returns (bool) {
        // Ensure thresholds are in ascending order
        return (MEDIUM_DUMP_THRESHOLD < LARGE_DUMP_THRESHOLD) &&
               (LARGE_DUMP_THRESHOLD < EXTREME_DUMP_THRESHOLD) &&
               (EXTREME_DUMP_THRESHOLD <= BASIS_POINTS);
    }

    /**
     * @dev Get all tax thresholds for external configuration
     */
    function getTaxThresholds() external pure returns (
        uint256 medium,
        uint256 large,
        uint256 extreme,
        uint256 threeDayRule
    ) {
        return (
            MEDIUM_DUMP_THRESHOLD,
            LARGE_DUMP_THRESHOLD,
            EXTREME_DUMP_THRESHOLD,
            THREE_DAY_RULE_THRESHOLD
        );
    }

    /**
     * @dev Get all tax rates for external reference
     */
    function getTaxRates() external pure returns (
        uint256 medium,
        uint256 large,
        uint256 extreme,
        uint256 threeDayRule
    ) {
        return (
            MEDIUM_DUMP_TAX,
            LARGE_DUMP_TAX,
            EXTREME_DUMP_TAX,
            THREE_DAY_RULE_TAX
        );
    }

    // FIXED: Add safe math helper functions for external use
    
    /**
     * @dev Safe multiplication with overflow check
     */
    function safeMul(uint256 a, uint256 b) external pure returns (uint256) {
        if (a == 0) return 0;
        if (a > type(uint256).max / b) {
            revert OverflowInTaxCalculation(a, b);
        }
        return a * b;
    }

    /**
     * @dev Safe percentage calculation with overflow protection
     */
    function safePercentage(uint256 amount, uint256 total) external pure returns (uint256) {
        if (total == 0) return 0;
        if (amount > type(uint256).max / BASIS_POINTS) {
            // Return maximum percentage for extremely large amounts
            return BASIS_POINTS; // 100%
        }
        return (amount * BASIS_POINTS) / total;
    }

    /**
     * @dev Check if multiplication would overflow
     */
    function wouldOverflow(uint256 a, uint256 b) external pure returns (bool) {
        if (a == 0) return false;
        return a > type(uint256).max / b;
    }
}