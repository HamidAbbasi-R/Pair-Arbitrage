#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_label1  "Slope"

// Indicator inputs
input string pair1 = "EURUSD";      // First symbol
input string pair2 = "GBPUSD";      // Second symbol
input int LOOKBACK_PERIOD = 100;  // Lookback period for linear regression

// Buffers for slope and intercept
double SlopeBuffer[], InterceptBuffer[];

// Buffers for storing return values of both symbols
double Returns1[], Returns2[];

// Handles for the custom return indicators
int handle1, handle2;

// Forward declaration of functions
//void CalculateLinearFit(double &slope, double &intercept, double &RETURNS1[], double &RETURNS2[]);

// Indicator initialization
int OnInit()
{
   // Indicator buffers
   SetIndexBuffer(0, SlopeBuffer);
   SetIndexBuffer(1, InterceptBuffer);
   
   // Dynamic arrays to hold returns
   //ArraySetAsSeries(Returns1, true);
   //ArraySetAsSeries(Returns2, true);
   
   // Get the handle for the custom indicator (PercentageReturnIndicator)
   handle1 = iCustom(pair1, PERIOD_CURRENT, "PercentReturn");
   handle2 = iCustom(pair2, PERIOD_CURRENT, "PercentReturn");
   
   return(INIT_SUCCEEDED);
}

// Main calculation function
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
   // Only process live data when a new bar is added
   if (prev_calculated<LOOKBACK_PERIOD){
      SlopeBuffer[prev_calculated] = 0;
      InterceptBuffer[prev_calculated] = 0;
   }
   
   // Process the rest of historical bars
   for (int i = MathMax(prev_calculated, LOOKBACK_PERIOD); i < rates_total - 1; i++) {
      // Copy return data from the custom indicators
      CopyBuffer(handle1, 0, rates_total-i, LOOKBACK_PERIOD, Returns1);
      CopyBuffer(handle2, 0, rates_total-i, LOOKBACK_PERIOD, Returns2);
      
      double slope, intercept;
      CalculateLinearFit(slope, intercept, Returns1, Returns2);
      
      SlopeBuffer[i] = slope;
      InterceptBuffer[i] = intercept;
   }
   
   // Update the buffer for the current live bar
   if (rates_total > 0) {
      // Copy return data from the custom indicators
      CopyBuffer(handle1, 0, 0, LOOKBACK_PERIOD, Returns1);
      CopyBuffer(handle2, 0, 0, LOOKBACK_PERIOD, Returns2);
      
      double slope, intercept;
      CalculateLinearFit(slope, intercept, Returns1, Returns2);

      SlopeBuffer[rates_total - 1] = slope;
      InterceptBuffer[rates_total - 1] = intercept;
   }
   
   return(rates_total);
}

// Function to calculate linear regression fit
void CalculateLinearFit(double &slope, double &intercept, double &RETURNS1[], double &RETURNS2[])
{
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   
   // Loop through both arrays and calculate sums
   for (int i = 0; i < LOOKBACK_PERIOD; i++) {
      double x = RETURNS1[i];
      double y = RETURNS2[i];
      
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
   }
   
   // Calculate slope (m) using the formula
   slope = (LOOKBACK_PERIOD * sumXY - sumX * sumY) / (LOOKBACK_PERIOD * sumX2 - sumX * sumX);
   
   // Calculate intercept (b) using the formula
   intercept = (sumY - slope * sumX) / LOOKBACK_PERIOD;
}