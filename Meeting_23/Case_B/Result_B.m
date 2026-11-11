%% =========================================================
%  CASE B - TWO CROWDS CROSSING IN A PLUS-SHAPED DOMAIN
%  POST-PROCESSING
%  ---------------------------------------------------------
%  Crowd A : enters at the BOTTOM, exits at the TOP    (moves in +y)
%            passage width  Lx
%  Crowd B : enters at the LEFT,   exits at the RIGHT  (moves in +x)
%            passage width  Ly
%  In this study Lx = Ly (the folders W_10 ... W_40 hold Lx = Ly = 10 ... 40 m)
%
%  Produces (for every width, and every inflow flux)
%   1. Outflow rate Q_A(t), Q_B(t)
%   2. FFT amplitude + power spectrum
%   3. Cross-correlation R_ab between Q_A and Q_B
%   4. Congestion area in the junction square (total density)
%   5. Total population in the junction square
%   6. Spatio-temporal density plots along Xc, Yc and Cc
%   7. AVI animation of the total density (black obstacles, contourf)
%   8. Choking time vs inflow flux for all widths (one plot)
% ==========================================================

clear;
clc;
close all;

set(groot,'defaultAxesFontName','Times New Roman');
set(groot,'defaultTextFontName','Times New Roman');

set(groot,'defaultAxesFontSize',12);
set(groot,'defaultTextFontSize',12);

set(groot,'defaultAxesLineWidth',1);
set(groot,'defaultLineLineWidth',1.5);

% Use LaTeX consistently for all figure text, legends, and tick labels.
set(groot,'defaultTextInterpreter','latex');
set(groot,'defaultLegendInterpreter','latex');
set(groot,'defaultAxesTickLabelInterpreter','latex');

% ---------------------------------------------------------
% LATEX BACKSLASH RULE
%   - Plain strings  '...'               -> SINGLE backslash  (\rho, \,)
%   - Inside sprintf(...) / compose(...) -> DOUBLE backslash  (\\rho, \\,)
% ---------------------------------------------------------

%% ---------------------------------------------------------
% 1. GENERAL PARAMETERS
% ----------------------------------------------------------

% Passage widths (Lx = Ly) and the folders with the solver output
widths      = [10 20 30 40];
folderNames = {'W_10','W_20','W_30','W_40'};

% Inflow flux (same for both crowds), pedestrians/m/s
F_values = 0.5:0.5:5.0;

% Grid (91 physical points + 3 ghost points on each side)
Nx = 91 + 6;      % = 97
Ny = 91 + 6;      % = 97

% Grid spacing, h = Lx/(Nx-6-1) = 90/90 = 1 m
Lx = 90;
h  = Lx/(Nx-6-1);

% Passage indices (same as makePathWidth in the solver)
%            P1  P2
P_values = [44  54;    % Lx = Ly = 10 m
            39  59;    % Lx = Ly = 20 m
            34  64;    % Lx = Ly = 30 m
            29  69];   % Lx = Ly = 40 m

% Density thresholds for the congestion area (total density)
congestionThresholds = [5 8];

% Choking criterion: total density anywhere in the domain exceeds this value
chokingThreshold = 10;

% ----- Spectral / correlation settings -----
analysisStartTime = 0;      % s   Data before this time is ignored in the
                            %     FFT and in the correlation (use e.g. 50
                            %     to skip the initial filling transient)
applyHannWindow   = false;  % true -> Hann window before the FFT
fMaxPlot          = 1.0;    % Hz  Upper frequency limit of the spectrum plots
maxLag            = 100;    % s   Lag range shown in the correlation plots

% ----- Total-density animation (AVI) -----
makeAnimations     = true;  % false -> skip all videos
animationFrameStep = 4;     % use every n-th saved frame (saved dt = 0.25 s,
                            % so 4 -> one video frame per 1 s of simulation)
videoFPS           = 20;    % frames per second of the AVI
densityColorLimit  = 10;    % colour-bar upper limit (rho_max)

% Re-use previously extracted data (much faster on a second run)
useCache     = true;
cacheVersion = 3;

% Colours: one colour per inflow flux (same colour for A and B)
colors = jet(length(F_values));

% Output folders
mainResultsFolder = fullfile(pwd,'Results_B');

if ~exist(mainResultsFolder,'dir')
    mkdir(mainResultsFolder);
end

correlationFolder = fullfile(mainResultsFolder,'Correlation');

if ~exist(correlationFolder,'dir')
    mkdir(correlationFolder);
end

% Storage for the choking time (all widths, all fluxes)
ChokingTimes = NaN(length(widths),length(F_values));

% Storage for the summary table (one row per width and flux)
summaryHeader = { ...
    'Lx_Ly_m','Flux_ped_m_s', ...
    'DominantFreq_A_Hz','DominantFreq_B_Hz', ...
    'DominantPeriod_A_s','DominantPeriod_B_s', ...
    'MeanQ_A_ped_s','MeanQ_B_ped_s', ...
    'MaxQ_A_ped_s','MaxQ_B_ped_s', ...
    'CorrNorm_ZeroLag','CorrNorm_Max','Lag_at_Max_s', ...
    'CorrNorm_Min','Lag_at_Min_s', ...
    'ChokingTime_s'};

summaryData = NaN(length(widths)*length(F_values),length(summaryHeader));
summaryRow  = 0;


%% ---------------------------------------------------------
% 2. LOOP OVER THE FOUR PASSAGE WIDTHS
% ----------------------------------------------------------

for l = 1:length(widths)

    W = widths(l);
    inputFolder = folderNames{l};

    P1 = P_values(l,1);
    P2 = P_values(l,2);

    % Text used in every title:  Lx = Ly = W
    lengthTitle = sprintf('$L_x=L_y=%d\\,\\mathrm{m}$',W);

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('PROCESSING Lx = Ly = %d m\n',W);
    fprintf('============================================\n');

    % -----------------------------------------------------
    % Output folders
    % -----------------------------------------------------

    resultFolder     = fullfile(mainResultsFolder,sprintf('result_%d',l));
    flowFolder       = fullfile(resultFolder,'Outflow_Rate');
    fftFolder        = fullfile(resultFolder,'FFT');
    congestionFolder = fullfile(resultFolder,'Congestion');
    populationFolder = fullfile(resultFolder,'Population');
    spaceTimeFolder  = fullfile(resultFolder,'SpatioTemporal');
    dataFolder       = fullfile(resultFolder,'Data');
    animationFolder  = fullfile(resultFolder,'Animations');

    outputFolders = {resultFolder; flowFolder; fftFolder; ...
                     congestionFolder; populationFolder; ...
                     spaceTimeFolder; dataFolder; animationFolder};

    for k = 1:length(outputFolders)

        if ~exist(outputFolders{k},'dir')
            mkdir(outputFolders{k});
        end

    end

    % -----------------------------------------------------
    % Storage for all inflow fluxes of this width
    % -----------------------------------------------------

    CaseData = cell(length(F_values),1);   % one struct per flux


    %% =====================================================
    % 3. READ / EXTRACT DATA FOR EVERY INFLOW FLUX
    % ======================================================

    for f = 1:length(F_values)

        F = F_values(f);

        fprintf('\nProcessing Lx = Ly = %d m, F = %.2f\n',W,F);

        cacheFile = fullfile(dataFolder, ...
            sprintf('Cache_W_%d_F_%.2f.mat',W,F));

        % Video file of this simulation
        videoFile = fullfile(animationFolder, ...
            sprintf('Total_Density_Lx_Ly_%d_F_%.2f.avi',W,F));

        % The video needs the full density fields, so the data is only
        % taken from the cache when no video has to be made.
        needVideo = makeAnimations && ~isfile(videoFile);

        C = [];

        if useCache && ~needVideo && isfile(cacheFile)

            S = load(cacheFile);

            if isfield(S,'cacheVersion') && S.cacheVersion == cacheVersion && ...
               isequal(S.congestionThresholds,congestionThresholds) && ...
               isequal(S.PP,[P1 P2])

                C = S.C;
                fprintf('  Loaded from cache.\n');

            end

        end

        if isempty(C)

            if needVideo
                videoSettings = struct( ...
                    'file',videoFile, ...
                    'P1',P1,'P2',P2, ...
                    'frameStep',animationFrameStep, ...
                    'fps',videoFPS, ...
                    'colorLimit',densityColorLimit);
            else
                videoSettings = [];
            end

            try

                C = processCase(inputFolder,W,F,Nx,Ny,h,P1,P2, ...
                    congestionThresholds,videoSettings);

            catch ME

                warning('Lx=Ly=%d, F=%.2f skipped:\n%s',W,F,ME.message);
                C = [];

            end

            if ~isempty(C)

                PP = [P1 P2]; %#ok<NASGU>

                save(cacheFile,'C','congestionThresholds','PP', ...
                    'cacheVersion');

            end

        end

        if isempty(C)
            continue;
        end

        CaseData{f} = C;

        % -------------------------------------------------
        % Choking time: first time the total density anywhere in the
        % domain exceeds the choking threshold
        % -------------------------------------------------

        chokeIndex = find(C.maxRho > chokingThreshold,1,'first');

        if ~isempty(chokeIndex)
            ChokingTimes(l,f) = C.t(chokeIndex);
        end

        % -------------------------------------------------
        % Save the time histories of this simulation
        % -------------------------------------------------

        simulationTable = table( ...
            C.t(:), ...
            C.QA(:), ...
            C.QB(:), ...
            C.pop(:), ...
            C.area(1,:)', ...
            C.area(2,:)', ...
            C.maxRho(:), ...
            'VariableNames',{ ...
            'Time_s', ...
            'OutflowRate_A_pedestrians_s', ...
            'OutflowRate_B_pedestrians_s', ...
            'JunctionPopulation_pedestrians', ...
            sprintf('JunctionArea_rho%g_m2',congestionThresholds(1)), ...
            sprintf('JunctionArea_rho%g_m2',congestionThresholds(2)), ...
            'MaxTotalDensity_pedestrians_m2'});

        writetable(simulationTable,fullfile(dataFolder, ...
            sprintf('Results_Lx_Ly_%d_F_%.2f.csv',W,F)));

        fprintf('  Frames: %d | final time: %.3f s\n', ...
            length(C.t),C.t(end));

        if isnan(ChokingTimes(l,f))
            fprintf('  Status: NOT CHOKED\n');
        else
            fprintf('  Status: CHOKED at %.3f s\n',ChokingTimes(l,f));
        end

    end


    %% =====================================================
    % 4. FIGURE 1 - OUTFLOW RATE OF BOTH CROWDS VS TIME
    % ======================================================

    figureFlow = figure('Color','w','Visible','off', ...
        'Position',[100 100 1000 600]);
    hold on;
    grid on;
    box on;

    flowLegend = {};

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        % Crowd A : continuous line
        plot(CaseData{f}.t,CaseData{f}.QA, ...
            'Color',colors(f,:), ...
            'LineStyle','-', ...
            'LineWidth',1.4);

        flowLegend{end+1} = sprintf( ...
            '$\\mathrm{A},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

        % Crowd B : dotted line (same colour)
        plot(CaseData{f}.t,CaseData{f}.QB, ...
            'Color',colors(f,:), ...
            'LineStyle',':', ...
            'LineWidth',2.0);

        flowLegend{end+1} = sprintf( ...
            '$\\mathrm{B},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$Q\,(\mathrm{pedestrians/s})$');

    title(['$\mathrm{OUTFLOW\ RATE\ vs\ TIME}$ - ' lengthTitle], ...
        'Interpreter','latex');

    if ~isempty(flowLegend)
        legend(flowLegend, ...
            'Location','eastoutside', ...
            'FontSize',8, ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figureFlow,fullfile(flowFolder, ...
        sprintf('Outflow_Rate_Lx_Ly_%d.png',W)),'Resolution',300);

    close(figureFlow);


    %% =====================================================
    % 5. FIGURE 2 - TOTAL POPULATION IN THE JUNCTION SQUARE
    % ======================================================

    figurePopulation = figure('Color','w','Visible','off', ...
        'Position',[100 100 1000 600]);
    hold on;
    grid on;
    box on;

    populationLegend = {};

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        plot(CaseData{f}.t,CaseData{f}.pop, ...
            'Color',colors(f,:), ...
            'LineWidth',1.4);

        populationLegend{end+1} = sprintf( ...
            '$F=%.1f$',F_values(f)); %#ok<SAGROW>

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$N_{\mathrm{junction}}\,(\mathrm{pedestrians})$');

    title(['$\mathrm{JUNCTION\ POPULATION\ vs\ TIME}$ - ' lengthTitle], ...
        'Interpreter','latex');

    if ~isempty(populationLegend)
        legend(populationLegend, ...
            'Location','eastoutside', ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figurePopulation,fullfile(populationFolder, ...
        sprintf('Junction_Population_Lx_Ly_%d.png',W)),'Resolution',300);

    close(figurePopulation);


    %% =====================================================
    % 6. FIGURE 3 - FFT AND POWER SPECTRUM (ONE FIGURE PER FLUX)
    % ======================================================

    % Uniform time-step used for resampling (FFT needs uniform sampling)
    uniformData = cell(length(F_values),1);   % {tU, QA_u, QB_u, dtU}

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        t_f = CaseData{f}.t;

        % Time-step of the saved data
        dtU = median(diff(t_f));

        tStart = max(analysisStartTime,t_f(1));
        tU = (tStart:dtU:t_f(end))';

        if numel(tU) < 16
            warning('Lx=Ly=%d, F=%.2f: too few samples after t = %.1f s.', ...
                W,F_values(f),analysisStartTime);
            continue;
        end

        QA_u = interp1(t_f,CaseData{f}.QA,tU,'linear');
        QB_u = interp1(t_f,CaseData{f}.QB,tU,'linear');

        uniformData{f} = {tU,QA_u,QB_u,dtU};

        [fA,ampA,psdA,fDomA] = computeSpectrum(QA_u,dtU,applyHannWindow);
        [fB,ampB,psdB,fDomB] = computeSpectrum(QB_u,dtU,applyHannWindow);

        figureFFT = figure('Color','w','Visible','off', ...
            'Position',[100 100 900 700]);

        % ---- (a) FFT amplitude ----
        subplot(2,1,1);
        hold on;
        grid on;
        box on;

        plot(fA,ampA,'-', ...
            'Color',colors(f,:), ...
            'LineWidth',1.4);

        plot(fB,ampB,':', ...
            'Color',colors(f,:), ...
            'LineWidth',2.0);

        xlim([0 min(fMaxPlot,fA(end))]);

        xlabel('$f\,(\mathrm{Hz})$');
        ylabel('$|\hat{Q}(f)|\,(\mathrm{pedestrians/s})$');

        title('$\mathrm{FFT\ AMPLITUDE\ SPECTRUM}$', ...
            'Interpreter','latex');

        legend({ ...
            sprintf('$Q_A$ ($f_d=%.4f\\,\\mathrm{Hz}$)',fDomA), ...
            sprintf('$Q_B$ ($f_d=%.4f\\,\\mathrm{Hz}$)',fDomB)}, ...
            'Location','northeast', ...
            'Interpreter','latex');

        set(gca,'FontName','Times New Roman','FontSize',11);

        % ---- (b) Power spectrum ----
        subplot(2,1,2);
        hold on;
        grid on;
        box on;

        plot(fA,psdA,'-', ...
            'Color',colors(f,:), ...
            'LineWidth',1.4);

        plot(fB,psdB,':', ...
            'Color',colors(f,:), ...
            'LineWidth',2.0);

        xlim([0 min(fMaxPlot,fA(end))]);

        xlabel('$f\,(\mathrm{Hz})$');
        ylabel('$S_{QQ}(f)\,(\mathrm{pedestrians^2/s})$');

        title('$\mathrm{POWER\ SPECTRUM}$', ...
            'Interpreter','latex');

        legend({'$Q_A$','$Q_B$'}, ...
            'Location','northeast', ...
            'Interpreter','latex');

        set(gca,'FontName','Times New Roman','FontSize',11);

        sgtitle(sprintf([ ...
            '$L_x=L_y=%d\\,\\mathrm{m}$ - ' ...
            '$F=%.1f\\,\\mathrm{pedestrians/m/s}$'], ...
            W,F_values(f)), ...
            'Interpreter','latex');

        exportgraphics(figureFFT,fullfile(fftFolder, ...
            sprintf('FFT_Lx_Ly_%d_F_%.2f.png',W,F_values(f))), ...
            'Resolution',300);

        close(figureFFT);

        % ---- Save the spectra ----
        nMin = min(numel(fA),numel(fB));

        spectrumTable = table( ...
            fA(1:nMin),ampA(1:nMin),psdA(1:nMin), ...
            ampB(1:nMin),psdB(1:nMin), ...
            'VariableNames',{ ...
            'Frequency_Hz', ...
            'Amplitude_A','PowerSpectrum_A', ...
            'Amplitude_B','PowerSpectrum_B'});

        writetable(spectrumTable,fullfile(dataFolder, ...
            sprintf('Spectrum_Lx_Ly_%d_F_%.2f.csv',W,F_values(f))));

    end


    %% =====================================================
    % 7. FIGURE 4 - CROSS-CORRELATION R_ab BETWEEN Q_A AND Q_B
    % ======================================================
    %
    %   R_ab(lag) = integral Q_A(tau) * Q_B(tau - lag) d tau
    %
    %   - Top plot    : exactly the formula above (raw flows)
    %   - Bottom plot : same quantity with the mean removed and
    %                   normalised to [-1,1]. Negative values mean the
    %                   two outflows oscillate in opposite directions
    %                   (anti-phase).
    %
    %   Positive lag : Q_A(tau) resembles Q_B(tau - lag), i.e. B leads A.

    figureCorr = figure('Color','w','Visible','off', ...
        'Position',[100 100 1000 800]);

    axRaw  = subplot(2,1,1); hold on; grid on; box on;
    axNorm = subplot(2,1,2); hold on; grid on; box on;

    corrLegend = {};

    for f = 1:length(F_values)

        if isempty(uniformData{f})
            continue;
        end

        QA_u = uniformData{f}{2};
        QB_u = uniformData{f}{3};
        dtU  = uniformData{f}{4};

        [lags,Rraw,Rnorm] = crossCorrelation(QA_u,QB_u,dtU);

        plot(axRaw,lags,Rraw, ...
            'Color',colors(f,:),'LineWidth',1.4);

        plot(axNorm,lags,Rnorm, ...
            'Color',colors(f,:),'LineWidth',1.4);

        corrLegend{end+1} = sprintf( ...
            '$F=%.1f$',F_values(f)); %#ok<SAGROW>

        % ---- Save the correlation ----
        corrTable = table(lags(:),Rraw(:),Rnorm(:), ...
            'VariableNames',{'Lag_s','R_ab_raw','R_ab_normalised'});

        writetable(corrTable,fullfile(correlationFolder, ...
            sprintf('Correlation_Lx_Ly_%d_F_%.2f.csv',W,F_values(f))));

        % ---- Summary values ----
        mask = abs(lags) <= maxLag;
        zeroIndex = find(abs(lags) < dtU/2,1,'first');

        RnormMasked = Rnorm;
        RnormMasked(~mask) = NaN;

        [corrMax,iMax] = max(RnormMasked);
        [corrMin,iMin] = min(RnormMasked);

        [~,~,~,fDomA] = computeSpectrum(QA_u,dtU,applyHannWindow);
        [~,~,~,fDomB] = computeSpectrum(QB_u,dtU,applyHannWindow);

        summaryRow = summaryRow + 1;

        summaryData(summaryRow,:) = [ ...
            W, F_values(f), ...
            fDomA, fDomB, ...
            1/fDomA, 1/fDomB, ...
            mean(QA_u), mean(QB_u), ...
            max(QA_u), max(QB_u), ...
            Rnorm(zeroIndex), ...
            corrMax, lags(iMax), ...
            corrMin, lags(iMin), ...
            ChokingTimes(l,f)];

    end

    % ---- Format the correlation figure ----
    xlabel(axRaw,'$\mathrm{lag}\,(\mathrm{s})$');
    ylabel(axRaw,'$R_{ab}\,(\mathrm{pedestrians^2/s})$');
    title(axRaw,['$\mathrm{CROSS\ CORRELATION}$ - ' lengthTitle], ...
        'Interpreter','latex');
    xlim(axRaw,[-maxLag maxLag]);

    xlabel(axNorm,'$\mathrm{lag}\,(\mathrm{s})$');
    ylabel(axNorm,'$R_{ab}^{\mathrm{norm}}\,(-)$');
    title(axNorm,['$\mathrm{NORMALISED\ CROSS\ CORRELATION}$ - ' lengthTitle], ...
        'Interpreter','latex');
    xlim(axNorm,[-maxLag maxLag]);
    ylim(axNorm,[-1 1]);

    plot(axNorm,[-maxLag maxLag],[0 0],'k-', ...
        'LineWidth',0.8,'HandleVisibility','off');

    set(axRaw, 'FontName','Times New Roman','FontSize',11);
    set(axNorm,'FontName','Times New Roman','FontSize',11);

    if ~isempty(corrLegend)

        legend(axRaw,corrLegend, ...
            'Location','eastoutside', ...
            'FontSize',8, ...
            'Interpreter','latex');

        legend(axNorm,corrLegend, ...
            'Location','eastoutside', ...
            'FontSize',8, ...
            'Interpreter','latex');

    end

    exportgraphics(figureCorr,fullfile(correlationFolder, ...
        sprintf('Cross_Correlation_Lx_Ly_%d.png',W)),'Resolution',300);

    close(figureCorr);


    %% =====================================================
    % 8. FIGURE 5 - CONGESTION AREA IN THE JUNCTION VS TIME
    % ======================================================

    for c = 1:length(congestionThresholds)

        threshold = congestionThresholds(c);

        figureCongestion = figure('Color','w','Visible','off', ...
            'Position',[100 100 1000 600]);
        hold on;
        grid on;
        box on;

        congestionLegend = {};

        for f = 1:length(F_values)

            if isempty(CaseData{f})
                continue;
            end

            plot(CaseData{f}.t,CaseData{f}.area(c,:), ...
                'Color',colors(f,:), ...
                'LineWidth',1.4);

            congestionLegend{end+1} = sprintf( ...
                '$F=%.1f$',F_values(f)); %#ok<SAGROW>

        end

        xlabel('$t\,(\mathrm{s})$');
        ylabel('$A_{\mathrm{congestion}}\,(\mathrm{m}^2)$');

        thresholdTitle = sprintf( ...
            '$\\rho_{\\mathrm{total}}>%.1f\\,\\mathrm{pedestrians/m^2}$', ...
            threshold);

        title(['$\mathrm{JUNCTION\ CONGESTION\ AREA\ vs\ TIME}$ - ' ...
            thresholdTitle ' - ' lengthTitle], ...
            'Interpreter','latex');

        if ~isempty(congestionLegend)
            legend(congestionLegend, ...
                'Location','eastoutside', ...
                'Interpreter','latex');
        end

        set(gca,'FontName','Times New Roman','FontSize',11);

        exportgraphics(figureCongestion,fullfile(congestionFolder, ...
            sprintf('Congestion_Area_Rho_%.1f_Lx_Ly_%d.png',threshold,W)), ...
            'Resolution',300);

        close(figureCongestion);

    end


    %% =====================================================
    % 9. FIGURE 6 - SPATIO-TEMPORAL DENSITY (Xc, Yc, Cc)
    % ======================================================

    xCoord = (0:Nx-7)*h;                 % 0 ... 90 m  (along Xc)
    yCoord = (0:Ny-7)*h;                 % 0 ... 90 m  (along Yc)
    sCoord = (0:(P2-P1))*sqrt(2)*h;      % along the junction diagonal

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        saveSpatioTemporalFigure( ...
            fullfile(spaceTimeFolder, ...
            sprintf('SpatioTemporal_Lx_Ly_%d_F_%.2f.png',W,F_values(f))), ...
            CaseData{f}.t, ...
            xCoord,CaseData{f}.Xc, ...
            yCoord,CaseData{f}.Yc, ...
            sCoord,CaseData{f}.Cc, ...
            W,F_values(f),densityColorLimit);

    end

    fprintf('\nFinished all analyses for Lx = Ly = %d m\n',W);

end


%% ---------------------------------------------------------
% 10. CHOKING TIME VS INFLOW FLUX (ALL WIDTHS IN ONE PLOT)
% ----------------------------------------------------------

figureChoking = figure('Color','w','Visible','off', ...
    'Position',[100 100 900 600]);
hold on;
grid on;
box on;

widthColors = lines(length(widths));

for l = 1:length(widths)

    plot(F_values,ChokingTimes(l,:), ...
        '-o', ...
        'Color',widthColors(l,:), ...
        'MarkerFaceColor',widthColors(l,:), ...
        'LineWidth',1.6, ...
        'MarkerSize',6);

end

xlabel('$F\,(\mathrm{pedestrians/m/s})$');
ylabel('$t_{\mathrm{choking}}\,(\mathrm{s})$');

title('$\mathrm{CHOKING\ TIME\ vs\ INFLOW\ FLUX}$', ...
    'Interpreter','latex');

legend(compose('$L_x=L_y=%d\\,\\mathrm{m}$',widths), ...
    'Location','best', ...
    'Interpreter','latex');

set(gca,'FontName','Times New Roman','FontSize',11);

exportgraphics(figureChoking,fullfile(mainResultsFolder, ...
    'Choking_Time_Comparison.png'),'Resolution',300);

close(figureChoking);

chokingTable = array2table( ...
    [F_values(:),ChokingTimes'], ...
    'VariableNames',{ ...
    'Flux_ped_m_s', ...
    'Lx_Ly_10m', ...
    'Lx_Ly_20m', ...
    'Lx_Ly_30m', ...
    'Lx_Ly_40m'});

writetable(chokingTable,fullfile(mainResultsFolder, ...
    'Choking_Time_Comparison.csv'));


%% ---------------------------------------------------------
% 11. SAVE SUMMARY TABLE (DOMINANT FREQUENCIES, CORRELATION)
% ----------------------------------------------------------

summaryData = summaryData(1:summaryRow,:);

summaryTable = array2table(summaryData, ...
    'VariableNames',summaryHeader);

writetable(summaryTable,fullfile(mainResultsFolder, ...
    'Summary_Dominant_Frequency_and_Correlation.csv'));


%% ---------------------------------------------------------
% 12. COMPLETION
% ----------------------------------------------------------

fprintf('\n');
fprintf('=================================================\n');
fprintf('ALL POST-PROCESSING COMPLETED SUCCESSFULLY\n');
fprintf('=================================================\n');

fprintf('Results saved in: %s\n',mainResultsFolder);


%% =========================================================
% FUNCTION: PROCESS ONE SIMULATION (ONE WIDTH, ONE FLUX)
% ==========================================================
%
% Files needed:
%   Density_A, Density_B  -> total density, exit densities
%   Y_Velocity_A          -> outflow of crowd A (top exit)
%   X_Velocity_B          -> outflow of crowd B (right exit)
%
% Returns a struct C with the fields
%   t       time                                   (nT x 1)
%   QA, QB  outflow rates                          (nT x 1)
%   pop     population in the junction square      (nT x 1)
%   area    congestion area in the junction square (nThresholds x nT)
%   maxRho  maximum total density in the domain    (nT x 1)
%   Xc      density along the middle row           (91 x nT)
%   Yc      density along the middle column        (91 x nT)
%   Cc      density along the junction diagonal    (W+1 x nT)

function C = processCase(inputFolder,W,F,Nx,Ny,h,P1,P2, ...
    thresholds,videoSettings)

    C = [];

    exitIndices = (P1+1):(P2-1);

    densityAFile = fullfile(inputFolder, ...
        sprintf('Density_A_Contour_L_%.2f_F_%.2f.csv',W,F));

    densityBFile = fullfile(inputFolder, ...
        sprintf('Density_B_Contour_L_%.2f_F_%.2f.csv',W,F));

    yVelocityAFile = fullfile(inputFolder, ...
        sprintf('Y_Velocity_A_Contour_L_%.2f_F_%.2f.csv',W,F));

    xVelocityBFile = fullfile(inputFolder, ...
        sprintf('X_Velocity_B_Contour_L_%.2f_F_%.2f.csv',W,F));

    requiredFiles = {densityAFile,densityBFile, ...
                     yVelocityAFile,xVelocityBFile};

    for k = 1:length(requiredFiles)

        if ~isfile(requiredFiles{k})
            warning('Missing file, case skipped: %s',requiredFiles{k});
            return;
        end

    end

    % NOTE: the readers return V(i,j,frame) with
    %   i = x index (column in the CSV), j = y index (row in the CSV)

    % ---- Density A ----
    [tA,RA] = readCSVFrames(densityAFile,Ny,Nx);
    rhoA_exit = RA(exitIndices,Ny-3,:);          % top exit    (j = Ny-3)

    % ---- Density B ----
    [tB,RB] = readCSVFrames(densityBFile,Ny,Nx);
    rhoB_exit = RB(Nx-3,exitIndices,:);          % right exit  (i = Nx-3)

    nFrames = min(length(tA),length(tB));

    % ---- Total density on the full grid ----
    RT = RA(:,:,1:nFrames) + RB(:,:,1:nFrames);

    clear RA RB;

    % ---- Maximum total density in the domain (interior 4:N-3) ----
    maxRho = reshape(max(max(RT(4:Nx-3,4:Ny-3,:),[],1),[],2),[],1);

    % ---- Junction square: nodes P1 ... P2 in x and y ----
    junctionIdx = P1:P2;
    nJ = numel(junctionIdx);

    % Trapezoidal weights: edge nodes half, corner nodes a quarter,
    % so the weights add up to exactly (W*h)^2
    wJ = ones(nJ,1);
    wJ([1 end]) = 0.5;
    weightJ = (wJ*wJ')*h*h;

    RJ = RT(junctionIdx,junctionIdx,:);

    % Total population in the junction square
    pop = reshape(sum(sum(RJ.*weightJ,1),2),[],1);

    % Congestion area in the junction square
    area = zeros(length(thresholds),nFrames);

    for c = 1:length(thresholds)

        area(c,:) = reshape( ...
            sum(sum((RJ > thresholds(c)).*weightJ,1),2),1,[]);

    end

    clear RJ;

    % ---- Spatio-temporal profiles (total density) ----
    jc = (Ny+1)/2;        % middle row    (y = 45 m)
    ic = (Nx+1)/2;        % middle column (x = 45 m)

    Xc = reshape(RT(4:Nx-3,jc,:),Nx-6,nFrames);
    Yc = reshape(RT(ic,4:Ny-3,:),Ny-6,nFrames);

    diagonalIdx = sub2ind([Nx Ny],junctionIdx,junctionIdx);
    RT2 = reshape(RT,Nx*Ny,nFrames);
    Cc  = RT2(diagonalIdx,:);

    clear RT2;

    % ---- Total-density animation (AVI) ----
    if ~isempty(videoSettings)

        fprintf('  Writing animation: %s\n',videoSettings.file);

        writeDensityVideo(videoSettings,RT,tA(1:nFrames),Nx,Ny,W,F,h);

    end

    clear RT;

    % ---- Velocity of crowd A (top exit) ----
    [tVA,VA] = readCSVFrames(yVelocityAFile,Ny,Nx);
    vA_exit = VA(exitIndices,Ny-3,:);
    clear VA;

    % ---- Velocity of crowd B (right exit) ----
    [tVB,VB] = readCSVFrames(xVelocityBFile,Ny,Nx);
    uB_exit = VB(Nx-3,exitIndices,:);
    clear VB;

    nFinal = min([nFrames,length(tVA),length(tVB)]);

    if any(abs(tA(1:nFinal)-tB(1:nFinal)) > 1e-9) || ...
       any(abs(tA(1:nFinal)-tVA(1:nFinal)) > 1e-9) || ...
       any(abs(tA(1:nFinal)-tVB(1:nFinal)) > 1e-9)

        error('Time values do not match for Lx=Ly=%d, F=%.2f',W,F);

    end

    % ---- Outflow rates  Q = sum(rho*v) * h  (pedestrians/s) ----
    %
    % Summing over the open exit cells and multiplying by h is the
    % trapezoidal rule, because the wall nodes at P1 and P2 carry
    % no flux.

    % Crowd A: rhoA_exit is [nExit x 1 x nFrames] -> sum over dimension 1
    QA = reshape(sum(rhoA_exit(:,:,1:nFinal).*vA_exit(:,:,1:nFinal),1), ...
        [],1)*h;

    % Crowd B: rhoB_exit is [1 x nExit x nFrames] -> sum over dimension 2
    QB = reshape(sum(rhoB_exit(:,:,1:nFinal).*uB_exit(:,:,1:nFinal),2), ...
        [],1)*h;

    % ---- Assemble the output (all trimmed to the same length) ----
    C = struct();
    C.t      = tA(1:nFinal);
    C.QA     = QA;
    C.QB     = QB;
    C.pop    = pop(1:nFinal);
    C.area   = area(:,1:nFinal);
    C.maxRho = maxRho(1:nFinal);
    C.Xc     = Xc(:,1:nFinal);
    C.Yc     = Yc(:,1:nFinal);
    C.Cc     = Cc(:,1:nFinal);

end


%% =========================================================
% FUNCTION: SPATIO-TEMPORAL FIGURE (Xc, Yc, Cc)
% ==========================================================
%
% x-axis : time
% y-axis : position along the line
% colour : total density

function saveSpatioTemporalFigure(fileName,t,xC,Xc,yC,Yc,sC,Cc,W,F,colorLimit)

    levels = linspace(0,colorLimit,41);

    cmap = jet(256);

    panels = {Xc,Yc,Cc};
    coords = {xC,yC,sC};

    yLabels = {'$x\,(\mathrm{m})$', ...
               '$y\,(\mathrm{m})$', ...
               '$s\,(\mathrm{m})$'};

    panelTitles = { ...
        '$\mathrm{MIDDLE\ ROW}\ (X_c,\ y=45\,\mathrm{m})$', ...
        '$\mathrm{MIDDLE\ COLUMN}\ (Y_c,\ x=45\,\mathrm{m})$', ...
        '$\mathrm{JUNCTION\ DIAGONAL}\ (C_c)$'};

    figureST = figure('Color','w','Visible','off', ...
        'Position',[100 100 1000 950]);

    for p = 1:3

        ax = subplot(3,1,p);

        Z = min(max(panels{p},0),colorLimit);

        contourf(ax,t,coords{p},Z,levels,'LineColor','none');

        colormap(ax,cmap);

        set(ax, ...
            'CLim',[0 colorLimit], ...
            'Color',cmap(1,:), ...
            'FontName','Times New Roman', ...
            'FontSize',11, ...
            'Layer','top');

        xlim(ax,[t(1) t(end)]);
        ylim(ax,[coords{p}(1) coords{p}(end)]);

        xlabel(ax,'$t\,(\mathrm{s})$');
        ylabel(ax,yLabels{p});
        title(ax,panelTitles{p},'Interpreter','latex');

        cb = colorbar(ax);
        cb.Label.String = '$\rho_{\mathrm{total}}\,(\mathrm{pedestrians/m^2})$';
        cb.Label.Interpreter = 'latex';
        cb.Label.FontSize = 11;
        cb.TickLabelInterpreter = 'latex';

    end

    sgtitle(sprintf([ ...
        '$L_x=L_y=%d\\,\\mathrm{m}$ - ' ...
        '$F=%.1f\\,\\mathrm{pedestrians/m/s}$'], ...
        W,F), ...
        'Interpreter','latex');

    exportgraphics(figureST,fileName,'Resolution',300);

    close(figureST);

end


%% =========================================================
% FUNCTION: WRITE THE TOTAL-DENSITY ANIMATION (AVI)
% ==========================================================
%
% RT(i,j,k) : total density on the full 97 x 97 grid. Only the interior
%             points 4:N-3 (91 x 91 points, 0 ... 90 m) are drawn.

function writeDensityVideo(settings,RT,t,Nx,Ny,W,F,h)

    nX = Nx - 6;
    nY = Ny - 6;

    xCoord = (0:nX-1)*h;
    yCoord = (0:nY-1)*h;

    % Obstacle corners (the four blocks of the plus-shaped domain)
    a = (settings.P1 - 4)*h;     % lower edge of the passage
    b = (settings.P2 - 4)*h;     % upper edge of the passage
    L = (nX - 1)*h;              % domain length (90 m)

    levels = linspace(0,settings.colorLimit,41);
    cmap = jet(256);

    video = VideoWriter(settings.file,'Motion JPEG AVI');
    video.FrameRate = settings.fps;
    video.Quality = 90;

    open(video);

    figureAnimation = figure( ...
        'Visible','off', ...
        'Color','w', ...
        'Position',[100 100 800 700]);

    ax = axes(figureAnimation);
    hold(ax,'on');

    colormap(ax,cmap);

    % Axes background = lowest colour, so empty regions never look white
    set(ax,'CLim',[0 settings.colorLimit],'Color',cmap(1,:));

    axis(ax,'equal');
    xlim(ax,[0 L]);
    ylim(ax,[0 L]);
    xticks(ax,0:15:L);
    yticks(ax,0:15:L);

    xlabel(ax,'$x\,(\mathrm{m})$','Interpreter','latex','FontSize',13);
    ylabel(ax,'$y\,(\mathrm{m})$','Interpreter','latex','FontSize',13);

    set(ax, ...
        'FontName','Times New Roman', ...
        'FontSize',12, ...
        'LineWidth',1.0, ...
        'TickLabelInterpreter','latex', ...
        'Box','on', ...
        'Layer','top');

    cb = colorbar(ax);
    cb.Label.String = '$\rho_{\mathrm{total}}\,(\mathrm{pedestrians/m^2})$';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize = 12;
    cb.TickLabelInterpreter = 'latex';
    cb.FontName = 'Times New Roman';

    hTitle = title(ax,'','Interpreter','latex','FontSize',13);

    hContour   = [];
    hObstacles = [];

    nFrames = size(RT,3);

    for k = 1:settings.frameStep:nFrames

        % Remove the previous frame (the axes, colour bar and labels stay)
        if ~isempty(hContour)
            delete(hContour);
            delete(hObstacles);
        end

        % Interior density, rows = y, columns = x
        Dk = RT(4:Nx-3,4:Ny-3,k)';
        Dk = min(max(Dk,0),settings.colorLimit);

        [~,hContour] = contourf(ax,xCoord,yCoord,Dk,levels, ...
            'LineColor','none');

        % Black obstacle blocks (drawn on top of the contour)
        hObstacles = gobjects(4,1);

        hObstacles(1) = patch(ax,[0 a a 0],[0 0 a a],'k', ...
            'EdgeColor','k');                                  % bottom left
        hObstacles(2) = patch(ax,[b L L b],[0 0 a a],'k', ...
            'EdgeColor','k');                                  % bottom right
        hObstacles(3) = patch(ax,[0 a a 0],[b b L L],'k', ...
            'EdgeColor','k');                                  % top left
        hObstacles(4) = patch(ax,[b L L b],[b b L L],'k', ...
            'EdgeColor','k');                                  % top right

        set(hTitle,'String',sprintf([ ...
            '$\\mathrm{TOTAL\\ DENSITY}$ - $L_x=L_y=%d\\,\\mathrm{m}$ - ' ...
            '$F=%.1f\\,\\mathrm{pedestrians/m/s}$ - ' ...
            '$t=%.2f\\,\\mathrm{s}$'], ...
            W,F,t(k)));

        frame = getframe(figureAnimation);
        writeVideo(video,frame);

    end

    close(video);
    close(figureAnimation);

end


%% =========================================================
% FUNCTION: ONE-SIDED FFT AMPLITUDE AND POWER SPECTRUM
% ==========================================================

function [f,amplitude,psd,fDominant] = computeSpectrum(Q,dt,useHann)

    Q = Q(:);
    N = numel(Q);
    fs = 1/dt;

    % Remove the mean so that f = 0 does not dominate
    y = Q - mean(Q);

    if useHann
        w = 0.5*(1 - cos(2*pi*(0:N-1)'/(N-1)));
    else
        w = ones(N,1);
    end

    Y = fft(y.*w);

    nHalf = floor(N/2) + 1;

    f = (0:nHalf-1)'*fs/N;

    amplitude = abs(Y(1:nHalf))/sum(w);
    psd       = abs(Y(1:nHalf)).^2/(fs*sum(w.^2));

    % One-sided spectrum: double everything except DC (and Nyquist)
    if mod(N,2) == 0
        amplitude(2:end-1) = 2*amplitude(2:end-1);
        psd(2:end-1)       = 2*psd(2:end-1);
    else
        amplitude(2:end) = 2*amplitude(2:end);
        psd(2:end)       = 2*psd(2:end);
    end

    % Dominant frequency = peak of the power spectrum (excluding DC)
    [~,index] = max(psd(2:end));
    fDominant = f(index + 1);

end


%% =========================================================
% FUNCTION: CROSS-CORRELATION R_ab(lag) = int Qa(tau) Qb(tau-lag) dtau
% ==========================================================

function [lags,Rraw,Rnorm] = crossCorrelation(Qa,Qb,dt)

    Qa = Qa(:);
    Qb = Qb(:);

    N = min(numel(Qa),numel(Qb));

    Qa = Qa(1:N);
    Qb = Qb(1:N);

    lags = (-(N-1):(N-1))'*dt;

    % Raw correlation (exactly the integral, discretised)
    Rraw = conv(Qa,flipud(Qb))*dt;

    % Normalised correlation with the mean removed
    a0 = Qa - mean(Qa);
    b0 = Qb - mean(Qb);

    denominator = sqrt(sum(a0.^2)*sum(b0.^2));

    if denominator > eps
        Rnorm = conv(a0,flipud(b0))/denominator;
    else
        Rnorm = NaN(size(lags));
    end

end


%% =========================================================
% FUNCTION: READ CSV FRAMES (FAST)
% ==========================================================
%
% File layout (written by the solver):
%     time
%     Ny rows of Nx comma-separated values
%     time
%     ...
%
% Returns
%     timeValues : nFrames x 1
%     V(i,j,k)   : i = x index (1..Nx), j = y index (1..Ny), k = frame

function [timeValues,V] = readCSVFrames(filename,Ny,Nx)

    text = fileread(filename);
    text(text == ',') = ' ';

    data = sscanf(text,'%f');
    clear text;

    frameLength = 1 + Nx*Ny;

    % A run that stopped in the middle of a write leaves an incomplete frame
    if mod(numel(data),frameLength) ~= 0

        nComplete = floor(numel(data)/frameLength);

        warning('Incomplete last frame ignored in: %s',filename);

        data = data(1:nComplete*frameLength);

    end

    nFrames = numel(data)/frameLength;

    if nFrames < 1

        fileInfo = dir(filename);

        firstLine  = '(empty file)';
        columnsRow = NaN;

        fid = fopen(filename,'r');

        if fid ~= -1

            line1 = fgetl(fid);
            line2 = fgetl(fid);
            fclose(fid);

            if ischar(line1)
                firstLine = line1(1:min(60,end));
            end

            if ischar(line2)
                columnsRow = numel(strfind(line2,',')) + 1;
            end

        end

        error(['No complete frame found in file: %s\n' ...
            '  File size           : %d bytes\n' ...
            '  Numbers parsed      : %d (one frame needs %d = 1 + Nx*Ny)\n' ...
            '  Columns in 1st row  : %g (expected Nx = %d)\n' ...
            '  First line of file  : %s'], ...
            filename,fileInfo.bytes,numel(data),frameLength, ...
            columnsRow,Nx,firstLine);

    end

    data = reshape(data,frameLength,nFrames);

    timeValues = data(1,:)';

    if any(diff(timeValues) <= 0)
        error('Time values are not increasing in file: %s',filename);
    end

    % Each CSV row j holds the values for i = 1..Nx, so the linear order
    % inside a frame is (j-1)*Nx + i  ->  reshape to [Nx, Ny, nFrames]
    V = reshape(data(2:end,:),Nx,Ny,nFrames);

end