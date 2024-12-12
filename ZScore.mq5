#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1   "Z-score"
#property indicator_type1    DRAW_LINE
#property indicator_color1   clrBlue


//--- input parameters
input string pair1 = "EURUSD";      // First symbol
input string pair2 = "GBPUSD";      // Second symbol
input int LookbackPeriod = 50; // Lookback period for calculating z-score

//--- indicator buffers
double ZScoreBuffer[];

//--- global variables
double SpreadArray[]; // Array to store spread values

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Indicator buffer setup
   SetIndexBuffer(0, ZScoreBuffer, INDICATOR_DATA);
   
   IndicatorSetString(INDICATOR_SHORTNAME, "Z-Score");
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Resize the spread array to handle all bars
   ArrayResize(SpreadArray, rates_total);
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 1;

   //--- loop through the candles and calculate the z-score for each bar
   for (int i = start; i < rates_total; i++)
   {
      // Get close prices of EUR/USD and GBP/USD for the current candle
      double eurusd_close = iClose(pair1, PERIOD_CURRENT, rates_total-i-1);
      double gbpusd_close = iClose(pair2, PERIOD_CURRENT, rates_total-i-1);

      // Calculate spread between EUR/USD and GBP/USD
      SpreadArray[i] = eurusd_close - gbpusd_close;
      if(i<LookbackPeriod) continue;

      // Calculate mean and standard deviation of spread over lookback period
      double sum = 0;
      for (int j = 0; j < LookbackPeriod; j++)
      {
         sum += SpreadArray[i - j];
      }
      double mean = sum / LookbackPeriod;

      double variance_sum = 0;
      for (int j = 0; j < LookbackPeriod; j++)
      {
         variance_sum += MathPow(SpreadArray[i - j] - mean, 2);
      }
      double stddev = MathSqrt(variance_sum / LookbackPeriod);

      // Calculate z-score
      if (stddev != 0)
         ZScoreBuffer[i] = (SpreadArray[i] - mean) / stddev;
      else
         ZScoreBuffer[i] = 0;

   }

   return(rates_total);
}
