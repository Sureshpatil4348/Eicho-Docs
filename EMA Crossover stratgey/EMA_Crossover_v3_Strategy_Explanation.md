# EMA Grid Recovery EA v3 Strategy Explained

## 1. Overview

The EMA Grid Recovery EA is a sophisticated automated trading strategy for the MetaTrader 4 platform. Its core design revolves around initiating trades based on a primary trend-following signal and then intelligently managing the position using a grid and recovery system if the market moves against the initial entry.

The EA is highly versatile, offering two distinct entry strategies (EMA Crossover and Bollinger Bands), an advanced bidirectional "flip-and-recover" mode, and features that adapt to market volatility using ATR and capitalize on trends using an RSI-based continuation system.

---

## 2. Core Trading Strategies

The EA's entry logic is based on one of two user-selected strategies.

### 2.1. Strategy 1: EMA Crossover (Default)

This is a classic trend-following strategy.

-   **Indicators Used**: A Fast Exponential Moving Average (EMA) and a Slow EMA.
-   **Buy Signal**: A "bullish crossover" occurs when the **Fast EMA crosses ABOVE the Slow EMA** on the close of a price bar. This signals the start of a potential uptrend.
-   **Sell Signal**: A "bearish crossover" occurs when the **Fast EMA crosses BELOW the Slow EMA** on the close of a price bar. This signals a potential downtrend and is used as an exit signal for buy trades or an entry signal for sell trades.

### 2.2. Strategy 2: Bollinger Bands

This strategy uses price breakouts relative to the Bollinger Bands.

-   **Indicators Used**: Bollinger Bands (Upper, Middle, Lower).
-   **Buy Signal**: Triggered when the price closes **ABOVE the selected `BB_EntryLevel`** (either the Upper Band for breakouts or the Middle Band for trend resumption).
-   **Sell Signal**: Triggered when the price closes **BELOW the selected `BB_ExitLevel`** (either the Middle Band for a trend change or the Lower Band for a strong down-move).

---

## 3. Trade Management Engine

This is the heart of the EA, dictating how it manages trades after entry.

### 3.1. The Trading Sequence

-   A "sequence" begins with an **Initial Trade**.
-   If the trade moves into drawdown, it can be followed by a series of **Grid Trades**.
-   The sequence ends when all trades are closed, either in profit or at a loss to initiate a recovery.

### 3.2. Grid System

The grid is a defensive mechanism to manage losing positions.

-   **Activation**: If the price moves against the initial trade by the `GridDistance`, the grid system activates and opens a new trade in the same direction.
-   **Lot Sizing**: Subsequent grid trades can have their lot size increased by the `LotMultiplier`. This martingale approach is moderated by `GridTradesForMultiplier`, which requires several grid trades before the multiplier kicks in.
-   **Averaged Take Profit**: After each new grid trade, the EA calculates a new, single take-profit level for *all* open trades in the sequence. This level is based on the volume-weighted average entry price. This allows the entire basket of trades to close in profit with a smaller price reversal than would be needed for the initial trade alone.

### 3.3. Recovery & Bidirectional Logic

This is the EA's primary risk management and reversal strategy.

-   **Standard Recovery**: If a sequence closes at a loss, the EA enters "Recovery Mode". The next trading sequence will use a larger initial lot size, calculated to recoup the previous loss plus a small profit (`RecoveryProfit`).

-   **Bi-Directional "Flip & Recover"** (when `TradeDirectionMode = MODE_BOTH_DIRECTIONS`): This is the most dynamic feature.
    -   If the EA has an open sequence (e.g., BUY trades) and receives a strong signal in the *opposite* direction (e.g., a bearish EMA crossover), it executes a "flip".
    -   **Action**: It immediately closes all open buy trades, accepting the loss. It then instantly opens a new SELL sequence.
    -   **Logic**: The initial lot size for this new sell sequence is calculated to recover the loss from the closed buy trades. This allows the EA to stop fighting a strong trend reversal and instead attempt to profit from it.

---

## 4. Special Features

### 4.1. ATR-Based Volatility Adjustment

When `UseATR` is enabled, the EA adapts to market volatility.

-   **Function**: It uses the Average True Range (ATR) indicator to dynamically set the `GridDistance` and `InitialTakeProfit`.
-   **Benefit**: In volatile markets, grid levels and take profits are automatically set wider to reduce the risk of being stopped out or over-trading. In quiet markets, they are set tighter to capture smaller moves.

### 4.2. RSI Continuation

This feature is designed to capitalize on strong, trending markets.

-   **Activation**: After an *initial trade* (not a grid trade) closes successfully, the EA checks if it can re-enter to continue riding the trend.
-   **Conditions**:
    1.  The primary trend signal is still valid (e.g., Fast EMA is still above Slow EMA).
    2.  The RSI on a higher timeframe (`RSI_Timeframe`) is **not overbought**, indicating a pullback or pause, which is a safer entry point.
    3.  The `MaxContinuationTrades` limit has not been reached.
-   **Waiting for RSI**: If the trend is still valid but RSI is overbought, the EA will pause and wait for RSI to drop below the threshold before placing the next continuation trade.

---

## 5. Input Parameters Explained

### Group: `=== Strategy Selection ===`
-   **`EntryStrategy`**: Choose the core logic: `STRATEGY_EMA_CROSSOVER` or `STRATEGY_BOLLINGER_BANDS`.
-   **`TradeDirectionMode`**: Defines the trading logic.
    -   `MODE_BUY_ONLY`: Only takes buy signals.
    -   `MODE_SELL_ONLY`: Only takes sell signals.
    -   `MODE_BOTH_DIRECTIONS`: Enables the full "Flip & Recover" logic.

### Group: `=== EMA Settings ===`
-   **`FastEMA_Period`**: The lookback period for the faster Exponential Moving Average.
-   **`SlowEMA_Period`**: The lookback period for the slower Exponential Moving Average.
-   **`EMA_Price`**: The price (Close, Open, etc.) used for EMA calculations.

### Group: `=== Bollinger Bands Settings ===`
-   **`BB_Period`**: The lookback period for the Bollinger Bands calculation.
-   **`BB_Deviation`**: The standard deviation multiplier for the bands.
-   **`BB_Price`**: The price used for the BB calculation.
-   **`BB_EntryLevel`**: The band that triggers a BUY entry when crossed (`BB_ENTRY_UPPER` or `BB_ENTRY_MIDDLE`).
-   **`BB_ExitLevel`**: The band that triggers a SELL/CLOSE signal when crossed (`BB_EXIT_MIDDLE` or `BB_EXIT_LOWER`).

### Group: `=== Trade Settings ===`
-   **`InitialLotSize`**: The starting lot size for the first trade of a new cycle.
-   **`InitialTakeProfit`**: The take profit in pips for the initial trade (only if ATR is disabled).
-   **`GridDistance`**: The distance in pips between grid trades (only if ATR is disabled).
-   **`LotMultiplier`**: The factor to multiply the lot size for grid trades (e.g., 1.5x).
-   **`GridTradesForMultiplier`**: How many grid trades to place *before* the `LotMultiplier` is first applied. A value of 3 means the 4th grid trade will be the first to have its lots multiplied.
-   **`RecoveryProfit`**: Extra profit in pips to target during a recovery sequence.

### Group: `=== ATR Settings ===`
-   **`UseATR`**: `true` enables the dynamic volatility adjustment.
-   **`ATR_Period`**: The lookback period for the ATR indicator.
-   **`ATR_TP_Timeframe`**: The chart timeframe to use for the take profit ATR calculation.
-   **`ATR_Grid_Timeframe`**: The chart timeframe to use for the grid distance ATR calculation.
-   **`ATR_TP_Multiplier`**: The ATR value is multiplied by this number to set the take profit distance.
-   **`ATR_Grid_Multiplier`**: The ATR value is multiplied by this number to set the grid distance.

### Group: `=== RSI Continuation Settings ===`
-   **`EnableRSIContinuation`**: `true` enables the trend-riding feature.
-   **`RSI_Period`**: The lookback period for the RSI indicator.
-   **`RSI_Timeframe`**: The (usually higher) timeframe for the RSI check, to gauge the larger trend's strength.
-   **`RSI_OverboughtLevel`**: The RSI level (e.g., 70) above which the EA considers the market overbought and will pause before entering a new buy trade.
-   **`MaxContinuationTrades`**: The maximum number of consecutive initial trades the EA will place in a single trend. Set to 0 for unlimited.

### Group: `=== System Settings ===`
-   **`MagicNumber`**: A unique ID to ensure the EA only manages its own trades.
-   **`Slippage`**: The maximum allowed price deviation in pips for order execution.
-   **`EnableLogging`**: `true` to print detailed operational logs in the MT4 "Experts" tab for monitoring. 