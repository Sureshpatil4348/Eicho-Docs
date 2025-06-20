//+------------------------------------------------------------------+
//|                                        BollingerZScoreGridEA.mq4 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                        https://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023"
#property link      ""
#property version   "1.00"
#property strict

//--- Input Parameters: Bollinger Bands Settings
input int BB_Period = 20;                      // Period for Bollinger Bands
input double BB_Deviation = 2.0;               // Deviation for Bollinger Bands
input int BB_Shift = 0;                        // Shift for Bollinger Bands
input ENUM_APPLIED_PRICE BB_Applied_Price = PRICE_CLOSE; // Price type for BB

//--- Input Parameters: Z-Score Settings
input int ZScore_Period = 20;                  // Period for Z-Score calculation
input double ZScore_Threshold_Upper = 2.8;     // Z-Score level to trigger a SELL
input double ZScore_Threshold_Lower = -2.8;    // Z-Score level to trigger a BUY

//--- Input Parameters: RSI Settings
input int RSI_Period = 14;                     // Period for RSI calculation
input int RSI_Oversold = 30;                   // RSI oversold level for BUY signal
input int RSI_Overbought = 70;                 // RSI overbought level for SELL signal
input ENUM_APPLIED_PRICE RSI_Applied_Price = PRICE_CLOSE; // Price type for RSI

//--- Input Parameters: Confirmation Method
enum ConfirmationMethodEnum {
   USE_ZSCORE,                                 // Use Z-Score only
   USE_RSI,                                    // Use RSI only
   USE_BOTH                                    // Use both Z-Score AND RSI
};
input ConfirmationMethodEnum Confirmation_Method = USE_ZSCORE; // Method for trade confirmation

//--- Input Parameters: ATR Settings for Grid
input int ATR_Period = 14;                     // Period for ATR calculation
input double ATR_Multiplier_For_Grid = 1.5;    // Multiplier for ATR to set grid distance

//--- Input Parameters: Trade & Money Management
input double Initial_LotSize = 0.01;           // Lot size of the first trade
input bool Use_Martingale = true;              // Enable/disable martingale lot multiplier
input double LotSize_Multiplier = 2.0;         // Martingale lot size multiplier for grid trades
input double Max_LotSize = 0.5;                // Maximum lot size for grid trades
input int Max_Grid_Trades = 5;                 // Maximum number of trades in a single grid cycle
input int Average_TP_In_Pips = 20;             // Take profit in pips from the average price
input bool Adjust_TP_For_MaxLot = true;        // Adjust take profit when max lot size is reached

//--- Input Parameters: EA General Settings
input int MagicNumber = 12345;                 // Unique ID for trades placed by this EA
input int Slippage = 3;                        // Maximum allowed slippage
input int Max_Spread = 5;                      // Maximum allowed spread to open a trade (in pips)
input string Trade_Comment = "BB_ZScore_Grid_EA"; // Comment for trades

//--- Input Parameters: Adaptive Recovery Settings
input bool Use_Adaptive_Recovery = false;      // Enable/disable adaptive recovery system
input int MaxGridLevels = 7;                   // Maximum grid levels before cutting losses
input double Recovery_Profit_Target = 50.0;    // Target profit in account currency for a recovery sequence

//--- Global Variables
double point;                                  // Point value adjusted for digits
bool newBar = false;                           // Flag for new bar detection

//--- Global Variables for Adaptive Recovery
bool inRecoveryMode = false;                   // Flag for recovery mode
double cumulativeLotSize = 0.0;                // Total lot size from closed sequences
double totalRealizedLoss = 0.0;                // Total realized loss from closed sequences
int currentSequenceCount = 0;                  // Counter for tracking sequences

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set point value based on digits
   point = Point;
   if(Digits == 3 || Digits == 5)
      point = Point * 10;
      
   // Print initialization message
   Print("BollingerZScoreGridEA initialized with MagicNumber: ", MagicNumber);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up if needed
   Print("BollingerZScoreGridEA removed with reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for a new bar
   if(!IsNewBar())
      return;
      
   // Check if trading is allowed
   if(!IsTradeAllowed())
   {
      Print("Trading is not allowed");
      return;
   }
   
   // Check if spread is acceptable
   double currentSpread = MarketInfo(Symbol(), MODE_SPREAD) * Point / point;
   if(currentSpread > Max_Spread)
   {
      Print("Current spread (", currentSpread, ") exceeds maximum allowed spread (", Max_Spread, ")");
      return;
   }
   
   // Calculate indicators
   double upperBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, BB_Shift, BB_Applied_Price, MODE_UPPER, 1);
   double lowerBand = iBands(Symbol(), 0, BB_Period, BB_Deviation, BB_Shift, BB_Applied_Price, MODE_LOWER, 1);
   double atrValue = iATR(Symbol(), 0, ATR_Period, 1);
   double zScore = CalculateZScore(ZScore_Period);
   double rsiValue = iRSI(Symbol(), 0, RSI_Period, RSI_Applied_Price, 1);
   
   // Count open trades
   int buyCount = GetOpenTradesCount(OP_BUY);
   int sellCount = GetOpenTradesCount(OP_SELL);
   
   // Check if we are in a trading cycle
   bool inBuyCycle = buyCount > 0;
   bool inSellCycle = sellCount > 0;
   
   // Adaptive Recovery: Check for max grid levels and close sequence if needed
   if(Use_Adaptive_Recovery)
   {
      int buyGrid = GetGridLevelCount(OP_BUY);
      int sellGrid = GetGridLevelCount(OP_SELL);
      if(buyGrid >= MaxGridLevels)
      {
         CloseSequenceAndUpdateMetrics(OP_BUY);
         return;
      }
      if(sellGrid >= MaxGridLevels)
      {
         CloseSequenceAndUpdateMetrics(OP_SELL);
         return;
      }
   }
   
   // Entry Logic - Only if we're not in any cycle
   if(!inBuyCycle && !inSellCycle)
   {
      double entryLot = Initial_LotSize;
      if(Use_Adaptive_Recovery && inRecoveryMode)
         entryLot = CalculateRecoveryLotSize();
      // Sell Entry Condition
      bool sellCondition = false;
      
      switch(Confirmation_Method)
      {
         case USE_ZSCORE:
            sellCondition = (Close[1] > upperBand && zScore >= ZScore_Threshold_Upper);
            break;
         case USE_RSI:
            sellCondition = (Close[1] > upperBand && rsiValue >= RSI_Overbought);
            break;
         case USE_BOTH:
            sellCondition = (Close[1] > upperBand && zScore >= ZScore_Threshold_Upper && rsiValue >= RSI_Overbought);
            break;
      }
      
      if(sellCondition)
      {
         Print("SELL signal: BB=", NormalizeDouble(upperBand, Digits), 
               ", Close=", NormalizeDouble(Close[1], Digits), 
               ", Z-Score=", NormalizeDouble(zScore, 2), 
               ", RSI=", NormalizeDouble(rsiValue, 2));
         OpenTrade(OP_SELL, entryLot);
      }
      
      // Buy Entry Condition
      bool buyCondition = false;
      
      switch(Confirmation_Method)
      {
         case USE_ZSCORE:
            buyCondition = (Close[1] < lowerBand && zScore <= ZScore_Threshold_Lower);
            break;
         case USE_RSI:
            buyCondition = (Close[1] < lowerBand && rsiValue <= RSI_Oversold);
            break;
         case USE_BOTH:
            buyCondition = (Close[1] < lowerBand && zScore <= ZScore_Threshold_Lower && rsiValue <= RSI_Oversold);
            break;
      }
      
      if(buyCondition)
      {
         Print("BUY signal: BB=", NormalizeDouble(lowerBand, Digits), 
               ", Close=", NormalizeDouble(Close[1], Digits), 
               ", Z-Score=", NormalizeDouble(zScore, 2), 
               ", RSI=", NormalizeDouble(rsiValue, 2));
         OpenTrade(OP_BUY, entryLot);
      }
   }
   
   // Grid Management Logic
   if(inSellCycle && sellCount < Max_Grid_Trades)
   {
      double lastSellPrice = GetLastTradePrice(OP_SELL);
      double nextGridPrice = lastSellPrice + (atrValue * ATR_Multiplier_For_Grid);
      
      if(Ask >= nextGridPrice)
      {
         double lastLotSize = GetLastLotSize(OP_SELL);
         double newLotSize = Initial_LotSize;
         
         if(Use_Martingale)
         {
            // Apply martingale multiplier based on the number of existing trades
            newLotSize = NormalizeDouble(Initial_LotSize * MathPow(LotSize_Multiplier, sellCount), 2);
            
            // Apply max lot size limit if needed
            if(newLotSize > Max_LotSize)
            {
               Print("Martingale calculation capped: ", newLotSize, " limited to Max_LotSize=", Max_LotSize);
               newLotSize = Max_LotSize;
            }
            else
            {
               Print("Martingale calculation: Initial_LotSize=", Initial_LotSize, " * LotSize_Multiplier=", LotSize_Multiplier, " ^ sellCount=", sellCount, " = ", newLotSize);
            }
         }
         
         OpenTrade(OP_SELL, newLotSize);
      }
   }
   
   if(inBuyCycle && buyCount < Max_Grid_Trades)
   {
      double lastBuyPrice = GetLastTradePrice(OP_BUY);
      double nextGridPrice = lastBuyPrice - (atrValue * ATR_Multiplier_For_Grid);
      
      if(Bid <= nextGridPrice)
      {
         double lastLotSize = GetLastLotSize(OP_BUY);
         double newLotSize = Initial_LotSize;
         
         if(Use_Martingale)
         {
            // Apply martingale multiplier based on the number of existing trades
            newLotSize = NormalizeDouble(Initial_LotSize * MathPow(LotSize_Multiplier, buyCount), 2);
            
            // Apply max lot size limit if needed
            if(newLotSize > Max_LotSize)
            {
               Print("Martingale calculation capped: ", newLotSize, " limited to Max_LotSize=", Max_LotSize);
               newLotSize = Max_LotSize;
            }
            else
            {
               Print("Martingale calculation: Initial_LotSize=", Initial_LotSize, " * LotSize_Multiplier=", LotSize_Multiplier, " ^ buyCount=", buyCount, " = ", newLotSize);
            }
         }
         
         OpenTrade(OP_BUY, newLotSize);
      }
   }
   
   // Average Take Profit Logic
   if(inBuyCycle)
   {
      double avgBuyPrice = GetCycleAveragePrice(OP_BUY);
      double targetTpPrice;
      if(Use_Adaptive_Recovery && inRecoveryMode)
         targetTpPrice = CalculateRecoveryTakeProfit(OP_BUY, avgBuyPrice);
      else if(Adjust_TP_For_MaxLot && HasMaxLotSizeTrade(OP_BUY))
      {
         double riskRewardRatio = CalculateRiskRewardRatio(OP_BUY);
         double adjustedTP = Average_TP_In_Pips / riskRewardRatio;
         targetTpPrice = avgBuyPrice + (adjustedTP * point);
         Print("Adjusted TP for BUY cycle (max lot reached): ", adjustedTP, " pips, target price: ", targetTpPrice);
      }
      else
         targetTpPrice = avgBuyPrice + (Average_TP_In_Pips * point);
      
      if(Bid >= targetTpPrice)
      {
         CloseAllCycleTrades(OP_BUY);
         if(Use_Adaptive_Recovery && inRecoveryMode)
            ResetRecoveryState();
      }
   }
   
   if(inSellCycle)
   {
      double avgSellPrice = GetCycleAveragePrice(OP_SELL);
      double targetTpPrice;
      if(Use_Adaptive_Recovery && inRecoveryMode)
         targetTpPrice = CalculateRecoveryTakeProfit(OP_SELL, avgSellPrice);
      else if(Adjust_TP_For_MaxLot && HasMaxLotSizeTrade(OP_SELL))
      {
         double riskRewardRatio = CalculateRiskRewardRatio(OP_SELL);
         double adjustedTP = Average_TP_In_Pips / riskRewardRatio;
         targetTpPrice = avgSellPrice - (adjustedTP * point);
         Print("Adjusted TP for SELL cycle (max lot reached): ", adjustedTP, " pips, target price: ", targetTpPrice);
      }
      else
         targetTpPrice = avgSellPrice - (Average_TP_In_Pips * point);
      
      if(Ask <= targetTpPrice)
      {
         CloseAllCycleTrades(OP_SELL);
         if(Use_Adaptive_Recovery && inRecoveryMode)
            ResetRecoveryState();
      }
   }
}

//+------------------------------------------------------------------+
//| Check for new bar                                                |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBar = 0;
   datetime currentBar = iTime(Symbol(), 0, 0);
   
   if(lastBar != currentBar)
   {
      lastBar = currentBar;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate Z-Score                                                |
//+------------------------------------------------------------------+
double CalculateZScore(int period)
{
   double sma = iMA(Symbol(), 0, period, 0, MODE_SMA, PRICE_CLOSE, 1);
   double stdDev = iStdDev(Symbol(), 0, period, 0, MODE_SMA, PRICE_CLOSE, 1);
   
   if(stdDev == 0) // Avoid division by zero
      return 0;
      
   return (Close[1] - sma) / stdDev;
}

//+------------------------------------------------------------------+
//| Open a new trade                                                 |
//+------------------------------------------------------------------+
bool OpenTrade(int orderType, double lotSize)
{
   double price;
   double sl = 0; // No stop loss as we're using grid strategy
   double tp = 0; // No take profit as we're using average TP
   
   // Normalize lot size
   lotSize = NormalizeDouble(lotSize, 2);
   
   // Check minimum and maximum lot size
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   
   if(lotSize < minLot)
      lotSize = minLot;
   if(lotSize > maxLot)
      lotSize = maxLot;
   
   // Set price based on order type
   if(orderType == OP_BUY)
      price = Ask;
   else
      price = Bid;
      
   // Open the order
   int ticket = OrderSend(Symbol(), orderType, lotSize, price, Slippage, sl, tp, Trade_Comment, MagicNumber, 0, orderType == OP_BUY ? clrBlue : clrRed);
   
   if(ticket > 0)
   {
      Print("Order opened: Type=", orderType, ", Lot=", lotSize, ", Price=", price);
      return true;
   }
   else
   {
      Print("Error opening order: ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Close all trades of a specific type                              |
//+------------------------------------------------------------------+
void CloseAllCycleTrades(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            bool result = false;
            
            if(orderType == OP_BUY)
               result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);
            else
               result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);
               
            if(!result)
               Print("Error closing order #", OrderTicket(), ": ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate volume-weighted average price for a cycle              |
//+------------------------------------------------------------------+
double GetCycleAveragePrice(int orderType)
{
   double totalVolume = 0;
   double volumePrice = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            totalVolume += OrderLots();
            volumePrice += OrderLots() * OrderOpenPrice();
         }
      }
   }
   
   if(totalVolume > 0)
      return volumePrice / totalVolume;
      
   return 0;
}

//+------------------------------------------------------------------+
//| Count open trades of a specific type                             |
//+------------------------------------------------------------------+
int GetOpenTradesCount(int orderType)
{
   int count = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
            count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get the price of the last trade of a specific type               |
//+------------------------------------------------------------------+
double GetLastTradePrice(int orderType)
{
   double lastPrice = 0;
   datetime lastTime = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            if(OrderOpenTime() > lastTime)
            {
               lastTime = OrderOpenTime();
               lastPrice = OrderOpenPrice();
            }
         }
      }
   }
   
   return lastPrice;
}

//+------------------------------------------------------------------+
//| Get the lot size of the last trade of a specific type            |
//+------------------------------------------------------------------+
double GetLastLotSize(int orderType)
{
   double lastLot = 0;
   datetime lastTime = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            if(OrderOpenTime() > lastTime)
            {
               lastTime = OrderOpenTime();
               lastLot = OrderLots();
            }
         }
      }
   }
   
   return lastLot;
}

//+------------------------------------------------------------------+
//| Check if any trade in the cycle has reached max lot size          |
//+------------------------------------------------------------------+
bool HasMaxLotSizeTrade(int orderType)
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            if(MathAbs(OrderLots() - Max_LotSize) < 0.001) // Compare with small tolerance
            {
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate risk-reward ratio based on lot sizes                   |
//+------------------------------------------------------------------+
double CalculateRiskRewardRatio(int orderType)
{
   double totalRisk = 0;
   double maxRisk = 0;
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            totalRisk += OrderLots();
            
            // Find the largest lot size (max risk)
            if(OrderLots() > maxRisk)
               maxRisk = OrderLots();
         }
      }
   }
   
   // If max risk is the same as total risk, or total risk is zero, return 1.0
   if(maxRisk == 0 || totalRisk == 0 || MathAbs(maxRisk - totalRisk) < 0.001)
      return 1.0;
      
   // Calculate risk-reward ratio (higher means more aggressive TP adjustment)
   double ratio = maxRisk / (totalRisk / GetOpenTradesCount(orderType));
   
   // Limit the ratio to a reasonable range (1.0 - 3.0)
   if(ratio < 1.0) ratio = 1.0;
   if(ratio > 3.0) ratio = 3.0;
   
   return ratio;
}

//+------------------------------------------------------------------+
//| Count grid levels for a specific type                             |
//+------------------------------------------------------------------+
int GetGridLevelCount(int orderType)
{
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Close all trades of a specific type and update recovery metrics   |
//+------------------------------------------------------------------+
void CloseSequenceAndUpdateMetrics(int orderType)
{
   double sequenceLotSize = 0.0;
   double sequenceLoss = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == orderType)
         {
            double openPrice = OrderOpenPrice();
            double lots = OrderLots();
            double closePrice = (orderType == OP_BUY) ? Bid : Ask;
            double profit = (orderType == OP_BUY) ? (closePrice - openPrice) * lots / point : (openPrice - closePrice) * lots / point;
            sequenceLotSize += lots;
            sequenceLoss += OrderProfit() + OrderSwap() + OrderCommission();
            bool result = false;
            if(orderType == OP_BUY)
               result = OrderClose(OrderTicket(), lots, Bid, Slippage, clrBlue);
            else
               result = OrderClose(OrderTicket(), lots, Ask, Slippage, clrRed);
            if(!result)
               Print("Error closing order #", OrderTicket(), ": ", GetLastError());
         }
      }
   }
   if(sequenceLotSize > 0)
   {
      cumulativeLotSize = sequenceLotSize;
      totalRealizedLoss += MathAbs(sequenceLoss);
      inRecoveryMode = true;
      currentSequenceCount++;
      Print("[Recovery] Sequence closed. LotSize=", sequenceLotSize, ", Loss=", sequenceLoss, ", CumulativeLot=", cumulativeLotSize, ", TotalLoss=", totalRealizedLoss);
   }
}

//+------------------------------------------------------------------+
//| Calculate recovery lot size                                      |
//+------------------------------------------------------------------+
double CalculateRecoveryLotSize()
{
   if(inRecoveryMode && cumulativeLotSize > 0)
      return cumulativeLotSize;
   return Initial_LotSize;
}

//+------------------------------------------------------------------+
//| Calculate dynamic recovery take profit                           |
//+------------------------------------------------------------------+
double CalculateRecoveryTakeProfit(int orderType, double avgPrice)
{
   // Step 1: Get the lot size for the recovery trade.
   double lotSize = CalculateRecoveryLotSize();
   
   // Step 2: Correctly calculate the monetary value of a single pip for the given lot size.
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE); // Value of one tick for a standard lot.
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE); // Size of one tick.
   if(tickSize == 0) return 0; // Avoid division by zero.
   
   // 'point' is our normalized pip size. Calculate how many ticks are in one of our pips.
   double ticksPerPip = point / tickSize;
   
   // Monetary value of one pip for the current trade's lot size.
   double monetaryValuePerPip = lotSize * tickValue * ticksPerPip;
   if(monetaryValuePerPip == 0) return 0; // Avoid division by zero.

   // Step 3: The desired profit for this sequence is the fixed value from the input parameters.
   double desiredProfitInMoney = Recovery_Profit_Target;

   // Step 4: Calculate the total profit needed to recover all past losses and achieve the desired profit.
   double totalMonetaryTarget = totalRealizedLoss + desiredProfitInMoney;
   
   // Step 5: Calculate how many pips are required to reach this monetary target.
   double pipsToTarget = totalMonetaryTarget / monetaryValuePerPip;
   
   // Step 6: Calculate and return the final Take Profit price based on the required pips.
   if(orderType == OP_BUY)
      return avgPrice + (pipsToTarget * point);
   else
      return avgPrice - (pipsToTarget * point);
}

//+------------------------------------------------------------------+
//| Reset recovery state                                             |
//+------------------------------------------------------------------+
void ResetRecoveryState()
{
   inRecoveryMode = false;
   cumulativeLotSize = 0.0;
   totalRealizedLoss = 0.0;
   currentSequenceCount = 0;
   Print("[Recovery] Recovery complete. Resetting to baseline.");
} 