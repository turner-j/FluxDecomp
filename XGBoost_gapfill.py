import pandas as pd 
import numpy as np 
from sklearn.utils import shuffle
import xgboost as xgb
from sklearn.model_selection import GridSearchCV, cross_val_predict
import os
import datetime as dt

def org_data(data, x_cols, y_col):
    """
    Shuffles data, returns X, y and their indices
    """
    data = data[data[y_col].notnull()]
    X = (data[x_cols]).values
    y = (data[y_col]).values
    X, y, id = shuffle(X, y, data.index, random_state = 42)

    return X, y, id


def cv_preds(data, x_cols, y_col, hyperparams, folds):
    """
    Gapfills y_col using x_cols as predictors
    """
    colsample_bytree=hyperparams.get('colsample_bytree')
    max_depth=hyperparams.get('max_depth')
    min_child_weight=hyperparams.get('min_child_weight')
    subsample=hyperparams.get('subsample')

    # Organize training data
    X, y, id = org_data(data, x_cols, y_col)

    # Fit model
    model = xgb.XGBRegressor(objective='reg:squarederror', colsample_bytree=colsample_bytree, max_depth=max_depth, min_child_weight=min_child_weight, subsample=subsample).fit(X, y)

    # CV predict all y where measured data
    y_pred = cross_val_predict(model, X, y, cv=folds)
    data.loc[id, 'modelled_'+y_col] = y_pred

    # Use all available measured data to predict real gaps
    y_pred_gaps = model.predict(np.asarray(data.loc[data[y_col].isnull(), x_cols]))
    gap_ids = data[data[y_col].isnull()].index
    data.loc[gap_ids, 'modelled_'+y_col] = y_pred_gaps

    return data
    
data = pd.read_csv(r"D:\MATLAB\USAtf_XGBoostin.csv", index_col=0)
data.index = pd.to_datetime(data.index, format="%Y%m%d%H%M")

x_cols = ['SW_IN_F','TA_F','WL','VPD_F','NDVI','Month_sin','Month_cos', 'Hour_sin', 'Hour_cos', 'Time']
y_col = 'NEE'
    
data['Month'] = data.index.month
data['Hour'] = data.index.hour+data.index.minute/60
data['Month_sin'] = np.sin((data.Month-1)*(2.*np.pi/12))
data['Month_cos'] = np.cos((data.Month-1)*(2.*np.pi/12))
data['Hour_sin'] = np.sin(data.Hour*(2.*np.pi/24))
data['Hour_cos'] = np.cos(data.Hour*(2.*np.pi/24))
data['Time'] = np.arange(0, len(data), 1)
    
X, y, _ = org_data(data, x_cols, y_col)

xgb_reg = xgb.XGBRegressor(objective='reg:squarederror')

params = {
	"subsample" : [0.5, 0.75, 1],
	"max_depth" :  [3, 5, 10, 15],
	"min_child_weight" : [2, 5, 10],
	"colsample_bytree" : [0.4, 0.6, 0.8, 1],
	"n_estimators" = [100, 250, 500]
}

xgb_grid = GridSearchCV(xgb_reg,
						params,
						cv=5,
						n_jobs=-1,
						verbose=False)

xgb_grid.fit(X, y)
hyperparams = xgb_grid.best_params_

data['complete_NEE'] = data.NEE.copy()            
gapfilled_data = cv_preds(data, x_cols, y_col, hyperparams, 10)
gapfilled_data['gapfilled_NEE'] = gapfilled_data.NEE.copy()
gapfilled_data.loc[gapfilled_data.NEE.isnull(), 'gapfilled_NEE'] = gapfilled_data.modelled_NEE.copy()
gapfilled_data.to_csv('USAtf_gapfilled_xgb_724.csv')

from sklearn.metrics import mean_squared_error, r2_score

print("RMSE:", np.sqrt(mean_squared_error(y, y_pred)))
print("R²:", r2_score(y, y_pred))
