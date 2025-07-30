%% Clear command window & workspace, load data
clear;clc;

run loading_RF_prefilled_data.m
run loadingFluxData_qc.m
str = ["2024-01-01 00:00","2024-12-31 23:30"];
starttime = datetime(str(1),'InputFormat','yyyy-MM-dd HH:mm');
endtime = datetime(str(2),'InputFormat','yyyy-MM-dd HH:mm');

newTimes = starttime:hours(0.5):endtime;
TT2 = table2timetable(qcfluxes32024to21225);
TT2 = retime(TT2,newTimes,'fillwithmissing');
TT2(end,:) = [];
%% Calculate moving average (trend term) and fluctuation term
T = movmean(RFFCO2.FCO2,48);% daily ave (trend term)
P = RFFCO2.FCO2 - T;% fluctuation term
%% Plotting
t = tiledlayout(1,3);

% Tile 1
nexttile([1 2])
hold on
plot(RFFCO2USAtf.TIMESTAMP_END,RFFCO2USAtf.FCO2,'-','Color',[0.8000 0.8000 0.8000],'LineWidth',2)
plot(RFFCO2USAtf.TIMESTAMP_END,T,'-','Color',[0.0353 0.6196 0.0353],'LineWidth',2)
hold off
box on

legend('pre-filled','MA')
ylabel('NEE (\mumol m^{2}s^{-1})','FontSize',14)
set(gca,'fontsize',14)

% Compute the probability density function
mu = 0;
sigma = 1;
pd = makedist('Normal','mu',mu,'sigma',sigma);

B = sort(T);
y = pdf(pd,B);

edges = -12:0.5:15;

% Last tile
nexttile
hold on
plot(B,y,'-k','LineWidth',2)
h1 = histogram(B,edges,'Normalization','pdf','FaceColor',[0.3922 0.8314 0.0745]);
hold off
box on
legend('PDF','Histogram')
ylabel('Frequency Density','FontSize',14)
xlabel('NEE (\mumol m^{2}s^{-1})','FontSize',14)
set(gca,'fontsize',14)
ax = gca;
ax.YAxisLocation = 'right';
%% Saving
% Save fluctuation term (P) for reconstructing the time series
X = readtable('RFinput_timeseries.csv');
X(end,:) = [];
save("NEEfluctuationterm.mat","P")

%% Remove trend term (T) at times when original NEE are not available
T(isnan(X.FCO2))=NaN;

USAtf_XGBoostin = table();
USAtf_XGBoostin.NEE = T;
USAtf_XGBoostin.SW_IN_F = X.Rg;
USAtf_XGBoostin.VPD_F = X.VPD;
USAtf_XGBoostin.TA_F = X.Tair;

X.TIMESTAMP_END.Format = 'yyyyMMddHHmm';
USAtf_XGBoostin.TIMESTAMP_START = X.TIMESTAMP_END-minutes(30);
USAtf_XGBoostin.TIMESTAMP_END = X.TIMESTAMP_END;
USAtf_XGBoostin.TS_F = X.TS;
USAtf_XGBoostin.WL = X.WL;
USAtf_XGBoostin.NDVI = X.NDVI;

USAtf_XGBoostin = movevars(USAtf_XGBoostin,{'TIMESTAMP_START','TIMESTAMP_END'},'Before',1);
writetable(USAtf_XGBoostin,'XGBoostin.csv')
