#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_label1   "Close Difference"
#property indicator_type1    DRAW_LINE
#property indicator_color1   clrBlue

double BufferReturn[];

// Initialize the indicator
int OnInit()
{
    SetIndexBuffer(0, BufferReturn);
    return(INIT_SUCCEEDED);
}

// The main calculation function
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
   // Process the first historical bar [not necessary if the previous candle is not being processed in buffer formula]
   if (prev_calculated<1) BufferReturn[0] = 0;
   
   // Process the rest of historical bars
   for (int i = MathMax(prev_calculated, 1); i < rates_total - 1; i++) {
      // Calculate the difference between current close and last close
      BufferReturn[i] = (close[i] - close[i - 1]) / close[i - 1] * 100.0; // Current close - Last close
   }
   
   // Update the buffer for the current live bar
   if (rates_total > 0) {
      BufferReturn[rates_total - 1] = (close[rates_total - 1] - close[rates_total - 2]) / close[rates_total - 2] * 100.0; // Update live bar difference
   }
   
   return(rates_total);
}
