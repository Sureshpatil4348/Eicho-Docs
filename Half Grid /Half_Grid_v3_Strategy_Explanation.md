## Half Grid v3 Strategy: Detailed Explanation

This document provides a comprehensive explanation of the Half Grid v3 Expert Advisor (EA), detailing its core logic, operational mechanics, and user-configurable parameters.

---

### **1. Core Concept**

The Half Grid v3 is an automated trading strategy that operates without traditional technical indicators. Its logic is based on a **dual-sequence grid system** that initiates trading at a specific time of day.

At its heart, the strategy simultaneously manages two independent trading sequences: a **Buy Sequence** and a **Sell Sequence**. It places trades against the prevailing trend for a sequence, with the goal of profiting from market volatility and price returning to a mean. The entire basket of trades is managed as a single unit with a collective profit target and stop loss.

---

### **2. Detailed Trading Logic and Mechanics**

The EA's operation is a continuous cycle that can be broken down into distinct phases. The core of the strategy lies in how it manages two opposing but concurrent sequences (Buy and Sell) and their corresponding hedge trades.

#### **Phase 1: Cycle Initiation**

The EA will only begin its trading activity under a strict set of conditions:

1.  **Daily Trigger:** The primary condition is that a new trading cycle has not already been started on the current day. The EA internally tracks the day it last started a cycle.
2.  **Time Window:** Trading can only begin at the precise time specified by the `StartHour` and `StartMinute` parameters. There is a one-minute window for initiation.
3.  **Simultaneous Anchor Trades:** At the exact start time, the EA attempts to open two "Anchor" trades simultaneously:
    *   One `BUY` trade, which becomes the foundation of the **Buy Sequence**.
    *   One `SELL` trade, which becomes the foundation of the **Sell Sequence**.
4.  **Cycle Activation:** The trading cycle is only considered active if **both** anchor trades are opened successfully. If either fails, the EA will wait for the next opportunity.
5.  **State Recording:** Upon successful activation:
    *   The `cycleActive` flag is set to `true`.
    *   The opening prices of the buy and sell anchors are recorded as `buyAnchorPrice` and `sellAnchorPrice`. These prices become the crucial reference points for all subsequent grid calculations.
    *   The `currentDay` is updated to prevent another cycle from starting on the same calendar day.

#### **Phase 2: Grid Management - The Hedging Mechanism**

Once the cycle is active, the EA continuously monitors the market price relative to the anchor prices for each sequence. The logic for the buy and sell sequences are mirrors of each other.

**A. Buy Sequence Grid Logic (When Price Goes DOWN)**

*   **Grid Trigger:** The grid mechanism for the buy sequence activates only if the price drops. Specifically, when the current `Bid` price is lower than the `buyAnchorPrice` by the amount of `PipsAgainst`.
*   **Grid Placement:**
    1.  The EA calculates imaginary horizontal lines, or "grid levels," below the `buyAnchorPrice`, spaced apart by `GridStep` pips.
    2.  As the `Bid` price crosses down through each of these levels, the EA places `SELL` trades (i.e., hedge trades against the anchor `BUY`).
    3.  **Dynamic Trade Volume:** The number of `SELL` trades opened at each grid level is equal to the current number of active anchor trades in the buy sequence (`buyAnchorCount`). If there is one anchor trade, it opens one hedge trade per level. If there are three anchor trades, it will open three hedge trades per level.
    4.  **Martingale Lots:** The lot size of these grid trades increases with each level further from the anchor, controlled by the `MartingaleMultiplier`. This is a high-risk approach that aims to capitalize on a price reversal.

**B. Sell Sequence Grid Logic (When Price Goes UP)**

*   **Grid Trigger:** The grid for the sell sequence activates if the price rises. Specifically, when the current `Ask` price is higher than the `sellAnchorPrice` by the amount of `PipsAgainst`.
*   **Grid Placement:**
    1.  The EA calculates grid levels above the `sellAnchorPrice`, spaced by `GridStep` pips.
    2.  As the `Ask` price crosses up through each level, the EA places `BUY` trades (hedging the anchor `SELL`).
    3.  The number of `BUY` trades opened at each level is equal to the `sellAnchorCount`.
    4.  Lot sizes are also increased using the `MartingaleMultiplier`.

#### **Phase 3: Sequence Re-entry - Strengthening the Position**

This is the most complex part of the strategy, allowing it to "double down" on a sequence.

1.  **Eligibility for Re-entry:** A sequence (e.g., the Buy Sequence) first needs to become "eligible" for a new anchor. This happens when the price has moved against the initial anchor enough to have triggered a specific number of grid levels (`MinGridTradesForReEntry`).
2.  **Re-entry Condition:** Once eligible, the EA waits for the price to **fully return to the original anchor price**.
    *   For the Buy Sequence: A new anchor is placed only if the `Bid` price moves back UP to the `buyAnchorPrice`.
    *   For the Sell Sequence: A new anchor is placed only if the `Ask` price moves back DOWN to the `sellAnchorPrice`.
3.  **Action on Re-entry:**
    *   A new anchor trade is opened in the same direction as the original (e.g., another `BUY` for the Buy Sequence). The lot size can be customized via the `CustomAnchor` parameters.
    *   The anchor count (`buyAnchorCount` or `sellAnchorCount`) is incremented.
    *   Crucially, the grid for that sequence is reset. This means the EA will now seek to open a number of hedge trades at each grid level equal to the *new, higher* anchor count, effectively strengthening the hedge against the now larger primary position.

#### **Phase 4: Cycle Termination**

The entire basket of trades is managed as a single entity. The cycle ends and all trades are closed when one of three things happens:

1.  **Profit Target:** The total combined floating profit of all open trades (from both sequences, including all anchors and grid trades) reaches the `ProfitTarget` amount in your account currency. The cycle is considered a success and the EA will wait for the next day to start again.
2.  **Stop Loss:** If `UseStopLoss` is enabled, and the total combined floating loss reaches the `MaxLossAmount`, all trades are immediately closed. The cycle ends, and the EA waits for the next day.
3.  **Manual Closure:** The user clicks the "Close Trades" button. All trades are closed, and the EA is reset. It will not trade again until the start time on the next calendar day.

---

### **3. On-Chart Dashboard**

The EA displays a dashboard on the chart to provide at-a-glance information:

*   **Balance:** Your account balance.
*   **Equity:** Your account equity.
*   **Profit:** The current floating profit/loss of all open trades and the profit target.
*   **Buy/Sell Status:** Shows whether each sequence is active and its current floating profit/loss.
*   **StopLoss Status:** Shows the configured `MaxLossAmount` and provides a warning if the current loss is approaching this value.

---

### **4. Input Parameters**

These are the settings you can configure in the EA's properties.

#### **Core EA Settings**
*   `MagicNumber` (Default: 12345): A unique ID to ensure the EA only manages its own trades.
*   `StartHour` (Default: 9): The hour of the day (0-23) to start a new trading cycle.
*   `StartMinute` (Default: 0): The minute of the hour (0-59) to start a new trading cycle.

#### **Risk Management Settings**
*   `UseStopLoss` (Default: true): Enables or disables the master stop loss feature.
*   `MaxLossAmount` (Default: 100): The maximum total loss (in your account's currency) before all trades are closed.
*   `ProfitTarget` (Default: 50): The total profit (in your account's currency) at which all trades will be closed.

#### **Lot Size Settings**
*   `SequenceInitialLot` (Default: 0.01): The initial lot size for anchor trades (unless a custom lot is specified).
*   `GridInitialLot` (Default: 0.01): The initial lot size for the very first trade in a grid sequence.
*   `MaxLotPerTrade` (Default: 0.64): The absolute maximum lot size for any single trade.
*   `MartingaleMultiplier` (Default: 2.0): The multiplier used to increase the lot size for subsequent grid trades. A value of 2 means each grid lot will be double the previous one.

#### **Grid Configuration**
*   `GridStep` (Default: 10): The distance in pips between each grid trade level.
*   `MaxGridLevel` (Default: 7): The maximum number of grid levels the EA is allowed to open for each sequence.
*   `PipsAgainst` (Default: 20): The distance in pips the price must move against an anchor trade before the grid trading begins.

#### **Re-entry Logic**
*   `MinGridTradesForReEntry` (Default: 5): The number of grid levels that must be opened before the EA is eligible to place a new anchor trade.

#### **Custom Anchor Trade Settings**
*   `CustomAnchorTrade1` to `CustomAnchorTrade6` (Default: 0): Specify the anchor trade number (e.g., 2 for the second anchor) you want to assign a custom lot size to. `0` disables it.
*   `CustomAnchorLot1` to `CustomAnchorLot6` (Default: 0.01): The custom lot size to be used for the corresponding `CustomAnchorTrade` number.

--- 