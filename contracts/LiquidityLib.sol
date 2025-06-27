//fileName: LiquidityLib.sol - MAINNET READY VERSION (NO CHANGES NEEDED)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Interfaces.sol";

/**
 * @title LiquidityLib
 * @dev Production-ready library for liquidity pool operations and TWAP calculations
 * @notice Enhanced with gas optimizations and overflow protection for mainnet deployment
 * @notice NO CHANGES NEEDED - Library functions remain unchanged for degraded mode fix
 */
library LiquidityLib {
    uint256 private constant TWAP_PERIOD = 1800; // 30 minutes
    
    event LiquidityPoolUpdated(uint256 oldBalance, uint256 newBalance, uint256 timestamp);
    
    struct LiquidityData {
        uint256 liquidityPoolBalance;
        uint256 liquidityPoolBalanceTWAP;
        uint256 lastTWAPUpdate;
        uint256 lastTWAPBlock;
    }
    
    /**
     * @dev Updates liquidity pool balance and TWAP with enhanced security
     * ⚡ Gas optimized with overflow protection
     */
    function updatePoolBalance(
        LiquidityData storage data,
        address liquidityPool,
        address tokenAddress
    ) external {
        if (liquidityPool == address(0)) return;

        // ⚡ Gas optimization: Cache current values to reduce SLOAD operations
        uint256 currentBalance = data.liquidityPoolBalance;
        uint256 currentTWAP = data.liquidityPoolBalanceTWAP;
        uint256 lastUpdate = data.lastTWAPUpdate;

        // Get current reserves from the pair
        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(liquidityPool).getReserves();
        address token0 = IPancakePair(liquidityPool).token0();
        uint256 newBalance = (token0 == tokenAddress) ? reserve0 : reserve1;

        // 🔒 SECURITY: Overflow protection in time delta calculation
        uint256 timeDelta;
        unchecked {
            // Safe because block.timestamp always increases
            timeDelta = block.timestamp > lastUpdate ? block.timestamp - lastUpdate : 0;
        }

        // ⚡ Gas optimized TWAP calculation
        if (timeDelta > 0 && currentTWAP > 0) {
            // 🔒 SECURITY: Safe weight calculation with bounds checking
            uint256 weight = timeDelta > TWAP_PERIOD ? TWAP_PERIOD : timeDelta;
            uint256 remainingWeight = TWAP_PERIOD - weight;
            
            // Prevent division by zero and overflow
            if (TWAP_PERIOD > 0) {
                // Safe arithmetic with overflow checks
                uint256 weightedOld = currentTWAP * remainingWeight;
                uint256 weightedNew = newBalance * weight;
                
                // 🔒 Check for potential overflow before addition
                if (weightedOld <= type(uint256).max - weightedNew) {
                    data.liquidityPoolBalanceTWAP = (weightedOld + weightedNew) / TWAP_PERIOD;
                } else {
                    // Fallback to new balance if overflow would occur
                    data.liquidityPoolBalanceTWAP = newBalance;
                }
            }
        } else {
            // Initialize TWAP with current balance
            data.liquidityPoolBalanceTWAP = newBalance;
        }

        // Update stored values
        data.liquidityPoolBalance = newBalance;
        data.lastTWAPUpdate = block.timestamp;
        data.lastTWAPBlock = block.number;

        // Emit event only if balance changed (gas optimization)
        if (currentBalance != newBalance) {
            emit LiquidityPoolUpdated(currentBalance, newBalance, block.timestamp);
        }
    }
    
    /**
     * @dev Calculates liquidity balance for view operations with enhanced safety
     * ⚡ Gas optimized for frequent calls
     */
    function getLiquidityBalanceForView(
        LiquidityData storage data
    ) external view returns (uint256) {
        // ⚡ Cache storage reads
        uint256 storedTWAP = data.liquidityPoolBalanceTWAP;
        uint256 storedBalance = data.liquidityPoolBalance;
        uint256 lastUpdate = data.lastTWAPUpdate;

        // Early return for uninitialized data
        if (storedTWAP == 0 || storedBalance == 0) {
            return storedBalance;
        }

        // 🔒 Safe time delta calculation
        uint256 timeDelta;
        unchecked {
            timeDelta = block.timestamp > lastUpdate ? block.timestamp - lastUpdate : 0;
        }

        // ⚡ Optimized TWAP calculation for view
        uint256 weight = timeDelta > TWAP_PERIOD ? TWAP_PERIOD : timeDelta;
        uint256 remainingWeight = TWAP_PERIOD - weight;
        
        // Safe calculation with overflow protection
        if (TWAP_PERIOD > 0) {
            uint256 weightedOld = storedTWAP * remainingWeight;
            uint256 weightedNew = storedBalance * weight;
            
            // Check for overflow
            if (weightedOld <= type(uint256).max - weightedNew) {
                return (weightedOld + weightedNew) / TWAP_PERIOD;
            }
        }
        
        // Fallback to stored balance
        return storedBalance;
    }
    
    /**
     * @dev Updates TWAP in _afterTokenTransfer hook with rate limiting
     * ⚡ Gas optimized for transaction hooks
     */
    function updateTWAPInHook(
        LiquidityData storage data,
        address liquidityPool,
        address tokenAddress,
        bool liquidityUpdatePending
    ) external returns (bool) {
        // Rate-limit TWAP updates to once per block for gas efficiency
        if (liquidityUpdatePending && liquidityPool != address(0)) {
            if (block.number > data.lastTWAPBlock) {
                // ⚡ Cache current balance to reduce SLOAD
                uint256 oldBalance = data.liquidityPoolBalance;
                
                // Get fresh reserves
                (uint112 reserve0, uint112 reserve1, ) = IPancakePair(liquidityPool).getReserves();
                address token0 = IPancakePair(liquidityPool).token0();
                uint256 newBalance = (token0 == tokenAddress) ? reserve0 : reserve1;

                // 🔒 Safe time delta calculation
                uint256 timeDelta;
                unchecked {
                    timeDelta = block.timestamp > data.lastTWAPUpdate 
                        ? block.timestamp - data.lastTWAPUpdate 
                        : 0;
                }

                // Update TWAP with overflow protection
                if (timeDelta > 0 && data.liquidityPoolBalanceTWAP > 0) {
                    uint256 weight = timeDelta > TWAP_PERIOD ? TWAP_PERIOD : timeDelta;
                    uint256 remainingWeight = TWAP_PERIOD - weight;
                    
                    if (TWAP_PERIOD > 0) {
                        uint256 weightedOld = data.liquidityPoolBalanceTWAP * remainingWeight;
                        uint256 weightedNew = newBalance * weight;
                        
                        // 🔒 Overflow check
                        if (weightedOld <= type(uint256).max - weightedNew) {
                            data.liquidityPoolBalanceTWAP = (weightedOld + weightedNew) / TWAP_PERIOD;
                        } else {
                            data.liquidityPoolBalanceTWAP = newBalance;
                        }
                    }
                } else {
                    data.liquidityPoolBalanceTWAP = newBalance;
                }

                // Update stored values
                data.liquidityPoolBalance = newBalance;
                data.lastTWAPUpdate = block.timestamp;
                data.lastTWAPBlock = block.number;

                // Emit event if balance changed
                if (oldBalance != newBalance) {
                    emit LiquidityPoolUpdated(oldBalance, newBalance, block.timestamp);
                }
                
                return false; // liquidityUpdatePending = false
            }
        }
        return liquidityUpdatePending;
    }

    /**
     * ✅ PRODUCTION: Batch liquidity data for gas-efficient external calls
     */
    function getLiquidityStats(
        LiquidityData storage data
    ) external view returns (
        uint256 currentBalance,
        uint256 twapBalance,
        uint256 lastUpdate,
        uint256 timeSinceUpdate
    ) {
        currentBalance = data.liquidityPoolBalance;
        twapBalance = data.liquidityPoolBalanceTWAP;
        lastUpdate = data.lastTWAPUpdate;
        
        // Safe time calculation
        unchecked {
            timeSinceUpdate = block.timestamp > lastUpdate 
                ? block.timestamp - lastUpdate 
                : 0;
        }
        
        return (currentBalance, twapBalance, lastUpdate, timeSinceUpdate);
    }

    /**
     * ✅ PRODUCTION: Reset TWAP data (emergency function)
     */
    function resetTWAPData(
        LiquidityData storage data,
        address liquidityPool,
        address tokenAddress
    ) external {
        if (liquidityPool == address(0)) return;

        // Get current balance
        (uint112 reserve0, uint112 reserve1, ) = IPancakePair(liquidityPool).getReserves();
        address token0 = IPancakePair(liquidityPool).token0();
        uint256 currentBalance = (token0 == tokenAddress) ? reserve0 : reserve1;

        // Reset to current values
        data.liquidityPoolBalance = currentBalance;
        data.liquidityPoolBalanceTWAP = currentBalance;
        data.lastTWAPUpdate = block.timestamp;
        data.lastTWAPBlock = block.number;

        emit LiquidityPoolUpdated(0, currentBalance, block.timestamp);
    }

    // =============================================================================
    // DEV / TESTNET ONLY FUNCTIONS (COMMENTED FOR PRODUCTION)
    // =============================================================================

    /*
    // 🧪 DEV ONLY: Manual TWAP manipulation for testing
    function setTWAPForTesting(
        LiquidityData storage data,
        uint256 twapValue
    ) external {
        data.liquidityPoolBalanceTWAP = twapValue;
        data.lastTWAPUpdate = block.timestamp;
    }

    // 🧪 DEV ONLY: Get detailed TWAP calculation breakdown
    function getTWAPCalculationDetails(
        LiquidityData storage data
    ) external view returns (
        uint256 currentBalance,
        uint256 currentTWAP,
        uint256 timeDelta,
        uint256 weight,
        uint256 projectedTWAP
    ) {
        currentBalance = data.liquidityPoolBalance;
        currentTWAP = data.liquidityPoolBalanceTWAP;
        timeDelta = block.timestamp > data.lastTWAPUpdate 
            ? block.timestamp - data.lastTWAPUpdate 
            : 0;
        weight = timeDelta > TWAP_PERIOD ? TWAP_PERIOD : timeDelta;
        
        if (TWAP_PERIOD > 0 && currentTWAP > 0) {
            uint256 remainingWeight = TWAP_PERIOD - weight;
            projectedTWAP = (currentTWAP * remainingWeight + currentBalance * weight) / TWAP_PERIOD;
        } else {
            projectedTWAP = currentBalance;
        }
        
        return (currentBalance, currentTWAP, timeDelta, weight, projectedTWAP);
    }
    */
}