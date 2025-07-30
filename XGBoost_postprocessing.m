%% After using XGBoost, add fluctuation term (P) to filled trend term (T)
clear;clc;close all;

load('USAtf_NEEfluctuationterm_724.mat')
T = readtable("D:\Python_codes\USAtf_gapfilled_xgb_724.csv");
addpath('D:\MATLAB\USAtf_Processing')
run loadingFluxData_qc.m

T.NEE_F = T.gapfilled_NEE + P;

%% Averaging
T = removevars(T, "TIMESTAMP_END");

x = table2timetable(T); %Note that data is a table containing time xby1 datetime and xby1 double
x_daily=retime(x,'daily','mean');

x = timetable2table(x_daily);
%% Plotting
figure()
hold on
plot(qcfluxes32024to21225.TIMESTAMP_END,qcfluxes32024to21225.co2_flux,'-','Color',[0.8000 0.8000 0.8000],'LineWidth',2)
plot(x.TIMESTAMP_START,x.NEE_F,'-r')
% plot(T.TIMESTAMP_START+minutes(30),T.NEE_F,'.r')
hold off
box on
xlim([x.TIMESTAMP_START(1)-days(1) x.TIMESTAMP_START(end)+days(3)])
ylabel('NEE (\mumol m^{2}s^{-1})','FontSize',14)
set(gca,'fontsize',14)
legend('Original','MA-RF (24 hr ave.)')