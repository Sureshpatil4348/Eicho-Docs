# Falcon V5 EA Strategy Explained

---

### 1. Overview

The Falcon V5 is an automated trading strategy (Expert Advisor) for the MetaTrader 4 platform. It is primarily a **breakout strategy** that aims to capture market volatility. It places pending `BUYSTOP` and `SELLSTOP` orders based on recent price highs and lows identified by the Fractals indicator.

The EA incorporates a sophisticated **recovery mechanism** to manage losing cycles, and includes multiple layers of risk management and trade management features, such as two different types of trailing stops, maximum drawdown protection, and configurable trading times.

---

### 2. Core Logic & Indicators

#### 2.1. Primary Indicator: Fractals

The core of the entry logic relies on the standard **Fractals indicator (`iFractals`)**.

*   At a specific time of day (defined by `TimeZone`), the EA looks for the most recent upper and lower fractal points.
*   These fractal points represent recent significant highs and lows.
*   A `BUYSTOP` order is placed slightly above the last upper fractal (`buyFractal + Buffer`).
*   A `SELLSTOP` order is placed slightly below the last lower fractal (`sellFractal - Buffer`).

If the market has already moved past these fractal levels, the EA uses the highest high or lowest low of the last `Candles` number of bars as a fallback.

#### 2.2. Entry Mechanism: Straddle Pending Orders

The strategy doesn't enter the market with an immediate market order. Instead, it sets up a "straddle" of pending orders:

1.  A `BUYSTOP` order to catch an upward breakout.
2.  A `SELLSTOP` order to catch a downward breakout.

Once one of the pending orders is triggered and becomes an active trade, the EA is designed to **cancel the opposing pending order**. For example, if the `BUYSTOP` is triggered, the `SELLSTOP` order is deleted. This ensures the EA only trades in the direction of the initial breakout.

---

### 3. Recovery System

A key feature of Falcon V5 is its recovery mode, which activates when the strategy experiences a net loss.

*   **Activation:** The EA enters "Recovery Mode" if the total profit (from closed and open trades since the cycle started) is negative.
*   **Lot Sizing:** In recovery mode, the EA can increase the lot size for subsequent trades to recover the loss faster. This is controlled by `LotIncrement` and `LotMultiplier` which are applied at intervals defined by `LotRepeater`.
*   **Take Profit:** Recovery trades use a separate, typically larger, take profit target (`RecoveryTakeProfit`) to help close the losing cycle with a net profit.
*   **Deactivation:** Once the overall profit becomes positive again, the EA exits recovery mode and reverts to the initial `Lot` size and standard `TakeProfit`.

---

### 4. Trade & Risk Management

#### 4.1. Stop Loss & Take Profit

*   **Standard TP/SL:** Each trade is placed with a `TakeProfit` and a `StopLoss` value.
*   **Opposite Order as SL (`OppoSL`):** If `OppoSL` is enabled, the stop loss for the buy order is set at the price of the sell stop order, and vice-versa. This creates a tight stop where a reversal immediately closes the trade.
*   **Maximum Drawdown (`MaxDrawDown`):** This is a critical safety feature. If the account's floating loss exceeds this percentage of the account balance, the EA will close all open positions to prevent further losses.

#### 4.2. Trailing Stop Mechanisms

The EA features two independent trailing stop systems:

1.  **Standard Trailing Stop:**
    *   **Logic:** Once a trade is in profit by `TrailingStart` pips, the stop loss is moved to lock in profit. The new stop loss level is calculated based on `TrailingStop`.
    *   **Parameters:** `TrailingStart`, `TrailingStop`.

2.  **Time-Based SL Trailing:**
    *   **Logic:** This is a more advanced trailing stop based on how long a trade has been open. It's designed to tighten the stop loss over time.
    *   After `SL_TrailingStartDuration_Hours` have passed, the stop loss begins to move.
    *   It moves by `SL_TrailDistance` pips every `SL_TrailFrequency_Hours`.
    *   The `SL_MaxTrailDifference` prevents the stop loss from moving too close to the open price.
    *   **Parameters:** `SL_TrailingStartDuration_Hours`, `SL_TrailFrequency_Hours`, `SL_TrailDistance`, `SL_MaxTrailDifference`.

---

### 5. Input Parameters Explained

#### **Lot Management**
*   `Lot` (double): The initial trading lot size for normal cycles.
*   `LotIncrement` (double): The value to add to the lot size during recovery mode.
*   `LotMultiplier` (double): The multiplier applied to the lot size during recovery mode (a value of 0 or 1 disables it).
*   `LotRepeater` (int): Determines how many recovery cycles pass before the lot size is increased. For example, a value of 2 means the lot is increased on the 2nd, 4th, 6th... recovery trade.

#### **Core Strategy Settings**
*   `Candles` (int): Number of candles to look back for highs/lows if the fractal price is invalid.
*   `Buffer` (double): Pips to add/subtract from the fractal price to set the pending order.
*   `MinDiff` (double): The minimum distance in pips required between the BuyStop and SellStop prices to place trades.
*   `MaxDiff` (double): The maximum allowed distance in pips between the BuyStop and SellStop prices.
*   `TakeProfit` (double): Take profit in pips for normal trades.
*   `StopLoss` (double): Stop loss in pips for all trades.
*   `OppoSL` (bool): If true, sets the opposite pending order's price as the stop loss.
*   `TradeMode` (int):
    *   `0`: Both Buy and Sell trades are allowed.
    *   `1`: Only Buy trades are allowed.
    *   `2`: Only Sell trades are allowed.

#### **Recovery Settings**
*   `RecoveryTakeProfit` (double): Take profit in pips used specifically for trades opened in recovery mode.

#### **Trailing Stop (Standard)**
*   `TrailingStart` (double): The profit in pips at which the trailing stop activates.
*   `TrailingStop` (double): The distance in pips the stop loss will be placed from the current price once activated.

#### **Trailing Stop (Time-Based)**
*   `SL_TrailingStartDuration_Hours` (int): Hours after a trade opens before this trailing mechanism starts.
*   `SL_TrailFrequency_Hours` (int): How often (in hours) the SL is trailed after it has started.
*   `SL_TrailDistance` (double): The distance in pips to move the stop loss at each trailing frequency interval.
*   `SL_MaxTrailDifference` (double): The maximum distance in pips the stop loss can be trailed away from the initial SL.

#### **Time & Session Management**
*   `TimeZone` (int): The GMT offset for the server time when the EA should place trades (e.g., 9 for GMT+9). The EA places trades when the server hour matches this value.
*   `EnableMonday` to `EnableFriday` (bool): Switches to enable or disable trading on specific days of the week.
*   `CloseTime` (string): Time in "HH:MM" format (GMT) to delete any remaining pending orders for the day.

#### **Risk & Order Management**
*   `MaxOrders` (int): The number of pending orders to place in the initial straddle.
*   `MaxDrawDown` (double): The maximum allowed drawdown percentage. If reached, all trades are closed.
*   `TradeComment` (string): A comment attached to each trade for identification.
*   `Magic` (int): A unique magic number to distinguish trades placed by this EA from other EAs or manual trades.

--- 