%% Clear command window & workspace, load data
clear;clc;

run importCRMS0479.m
CRMS0479.dt  = CRMS0479.Datemmddyyyy + timeofday(CRMS0479.Timehhmmss);
CRMS0479 = removevars(CRMS0479, ["Datemmddyyyy","Timehhmmss"]);
WL = table2timetable(CRMS0479);

run loadingFluxData_qc.m
T = readtable('USAtf_NDVI_timeseries.csv');T(end,:) = [];

try
    TT = readtable('USAtf_ERA5_hhtimeseries.csv');
catch 
    TT = readtable('E:\MATLAB\USAtf_ERA5_hhtimeseries.csv');
end
%% Retime the datasets to have same timesteps
str = ["2024-01-01 00:00","2024-12-31 23:30"];
starttime = datetime(str(1),'InputFormat','yyyy-MM-dd HH:mm');
endtime = datetime(str(2),'InputFormat','yyyy-MM-dd HH:mm');

newTimes = starttime:hours(0.5):endtime;
TT2 = table2timetable(qcfluxes32024to21225);
TT2 = retime(TT2,newTimes,'fillwithmissing');

WL(end,:) = [];
WL = retime(WL,newTimes,'linear');

TT = table2timetable(TT);
TT = retime(TT,newTimes,'fillwithmissing');
%% Get comparable variables
TT2.SWC_2_1_1(TT2.SWC_2_1_1>1) = NaN;

A = [TT2.SWC_1_1_1,TT2.SWC_2_1_1,TT2.SWC_3_1_1];
TT2.SWC = mean(A,2,'omitnan');

B = [TT2.TS_1_1_1,TT2.TS_2_1_1,TT2.TS_3_1_1,TT2.TS_4_1_1,TT2.TS_5_1_1,TT2.TS_6_1_1];
TT2.TS = mean(B,2,'omitnan');

% Calculate VPD from Tair and Tdewpoint
esTa = 0.6108 * exp((17.27*TT.x2T)./(TT.x2T+237.3));
esTd = 0.6108 * exp((17.27*TT.x2D)./(TT.x2D+237.3));
TT.VPD = esTa - esTd;

%% Air and soil temperature corrections

% Air
TT2.air_temperature = TT2.air_temperature-273.15;
X = [ones(length(TT.x2T),1) TT.x2T];
ix = find(~isnan(TT2.air_temperature)&~isnan(X(:,2)));
b = X(ix,:)\TT2.air_temperature(ix);
y = X*b;

figure()
hold on
plot(TT.x2T,TT2.air_temperature,'o')
plot(TT.x2T,y)
xlabel('flux tower air temp (deg C)')
ylabel('ERA5 air temp (deg C)')
hold off

for ij = [5262:8162 15640:length(TT2.TS)]
        TT2.TS(ij) = NaN;
end

% Soil
TT2.TS = TT2.TS-273.15;
X = [ones(length(TT.ST),1) TT.ST];
ix = find(~isnan(TT2.TS)&~isnan(X(:,2)));
b = X(ix,:)\TT2.TS(ix);
y = X*b;

figure()
hold on
plot(TT.ST,TT2.TS,'o')
plot(TT.ST,y)
hold off

%% Correlation of ERA5 and flux data
R = corrcoef(TT2.SWIN_1_1_1(~isnan(TT2.SWIN_1_1_1)&~isnan(TT.SSRD)),TT.SSRD(~isnan(TT2.SWIN_1_1_1)&~isnan(TT.SSRD)));
disp(R)

R = corrcoef(TT2.air_temperature(~isnan(TT2.air_temperature)&~isnan(TT.x2T)),TT.x2T(~isnan(TT2.air_temperature)&~isnan(TT.x2T)));
disp(R)

figure()
scatter(TT2.SWIN_1_1_1(~isnan(TT2.SWIN_1_1_1)&~isnan(TT.SSRD)),TT.SSRD(~isnan(TT2.SWIN_1_1_1)&~isnan(TT.SSRD)))
xlabel('flux tower')
ylabel('ERA5')
title('Shortwave Incoming Radiation (W/m2)')
box on

X = TT.SSRD(~isnan(TT2.SWIN_1_1_1)&~isnan(TT.SSRD));
mdl = fitlm(X,TT2.SWIN_1_1_1(~isnan(TT2.SWIN_1_1_1)&~isnan(TT.SSRD)));
disp(mdl.Rsquared.Ordinary)

figure()
scatter(TT2.air_temperature,TT.x2T)
xlabel('flux tower')
ylabel('ERA5')
title('Air temp (deg C)')
box on

X = TT.x2T(~isnan(TT.x2T)&~isnan(TT2.air_temperature));
mdl = fitlm(X,TT2.air_temperature(~isnan(TT.x2T)&~isnan(TT2.air_temperature)));
disp(mdl.Rsquared.Ordinary)


%% Rg Predictions
hrs = hour(TT.times) + (minute(TT.times)./60);
sin_time = sin((2*pi*hrs)./24);
cos_time = cos((2*pi*hrs)./24);

doy_radians = 2*pi*((day(TT.times,'dayofyear'))./365);
sin_year = sin(doy_radians);
cos_year = cos(doy_radians);

X = [sin_time cos_time sin_year cos_year TT.SSRD TT.x2T TT.VPD];

t = any(~isnan(X),2); X = X(t,:);y = TT2.SWIN_1_1_1(t);

mdl = stepwiselm(X(~isnan(y),:),y(~isnan(y)));
disp(mdl.Rsquared.Ordinary)

y_pred = predict(mdl, X);
y_pred(y_pred<0) = 0;

% Plot the actual vs predicted values
figure()
scatter(y,y_pred)
xlabel('Observed')
ylabel('Predicted')
title('Actual vs Predicted SW_{IN} Values');
box on

R = corrcoef(y(~isnan(y)&~isnan(y_pred)),y_pred(~isnan(y)&~isnan(y_pred)));
disp(R)

%% Fill in gaps

for i = 1:height(TT2)
    if isnan(TT2.P_RAIN_1_1_1(i))
        TT2.P_RAIN_1_1_1(i)=TT.TP(i);
    end
    if isnan(TT2.TS(i))
        TT2.TS(i)=TT.ST(i);
    end
    if isnan(TT2.SWC(i))
        TT2.SWC(i)=TT.SWVL1(i);
    end
    if isnan(TT2.u(i))
        TT2.u(i)=TT.ustar(i);
    end
    if isnan(TT2.wind_speed(i))
        TT2.wind_speed(i)=TT.WS(i);
    end
    if isnan(TT2.SWIN_1_1_1(i))
        TT2.SWIN_1_1_1(i)=y_pred(i);
    end
    if isnan(TT2.air_temperature(i))
        TT2.air_temperature(i)=TT.x2T(i);
    end
    if isnan(TT2.VPD(i))
        TT2.VPD(i)=TT.VPD(i);
    end
end

%% Create new table of all variables needed for RF test

Tnew = table;
Tnew.TIMESTAMP_END = TT2.TIMESTAMP_END;

Tnew.Rg= TT2.SWIN_1_1_1;
Tnew.Tair= TT2.air_temperature;
Tnew.VPD= TT2.VPD;
Tnew.WS= TT2.wind_speed;
Tnew.P= TT2.P_RAIN_1_1_1;
Tnew.TS= TT2.TS;
Tnew.SWC= TT2.SWC;
Tnew.NDVI = T.NDVI;
Tnew.FCO2 = TT2.co2_flux;
Tnew.FCH4 = TT2.ch4_flux;
Tnew.VPD = TT2.VPD;
Tnew.WL = WL.AdjustedWaterLevelft;
%% saving
writetable(Tnew,'USAtf_RFinput_timeseries_724.csv')