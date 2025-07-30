# FluxDecomp

*Use the following scripts, in order, to fill long gaps in flux data with time series decomposition.*

### Before you begin

You will need NDVI from Landsat and other variables from ERA5 Reanalysis data at your site.\
These are available for download online.

### The process
**1.** Run prepping_RF_data in MATLAB. This will output RFinput_timeseries and NEEfluctuationterm.\
**2.** Run RFtesting_Grid_output in Python. This will use the input RFinput_timeseries and output RF_FCO2.\
**3.** Run calculating_trendterm in MATLAB. This will use the input RFinput_timeseries to output XGBoostin.\
**4.** Run XGBoost_gapfill in Python. This will use the input XGBoostin and output gapfilled_xgb.\
**5.** Run XGBoost_postprocessing in MATLAB. This will produce the gap-filled time series.

### Acknowledgements

This process is described in Gao et al (2023): [“Eddy Covariance CO2 Flux Gap Filling for Long Data Gaps: A Novel Framework Based on Machine Learning and Time Series Decomposition"](https://www.mdpi.com/2072-4292/15/10/2695).

