//+------------------------------------------------------------------+
//| EMA Grid Recovery EA                                             |
//| Expert Advisor for EMA Crossover with Grid and Recovery System  |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "2.00"
#property strict

// Strategy Selection
enum ENUM_ENTRY_STRATEGY
{
   STRATEGY_EMA_CROSSOVER = 0,    // EMA Crossover
   STRATEGY_BOLLINGER_BANDS = 1    // Bollinger Bands
};

// Trade Direction Mode
enum ENUM_TRADE_DIRECTION_MODE
{
    MODE_BUY_ONLY = 0,        // Buy Only
    MODE_SELL_ONLY = 1,       // Sell Only
    MODE_BOTH_DIRECTIONS = 2  // Both Directions (Flip & Recover)
};

// Bollinger Bands Entry Level
enum ENUM_BB_ENTRY_LEVEL
{
   BB_ENTRY_UPPER = 0,    // Upper Band
   BB_ENTRY_MIDDLE = 1    // Middle Band
};

// Bollinger Bands Exit Level
enum ENUM_BB_EXIT_LEVEL
{
   BB_EXIT_MIDDLE = 0,    // Middle Band
   BB_EXIT_LOWER = 1      // Lower Band
};

//--- Input Parameters
input group "=== Strategy Selection ==="
input ENUM_ENTRY_STRATEGY EntryStrategy = STRATEGY_EMA_CROSSOVER;  // Entry Strategy
input ENUM_TRADE_DIRECTION_MODE TradeDirectionMode = MODE_BOTH_DIRECTIONS;  // Trading Direction Mode

input group "=== EMA Settings ==="
input int FastEMA_Period = 10;                    // Fast EMA Period
input int SlowEMA_Period = 20;                    // Slow EMA Period
input ENUM_APPLIED_PRICE EMA_Price = PRICE_CLOSE; // Price to apply EMA

input group "=== Bollinger Bands Settings ==="
input int BB_Period = 20;                         // Bollinger Bands Period
input double BB_Deviation = 2.0;                  // Bollinger Bands Deviation
input ENUM_APPLIED_PRICE BB_Price = PRICE_CLOSE;  // Price to apply Bollinger Bands
input ENUM_BB_ENTRY_LEVEL BB_EntryLevel = BB_ENTRY_UPPER; // Entry Level
input ENUM_BB_EXIT_LEVEL BB_ExitLevel = BB_EXIT_MIDDLE;   // Exit Level

input group "=== Trade Settings ==="
input double InitialLotSize = 0.01;               // Initial Lot Size
input int InitialTakeProfit = 20;                 // Initial Take Profit (pips)
input int GridDistance = 15;                      // Grid Distance (pips)
input double LotMultiplier = 1.5;                 // Lot Multiplier for grid
input int GridTradesForMultiplier = 3;            // Grid trades before lot multiplier increases
input int RecoveryProfit = 5;                     // Additional profit for recovery (pips)

input group "=== ATR Settings ==="
input bool UseATR = false;                        // Use ATR for TP and Grid Distance
input int ATR_Period = 14;                        // ATR Period
input ENUM_TIMEFRAMES ATR_TP_Timeframe = PERIOD_H1; // ATR Timeframe for Take Profit
input ENUM_TIMEFRAMES ATR_Grid_Timeframe = PERIOD_H1; // ATR Timeframe for Grid Distance
input double ATR_TP_Multiplier = 1.5;            // ATR Multiplier for Take Profit
input double ATR_Grid_Multiplier = 1.0;          // ATR Multiplier for Grid Distance

input group "=== RSI Continuation Settings ==="
input bool EnableRSIContinuation = true;          // Enable RSI-based continuation
input int RSI_Period = 14;                        // RSI Period
input ENUM_TIMEFRAMES RSI_Timeframe = PERIOD_H4;  // RSI Timeframe
input double RSI_OverboughtLevel = 70.0;          // RSI Overbought Level
input int MaxContinuationTrades = 10;             // Max consecutive initial trades (0 = unlimited)

input group "=== System Settings ==="
input int MagicNumber = 12345;                    // Magic Number
input int Slippage = 3;                          // Slippage (pips)
input bool EnableLogging = true;                 // Enable detailed logging

//--- Global Variables
double g_FastEMA_Current, g_FastEMA_Previous;
double g_SlowEMA_Current, g_SlowEMA_Previous;

// Bollinger Bands variables
double g_BB_Upper, g_BB_Middle, g_BB_Lower;
bool g_PriceAboveUpperBand = false;
bool g_PriceBelowMiddleBand = false;
bool g_BollingerBandsInitialized = false;

// Recovery tracking
double g_TotalAccumulatedLoss = 0.0;             // All losses across all sequences
double g_PreviousSequenceTotalLots = 0.0;       // Combined lot size from previous losing sequence
bool g_InRecoveryMode = false;                   // Recovery mode flag

// Grid tracking (persistent across sequences)
int g_GlobalGridPosition = 0;                    // Only increments for actual grid trades
double g_InitialBaseLot = 0.0;                   // Store original InitialLotSize for calculations

// Current sequence tracking
int g_TradesInCurrentSequence = 0;               // Number of trades in current sequence
int g_CurrentSequence = 1;                       // Current sequence number
bool g_FirstTradeOfSequence = true;              // Flag to identify sequence starter

// Grid system
double g_LastEntryPrice = 0.0;                   // Last entry price for grid calculation
bool g_GridActive = false;                       // Grid system active flag

// System
datetime g_LastBarTime = 0;                      // Tracks the time of the last processed bar

// RSI Continuation System
bool g_WaitingForRSI = false;                     // Flag when waiting for RSI to come down
int g_ContinuationTradeCount = 0;                 // Count of consecutive initial trades in current trend
bool g_LastCompletionWasProfit = false;          // Track if last completion was profitable
string g_CompletionType = "";                     // "INITIAL", "GRID", "RECOVERY"
bool g_InitialTradeActive = false;                // Track if we have an initial trade (not grid) active

// Bidirectional Trading System
int g_CurrentTradeDirection = -1;                 // -1: None, OP_BUY: Buy, OP_SELL: Sell
bool g_FlipRecoveryActive = false;                // Flag when a direction flip recovery is active
double g_OppositeSequenceTotalLots = 0.0;         // Store lots for direction flip recovery
double g_OppositeSequenceTotalLoss = 0.0;         // Store loss for direction flip recovery

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    if(EnableLogging) Print("=== EMA Grid Recovery EA v2.0 (Bidirectional) Initialized ===");
    if(EnableLogging) Print("Entry Strategy: ", EntryStrategy == STRATEGY_EMA_CROSSOVER ? "EMA Crossover" : "Bollinger Bands");
    
    // Log trading direction mode
    if(EnableLogging) 
    {
        string modeStr;
        switch(TradeDirectionMode)
        {
            case MODE_BUY_ONLY: modeStr = "BUY ONLY"; break;
            case MODE_SELL_ONLY: modeStr = "SELL ONLY"; break;
            case MODE_BOTH_DIRECTIONS: modeStr = "BOTH DIRECTIONS (Flip & Recover)"; break;
            default: modeStr = "UNKNOWN";
        }
        Print("Trading Direction Mode: ", modeStr);
    }
    
    if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
    {
    if(EnableLogging) Print("Fast EMA Period: ", FastEMA_Period);
    if(EnableLogging) Print("Slow EMA Period: ", SlowEMA_Period);
    }
    else // STRATEGY_BOLLINGER_BANDS
    {
        if(EnableLogging) Print("Bollinger Bands Period: ", BB_Period);
        if(EnableLogging) Print("Bollinger Bands Deviation: ", BB_Deviation);
    }
    
    if(EnableLogging) Print("Initial Lot Size: ", InitialLotSize);
    if(EnableLogging) Print("Initial Take Profit: ", InitialTakeProfit, " pips");
    if(EnableLogging) Print("Grid Distance: ", GridDistance, " pips");
    if(EnableLogging) Print("Lot Multiplier: ", LotMultiplier);
    if(EnableLogging) Print("Grid Trades for Multiplier: ", GridTradesForMultiplier);
    
    // Store initial base lot for grid calculations
    g_InitialBaseLot = InitialLotSize;
    
    // Initialize indicator values based on selected strategy
    if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
    {
    UpdateEMAValues();
    }
    else // STRATEGY_BOLLINGER_BANDS
    {
        UpdateBollingerBandsValues();
    }
    
    // Set timer for status updates
    EventSetTimer(1);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    if(EnableLogging) Print("=== EMA Grid Recovery EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // These functions manage the state of open trades and should run on every tick for precision.
    ManageExistingTrades();
    CheckGridOpportunities();
    
    // Check RSI waiting conditions (runs every tick when waiting)
    CheckRSIWaitingConditions();

    // --- Trading signals are only checked once per bar ---
    if(Time[0] == g_LastBarTime)
    {
        return; // Not a new bar, so we exit and wait for the next tick.
    }
    g_LastBarTime = Time[0]; // Update the last bar time.
    
    if(EnableLogging) Print("--- New Bar Check at ", TimeToString(g_LastBarTime), " ---");
    
    // Check for trading signals based on selected strategy
    if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
    {
    // Check for EMA crossover signals on the close of the last bar.
    CheckEMACrossover();
    }
    else // STRATEGY_BOLLINGER_BANDS
    {
        // Check for Bollinger Bands signals on the close of the last bar.
        CheckBollingerBandsSignals();
    }
}

//+------------------------------------------------------------------+
//| Update EMA values                                               |
//+------------------------------------------------------------------+
void UpdateEMAValues()
{
    g_FastEMA_Previous = g_FastEMA_Current;
    g_SlowEMA_Previous = g_SlowEMA_Current;
    
    g_FastEMA_Current = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 0);
    g_SlowEMA_Current = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 0);
}

//+------------------------------------------------------------------+
//| Check for EMA crossover signals on closed bars                   |
//+------------------------------------------------------------------+
void CheckEMACrossover()
{
    // Get EMA values for the two most recently closed bars.
    // Bar 1 is the most recently completed bar.
    // Bar 2 is the one before that.
    double fastEmaBar1 = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 1);
    double slowEmaBar1 = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 1);
    double fastEmaBar2 = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 2);
    double slowEmaBar2 = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 2);

    // Check for bullish crossover (Fast EMA crosses above Slow EMA on bar close)
    if (fastEmaBar2 <= slowEmaBar2 && fastEmaBar1 > slowEmaBar1)
    {
        if (EnableLogging) Print("BULLISH CROSSOVER confirmed on bar close.");
        ProcessSignal(OP_BUY);
    }
    // Check for bearish crossover (Fast EMA crosses below Slow EMA on bar close)
    else if (fastEmaBar2 >= slowEmaBar2 && fastEmaBar1 < slowEmaBar1)
    {
        if (EnableLogging) Print("BEARISH CROSSOVER confirmed on bar close.");
        ProcessSignal(OP_SELL);
    }
}

//+------------------------------------------------------------------+
//| Handle bullish crossover                                        |
//+------------------------------------------------------------------+
void OnBullishCrossover()
{
    // If we already have trades open, we should ignore any new entry signals.
    if(CountOpenTrades() > 0)
    {
        if(EnableLogging) Print("Bullish crossover ignored, trades are already open.");
        return;
    }
    
    // Reset RSI continuation system for new trend
    g_ContinuationTradeCount = 0;
    g_WaitingForRSI = false;
    
    // Determine lot size for new trade
    double lotSize = g_InitialBaseLot; // Default to initial lot size
    if(g_InRecoveryMode)
    {
        lotSize = g_PreviousSequenceTotalLots;
        if(EnableLogging) Print("Recovery mode active. Using combined lot size: ", lotSize);
        if(EnableLogging) Print("Starting Sequence #", g_CurrentSequence);
    }
    else
    {
        if(EnableLogging) Print("Normal mode. Starting Sequence #", g_CurrentSequence);
    }
    
    // Place initial buy trade
    PlaceInitialBuyTrade(lotSize);
}

//+------------------------------------------------------------------+
//| Handle bearish crossover                                        |
//+------------------------------------------------------------------+
void OnBearishCrossover()
{
    // Cancel any RSI waiting and reset continuation system
    g_WaitingForRSI = false;
    g_ContinuationTradeCount = 0;
    
    if(CountOpenTrades() > 0)
    {
        if(EnableLogging) Print("Bearish crossover - closing all trades and recording loss");
        RecordLossAndCloseTrades();
    }
}

//+------------------------------------------------------------------+
//| Place initial buy trade                                         |
//+------------------------------------------------------------------+
void PlaceInitialBuyTrade(double lotSize)
{
    double price = Ask;
    double takeProfit = 0;
    
    // Set take profit immediately based on mode
    if(g_InRecoveryMode)
    {
        // Calculate recovery take profit
        takeProfit = CalculateRecoveryTakeProfit(OP_BUY, price, lotSize);
    }
    else
    {
        // Use ATR or normal take profit
        if(UseATR)
        {
            double atr = GetATRValue(ATR_TP_Timeframe);
            takeProfit = price + (atr * ATR_TP_Multiplier);
            if(EnableLogging) Print("Using ATR-based Take Profit: ATR=", atr, " x Multiplier=", ATR_TP_Multiplier);
        }
        else
        {
            // Normal fixed take profit
            takeProfit = price + (InitialTakeProfit * Point * 10);
        }
    }
    
    string comment = "Seq" + IntegerToString(g_CurrentSequence) + "_T1";
    int ticket = OrderSend(Symbol(), OP_BUY, lotSize, price, Slippage, 0, takeProfit, 
                          comment, MagicNumber, 0, clrGreen);
    
    if(ticket > 0)
    {
        // Set sequence flags and tracking
        g_LastEntryPrice = price;
        g_FirstTradeOfSequence = true;
        g_TradesInCurrentSequence = 1;
        g_GridActive = false;
        g_InitialTradeActive = true; // Mark as initial trade
        // NOTE: g_GlobalGridPosition is NOT incremented (this is not a grid trade)
        
        if(EnableLogging) 
        {
            Print("=== INITIAL TRADE PLACED ===");
            Print("  Sequence: ", g_CurrentSequence);
            Print("  Ticket: ", ticket);
            Print("  Lot Size: ", lotSize);
            Print("  Entry Price: ", price);
            Print("  Take Profit: ", takeProfit);
            Print("  Recovery Mode: ", g_InRecoveryMode ? "YES" : "NO");
            Print("  Global Grid Position: ", g_GlobalGridPosition, " (unchanged)");
            Print("  Trades in Sequence: ", g_TradesInCurrentSequence);
        }
    }
    else
    {
        if(EnableLogging) Print("ERROR: Failed to place initial buy trade. Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculate recovery take profit                                  |
//+------------------------------------------------------------------+
double CalculateRecoveryTakeProfit(int direction, double entryPrice, double lotSize)
{
    // Calculate pip value for this lot size
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    if(MarketInfo(Symbol(), MODE_DIGITS) == 5 || MarketInfo(Symbol(), MODE_DIGITS) == 3)
        pipValue = pipValue * 10; // Adjust for 5-digit brokers
    
    // Calculate required profit in pips
    double requiredProfitPips = g_TotalAccumulatedLoss / (pipValue * lotSize);
    
    // Add additional recovery profit in pips
    requiredProfitPips += RecoveryProfit;
    
    // Calculate take profit price based on ATR or fixed pips
    double takeProfitPrice;
    
    if(direction == OP_BUY)
    {
        if(UseATR)
        {
            // In recovery mode, we still need to ensure we cover the required profit
            // So we use the greater of the ATR-based TP or the required profit
            double atr = GetATRValue(ATR_TP_Timeframe);
            double atrTakeProfit = entryPrice + (atr * ATR_TP_Multiplier);
            double requiredTakeProfit = entryPrice + (requiredProfitPips * Point * 10);
            
            // Use the maximum of ATR-based TP or required profit TP
            takeProfitPrice = MathMax(atrTakeProfit, requiredTakeProfit);
            
            if(EnableLogging) 
            {
                Print("=== BUY RECOVERY TAKE PROFIT CALCULATION (ATR) ===");
                Print("  ATR Value: ", atr);
                Print("  ATR Take Profit: ", atrTakeProfit);
                Print("  Required Take Profit: ", requiredTakeProfit);
                Print("  Selected Take Profit: ", takeProfitPrice);
            }
        }
        else
        {
            // Standard take profit calculation for BUY
            takeProfitPrice = entryPrice + (requiredProfitPips * Point * 10);
        }
    }
    else // OP_SELL
    {
        if(UseATR)
        {
            // For SELL orders in recovery mode
            double atr = GetATRValue(ATR_TP_Timeframe);
            double atrTakeProfit = entryPrice - (atr * ATR_TP_Multiplier);
            double requiredTakeProfit = entryPrice - (requiredProfitPips * Point * 10);
            
            // Use the minimum of ATR-based TP or required profit TP
            takeProfitPrice = MathMin(atrTakeProfit, requiredTakeProfit);
            
            if(EnableLogging) 
            {
                Print("=== SELL RECOVERY TAKE PROFIT CALCULATION (ATR) ===");
                Print("  ATR Value: ", atr);
                Print("  ATR Take Profit: ", atrTakeProfit);
                Print("  Required Take Profit: ", requiredTakeProfit);
                Print("  Selected Take Profit: ", takeProfitPrice);
            }
        }
        else
        {
            // Standard take profit calculation for SELL
            takeProfitPrice = entryPrice - (requiredProfitPips * Point * 10);
        }
    }
    
    if(EnableLogging && !UseATR) 
    {
        string dirStr = (direction == OP_BUY) ? "BUY" : "SELL";
        Print("=== ", dirStr, " RECOVERY TAKE PROFIT CALCULATION ===");
        Print("  Accumulated loss to recover: ", g_TotalAccumulatedLoss);
        Print("  Pip value: ", pipValue);
        Print("  Recovery lot size: ", lotSize);
        Print("  Required profit pips: ", requiredProfitPips - RecoveryProfit);
        Print("  Additional profit pips: ", RecoveryProfit);
        Print("  Total TP pips: ", requiredProfitPips);
        Print("  Take profit price: ", takeProfitPrice);
    }
    
    return takeProfitPrice;
}

//+------------------------------------------------------------------+
//| Manage existing trades                                          |
//+------------------------------------------------------------------+
void ManageExistingTrades()
{
    if(g_CurrentTradeDirection == -1) return; // No active direction
    
    // Check if trades of current direction are closed by take profit (successful completion)
    if(CountOpenTrades(g_CurrentTradeDirection) == 0 && g_TradesInCurrentSequence > 0)
    {
        if(EnableLogging) 
        {
            string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
            Print("=== ALL ", dirStr, " TRADES CLOSED SUCCESSFULLY ===");
            Print("  Sequence #", g_CurrentSequence, " completed in profit");
            Print("  Recovery mode was: ", g_InRecoveryMode ? "ACTIVE" : "INACTIVE");
            Print("  Flip recovery was: ", g_FlipRecoveryActive ? "ACTIVE" : "INACTIVE");
        }
        
        // Determine completion type and route to appropriate handler
        if(g_InitialTradeActive && g_TradesInCurrentSequence == 1)
        {
            // Only initial trade was active and closed - RSI continuation only applies to BUY trades
            if(g_CurrentTradeDirection == OP_BUY)
            {
                HandleInitialTradeCompletion();
            }
            else
            {
                // For SELL trades, just use grid/recovery completion which resets counters
                HandleGridRecoveryCompletion();
            }
        }
        else
        {
            // Grid or recovery trades were involved
            HandleGridRecoveryCompletion();
        }
    }
}

//+------------------------------------------------------------------+
//| Check for grid opportunities                                    |
//+------------------------------------------------------------------+
void CheckGridOpportunities()
{
    // Only check if we have at least the first trade of sequence and a valid direction
    if(g_TradesInCurrentSequence < 1 || g_CurrentTradeDirection == -1) return;
    
    double currentPrice = (g_CurrentTradeDirection == OP_BUY) ? Bid : Ask;
    double gridTriggerPrice;
    
    // Calculate grid trigger price based on ATR or fixed pips and direction
    if(UseATR)
    {
        double atr = GetATRValue(ATR_Grid_Timeframe);
        
        // For BUY, grid triggers on price dropping below entry
        // For SELL, grid triggers on price rising above entry
        if(g_CurrentTradeDirection == OP_BUY)
            gridTriggerPrice = g_LastEntryPrice - (atr * ATR_Grid_Multiplier);
        else // OP_SELL
            gridTriggerPrice = g_LastEntryPrice + (atr * ATR_Grid_Multiplier);
        
        if(EnableLogging && !g_GridActive) 
        {
            string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
            Print("=== ATR ", dirStr, " GRID CALCULATION ===");
            Print("  ATR Value: ", atr);
            Print("  ATR Multiplier: ", ATR_Grid_Multiplier);
            Print("  ATR Grid Distance: ", atr * ATR_Grid_Multiplier);
        }
    }
    else
    {
        if(g_CurrentTradeDirection == OP_BUY)
            gridTriggerPrice = g_LastEntryPrice - (GridDistance * Point * 10);
        else // OP_SELL
            gridTriggerPrice = g_LastEntryPrice + (GridDistance * Point * 10);
    }
    
    // Grid activation trigger - check based on direction
    bool gridTriggerCondition;
    
    if(g_CurrentTradeDirection == OP_BUY)
        gridTriggerCondition = (currentPrice <= gridTriggerPrice);
    else // OP_SELL
        gridTriggerCondition = (currentPrice >= gridTriggerPrice);
    
    if(gridTriggerCondition && !g_GridActive)
    {
        if(EnableLogging) 
        {
            string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
            Print("=== ", dirStr, " GRID SYSTEM ACTIVATED ===");
            Print("  Current price: ", currentPrice);
            Print("  Grid trigger price: ", gridTriggerPrice);
            Print("  Reference entry: ", g_LastEntryPrice);
            Print("  Sequence: ", g_CurrentSequence);
            Print("  Using ATR: ", UseATR ? "YES" : "NO");
        }
        ActivateGridSystem();
    }
    
    // Check for additional grid levels
    if(g_GridActive)
    {
        CheckForNewGridLevel();
    }
}

//+------------------------------------------------------------------+
//| Activate grid system                                           |
//+------------------------------------------------------------------+
void ActivateGridSystem()
{
    g_GridActive = true;
    
    // Place first grid trade (this will increment g_GlobalGridPosition)
    PlaceGridTrade();
    
    // After placing first grid trade, update all TPs to averaged level
    ModifyAllTradesToAverageTakeProfit();
}

//+------------------------------------------------------------------+
//| Check for new grid level                                       |
//+------------------------------------------------------------------+
void CheckForNewGridLevel()
{
    // Check that we have a valid direction
    if(g_CurrentTradeDirection == -1) return;
    
    // Price is based on direction
    double currentPrice = (g_CurrentTradeDirection == OP_BUY) ? Bid : Ask;
    double nextGridPrice;
    
    // Calculate next grid level based on ATR or fixed pips and direction
    if(UseATR)
    {
        double atr = GetATRValue(ATR_Grid_Timeframe);
        
        // We multiply by trades in sequence to maintain grid spacing
        // This ensures each grid level is proportionally deeper based on ATR
        int gridLevelsFromFirst = g_TradesInCurrentSequence;
        
        if(g_CurrentTradeDirection == OP_BUY)
            nextGridPrice = g_LastEntryPrice - (gridLevelsFromFirst * atr * ATR_Grid_Multiplier);
        else // OP_SELL
            nextGridPrice = g_LastEntryPrice + (gridLevelsFromFirst * atr * ATR_Grid_Multiplier);
        
        if(EnableLogging) 
        {
            string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
            Print("=== ATR NEXT ", dirStr, " GRID LEVEL CALCULATION ===");
            Print("  ATR Value: ", atr);
            Print("  Grid levels from first: ", gridLevelsFromFirst);
            Print("  ATR Grid Distance: ", atr * ATR_Grid_Multiplier);
            Print("  Total Grid Distance: ", gridLevelsFromFirst * atr * ATR_Grid_Multiplier);
        }
    }
    else
    {
        // Calculate next grid level based on direction and the number of trades already in sequence
        int gridLevelsFromFirst = g_TradesInCurrentSequence; // This will be the next grid level
        
        if(g_CurrentTradeDirection == OP_BUY)
            nextGridPrice = g_LastEntryPrice - (gridLevelsFromFirst * GridDistance * Point * 10);
        else // OP_SELL
            nextGridPrice = g_LastEntryPrice + (gridLevelsFromFirst * GridDistance * Point * 10);
    }
    
    // Check trigger condition based on direction
    bool gridTriggerCondition;
    
    if(g_CurrentTradeDirection == OP_BUY)
        gridTriggerCondition = (currentPrice <= nextGridPrice);
    else // OP_SELL
        gridTriggerCondition = (currentPrice >= nextGridPrice);
    
    if(gridTriggerCondition)
    {
        if(EnableLogging) 
        {
            string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
            Print("=== NEW ", dirStr, " GRID LEVEL TRIGGERED ===");
            Print("  Current price: ", currentPrice);
            Print("  Next grid price: ", nextGridPrice);
            Print("  Grid level from first: ", g_TradesInCurrentSequence);
            Print("  Trades in sequence: ", g_TradesInCurrentSequence);
            Print("  Using ATR: ", UseATR ? "YES" : "NO");
        }
        PlaceGridTrade();
        
        // Update all TPs after placing new grid trade
        ModifyAllTradesToAverageTakeProfit();
    }
}

//+------------------------------------------------------------------+
//| Place grid trade                                               |
//+------------------------------------------------------------------+
void PlaceGridTrade()
{
    // Check that we have a valid direction
    if(g_CurrentTradeDirection == -1) 
    {
        if(EnableLogging) Print("ERROR: Attempted to place grid trade with no direction set");
        return;
    }
    
    // Increment global grid position (only for actual grid trades)
    g_GlobalGridPosition++;
    g_TradesInCurrentSequence++;
    
    // Calculate lot size based on global grid progression
    double lotSize = g_InitialBaseLot;
    
    if(GridTradesForMultiplier > 0)
    {
        // For GridTradesForMultiplier = 2:
        // Grid position 1: g_GlobalGridPosition=1, (1-1)/2=0 → No multiplier (lotSize = g_InitialBaseLot)
        // Grid position 2: g_GlobalGridPosition=2, (2-1)/2=0 → No multiplier (lotSize = g_InitialBaseLot)
        // Grid position 3: g_GlobalGridPosition=3, (3-1)/2=1 → First multiplier (lotSize = g_InitialBaseLot * LotMultiplier)
        // Grid position 4: g_GlobalGridPosition=4, (4-1)/2=1 → First multiplier (lotSize = g_InitialBaseLot * LotMultiplier)
        // Grid position 5: g_GlobalGridPosition=5, (5-1)/2=2 → Second multiplier (lotSize = g_InitialBaseLot * LotMultiplier^2)
        int multiplierLevel = (g_GlobalGridPosition - 1) / GridTradesForMultiplier;
        lotSize = g_InitialBaseLot * MathPow(LotMultiplier, multiplierLevel);
    }
    
    // Log the multiplier calculation
    if(EnableLogging) 
    {
        Print("=== GRID LOT SIZE CALCULATION ===");
        Print("  Grid Position: ", g_GlobalGridPosition);
        Print("  Grid Trades For Multiplier: ", GridTradesForMultiplier);
        int multiplierLevel = (g_GlobalGridPosition - 1) / GridTradesForMultiplier;
        Print("  Multiplier Level: ", multiplierLevel);
        Print("  Base Lot: ", g_InitialBaseLot);
        Print("  Lot Multiplier: ", LotMultiplier);
        Print("  Final Lot Size: ", lotSize);
        
        // Explain the multiplier logic
        if(g_GlobalGridPosition <= GridTradesForMultiplier)
        {
            Print("  No lot multiplier applied yet - will apply after grid position ", GridTradesForMultiplier);
        }
        else
        {
            Print("  Lot multiplier applied ", multiplierLevel, " times");
            Print("  Next multiplier increase at grid position ", (multiplierLevel+1)*GridTradesForMultiplier + 1);
        }
    }
    
    // Set price and color based on direction
    double price;
    color orderColor;
    
    if(g_CurrentTradeDirection == OP_BUY)
    {
        price = Ask;
        orderColor = clrBlue;
    }
    else // OP_SELL
    {
        price = Bid;
        orderColor = clrRed;
    }
    
    string comment = "Seq" + IntegerToString(g_CurrentSequence) + "_G" + IntegerToString(g_GlobalGridPosition);
    
    int ticket = OrderSend(Symbol(), g_CurrentTradeDirection, lotSize, price, Slippage, 0, 0, 
                          comment, MagicNumber, 0, orderColor);
    
    if(ticket > 0)
    {
        if(EnableLogging) 
        {
            string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
            Print("=== ", dirStr, " GRID TRADE PLACED ===");
            Print("  Sequence: ", g_CurrentSequence);
            Print("  Trade in sequence: ", g_TradesInCurrentSequence);
            Print("  Global grid position: ", g_GlobalGridPosition);
            Print("  Ticket: ", ticket);
            Print("  Lot Size: ", lotSize);
            Print("  Entry Price: ", price);
            int multiplierLevel = (g_GlobalGridPosition - 1) / GridTradesForMultiplier;
            Print("  Multiplier Level: ", multiplierLevel, " (", g_InitialBaseLot, " x ", MathPow(LotMultiplier, multiplierLevel), ")");
            Print("  Base lot size: ", g_InitialBaseLot);
        }
    }
    else
    {
        if(EnableLogging) Print("ERROR: Failed to place ", (g_CurrentTradeDirection == OP_BUY ? "buy" : "sell"), " grid trade. Error: ", GetLastError());
        // Revert counters if trade failed
        g_GlobalGridPosition--;
        g_TradesInCurrentSequence--;
    }
}

//+------------------------------------------------------------------+
//| Modify all trades to average take profit                       |
//+------------------------------------------------------------------+
void ModifyAllTradesToAverageTakeProfit()
{
    // Check that we have a valid direction
    if(g_CurrentTradeDirection == -1) return;
    
    double totalLots = 0;
    double weightedPrice = 0;
    int tradeCount = 0;
    
    // Calculate average entry price for current direction
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == g_CurrentTradeDirection)
        {
            totalLots += OrderLots();
            weightedPrice += OrderOpenPrice() * OrderLots();
            tradeCount++;
        }
    }
    
    if(tradeCount == 0) return;
    
    double averagePrice = weightedPrice / totalLots;
    double averageTakeProfit;
    
    if(g_InRecoveryMode)
    {
        // Calculate pip value for average take profit calculation
        double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
        if(MarketInfo(Symbol(), MODE_DIGITS) == 5 || MarketInfo(Symbol(), MODE_DIGITS) == 3)
            pipValue = pipValue * 10; // Adjust for 5-digit brokers
        
        // Calculate required profit in pips
        double requiredProfitPips = g_TotalAccumulatedLoss / (pipValue * totalLots);
        requiredProfitPips += RecoveryProfit;
        
        if(UseATR)
        {
            // In recovery mode, we still need to ensure we cover the required profit
            double atr = GetATRValue(ATR_TP_Timeframe);
            double atrTakeProfit, requiredTakeProfit;
            
            if(g_CurrentTradeDirection == OP_BUY)
            {
                atrTakeProfit = averagePrice + (atr * ATR_TP_Multiplier);
                requiredTakeProfit = averagePrice + (requiredProfitPips * Point * 10);
                
                // Use the maximum of ATR-based TP or required profit TP
                averageTakeProfit = MathMax(atrTakeProfit, requiredTakeProfit);
            }
            else // OP_SELL
            {
                atrTakeProfit = averagePrice - (atr * ATR_TP_Multiplier);
                requiredTakeProfit = averagePrice - (requiredProfitPips * Point * 10);
                
                // Use the minimum of ATR-based TP or required profit TP
                averageTakeProfit = MathMin(atrTakeProfit, requiredTakeProfit);
            }
            
            if(EnableLogging)
            {
                string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
                Print("=== ", dirStr, " AVERAGE TAKE PROFIT (ATR + RECOVERY) ===");
                Print("  ATR Value: ", atr);
                Print("  ATR Take Profit: ", atrTakeProfit);
                Print("  Required Take Profit: ", requiredTakeProfit);
                Print("  Selected Take Profit: ", averageTakeProfit);
            }
        }
        else
        {
            // Standard fixed take profit based on direction
            if(g_CurrentTradeDirection == OP_BUY)
                averageTakeProfit = averagePrice + (requiredProfitPips * Point * 10);
            else // OP_SELL
                averageTakeProfit = averagePrice - (requiredProfitPips * Point * 10);
        }
    }
    else
    {
        if(UseATR)
        {
            // Normal mode with ATR-based take profit
            double atr = GetATRValue(ATR_TP_Timeframe);
            
            if(g_CurrentTradeDirection == OP_BUY)
                averageTakeProfit = averagePrice + (atr * ATR_TP_Multiplier);
            else // OP_SELL
                averageTakeProfit = averagePrice - (atr * ATR_TP_Multiplier);
            
            if(EnableLogging)
            {
                string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
                Print("=== ", dirStr, " AVERAGE TAKE PROFIT (ATR) ===");
                Print("  ATR Value: ", atr);
                Print("  ATR Multiplier: ", ATR_TP_Multiplier);
                Print("  Average Price: ", averagePrice);
                Print("  Take Profit: ", averageTakeProfit);
            }
        }
        else
        {
            // Normal fixed take profit based on direction
            if(g_CurrentTradeDirection == OP_BUY)
                averageTakeProfit = averagePrice + (InitialTakeProfit * Point * 10);
            else // OP_SELL
                averageTakeProfit = averagePrice - (InitialTakeProfit * Point * 10);
        }
    }
    
    // Modify all trades of current direction
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == g_CurrentTradeDirection)
        {
            if(OrderTakeProfit() != averageTakeProfit)
            {
                bool result = OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), 
                                        averageTakeProfit, 0, clrYellow);
                if(!result && EnableLogging)
                {
                    Print("ERROR: Failed to modify trade ", OrderTicket(), ". Error: ", GetLastError());
                }
            }
        }
    }
    
    if(EnableLogging && !(UseATR || g_InRecoveryMode)) 
    {
        string dirStr = (g_CurrentTradeDirection == OP_BUY) ? "BUY" : "SELL";
        Print("=== ", dirStr, " AVERAGE TAKE PROFIT UPDATED ===");
        Print("  Total Lots: ", totalLots);
        Print("  Average Entry: ", averagePrice);
        Print("  Average Take Profit: ", averageTakeProfit);
        Print("  Recovery Mode: ", g_InRecoveryMode ? "YES" : "NO");
        if(g_InRecoveryMode)
        {
            Print("  Accumulated Loss: ", g_TotalAccumulatedLoss);
            Print("  Recovery Profit: ", RecoveryProfit, " pips");
        }
        Print("  Trades Modified: ", tradeCount);
    }
}

//+------------------------------------------------------------------+
//| Record loss and close all trades                               |
//+------------------------------------------------------------------+
void RecordLossAndCloseTrades()
{
    double totalLoss = 0;
    double totalLots = 0;
    int closedTrades = 0;
    
    // Calculate total loss and lots before closing
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
        {
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            totalLoss += profit; // This will be negative for losses
            totalLots += OrderLots();
        }
    }
    
    // Close all trades
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
        {
            bool result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);
            if(result) closedTrades++;
        }
    }
    
    // Update global loss tracking
    if(totalLoss < 0) // Only if there's actually a loss
    {
        g_TotalAccumulatedLoss += MathAbs(totalLoss);
        g_PreviousSequenceTotalLots = totalLots;
        g_InRecoveryMode = true;
        g_CurrentSequence++;
        
        if(EnableLogging) 
        {
            Print("=== LOSS RECORDED - BEARISH CROSSOVER ===");
            Print("  Sequence #", g_CurrentSequence - 1, " CLOSED IN LOSS");
            Print("  Trades Closed: ", closedTrades);
            Print("  Sequence Loss: ", totalLoss);
            Print("  Sequence Total Lots: ", totalLots);
            Print("  Accumulated Loss: ", g_TotalAccumulatedLoss);
            Print("  Global Grid Position: ", g_GlobalGridPosition, " (persisted)");
            Print("  Next Sequence: ", g_CurrentSequence);
            Print("  Recovery Mode: ACTIVATED");
            Print("  Next recovery trade lot size: ", g_PreviousSequenceTotalLots);
        }
    }
    else
    {
        if(EnableLogging) Print("Trades closed in profit. No loss recorded.");
        ResetToNormalMode();
    }
    
    // Reset current sequence tracking
    g_GridActive = false;
    g_TradesInCurrentSequence = 0;
    g_FirstTradeOfSequence = true;
    g_InitialTradeActive = false;
    // NOTE: g_GlobalGridPosition is NOT reset - it persists for recovery
}

//+------------------------------------------------------------------+
//| Close all trades                                               |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
    int closedTrades = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
        {
            bool result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrOrange);
            if(result) closedTrades++;
        }
    }
    
    if(EnableLogging) Print("Closed ", closedTrades, " trades due to new bullish crossover");
    
    // Reset current sequence tracking
    g_GridActive = false;
    g_TradesInCurrentSequence = 0;
    g_FirstTradeOfSequence = true;
}

//+------------------------------------------------------------------+
//| Reset to normal mode                                           |
//+------------------------------------------------------------------+
void ResetToNormalMode()
{
    // Reset recovery tracking
    g_InRecoveryMode = false;
    g_TotalAccumulatedLoss = 0;
    g_PreviousSequenceTotalLots = 0;
    
    // Reset sequence tracking
    g_CurrentSequence = 1;
    g_TradesInCurrentSequence = 0;
    g_FirstTradeOfSequence = true;
    
    // Reset grid tracking
    g_GlobalGridPosition = 0; // Reset global grid position when fully recovered
    g_GridActive = false;
    
    // Reset RSI continuation system
    g_WaitingForRSI = false;
    g_ContinuationTradeCount = 0;
    g_LastCompletionWasProfit = false;
    g_CompletionType = "";
    g_InitialTradeActive = false;
    
    if(EnableLogging) 
    {
        Print("=== RESET TO NORMAL MODE ===");
        Print("  FULL RECOVERY COMPLETE!");
        Print("  All sequences profitable");
        Print("  Ready for new trading cycle");
    }
}

//+------------------------------------------------------------------+
//| Count open trades                                              |
//+------------------------------------------------------------------+
int CountOpenTrades(int direction = -1)
{
    // If direction is not specified, use current trade direction
    if(direction == -1)
        direction = g_CurrentTradeDirection;
        
    // If still no direction specified, return count of all trades
    if(direction == -1)
    {
        return CountAllOpenTrades();
    }
    
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == direction)
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Count all open trades regardless of direction                    |
//+------------------------------------------------------------------+
int CountAllOpenTrades()
{
    int count = 0;
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && 
           (OrderType() == OP_BUY || OrderType() == OP_SELL))
        {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Expert comment function                                         |
//+------------------------------------------------------------------+
string GetStatusComment()
{
    string comment = "EMA Grid Recovery EA\n";
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    
    // Strategy-specific information
    if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
    {
        double fastEMA = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 0);
        double slowEMA = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 0);
        
        comment += "--- EMA Strategy ---\n";
        comment += "Fast EMA: " + DoubleToString(fastEMA, digits) + "\n";
        comment += "Slow EMA: " + DoubleToString(slowEMA, digits) + "\n";
    }
    else // STRATEGY_BOLLINGER_BANDS
    {
        double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 0);
        double middleBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 0);
        double lowerBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_LOWER, 0);
        double currentClose = iClose(Symbol(), 0, 0);
        
        comment += "--- Bollinger Bands Strategy ---\n";
        comment += "Entry Level: " + (BB_EntryLevel == BB_ENTRY_UPPER ? "Upper Band" : "Middle Band") + "\n";
        comment += "Exit Level: " + (BB_ExitLevel == BB_EXIT_MIDDLE ? "Middle Band" : "Lower Band") + "\n";
        comment += "Upper Band: " + DoubleToString(upperBand, digits) + "\n";
        comment += "Middle Band: " + DoubleToString(middleBand, digits) + "\n";
        comment += "Lower Band: " + DoubleToString(lowerBand, digits) + "\n";
        comment += "Current Close: " + DoubleToString(currentClose, digits) + "\n";
        
        // Display status relative to selected entry level
        if(BB_EntryLevel == BB_ENTRY_UPPER)
        {
            comment += "Above Entry (Upper): " + (currentClose > upperBand ? "YES" : "NO") + "\n";
        }
        else
        {
            comment += "Above Entry (Middle): " + (currentClose > middleBand ? "YES" : "NO") + "\n";
        }
        
        // Display status relative to selected exit level
        if(BB_ExitLevel == BB_EXIT_MIDDLE)
        {
            comment += "Below Exit (Middle): " + (currentClose < middleBand ? "YES" : "NO") + "\n";
        }
        else
        {
            comment += "Below Exit (Lower): " + (currentClose < lowerBand ? "YES" : "NO") + "\n";
        }
    }

    // Direction information
    string directionStr = "NONE";
    if(g_CurrentTradeDirection == OP_BUY) directionStr = "BUY";
    if(g_CurrentTradeDirection == OP_SELL) directionStr = "SELL";
    
    comment += "--- Trading State ---\n";
    comment += "Direction Mode: " + (TradeDirectionMode == MODE_BUY_ONLY ? "BUY ONLY" : 
                                  (TradeDirectionMode == MODE_SELL_ONLY ? "SELL ONLY" : "BOTH DIRECTIONS")) + "\n";
    comment += "Current Direction: " + directionStr + "\n";
    comment += "Buy Trades: " + IntegerToString(CountOpenTrades(OP_BUY)) + "\n";
    comment += "Sell Trades: " + IntegerToString(CountOpenTrades(OP_SELL)) + "\n";
    comment += "Sequence: " + IntegerToString(g_CurrentSequence) + "\n";
    comment += "Trades in Sequence: " + IntegerToString(g_TradesInCurrentSequence) + "\n";
    comment += "Grid Active: " + (g_GridActive ? "YES" : "NO") + "\n";
    comment += "Global Grid Position: " + IntegerToString(g_GlobalGridPosition) + "\n";
    comment += "Recovery Mode: " + (g_InRecoveryMode ? "YES" : "NO") + "\n";
    comment += "Flip Recovery: " + (g_FlipRecoveryActive ? "YES" : "NO") + "\n";
    if(g_InRecoveryMode)
    {
        comment += "Accumulated Loss: " + DoubleToString(g_TotalAccumulatedLoss, 2) + "\n";
        if(g_FlipRecoveryActive)
            comment += "Opposite Seq Loss: " + DoubleToString(g_OppositeSequenceTotalLoss, 2) + "\n";
        comment += "Recovery Lot Size: " + DoubleToString(g_PreviousSequenceTotalLots, 2) + "\n";
    }
    
    // ATR Information when enabled
    if(UseATR)
    {
        comment += "--- ATR Settings ---\n";
        comment += "ATR Period: " + IntegerToString(ATR_Period) + "\n";
        double atrTP = GetATRValue(ATR_TP_Timeframe);
        double atrGrid = GetATRValue(ATR_Grid_Timeframe);
        comment += "ATR TP (" + GetTimeframeString(ATR_TP_Timeframe) + "): " + DoubleToString(atrTP, digits) + "\n";
        comment += "ATR Grid (" + GetTimeframeString(ATR_Grid_Timeframe) + "): " + DoubleToString(atrGrid, digits) + "\n";
        comment += "TP Distance: " + DoubleToString(atrTP * ATR_TP_Multiplier, digits) + "\n";
        comment += "Grid Distance: " + DoubleToString(atrGrid * ATR_Grid_Multiplier, digits) + "\n";
    }
    
    // RSI Continuation Information
    if(EnableRSIContinuation)
    {
        comment += "--- RSI Continuation ---\n";
        double rsiValue = GetRSIValue(RSI_Timeframe);
        comment += "RSI (" + IntegerToString(RSI_Period) + "): " + DoubleToString(rsiValue, 2) + "\n";
        comment += "RSI Threshold: " + DoubleToString(RSI_OverboughtLevel, 1) + "\n";
        comment += "Continuation Count: " + IntegerToString(g_ContinuationTradeCount) + "\n";
        comment += "Waiting for RSI: " + (g_WaitingForRSI ? "YES" : "NO") + "\n";
        comment += "Initial Trade Active: " + (g_InitialTradeActive ? "YES" : "NO") + "\n";
        if(MaxContinuationTrades > 0)
        {
            comment += "Max Continuations: " + IntegerToString(MaxContinuationTrades) + "\n";
        }
    }
    
    return comment;
}

//+------------------------------------------------------------------+
//| Get timeframe as string                                         |
//+------------------------------------------------------------------+
string GetTimeframeString(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN";
        default:         return "Custom";
    }
}

//+------------------------------------------------------------------+
//| Timer function to update comment                               |
//+------------------------------------------------------------------+
void OnTimer()
{
    Comment(GetStatusComment());
}

//+------------------------------------------------------------------+
//| Get RSI value for specified timeframe                          |
//+------------------------------------------------------------------+
double GetRSIValue(ENUM_TIMEFRAMES timeframe)
{
    return iRSI(Symbol(), timeframe, RSI_Period, PRICE_CLOSE, 0);
}

//+------------------------------------------------------------------+
//| Check if RSI continuation conditions are met                   |
//+------------------------------------------------------------------+
bool CheckRSIContinuationConditions()
{
    if(!EnableRSIContinuation) return false;
    
    // Check trend condition based on selected strategy
    bool trendConditionMet = false;
    
    if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
    {
        // EMA trend condition - Fast EMA above Slow EMA
        double fastEMA = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 0);
        double slowEMA = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 0);
        trendConditionMet = (fastEMA > slowEMA);
    }
    else // STRATEGY_BOLLINGER_BANDS
    {
        // Bollinger Bands trend condition based on selected entry level
        double closePrice = iClose(Symbol(), 0, 1);
        
        if(BB_EntryLevel == BB_ENTRY_UPPER)
        {
            // Entry level is upper band
            double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 1);
            trendConditionMet = (closePrice > upperBand);
        }
        else // BB_ENTRY_MIDDLE
        {
            // Entry level is middle band
            double middleBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 1);
            trendConditionMet = (closePrice > middleBand);
        }
    }
    
    if(!trendConditionMet) return false;
    
    // Check RSI condition
    double rsiValue = GetRSIValue(RSI_Timeframe);
    if(rsiValue >= RSI_OverboughtLevel) return false;
    
    // Check continuation limit
    if(MaxContinuationTrades > 0 && g_ContinuationTradeCount >= MaxContinuationTrades) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Check RSI waiting conditions                                   |
//+------------------------------------------------------------------+
void CheckRSIWaitingConditions()
{
    if(!g_WaitingForRSI) return;
    
    // Check if trend condition is still valid based on selected strategy
    bool trendConditionValid = false;
    
    if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
    {
        // Check if Fast EMA is still above Slow EMA
        double fastEMA = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 0);
        double slowEMA = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 0);
        trendConditionValid = (fastEMA > slowEMA);
        
        if(!trendConditionValid && EnableLogging)
        {
            Print("RSI waiting cancelled - Fast EMA no longer above Slow EMA");
        }
    }
    else // STRATEGY_BOLLINGER_BANDS
    {
        // Check if price is still above the selected entry level
        double closePrice = iClose(Symbol(), 0, 1);
        
        if(BB_EntryLevel == BB_ENTRY_UPPER)
        {
            // Entry level is upper band
            double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 1);
            trendConditionValid = (closePrice > upperBand);
            
            if(!trendConditionValid && EnableLogging)
            {
                Print("RSI waiting cancelled - Price no longer above upper Bollinger Band");
            }
        }
        else // BB_ENTRY_MIDDLE
        {
            // Entry level is middle band
            double middleBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 1);
            trendConditionValid = (closePrice > middleBand);
            
            if(!trendConditionValid && EnableLogging)
            {
                Print("RSI waiting cancelled - Price no longer above middle Bollinger Band");
            }
        }
    }
    
    if(!trendConditionValid)
    {
        // Trend condition no longer valid, cancel waiting
        g_WaitingForRSI = false;
        return;
    }
    
    // Check if RSI has come down
    double rsiValue = GetRSIValue(RSI_Timeframe);
    if(rsiValue < RSI_OverboughtLevel)
    {
        // RSI condition now satisfied, place continuation trade
        g_WaitingForRSI = false;
        if(EnableLogging) 
        {
            Print("=== RSI WAITING COMPLETED ===");
            Print("  RSI Value: ", rsiValue);
            Print("  RSI Threshold: ", RSI_OverboughtLevel);
            Print("  Placing continuation trade");
        }
        PlaceContinuationInitialTrade();
    }
}

//+------------------------------------------------------------------+
//| Handle completion of initial trade only                        |
//+------------------------------------------------------------------+
void HandleInitialTradeCompletion()
{
    g_LastCompletionWasProfit = true;
    g_CompletionType = "INITIAL";
    g_InitialTradeActive = false;
    
    if(EnableLogging) 
    {
        Print("=== INITIAL TRADE COMPLETED ===");
        Print("  Continuation trades so far: ", g_ContinuationTradeCount);
    }
    
    if(!EnableRSIContinuation)
    {
        if(EnableLogging) Print("RSI Continuation disabled, ending sequence");
        return;
    }
    
    // Check continuation conditions
    if(CheckRSIContinuationConditions())
    {
        if(EnableLogging) Print("RSI Continuation conditions met, placing new initial trade");
        PlaceContinuationInitialTrade();
    }
    else
    {
        // Check if we should wait for RSI
        bool trendConditionMet = false;
        
        if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
        {
            double fastEMA = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 0);
            double slowEMA = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 0);
            trendConditionMet = (fastEMA > slowEMA);
        }
        else // STRATEGY_BOLLINGER_BANDS
        {
            double closePrice = iClose(Symbol(), 0, 1);
            
            if(BB_EntryLevel == BB_ENTRY_UPPER)
            {
                // Entry level is upper band
                double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 1);
                trendConditionMet = (closePrice > upperBand);
            }
            else // BB_ENTRY_MIDDLE
            {
                // Entry level is middle band
                double middleBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 1);
                trendConditionMet = (closePrice > middleBand);
            }
        }
        
        double rsiValue = GetRSIValue(RSI_Timeframe);
        
        if(trendConditionMet && rsiValue >= RSI_OverboughtLevel)
        {
            // Trend condition good but RSI overbought, wait for RSI
            g_WaitingForRSI = true;
            if(EnableLogging) 
            {
                Print("=== WAITING FOR RSI ===");
                if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
                {
                    Print("  Fast EMA > Slow EMA: YES");
                }
                else // STRATEGY_BOLLINGER_BANDS
                {
                    if(BB_EntryLevel == BB_ENTRY_UPPER)
                    {
                        Print("  Price > Upper BB: YES");
                    }
                    else
                    {
                        Print("  Price > Middle BB: YES");
                    }
                }
                Print("  RSI Value: ", rsiValue);
                Print("  RSI Threshold: ", RSI_OverboughtLevel);
                Print("  Waiting for RSI to come down...");
            }
        }
        else
        {
            if(EnableLogging) 
            {
                Print("=== CONTINUATION SEQUENCE ENDED ===");
                if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
                {
                    Print("  Fast EMA > Slow EMA: ", trendConditionMet ? "YES" : "NO");
                }
                else // STRATEGY_BOLLINGER_BANDS
                {
                    if(BB_EntryLevel == BB_ENTRY_UPPER)
                    {
                        Print("  Price > Upper BB: ", trendConditionMet ? "YES" : "NO");
                    }
                    else
                    {
                        Print("  Price > Middle BB: ", trendConditionMet ? "YES" : "NO");
                    }
                }
                Print("  RSI < Threshold: ", (rsiValue < RSI_OverboughtLevel) ? "YES" : "NO");
                Print("  Max trades reached: ", (MaxContinuationTrades > 0 && g_ContinuationTradeCount >= MaxContinuationTrades) ? "YES" : "NO");
                Print("  Total continuation trades: ", g_ContinuationTradeCount);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Handle completion of grid/recovery trades                      |
//+------------------------------------------------------------------+
void HandleGridRecoveryCompletion()
{
    g_LastCompletionWasProfit = true;
    g_CompletionType = (g_InRecoveryMode) ? "RECOVERY" : "GRID";
    
    if(EnableLogging) 
    {
        Print("=== GRID/RECOVERY COMPLETED ===");
        Print("  Completion Type: ", g_CompletionType);
        Print("  Resetting continuation counter");
    }
    
    // Reset continuation counter for fresh start
    g_ContinuationTradeCount = 0;
    
    // Reset to normal mode (existing function)
    ResetToNormalMode();
    
    if(!EnableRSIContinuation)
    {
        if(EnableLogging) Print("RSI Continuation disabled, waiting for new signal");
        return;
    }
    
    // Check if we should start fresh sequence
    if(CheckRSIContinuationConditions())
    {
        if(EnableLogging) Print("Starting fresh sequence after grid/recovery completion");
        PlaceContinuationInitialTrade();
    }
    else
    {
        // Check if we should wait for RSI
        bool trendConditionMet = false;
        
        if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
        {
            double fastEMA = iMA(Symbol(), 0, FastEMA_Period, 0, MODE_EMA, EMA_Price, 0);
            double slowEMA = iMA(Symbol(), 0, SlowEMA_Period, 0, MODE_EMA, EMA_Price, 0);
            trendConditionMet = (fastEMA > slowEMA);
        }
        else // STRATEGY_BOLLINGER_BANDS
        {
            double closePrice = iClose(Symbol(), 0, 1);
            
            if(BB_EntryLevel == BB_ENTRY_UPPER)
            {
                // Entry level is upper band
                double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 1);
                trendConditionMet = (closePrice > upperBand);
            }
            else // BB_ENTRY_MIDDLE
            {
                // Entry level is middle band
                double middleBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 1);
                trendConditionMet = (closePrice > middleBand);
            }
        }
        
        double rsiValue = GetRSIValue(RSI_Timeframe);
        
        if(trendConditionMet && rsiValue >= RSI_OverboughtLevel)
        {
            g_WaitingForRSI = true;
            if(EnableLogging) 
            {
                Print("=== WAITING FOR RSI AFTER RECOVERY ===");
                if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
                {
                    Print("  Fast EMA > Slow EMA: YES");
                }
                else // STRATEGY_BOLLINGER_BANDS
                {
                    if(BB_EntryLevel == BB_ENTRY_UPPER)
                    {
                        Print("  Price > Upper BB: YES");
                    }
                    else
                    {
                        Print("  Price > Middle BB: YES");
                    }
                }
                Print("  RSI Value: ", rsiValue);
                Print("  Waiting for RSI to come down...");
            }
        }
        else
        {
            if(EnableLogging) 
            {
                if(EntryStrategy == STRATEGY_EMA_CROSSOVER)
                {
                    Print("Conditions not met for fresh sequence, waiting for new EMA crossover");
                }
                else // STRATEGY_BOLLINGER_BANDS
                {
                    if(BB_EntryLevel == BB_ENTRY_UPPER)
                    {
                        Print("Conditions not met for fresh sequence, waiting for price to close above upper Bollinger Band");
                    }
                    else
                    {
                        Print("Conditions not met for fresh sequence, waiting for price to close above middle Bollinger Band");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Place continuation initial trade                               |
//+------------------------------------------------------------------+
void PlaceContinuationInitialTrade()
{
    // Increment continuation counter
    g_ContinuationTradeCount++;
    
    // Always use initial lot size for continuation trades
    double lotSize = g_InitialBaseLot;
    
    double price = Ask;
    double takeProfit;
    
    // Calculate take profit based on ATR or fixed pips
    if(UseATR)
    {
        double atr = GetATRValue(ATR_TP_Timeframe);
        takeProfit = price + (atr * ATR_TP_Multiplier);
        
        if(EnableLogging)
        {
            Print("=== CONTINUATION TRADE TAKE PROFIT (ATR) ===");
            Print("  ATR Value: ", atr);
            Print("  ATR Multiplier: ", ATR_TP_Multiplier);
            Print("  Take Profit: ", takeProfit);
        }
    }
    else
    {
        // Standard fixed take profit
        takeProfit = price + (InitialTakeProfit * Point * 10);
    }
    
    string comment = "Seq" + IntegerToString(g_CurrentSequence) + "_Cont" + IntegerToString(g_ContinuationTradeCount);
    int ticket = OrderSend(Symbol(), OP_BUY, lotSize, price, Slippage, 0, takeProfit, 
                          comment, MagicNumber, 0, clrGreen);
    
    if(ticket > 0)
    {
        // Set sequence flags
        g_LastEntryPrice = price;
        g_FirstTradeOfSequence = true;
        g_TradesInCurrentSequence = 1;
        g_GridActive = false;
        g_InitialTradeActive = true;
        g_CurrentSequence++; // Increment sequence for each continuation
        
        if(EnableLogging) 
        {
            Print("=== CONTINUATION INITIAL TRADE PLACED ===");
            Print("  Continuation Number: ", g_ContinuationTradeCount);
            Print("  Sequence: ", g_CurrentSequence);
            Print("  Ticket: ", ticket);
            Print("  Lot Size: ", lotSize);
            Print("  Entry Price: ", price);
            Print("  Take Profit: ", takeProfit);
            Print("  Using ATR: ", UseATR ? "YES" : "NO");
            double rsiValue = GetRSIValue(RSI_Timeframe);
            Print("  Current RSI: ", rsiValue);
        }
    }
    else
    {
        if(EnableLogging) Print("ERROR: Failed to place continuation trade. Error: ", GetLastError());
        // Revert counter if trade failed
        g_ContinuationTradeCount--;
    }
}

//+------------------------------------------------------------------+
//| Calculate ATR value                                             |
//+------------------------------------------------------------------+
double GetATRValue(ENUM_TIMEFRAMES timeframe)
{
    return iATR(Symbol(), timeframe, ATR_Period, 0);
}

//+------------------------------------------------------------------+
//| Update Bollinger Bands values                                   |
//+------------------------------------------------------------------+
void UpdateBollingerBandsValues()
{
    g_BB_Upper = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 0);
    g_BB_Middle = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 0);
    g_BB_Lower = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_LOWER, 0);
    
    // Check if this is the first initialization
    if(!g_BollingerBandsInitialized)
    {
        g_BollingerBandsInitialized = true;
        if(EnableLogging) Print("Bollinger Bands initialized: Upper=", g_BB_Upper, ", Middle=", g_BB_Middle, ", Lower=", g_BB_Lower);
    }
}

//+------------------------------------------------------------------+
//| Check for Bollinger Bands signals on closed bars                 |
//+------------------------------------------------------------------+
void CheckBollingerBandsSignals()
{
    // Update the Bollinger Bands values
    UpdateBollingerBandsValues();
    
    // Get close price of the last completed bar
    double closePrice = iClose(Symbol(), 0, 1);
    
    // Get Bollinger Bands values for the last completed bar
    double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_UPPER, 1);
    double middleBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_MAIN, 1);
    double lowerBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, 0, BB_Price, MODE_LOWER, 1);
    
    // Check buy signal based on selected entry level
    bool buySignal = false;
    if(BB_EntryLevel == BB_ENTRY_UPPER)
    {
        // Buy signal: Price closed above upper band
        buySignal = closePrice > upperBand;
        g_PriceAboveUpperBand = buySignal;
        
        if(buySignal && EnableLogging)
            Print("BOLLINGER BANDS: Price closed above upper band at ", closePrice);
    }
    else // BB_ENTRY_MIDDLE
    {
        // Buy signal: Price closed above middle band
        buySignal = closePrice > middleBand;
        g_PriceAboveUpperBand = (closePrice > upperBand); // Still track this for other logic
        
        if(buySignal && EnableLogging)
            Print("BOLLINGER BANDS: Price closed above middle band at ", closePrice);
    }
    
    // Process buy signal
    if(buySignal)
        ProcessSignal(OP_BUY);
    
    // Check sell signal based on selected exit level
    bool sellSignal = false;
    if(BB_ExitLevel == BB_EXIT_MIDDLE)
    {
        // Sell signal: Price closed below middle band
        sellSignal = closePrice < middleBand;
        g_PriceBelowMiddleBand = sellSignal;
        
        if(sellSignal && EnableLogging)
            Print("BOLLINGER BANDS: Price closed below middle band at ", closePrice);
    }
    else // BB_EXIT_LOWER
    {
        // Sell signal: Price closed below lower band
        sellSignal = closePrice < lowerBand;
        g_PriceBelowMiddleBand = (closePrice < middleBand); // Still track this for other logic
        
        if(sellSignal && EnableLogging)
            Print("BOLLINGER BANDS: Price closed below lower band at ", closePrice);
    }
    
    // Process sell signal
    if(sellSignal)
        ProcessSignal(OP_SELL);
}

//+------------------------------------------------------------------+
//| Handle Bollinger Bands entry signal                             |
//+------------------------------------------------------------------+
void OnBollingerBandsEntrySignal()
{
    // If we already have trades open, we should ignore any new entry signals.
    if(CountOpenTrades() > 0)
    {
        if(EnableLogging) Print("Bollinger Bands entry signal ignored, trades are already open.");
        return;
    }
    
    // Reset RSI continuation system for new trend
    g_ContinuationTradeCount = 0;
    g_WaitingForRSI = false;
    
    // Determine lot size for new trade
    double lotSize = g_InitialBaseLot; // Default to initial lot size
    if(g_InRecoveryMode)
    {
        lotSize = g_PreviousSequenceTotalLots;
        if(EnableLogging) Print("Recovery mode active. Using combined lot size: ", lotSize);
        if(EnableLogging) Print("Starting Sequence #", g_CurrentSequence);
    }
    else
    {
        if(EnableLogging) Print("Normal mode. Starting Sequence #", g_CurrentSequence);
    }
    
    // Place initial buy trade
    PlaceInitialBuyTrade(lotSize);
}

//+------------------------------------------------------------------+
//| Handle Bollinger Bands exit signal                              |
//+------------------------------------------------------------------+
void OnBollingerBandsExitSignal()
{
    // Cancel any RSI waiting and reset continuation system
    g_WaitingForRSI = false;
    g_ContinuationTradeCount = 0;
    
    if(CountOpenTrades() > 0)
    {
        if(EnableLogging) Print("Bollinger Bands exit signal - closing all trades and recording loss");
        RecordLossAndCloseTrades();
    }
}

//+------------------------------------------------------------------+
//| Process trading signal                                          |
//+------------------------------------------------------------------+
void ProcessSignal(int signalDirection)
{
    // If trading direction mode restricts this signal, ignore it
    if((TradeDirectionMode == MODE_BUY_ONLY && signalDirection == OP_SELL) ||
       (TradeDirectionMode == MODE_SELL_ONLY && signalDirection == OP_BUY))
    {
        if(EnableLogging) Print("Signal ignored due to TradeDirectionMode restriction");
        return;
    }
    
    // If no trades are open, start a new sequence in the signal direction
    if(CountAllOpenTrades() == 0)
    {
        if(EnableLogging) Print("No trades open, starting new sequence in direction: ", 
                                signalDirection == OP_BUY ? "BUY" : "SELL");
                                
        g_CurrentTradeDirection = signalDirection;
        
        // Reset all sequence counters for fresh start
        g_ContinuationTradeCount = 0;
        g_WaitingForRSI = false;
        g_FlipRecoveryActive = false;
        
        // Determine lot size for new trade
        double lotSize = g_InitialBaseLot; // Default to initial lot size
        
        if(g_InRecoveryMode)
        {
            lotSize = g_PreviousSequenceTotalLots;
            if(EnableLogging) Print("Recovery mode active. Using combined lot size: ", lotSize);
        }
        
        // Place initial trade in signal direction
        PlaceInitialTrade(signalDirection, lotSize);
        return;
    }
    
    // If trades are already open in same direction, ignore signal
    if(CountOpenTrades(signalDirection) > 0)
    {
        if(EnableLogging) Print("Signal ignored, already have trades in the ", 
                               signalDirection == OP_BUY ? "BUY" : "SELL", " direction");
        return;
    }
    
    // If trades are open in opposite direction, implement direction-flip recovery
    int oppositeDirection = (signalDirection == OP_BUY) ? OP_SELL : OP_BUY;
    
    if(CountOpenTrades(oppositeDirection) > 0)
    {
        if(EnableLogging) Print("Opposite direction signal received, initiating flip-and-recover");
        FlipAndRecover(signalDirection);
        return;
    }
}

//+------------------------------------------------------------------+
//| Flip trade direction and recover                                |
//+------------------------------------------------------------------+
void FlipAndRecover(int newDirection)
{
    // Get the current direction that we are flipping from
    int oldDirection = g_CurrentTradeDirection;
    string oldDirectionStr = (oldDirection == OP_BUY) ? "BUY" : "SELL";
    string newDirectionStr = (newDirection == OP_BUY) ? "BUY" : "SELL";
    
    if(EnableLogging) 
    {
        Print("=== FLIP AND RECOVER ===");
        Print("  Flipping from ", oldDirectionStr, " to ", newDirectionStr);
    }
    
    // Calculate total loss and total lots before closing trades
    double totalLoss = 0;
    double totalLots = 0;
    int tradesToClose = 0;
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == oldDirection)
        {
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            totalLoss += profit; // Will be negative for losses
            totalLots += OrderLots();
            tradesToClose++;
        }
    }
    
    if(EnableLogging) 
    {
        Print("  Total loss from ", oldDirectionStr, " trades: ", totalLoss);
        Print("  Total lots to flip: ", totalLots);
    }
    
    // Close all trades in the old direction
    int closedTrades = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber && OrderType() == oldDirection)
        {
            double closePrice = (oldDirection == OP_BUY) ? Bid : Ask;
            bool result = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, 
                                    (oldDirection == OP_BUY) ? clrRed : clrRed);
            if(result) closedTrades++;
        }
    }
    
    if(closedTrades != tradesToClose)
    {
        if(EnableLogging) Print("WARNING: Failed to close some trades. Closed ", closedTrades, " out of ", tradesToClose);
    }
    
    // Update recovery state
    if(totalLoss < 0) // Only if there's actually a loss
    {
        g_TotalAccumulatedLoss += MathAbs(totalLoss);
        g_OppositeSequenceTotalLots = totalLots;
        g_OppositeSequenceTotalLoss = MathAbs(totalLoss);
        g_InRecoveryMode = true;
        g_FlipRecoveryActive = true;
        
        if(EnableLogging) 
        {
            Print("  Total accumulated loss now: ", g_TotalAccumulatedLoss);
            Print("  Recovery mode: ACTIVATED");
            Print("  Flip recovery: ACTIVATED");
        }
    }
    else
    {
        // Even if we closed in profit, we should still flip direction
        // but don't need to activate recovery mode
        if(EnableLogging) Print("  Trades closed in profit. No loss recorded for recovery.");
    }
    
    // Update trade direction
    g_CurrentTradeDirection = newDirection;
    
    // Update sequence tracking for new direction
    g_CurrentSequence++; 
    g_GridActive = false;
    g_TradesInCurrentSequence = 0;
    g_FirstTradeOfSequence = true;
    g_InitialTradeActive = false;
    
    // Place initial trade in new direction
    // If we had a loss, use the combined lot size; otherwise use base lot size
    double lotSize = (totalLoss < 0) ? totalLots : g_InitialBaseLot;
    PlaceInitialTrade(newDirection, lotSize);
}

//+------------------------------------------------------------------+
//| Place initial trade in the specified direction                  |
//+------------------------------------------------------------------+
void PlaceInitialTrade(int direction, double lotSize)
{
    double price, takeProfit;
    
    // Set entry price based on direction
    if(direction == OP_BUY)
    {
        price = Ask;
    }
    else // OP_SELL
    {
        price = Bid;
    }
    
    // Set take profit immediately based on mode
    if(g_InRecoveryMode)
    {
        // Calculate recovery take profit based on direction
        takeProfit = CalculateRecoveryTakeProfit(direction, price, lotSize);
    }
    else
    {
        // Use ATR or normal take profit
        if(UseATR)
        {
            double atr = GetATRValue(ATR_TP_Timeframe);
            
            if(direction == OP_BUY)
                takeProfit = price + (atr * ATR_TP_Multiplier);
            else // OP_SELL
                takeProfit = price - (atr * ATR_TP_Multiplier);
                
            if(EnableLogging) Print("Using ATR-based Take Profit: ATR=", atr, " x Multiplier=", ATR_TP_Multiplier);
        }
        else
        {
            // Normal fixed take profit
            if(direction == OP_BUY)
                takeProfit = price + (InitialTakeProfit * Point * 10);
            else // OP_SELL
                takeProfit = price - (InitialTakeProfit * Point * 10);
        }
    }
    
    string comment = "Seq" + IntegerToString(g_CurrentSequence) + "_T1";
    color orderColor = (direction == OP_BUY) ? clrGreen : clrRed;
    
    int ticket = OrderSend(Symbol(), direction, lotSize, price, Slippage, 0, takeProfit, 
                          comment, MagicNumber, 0, orderColor);
    
    if(ticket > 0)
    {
        // Set sequence flags and tracking
        g_LastEntryPrice = price;
        g_FirstTradeOfSequence = true;
        g_TradesInCurrentSequence = 1;
        g_GridActive = false;
        g_InitialTradeActive = true; // Mark as initial trade
        g_CurrentTradeDirection = direction; // Set current trade direction
        // NOTE: g_GlobalGridPosition is NOT incremented (this is not a grid trade)
        
        if(EnableLogging) 
        {
            string dirStr = (direction == OP_BUY) ? "BUY" : "SELL";
            Print("=== INITIAL ", dirStr, " TRADE PLACED ===");
            Print("  Sequence: ", g_CurrentSequence);
            Print("  Ticket: ", ticket);
            Print("  Lot Size: ", lotSize);
            Print("  Entry Price: ", price);
            Print("  Take Profit: ", takeProfit);
            Print("  Recovery Mode: ", g_InRecoveryMode ? "YES" : "NO");
            Print("  Flip Recovery: ", g_FlipRecoveryActive ? "YES" : "NO");
            Print("  Global Grid Position: ", g_GlobalGridPosition, " (unchanged)");
            Print("  Trades in Sequence: ", g_TradesInCurrentSequence);
        }
    }
    else
    {
        if(EnableLogging) Print("ERROR: Failed to place initial ", (direction == OP_BUY ? "buy" : "sell"), " trade. Error: ", GetLastError());
    }
} 