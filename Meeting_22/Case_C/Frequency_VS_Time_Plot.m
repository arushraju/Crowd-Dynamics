clear;
clc;
close all;

%% ============================================================
%  WIDTH = 10
%  F = 0.5 to 3.0
%  ============================================================

F_values_W10 = 0.5:0.5:3.0;
t_threshold_W10 = 120; % Time after which flow is fully developed

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

%% Plot W = 10 & Calculate FFT Frequencies

figure;
hold on;
colors = lines(length(F_values_W10));

fprintf('====================================================\n');
fprintf('  Results for Width = 10 (Crowd A, t >= %.1f s)\n', t_threshold_W10);
fprintf('====================================================\n');

freqs_W10 = zeros(length(F_values_W10), 1);

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

    fprintf('F = %.2f | Dominant Frequency: %.4f Hz\n', ...
        F_values_W10(i), dominantFreq);

    freqs_W10(i) = dominantFreq;
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

%% Plot W = 20 & Calculate FFT Frequencies

figure;
hold on;
colors = lines(length(F_values_W20));

fprintf('\n====================================================\n');
fprintf('  Results for Width = 20 (Crowd A, t >= %.1f s)\n', t_threshold_W20);
fprintf('====================================================\n');

freqs_W20 = zeros(length(F_values_W20), 1);

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

    fprintf('F = %.2f | Dominant Frequency: %.4f Hz\n', ...
        F_values_W20(i), dominantFreq);

    freqs_W20(i) = dominantFreq;
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

%% Plot W = 30 & Calculate FFT Frequencies

figure;
hold on;
colors = lines(length(F_values_W30));

fprintf('\n====================================================\n');
fprintf('  Results for Width = 30 (Crowd A, t >= %.1f s)\n', t_threshold_W30);
fprintf('====================================================\n');

freqs_W30 = zeros(length(F_values_W30), 1);

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

    fprintf('F = %.2f | Dominant Frequency: %.4f Hz\n', ...
        F_values_W30(i), dominantFreq);

    freqs_W30(i) = dominantFreq;
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
%  SUMMARY PLOT: Dominant Frequency vs F Parameter Across Widths
%  ============================================================
figure('Position', [100, 100, 700, 500]);
hold on;

plot(F_values_W10, freqs_W10, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 10');
plot(F_values_W20, freqs_W20, '-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 20');
plot(F_values_W30, freqs_W30, '-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 30');

xlabel('F Parameter', 'FontSize', 11);
ylabel('Dominant Frequency (Hz)', 'FontSize', 11);
title('Cross-Flow Oscillation Frequency vs F Parameter', 'FontSize', 12, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 10);
grid on;
box on;
hold off;

% Export the summary plot as a high-resolution image
exportgraphics(gcf, 'Summary_Frequency_vs_F.png', 'Resolution', 300);


%% ============================================================
%  CHOKING DYNAMICS VS. FLUX VALUE PLOT
%  ============================================================

flux_value = 0.5:0.5:5.0;

choking_W10 = [NaN, NaN, NaN, NaN, NaN, NaN, 238.25, 137.00, 119.75, 115.25];
choking_W20 = []; % Add data here when ready, e.g., [...]
choking_W30 = [NaN, NaN, NaN, NaN, NaN, 196.5,  125.75, 115.00, 82.75,  78.75];
choking_W40 = []; % Add data here when ready, e.g., [...]

figure('Position', [100, 100, 800, 500]);
hold on;

% Plot W = 10
if ~isempty(choking_W10)
    plot(flux_value, choking_W10, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 10');
end

% Plot W = 20 (will automatically display once data is added)
if ~isempty(choking_W20)
    plot(flux_value, choking_W20, '-s', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 20');
end

% Plot W = 30
if ~isempty(choking_W30)
    plot(flux_value, choking_W30, '-^', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto', 'DisplayName', 'W = 30');
end

% Plot W = 40 (will automatically display once data is added)
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

% Export high-resolution figure
exportgraphics(gcf, 'Choking_vs_Flux_Summary.png', 'Resolution', 300);
