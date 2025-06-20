# Bollinger Z-Score Grid EA Strategy Explained

## 1. Overview

The Bollinger Z-Score Grid EA is a sophisticated automated trading strategy designed for MetaTrader 4. It operates on the principle of **mean reversion**. The core idea is that asset prices, after making an extreme move away from their average, tend to revert back to that average over time.

The EA identifies these extreme price movements using Bollinger Bands and confirms them with either a Z-Score or an RSI indicator. When a trading opportunity is identified, it enters a trade. If the price continues to move against the initial position, the EA employs a **grid system**, opening additional trades at calculated intervals to improve the average entry price. The ultimate goal is to close the entire grid of trades for a collective profit when the price reverts to the mean.

It includes advanced features like optional Martingale lot sizing, an adaptive take-profit mechanism, and a unique adaptive recovery system to manage losing trade cycles.

---

## 2. Core Strategy & Logic

The strategy can be broken down into four main components:

### a. Mean Reversion Entry Signal
The primary signal for a potential trade occurs when the price closes outside of the Bollinger Bands.
- **Sell Signal:** The price closes *above* the Upper Bollinger Band, suggesting the asset is overbought and likely to decrease in price.
- **Buy Signal:** The price closes *below* the Lower Bollinger Band, suggesting the asset is oversold and likely to increase in price.

### b. Trade Confirmation
A raw Bollinger Band crossover is not enough to open a trade. The EA requires confirmation from a secondary indicator to filter out false signals and improve accuracy. The user can choose one of three confirmation methods:
1.  **Z-Score Only:** Confirms the signal using a statistical measure of how far the price is from its moving average. A high positive Z-Score confirms a sell, and a large negative Z-Score confirms a buy.
2.  **RSI Only:** Confirms the signal using the Relative Strength Index. An overbought RSI reading confirms a sell, and an oversold reading confirms a buy.
3.  **Both (Z-Score AND RSI):** The most stringent method, requiring both Z-Score and RSI to agree with the Bollinger Band signal before a trade is placed.

### c. The Grid System
Once an initial trade is opened, if the market continues to move against it (e.g., the price keeps rising after a sell trade), the EA will open additional trades.
- **Grid Spacing:** The distance between these grid trades is not fixed. It is calculated dynamically using the Average True Range (ATR), which measures market volatility. In high volatility, the grid levels are spaced further apart, and in low volatility, they are closer together.
- **Averaging Down:** Each new trade in the grid improves the overall average entry price for the entire cycle. This means the price doesn't need to return to the initial entry point to become profitable; it only needs to revert back to the improved average price.

### d. Profit Taking
Instead of setting an individual Take Profit for each trade, the EA manages all trades in a cycle (all buys or all sells) as a single unit.
- **Average Price TP:** It calculates the volume-weighted average price of all open trades in the grid. A single Take Profit target is then placed a specified number of pips away from this average price.
- **Closing the Cycle:** When the market price hits this calculated Take Profit level, the EA closes *all* trades in the grid simultaneously, securing the profit and ending the cycle.

---

## 3. Key Indicators Explained

-   **Bollinger Bands (BB):** A volatility indicator consisting of a middle band (a simple moving average) and two outer bands set at a certain number of standard deviations away from the middle band. The EA uses the outer bands to identify statistically significant price extremes.
-   **Z-Score:** A statistical measurement that describes a value's relationship to the mean of a group of values. It is measured in terms of standard deviations from the mean. In this EA, it helps quantify *how* overbought or oversold the market is, providing a more robust confirmation than price alone.
-   **Relative Strength Index (RSI):** A momentum oscillator that measures the speed and change of price movements. It oscillates between 0 and 100 and is traditionally used to identify overbought (>70) and oversold (<30) conditions.
-   **Average True Range (ATR):** An indicator that measures market volatility. The EA uses it to set the distance for its grid trades, adapting automatically to changing market conditions.

---

## 4. Special Features

### a. Martingale Lot Sizing
When enabled (`Use_Martingale` = true), the lot size for each subsequent trade in the grid is increased by a multiplier (`LotSize_Multiplier`). For example, if the first trade is 0.01 lots and the multiplier is 2, the grid trades will have sizes of 0.02, 0.04, 0.08, and so on. This is a high-risk strategy that can lead to faster profit recovery but also significantly increases the risk of large drawdowns.

### b. Adaptive Take Profit
When the grid accumulates trades and one of the trades reaches the `Max_LotSize`, this feature (`Adjust_TP_For_MaxLot` = true) can dynamically adjust the take profit target. It calculates a risk-reward ratio and may set a smaller-than-usual Take Profit to exit the risky cycle more quickly.

### c. Adaptive Recovery System
This is a unique risk management feature (`Use_Adaptive_Recovery` = true). If a grid cycle reaches a predefined maximum number of levels (`MaxGridLevels`), the EA assumes the trade is unlikely to succeed.
1.  **Cut Losses:** It closes the entire losing grid, realizing the loss.
2.  **Enter Recovery Mode:** It records the total realized loss from that cycle.
3.  **Calculate Recovery Trade:** The next time a valid entry signal appears, it opens a single, larger trade. The size is calculated to be large enough to not only make a standard profit but also to **recover the entire loss from the previously closed grid**.
4.  **Reset:** Once the recovery trade hits its special take profit target, the recovery is complete, and the EA returns to its normal baseline trading logic.

---

## 5. Input Parameters Explained

This section details every user-configurable parameter in the EA.

### Bollinger Bands Settings
-   `BB_Period` (Default: 20): The calculation period for the Bollinger Bands.
-   `BB_Deviation` (Default: 2.0): The number of standard deviations for the upper and lower bands.
-   `BB_Shift` (Default: 0): The shift of the bands forward or backward on the chart.
-   `BB_Applied_Price` (Default: PRICE_CLOSE): The price type (Close, Open, etc.) used for the BB calculation.

### Z-Score Settings
-   `ZScore_Period` (Default: 20): The lookback period for calculating the moving average and standard deviation used in the Z-Score.
-   `ZScore_Threshold_Upper` (Default: 2.8): The Z-Score value that must be met or exceeded to confirm a SELL signal.
-   `ZScore_Threshold_Lower` (Default: -2.8): The Z-Score value that must be met or exceeded to confirm a BUY signal.

### RSI Settings
-   `RSI_Period` (Default: 14): The calculation period for the RSI.
-   `RSI_Oversold` (Default: 30): The RSI level below which a BUY signal can be confirmed.
-   `RSI_Overbought` (Default: 70): The RSI level above which a SELL signal can be confirmed.
-   `RSI_Applied_Price` (Default: PRICE_CLOSE): The price type used for the RSI calculation.

### Confirmation Method
-   `Confirmation_Method` (Default: USE_ZSCORE): Determines which indicator(s) to use for trade confirmation.
    -   `USE_ZSCORE`: Only Z-Score is used.
    -   `USE_RSI`: Only RSI is used.
    -   `USE_BOTH`: Both Z-Score and RSI conditions must be met.

### ATR Settings for Grid
-   `ATR_Period` (Default: 14): The calculation period for the ATR indicator.
-   `ATR_Multiplier_For_Grid` (Default: 1.5): The ATR value is multiplied by this number to determine the distance for the next grid trade.

### Trade & Money Management
-   `Initial_LotSize` (Default: 0.01): The lot size of the very first trade in a cycle.
-   `Use_Martingale` (Default: true): Set to `true` to enable the Martingale lot multiplier for grid trades. `false` uses `Initial_LotSize` for all trades.
-   `LotSize_Multiplier` (Default: 2.0): If Martingale is on, the lot size of the previous trade is multiplied by this value for the next grid trade.
-   `Max_LotSize` (Default: 0.5): The absolute maximum lot size a single trade can have.
-   `Max_Grid_Trades` (Default: 5): The maximum number of trades allowed in a single grid cycle (including the initial trade).
-   `Average_TP_In_Pips` (Default: 20): The distance in pips from the average entry price to set the take profit for the entire grid.
-   `Adjust_TP_For_MaxLot` (Default: true): If `true`, allows the EA to dynamically adjust the TP target when a trade in the grid hits the `Max_LotSize`.

### EA General Settings
-   `MagicNumber` (Default: 12345): A unique ID that allows the EA to distinguish its trades from other EAs or manual trades.
-   `Slippage` (Default: 3): The maximum deviation in pips between the expected price and the executed price.
-   `Max_Spread` (Default: 5): The maximum allowed spread in pips to open a new initial trade.
-   `Trade_Comment` (Default: "BB_ZScore_Grid_EA"): A comment attached to each trade for identification.

### Adaptive Recovery Settings
-   `Use_Adaptive_Recovery` (Default: false): Set to `true` to enable the recovery system.
-   `MaxGridLevels` (Default: 7): The number of grid trades that will trigger the recovery system to cut losses and enter recovery mode.
-   `Recovery_Profit_Target` (Default: 50.0): The target profit (in your account's currency) that the recovery trade aims to achieve *in addition to* covering the previous losses. 