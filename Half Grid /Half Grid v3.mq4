//+------------------------------------------------------------------+
//|                                                GridStrategy.mq4  |
//|                                Example code with fixes for MQL4 |
//+------------------------------------------------------------------+
#property copyright "YourName"
#property link      "http://www.example.com"
#property version   "4.10"
#property strict    // ensures stricter compilation checks

//--- Core EA Settings
extern int      MagicNumber             = 12345;   // Unique identifier for trades
extern int      StartHour               = 9;       // Hour to start trading (0-23)
extern int      StartMinute             = 0;       // Minute to start trading (0-59)

//--- Risk Management Settings
extern bool     UseStopLoss             = true;    // Enable/disable stoploss functionality
extern double   MaxLossAmount           = 100;     // Maximum loss in USD before closing all trades
extern double   ProfitTarget            = 50;      // Target profit to close all trades (USD)

//--- Lot Size Settings
extern double   SequenceInitialLot      = 0.01;    // Initial lot size for sequence trades
extern double   GridInitialLot          = 0.01;    // Initial lot size for grid trades
extern double   MaxLotPerTrade          = 0.64;    // Maximum allowed lot size per trade
extern double   MartingaleMultiplier    = 2.0;     // Multiplier for grid trade lot sizes

//--- Grid Configuration
extern double   GridStep                = 10;      // Distance between grid levels in pips
extern int      MaxGridLevel            = 7;       // Maximum number of grid levels
extern double   PipsAgainst             = 20;      // Pips against before starting grid

//--- Custom Anchor Trade Settings
extern int      CustomAnchorTrade1      = 0;       // First anchor trade number (0 = disabled)
extern double   CustomAnchorLot1        = 0.01;    // Lot size for first anchor trade
extern int      CustomAnchorTrade2      = 0;       // Second anchor trade number (0 = disabled)
extern double   CustomAnchorLot2        = 0.01;    // Lot size for second anchor trade
extern int      CustomAnchorTrade3      = 0;       // Third anchor trade number (0 = disabled)
extern double   CustomAnchorLot3        = 0.01;    // Lot size for third anchor trade
extern int      CustomAnchorTrade4      = 0;       // Fourth anchor trade number (0 = disabled)
extern double   CustomAnchorLot4        = 0.01;    // Lot size for fourth anchor trade
extern int      CustomAnchorTrade5      = 0;       // Fifth anchor trade number (0 = disabled)
extern double   CustomAnchorLot5        = 0.01;    // Lot size for fifth anchor trade
extern int      CustomAnchorTrade6      = 0;       // Sixth anchor trade number (0 = disabled)
extern double   CustomAnchorLot6        = 0.01;    // Lot size for sixth anchor trade

//--- re-entry logic
extern int      MinGridTradesForReEntry = 5;       //Number of trade algo should take before re-entring

double pipValue;

//--- tracking for dual sequences
int    currentDay           = -1;    
bool   cycleActive          = false;  // Overall cycle tracking

// Buy sequence variables
bool   buySequenceActive    = false;
double buyAnchorPrice       = 0.0;
int    buyAnchorCount       = 0;
int    buyFirstTicket       = -1;
bool   buyGridStarted       = false;
int    buyGridIndex         = 0;
int    buyGridCount         = 0;
bool   buyEligibleForNext   = false;

// Sell sequence variables
bool   sellSequenceActive   = false;
double sellAnchorPrice      = 0.0;
int    sellAnchorCount      = 0;
int    sellFirstTicket      = -1;
bool   sellGridStarted      = false;
int    sellGridIndex        = 0;
int    sellGridCount        = 0;
bool   sellEligibleForNext  = false;

//--- for partial expansions
#define MAX_GRID_LINES 2000
struct GridLineInfo
{
   bool   used;          
   int    gridIndex;     
   int    tradesOpened;  
};

// Separate grid tracking for buy and sell sequences
GridLineInfo buyGridLines[MAX_GRID_LINES];
GridLineInfo sellGridLines[MAX_GRID_LINES];

//+------------------------------------------------------------------+
//| Additional dashboard variables                                   |
//+------------------------------------------------------------------+
string dashboardBgName = "DashboardBG";
string balanceLabelName = "BalanceLabel";
string equityLabelName = "EquityLabel";
string profitLabelName = "ProfitLabel"; 
string buyStatusLabelName = "BuyStatusLabel";
string sellStatusLabelName = "SellStatusLabel";
string stopLossLabelName = "StopLossLabel";

//+------------------------------------------------------------------+
//| init()                                                          |
//+------------------------------------------------------------------+
int init()
{
   if(Digits==3 || Digits==5) pipValue = 0.00010;
   else                       pipValue = 0.0001;

   ResetBuyGridLines();
   ResetSellGridLines();

   // Create close button
   CreateCloseButton();
   
   // Create dashboard
   CreateDashboard();
   
   // Enable chart events - use the older method that works in all MT4 versions
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);  // Use value 1 instead of true
   
   Print("Half Grid Strategy initialized, button created");
   return(0);
}

//+------------------------------------------------------------------+
//| deinit()                                                        |
//+------------------------------------------------------------------+
int deinit()
{
   ObjectDelete(0, "btnCloseAllTrades");
   
   // Delete dashboard objects
   ObjectDelete(dashboardBgName);
   ObjectDelete(balanceLabelName);
   ObjectDelete(equityLabelName);
   ObjectDelete(profitLabelName);
   ObjectDelete(buyStatusLabelName);
   ObjectDelete(sellStatusLabelName);
   ObjectDelete(stopLossLabelName);
   
   return(0);
}

//+------------------------------------------------------------------+
//| start()                                                         |
//+------------------------------------------------------------------+
int start()
{
   // Update dashboard on every tick
   UpdateDashboard();

   // Alternative button check for older MT4 versions
   if(ObjectGetInteger(0, "btnCloseAllTrades", OBJPROP_STATE))
   {
      Print("Close button state detected");
      ObjectSetInteger(0, "btnCloseAllTrades", OBJPROP_STATE, false);
      CloseAllTradesWithMagic(MagicNumber);
      ResetAll(false);
      return(0);
   }

   // Check if there are any trades with our magic number
   bool hasActiveTrades = AreTradesOpenWithMagic(MagicNumber);
   
   // If we think the cycle is active but no trades found, reset
   if(cycleActive && !hasActiveTrades)
   {
      ResetAll(false);
   }

   // Check stoploss if enabled and we have active trades
   if(UseStopLoss && cycleActive)
   {
      double currentProfit = CalculateTotalProfit(MagicNumber);
      
      // If we're losing more than the max loss amount, close all trades
      if(currentProfit <= -MaxLossAmount)
      {
         Print("⚠️ STOPLOSS TRIGGERED: Current loss (", currentProfit, 
               ") exceeded maximum allowed (", MaxLossAmount, ")");
         CloseAllTradesWithMagic(MagicNumber);
         ResetAll(false);
         return(0);
      }
   }

   // Check if we should start a new cycle
   int currentHour = TimeHour(TimeCurrent());
   int currentMinute = TimeMinute(TimeCurrent());
   bool isCorrectTimeToTrade = false;
   
   // Check if current time is exactly at start time (or within first minute)
   if(currentHour == StartHour && currentMinute >= StartMinute && currentMinute < StartMinute + 1) {
      isCorrectTimeToTrade = true;
   }
   
   // Initialize both sequences simultaneously if conditions are met
   if(!cycleActive && currentDay != Day() && isCorrectTimeToTrade)
   {
      // Use custom lot size for first anchor (anchor #1)
      double buyLotSize = GetCustomAnchorLotSize(1);
      double sellLotSize = GetCustomAnchorLotSize(1);
      
      // Start both sequences with initial anchor trades
      int buyTicket = OpenTrade(OP_BUY, buyLotSize, "BUY_ANCHOR_1");
      int sellTicket = OpenTrade(OP_SELL, sellLotSize, "SELL_ANCHOR_1");
      
      // Only activate if both trades were opened successfully
      if(buyTicket > 0 && sellTicket > 0)
      {
         // Setup buy sequence
         buySequenceActive = true;
         buyAnchorPrice = OrderOpenPriceByTicket(buyTicket);
         buyAnchorCount = 1;
         buyFirstTicket = buyTicket;
         
         // Setup sell sequence
         sellSequenceActive = true;
         sellAnchorPrice = OrderOpenPriceByTicket(sellTicket);
         sellAnchorCount = 1;
         sellFirstTicket = sellTicket;
         
         // Activate cycle and update day tracking
         cycleActive = true;
         currentDay = Day();
         
         Print("=== NEW CYCLE STARTED ===");
         Print("Buy anchor at: ", buyAnchorPrice, " Sell anchor at: ", sellAnchorPrice);
      }
      else
      {
         Print("Failed to open both anchor trades. Will try again.");
      }
   }
   else
   {
      // Debug logging for time conditions if not starting
      if(currentDay == Day() && !cycleActive)
         Print("Waiting for new day before placing trades. Current day: ", Day());
      else if(!isCorrectTimeToTrade && !cycleActive)
         Print("Waiting for start time. Current time: ", TimeToStr(TimeCurrent()), 
               " Target: ", StartHour, ":", StartMinute);
   }

   // Main trading logic for active cycle
   if(cycleActive)
   {
      // First check if profit target has been reached
      double totalProfit = CalculateTotalProfit(MagicNumber);
      if(totalProfit >= ProfitTarget)
      {
         Print("Profit target of ", ProfitTarget, " reached: ", totalProfit);
         CloseAllTradesWithMagic(MagicNumber);
         ResetAll(true);
         return(0);
      }
      
      // Process buy sequence if active
      if(buySequenceActive)
      {
         ProcessBuySequence();
      }
      
      // Process sell sequence if active
      if(sellSequenceActive)
      {
         ProcessSellSequence();
      }
   }

   return(0);
}

//+------------------------------------------------------------------+
//| ProcessBuySequence                                              |
//+------------------------------------------------------------------+
void ProcessBuySequence()
{
   // Check if we should start placing grid trades
   if(!buyGridStarted && buyAnchorCount > 0)
   {
      double triggerPrice = buyAnchorPrice - PipsAgainst*pipValue;
      if(Bid <= triggerPrice)
      {
         buyGridStarted = true;
         Print("Buy grid trades started. Trigger price: ", triggerPrice);
      }
   }
   
   // Place grid trades if conditions are met
   if(buyGridStarted)
   {
      PlaceBuyGridTrades();
   }
   
   // Place next anchor trade if eligible
   if(buyEligibleForNext)
   {
      if(Bid >= buyAnchorPrice)
      {
         // Calculate next anchor number and get appropriate lot size
         int nextAnchorNumber = buyAnchorCount + 1;
         double lotSize = GetCustomAnchorLotSize(nextAnchorNumber);
         
         int t = OpenTrade(OP_BUY, lotSize, 
                        "BUY_ANCHOR_" + IntegerToString(nextAnchorNumber));
         if(t > 0)
         {
            buyAnchorCount++;
            buyEligibleForNext = false;
            buyGridCount = 0;
            buyGridIndex = 0;
            ResetBuyGridLines();
            
            Print("New buy anchor trade #", buyAnchorCount, " placed");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ProcessSellSequence                                             |
//+------------------------------------------------------------------+
void ProcessSellSequence()
{
   // Check if we should start placing grid trades
   if(!sellGridStarted && sellAnchorCount > 0)
   {
      double triggerPrice = sellAnchorPrice + PipsAgainst*pipValue;
      if(Ask >= triggerPrice)
      {
         sellGridStarted = true;
         Print("Sell grid trades started. Trigger price: ", triggerPrice);
      }
   }
   
   // Place grid trades if conditions are met
   if(sellGridStarted)
   {
      PlaceSellGridTrades();
   }
   
   // Place next anchor trade if eligible
   if(sellEligibleForNext)
   {
      if(Ask <= sellAnchorPrice)
      {
         // Calculate next anchor number and get appropriate lot size
         int nextAnchorNumber = sellAnchorCount + 1;
         double lotSize = GetCustomAnchorLotSize(nextAnchorNumber);
         
         int t = OpenTrade(OP_SELL, lotSize, 
                        "SELL_ANCHOR_" + IntegerToString(nextAnchorNumber));
         if(t > 0)
         {
            sellAnchorCount++;
            sellEligibleForNext = false;
            sellGridCount = 0;
            sellGridIndex = 0;
            ResetSellGridLines();
            
            Print("New sell anchor trade #", sellAnchorCount, " placed");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PlaceBuyGridTrades                                              |
//+------------------------------------------------------------------+
void PlaceBuyGridTrades()
{
   // Safety counter to prevent too many trades in a single function call
   static int buyGridSafetyCounter = 0;
   
   // Safety reset every 100 ticks
   static int buyTickCounter = 0;
   buyTickCounter++;
   if(buyTickCounter > 100) {
      buyTickCounter = 0;
      buyGridSafetyCounter = 0;
   }
   
   // Hard safety limit 
   if(buyGridSafetyCounter >= 10) {
      Print("⚠️ BUY GRID SAFETY LIMIT REACHED");
      return;
   }
   
   double currentPrice = Bid;
   if(currentPrice >= buyAnchorPrice) return; // No grid trades if price is above anchor
   
   // Calculate how many grid levels based on distance from anchor price
   double dist = (buyAnchorPrice - currentPrice) / (GridStep * pipValue);
   int maxLevel = (int)MathFloor(dist);
   
   // Safety limit for grid levels
   maxLevel = MathMin(maxLevel, 10);
   
   Print("Processing buy grid levels. Max level: ", maxLevel);
   
   // Process each potential grid level
   for(int level=1; level <= maxLevel && level <= MaxGridLevel; level++)
   {
      double levelPrice = buyAnchorPrice - level*GridStep*pipValue;
      if(currentPrice <= levelPrice)
      {
         // Count existing grid trades at this level
         int existingTrades = CountExactGridTrades(OP_SELL, level, true); // true = buy sequence
         
         Print("Buy sequence level ", level, " price ", levelPrice, 
               " has ", existingTrades, " of ", buyAnchorCount, " needed");
         
         // Skip if we already have enough trades at this level
         if(existingTrades >= buyAnchorCount) {
            continue;
         }
         
         // Calculate needed trades
         int neededTrades = buyAnchorCount - existingTrades;
         
         // Calculate appropriate lot size
         double lot = CalculateGridLotSize(GridInitialLot, level-1);
         
         // Place the needed trades
         for(int n=0; n < neededTrades; n++)
         {
            // Safety check
            if(buyGridSafetyCounter >= 10) break;
            
            // Create a trade comment that clearly identifies the sequence and level
            string comment = "BUY_GRID_L" + IntegerToString(level) + "_A" + IntegerToString(buyAnchorCount);
            
            int ticket = OpenTrade(OP_SELL, lot, comment);
            if(ticket > 0) {
               buyGridSafetyCounter++;
               Print("Placed buy sequence grid sell trade at level ", level);
            }
         }
         
         // Track this grid level
         if(!buyGridLines[level].used) {
            buyGridLines[level].used = true;
            buyGridLines[level].gridIndex = buyGridIndex;
            buyGridLines[level].tradesOpened = buyAnchorCount;
            
            // Count new grid level for re-entry eligibility
            buyGridCount++;
            buyGridIndex++;
            
            // Check if we can place another anchor trade
            if(buyGridCount >= MinGridTradesForReEntry) {
               buyEligibleForNext = true;
               Print("Buy sequence now eligible for next anchor trade");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PlaceSellGridTrades                                             |
//+------------------------------------------------------------------+
void PlaceSellGridTrades()
{
   // Safety counter to prevent too many trades in a single function call
   static int sellGridSafetyCounter = 0;
   
   // Safety reset every 100 ticks
   static int sellTickCounter = 0;
   sellTickCounter++;
   if(sellTickCounter > 100) {
      sellTickCounter = 0;
      sellGridSafetyCounter = 0;
   }
   
   // Hard safety limit 
   if(sellGridSafetyCounter >= 10) {
      Print("⚠️ SELL GRID SAFETY LIMIT REACHED");
      return;
   }
   
   double currentPrice = Ask;
   if(currentPrice <= sellAnchorPrice) return; // No grid trades if price is below anchor
   
   // Calculate how many grid levels based on distance from anchor price
   double dist = (currentPrice - sellAnchorPrice) / (GridStep * pipValue);
   int maxLevel = (int)MathFloor(dist);
   
   // Safety limit for grid levels
   maxLevel = MathMin(maxLevel, 10);
   
   Print("Processing sell grid levels. Max level: ", maxLevel);
   
   // Process each potential grid level
   for(int level=1; level <= maxLevel && level <= MaxGridLevel; level++)
   {
      double levelPrice = sellAnchorPrice + level*GridStep*pipValue;
      if(currentPrice >= levelPrice)
      {
         // Count existing grid trades at this level
         int existingTrades = CountExactGridTrades(OP_BUY, level, false); // false = sell sequence
         
         Print("Sell sequence level ", level, " price ", levelPrice, 
               " has ", existingTrades, " of ", sellAnchorCount, " needed");
         
         // Skip if we already have enough trades at this level
         if(existingTrades >= sellAnchorCount) {
            continue;
         }
         
         // Calculate needed trades
         int neededTrades = sellAnchorCount - existingTrades;
         
         // Calculate appropriate lot size
         double lot = CalculateGridLotSize(GridInitialLot, level-1);
         
         // Place the needed trades
         for(int n=0; n < neededTrades; n++)
         {
            // Safety check
            if(sellGridSafetyCounter >= 10) break;
            
            // Create a trade comment that clearly identifies the sequence and level
            string comment = "SELL_GRID_L" + IntegerToString(level) + "_A" + IntegerToString(sellAnchorCount);
            
            int ticket = OpenTrade(OP_BUY, lot, comment);
            if(ticket > 0) {
               sellGridSafetyCounter++;
               Print("Placed sell sequence grid buy trade at level ", level);
            }
         }
         
         // Track this grid level
         if(!sellGridLines[level].used) {
            sellGridLines[level].used = true;
            sellGridLines[level].gridIndex = sellGridIndex;
            sellGridLines[level].tradesOpened = sellAnchorCount;
            
            // Count new grid level for re-entry eligibility
            sellGridCount++;
            sellGridIndex++;
            
            // Check if we can place another anchor trade
            if(sellGridCount >= MinGridTradesForReEntry) {
               sellEligibleForNext = true;
               Print("Sell sequence now eligible for next anchor trade");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CountExactGridTrades                                            |
//+------------------------------------------------------------------+
int CountExactGridTrades(int orderType, int level, bool isBuySequence)
{
   int count = 0;
   string levelMarker;
   
   // Construct the marker based on sequence type
   if(isBuySequence)
      levelMarker = "BUY_GRID_L" + IntegerToString(level) + "_";
   else
      levelMarker = "SELL_GRID_L" + IntegerToString(level) + "_";
   
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol() && OrderType()==orderType)
         {
            string comment = OrderComment();
            
            // Count only trades with exact level marker in comment
            if(StringFind(comment, levelMarker) >= 0)
               count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Create the "Close All Trades" button                            |
//+------------------------------------------------------------------+
void CreateCloseButton()
{
   string btnName = "btnCloseAllTrades";
   ObjectDelete(btnName); // remove if exists - note: no '0' parameter in older versions

   // Create a button - use older method for compatibility
   ObjectCreate(btnName, OBJ_BUTTON, 0, 0, 0);
   ObjectSet(btnName, OBJPROP_XDISTANCE, 10);
   ObjectSet(btnName, OBJPROP_YDISTANCE, 10);
   ObjectSet(btnName, OBJPROP_XSIZE, 100);
   ObjectSet(btnName, OBJPROP_YSIZE, 30);
   ObjectSetText(btnName, "Close Trades", 10, "Arial", clrWhite);
   ObjectSet(btnName, OBJPROP_BGCOLOR, clrRed);
   
   Print("Close Trades button created");
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "btnCloseAllTrades")
      {
         Print("Close Trades button clicked - closing all trades");
         CloseAllTradesWithMagic(MagicNumber);
         ResetAll(false);
         Print("All trades closed");
      }
   }
}

//+------------------------------------------------------------------+
//| ResetAll                                                        |
//+------------------------------------------------------------------+
void ResetAll(bool closedByProfit)
{
   Print("=== RESETTING STRATEGY ===");
   
   // Reset overall cycle state
   cycleActive = false;
   
   // Reset buy sequence variables
   buySequenceActive = false;
   buyAnchorPrice = 0.0;
   buyAnchorCount = 0;
   buyFirstTicket = -1;
   buyGridStarted = false;
   buyGridIndex = 0;
   buyGridCount = 0;
   buyEligibleForNext = false;
   
   // Reset sell sequence variables
   sellSequenceActive = false;
   sellAnchorPrice = 0.0;
   sellAnchorCount = 0;
   sellFirstTicket = -1;
   sellGridStarted = false;
   sellGridIndex = 0;
   sellGridCount = 0;
   sellEligibleForNext = false;
   
   // Handle day tracking
   if(closedByProfit) {
      currentDay = Day(); 
   } else {
      // When manually closed, set to previous day to force waiting until next day
      currentDay = Day() - 1;
      Print("Manual close - will wait for next day's start time");
   }

   // Reset grid tracking
   ResetBuyGridLines();
   ResetSellGridLines();
}

//+------------------------------------------------------------------+
//| ResetBuyGridLines                                              |
//+------------------------------------------------------------------+
void ResetBuyGridLines()
{
   for(int i=0; i<MAX_GRID_LINES; i++)
   {
      buyGridLines[i].used = false;
      buyGridLines[i].gridIndex = 0;
      buyGridLines[i].tradesOpened = 0;
   }
}

//+------------------------------------------------------------------+
//| ResetSellGridLines                                              |
//+------------------------------------------------------------------+
void ResetSellGridLines()
{
   for(int i=0; i<MAX_GRID_LINES; i++)
   {
      sellGridLines[i].used = false;
      sellGridLines[i].gridIndex = 0;
      sellGridLines[i].tradesOpened = 0;
   }
}

//+------------------------------------------------------------------+
//| AreTradesOpenWithMagic                                          |
//+------------------------------------------------------------------+
bool AreTradesOpenWithMagic(int magNum)
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber()==magNum && OrderSymbol()==Symbol())
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| CloseAllTradesWithMagic                                         |
//+------------------------------------------------------------------+
void CloseAllTradesWithMagic(int magNum)
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber()==magNum && OrderSymbol()==Symbol())
         {
            double lots = OrderLots();
            int type = OrderType();
            double price = (type==OP_BUY) ? Bid : Ask;

            // Check return value
            bool result = OrderClose(OrderTicket(), lots, price, 30, clrNONE);
            if(!result)
               Print("OrderClose failed, err=", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CalculateTotalProfit                                            |
//+------------------------------------------------------------------+
double CalculateTotalProfit(int magNum)
{
   double total=0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber()==magNum && OrderSymbol()==Symbol())
         {
            total += (OrderProfit() + OrderSwap() + OrderCommission());
         }
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalculateSequenceProfits                                        |
//+------------------------------------------------------------------+
void CalculateSequenceProfits(double &buyProfit, double &sellProfit)
{
   buyProfit = 0.0;
   sellProfit = 0.0;
   
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         {
            double profit = OrderProfit() + OrderSwap() + OrderCommission();
            string comment = OrderComment();
            
            // Identify which sequence this trade belongs to
            if(StringFind(comment, "BUY_") >= 0)
               buyProfit += profit;
            else if(StringFind(comment, "SELL_") >= 0)
               sellProfit += profit;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OrderOpenPriceByTicket                                          |
//+------------------------------------------------------------------+
double OrderOpenPriceByTicket(int ticket)
{
   if(OrderSelect(ticket, SELECT_BY_TICKET))
      return OrderOpenPrice();
   return 0.0;
}

//+------------------------------------------------------------------+
//| OpenTrade                                                        |
//+------------------------------------------------------------------+
int OpenTrade(int tradeType, double lots, string comment)
{
   RefreshRates();
   double slippage = 3;
   double price = (tradeType==OP_BUY) ? Ask : Bid;

   // store the ticket, no data-loss warning since it's an int
   int ticket = OrderSend(Symbol(), tradeType, lots, price, slippage, 0, 0, 
                          comment, MagicNumber, 0, clrNONE);
   
   if(ticket <= 0)
      Print("Failed to open trade: ", GetLastError(), " Comment: ", comment);
      
   return ticket;
}

//+------------------------------------------------------------------+
//| CalculateGridLotSize                                            |
//+------------------------------------------------------------------+
double CalculateGridLotSize(double baseLot, int gridIndexLocal)
{
   double newLot = baseLot * MathPow(MartingaleMultiplier, gridIndexLocal);
   if(newLot > MaxLotPerTrade)
      newLot = MaxLotPerTrade;
   return NormalizeLotSize(newLot);
}

//+------------------------------------------------------------------+
//| NormalizeLotSize                                                |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
{
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   double normalized = MathFloor(lots / lotStep) * lotStep;
   return normalized;
}

//+------------------------------------------------------------------+
//| GetCustomAnchorLotSize                                          |
//+------------------------------------------------------------------+
double GetCustomAnchorLotSize(int anchorNumber)
{
   // Default to standard lot size if no custom size is specified
   double lotSize = SequenceInitialLot;
   
   // Check if this anchor number matches any of our custom anchor trades
   if(anchorNumber == CustomAnchorTrade1) lotSize = CustomAnchorLot1;
   else if(anchorNumber == CustomAnchorTrade2) lotSize = CustomAnchorLot2;
   else if(anchorNumber == CustomAnchorTrade3) lotSize = CustomAnchorLot3;
   else if(anchorNumber == CustomAnchorTrade4) lotSize = CustomAnchorLot4;
   else if(anchorNumber == CustomAnchorTrade5) lotSize = CustomAnchorLot5;
   else if(anchorNumber == CustomAnchorTrade6) lotSize = CustomAnchorLot6;
   
   // Return normalized lot size
   return NormalizeLotSize(lotSize);
}

//+------------------------------------------------------------------+
//| CreateDashboard                                                 |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   // Create background panel
   ObjectCreate(dashboardBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSet(dashboardBgName, OBJPROP_CORNER, 0); // Top left corner
   ObjectSet(dashboardBgName, OBJPROP_XDISTANCE, 300); // Position in center area
   ObjectSet(dashboardBgName, OBJPROP_YDISTANCE, 20); // Near top of chart
   ObjectSet(dashboardBgName, OBJPROP_XSIZE, 220); // Width
   ObjectSet(dashboardBgName, OBJPROP_YSIZE, 140); // Height increased for more labels
   ObjectSet(dashboardBgName, OBJPROP_BGCOLOR, C'25,25,25');
   ObjectSet(dashboardBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSet(dashboardBgName, OBJPROP_COLOR, clrWhite);
   
   // Create Balance Label
   ObjectCreate(balanceLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSet(balanceLabelName, OBJPROP_CORNER, 0);
   ObjectSet(balanceLabelName, OBJPROP_XDISTANCE, 310);
   ObjectSet(balanceLabelName, OBJPROP_YDISTANCE, 30);
   ObjectSetText(balanceLabelName, "Balance: $0.00", 10, "Arial Bold", clrWhite);
   
   // Create Equity Label
   ObjectCreate(equityLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSet(equityLabelName, OBJPROP_CORNER, 0);
   ObjectSet(equityLabelName, OBJPROP_XDISTANCE, 310);
   ObjectSet(equityLabelName, OBJPROP_YDISTANCE, 50);
   ObjectSetText(equityLabelName, "Equity: $0.00", 10, "Arial Bold", clrWhite);
   
   // Create Profit Label
   ObjectCreate(profitLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSet(profitLabelName, OBJPROP_CORNER, 0);
   ObjectSet(profitLabelName, OBJPROP_XDISTANCE, 310);
   ObjectSet(profitLabelName, OBJPROP_YDISTANCE, 70);
   ObjectSetText(profitLabelName, "Profit: $0.00", 10, "Arial Bold", clrWhite);
   
   // Create Buy Sequence Status Label
   ObjectCreate(buyStatusLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSet(buyStatusLabelName, OBJPROP_CORNER, 0);
   ObjectSet(buyStatusLabelName, OBJPROP_XDISTANCE, 310);
   ObjectSet(buyStatusLabelName, OBJPROP_YDISTANCE, 90);
   ObjectSetText(buyStatusLabelName, "Buy: Inactive", 10, "Arial Bold", clrWhite);
   
   // Create Sell Sequence Status Label
   ObjectCreate(sellStatusLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSet(sellStatusLabelName, OBJPROP_CORNER, 0);
   ObjectSet(sellStatusLabelName, OBJPROP_XDISTANCE, 310);
   ObjectSet(sellStatusLabelName, OBJPROP_YDISTANCE, 110);
   ObjectSetText(sellStatusLabelName, "Sell: Inactive", 10, "Arial Bold", clrWhite);
   
   // Create StopLoss Status Label
   ObjectCreate(stopLossLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSet(stopLossLabelName, OBJPROP_CORNER, 0);
   ObjectSet(stopLossLabelName, OBJPROP_XDISTANCE, 310);
   ObjectSet(stopLossLabelName, OBJPROP_YDISTANCE, 130);
   ObjectSetText(stopLossLabelName, "StopLoss: Disabled", 10, "Arial Bold", clrWhite);
}

//+------------------------------------------------------------------+
//| UpdateDashboard                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double balance = AccountBalance();
   double equity = AccountEquity();
   double profit = equity - balance;
   
   // Calculate sequence specific profits
   double buyProfit = 0.0;
   double sellProfit = 0.0;
   CalculateSequenceProfits(buyProfit, sellProfit);
   
   string balanceText = "Balance: $" + DoubleToStr(balance, 2);
   string equityText = "Equity: $" + DoubleToStr(equity, 2);
   string profitText = "Profit: $" + DoubleToStr(profit, 2) + "/" + DoubleToStr(ProfitTarget, 2);
   
   // Updated status texts with profits
   string buyText = "Buy: " + (buySequenceActive ? "Active" : "Inactive");
   buyText += " (" + DoubleToStr(buyProfit, 2) + ")";
   
   string sellText = "Sell: " + (sellSequenceActive ? "Active" : "Inactive");
   sellText += " (" + DoubleToStr(sellProfit, 2) + ")";
   
   // StopLoss status with current settings
   string slText;
   if(UseStopLoss) {
      slText = "StopLoss: $" + DoubleToStr(MaxLossAmount, 2);
      // Add warning if getting close to stoploss
      if(profit < 0 && MathAbs(profit) > (0.7 * MaxLossAmount))
         slText += " ⚠️";
   } else {
      slText = "StopLoss: Disabled";
   }
   
   // Set colors based on profits
   color profitColor = (profit >= 0) ? clrLime : clrRed;
   color buyColor = (buyProfit >= 0) ? clrLime : clrRed;
   color sellColor = (sellProfit >= 0) ? clrLime : clrRed;
   color slColor = UseStopLoss ? 
                  (profit < 0 && MathAbs(profit) > (0.7 * MaxLossAmount) ? clrRed : clrYellow) : 
                  clrDarkGray;
   
   ObjectSetText(balanceLabelName, balanceText, 10, "Arial Bold", clrWhite);
   ObjectSetText(equityLabelName, equityText, 10, "Arial Bold", clrWhite);
   ObjectSetText(profitLabelName, profitText, 10, "Arial Bold", profitColor);
   ObjectSetText(buyStatusLabelName, buyText, 10, "Arial Bold", buyColor);
   ObjectSetText(sellStatusLabelName, sellText, 10, "Arial Bold", sellColor);
   ObjectSetText(stopLossLabelName, slText, 10, "Arial Bold", slColor);
}
//+------------------------------------------------------------------+
