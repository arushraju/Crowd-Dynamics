%% =========================================================
%  CASE B - TWO CROWDS CROSSING IN A PLUS-SHAPED DOMAIN
%  POST-PROCESSING
%  ---------------------------------------------------------
%  Crowd A : enters at the BOTTOM, exits at the TOP    (moves in +y)
%  Crowd B : enters at the LEFT,   exits at the RIGHT  (moves in +x)
%
%  Produces
%   1. Outflow rate Q_A(t), Q_B(t)   (one figure per passage width)
%   2. FFT amplitude + power spectrum (one figure per width & flux = 40)
%   3. Cross-correlation R_ab between Q_A and Q_B
%   4. Congestion area (total density) vs time, thresholds 5 and 8
%   5. AVI animation of the total density (one per width and flux)
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

% Passage widths and the folders that contain the solver output
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
dx = h;
dy = h;

% Passage indices (same as makePathWidth in the solver)
%            P1  P2
P_values = [44  54;    % W = 10 m
            39  59;    % W = 20 m
            34  64;    % W = 30 m
            29  69];   % W = 40 m

% Density thresholds for the congestion area (total density)
congestionThresholds = [5 8];

% ----- Spectral / correlation settings -----
analysisStartTime = 0;      % s   Data before this time is ignored in the
                            %     FFT and in the correlation (use e.g. 50
                            %     to skip the initial filling transient)
applyHannWindow   = false;  % true -> Hann window before the FFT
fMaxPlot          = 1.0;    % Hz  Upper frequency limit of the spectrum plots
maxLag            = 100;    % s   Lag range shown in the correlation plots

% Re-use previously extracted data (much faster on a second run)
useCache = true;

% ----- Total-density animation (AVI) -----
makeAnimations     = true;  % false -> skip all videos
animationFrameStep = 4;     % use every n-th saved frame (saved dt = 0.25 s,
                            % so 4 -> one video frame per 1 s of simulation)
videoFPS           = 20;    % frames per second of the AVI
densityColorLimit  = 10;    % colour-bar upper limit (rho_max)

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

% Storage for the summary table (one row per width and flux)
summaryHeader = { ...
    'Width_m','Flux_ped_m_s', ...
    'DominantFreq_A_Hz','DominantFreq_B_Hz', ...
    'DominantPeriod_A_s','DominantPeriod_B_s', ...
    'MeanQ_A_ped_s','MeanQ_B_ped_s', ...
    'MaxQ_A_ped_s','MaxQ_B_ped_s', ...
    'CorrNorm_ZeroLag','CorrNorm_Max','Lag_at_Max_s', ...
    'CorrNorm_Min','Lag_at_Min_s'};

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

    % Exit cells, as used by the solver's outflow boundary condition
    %   Crowd A : top   boundary, row    Ny-3, columns P1+1 ... P2-1
    %   Crowd B : right boundary, column Nx-3, rows    P1+1 ... P2-1
    exitIndices = (P1+1):(P2-1);

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('PROCESSING PASSAGE WIDTH: %d m\n',W);
    fprintf('============================================\n');

    % -----------------------------------------------------
    % Output folders
    % -----------------------------------------------------

    resultFolder     = fullfile(mainResultsFolder,sprintf('result_%d',l));
    flowFolder       = fullfile(resultFolder,'Outflow_Rate');
    fftFolder        = fullfile(resultFolder,'FFT');
    congestionFolder = fullfile(resultFolder,'Congestion');
    dataFolder       = fullfile(resultFolder,'Data');
    animationFolder  = fullfile(resultFolder,'Animations');

    outputFolders = {resultFolder; flowFolder; fftFolder; ...
                     congestionFolder; dataFolder; animationFolder};

    for k = 1:length(outputFolders)

        if ~exist(outputFolders{k},'dir')
            mkdir(outputFolders{k});
        end

    end

    % -----------------------------------------------------
    % Storage for all inflow fluxes of this width
    % -----------------------------------------------------

    Time_values = cell(length(F_values),1);
    Q_A         = cell(length(F_values),1);
    Q_B         = cell(length(F_values),1);

    CongestionArea = cell(length(congestionThresholds),length(F_values));


    %% =====================================================
    % 3. READ / EXTRACT DATA FOR EVERY INFLOW FLUX
    % ======================================================

    for f = 1:length(F_values)

        F = F_values(f);

        fprintf('\nProcessing W = %d m, F = %.2f\n',W,F);

        cacheFile = fullfile(dataFolder, ...
            sprintf('Cache_W_%d_F_%.2f.mat',W,F));

        % Video file of this simulation
        videoFile = fullfile(animationFolder, ...
            sprintf('Total_Density_W_%d_F_%.2f.avi',W,F));

        % The video needs the full density fields, so the data is only
        % taken from the cache when no video has to be made.
        needVideo = makeAnimations && ~isfile(videoFile);

        loadedFromCache = false;

        if useCache && ~needVideo && isfile(cacheFile)

            S = load(cacheFile);

            if isfield(S,'congestionThresholds') && ...
               isequal(S.congestionThresholds,congestionThresholds) && ...
               isequal(S.PP,[P1 P2])

                tCase    = S.tCase;
                QA_case  = S.QA_case;
                QB_case  = S.QB_case;
                areaCase = S.areaCase;

                loadedFromCache = true;
                fprintf('  Loaded from cache.\n');

            end

        end

        if ~loadedFromCache

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

                [tCase,QA_case,QB_case,areaCase] = processCase( ...
                    inputFolder,W,F,Nx,Ny,h,exitIndices, ...
                    congestionThresholds,videoSettings);

            catch ME

                warning('W=%d, F=%.2f skipped:\n%s',W,F,ME.message);

                tCase = [];
                QA_case = [];
                QB_case = [];
                areaCase = [];

            end

            if ~isempty(tCase)

                PP = [P1 P2]; %#ok<NASGU>

                save(cacheFile,'tCase','QA_case','QB_case', ...
                    'areaCase','congestionThresholds','PP');

            end

        end

        if isempty(tCase)
            continue;
        end

        Time_values{f} = tCase;
        Q_A{f}         = QA_case;
        Q_B{f}         = QB_case;

        for c = 1:length(congestionThresholds)
            CongestionArea{c,f} = areaCase(c,:)';
        end

        % -------------------------------------------------
        % Save the time histories of this simulation
        % -------------------------------------------------

        simulationTable = table( ...
            tCase(:), ...
            QA_case(:), ...
            QB_case(:), ...
            areaCase(1,:)', ...
            areaCase(2,:)', ...
            'VariableNames',{ ...
            'Time_s', ...
            'OutflowRate_A_pedestrians_s', ...
            'OutflowRate_B_pedestrians_s', ...
            sprintf('Area_rho%g_m2',congestionThresholds(1)), ...
            sprintf('Area_rho%g_m2',congestionThresholds(2))});

        writetable(simulationTable,fullfile(dataFolder, ...
            sprintf('Results_W_%d_F_%.2f.csv',W,F)));

        fprintf('  Frames: %d | final time: %.3f s\n', ...
            length(tCase),tCase(end));

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

        if isempty(Time_values{f})
            continue;
        end

        % Crowd A : continuous line
        plot(Time_values{f},Q_A{f}, ...
            'Color',colors(f,:), ...
            'LineStyle','-', ...
            'LineWidth',1.4);

        flowLegend{end+1} = sprintf( ...
            '$\\mathrm{A},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

        % Crowd B : dotted line (same colour)
        plot(Time_values{f},Q_B{f}, ...
            'Color',colors(f,:), ...
            'LineStyle',':', ...
            'LineWidth',2.0);

        flowLegend{end+1} = sprintf( ...
            '$\\mathrm{B},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$Q\,(\mathrm{pedestrians/s})$');

    title(sprintf( ...
        '$\\mathrm{OUTFLOW\\ RATE\\ vs\\ TIME}$ - $W=%d\\,\\mathrm{m}$',W), ...
        'Interpreter','latex');

    if ~isempty(flowLegend)
        legend(flowLegend, ...
            'Location','eastoutside', ...
            'FontSize',8, ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figureFlow,fullfile(flowFolder, ...
        sprintf('Outflow_Rate_W_%d.png',W)),'Resolution',300);

    close(figureFlow);


    %% =====================================================
    % 5. FIGURE 2 - FFT AND POWER SPECTRUM (ONE FIGURE PER FLUX)
    % ======================================================

    % Uniform time-step used for resampling (FFT needs uniform sampling)
    uniformData = cell(length(F_values),1);   % {tU, QA_u, QB_u, dtU}

    for f = 1:length(F_values)

        if isempty(Time_values{f})
            continue;
        end

        t_f = Time_values{f};

        % Time-step of the saved data
        dtU = median(diff(t_f));

        tStart = max(analysisStartTime,t_f(1));
        tU = (tStart:dtU:t_f(end))';

        if numel(tU) < 16
            warning('W=%d, F=%.2f: too few samples after t = %.1f s.', ...
                W,F_values(f),analysisStartTime);
            continue;
        end

        QA_u = interp1(t_f,Q_A{f},tU,'linear');
        QB_u = interp1(t_f,Q_B{f},tU,'linear');

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
            '$W=%d\\,\\mathrm{m}$ - ' ...
            '$F=%.1f\\,\\mathrm{pedestrians/m/s}$'], ...
            W,F_values(f)), ...
            'Interpreter','latex');

        exportgraphics(figureFFT,fullfile(fftFolder, ...
            sprintf('FFT_W_%d_F_%.2f.png',W,F_values(f))), ...
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
            sprintf('Spectrum_W_%d_F_%.2f.csv',W,F_values(f))));

    end


    %% =====================================================
    % 6. FIGURE 3 - CROSS-CORRELATION R_ab BETWEEN Q_A AND Q_B
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

        tU   = uniformData{f}{1};
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
            sprintf('Correlation_W_%d_F_%.2f.csv',W,F_values(f))));

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
            corrMin, lags(iMin)];

    end

    % ---- Format the correlation figure ----
    xlabel(axRaw,'$\mathrm{lag}\,(\mathrm{s})$');
    ylabel(axRaw,'$R_{ab}\,(\mathrm{pedestrians^2/s})$');
    title(axRaw,sprintf( ...
        '$\\mathrm{CROSS\\ CORRELATION}$ - $W=%d\\,\\mathrm{m}$',W), ...
        'Interpreter','latex');
    xlim(axRaw,[-maxLag maxLag]);

    xlabel(axNorm,'$\mathrm{lag}\,(\mathrm{s})$');
    ylabel(axNorm,'$R_{ab}^{\mathrm{norm}}\,(-)$');
    title(axNorm,sprintf( ...
        '$\\mathrm{NORMALISED\\ CROSS\\ CORRELATION}$ - $W=%d\\,\\mathrm{m}$',W), ...
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
        sprintf('Cross_Correlation_W_%d.png',W)),'Resolution',300);

    close(figureCorr);


    %% =====================================================
    % 7. FIGURE 4 - CONGESTION AREA VS TIME (TOTAL DENSITY)
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

            if isempty(Time_values{f})
                continue;
            end

            plot(Time_values{f},CongestionArea{c,f}, ...
                'Color',colors(f,:), ...
                'LineWidth',1.4);

            congestionLegend{end+1} = sprintf( ...
                '$F=%.1f$',F_values(f)); %#ok<SAGROW>

        end

        xlabel('$t\,(\mathrm{s})$');
        ylabel('$A_{\mathrm{congestion}}\,(\mathrm{m}^2)$');

        title(sprintf([ ...
            '$\\mathrm{CONGESTION\\ AREA\\ vs\\ TIME}$ - ' ...
            '$\\rho_{\\mathrm{total}}>%.1f\\,\\mathrm{pedestrians/m^2}$ - ' ...
            '$W=%d\\,\\mathrm{m}$'], ...
            threshold,W), ...
            'Interpreter','latex');

        if ~isempty(congestionLegend)
            legend(congestionLegend, ...
                'Location','eastoutside', ...
                'Interpreter','latex');
        end

        set(gca,'FontName','Times New Roman','FontSize',11);

        exportgraphics(figureCongestion,fullfile(congestionFolder, ...
            sprintf('Congestion_Area_Rho_%.1f_W_%d.png',threshold,W)), ...
            'Resolution',300);

        close(figureCongestion);

    end

    fprintf('\nFinished all analyses for W = %d m\n',W);

end


%% ---------------------------------------------------------
% 8. SAVE SUMMARY TABLE (DOMINANT FREQUENCIES, CORRELATION)
% ----------------------------------------------------------

summaryData = summaryData(1:summaryRow,:);

summaryTable = array2table(summaryData, ...
    'VariableNames',summaryHeader);

writetable(summaryTable,fullfile(mainResultsFolder, ...
    'Summary_Dominant_Frequency_and_Correlation.csv'));


%% ---------------------------------------------------------
% 9. COMPLETION
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
% Only four of the six solver files are needed:
%   Density_A, Density_B  -> congestion area, exit densities
%   Y_Velocity_A          -> outflow of crowd A (top exit)
%   X_Velocity_B          -> outflow of crowd B (right exit)

function [t,QA,QB,area] = processCase( ...
    inputFolder,W,F,Nx,Ny,h,exitIndices,thresholds,videoSettings)

    t = [];
    QA = [];
    QB = [];
    area = [];

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

    % ---- Congestion area (total density, interior 4:N-3) ----
    interiorTotal = RA(4:Nx-3,4:Ny-3,1:nFrames) + ...
                    RB(4:Nx-3,4:Ny-3,1:nFrames);

    area = zeros(length(thresholds),nFrames);

    for c = 1:length(thresholds)

        numberOfCells = sum(sum(interiorTotal > thresholds(c),1),2);

        area(c,:) = reshape(numberOfCells,1,[])*h*h;

    end

    % ---- Total-density animation (AVI) ----
    if ~isempty(videoSettings)

        fprintf('  Writing animation: %s\n',videoSettings.file);

        writeDensityVideo(videoSettings,interiorTotal,tA(1:nFrames), ...
            W,F,h);

    end

    clear RA RB interiorTotal;

    % ---- Velocity of crowd A (top exit) ----
    [tVA,VA] = readCSVFrames(yVelocityAFile,Ny,Nx);
    vA_exit = VA(exitIndices,Ny-3,:);
    clear VA;

    % ---- Velocity of crowd B (right exit) ----
    [tVB,VB] = readCSVFrames(xVelocityBFile,Ny,Nx);
    uB_exit = VB(Nx-3,exitIndices,:);
    clear VB;

    nFrames = min([nFrames,length(tVA),length(tVB)]);

    if any(abs(tA(1:nFrames)-tB(1:nFrames)) > 1e-9) || ...
       any(abs(tA(1:nFrames)-tVA(1:nFrames)) > 1e-9) || ...
       any(abs(tA(1:nFrames)-tVB(1:nFrames)) > 1e-9)

        error('Time values do not match for W=%d, F=%.2f',W,F);

    end

    t = tA(1:nFrames);
    area = area(:,1:nFrames);

    % ---- Outflow rates  Q = sum(rho*v) * h  (pedestrians/s) ----
    %
    % Summing over the open exit cells and multiplying by h is the
    % trapezoidal rule, because the wall nodes at P1 and P2 carry
    % no flux.

    % Crowd A: rhoA_exit is [nExit x 1 x nFrames] -> sum over dimension 1
    QA = reshape(sum(rhoA_exit(:,:,1:nFrames).*vA_exit(:,:,1:nFrames),1), ...
        [],1)*h;

    % Crowd B: rhoB_exit is [1 x nExit x nFrames] -> sum over dimension 2

    QB = reshape(sum(rhoB_exit(:,:,1:nFrames).*uB_exit(:,:,1:nFrames),2), ...
        [],1)*h;

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
% FUNCTION: WRITE THE TOTAL-DENSITY ANIMATION (AVI)
% ==========================================================
%
% interiorTotal(i,j,k) : total density on the interior points 4:N-3
%                        (91 x 91 points, 0 ... 90 m)

function writeDensityVideo(settings,interiorTotal,t,W,F,h)

    nX = size(interiorTotal,1);
    nY = size(interiorTotal,2);

    xCoord = (0:nX-1)*h;
    yCoord = (0:nY-1)*h;

    % Obstacle corners (the four blocks of the plus-shaped domain)
    a = (settings.P1 - 4)*h;     % lower edge of the passage
    b = (settings.P2 - 4)*h;     % upper edge of the passage
    L = (nX - 1)*h;              % domain length (90 m)

    video = VideoWriter(settings.file,'Motion JPEG AVI');
    video.FrameRate = settings.fps;
    video.Quality = 90;

    open(video);

    figureAnimation = figure( ...
        'Visible','off', ...
        'Color','w', ...
        'Position',[100 100 800 700]);

    % First frame (also creates the graphics objects)
    D = interiorTotal(:,:,1)';           % transpose: rows = y, columns = x

    hImage = imagesc(xCoord,yCoord,D);
    set(gca,'YDir','normal');

    hold on;

    % Grey obstacle blocks
    obstacleColor = [0.55 0.55 0.55];

    patch([0 a a 0],[0 0 a a],obstacleColor,'EdgeColor','k');   % bottom left
    patch([b L L b],[0 0 a a],obstacleColor,'EdgeColor','k');   % bottom right
    patch([0 a a 0],[b b L L],obstacleColor,'EdgeColor','k');   % top left
    patch([b L L b],[b b L L],obstacleColor,'EdgeColor','k');   % top right

    colormap(figureAnimation,jet(256));
    set(gca,'CLim',[0 settings.colorLimit]);

    axis equal;
    xlim([0 L]);
    ylim([0 L]);
    xticks(0:15:L);
    yticks(0:15:L);

    xlabel('$x\,(\mathrm{m})$','Interpreter','latex','FontSize',13);
    ylabel('$y\,(\mathrm{m})$','Interpreter','latex','FontSize',13);

    set(gca, ...
        'FontName','Times New Roman', ...
        'FontSize',12, ...
        'LineWidth',1.0, ...
        'TickLabelInterpreter','latex', ...
        'Layer','top');

    cb = colorbar;
    cb.Label.String = '$\rho_{\mathrm{total}}\,(\mathrm{pedestrians/m^2})$';
    cb.Label.Interpreter = 'latex';
    cb.Label.FontSize = 12;
    cb.TickLabelInterpreter = 'latex';
    cb.FontName = 'Times New Roman';

    hTitle = title('','Interpreter','latex','FontSize',13);

    frameIndices = 1:settings.frameStep:size(interiorTotal,3);

    for k = frameIndices

        set(hImage,'CData',interiorTotal(:,:,k)');

        set(hTitle,'String',sprintf([ ...
            '$\\mathrm{TOTAL\\ DENSITY}$ - $W=%d\\,\\mathrm{m}$ - ' ...
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