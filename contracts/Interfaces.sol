//fileName: Interfaces.sol - SECURITY FIXED VERSION
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19; // FIXED: L1 - Use fixed pragma instead of floating

/**
 * @title Interfaces
 * @dev Production-ready shared interfaces for MilliesToken ecosystem
 * @notice Verified compatible with BSC mainnet PancakeSwap contracts - SECURITY FIXED VERSION
 */

// ✅ MAINNET COMPATIBLE: Standard PancakeSwap V2 Router interface
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

// ✅ MAINNET COMPATIBLE: Standard PancakeSwap V2 Factory interface
interface IPancakeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

// ✅ MAINNET COMPATIBLE: Standard PancakeSwap V2 Pair interface
interface IPancakePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

// ✅ PRODUCTION NOTE: These interfaces are standard across all networks
// They work identically on BSC mainnet, testnet, and other EVM chains
// No network-specific modifications required