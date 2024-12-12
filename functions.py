from tqdm import tqdm
# from pomegranate import HiddenMarkovModel, State, NormalDistribution
from datetime import datetime
import matplotlib.pyplot as plt
from hmmlearn.hmm import GaussianHMM, GMMHMM, MultinomialHMM
import pandas as pd
import pandas_ta as ta
from pandas.plotting import register_matplotlib_converters
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import numpy as np
# render plotly in browser
import plotly.io as pio
import MetaTrader5 as mt5
import warnings
register_matplotlib_converters()
pio.renderers.default = 'vscode'
mt5.initialize()
# disable all the warnings
warnings.filterwarnings('ignore')

def GetPriceData(
        symbol, 
        endTime = datetime.now(),
        timeframe = 'M5',
        Nbars = 1000,
        source = 'MT5',
        indicators_dict = {
            'ATR':      False,
            'ADX':      False,
            'RSI':      False,
        },
        MA_period = 20,
        ):
    
    if source=='MT5':
        # move the hour forward by 2 hours 
        endTime = endTime + pd.DateOffset(hours=2)

        # if Nbars is larger than 99999, get the data in chunks
        rates = pd.DataFrame()  # Initialize an empty DataFrame
        while Nbars > 0:
            Nbars_chunk = min(Nbars, 200000)
            Nbars -= Nbars_chunk

            rates_chunk = mt5.copy_rates_from(
                symbol, 
                ConvertTimeFrametoMT5(timeframe), 
                endTime,
                Nbars_chunk,
            )

            # convert to pandas DataFrame
            rates_chunk = pd.DataFrame(rates_chunk)

            # Add the retrieved chunk to the overall list
            rates = pd.concat([rates, rates_chunk], ignore_index=True)

            # Update endTime to the last time of the retrieved data
            endTime = rates_chunk['time'][0]  # Assuming the data is sorted in reverse chronological order
            
            # convert the endTime from int64 to datetime
            endTime = pd.to_datetime(endTime, unit='s')
            
        # convert times to UTC+1
        rates['time']=pd.to_datetime(rates['time'], unit='s')
        rates['time'] = rates['time'] + pd.DateOffset(hours=-2)

        rates['hour'] = rates['time'].dt.hour

        # rates['MA_close'] = rates['close'].rolling(MA_period).mean()
        # rates['EMA_close'] = rates['close'].ewm(span=MA_period, adjust=False).mean()

        # remove nans
        rates = rates.dropna()
        rates.rename(columns={'tick_volume': 'volume'}, inplace=True)
        # rates['MA_volume'] = rates['volume'].rolling(MA_period).mean()
        # rates['EMA_volume'] = rates['volume'].ewm(span=MA_period, adjust=False).mean()
        
        # rates['log_volume'] = np.log(rates['volume'])
        # rates['MA_log_volume'] = rates['log_volume'].rolling(MA_period).mean()
        # rates['EMA_log_volume'] = rates['log_volume'].ewm(span=MA_period, adjust=False).mean()
        
        rates['log_return'] = np.log(rates['close'] / rates['close'].shift(1))
        # rates['MA_log_return'] = rates['log_return'].rolling(MA_period).mean()       
        # rates['EMA_log_return'] = rates['log_return'].ewm(span=MA_period, adjust=False).mean()
        
        # rates['volatility'] = rates['log_return'].rolling(MA_period).std()
        # rates['MA_volatility'] = rates['volatility'].rolling(MA_period).std()   
        # rates['EMA_volatility'] = rates['volatility'].ewm(span=MA_period, adjust=False).std()
        
        # rates['log_volatility'] = np.log(rates['volatility'])
        # rates['MA_log_volatility'] = rates['log_volatility'].rolling(MA_period).mean()
        # rates['EMA_log_volatility'] = rates['log_volatility'].ewm(span=MA_period, adjust=False).mean()
        
        # rates['MA_volume'] = rates['volume'].rolling(MA_period).mean()
        # rates['EMA_volume'] = rates['volume'].ewm(span=MA_period, adjust=False).mean()
        
        # rates['upward'] = (rates['log_return'] > 0).astype(int)
            

        if indicators_dict['ATR']:
            rates['ATR'] = ta.atr(rates['high'], rates['low'], rates['close'], length=MA_period)
            
        if indicators_dict['ADX']:
            ADX = ta.adx(rates['high'], rates['low'], rates['close'], length=MA_period)
            rates['ADX'] = ADX[f'ADX_{MA_period}']

        if indicators_dict['RSI']:
            rates['RSI'] = ta.rsi(rates['close'], length=MA_period)
      
        return rates
    
    elif source=='yfinance':
        startTime = get_start_time(endTime, timeframe, Nbars)
        # convert the symbol to the format required by yfinance
        # AVAILABLE ASSETS
        # 'USDJPY=X' , 'USDCHF=X' , 'USDCAD=X', 
        # 'EURUSD=X' , 'GBPUSD=X' , 'AUDUSD=X' , 'NZDUSD=X', 
        # 'BTC-USD', 'ETH-USD', 'BNB-USD', 
        # 'XRP-USD', 'ADA-USD', 'SOL-USD', 'DOT-USD'
        if symbol[:3] in ['BTC', 'ETH', 'XRP', 'BNB', 'ADA', 'DOGE', 'DOT', 'SOL']:
            symbol = symbol[:3] + '-' + symbol[3:]
        else:
            symbol = symbol + '=X'
            # pass
        # convert timeframe to yfinance format
        timeframe = ConvertTimeFrametoYfinance(timeframe)
        rates = GetPriceData_Yfinance(symbol, startTime, endTime, timeframe)
        # change keys name from Close, Open, High, Low to close, open, high, low
        rates = rates.rename(columns={'Close':'close', 'Open':'open', 'High':'high', 'Low':'low'})
        # change keys name from Date to time
        rates['time'] = rates.index
        return rates

def ConvertTimeFrametoYfinance(timeframe):
    timeframes = {
        'M1': '1m',
        'M5': '5m',
        'M15': '15m',
        'M30': '30m',
        'H1': '1h',
        'H4': '4h',
        'D1': '1d',
        'W1': '1wk',
        'MN1': '1mo'
    }
    return timeframes.get(timeframe, 'Invalid timeframe')

def ConvertTimeFrametoMT5(timeframe):
    timeframes = {
        'M1': mt5.TIMEFRAME_M1,
        'M2': mt5.TIMEFRAME_M2,
        'M3': mt5.TIMEFRAME_M3,
        'M4': mt5.TIMEFRAME_M4,
        'M5': mt5.TIMEFRAME_M5,
        'M6': mt5.TIMEFRAME_M6,
        'M10': mt5.TIMEFRAME_M10,
        'M12': mt5.TIMEFRAME_M12,
        'M15': mt5.TIMEFRAME_M15,
        'M20': mt5.TIMEFRAME_M20,
        'M30': mt5.TIMEFRAME_M30,
        'H1': mt5.TIMEFRAME_H1,
        'H2': mt5.TIMEFRAME_H2,
        'H3': mt5.TIMEFRAME_H3,
        'H4': mt5.TIMEFRAME_H4,
        'H6': mt5.TIMEFRAME_H6,
        'H8': mt5.TIMEFRAME_H8,
        'H12': mt5.TIMEFRAME_H12,
        'D1': mt5.TIMEFRAME_D1,
        'W1': mt5.TIMEFRAME_W1,
        'MN1': mt5.TIMEFRAME_MN1
    }
    return timeframes.get(timeframe, 'Invalid timeframe')

def GetPriceData_Yfinance(
        symbol, 
        start_time, 
        end_time, 
        timeframe,
        ):
    import yfinance as yf
    OHLC = yf.Ticker(symbol).history(
                # [1m, 2m, 5m, 15m, 30m, 60m, 90m, 1h, 1d, 5d, 1wk, 1mo, 3mo]
                interval=timeframe,
                # period=Duration,
                start = start_time,
                end = end_time,
            )
    return OHLC

def get_start_time(
        endTime, 
        timeframe, 
        Nbars,
        ):
    import re
    from datetime import timedelta
    def get_time_per_bar(timeframe):
    # Use regex to capture the numeric part and the unit
        match = re.match(r'([A-Za-z]+)(\d+)', timeframe)
        if not match:
            raise ValueError(f"Invalid timeframe format: {timeframe}")
    
        unit = match.group(1).upper()  # Get the letter part (M, H, D)
        value = int(match.group(2))    # Get the numeric part

        # Convert unit to appropriate timedelta
        if unit == 'M':  # Minutes
            return timedelta(minutes=value)
        elif unit == 'H':  # Hours
            return timedelta(hours=value)
        elif unit == 'D':  # Days
            return timedelta(days=value)
        else:
            raise ValueError(f"Unsupported timeframe unit: {unit}")

    # Get time per bar based on the timeframe
    time_per_bar = get_time_per_bar(timeframe)

    # Calculate total time to subtract
    total_time = time_per_bar * Nbars

    # Calculate the startTime
    startTime = endTime - total_time

    return startTime

def plot_candlesticks(
        symbol1, 
        symbol2=None,
        titles=['Pair1', 'Pair2'],
        show_states=False,
        begin=0,        # from 0 to 1
        fraction=1,     # from 0 to 1
        ):
    
    # if OHL data is not provided, use Scatter plot instead of Candlestick
    if symbol1['open'].isnull().all():
        flagScatter = True
    else:
        flagScatter = False

    # cut the data to a fraction from the "begin" point
    symbol1 = symbol1.iloc[int(begin*len(symbol1)):int(begin*len(symbol1))+int(fraction*len(symbol1))]
    if symbol2 is not None:
        symbol2 = symbol2.iloc[int(begin*len(symbol2)):int(begin*len(symbol2))+int(fraction*len(symbol2))]

    # if pair2 is not None, create a subplot with linked x-axis
    # use plotly
    fig = make_subplots(
        rows=3 if symbol2 is not None else 1, 
        cols=1)
    fig.add_trace(go.Candlestick(
        x    = symbol1['time'],
        open = symbol1['open'],
        high = symbol1['high'],
        low  = symbol1['low'],
        close= symbol1['close'],
        name = titles[0],
        hoverinfo=None,
    ), row=1, col=1)
    if symbol2 is not None:
        fig.add_trace(go.Candlestick(
            x     = symbol2['time'],
            open  = symbol2['open'],
            high  = symbol2['high'],
            low   = symbol2['low'],
            close = symbol2['close'],
            name  = titles[1],
            hoverinfo=None,
        ), row=2, col=1)
        fig.update_layout(
            xaxis2_title='Time',
            yaxis2_title=titles[1],
        )

    fig.update_layout(
        xaxis_title='Time',
        yaxis_title=titles[0],
    )
    fig.update_traces(
        increasing_line_color='rgb(8,153,129)',
        decreasing_line_color='rgb(242,54,69)',
        increasing_fillcolor='rgb(8,153,129)',
        decreasing_fillcolor='rgb(242,54,69)',
    )
    fig.update_xaxes(
        # type='category',
        rangeslider_visible=False,
        matches='x',
        )
    
    # add states to the chart
    if show_states:
        states = np.array(symbol1['hidden_state'])
        # use alternating colors the same size as len(np.unique(states))
        colors = ['blue', 'red', 'green']
        for i in tqdm(range(len(states))):
            if i == 0:
                start = symbol1['time'].iloc[i]
            elif states[i] != states[i-1]:
                end = symbol1['time'].iloc[i]
                fig.add_vrect(
                    x0=start, 
                    x1=end, 
                    fillcolor=colors[states[i]], 
                    opacity=0.2, 
                    layer='below', 
                    line_width=0,
                    )
                start = symbol1['time'].iloc[i]
    
    return fig
