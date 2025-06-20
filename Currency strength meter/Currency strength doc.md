# Currency Strength Strategy

This document details a currency strength trading strategy based on the Rate of Change (ROC) indicator, designed to identify strong trends and optimize trade entry and position sizing.

## 1. Currency Strength Calculation: Rate of Change (ROC) Based

The core of this strategy lies in measuring the price momentum of individual currencies using the Rate of Change (ROC) indicator.

### What is Rate of Change (ROC)?

The Rate of Change (ROC) is a momentum oscillator that measures the percentage change in price over a given period. It helps identify overbought/oversold conditions and the strength of a trend.

### ROC Formula:

The formula used to calculate ROC is:
```
ROC = ((Current Price - Price n periods ago) / Price n periods ago) * 100
```
Where 'n' is the number of periods over which the ROC is calculated.

### Period Adjustment Based on Timeframe:

The `n` period for ROC calculation is crucial and needs to be adjusted based on your trading timeframe:

- **Weekly Charts:** Use a 15-week ROC period (e.g., for longer-term trend following).
- **Below 4-Hour Charts:** Use a 4-period ROC (e.g., 4 days for a daily chart, 4 hours for an hourly chart).
- **General Rule:** Adjust the period to best capture the momentum relevant to your chosen timeframe.

### Steps to Create the Currency Strength Meter:

1.  **Compile Currency Pairs:** Gather a list of major currency pairs (e.g., EUR/USD, GBP/JPY, AUD/CAD, etc.). You can also add exotic pairs for more trading options.
2.  **Calculate ROC for Each Pair:** For each selected currency pair, calculate its ROC value using the formula above, applying the appropriate period for your chosen timeframe.
3.  **Determine Individual Currency Strength:** Based on the ROC values of all pairs, deduce the strength of individual currencies. For example, if EUR/USD ROC is strongly positive, EUR is likely strong relative to USD. You'll need a method to consolidate these pair-based ROCs into a single strength score for each currency (e.g., averaging the ROCs of all pairs involving that currency).
4.  **Rank Currencies:** Rank all analyzed currencies from the strongest (highest ROC-derived strength) to the weakest (lowest ROC-derived strength).

### Application:

This ROC-based strength meter is ideal for trend-following strategies. The primary application is to pair the strongest currency with the weakest currency to identify high-probability trading opportunities.

## 2. Strategy Logic: Trading Decisions

Once the currency strength meter is calculated for a chosen timeframe, the trading decisions follow a clear set of rules.

### Timeframe Decision:

First, decide on the timeframe you will be analyzing (e.g., Daily, H4, H1). The strength meter will be calculated and trades will be managed according to this chosen timeframe. For instance, if you decide on a daily timeframe, the strength meter will be based on daily ROC values.

### Identifying Strongest and Weakest:

After ranking, identify the single strongest and the single weakest currency.

**Example:**
-   Strongest: EUR
-   Weakest: USD

### Buy/Sell Logic:

Based on the identified strongest and weakest currencies, you will enter trades on all relevant pairs to capitalize on this strength/weakness differential.

-   If a currency is **strong** (e.g., EUR): You will aim to **BUY** all pairs where EUR is the base currency (e.g., EUR/GBP, EUR/JPY) and **SELL** all pairs where EUR is the quote currency (e.g., CAD/EUR, CHF/EUR).
-   If a currency is **weak** (e.g., USD): You will aim to **SELL** all pairs where USD is the base currency (e.g., USD/JPY, USD/CAD) and **BUY** all pairs where USD is the quote currency (e.g., GBP/USD, AUD/USD).

### Handling Common Pairs:

It is crucial to ignore pairs that are common to both sets of strong and weak currency trades. For example, if EUR is strongest and USD is weakest:

-   Buying EUR/USD (due to strong EUR)
-   Selling EUR/USD (due to weak USD)

Trading both would result in a net zero profit/loss. Therefore, such pairs (e.g., EUR/USD) must be excluded from the trade selection.

## 3. Pair Selection Logic

Let's illustrate the pair selection process with an example:

### Example Scenario:

-   **Strongest Currency:** EUR
-   **Weakest Currency:** USD

### Actions based on Strong EUR:

These pairs are affected by EUR getting stronger, leading to potential BUY opportunities:

-   EUR/GBP - BUY
-   EUR/JPY - BUY
-   EUR/CHF - BUY
-   AUD/EUR - SELL
-   NZD/EUR - SELL
-   CAD/EUR - SELL

### Actions based on Weak USD:

These pairs are affected by USD getting weaker, leading to potential SELL opportunities (or BUY if USD is the quote currency):

-   USD/JPY - SELL
-   GBP/USD - BUY
-   AUD/USD - BUY
-   NZD/USD - BUY
-   USD/CAD - SELL
-   USD/CHF - SELL

### Final Pair Selection:

From these two lists, remove any common pairs (like EUR/USD if it were listed). Then, combine the remaining unique pairs to form your portfolio for the current trading period. This structured approach ensures you trade pairs aligned with the identified currency strength and weakness.

## 4. Lotsize Selection

Position sizing is dynamic and based on the Average True Range (ATR) of the selected pairs. This method aims to normalize risk across different instruments.

### Steps for Lotsize Calculation:

1.  **Calculate ATR for All Selected Pairs:** For each pair identified in Section 3 (strongest and weakest currency influence), calculate its ATR over a specified period (e.g., same 'n' period used for ROC, or a standard 14-period ATR).
2.  **Identify the "Base Section":**
    -   Sum the ATRs of all pairs associated with the strongest currency (e.g., sum of ATRs for EUR/GBP, EUR/JPY, EUR/CHF, AUD/EUR, etc.). Let's call this `ATR_Strong_Section`.
    -   Sum the ATRs of all pairs associated with the weakest currency (e.g., sum of ATRs for USD/JPY, GBP/USD, AUD/USD, USD/CAD, etc.). Let's call this `ATR_Weak_Section`.
    -   The section with the highest combined ATR will be considered the "Base Section".
    
    **Example:** If `ATR_Strong_Section` is 1200 and `ATR_Weak_Section` is 600, then the Strong_Section is the Base Section.

3.  **Lotsize for the Base Section:**
    -   You will define a total "Base Lotsize" for this section (e.g., 1 standard lot).
    -   This total Base Lotsize will be distributed proportionally among all the pairs within the Base Section, based on their individual ATR contribution.
    -   `Individual Pair Lotsize = Base Lotsize * (Individual Pair ATR / Total ATR of Base Section)`

4.  **Lotsize for the "Other Section":**
    -   Calculate the ratio of the Base Section's ATR to the Other Section's ATR: `Ratio = Total ATR of Other Section / Total ATR of Base Section`.
    -   The total lotsize for the Other Section will be `Base Lotsize * Ratio`.

    **Example:** If Base Section ATR is 1200 and Other Section ATR is 600, and Base Lotsize is 1 lot, then the Other Section's total lotsize will be `1 lot * (600 / 1200) = 0.5 lots`.
    
    This calculated total lotsize for the Other Section will then be distributed proportionally among all the pairs within the Other Section, based on their individual ATR contribution.

This dynamic lotsize allocation ensures that pairs with higher volatility (higher ATR) get a proportionally larger share of the total risk, while maintaining a balanced overall exposure based on the underlying strength/weakness.

## 5. Trade Management and Re-entry

Managing trades and deciding when to re-enter are critical aspects of this strategy.

### Exit Conditions:

Trades will be exited under one of the following conditions:

-   **Take Profit (TP):** When the predefined profit target is hit.
-   **Stop Loss (SL):** When the predefined maximum loss level is reached.
-   **Strength Reversal:** If the currency strength meter indicates a significant reversal in the strength ranking (i.e., the strongest currency is no longer strongest, or the weakest is no longer weakest). This serves as a dynamic exit based on strategy fundamentals.

### Re-entry Scenarios:

The re-entry logic accounts for daily strength changes and profit-taking events.

-   **Strength Change on the Next Day:**
    If you have trades running based on today's strength meter (e.g., 1-day timeframe), and the next day the strength meter indicates a different strongest/weakest currency pair, you will enter new trades based on the new strength readings. This implies actively adjusting your portfolio daily to the evolving market conditions.

-   **Trades Closed in Profit (TP Hit) - Strength Remains Same:**
    If your trades were closed in profit (TP hit), and the strongest and weakest currencies remain the same according to the strength meter, you will not instantly re-enter the trade.
    Instead, there will be a cooldown period of 24 to 48 hours. Only after this cooldown period, if the strongest and weakest pairs are still the same, will you consider re-entering the trade. This prevents overtrading and allows for market consolidation.

-   **Trades Closed in Profit (TP Hit) - Strength Changes:**
    If your trades were closed in profit (TP hit), and the strongest and weakest currencies are now different according to the strength meter, you will immediately enter new trades based on the new strength readings. There is no cooldown period in this scenario as the underlying market condition has shifted.

This comprehensive approach to re-entry ensures that you capitalize on persistent trends while also adapting to new market conditions and avoiding unnecessary trades after immediate profit-taking.
