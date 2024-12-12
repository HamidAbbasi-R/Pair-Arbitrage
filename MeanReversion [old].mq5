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
int input LOOKBACK_PERIOD = 20;  // Lookback period
input double thd = 0.0005;             // Distance from regression threhsold

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
double CLOSES1[], CLOSES2[];           // Array to hold closing prices
double RETURNS1[], RETURNS2[];          // Array to hold return values
datetime lastBarTime;      // To track new bar creation
int digits_pair1, digits_pair2;
CTrade trade;
int handle_ATR1, handle_ATR2;
int handle_RSI1, handle_RSI2;
int handle_SRSI1, handle_SRSI2;
int handle_distance;


// OnInit() - Initialization and Setup
int OnInit(){

   // INDICATORS
   handle_ATR1 = iATR(pair1, timeFrame, ATRperiod);
   handle_ATR2 = iATR(pair2, timeFrame, ATRperiod);
   
   handle_RSI1 = iRSI(pair1, timeFrame, 14, PRICE_CLOSE);
   handle_RSI2 = iRSI(pair2, timeFrame, 14, PRICE_CLOSE);
   
   handle_SRSI1 = iStochastic(pair1, timeFrame, 5, 3, 3, MODE_EMA, STO_CLOSECLOSE);
   handle_SRSI2 = iStochastic(pair2, timeFrame, 5, 3, 3, MODE_EMA, STO_CLOSECLOSE);
   
   handle_distance = iCustom(NULL, timeFrame, "Distance", pair1, pair2, LOOKBACK_PERIOD);
   
   // Resize CLOSES and RETURNS arrays
   ArrayResize(CLOSES1, LOOKBACK_PERIOD);
   ArrayResize(RETURNS1, LOOKBACK_PERIOD - 1);
   
   ArrayResize(CLOSES2, LOOKBACK_PERIOD);
   ArrayResize(RETURNS2, LOOKBACK_PERIOD - 1);
   
   
   // Get the closing prices for the last LOOKBACK_PERIOD bars
   for (int i = 0; i < LOOKBACK_PERIOD; i++){
      CLOSES1[i] = iClose(pair1, timeFrame, i);
      CLOSES2[i] = iClose(pair2, timeFrame, i);
   }
   
   // Calculate the returns
   for (int i = 0; i < LOOKBACK_PERIOD - 1; i++){
      RETURNS1[i] = (CLOSES1[i] - CLOSES1[i + 1]) / CLOSES1[i + 1];
      RETURNS2[i] = (CLOSES2[i] - CLOSES2[i + 1]) / CLOSES2[i + 1];
   }
   
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
      
      // Update RETURNS
      //---UpdateReturns();
      CopyBuffer(handle_ret, 0, 0, LOOKBACK_PERIOD, RETURNS1);
      CopyBuffer(handle_ret, 0, 0, LOOKBACK_PERIOD, RETURNS2);
            
      // Calculate slope and intercept
      double slope, intercept;
      CalculateLinearFit(slope, intercept);
      
      // Calculate the distances of the last RETURNS from the regression line
      double distance = CalculatePerpendicularDistance(RETURNS1[0], RETURNS2[0], slope, intercept);
      
      // Enter positions with the aid of comparing distance to a threshold
      if(distance>thd && IsTimeCond() && PositionsTotal()==0){
         double rsi1[], rsi2[], srsi1[], srsi2[];
         CopyBuffer(handle_RSI1, 0, 0, 1, rsi1);
         CopyBuffer(handle_RSI2, 0, 0, 1, rsi2);
         CopyBuffer(handle_SRSI1, 0, 0, 1, srsi1);
         CopyBuffer(handle_SRSI2, 0, 0, 1, srsi2);
         
         if(rsi1[0] < 30.0){
            //executeBuy(pair1, distance);
         }else if(rsi2[0] > 70.0){
            //executeSell(pair2, distance);
         }else{
            //executeBuy(pair1, distance);
            //executeSell(pair2, distance);
         }
         
      }else if(distance<-thd && IsTimeCond() && PositionsTotal()==0){
         double rsi1[], rsi2[], srsi1[], srsi2[];
         CopyBuffer(handle_RSI1, 0, 0, 1, rsi1);
         CopyBuffer(handle_RSI2, 0, 0, 1, rsi2);
         CopyBuffer(handle_SRSI1, 0, 0, 1, srsi1);
         CopyBuffer(handle_SRSI2, 0, 0, 1, srsi2);
         
         if(rsi1[0] > 70.0){
            //executeSell(pair1, distance);
         }else if(rsi2[0] < 30.0){
            //executeBuy(pair2, distance);
         }else{
            //executeSell(pair1, distance);
            //executeBuy(pair2, distance);
         }
         
      }
   }
}

void UpdateReturns(){
   // Shift CLOSES array to the right, making space for the new close
   for (int i = LOOKBACK_PERIOD - 1; i > 0; i--){
      CLOSES1[i] = CLOSES1[i - 1];
      CLOSES2[i] = CLOSES2[i - 1];
   }
   // Add the closing price of the new bar to the start of CLOSES array
   CLOSES1[0] = iClose(pair1, timeFrame, 0);
   CLOSES2[0] = iClose(pair2, timeFrame, 0);
   
   // Calculate the latest return and shift the RETURNS array
   for (int i = LOOKBACK_PERIOD - 2; i > 0; i--){
      RETURNS1[i] = RETURNS1[i - 1];
      RETURNS2[i] = RETURNS2[i - 1];
   }
   
   double newReturn1 = (CLOSES1[0] - CLOSES1[1]) / CLOSES1[1];
   double newReturn2 = (CLOSES2[0] - CLOSES2[1]) / CLOSES2[1];
   RETURNS1[0] = newReturn1; // Add the latest return to the start of RETURNS array
   RETURNS2[0] = newReturn2; // Add the latest return to the start of RETURNS array
}


void CalculateLinearFit(double &slope, double &intercept){
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   
   // Number of data points (should be the same length for both arrays)
   int N = ArraySize(RETURNS1);
   
   // Loop through both arrays and calculate sums
   for (int i = 0; i < N; i++){
      double x = RETURNS1[i];
      double y = RETURNS2[i];
      
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   
   
   // Calculate slope (m) using the formula
   slope = (N * sumXY - sumX * sumY) / (N * sumX2 - sumX * sumX);
   
   // Calculate intercept (b) using the formula
   intercept = (sumY - slope * sumX) / N;
}



double CalculatePerpendicularDistance(double x, double y, double slope, double intercept)
{
   // Step 1: Calculate the perpendicular slope (m)
   double m = -1 / slope;
   
   // Step 2: Calculate the x-coordinate of the perpendicular intersection (x_per)
   double x_per = (intercept + m * x - y) / (m - slope);
   
   // Step 3: Calculate the y-coordinate of the perpendicular intersection (y_per)
   double y_per = (slope * (intercept + m * x - y) + intercept * (m - slope)) / (m - slope);
   
   // Step 4: Calculate the Euclidean distance
   double distance = MathSqrt(MathPow(x - x_per, 2) + MathPow(y - y_per, 2));
   
   // Step 5: Determine the sign of the distance based on the point's position relative to the regression line
   if (y < slope * x + intercept)
   {
     distance = -distance;
   }
   
   return distance;
}


void executeBuy(string sym, double distance){
   double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
   int dgts = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   
   entry = NormalizeDouble(entry, dgts);
   
   int slPts = calculateRisk(sym, distance);
   double sl = entry - slPts*point;
   sl = NormalizeDouble(sl, dgts);
   
   double tp_points = slPts * rewardToRisk;
   double tp = entry + tp_points*point;
   tp = NormalizeDouble(tp, dgts);
   
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
   
   double tp_points = slPts * rewardToRisk;
   double tp = entry - tp_points*point;
   tp = NormalizeDouble(tp, dgts);
   
   double lots = CalculateLotSize(sym, slPts);
   trade.Sell(lots, sym, entry, sl, tp);
}



double CalculateLotSize(string sym, int slPts){
   // Get the current account balance
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   // risk in deposit units [$] riskpercentage/2 since it's always two opposite trades
   double risk = accountBalance * riskPercentage/2 / 100.0;    
   double tickSize = SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   
   //double moneyPerLotStep = sl_points / tickSize * tickValue * lotStep;
   double moneyPerLotStep = slPts*tickValue;
   double lots = risk / moneyPerLotStep;
   int digits = int(-MathLog10(lotStep));
   lots = NormalizeDouble(lots,digits);

   //double lots = MathFloor(risk / moneyPerLotStep) * lotStep;
   
   // Ensure the lot size is within allowed minimum and maximum values
   // double minLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   // double maxLotSize = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   // Print("min volume= ", minLotSize, "    max volume= ", maxLotSize, "    lot size = ", lots);
   
   // Clamp the lot size within the broker's allowed range
   //lots = MathMax(minLotSize, MathMin(lots, maxLotSize));
   
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
      slPts = int(100000.0* RegressionMultiplier * MathAbs(distance));
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