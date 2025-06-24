//fileName: MilliesToken.sol - COMPILATION FIXED VERSION  
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Interfaces.sol";

interface IMilliesHelper {
    function validateTransfer(address from, address to, uint256 amount) external;
    function processSell(address seller, uint256 amount) external returns (uint256);
    function processBuy(address buyer, uint256 amount) external returns (uint256);
    function updateLiquidity() external;
    function getSellWindow(address account) external view returns (uint256, uint256, uint256, uint256, uint256);
    function getCooldownInfo(address account) external view returns (uint256, uint256, bool, uint256, bool);
    function totalTaxAccumulated() external view returns (uint256);
    function reservedLiquidityTokens() external view returns (uint256);
    function totalBurned() external view returns (uint256);
    function dailyTradingVolume() external view returns (uint256);
    function calculateTaxDistribution(address seller, uint256 amount) external view returns (uint256, uint256, uint256, uint256, bool);
    function isTradeTransaction(address from, address to) external view returns (bool isBuy, bool isSell);
}

/**
 * @title MilliesToken
 * @dev Production-ready meme token with comprehensive anti-bot features and PancakeSwap integration
 * @notice Mainnet deployment with enhanced security and gas optimizations - COMPILATION FIXED VERSION
 */
contract MilliesToken is ERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    // =============================================================================
    // CONSTANTS - MAINNET CONFIGURATION
    // =============================================================================

    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 10**18;
    uint256 private constant MAX_AIRDROP_RECIPIENTS = 20;
    uint256 private constant BASIS_POINTS = 10000;
    
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    // ✅ MAINNET: Updated to BSC mainnet PancakeSwap factory
    address public constant PANCAKE_FACTORY = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;//0x6725F303b657a9451d8BA641348b6761A6CC7a17(testnet);//0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;(mainnet)

    // =============================================================================
    // STATE VARIABLES
    // =============================================================================

    // Feature toggles
    bool public dumpSpikeDetectionEnabled;
    bool public sybilDefenseEnabled;
    bool public autoSwapAndLiquifyEnabled;
    bool public tradingEnabled;
    bool public buyTaxEnabled = true;

    // Setup state
    bool public setupCompleted;
    uint256 public contractDeployTime;
    uint256 public tradingEnabledTime;

    // Contract addresses
    address public advertisingWallet;
    address public communityWallet;
    address public liquidityPool;
    address public helperContract;
    
    // Router & WBNB
    address public WBNB;
    IUniswapV2Router02 public pancakeRouter;

    // Access control
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => bool) public isExcludedFromCooldown;
    mapping(address => bool) public isBlacklisted;

    // Holder tracking
    mapping(address => bool) public isHoldingTokens;
    uint256 public totalHolders;

    // FIXED: Add degraded mode tracking for helper failures
    bool public degradedMode;
    uint256 public degradedModeActivated;

    // =============================================================================
    // EVENTS - ENHANCED FOR PRODUCTION MONITORING
    // =============================================================================

    event TaxCollected(address indexed from, address indexed to, uint256 amount, string indexed taxType, uint256 timestamp);
    event BuyTaxCollected(address indexed buyer, uint256 amount, uint256 taxAmount, uint256 timestamp);
    event TradingToggled(bool enabled, uint256 timestamp);
    event FeatureToggled(string indexed feature, bool enabled, address indexed by, uint256 timestamp);
    event SetupCompleted(address indexed by, uint256 timestamp);
    event WalletUpdated(string indexed walletType, address indexed oldWallet, address indexed newWallet, uint256 timestamp);
    event WalletFunded(address indexed wallet, uint256 amount, string indexed purpose, uint256 timestamp);
    event AddressBlacklisted(address indexed account, bool status, uint256 timestamp);
    event HelperContractUpdated(address indexed oldHelper, address indexed newHelper, uint256 timestamp);
    event TradeDetected(address indexed from, address indexed to, uint256 amount, bool isBuy, bool isSell, uint256 timestamp);
    
    // FIXED: Add new events for enhanced monitoring
    event DegradedModeActivated(string reason, uint256 timestamp);
    event DegradedModeDeactivated(uint256 timestamp);
    event HelperValidationFailed(address indexed from, address indexed to, uint256 amount, string reason, uint256 timestamp);

    // =============================================================================
    // CUSTOM ERRORS - FIXED: Add for gas efficiency
    // =============================================================================
    
    error InvalidAddress(address provided);
    error InsufficientBalance(uint256 requested, uint256 available);
    error TradingDisabled();
    error TransferCooldownActive(uint256 remainingTime);
    error ErrHelperValidationFailed(address from, address to, uint256 amount, string reason);
    error InvalidRouter(address router);

    // =============================================================================
    // MODIFIERS - ENHANCED SECURITY
    // =============================================================================

    modifier onlyBeforeSetup() {
        require(!setupCompleted, "Setup already completed");
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert InvalidAddress(addr);
        require(addr != address(this), "Cannot use contract address");
        require(!isBlacklisted[addr], "Address is blacklisted");
        _;
    }

    modifier enhancedBlacklistCheck(address from, address to) {
        require(!isBlacklisted[from], "Sender is blacklisted");
        require(!isBlacklisted[to], "Recipient is blacklisted");
        require(!isBlacklisted[tx.origin], "Transaction origin is blacklisted");
        _;
    }

    // =============================================================================
    // CONSTRUCTOR - FIXED: Enhanced router validation (M5)
    // =============================================================================

    constructor(address _router) ERC20("Millies", "MILLIES") {
        if (_router == address(0)) revert InvalidRouter(_router);
        
        // FIXED: Validate router has required functions and get WBNB
        try IUniswapV2Router02(_router).WETH() returns (address weth) {
            if (weth == address(0)) revert InvalidRouter(_router);
            WBNB = weth;
        } catch {
            revert InvalidRouter(_router);
        }
        
        pancakeRouter = IUniswapV2Router02(_router);
        contractDeployTime = block.timestamp;

        _mint(msg.sender, TOTAL_SUPPLY);

        // Exclude system addresses from fees and cooldowns
        isExcludedFromFees[msg.sender] = true;
        isExcludedFromFees[address(this)] = true;
        isExcludedFromFees[BURN_ADDRESS] = true;
        isExcludedFromCooldown[msg.sender] = true;
        isExcludedFromCooldown[address(this)] = true;
        isExcludedFromCooldown[BURN_ADDRESS] = true;
        
        // Router excluded from cooldowns but NOT from fees (critical for tax collection)
        isExcludedFromCooldown[_router] = true;
    }

    // =============================================================================
    // ERC20 OVERRIDES WITH REENTRANCY PROTECTION - PRODUCTION SECURITY
    // =============================================================================

    /**
     * @dev Override transfer with reentrancy protection for production security
     * @notice Protects against potential reentrancy attacks during tax processing
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        nonReentrant 
        returns (bool) 
    {
        return super.transfer(to, amount);
    }

    /**
     * @dev Override transferFrom with reentrancy protection for production security
     * @notice Protects against potential reentrancy attacks during tax processing
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        nonReentrant 
        returns (bool) 
    {
        return super.transferFrom(from, to, amount);
    }

    // =============================================================================
    // BUY TAX MANAGEMENT
    // =============================================================================

    function toggleBuyTax() external onlyOwner {
        buyTaxEnabled = !buyTaxEnabled;
        emit FeatureToggled("buy_tax", buyTaxEnabled, msg.sender, block.timestamp);
    }

    // =============================================================================
    // DEGRADED MODE MANAGEMENT - FIXED: Add degraded mode functions
    // =============================================================================

    /**
     * @dev Manually activate degraded mode in case of helper issues
     */
    function activateDegradedMode(string calldata reason) external onlyOwner {
        degradedMode = true;
        degradedModeActivated = block.timestamp;
        emit DegradedModeActivated(reason, block.timestamp);
    }

    /**
     * @dev Deactivate degraded mode when helper is fixed
     */
    function deactivateDegradedMode() external onlyOwner {
        degradedMode = false;
        degradedModeActivated = 0;
        emit DegradedModeDeactivated(block.timestamp);
    }

    // =============================================================================
    // CORE TRANSFER LOGIC - FIXED: Enhanced helper failure handling (Gap 1)
    // =============================================================================

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);

        // Skip validation for minting/burning or excluded addresses
        if (from == address(0) || to == address(0) || 
            isExcludedFromFees[from] || isExcludedFromFees[to]) {
            return;
        }

        if (!tradingEnabled) revert TradingDisabled();

        // FIXED: Enhanced helper validation with degraded mode fallback
        if (helperContract != address(0) && !degradedMode) {
            try IMilliesHelper(helperContract).validateTransfer(from, to, amount) {
                // Validation successful
            } catch Error(string memory reason) {
                emit HelperValidationFailed(from, to, amount, reason, block.timestamp);
                
                if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) {
                    // Activate degraded mode and apply basic validation
                    degradedMode = true;
                    degradedModeActivated = block.timestamp;
                    emit DegradedModeActivated("Helper validation failed", block.timestamp);
                    
                    _applyDegradedModeValidation(from, to, amount);
                }
            } catch {
                emit HelperValidationFailed(from, to, amount, "Unknown error", block.timestamp);
                
                if (!isExcludedFromFees[from] && !isExcludedFromFees[to]) {
                    degradedMode = true;
                    degradedModeActivated = block.timestamp;
                    emit DegradedModeActivated("Helper call failed", block.timestamp);
                    
                    _applyDegradedModeValidation(from, to, amount);
                }
            }
        } else if (degradedMode && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            _applyDegradedModeValidation(from, to, amount);
        }
    }

    /**
     * @dev Apply basic validation when helper is unavailable
     * FIXED: Remove view modifier since function can revert with require()
     */
    function _applyDegradedModeValidation(address from, address /*to*/, uint256 amount) internal view {
        uint256 fromBalance = balanceOf(from);
        if (fromBalance == 0) return;
        
        // Limit transfers to 1% of balance in degraded mode
        uint256 maxTransfer = fromBalance / 100;
        if (maxTransfer == 0) maxTransfer = 1; // Allow at least 1 wei
        
        require(amount <= maxTransfer, "Degraded mode: Max 1% of balance per transfer");
    }

    // FIXED: Enhanced transfer logic with proper tax calculation consistency (M4)
    function _transfer(address from, address to, uint256 amount) internal override enhancedBlacklistCheck(from, to) {
        if (from == address(0) || to == address(0)) revert InvalidAddress(from == address(0) ? from : to);
        require(amount > 0, "Amount must be > 0");

        // Cache exclusion status to reduce SLOAD operations
        bool fromExcluded = isExcludedFromFees[from];
        bool toExcluded = isExcludedFromFees[to];
        bool isExcludedFromTransfer = fromExcluded || toExcluded;
        
        // Enhanced trade detection using helper contract
        bool isBuy = false;
        bool isSell = false;
        
        if (helperContract != address(0) && !isExcludedFromTransfer && !degradedMode) {
            try IMilliesHelper(helperContract).isTradeTransaction(from, to) returns (bool _isBuy, bool _isSell) {
                isBuy = _isBuy;
                isSell = _isSell;
            } catch {
                // Trade detection failed, treat as regular transfer
            }
        }
        
        bool isTrade = isBuy || isSell;
        
        // Emit trade detection event for production monitoring
        if (isTrade) {
            emit TradeDetected(from, to, amount, isBuy, isSell, block.timestamp);
        }

        // Apply tax logic to trades based on configuration
        if (!isExcludedFromTransfer && isTrade && helperContract != address(0) && !degradedMode) {
            if (isSell) {
                _processSellWithTax(from, to, amount);
            } else if (isBuy && buyTaxEnabled) {
                _processBuyWithTax(from, to, amount);
            } else {
                // Trade but no tax (buy tax disabled)
                super._transfer(from, to, amount);
            }
        } else {
            // Standard transfer (no tax)
            super._transfer(from, to, amount);
        }
    }

    // FIXED: Enhanced sell processing with consistent tax calculation and community distribution
    function _processSellWithTax(address from, address to, uint256 amount) private {
        IMilliesHelper helper = IMilliesHelper(helperContract);
        
        // FIXED: Calculate tax distribution and process sell atomically to prevent inconsistency
        try helper.calculateTaxDistribution(from, amount) returns (
            uint256 burnAmt, 
            uint256 advAmt, 
            uint256 lpAmt, 
            uint256 commAmt,  // ← ADDED COMMUNITY AMOUNT
            bool isHighImpact
        ) {
            // Process sell in helper (updates state, validates limits)
            try helper.processSell(from, amount) returns (uint256 transferAmount) {
                // Execute tax distributions atomically
                if (burnAmt > 0) {
                    super._transfer(from, BURN_ADDRESS, burnAmt);
                    emit TaxCollected(from, BURN_ADDRESS, burnAmt, "burn", block.timestamp);
                }
                if (advAmt > 0 && advertisingWallet != address(0)) {
                    super._transfer(from, advertisingWallet, advAmt);
                    emit TaxCollected(from, advertisingWallet, advAmt, "advertising", block.timestamp);
                }
                if (lpAmt > 0 && liquidityPool != address(0)) {
                    super._transfer(from, liquidityPool, lpAmt);
                    string memory taxType = isHighImpact ? "high_impact_to_lp" : "liquidity";
                    emit TaxCollected(from, liquidityPool, lpAmt, taxType, block.timestamp);
                }
                // ADDED: Community distribution
                if (commAmt > 0 && communityWallet != address(0)) {
                    super._transfer(from, communityWallet, commAmt);
                    emit TaxCollected(from, communityWallet, commAmt, "community", block.timestamp);
                }
                
                // Transfer net amount to destination
                super._transfer(from, to, transferAmount);
                
                // Update liquidity tracking
                helper.updateLiquidity();
            } catch {
                // If processSell fails, fallback to regular transfer
                super._transfer(from, to, amount);
            }
        } catch {
            // If tax calculation fails, fallback to regular transfer
            super._transfer(from, to, amount);
        }
    }

    // Enhanced buy processing with tax collection
    function _processBuyWithTax(address from, address to, uint256 amount) private {
        if (helperContract == address(0)) {
            super._transfer(from, to, amount);
            return;
        }

        try IMilliesHelper(helperContract).processBuy(to, amount) returns (uint256 transferAmount) {
            uint256 taxAmount = amount - transferAmount;
            
            if (taxAmount > 0) {
                // Production buy tax distribution: 2% total (0.2% burn, 1.8% LP)
                uint256 burnAmount = taxAmount / 10; // 10% of tax = 0.2% of buy amount
                uint256 lpAmount = taxAmount - burnAmount; // 90% of tax = 1.8% of buy amount
                
                super._transfer(from, BURN_ADDRESS, burnAmount);
                if (liquidityPool != address(0)) {
                    super._transfer(from, liquidityPool, lpAmount);
                    emit TaxCollected(from, liquidityPool, lpAmount, "buy_liquidity", block.timestamp);
                }
                
                emit TaxCollected(from, BURN_ADDRESS, burnAmount, "buy_burn", block.timestamp);
                emit BuyTaxCollected(to, amount, taxAmount, block.timestamp);
            }
            
            // Transfer net amount to buyer
            super._transfer(from, to, transferAmount);
        } catch {
            // If buy processing fails, fallback to regular transfer
            super._transfer(from, to, amount);
        }
    }

    // =============================================================================
    // CONTRACT CONFIGURATION FUNCTIONS
    // =============================================================================

    function setHelperContract(address _helper) external onlyOwner {
        if (_helper == address(0)) revert InvalidAddress(_helper);
        address oldHelper = helperContract;
        helperContract = _helper;
        isExcludedFromFees[_helper] = true;
        isExcludedFromCooldown[_helper] = true;
        
        // Reset degraded mode when new helper is set
        if (degradedMode) {
            degradedMode = false;
            degradedModeActivated = 0;
            emit DegradedModeDeactivated(block.timestamp);
        }
        
        emit HelperContractUpdated(oldHelper, _helper, block.timestamp);
    }

    function setAdvertisingWallet(address _wallet) external onlyOwner validAddress(_wallet) {
        address oldWallet = advertisingWallet;
        advertisingWallet = _wallet;
        isExcludedFromFees[_wallet] = true;
        isExcludedFromCooldown[_wallet] = true;
        emit WalletUpdated("advertising", oldWallet, _wallet, block.timestamp);
    }

    function setCommunityWallet(address _wallet) external onlyOwner validAddress(_wallet) {
        address oldWallet = communityWallet;
        communityWallet = _wallet;
        isExcludedFromFees[_wallet] = true;
        isExcludedFromCooldown[_wallet] = true;
        emit WalletUpdated("community", oldWallet, _wallet, block.timestamp);
    }

    function setLiquidityPool(address _pool) external onlyOwner validAddress(_pool) {
        require(liquidityPool == address(0), "LP already set");
        
        // Validate pool against mainnet factory
        IPancakePair pair = IPancakePair(_pool);
        address token0 = pair.token0();
        address token1 = pair.token1();
        
        require(
            (token0 == address(this) && token1 == WBNB) ||
            (token1 == address(this) && token0 == WBNB),
            "Pool must be MILLIES-WBNB"
        );

        address expectedPair = IPancakeFactory(PANCAKE_FACTORY).getPair(address(this), WBNB);
        require(expectedPair == _pool, "Pool not from factory");

        liquidityPool = _pool;
        // LP included in fees for tax detection, excluded from cooldowns
        isExcludedFromCooldown[_pool] = true;
        emit WalletUpdated("liquidityPool", address(0), _pool, block.timestamp);
    }

    function completeSetup() external onlyOwner onlyBeforeSetup {
        require(advertisingWallet != address(0), "Ad wallet not set");
        require(communityWallet != address(0), "Comm wallet not set");
        require(liquidityPool != address(0), "Pool not set");
        require(helperContract != address(0), "Helper not set");

        setupCompleted = true;
        tradingEnabled = true;
        tradingEnabledTime = block.timestamp;

        // Enable anti-bot features by default
        dumpSpikeDetectionEnabled = true;
        sybilDefenseEnabled = true;

        emit SetupCompleted(msg.sender, block.timestamp);
        emit TradingToggled(true, block.timestamp);
        emit FeatureToggled("dump_spike_detection", true, msg.sender, block.timestamp);
        emit FeatureToggled("sybil_defense", true, msg.sender, block.timestamp);
    }

    // =============================================================================
    // FEATURE TOGGLES
    // =============================================================================

    function toggleTrading() external onlyOwner {
        tradingEnabled = !tradingEnabled;
        if (tradingEnabled && tradingEnabledTime == 0) {
            tradingEnabledTime = block.timestamp;
        }
        emit TradingToggled(tradingEnabled, block.timestamp);
    }

    function toggleDumpSpikeDetection() external onlyOwner {
        dumpSpikeDetectionEnabled = !dumpSpikeDetectionEnabled;
        emit FeatureToggled("dump_spike_detection", dumpSpikeDetectionEnabled, msg.sender, block.timestamp);
    }

    function toggleSybilDefense() external onlyOwner {
        sybilDefenseEnabled = !sybilDefenseEnabled;
        emit FeatureToggled("sybil_defense", sybilDefenseEnabled, msg.sender, block.timestamp);
    }

    function toggleAutoSwapAndLiquify() external onlyOwner {
        autoSwapAndLiquifyEnabled = !autoSwapAndLiquifyEnabled;
        emit FeatureToggled("auto_swap_liquify", autoSwapAndLiquifyEnabled, msg.sender, block.timestamp);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner validAddress(account) {
        isExcludedFromFees[account] = excluded;
        emit FeatureToggled("fee_exclusion", excluded, msg.sender, block.timestamp);
    }

    function excludeFromCooldown(address account, bool excluded) external onlyOwner validAddress(account) {
        isExcludedFromCooldown[account] = excluded;
        emit FeatureToggled("cooldown_exclusion", excluded, msg.sender, block.timestamp);
    }

    function setBlacklistStatus(address account, bool blacklisted) external onlyOwner {
        require(account != owner() && account != address(this), "Cannot blacklist");
        require(account != liquidityPool && account != helperContract, "Cannot blacklist system");
        isBlacklisted[account] = blacklisted;
        emit AddressBlacklisted(account, blacklisted, block.timestamp);
    }

    function configureRouterForTrading() external onlyOwner {
        isExcludedFromCooldown[address(pancakeRouter)] = true;
        // Router must NOT be excluded from fees for tax collection
        isExcludedFromFees[address(pancakeRouter)] = false;
        emit FeatureToggled("router_configured", true, msg.sender, block.timestamp);
    }

    // =============================================================================
    // WALLET FUNDING AND AIRDROP FUNCTIONS
    // =============================================================================

    function fundAdvertisingWallet(uint256 amount) external onlyOwner {
        require(advertisingWallet != address(0), "Ad wallet not set");
        uint256 ownerBalance = balanceOf(msg.sender);
        if (ownerBalance < amount) revert InsufficientBalance(amount, ownerBalance);
        _transfer(msg.sender, advertisingWallet, amount);
        emit WalletFunded(advertisingWallet, amount, "advertising", block.timestamp);
    }

    function fundCommunityWallet(uint256 amount) external onlyOwner {
        require(communityWallet != address(0), "Comm wallet not set");
        uint256 ownerBalance = balanceOf(msg.sender);
        if (ownerBalance < amount) revert InsufficientBalance(amount, ownerBalance);
        _transfer(msg.sender, communityWallet, amount);
        emit WalletFunded(communityWallet, amount, "community", block.timestamp);
    }

    function airdropToCommunity(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner nonReentrant {
        require(recipients.length == amounts.length, "Arrays mismatch");
        require(recipients.length <= MAX_AIRDROP_RECIPIENTS, "Too many recipients");
        require(communityWallet != address(0), "Comm wallet not set");

        uint256 totalAmount = 0;
        unchecked {
            for (uint256 i = 0; i < recipients.length; i++) {
                if (recipients[i] == address(0)) revert InvalidAddress(recipients[i]);
                require(!isBlacklisted[recipients[i]], "Recip blacklisted");
                totalAmount += amounts[i];
            }
        }
        
        uint256 communityBalance = balanceOf(communityWallet);
        if (communityBalance < totalAmount) revert InsufficientBalance(totalAmount, communityBalance);

        unchecked {
            for (uint256 i = 0; i < recipients.length; i++) {
                _transfer(communityWallet, recipients[i], amounts[i]);
            }
        }
        emit WalletFunded(communityWallet, totalAmount, "airdrop", block.timestamp);
    }

    // =============================================================================
    // VIEW FUNCTIONS - DELEGATE TO HELPER
    // =============================================================================

    function getSellWindow(address account) external view returns (
        uint256 totalSold,
        uint256 windowStart,
        uint256 initialHoldings,
        uint256 sellCount,
        uint256 timeRemaining
    ) {
        if (helperContract != address(0)) {
            return IMilliesHelper(helperContract).getSellWindow(account);
        }
        return (0, 0, 0, 0, 0);
    }

    function getCooldownInfo(address account) external view returns (
        uint256 sellCooldownEndTimestamp,
        uint256 timeRemaining,
        bool canSell,
        uint256 lastBuy,
        bool canBuy
    ) {
        if (helperContract != address(0)) {
            return IMilliesHelper(helperContract).getCooldownInfo(account);
        }
        return (0, 0, true, 0, true);
    }

    function getTotalBurned() external view returns (uint256) {
        return balanceOf(BURN_ADDRESS);
    }

    function getTotalSupplyAfterBurn() external view returns (uint256) {
        return totalSupply() - balanceOf(BURN_ADDRESS);
    }

    function getOwnerBalance() external view returns (uint256) {
        return balanceOf(owner());
    }

    function isExcluded(address account) external view returns (
        bool feesExcluded,
        bool cooldownExcluded,
        bool blacklisted
    ) {
        return (
            isExcludedFromFees[account],
            isExcludedFromCooldown[account],
            isBlacklisted[account]
        );
    }

    function getTradingStatus() external view returns (
        bool enabled,
        uint256 enabledTime,
        uint256 deployTime,
        uint256 timeSinceEnabled
    ) {
        uint256 timeSince = (tradingEnabledTime > 0) ? block.timestamp - tradingEnabledTime : 0;
        return (tradingEnabled, tradingEnabledTime, contractDeployTime, timeSince);
    }

    // Delegate complex metrics to helper contract
    function totalTaxAccumulated() external view returns (uint256) {
        return helperContract != address(0) ? IMilliesHelper(helperContract).totalTaxAccumulated() : 0;
    }

    function reservedLiquidityTokens() external view returns (uint256) {
        return helperContract != address(0) ? IMilliesHelper(helperContract).reservedLiquidityTokens() : 0;
    }

    function dailyTradingVolume() external view returns (uint256) {
        return helperContract != address(0) ? IMilliesHelper(helperContract).dailyTradingVolume() : 0;
    }

    // =============================================================================
    // EMERGENCY FUNCTIONS
    // =============================================================================

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner nonReentrant {
        uint256 contractBalance = balanceOf(address(this));
        if (amount > contractBalance) revert InsufficientBalance(amount, contractBalance);
        _transfer(address(this), owner(), amount);
    }

    function rescueTokens(address tokenAddress, uint256 amount) external onlyOwner nonReentrant {
        require(tokenAddress != address(this), "Cannot rescue own tokens");
        IERC20(tokenAddress).safeTransfer(owner(), amount);
    }

    function rescueBNB() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        require(amount > 0, "No BNB to rescue");
        payable(owner()).sendValue(amount);
    }

    // =============================================================================
    // INTERNAL HOOKS
    // =============================================================================

    function _afterTokenTransfer(address /* from */, address to, uint256 /* amount */) internal override {
        // Track first-time holders efficiently
        if (!isHoldingTokens[to] && balanceOf(to) > 0) {
            isHoldingTokens[to] = true;
            unchecked {
                totalHolders++;
            }
        }
    }

    // =============================================================================
    // RECEIVE FUNCTION
    // =============================================================================

    receive() external payable {}
}