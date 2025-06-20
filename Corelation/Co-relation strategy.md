# Correlation & RSI Divergence Trading Strategy Guide

This document provides a detailed explanation of the Correlation & RSI Divergence trading strategy, its underlying logic, and all configurable parameters.

## 1. Strategy Overview

The core of this system is a **statistical arbitrage** (or **pairs trading**) strategy designed for the Forex market. It operates on the principle of **mean reversion**. The strategy identifies two currency pairs that have a historically high correlation, meaning their prices tend to move together.

The fundamental idea is to monitor these two pairs and wait for a temporary breakdown in their correlation—a moment when their prices diverge significantly. When this divergence occurs, the strategy enters two opposing trades (one long, one short) with the expectation that the pair's prices will eventually revert to their historical mean, allowing the trades to be closed for a profit.

The strategy uses the **Relative Strength Index (RSI)** as a secondary confirmation tool to time the entry precisely, ensuring it trades in the direction of the divergence.

## 2. How the Strategy Works

The strategy follows a clear, rules-based process for entering and exiting trades.

### Entry Conditions

A trade is only initiated when **all** of the following conditions are met:

1.  **Correlation Breakdown**: The rolling correlation between the two selected currency pairs drops **below** the `Entry Threshold` you define. For example, if two pairs are usually 90% correlated and the threshold is set to 0.70, the strategy sees a potential opportunity when the correlation falls to 69% or lower.

2.  **RSI Divergence Confirmation**: Once the correlation condition is met, the strategy checks the RSI values of both pairs to confirm that they are moving away from each other.
    *   **Short Entry**: If Pair A's RSI is above the `RSI Overbought` level AND Pair B's RSI is below the `RSI Oversold` level, the strategy will **SELL Pair A** and **BUY Pair B**.
    *   **Long Entry**: If Pair A's RSI is below the `RSI Oversold` level AND Pair B's RSI is above the `RSI Overbought` level, the strategy will **BUY Pair A** and **SELL Pair B**.

3.  **Cooldown Period**: The strategy will not open a new trade if it is still within the `Cooldown Period` (defined in hours) from the last trade's entry. This prevents over-trading.

### Exit Conditions

The strategy will close an open pair trade based on a "whichever comes first" logic between two primary exit signals:

1.  **Take Profit Level Hit (New Feature)**: A `Take Profit` value (defined in pips or points) can be set. The strategy continuously calculates the combined profit/loss of the two open positions. If the combined profit reaches the specified `Take Profit` level, both trades are closed immediately.

2.  **Correlation Recovery**: The strategy monitors the correlation that triggered the entry. If this correlation recovers and rises **above** the `Exit Threshold`, the strategy will close the trade, **provided the combined position is profitable**. If the position is at a loss, it will hold the trade, waiting for it to become profitable or for the Take Profit level to be hit.

The exit condition is designed to be flexible: **the trade is closed as soon as either the Take Profit is reached OR the correlation recovers while the trade is profitable.**

## 3. Detailed Input Parameters

This section explains every configuration option available in the Strategy Parameters interface.

#### Strategy Name
*   **Description**: A user-friendly name to identify your strategy configuration.
*   **Example**: `AUDNZD Mean Reversion`

#### Currency Pair 1 / Currency Pair 2
*   **Description**: The two currency pair symbols you want the strategy to monitor and trade. These should be pairs you have identified as having a historical correlation.
*   **Example**: `AUDCAD`, `NZDCAD`

#### Lot Size for Pair 1 / Lot Size for Pair 2
*   **Description**: The trading volume (lot size) for each respective currency pair. It is often best to keep these values equal unless you have a specific reason to weigh one pair more heavily.
*   **Example**: `0.05`, `0.05`

#### Time Frame
*   **Description**: The chart timeframe on which the strategy's calculations are based.
*   **Options**: `M1`, `M5`, `M15`, `M30`, `H1`, `H4`, `D1`.

#### Magic Number
*   **Description**: A unique integer used to "tag" all orders placed by this specific strategy instance. This is critical for preventing the strategy from interfering with manual trades or other automated strategies running on the same account.
*   **Example**: `10101`

#### Trade Comment
*   **Description**: A custom text comment that will be attached to every trade executed by the strategy.
*   **Example**: `CorrelationBot v1.2`

#### RSI Period
*   **Description**: The lookback period (number of candles) used for calculating the Relative Strength Index (RSI).
*   **Default**: `14`

#### Correlation Window
*   **Description**: The lookback period (number of candles) used for calculating the rolling correlation between the two pairs.
*   **Default**: `10`

#### RSI Overbought / RSI Oversold
*   **Description**: The RSI levels that define overbought and oversold conditions.
    *   `RSI Overbought`: An asset is considered overbought if its RSI is **above** this value. (Default: `70`)
    *   `RSI Oversold`: An asset is considered oversold if its RSI is **below** this value. (Default: `30`)

#### Entry Threshold
*   **Description**: The correlation value that must be breached to the downside for a trade entry to be considered. The strategy looks for an entry when `current_correlation < Entry Threshold`.
*   **Range**: `-1.0` to `1.0`. A value like `0.7` is a common starting point for positively correlated pairs.

#### Exit Threshold
*   **Description**: The correlation value that signals a potential trade exit. The strategy looks to exit when `current_correlation > Exit Threshold` (and the trade is profitable).
*   **Range**: `-1.0` to `1.0`. This should typically be higher than the `Entry Threshold`, e.g., `0.85`.

#### Take Profit (New Feature)
*   **Description**: The total combined profit in pips for the pair trade that will trigger an immediate exit.
*   **Example**: A value of `50` would mean the strategy closes both trades as soon as their combined profit reaches 50 pips.

#### Starting Balance
*   **Description**: The initial amount of capital to be used for a backtest simulation.
*   **Example**: `10000`

## 4. Calculation Deep Dive

### Rolling Correlation
Correlation measures the degree to which two assets move in relation to each other. It is expressed as a value between -1.0 and +1.0.
*   **+1.0**: Perfect positive correlation (prices move in the same direction).
*   **-1.0**: Perfect negative correlation (prices move in opposite directions).
*   **0.0**: No correlation.

The strategy uses a **rolling correlation**, which is calculated over the last 'N' periods, where 'N' is the `Correlation Window`. The calculation is performed by taking the closing prices of both pairs for the last 'N' candles and applying a standard Pearson correlation formula. This gives a dynamic correlation value that adapts to recent market behavior.

### Relative Strength Index (RSI)
RSI is a momentum oscillator that measures the speed and change of price movements. It oscillates between 0 and 100 and is used to identify overbought or oversold conditions.
*   **Overbought (RSI > 70)**: Suggests the asset may be due for a price pullback.
*   **Oversold (RSI < 30)**: Suggests the asset may be due for a price rebound.

The strategy uses RSI to confirm that the two pairs are not just decorrelated, but are actively moving apart, providing a stronger signal for entry.

## 5. Example Trade Scenario

Let's walk through a hypothetical trade.

**Parameters:**
*   Pair 1: `AUDUSD`, Pair 2: `NZDUSD`
*   Entry Threshold: `0.7`
*   Exit Threshold: `0.85`
*   Take Profit: `100` pips
*   RSI Overbought: `70`, RSI Oversold: `30`

**Trade Execution:**
1.  **Monitoring**: The `AUDUSD`/`NZDUSD` pair normally has a correlation of `0.90`.
2.  **Entry Signal**: The correlation suddenly drops to `0.65`, which is below the `0.7` entry threshold. The strategy now checks the RSI values.
3.  **Confirmation**: `AUDUSD` RSI is `75` (overbought), and `NZDUSD` RSI is `25` (oversold).
4.  **Action**: The conditions for a short entry are met. The strategy simultaneously **SELLS AUDUSD** and **BUYS NZDUSD**.

**Exit Scenario 1: Take Profit Hit**
*   The market moves, and the combined profit of the two trades reaches **100 pips**.
*   **Action**: The strategy immediately closes both positions, securing the profit.

**Exit Scenario 2: Correlation Recovers**
*   The Take Profit is not hit, but the prices start to revert to their mean.
*   The correlation between `AUDUSD` and `NZDUSD` rises to `0.86`, which is above the `0.85` exit threshold.
*   The combined profit of the trades is currently `+65` pips.
*   **Action**: Since the correlation has recovered AND the trade is profitable, the strategy closes both positions. 