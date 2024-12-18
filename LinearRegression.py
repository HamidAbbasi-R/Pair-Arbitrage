#%% LIBRARIES
# The only thing that needs to be done is that the regression line 
# should be calculated on the closing prices at any given moment.
# meaning that if I'm working with 1000 data points,
# the regression line should be calculated on the closing prices of each of these 1000 data points
# with a given backwardCounts.
# Then implement it in MQL5.

from datetime import datetime
import functions as fns
import numpy as np
import plotly.graph_objects as go
# render plotly in browser
import plotly.io as pio
pio.renderers.default = 'browser'

def find_special_points(
        distances, 
        regressionThreshold, 
        distanceThreshold,
        forwardCounts=5,
        ):
    """
    Find the data points where there is a significant deviation from the regression line. 
    Then find out if the next data point is closer to zero or crosses the zero line or move further away
    from the regression line.

    Find data points that meet the specified conditions:
    1. Data point is outside the threshold range.
    2. The next data point is closer to zero or crosses the zero line.

    Parameters:
        data (np.ndarray): Input signal array.
        threshold (float): Threshold value for detecting out-of-bound points.

    Returns:
        list of tuple: Indices of points and their values that meet the conditions.
    """
    winPoints = []
    lossPoints = []
    winTrades = 0
    lossTrades = 0
    inTrade = [False] * len(distances)

    def compare(next_dist, factor, mode):
        if mode=='TP':
            return next_dist < current_dist * (1-factor) if current_dist > 0 else next_dist > current_dist * (1-factor)
        elif mode=='SL':
            return next_dist > current_dist * (1+factor) if current_dist > 0 else next_dist < current_dist * (1+factor)
    
    for i in range(len(distances) - forwardCounts):
        # Condition 1: Check if the data point is outside the threshold area
        if (distances[i] > regressionThreshold or distances[i] < -regressionThreshold) and not inTrade[i]:
            inTrade[i] = True
            
            # Condition 2: Check if the next data point is closer to zero or crosses the zero line
            current_dist = distances[i]
            next_dists = [distances[i+j] for j in range(1, forwardCounts)]

            # Calculate conditions for Take Profit (TP) and Stop Loss (SL)
            conds_tp = [compare(next_dist, distanceThreshold, 'TP') for next_dist in next_dists]
            conds_sl = [compare(next_dist, distanceThreshold, 'SL') for next_dist in next_dists]

            # find the first True value in condTP and condSL
            i_TP = next((i for i, x in enumerate(conds_tp) if x), None)
            i_SL = next((i for i, x in enumerate(conds_sl) if x), None)


            condTP = False
            condSL = False
            if i_TP is None and i_SL is None:
                continue
            elif i_SL is None:
                condTP = True
            elif i_TP is None:
                condSL = True
            else:
                condTP = True if i_TP < i_SL else False
                condSL = True if i_SL < i_TP else False

            if condTP:
                winPoints.append((i, distances[i], distances[i + 1]))  # (index, current value, next value)
                inTrade[i:i + i_TP + 1] = [True] * (i_TP + 1)

                if distances[i] > 0:
                    # buy the first asset and sell the second asset
                    if data['close_0'].iloc[i+1] > data['close_0'].iloc[i]:
                        winTrades += 1
                    else:
                        lossTrades += 1 
                    if data['close_1'].iloc[i+1] < data['close_1'].iloc[i]:
                        winTrades += 1
                    else:
                        lossTrades += 1
                
                if distances[i] < 0:
                    # sell the first asset and buy the second asset
                    if data['close_0'].iloc[i+1] < data['close_0'].iloc[i]:
                        winTrades += 1
                    else:
                        lossTrades += 1 
                    if data['close_1'].iloc[i+1] > data['close_1'].iloc[i]:
                        winTrades += 1
                    else:
                        lossTrades += 1

            elif condSL:
                lossPoints.append((i, distances[i], distances[i + 1]))
                inTrade[i:i + i_SL + 1] = [True] * (i_SL + 1)

    return winPoints, lossPoints, winTrades, lossTrades

#%% CONSTANTS
symbol = ['EURUSD', 'GBPUSD']
timeframe = "D1"
endTime = datetime(        # in LONDON time
    year = 2024, 
    month = 10, 
    day = 9, 
    hour = 10,
    minute = 0,
    second = 0,
)
Nbars = 1000
LoopbackBars = 20

regressionThreshold = 0.005
distanceThreshold = 0.9

fitReturns = True       # if True, the linear regression is calculated on the closing prices, otherwise on the returns

figRegression = False
showDistancesOnCorrelationPlot = False
figCandles = True

#%% GET PRICE DATA
data0_raw = fns.GetPriceData(symbol[0], endTime, timeframe, Nbars+LoopbackBars)
data1_raw = fns.GetPriceData(symbol[1], endTime, timeframe, Nbars+LoopbackBars)
# only copy the time and log return columns to data0
data0 = data0_raw[['time', 'log_return', 'open', 'high', 'low', 'close']]
data1 = data1_raw[['time', 'log_return', 'open', 'high', 'low', 'close']]

# remove two last columns
# data0 = data0.drop(data0.columns[-3:], axis=1)
data0.columns = [f"{col}_0" for col in data0.columns]

# remove two last columns
# data1 = data1.drop(data1.columns[-3:], axis=1)
data1.columns = [f"{col}_1" for col in data1.columns]

data = data0.join(data1)
# remove the time1 column
data = data.drop('time_1', axis=1)
# rename the time0 column to time
data = data.rename(columns={'time_0': 'time'})
# drop nan values
data = data.dropna()

#%% LINEAR REGRESSION

# calculate the linear regression and the R2 value
line = [np.polyfit(data['log_return_0'][i:i+LoopbackBars], data['log_return_1'][i:i+LoopbackBars], 1) for i in range(1,Nbars)]
# populate the slope and intercept columns of the data

# create data['slope'] and data['intercept'] columns and populate the values
slope = np.array([l[0] for l in line])
intercept = np.array([l[1] for l in line])
r2 = [np.corrcoef(data['log_return_0'][i:i+LoopbackBars], data['log_return_1'][i:i+LoopbackBars])[0, 1] ** 2 for i in range(1,Nbars)]

data['slope'] = np.zeros_like(data['log_return_0'])*np.nan
data['intercept'] = np.zeros_like(data['log_return_0'])*np.nan
data['r2'] = np.zeros_like(data['log_return_0'])*np.nan
data['slope'][LoopbackBars:] = slope
data['intercept'][LoopbackBars:] = intercept
data['r2'][LoopbackBars:] = r2

# drop na values
data = data.dropna()


# calculate the distances of the data points from the regression line
data['distance'] = np.zeros_like(data['log_return_0']) * np.nan
# Calculate the distances of the data points from the regression line without using a loop
x = data['log_return_0']
y = data['log_return_1']
a = data['slope']
b = data['intercept']

distances = -(a * x - y + b) / np.sqrt(a**2 + 1)
# distances = np.where(y > a * x + b, distances, -distances)

data['distance'][LoopbackBars+1:] = distances[LoopbackBars+1:]

# if distance is positive, then the first asset is undervalued (or the second is overvalued), which means:
# Buy the first asset and sell the second asset
# if distance is negative, then the first asset is overvalued (or the second is undervalued), which means: 
# Sell the first asset and buy the second asset

# calculate zero-crossing rate of the distances
zero_crossings = np.sum(np.diff(np.sign(data['distance'][LoopbackBars+1:])) != 0)
zcr = zero_crossings / (sum(~np.isnan(data['distance'])) - 1)  # Normalized by the number of intervals

# print the results
# print(f"slope: {slope:.5f}, intercept: {intercept:.5f}")
# print(f"R2: {r2:.1%}")
print(f"Zero-crossing rate: {zcr:.1%}")

#%% PLOTTING THE RESULTS
# if figRegression:
#     fig = go.Figure()

#     # plot the data points
#     fig.add_trace(go.Scatter
#     (
#         x = data['log_return_0'],
#         y = data['log_return_1'],
#         mode = 'markers',
#         # size of the markers
#         marker = dict(size=3),
#         # line color
#         # line = dict(color='black', width=0.5),
#         # color of the markers change according to their order of appearance
#         marker_color = np.arange(len(data['log_return_0'])),
#         name = 'Data Points',
#     ))

#     # plot the regression line
#     # fig.add_trace(go.Scatter
#     # (
#     #     x = data[0][LoopbackBars:],
#     #     y = np.mean(slope) * data[0][LoopbackBars:] + np.mean(intercept),
#     #     mode = 'lines',
#     #     line = dict(color='black'),
#     #     name = 'Regression Line',
#     # ))

#     # add the equation of the regression line
#     fig.add_annotation(
#         x = 0.05,
#         y = 0.95,
#         xref = 'paper',
#         yref = 'paper',
#         text = f"y = {np.mean(slope):.2f}x + {np.mean(intercept):.2f}, R2 = {np.mean(r2):.1%}",
#         showarrow = False,
#     )

#     # plot the lines connecting the data points perpendicular to the regression line
#     if showDistancesOnCorrelationPlot:
#         i=0
#         for x,y in zip(data[0][LoopbackBars:], data[1][LoopbackBars:]):
#             fig.add_trace(go.Scatter(
#                 x = [x, x_int[i]],
#                 y = [y, y_int[i]],
#                 mode = 'lines',
#                 line = dict(color='black', width=0.5),
#                 showlegend = False,
#             ))
#             i+=1


#     # update the layout
#     fig.update_layout(
#         title = 'Linear Regression',
#         xaxis_title = symbol[0],
#         yaxis_title = symbol[1],
#         # remove hovermode
#         hovermode = False,
#         # xaxis=dict(scaleanchor='y', scaleratio=1)
#     )

#     # fig.show()
#     fig.write_html('regression.html', auto_open=True)

if figCandles:
    distances = np.array(data['distance'][LoopbackBars+1:])
    # if distances outside the threshold area and the next distances is closer to zero than the previous one, then mark the point
    winPoints, lossPoints, winTrades, lossTrades = find_special_points(distances, regressionThreshold, distanceThreshold)
    winPoints = np.array(winPoints)
    lossPoints = np.array(lossPoints)

    indicesWin = winPoints[:, 0].astype(int)
    indicesLoss = lossPoints[:, 0].astype(int) if len(lossPoints) > 0 else []
    
    # define indicesWinPos as a subset of indicesWin where the distance is positive
    indicesWinPos = indicesWin[distances[indicesWin] > 0]
    indicesWinNeg = indicesWin[distances[indicesWin] < 0]
    indicesLossPos = indicesLoss[distances[indicesLoss] > 0] if len(lossPoints) > 0 else []
    indicesLossNeg = indicesLoss[distances[indicesLoss] < 0] if len(lossPoints) > 0 else []

    # plot the candlesticks
    data0.columns = [f"{col[:-2]}" for col in data0.columns]
    data1.columns = [f"{col[:-2]}" for col in data1.columns]
    figCandles = fns.plot_candlesticks(data0[LoopbackBars:],data1[LoopbackBars:], titles=symbol)
    
    # add win and loss points
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:].iloc[indicesWinPos],
        y = data['low_0'][LoopbackBars+1:].iloc[indicesWinPos],
        mode = 'markers',
        # show upward arrows
        marker = dict(size=10, color='green', symbol='triangle-up'),
        name = 'Buy Points',
        showlegend=False,
    ), row=1, col=1)
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:].iloc[indicesWinNeg],
        y = data['high_0'][LoopbackBars+1:].iloc[indicesWinNeg],
        mode = 'markers',
        marker = dict(size=10, color='red', symbol='triangle-down'),
        name = 'Sell Points',
        showlegend=False,
    ), row=1, col=1)
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:].iloc[indicesWinPos],
        y = data['high_1'][LoopbackBars+1:].iloc[indicesWinPos],
        mode = 'markers',
        marker = dict(size=10, color='red', symbol='triangle-down'),
        name = 'Sell Points',
        showlegend=False,
    ), row=2, col=1)
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:].iloc[indicesWinNeg],
        y = data['low_1'][LoopbackBars+1:].iloc[indicesWinNeg],
        mode = 'markers',
        marker = dict(size=10, color='green', symbol='triangle-up'),
        name = 'Buy Points',
        showlegend=False,
    ), row=2, col=1)

    # Distance plot
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:],
        y = distances,
        mode = 'lines',
        name = 'Distances',
        # set the color of the line
        line = dict(color='black', width=1),
    ), row=3, col=1)

    # add zero line
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars:],
        y = np.zeros_like(distances),
        mode = 'lines',
        name = 'Zero Line',
        line = dict(color='red', width=1, dash='dash'),
    ), row=3, col=1)
    
    # highlight the area between y=0.001 and y=-0.001
    figCandles.add_shape(
        type = 'rect',
        x0 = data['time'][LoopbackBars+1:].iloc[0],
        x1 = data['time'][LoopbackBars+1:].iloc[-1],
        y0 = regressionThreshold,
        y1 = -regressionThreshold,
        # color blue
        fillcolor = 'rgba(0, 0, 255, 0.3)',
        line = dict(width=0),
        layer = 'below',
        name = 'Threshold Area',
        row=3, col=1
    )

    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:].iloc[indicesWin],
        y = distances[indicesWin],
        mode = 'markers',
        marker = dict(size=5, color='green'),
        name = 'Arbitrage Points (positive)',
    ), row=3, col=1)
    figCandles.add_trace(go.Scatter(
        x = data['time'][LoopbackBars+1:].iloc[indicesLoss],
        y = distances[indicesLoss],
        mode = 'markers',
        marker = dict(size=5, color='red'),
        name = 'Arbitrage Points (negative)',
    ), row=3, col=1)


    # x axis for the last subplot
    figCandles.update_xaxes(
        rangeslider_visible=False,
        matches='x',
        title_text="Time",
        row=3, col=1
        )
    figCandles.update_yaxes(
        title_text="Distance",
        row=3, col=1
    )
    # figCandles.show()
    figCandles.write_html('candles.html', auto_open=True)
