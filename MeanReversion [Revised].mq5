#include <trade/trade.mqh>

// USER INPUTS

input group "General settings"
input ENUM_TIMEFRAMES timeFrame = PERIOD_M5;    // Time frame
input string pair1 = "EURUSD";         // First symbol
input string pair2 = "GBPUSD";         // Second symbol
enum sessionsChoices
   {
   AllSessions,
   AsiaSession,
   LondonSession,
   NewYorkSession,
   AsiaANDLondon,
   LondonANDNewYork,
   NewYorkANDAsia,
   };
input sessionsChoices session = AllSessions;    // Active sessions

input group "Mean diversion settings"
enum MeanRevChoices
  {
   Zscore,
   LinearRegression,
  };
input MeanRevChoices MeanRevChoice = Zscore;     // Mean reversion type
int input LOOKBACK_PERIOD = 100;  // Lookback period
input double thd = 2;             // Threshold distance

input group "Risk Management settings"
enum riskChoices
  {
   Constant,
   ATR,
   Regression,
  };
input riskChoices RiskOption = Constant;     // Risk option
input double riskPercentage = 1.0;              // Risk percentage
input double rewardToRisk = 2.0;                // Reward to Risk ratio
input int SLpointsConstant=100;                 // SL points (applicable to Constant mode)
input double ATRMultipler = 1.5;             // ATR multiple for SL (applicable to ATR mode)
input int ATRperiod = 14;                       // ATR period (applicable to ATR mode)
input double RegressionMultiplier = 1;               // Distance Multiple for SL (applicable to regression mode)


// GLOBAL VARIABLES
datetime lastBarTime;      // To track new bar creation
int digits_pair1, digits_pair2;
CTrade trade;
int handle_ATR1, handle_ATR2;
int handle_RSI1, handle_RSI2;
int handle_SRSI1, handle_SRSI2;
int handle_distance, handle_Zscore;


// OnInit() - Initialization and Setup
int OnInit(){

   // INDICATORS
   handle_ATR1 = iATR(pair1, timeFrame, ATRperiod);
   handle_ATR2 = iATR(pair2, timeFrame, ATRperiod);
   
   //handle_RSI1 = iRSI(pair1, timeFrame, 14, PRICE_CLOSE);
   //handle_RSI2 = iRSI(pair2, timeFrame, 14, PRICE_CLOSE);
   
   //handle_SRSI1 = iStochastic(pair1, timeFrame, 5, 3, 3, MODE_EMA, STO_CLOSECLOSE);
   //handle_SRSI2 = iStochastic(pair2, timeFrame, 5, 3, 3, MODE_EMA, STO_CLOSECLOSE);
   
   handle_distance = iCustom(NULL, timeFrame, "Distance", pair1, pair2, LOOKBACK_PERIOD);
   handle_Zscore = iCustom(NULL, timeFrame, "ZScore", pair1, pair2, LOOKBACK_PERIOD);
   
   // Store the time of the most recent bar
   lastBarTime = iTime(NULL, timeFrame, 0);
   
   return INIT_SUCCEEDED;
}


// OnTick() - Main logic that runs on each tick
void OnTick()
{
   // Check if a new bar has been created
   datetime currentBarTime = iTime(NULL, timeFrame, 0);
   if (currentBarTime > lastBarTime){
      
      // Update lastBarTime to the new bar
      lastBarTime = currentBarTime;
      
      // Calculate the distances of the last RETURNS from the regression line
      double dist[];
      if(MeanRevChoice==Zscore){
         CopyBuffer(handle_Zscore, 0, 1, 1, dist);
      }else if(MeanRevChoice==LinearRegression){
         CopyBuffer(handle_distance, 0, 1, 1, dist);
      }
      
      
      /* Enter positions with the aid of comparing distance to a threshold
      Main assumption here is:
      When distance>thd ---> first asset is underperforming and the second one is overperforming (buy the first, sell the second)
      When distance<thd ---> first asset is overperforming and the second one is underperforming (sell the first, buy the second)
      These assumptions might be wrong
      */
      if(dist[0]>thd && IsTimeCond() && PositionsTotal()==0){
         double rsi1[], rsi2[], srsi1[], srsi2[];
         //CopyBuffer(handle_SRSI1, 0, 0, 1, srsi1);
         //CopyBuffer(handle_SRSI2, 0, 0, 1, srsi2);
         
         executeBuy(pair2, dist[0]);
         executeSell(pair1, dist[0]);
         //if(srsi1[0] < 20.0){
            //executeBuy(pair1, dist[0]);
         //}else if(srsi2[0] > 80.0){
            //executeSell(pair2, dist[0]);
         //}else{
            //executeBuy(pair1, dist[0]);
            //executeSell(pair2, dist[0]);
         //}
         
      }else if(dist[0]<-thd && IsTimeCond() && PositionsTotal()==0){
         double rsi1[], rsi2[], srsi1[], srsi2[];
         //CopyBuffer(handle_SRSI1, 0, 0, 1, srsi1);
         //CopyBuffer(handle_SRSI2, 0, 0, 1, srsi2);
         
         executeBuy(pair1, dist[0]);
         executeSell(pair2, dist[0]);
         //if(srsi1[0] > 80.0){
         //   executeSell(pair1, dist[0]);
         //}else if(srsi2[0] < 20.0){
         //   executeBuy(pair2, dist[0]);
         //}else{
         //   executeSell(pair1, dist[0]);
         //   executeBuy(pair2, dist[0]);
         //}
         
      }
   }
}



void executeBuy(string sym, double distance){
   double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
   int dgts = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   entry = NormalizeDouble(entry, dgts);
   
   int slPts = calculateRisk(sym, distance);
   double sl = entry - slPts*point;
   sl = NormalizeDouble(sl, dgts);
   
   int tp_points = int(slPts * rewardToRisk);
   double tp = entry + tp_points*point;
   tp = NormalizeDouble(tp, dgts);
   Print(sym, "tpPts=",tp_points,",   slPts=",slPts, ",    entry=",entry);
   
   double lots = CalculateLotSize(sym, slPts);
   trade.Buy(lots, sym, entry, sl, tp);
}

void executeSell(string sym, double distance){
   double entry = SymbolInfoDouble(sym, SYMBOL_BID);
   int dgts = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      
   entry = NormalizeDouble(entry, dgts);
   
   int slPts = calculateRisk(sym, distance);
   double sl = entry + slPts*point;
   sl = NormalizeDouble(sl, dgts);
   
   double tp_points = int(slPts * rewardToRisk);
   double tp = entry - tp_points*point;
   tp = NormalizeDouble(tp, dgts);
   Print(sym, "tpPts=",tp_points,",   slPts=",slPts, ",    entry=",entry);
   
   double lots = CalculateLotSize(sym, slPts);
   trade.Sell(lots, sym, entry, sl, tp);
}

double CalculateLotSize(string sym, int slPts){
   // Get the current account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   // risk in deposit units [$] riskpercentage/2 since it's always two opposite trades 
   // not always if you're only entering one positions (needs modification)
   double risk = accountBalance * riskPercentage/2 / 100.0;    
   double tickSize = SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   
   //double moneyPerLotStep = sl_points / tickSize * tickValue * lotStep;
   double moneyPerLotStep = slPts*tickValue;
   double lots = risk / moneyPerLotStep;
   int digits = int(-MathLog10(lotStep));
   lots = NormalizeDouble(lots,digits);
   
   return lots;
}


int calculateRisk(string sym, double distance){
   double points = SymbolInfoDouble(sym, SYMBOL_POINT);
   int slPts;
   if(RiskOption==Constant){
      slPts = SLpointsConstant; 
   }else if(RiskOption==ATR){
      double atr1[], atr2[], atr;
      CopyBuffer(handle_ATR1,0,0,1,atr1);
      CopyBuffer(handle_ATR2,0,0,1,atr2);
      atr = sym==pair1 ? atr1[0] : atr2[0];
      slPts = int(atr * ATRMultipler / points);
   }else{      // if(RiskOption==Regression)
      slPts = int(RegressionMultiplier * MathAbs(distance));
   }
   return slPts;
}


bool IsInSession(int startHour, int endHour){
   // Get the current server time in UTC (TimeCurrent returns server time in seconds)
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   
   // Extract the hour part of the current time (in UTC)
   int currentHour = timeStruct.hour;
   
   // Check if the current hour is within the London session range
   if (currentHour >= startHour && currentHour < endHour)
      return true;  // It's during the London session
   else
      return false; // It's outside the London session
}

bool IsTimeCond(){
   if(session == AllSessions){return true;};

   if(session == AsiaSession    && IsInSession(0,10)){return true;};
   if(session == LondonSession  && IsInSession(10,19)){return true;};
   if(session == NewYorkSession && IsInSession(15,24)){return true;};
   
   if(session == LondonANDNewYork && IsInSession(10,24)){return true;};
   if(session == AsiaANDLondon    && IsInSession(0,19)){return true;};
   if(session == NewYorkANDAsia   && !IsInSession(10,15)){return true;};
 
   return false;
}