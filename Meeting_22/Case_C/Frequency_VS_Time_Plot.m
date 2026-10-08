clear;
clc;
close all;

%% ============================================================
%  WIDTH = 10
%  F = 0.5 to 3.0
%  ============================================================
F_values_W10 = 0.5:0.5:3.0;
t_threshold_W10 = 120; % Time after which flow is fully developed
W10 = 10;
V_max = 2;

filesA_W10 = {
    "Outflow_Flux_W_10.00_F_0.50_Crowd_A.csv"
    "Outflow_Flux_W_10.00_F_1.00_Crowd_A.csv"
    "Outflow_Flux_W_10.00_F_1.50_Crowd_A.csv"
    "Outflow_Flux_W_10.00_F_2.00_Crowd_A.csv"
    "Outflow_Flux_W_10.00_F_2.50_Crowd_A.csv"
    "Outflow_Flux_W_10.00_F_3.00_Crowd_A.csv"
};
filesB_W10 = {
    "Outflow_Flux_W_10.00_F_0.50_Crowd_B.csv"
    "Outflow_Flux_W_10.00_F_1.00_Crowd_B.csv"
    "Outflow_Flux_W_10.00_F_1.50_Crowd_B.csv"
    "Outflow_Flux_W_10.00_F_2.00_Crowd_B.csv"
    "Outflow_Flux_W_10.00_F_2.50_Crowd_B.csv"
    "Outflow_Flux_W_10.00_F_3.00_Crowd_B.csv"
};

%% Plot W = 10 & Calculate FFT Frequencies & Strouhal Numbers
figure;
hold on;
colors = lines(length(F_values_W10));
fprintf('====================================================\n');
fprintf('  Results for Width = 10 (Crowd A, t >= %.1f s)\n', t_threshold_W10);
fprintf('====================================================\n');
freqs_W10 = zeros(length(F_values_W10), 1);
st_W10 = zeros(length(F_values_W10), 1);

for i = 1:length(F_values_W10)
    dataA = readmatrix(filesA_W10{i});
    flux = dataA(:,1);
    time = dataA(:,2);
    
    plot(time, flux, ...
        'Color', colors(i,:), ...
        'LineWidth', 1.5, ...
        'LineStyle', '-', ...
        'DisplayName', sprintf('Crowd A, F = %.2f', F_values_W10(i)));
    
    steadyMask = (time >= t_threshold_W10);
    steadyTime = time(steadyMask);
    steadyFlux = flux(steadyMask);
    
    if length(steadyFlux) > 1
        steadyFluxCentered = steadyFlux - mean(steadyFlux);
        N = length(steadyFluxCentered);
        dt = mean(diff(steadyTime));
        Fs = 1 / dt;
        
        Y = fft(steadyFluxCentered);
        P2 = abs(Y / N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2 * P1(2:end-1);
        f = Fs * (0:(N/2)) / N;
        
        [~, maxIdx] = max(P1);
        dominantFreq = f(maxIdx);
    else
        dominantFreq = NaN;
    end
    
    dominantSt = (dominantFreq * W10) / V_max;
    
    fprintf('F = %.2f | Dominant Frequency: %.4f Hz | Strouhal Number: %.4f\n', ...
        F_values_W10(i), dominantFreq, dominantSt);
    freqs_W10(i) = dominantFreq;
    st_W10(i) = dominantSt;
end
xlabel('Time (s)');
ylabel('Outflow Flux');
title('Outflow Flux vs Time, W = 10');
legend('Location', 'best');
grid on;
box on;
hold off;
exportgraphics(gcf, 'Outflow_Flux_W_10.png', 'Resolution', 300);

%% ============================================================
%  WIDTH = 20
%  F = 0.5 to 2.5
%  ============================================================
F_values_W20 = 0.5:0.5:2.5;
t_threshold_W20 = 100;
W20 = 20;

filesA_W20 = {
    "Outflow_Flux_W_20.00_F_0.50_Crowd_A.csv"
    "Outflow_Flux_W_20.00_F_1.00_Crowd_A.csv"
    "Outflow_Flux_W_20.00_F_1.50_Crowd_A.csv"
    "Outflow_Flux_W_20.00_F_2.00_Crowd_A.csv"
    "Outflow_Flux_W_20.00_F_2.50_Crowd_A.csv"
};
filesB_W20 = {
    "Outflow_Flux_W_20.00_F_0.50_Crowd_B.csv"
    "Outflow_Flux_W_20.00_F_1.00_Crowd_B.csv"
    "Outflow_Flux_W_20.00_F_1.50_Crowd_B.csv"
    "Outflow_Flux_W_20.00_F_2.00_Crowd_B.csv"
    "Outflow_Flux_W_20.00_F_2.50_Crowd_B.csv"
};

%% Plot W = 20 & Calculate FFT Frequencies & Strouhal Numbers
figure;
hold on;
colors = lines(length(F_values_W20));
fprintf('\n====================================================\n');
fprintf('  Results for Width = 20 (Crowd A, t >= %.1f s)\n', t_threshold_W20);
fprintf('====================================================\n');
freqs_W20 = zeros(length(F_values_W20), 1);
st_W20 = zeros(length(F_values_W20), 1);

for i = 1:length(F_values_W20)
    dataA = readmatrix(filesA_W20{i});
    flux = dataA(:,1);
    time = dataA(:,2);
    
    plot(time, flux, ...
        'Color', colors(i,:), ...
        'LineWidth', 1.5, ...
        'LineStyle', '-', ...
        'DisplayName', sprintf('Crowd A, F = %.2f', F_values_W20(i)));
    
    steadyMask = (time >= t_threshold_W20);
    steadyTime = time(steadyMask);
    steadyFlux = flux(steadyMask);
    
    if length(steadyFlux) > 1
        steadyFluxCentered = steadyFlux - mean(steadyFlux);
        N = length(steadyFluxCentered);
        dt = mean(diff(steadyTime));
        Fs = 1 / dt;
        
        Y = fft(steadyFluxCentered);
        P2 = abs(Y / N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2 * P1(2:end-1);
        f = Fs * (0:(N/2)) / N;
        
        [~, maxIdx] = max(P1);
        dominantFreq = f(maxIdx);
    else
        dominantFreq = NaN;
    end
    
    dominantSt = (dominantFreq * W20) / V_max;
    
    fprintf('F = %.2f | Dominant Frequency: %.4f Hz | Strouhal Number: %.4f\n', ...
        F_values_W20(i), dominantFreq, dominantSt);
    freqs_W20(i) = dominantFreq;
    st_W20(i) = dominantSt;
end
xlabel('Time (s)');
ylabel('Outflow Flux');
title('Outflow Flux vs Time, W = 20');
legend('Location', 'best');
grid on;
box on;
hold off;
exportgraphics(gcf, 'Outflow_Flux_W_20.png', 'Resolution', 300);

%% ============================================================
%  WIDTH = 30
%  F = 0.5 to 2.5
%  ============================================================
F_values_W30 = 0.5:0.5:2.5;
t_threshold_W30 = 100;
W30 = 30;

filesA_W30 = {
    "Outflow_Flux_W_30.00_F_0.50_Crowd_A.csv"
    "Outflow_Flux_W_30.00_F_1.00_Crowd_A.csv"
    "Outflow_Flux_W_30.00_F_1.50_Crowd_A.csv"
    "Outflow_Flux_W_30.00_F_2.00_Crowd_A.csv"
    "Outflow_Flux_W_30.00_F_2.50_Crowd_A.csv"
};
filesB_W30 = {
    "Outflow_Flux_W_30.00_F_0.50_Crowd_B.csv"
    "Outflow_Flux_W_30.00_F_1.00_Crowd_B.csv"
    "Outflow_Flux_W_30.00_F_1.50_Crowd_B.csv"
    "Outflow_Flux_W_30.00_F_2.00_Crowd_B.csv"
    "Outflow_Flux_W_30.00_F_2.50_Crowd_B.csv"
};

%% Plot W = 30 & Calculate FFT Frequencies & Strouhal Numbers
figure;
hold on;
colors = lines(length(F_values_W30));
fprintf('\n====================================================\n');
fprintf('  Results for Width = 30 (Crowd A, t >= %.1f s)\n', t_threshold_W30);
fprintf('====================================================\n');
freqs_W30 = zeros(length(F_values_W30), 1);
st_W30 = zeros(length(F_values_W30), 1);

for i = 1:length(F_values_W30)
    dataA = readmatrix(filesA_W30{i});
    flux = dataA(:,1);
    time = dataA(:,2);
    
    plot(time, flux, ...
        'Color', colors(i,:), ...
        'LineWidth', 1.5, ...
        'LineStyle', '-', ...
        'DisplayName', sprintf('Crowd A, F = %.2f', F_values_W30(i)));
    
    steadyMask = (time >= t_threshold_W30);
    steadyTime = time(steadyMask);
    steadyFlux = flux(steadyMask);
    
    if length(steadyFlux) > 1
        steadyFluxCentered = steadyFlux - mean(steadyFlux);
        N = length(steadyFluxCentered);
        dt = mean(diff(steadyTime));
        Fs = 1 / dt;
        
        Y = fft(steadyFluxCentered);
        P2 = abs(Y / N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2 * P1(2:end-1);
        f = Fs * (0:(N/2)) / N;
        
        [~, maxIdx] = max(P1);
        dominantFreq = f(maxIdx);
    else
        dominantFreq = NaN;
    end
    
    dominantSt = (dominantFreq * W30) / V_max;
    
    fprintf('F = %.2f | Dominant Frequency: %.4f Hz | Strouhal Number: %.4f\n', ...
        F_values_W30(i), dominantFreq, dominantSt);
    freqs_W30(i) = dominantFreq;
    st_W30(i) = dominantSt;
end
xlabel('Time (s)');
ylabel('Outflow Flux');
title('Outflow Flux vs Time, W = 30');
legend('Location', 'best');
grid on;
box on;
hold off;
exportgraphics(gcf, 'Outflow_Flux_W_30.png', 'Resolution', 300);

%% ============================================================
%  WIDTH = 40
%  F = 0.5 to 2.0
%  ============================================================
F_values_W40 = 0.5:0.5:2.0;
t_threshold_W40 = 100;
W40 = 40;

filesA_W40 = {
    "Outflow_Flux_W_40.00_F_0.50_Crowd_A.csv"
    "Outflow_Flux_W_40.00_F_1.00_Crowd_A.csv"
    "Outflow_Flux_W_40.00_F_1.50_Crowd_A.csv"
    "Outflow_Flux_W_40.00_F_2.00_Crowd_A.csv"
};
filesB_W40 = {
    "Outflow_Flux_W_40.00_F_0.50_Crowd_B.csv"
    "Outflow_Flux_W_40.00_F_1.00_Crowd_B.csv"
    "Outflow_Flux_W_40.00_F_1.50_Crowd_B.csv"
    "Outflow_Flux_W_40.00_F_2.00_Crowd_B.csv"
};

%% Plot W = 40 & Calculate FFT Frequencies & Strouhal Numbers
figure;
hold on;
colors = lines(length(F_values_W40));
fprintf('\n====================================================\n');
fprintf('  Results for Width = 40 (Crowd A, t >= %.1f s)\n', t_threshold_W40);
fprintf('====================================================\n');
freqs_W40 = zeros(length(F_values_W40), 1);
st_W40 = zeros(length(F_values_W40), 1);

for i = 1:length(F_values_W40)
    dataA = readmatrix(filesA_W40{i});
    flux = dataA(:,1);
    time = dataA(:,2);
    
    plot(time, flux, ...
        'Color', colors(i,:), ...
        'LineWidth', 1.5, ...
        'LineStyle', '-', ...
        'DisplayName', sprintf('Crowd A, F = %.2f', F_values_W40(i)));
    
    steadyMask = (time >= t_threshold_W40);
    steadyTime = time(steadyMask);
    steadyFlux = flux(steadyMask);
    
    if length(steadyFlux) > 1
        steadyFluxCentered = steadyFlux - mean(steadyFlux);
        N = length(steadyFluxCentered);
        dt = mean(diff(steadyTime));
        Fs = 1 / dt;
        
        Y = fft(steadyFluxCentered);
        P2 = abs(Y / N);
        P1 = P2(1:floor(N/2)+1);
        P1(2:end-1) = 2 * P1(2:end-1);
        f = Fs * (0:(N/2)) / N;
        
        [~, maxIdx] = max(P1);
        dominantFreq = f(maxIdx);
    else
        dominantFreq = NaN;
    end
    
    dominantSt = (dominantFreq * W40) / V_max;
    
    fprintf('F = %.2f | Dominant Frequency: %.4f Hz | Strouhal Number: %.4f\n', ...
        F_values_W40(i), dominantFreq, dominantSt);
    freqs_W40(i) = dominantFreq;
    st_W40(i) = dominantSt;
end
xlabel('Time (s)');
ylabel('Outflow Flux');
title('Outflow Flux vs Time, W = 40');
legend('Location', 'best');
grid on;
box on;
hold off;
exportgraphics(gcf, 'Outflow_Flux_W_40.png', 'Resolution', 300);

%% ============================================================
%  SUMMARY PLOT: Dominant Frequency vs F Parameter Across Widths
%  ============================================================
figure('Position', [100, 100, 700, 500]);
hold on;
plot(F_values_W10, freqs_W10, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 10');
plot(F_values_W20, freqs_W20, '-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 20');
plot(F_values_W30, freqs_W30, '-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 30');
plot(F_values_W40, freqs_W40, '-d', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 40');
xlabel('F Parameter', 'FontSize', 11);
ylabel('Dominant Frequency (Hz)', 'FontSize', 11);
title('Cross-Flow Oscillation Frequency vs F Parameter', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
box on;
hold off;
exportgraphics(gcf, 'Summary_Frequency_vs_F.png', 'Resolution', 300);

%% ============================================================
%  CHOKING DYNAMICS VS. FLUX VALUE PLOT
%  ============================================================
flux_value = 0.5:0.5:5.0;
choking_W10 = [NaN, NaN, NaN, NaN, NaN, NaN, 238.25, 137.00, 119.75, 115.25];
choking_W20 = [NaN, NaN, NaN, NaN, NaN, 271.75, 122.50, 109.75, 95.75, 91.25]; 
choking_W30 = [NaN, NaN, NaN, NaN, NaN, 196.5,  125.75, 115.00, 82.75,  78.75];
choking_W40 = [NaN, NaN, NaN, NaN, 345.75, 150.50, 123.50, 83.25, 70.75, 69.25]; 
figure('Position', [100, 100, 800, 500]);
hold on;
if ~isempty(choking_W10)
    plot(flux_value, choking_W10, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 10');
end
if ~isempty(choking_W20)
    plot(flux_value, choking_W20, '-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 20');
end
if ~isempty(choking_W30)
    plot(flux_value, choking_W30, '-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 30');
end
if ~isempty(choking_W40)
    plot(flux_value, choking_W40, '-d', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 40');
end
xlabel('Flux Value (F)', 'FontSize', 11);
ylabel('Choking Metric (s)', 'FontSize', 11);
title('Choking Threshold vs. Flux Value across Bottleneck Widths', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
xlim([0 5]);
box on;
hold off;
exportgraphics(gcf, 'Choking_vs_Flux_Summary.png', 'Resolution', 300);