import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import  train_test_split, TimeSeriesSplit, GridSearchCV
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error
import numpy as np
import datetime as dt

df = pd.read_csv(r"D:\MATLAB\RFinput_timeseries.csv")

df['Month'] = pd.to_datetime(df['TIMESTAMP_END'], format='%d-%b-%Y %H:%M:%S').dt.month
df['Month_sin'] = np.sin(2 * np.pi * df['Month'] / 12)
df['Month_cos'] = np.cos(2 * np.pi * df['Month'] / 12)

ddf = df[['TIMESTAMP_END','Rg', 'Tair','WS','P','TS','SWC','NDVI','VPD','WL']]
df = df[['TIMESTAMP_END','Rg', 'Tair','WS','P','TS','SWC','NDVI','VPD','WL','FCO2']]

# drop rows that contain NaN values
df = df.dropna()

X = df[['Rg', 'Tair','WS','P','TS','SWC','VPD','NDVI','WL']]
y = df['FCO2']

X_train, X_test, y_train, y_test = train_test_split(X,y,random_state=17,test_size = 0.6)

tscv = TimeSeriesSplit(n_splits=5)
param_grid = {
    'n_estimators': [100, 200],
    'max_depth': [5, 10],
    'min_samples_split': [2, 5, 10],
    'min_samples_leaf': [1, 3, 5]
}

grid_search = GridSearchCV(
    RandomForestRegressor(random_state=42),
    param_grid,
    cv=tscv,
    scoring='neg_mean_squared_error',
    n_jobs=-1,
    verbose=1
)

grid_search.fit(X_train, y_train)
rf = grid_search.best_estimator_

rows_to_drop = ddf[ddf.isna().any(axis=1)].index
times = ddf.loc[~ddf.index.isin(rows_to_drop),'TIMESTAMP_END']

newX = ddf[['Rg','Tair','WS','P','TS','SWC','VPD','NDVI','WL']]
newX = newX.dropna()

# Predict on the original dataset
y_pred = rf.predict(newX)

# Create the new DataFrame with the columns 'FCO2' and 'TIMESTAMP_END'
new_df = pd.DataFrame({
    'FCO2': y_pred,
    'TIMESTAMP_END': times
})

# save the new DataFrame to a CSV file
new_df.to_csv('RF_FCO2.csv', index=False)


import matplotlib.pyplot as plt

y_train_pred = rf.predict(X_train)
y_test_pred = rf.predict(X_test)

# --- Training Set Metrics ---
train_rmse = np.sqrt(mean_squared_error(y_train, y_train_pred))
train_r2 = r2_score(y_train, y_train_pred)
train_mae = mean_absolute_error(y_train, y_train_pred)

# --- Test Set Metrics ---
test_rmse = np.sqrt(mean_squared_error(y_test, y_test_pred))
test_r2 = r2_score(y_test, y_test_pred)
test_mae = mean_absolute_error(y_test, y_test_pred)

# --- Print Results ---
print("\n🔎 Model Fit Metrics")
print(f"Training RMSE: {train_rmse:.3f}, R²: {train_r2:.3f}, MAE: {train_mae:.3f}")
print(f"Test     RMSE: {test_rmse:.3f}, R²: {test_r2:.3f}, MAE: {test_mae:.3f}")

# Optional: simple overfitting check
rmse_gap = train_rmse - test_rmse
print(f"Overfitting RMSE Gap (Train - Test): {rmse_gap:.3f}")


plt.figure(figsize=(6,6))
plt.scatter(y_test, y_test_pred, alpha=0.5, edgecolors='k')
plt.plot([y_test.min(), y_test.max()], [y_test.min(), y_test.max()], 'r--')
plt.xlabel("Actual FCO2")
plt.ylabel("Predicted FCO2")
plt.title("Test Set: Predicted vs Actual FCO2")
plt.grid(True)
plt.tight_layout()
plt.show()


importances = rf.feature_importances_
features = X.columns
plt.barh(features, importances)
plt.xlabel("Feature Importance")
plt.show()
