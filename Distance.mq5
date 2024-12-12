#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots 1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_label1  "Distance"

// INPUTS
input string pair1 = "EURUSD";      // First symbol
input string pair2 = "GBPUSD";      // Second symbol
input int LOOKBACK_PERIOD = 20;     //Lookback period (bars)

// Buffer to store the distance values
double DistanceBuffer[], Returns1[], Returns2[], slopeArray[], interceptArray[];
double upper[], lower[];

// Handles for the custom indicators
int handle_return1, handle_return2, handle_regression;


int OnInit() {
   // Set the size of the indicator buffer
   SetIndexBuffer(0, DistanceBuffer);
   
   handle_return1 = iCustom(pair1, PERIOD_CURRENT, "PercentReturn");
   handle_return2 = iCustom(pair2, PERIOD_CURRENT, "PercentReturn");
   handle_regression = iCustom(NULL, PERIOD_CURRENT, "LinearRegression", pair1, pair2, LOOKBACK_PERIOD);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release the indicator handles
   IndicatorRelease(handle_return1);
   IndicatorRelease(handle_return2);
   IndicatorRelease(handle_regression);
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
                const int &spread[]) {
                
   // Process historical bars (only once per initiation of the indicator)
   for (int i = MathMax(prev_calculated, 0); i < rates_total - 1; i++) {
      CopyBuffer(handle_return1, 0, rates_total-i, 1, Returns1);
      CopyBuffer(handle_return2, 0, rates_total-i, 1, Returns2);
      CopyBuffer(handle_regression, 0, rates_total-i, 1, slopeArray);
      CopyBuffer(handle_regression, 1, rates_total-i, 1, interceptArray);
      double distance = CalculatePerpendicularDistance(Returns1[0], Returns2[0], slopeArray[0], interceptArray[0]);
      DistanceBuffer[i] = distance;
   }
   
   // Continuously update the current live bar on each tick
   if (rates_total > 0) {
      CopyBuffer(handle_return1, 0, 0, 1, Returns1);
      CopyBuffer(handle_return2, 0, 0, 1, Returns2);
      CopyBuffer(handle_regression, 0, 0, 1, slopeArray);
      CopyBuffer(handle_regression, 1, 0, 1, interceptArray);
      double distance = CalculatePerpendicularDistance(Returns1[0], Returns2[0], slopeArray[0], interceptArray[0]);
      DistanceBuffer[rates_total - 1] = distance;
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Function to calculate the perpendicular distance to the line     |
//+------------------------------------------------------------------+
double CalculatePerpendicularDistance(double x, double y, double slope, double intercept) {
   // Step 1: Calculate the perpendicular slope (m)
   double m = -1 / slope;
   
   // Step 2: Calculate the x-coordinate of the perpendicular intersection (x_per)
   double x_per = (intercept + m * x - y) / (m - slope);
   
   // Step 3: Calculate the y-coordinate of the perpendicular intersection (y_per)
   double y_per = (slope * (intercept + m * x - y) + intercept * (m - slope)) / (m - slope);
   
   // Step 4: Calculate the Euclidean distance
   double distance = MathSqrt(MathPow(x - x_per, 2) + MathPow(y - y_per, 2));
   
   // Step 5: Determine the sign of the distance based on the point's position relative to the regression line
   if (y < slope * x + intercept) {
      distance = -distance;
   }
   
   return distance;
}
