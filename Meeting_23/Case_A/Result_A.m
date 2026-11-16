%% =========================================================
%  CASE A - CROWD FLOW PAST A SQUARE OBSTACLE IN A RECTANGULAR DOMAIN
%  POST-PROCESSING
%  ---------------------------------------------------------
%  Domain   : 100 m x 50 m, crowd enters on the LEFT (column 4,
%             rows 4:Ny-3) and leaves on the RIGHT (column Nx-3,
%             rows 4:Ny-3)
%  Obstacle : square Lx = Ly = 10, 20, 30, 40 m, at the centre
%             obstacle(P2:P4, P1:P3) = true   (rows P2:P4, columns P1:P3)
%  Inflow flux F = 0.5 : 0.5 : 5.0  pedestrians/m/s
%
%  Station A : bottom channel, middle column, rows 4 ... P2-1
%  Station B : top channel,    middle column, rows P4+1 ... Ny-3
%
%  Produces
%   1. Average density vs average flux (per length + all lengths)
%   2. Inflow rate vs outflow rate vs time (one figure per length)
%   3. Choking time vs inflow flux (all lengths in one plot)
%   4. Flow rate at station A and B vs time (one figure per length)
%   5. FFT amplitude + power spectrum (one figure per length & flux = 40)
%   6. Phase space Q_A vs Q_B (one figure per length)
%   7. AVI animation of the density (black obstacle, contourf)
%   8. AVI animation of the normal density gradient
%         d(rho)/dn = grad(rho) . u/|u|      (u = local velocity vector)
%   9. Time-averaged inflow / outflow rate vs time
%         (a) cumulative average   (b) moving-window average
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

% Obstacle sizes (Lx = Ly) and the folders with the solver output
obstacleLengths = [10 20 30 40];
folderNames     = {'L_10','L_20','L_30','L_40'};

% Inflow flux, pedestrians/m/s
F_values = 0.5:0.5:5.0;

% Grid (100 x 50 cells + 3 ghost cells on each side)
Nx = 106;
Ny = 56;
Lx = 100;
Ly = 50;

% Cell size (cell-centred grid, h = 1 m)
h = Lx/(Nx-6);

% Obstacle indices, as in makeGeometry of the solver:
%   obstacle(P2:P4, P1:P3) = true  ->  columns P1:P3, rows P2:P4
%            P1  P2  P3  P4
P_values = [49  24  58  33;    % L = 10 m
            44  19  63  38;    % L = 20 m
            39  14  68  43;    % L = 30 m
            34   9  73  48];   % L = 40 m

% Choking criterion: density anywhere in the domain exceeds this value
% (the solver itself stops when the density exceeds 11)
chokingThreshold = 10;

% Averages (density vs flux) are taken over t >= averageStartTime
averageStartTime = 0;       % s

% ----- Spectral settings -----
analysisStartTime = 120;      % s   Data before this time is ignored in the FFT
                            %     (use e.g. 50 to skip the filling transient)
applyHannWindow   = false;  % true -> Hann window before the FFT
fMaxPlot          = 1.0;    % Hz  Upper frequency limit of the spectrum plots

% ----- Density animation (AVI) -----
makeAnimations     = true;  % false -> skip all videos
animationFrameStep = 1;     % use every n-th saved frame
videoFPS           = 10;    % frames per second of the AVI
densityColorLimit  = 10;    % colour-bar upper limit (rho_max)
contourLevels      = 100;   % number of contour levels (more = smoother colours)
animationUpsample  = 3;     % each cell is split into n x n points before
                            % contouring (1 = no refinement, 4 = very fine,
                            % but slower)
videoFigureSize    = [1400 700];   % video frame size in pixels [width height]

% ----- Normal density gradient animation (AVI) -----
makeGradientAnimation = true;   % false -> skip the gradient videos
gradientColorLimit    = 2;      % colour scale is symmetric: [-lim, +lim]
                                % (ped/m^3). The peak value of every video is
                                % printed in the command window - adjust this
                                % number if the colours look saturated/faint.
gradientColormap      = 'jet';  % 'jet' (same as density) or 'bwr'
                                % (blue-white-red, zero = white)
velocityEpsilon       = 1e-6;   % m/s. Where |u| < this, the direction u/|u|
                                % is undefined and d(rho)/dn is set to 0

% ----- Time-averaged outflow -----
outflowAvgStartTime = 0;        % s  averaging starts here (use e.g. 50 to
                                %    skip the filling transient)
outflowAvgWindow    = 60;       % s  window length of the moving average

% Re-use previously extracted data (much faster on a second run)
useCache     = true;
cacheVersion = 1;

% Colours: one colour per inflow flux
colors = jet(length(F_values));

% Output folders
mainResultsFolder = fullfile(pwd,'Results_Case_A');

if ~exist(mainResultsFolder,'dir')
    mkdir(mainResultsFolder);
end

% Storage (rows = obstacle length, columns = inflow flux)
AvgDensity   = NaN(length(obstacleLengths),length(F_values));
AvgFlux      = NaN(length(obstacleLengths),length(F_values));
ChokingTimes = NaN(length(obstacleLengths),length(F_values));

% Summary table: one row per length and flux
summaryHeader = { ...
    'Lx_Ly_m','Flux_ped_m_s', ...
    'AvgDensity_ped_m2','AvgFlux_ped_m_s','ChokingTime_s', ...
    'MeanQin_ped_s','MeanQout_ped_s', ...
    'MeanQ_A_ped_s','MeanQ_B_ped_s', ...
    'DominantFreq_Qout_Hz','DominantFreq_QA_Hz','DominantFreq_QB_Hz'};

summaryData = NaN(length(obstacleLengths)*length(F_values), ...
    length(summaryHeader));


%% ---------------------------------------------------------
% 2. LOOP OVER THE FOUR OBSTACLE SIZES
% ----------------------------------------------------------

for l = 1:length(obstacleLengths)

    len = obstacleLengths(l);
    inputFolder = folderNames{l};

    P = P_values(l,:);

    % Text used in every title:  Lx = Ly = L
    lengthTitle = sprintf('$L_x=L_y=%d\\,\\mathrm{m}$',len);

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('PROCESSING OBSTACLE Lx = Ly = %d m\n',len);
    fprintf('============================================\n');

    if ~exist(inputFolder,'dir')
        warning('Input folder %s does not exist. Skipping.',inputFolder);
        continue;
    end

    % -----------------------------------------------------
    % Output folders
    % -----------------------------------------------------

    resultFolder      = fullfile(mainResultsFolder,sprintf('result_%d',l));
    densityFluxFolder = fullfile(resultFolder,'Density_vs_Flux');
    inOutFolder       = fullfile(resultFolder,'Inflow_vs_Outflow');
    stationFolder     = fullfile(resultFolder,'Station_Flow_Rates');
    fftFolder         = fullfile(resultFolder,'FFT');
    phaseFolder       = fullfile(resultFolder,'Phase_Space');
    dataFolder        = fullfile(resultFolder,'Data');
    animationFolder   = fullfile(resultFolder,'Animations');
    avgFolder         = fullfile(resultFolder,'Outflow_Time_Averaged');

    outputFolders = {resultFolder; densityFluxFolder; inOutFolder; ...
                     stationFolder; fftFolder; phaseFolder; ...
                     dataFolder; animationFolder; avgFolder};

    for k = 1:length(outputFolders)

        if ~exist(outputFolders{k},'dir')
            mkdir(outputFolders{k});
        end

    end

    CaseData = cell(length(F_values),1);   % one struct per flux


    %% =====================================================
    % 3. READ / EXTRACT DATA FOR EVERY INFLOW FLUX
    % ======================================================

    for f = 1:length(F_values)

        F = F_values(f);

        fprintf('\nProcessing Lx = Ly = %d m, F = %.2f\n',len,F);

        cacheFile = fullfile(dataFolder, ...
            sprintf('Cache_L_%d_F_%.2f.mat',len,F));

        videoFile = fullfile(animationFolder, ...
            sprintf('Density_Lx_Ly_%d_F_%.2f.avi',len,F));

        gradVideoFile = fullfile(animationFolder, ...
            sprintf('Normal_Density_Gradient_Lx_Ly_%d_F_%.2f.avi',len,F));

        % The videos need the full fields, so the data is only taken from
        % the cache when no video has to be made.
        needDensityVideo = makeAnimations         && ~isfile(videoFile);
        needGradVideo    = makeGradientAnimation  && ~isfile(gradVideoFile);
        needVideo        = needDensityVideo || needGradVideo;

        C = [];

        if useCache && ~needVideo && isfile(cacheFile)

            S = load(cacheFile);

            if isfield(S,'cacheVersion') && S.cacheVersion == cacheVersion && ...
               isequal(S.PP,P)

                C = S.C;
                fprintf('  Loaded from cache.\n');

            end

        end

        if isempty(C)

            % ---- settings of the density video ----
            densityVideo = [];

            if needDensityVideo
                densityVideo = struct( ...
                    'file',videoFile, ...
                    'P',P, ...
                    'frameStep',animationFrameStep, ...
                    'fps',videoFPS, ...
                    'colorLimit',densityColorLimit, ...
                    'symmetric',false, ...
                    'colormap','jet', ...
                    'colorbarLabel','$\rho\,(\mathrm{pedestrians/m^2})$', ...
                    'levels',contourLevels, ...
                    'upsample',animationUpsample, ...
                    'figureSize',videoFigureSize);
            end

            % ---- settings of the normal-density-gradient video ----
            gradVideo = [];

            if needGradVideo
                gradVideo = struct( ...
                    'file',gradVideoFile, ...
                    'P',P, ...
                    'frameStep',animationFrameStep, ...
                    'fps',videoFPS, ...
                    'colorLimit',gradientColorLimit, ...
                    'symmetric',true, ...
                    'colormap',gradientColormap, ...
                    'colorbarLabel','$\partial\rho/\partial n\,(\mathrm{pedestrians/m^3})$', ...
                    'levels',contourLevels, ...
                    'upsample',animationUpsample, ...
                    'figureSize',videoFigureSize, ...
                    'velocityEpsilon',velocityEpsilon);
            end

            try

                C = processCase(inputFolder,len,F,Nx,Ny,h,P,densityVideo,gradVideo);

            catch ME

                warning('Lx=Ly=%d, F=%.2f skipped:\n%s',len,F,ME.message);
                C = [];

            end

            if ~isempty(C)

                PP = P; %#ok<NASGU>

                save(cacheFile,'C','PP','cacheVersion');

            end

        end

        if isempty(C)
            continue;
        end

        % -------------------------------------------------
        % Time-averaged inflow / outflow rate
        %   Cum : (1/(t-t0)) * integral_t0^t Q dt'   (running mean)
        %   Mov : centred moving average, window = outflowAvgWindow
        % -------------------------------------------------

        C.QinCum  = cumulativeAverage(C.t,C.Qin, outflowAvgStartTime);
        C.QoutCum = cumulativeAverage(C.t,C.Qout,outflowAvgStartTime);
        C.QinMov  = movingAverage(C.t,C.Qin, outflowAvgWindow);
        C.QoutMov = movingAverage(C.t,C.Qout,outflowAvgWindow);

        CaseData{f} = C;

        % -------------------------------------------------
        % Averages in space and time (density vs flux)
        % -------------------------------------------------

        AvgDensity(l,f) = timeAverage(C.t,C.meanRho, averageStartTime);
        AvgFlux(l,f)    = timeAverage(C.t,C.meanFlux,averageStartTime);

        % -------------------------------------------------
        % Choking time: first time the density anywhere in the
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
            C.Qin(:), ...
            C.Qout(:), ...
            C.QA(:), ...
            C.QB(:), ...
            C.meanRho(:), ...
            C.meanFlux(:), ...
            C.maxRho(:), ...
            C.QinCum(:), ...
            C.QoutCum(:), ...
            C.QinMov(:), ...
            C.QoutMov(:), ...
            'VariableNames',{ ...
            'Time_s', ...
            'InflowRate_pedestrians_s', ...
            'OutflowRate_pedestrians_s', ...
            'StationA_Flow_pedestrians_s', ...
            'StationB_Flow_pedestrians_s', ...
            'MeanDensity_pedestrians_m2', ...
            'MeanFlux_pedestrians_m_s', ...
            'MaxDensity_pedestrians_m2', ...
            'InflowCumAvg_pedestrians_s', ...
            'OutflowCumAvg_pedestrians_s', ...
            'InflowMovAvg_pedestrians_s', ...
            'OutflowMovAvg_pedestrians_s'});

        writetable(simulationTable,fullfile(dataFolder, ...
            sprintf('Results_Lx_Ly_%d_F_%.2f.csv',len,F)));

        fprintf('  Frames: %d | final time: %.3f s\n', ...
            length(C.t),C.t(end));

        if isnan(ChokingTimes(l,f))
            fprintf('  Status: NOT CHOKED\n');
        else
            fprintf('  Status: CHOKED at %.3f s\n',ChokingTimes(l,f));
        end

    end


    %% =====================================================
    % 4. FIGURE 1 - AVERAGE DENSITY VS AVERAGE FLUX (ONE PER LENGTH)
    % ======================================================

    figureDF = figure('Color','w','Visible','off', ...
        'Position',[100 100 800 600]);
    hold on;
    grid on;
    box on;

    plot(AvgDensity(l,:),AvgFlux(l,:), ...
        '-o', ...
        'Color',[0 0.447 0.741], ...
        'MarkerFaceColor',[0 0.447 0.741], ...
        'LineWidth',1.8, ...
        'MarkerSize',6);

    % Label every point with its inflow flux
    for f = 1:length(F_values)

        if ~isnan(AvgDensity(l,f))
            text(AvgDensity(l,f),AvgFlux(l,f), ...
                sprintf('  %.1f',F_values(f)), ...
                'FontSize',9,'Interpreter','latex');
        end

    end

    xlabel('$\rho_{\mathrm{avg}}\,(\mathrm{pedestrians/m^2})$');
    ylabel('$q_{\mathrm{avg}}\,(\mathrm{pedestrians/m/s})$');

    title(['$\mathrm{DENSITY\ vs\ FLUX}$ - ' lengthTitle], ...
        'Interpreter','latex');

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figureDF,fullfile(densityFluxFolder, ...
        sprintf('Density_vs_Flux_Lx_Ly_%d.png',len)),'Resolution',300);

    close(figureDF);


    %% =====================================================
    % 5. FIGURE 2 - INFLOW RATE VS OUTFLOW RATE VS TIME
    % ======================================================
    %
    %   Inflow  : sum(rho*u)*h at column 4,    rows 4:Ny-3  (dotted)
    %   Outflow : sum(rho*u)*h at column Nx-3, rows 4:Ny-3  (continuous)

    figureIO = figure('Color','w','Visible','off', ...
        'Position',[100 100 1000 600]);
    hold on;
    grid on;
    box on;

    ioLegend = {};

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        plot(CaseData{f}.t,CaseData{f}.Qout, ...
            'Color',colors(f,:), ...
            'LineStyle','-', ...
            'LineWidth',1.4);

        ioLegend{end+1} = sprintf( ...
            '$\\mathrm{Out},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

        plot(CaseData{f}.t,CaseData{f}.Qin, ...
            'Color',colors(f,:), ...
            'LineStyle',':', ...
            'LineWidth',2.0);

        ioLegend{end+1} = sprintf( ...
            '$\\mathrm{In},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$Q\,(\mathrm{pedestrians/s})$');

    title(['$\mathrm{INFLOW\ vs\ OUTFLOW\ RATE}$ - ' lengthTitle], ...
        'Interpreter','latex');

    if ~isempty(ioLegend)
        legend(ioLegend, ...
            'Location','eastoutside', ...
            'FontSize',8, ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figureIO,fullfile(inOutFolder, ...
        sprintf('Inflow_Outflow_Lx_Ly_%d.png',len)),'Resolution',300);

    close(figureIO);


    %% =====================================================
    % 5b. FIGURE 2b / 2c - TIME-AVERAGED INFLOW AND OUTFLOW RATE
    % ======================================================
    %
    %   2b : cumulative (running) average from outflowAvgStartTime
    %   2c : centred moving average over outflowAvgWindow seconds
    %   Outflow : continuous line,  Inflow : dotted line

    avgVariants = { ...
        'QoutCum','QinCum','Cumulative', ...
        '$\mathrm{TIME\ AVERAGED\ FLOW\ RATE\ (CUMULATIVE)}$'; ...
        'QoutMov','QinMov','MovingWindow', ...
        sprintf('$\\mathrm{TIME\\ AVERAGED\\ FLOW\\ RATE\\ (%g\\,s\\ MOVING\\ WINDOW)}$', ...
        outflowAvgWindow)};

    for v = 1:size(avgVariants,1)

        figureAvg = figure('Color','w','Visible','off', ...
            'Position',[100 100 1000 600]);
        hold on;
        grid on;
        box on;

        avgLegend = {};

        for f = 1:length(F_values)

            if isempty(CaseData{f})
                continue;
            end

            plot(CaseData{f}.t,CaseData{f}.(avgVariants{v,1}), ...
                'Color',colors(f,:), ...
                'LineStyle','-', ...
                'LineWidth',1.6);

            avgLegend{end+1} = sprintf( ...
                '$\\langle\\mathrm{Out}\\rangle,\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

            plot(CaseData{f}.t,CaseData{f}.(avgVariants{v,2}), ...
                'Color',colors(f,:), ...
                'LineStyle',':', ...
                'LineWidth',2.0);

            avgLegend{end+1} = sprintf( ...
                '$\\langle\\mathrm{In}\\rangle,\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

        end

        xlabel('$t\,(\mathrm{s})$');
        ylabel('$\langle Q\rangle_t\,(\mathrm{pedestrians/s})$');

        title([avgVariants{v,4} ' - ' lengthTitle],'Interpreter','latex');

        if ~isempty(avgLegend)
            legend(avgLegend, ...
                'Location','eastoutside', ...
                'FontSize',8, ...
                'Interpreter','latex');
        end

        set(gca,'FontName','Times New Roman','FontSize',11);

        exportgraphics(figureAvg,fullfile(avgFolder, ...
            sprintf('Outflow_TimeAveraged_%s_Lx_Ly_%d.png', ...
            avgVariants{v,3},len)),'Resolution',300);

        close(figureAvg);

    end


    %% =====================================================
    % 6. FIGURE 4 - FLOW RATE AT STATION A AND STATION B
    % ======================================================
    %
    %   Station A (bottom channel) : continuous line
    %   Station B (top channel)    : dotted line

    figureStation = figure('Color','w','Visible','off', ...
        'Position',[100 100 1000 600]);
    hold on;
    grid on;
    box on;

    stationLegend = {};

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        plot(CaseData{f}.t,CaseData{f}.QA, ...
            'Color',colors(f,:), ...
            'LineStyle','-', ...
            'LineWidth',1.4);

        stationLegend{end+1} = sprintf( ...
            '$\\mathrm{A},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

        plot(CaseData{f}.t,CaseData{f}.QB, ...
            'Color',colors(f,:), ...
            'LineStyle',':', ...
            'LineWidth',2.0);

        stationLegend{end+1} = sprintf( ...
            '$\\mathrm{B},\\ F=%.1f$',F_values(f)); %#ok<SAGROW>

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$Q_{\mathrm{station}}\,(\mathrm{pedestrians/s})$');

    title(['$\mathrm{STATION\ A\ AND\ B\ FLOW\ RATE}$ - ' lengthTitle], ...
        'Interpreter','latex');

    if ~isempty(stationLegend)
        legend(stationLegend, ...
            'Location','eastoutside', ...
            'FontSize',8, ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figureStation,fullfile(stationFolder, ...
        sprintf('Station_Flow_Lx_Ly_%d.png',len)),'Resolution',300);

    close(figureStation);


    %% =====================================================
    % 7. FIGURE 6 - PHASE SPACE  Q_A  VS  Q_B
    % ======================================================

    figurePhase = figure('Color','w','Visible','off', ...
        'Position',[100 100 900 700]);
    hold on;
    grid on;
    box on;

    phaseLegend = {};

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        plot(CaseData{f}.QA,CaseData{f}.QB, ...
            'Color',colors(f,:), ...
            'LineWidth',1.2);

        % Filled dot = last recorded state
        plot(CaseData{f}.QA(end),CaseData{f}.QB(end),'o', ...
            'Color',colors(f,:), ...
            'MarkerFaceColor',colors(f,:), ...
            'MarkerSize',5, ...
            'HandleVisibility','off');

        phaseLegend{end+1} = sprintf( ...
            '$F=%.1f$',F_values(f)); %#ok<SAGROW>

    end

    xlabel('$Q_A\,(\mathrm{pedestrians/s})$');
    ylabel('$Q_B\,(\mathrm{pedestrians/s})$');

    title(['$\mathrm{PHASE\ SPACE}\ (Q_A\ \mathrm{vs}\ Q_B)$ - ' lengthTitle], ...
        'Interpreter','latex');

    if ~isempty(phaseLegend)
        legend(phaseLegend, ...
            'Location','eastoutside', ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    exportgraphics(figurePhase,fullfile(phaseFolder, ...
        sprintf('Phase_Space_Lx_Ly_%d.png',len)),'Resolution',300);

    close(figurePhase);


    %% =====================================================
    % 8. FIGURE 5 - FFT AND POWER SPECTRUM (ONE FIGURE PER FLUX)
    % ======================================================
    %
    % The solver time-step follows a CFL condition, so the saved times are
    % not uniform. Every signal is resampled to a uniform grid first.

    for f = 1:length(F_values)

        if isempty(CaseData{f})
            continue;
        end

        C = CaseData{f};

        dtU = median(diff(C.t));

        tStart = max(analysisStartTime,C.t(1));
        tU = (tStart:dtU:C.t(end))';

        if numel(tU) < 16
            warning('Lx=Ly=%d, F=%.2f: too few samples after t = %.1f s.', ...
                len,F_values(f),analysisStartTime);
            continue;
        end

        Qout_u = interp1(C.t,C.Qout,tU,'linear');
        QA_u   = interp1(C.t,C.QA,  tU,'linear');
        QB_u   = interp1(C.t,C.QB,  tU,'linear');

        [fo,ampO,psdO,fDomO] = computeSpectrum(Qout_u,dtU,applyHannWindow);
        [fa,ampA,psdA,fDomA] = computeSpectrum(QA_u,  dtU,applyHannWindow);
        [fb,ampB,psdB,fDomB] = computeSpectrum(QB_u,  dtU,applyHannWindow);

        figureFFT = figure('Color','w','Visible','off', ...
            'Position',[100 100 900 700]);

        legendText = { ...
            sprintf('$Q_{\\mathrm{out}}$ ($f_d=%.4f\\,\\mathrm{Hz}$)',fDomO), ...
            sprintf('$Q_A$ ($f_d=%.4f\\,\\mathrm{Hz}$)',fDomA), ...
            sprintf('$Q_B$ ($f_d=%.4f\\,\\mathrm{Hz}$)',fDomB)};

        fLimit = min(fMaxPlot,fo(end));

        % ---- (a) FFT amplitude ----
        subplot(2,1,1);
        hold on;
        grid on;
        box on;

        plot(fo,ampO,'-','Color',[0 0 0],'LineWidth',1.2);
        plot(fa,ampA,'-','Color',colors(f,:),'LineWidth',1.4);
        plot(fb,ampB,':','Color',colors(f,:),'LineWidth',2.0);

        xlim([0 fLimit]);

        xlabel('$f\,(\mathrm{Hz})$');
        ylabel('$|\hat{Q}(f)|\,(\mathrm{pedestrians/s})$');

        title('$\mathrm{FFT\ AMPLITUDE\ SPECTRUM}$', ...
            'Interpreter','latex');

        legend(legendText,'Location','northeast','Interpreter','latex');

        set(gca,'FontName','Times New Roman','FontSize',11);

        % ---- (b) Power spectrum ----
        subplot(2,1,2);
        hold on;
        grid on;
        box on;

        plot(fo,psdO,'-','Color',[0 0 0],'LineWidth',1.2);
        plot(fa,psdA,'-','Color',colors(f,:),'LineWidth',1.4);
        plot(fb,psdB,':','Color',colors(f,:),'LineWidth',2.0);

        xlim([0 fLimit]);

        xlabel('$f\,(\mathrm{Hz})$');
        ylabel('$S_{QQ}(f)\,(\mathrm{pedestrians^2/s})$');

        title('$\mathrm{POWER\ SPECTRUM}$', ...
            'Interpreter','latex');

        legend({'$Q_{\mathrm{out}}$','$Q_A$','$Q_B$'}, ...
            'Location','northeast','Interpreter','latex');

        set(gca,'FontName','Times New Roman','FontSize',11);

        sgtitle(sprintf([ ...
            '$L_x=L_y=%d\\,\\mathrm{m}$ - ' ...
            '$F=%.1f\\,\\mathrm{pedestrians/m/s}$'], ...
            len,F_values(f)), ...
            'Interpreter','latex');

        exportgraphics(figureFFT,fullfile(fftFolder, ...
            sprintf('FFT_Lx_Ly_%d_F_%.2f.png',len,F_values(f))), ...
            'Resolution',300);

        close(figureFFT);

        % ---- Save the spectra ----
        nMin = min([numel(fo),numel(fa),numel(fb)]);

        spectrumTable = table( ...
            fo(1:nMin), ...
            ampO(1:nMin),psdO(1:nMin), ...
            ampA(1:nMin),psdA(1:nMin), ...
            ampB(1:nMin),psdB(1:nMin), ...
            'VariableNames',{ ...
            'Frequency_Hz', ...
            'Amplitude_Qout','PowerSpectrum_Qout', ...
            'Amplitude_QA','PowerSpectrum_QA', ...
            'Amplitude_QB','PowerSpectrum_QB'});

        writetable(spectrumTable,fullfile(dataFolder, ...
            sprintf('Spectrum_Lx_Ly_%d_F_%.2f.csv',len,F_values(f))));

        % ---- Summary row ----
        row = (l-1)*length(F_values) + f;

        summaryData(row,:) = [ ...
            len, F_values(f), ...
            AvgDensity(l,f), AvgFlux(l,f), ChokingTimes(l,f), ...
            mean(C.Qin), mean(C.Qout), ...
            mean(C.QA), mean(C.QB), ...
            fDomO, fDomA, fDomB];

    end

    fprintf('\nFinished all analyses for Lx = Ly = %d m\n',len);

end


%% ---------------------------------------------------------
% 9. FIGURE 1b - DENSITY VS FLUX, ALL OBSTACLE SIZES IN ONE PLOT
% ----------------------------------------------------------

figureDFall = figure('Color','w','Visible','off', ...
    'Position',[100 100 900 650]);
hold on;
grid on;
box on;

lengthColors  = lines(length(obstacleLengths));
lengthMarkers = {'o','s','^','d'};

for l = 1:length(obstacleLengths)

    plot(AvgDensity(l,:),AvgFlux(l,:), ...
        'Marker',lengthMarkers{l}, ...
        'Color',lengthColors(l,:), ...
        'MarkerFaceColor',lengthColors(l,:), ...
        'LineWidth',1.6, ...
        'MarkerSize',6);

end

xlabel('$\rho_{\mathrm{avg}}\,(\mathrm{pedestrians/m^2})$');
ylabel('$q_{\mathrm{avg}}\,(\mathrm{pedestrians/m/s})$');

title('$\mathrm{DENSITY\ vs\ FLUX}$', ...
    'Interpreter','latex');

legend(compose('$L_x=L_y=%d\\,\\mathrm{m}$',obstacleLengths), ...
    'Location','best', ...
    'Interpreter','latex');

set(gca,'FontName','Times New Roman','FontSize',11);

exportgraphics(figureDFall,fullfile(mainResultsFolder, ...
    'Density_vs_Flux_All_Lengths.png'),'Resolution',300);

close(figureDFall);


%% ---------------------------------------------------------
% 10. FIGURE 3 - CHOKING TIME VS INFLOW FLUX (ALL OBSTACLE SIZES)
% ----------------------------------------------------------

figureChoking = figure('Color','w','Visible','off', ...
    'Position',[100 100 900 600]);
hold on;
grid on;
box on;

for l = 1:length(obstacleLengths)

    plot(F_values,ChokingTimes(l,:), ...
        'Marker',lengthMarkers{l}, ...
        'Color',lengthColors(l,:), ...
        'MarkerFaceColor',lengthColors(l,:), ...
        'LineWidth',1.6, ...
        'MarkerSize',6);

end

xlabel('$F\,(\mathrm{pedestrians/m/s})$');
ylabel('$t_{\mathrm{choking}}\,(\mathrm{s})$');

title('$\mathrm{CHOKING\ TIME\ vs\ INFLOW\ FLUX}$', ...
    'Interpreter','latex');

legend(compose('$L_x=L_y=%d\\,\\mathrm{m}$',obstacleLengths), ...
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
% 11. SAVE SUMMARY TABLE
% ----------------------------------------------------------

summaryTable = array2table(summaryData,'VariableNames',summaryHeader);

writetable(summaryTable,fullfile(mainResultsFolder, ...
    'Summary_Results.csv'));


%% ---------------------------------------------------------
% 12. COMPLETION
% ----------------------------------------------------------

fprintf('\n');
fprintf('=================================================\n');
fprintf('CASE A POST-PROCESSING COMPLETED SUCCESSFULLY\n');
fprintf('=================================================\n');

fprintf('Results saved in: %s\n',mainResultsFolder);


%% =========================================================
% FUNCTION: PROCESS ONE SIMULATION (ONE OBSTACLE SIZE, ONE FLUX)
% ==========================================================
%
% Files needed:
%   Density_L_xx.xx_F_x.xx.csv
%   X_Velocity_L_xx.xx_F_x.xx.csv
%   Y_Velocity_L_xx.xx_F_x.xx.csv   (only for the gradient animation;
%                                    all flows are measured through
%                                    vertical cross-sections)
%
% Returns a struct C with the fields
%   t         time                                 (nT x 1)
%   Qin       inflow rate,  column 4               (nT x 1)
%   Qout      outflow rate, column Nx-3            (nT x 1)
%   QA, QB    flow rate at station A and B         (nT x 1)
%   meanRho   density averaged over the fluid area (nT x 1)
%   meanFlux  rho*u  averaged over the fluid area  (nT x 1)
%   maxRho    maximum density in the domain        (nT x 1)

function C = processCase(inputFolder,len,F,Nx,Ny,h,P,densityVideo,gradVideo)

    C = [];

    P1 = P(1);
    P2 = P(2);
    P3 = P(3);
    P4 = P(4);

    densityFile = fullfile(inputFolder, ...
        sprintf('Density_L_%.2f_F_%.2f.csv',len,F));

    xVelocityFile = fullfile(inputFolder, ...
        sprintf('X_Velocity_L_%.2f_F_%.2f.csv',len,F));

    if ~isfile(densityFile) || ~isfile(xVelocityFile)
        warning('Missing simulation files for L=%d, F=%.2f. Skipping.', ...
            len,F);
        return;
    end

    % NOTE: the reader returns V(i,j,frame) with
    %   i = x index (column in the CSV), j = y index (row in the CSV)

    [tR,R] = readCSVFrames(densityFile,Ny,Nx);
    [tU,U] = readCSVFrames(xVelocityFile,Ny,Nx);

    % The Y velocity is only read when the gradient video is requested
    V  = [];
    tV = tR;

    if ~isempty(gradVideo)

        yVelocityFile = fullfile(inputFolder, ...
            sprintf('Y_Velocity_L_%.2f_F_%.2f.csv',len,F));

        if isfile(yVelocityFile)
            [tV,V] = readCSVFrames(yVelocityFile,Ny,Nx);
        else
            warning('Missing %s - gradient animation skipped.',yVelocityFile);
            gradVideo = [];
        end

    end

    nFrames = min([length(tR),length(tU),length(tV)]);

    if nFrames < 2
        warning('Fewer than 2 frames for L=%d, F=%.2f. Skipping.',len,F);
        return;
    end

    if any(abs(tR(1:nFrames)-tU(1:nFrames)) > 1e-9)
        error('Time values do not match for L=%d, F=%.2f',len,F);
    end

    R = R(:,:,1:nFrames);
    U = U(:,:,1:nFrames);
    t = tR(1:nFrames);

    if ~isempty(V)

        if any(abs(tR(1:nFrames)-tV(1:nFrames)) > 1e-9)
            error('Y-velocity times do not match for L=%d, F=%.2f',len,F);
        end

        V = V(:,:,1:nFrames);

    end

    % ---- Obstacle mask: obstacle(P2:P4,P1:P3) -> columns P1:P3, rows P2:P4
    obstacle = false(Nx,Ny);
    obstacle(P1:P3,P2:P4) = true;

    fluid  = ~obstacle(4:Nx-3,4:Ny-3);
    nFluid = nnz(fluid);

    % ---- Averages over the fluid part of the interior (4:N-3) ----
    RI = R(4:Nx-3,4:Ny-3,:);
    UI = U(4:Nx-3,4:Ny-3,:);

    meanRho  = reshape(sum(sum(RI.*fluid,1),2),[],1)/nFluid;
    meanFlux = reshape(sum(sum(RI.*UI.*fluid,1),2),[],1)/nFluid;
    maxRho   = reshape(max(max(RI.*fluid,[],1),[],2),[],1);

    clear RI UI;

    % ---- Inflow and outflow rates  Q = sum(rho*u)*h  (pedestrians/s) ----
    rows = 4:Ny-3;

    Qin  = reshape(sum(R(4,   rows,:).*U(4,   rows,:),2),[],1)*h;
    Qout = reshape(sum(R(Nx-3,rows,:).*U(Nx-3,rows,:),2),[],1)*h;

    % ---- Station A (bottom channel) and B (top channel), middle column ----
    midCol = round(Nx/2);

    stationARows = 4:(P2-1);
    stationBRows = (P4+1):(Ny-3);

    QA = reshape(sum(R(midCol,stationARows,:).*U(midCol,stationARows,:),2), ...
        [],1)*h;

    QB = reshape(sum(R(midCol,stationBRows,:).*U(midCol,stationBRows,:),2), ...
        [],1)*h;

    % ---- Density animation (AVI) ----
    if ~isempty(densityVideo)

        fprintf('  Writing density animation: %s\n',densityVideo.file);

        densityFcn = @(k) R(4:Nx-3,4:Ny-3,k);

        writeFieldVideo(densityVideo,densityFcn,t,Nx,Ny,len,F,h);

    end

    % ---- Normal density gradient animation (AVI) ----
    if ~isempty(gradVideo)

        fprintf('  Writing gradient animation: %s\n',gradVideo.file);

        gradFcn = @(k) normalDensityGradient( ...
            R(:,:,k),U(:,:,k),V(:,:,k),obstacle,h,gradVideo.velocityEpsilon);

        writeFieldVideo(gradVideo,gradFcn,t,Nx,Ny,len,F,h);

    end

    % ---- Assemble the output ----
    C = struct();
    C.t        = t;
    C.Qin      = Qin;
    C.Qout     = Qout;
    C.QA       = QA;
    C.QB       = QB;
    C.meanRho  = meanRho;
    C.meanFlux = meanFlux;
    C.maxRho   = maxRho;

end


%% =========================================================
% FUNCTION: TIME AVERAGE (TRAPEZOIDAL, NON-UNIFORM TIME STEPS)
% ==========================================================

function m = timeAverage(t,x,tStart)

    mask = t >= tStart;

    t = t(mask);
    x = x(mask);

    if numel(t) >= 2 && t(end) > t(1)
        m = trapz(t,x)/(t(end)-t(1));
    elseif ~isempty(x)
        m = mean(x);
    else
        m = NaN;
    end

end


%% =========================================================
% FUNCTION: NORMAL DENSITY GRADIENT   d(rho)/dn = grad(rho) . u/|u|
% ==========================================================
%
% R,U,V : density, x-velocity, y-velocity on the FULL Nx x Ny grid
%         (index i = x, j = y) for ONE frame.
% Returns the (Nx-6) x (Ny-6) interior field (ped/m^3).
%
%   - central differences, spacing h
%   - next to the obstacle the difference switches to one-sided, so the
%     density stored inside the obstacle never enters the gradient
%   - |u| < velocityEpsilon : direction undefined -> value set to 0
%   - inside the obstacle the value is 0 (it is hidden by the black patch)

function G = normalDensityGradient(R,U,V,obstacle,h,velocityEpsilon)

    Nx = size(R,1);
    Ny = size(R,2);

    ii = 4:Nx-3;
    jj = 4:Ny-3;

    Rc = R(ii,jj);

    Rl = R(ii-1,jj);   Ol = obstacle(ii-1,jj);
    Rr = R(ii+1,jj);   Or = obstacle(ii+1,jj);
    Rd = R(ii,jj-1);   Od = obstacle(ii,jj-1);
    Ru = R(ii,jj+1);   Ou = obstacle(ii,jj+1);

    % Obstacle neighbour -> use the centre value (one-sided difference)
    Rl(Ol) = Rc(Ol);
    Rr(Or) = Rc(Or);
    Rd(Od) = Rc(Od);
    Ru(Ou) = Rc(Ou);

    denX = max(2 - double(Ol) - double(Or),1);
    denY = max(2 - double(Od) - double(Ou),1);

    dRdx = (Rr - Rl)./(denX*h);
    dRdy = (Ru - Rd)./(denY*h);

    Uc = U(ii,jj);
    Vc = V(ii,jj);

    speed = sqrt(Uc.^2 + Vc.^2);

    G = (dRdx.*Uc + dRdy.*Vc)./max(speed,eps);

    G(speed < velocityEpsilon)  = 0;
    G(obstacle(ii,jj))          = 0;
    G(~isfinite(G))             = 0;

end


%% =========================================================
% FUNCTION: WRITE A FIELD ANIMATION (AVI)  - density or gradient
% ==========================================================
%
% fieldFcn(k) returns the interior field (Nx-6) x (Ny-6) of frame k
% (cells 4:N-3 = 100 x 50 cells, 0 ... 100 m x 0 ... 50 m).
% videoSettings.symmetric = true  -> colour scale [-lim, +lim]
%                         = false -> colour scale [0, lim]

function writeFieldVideo(videoSettings,fieldFcn,t,Nx,Ny,len,F,h)

    % ---------------------------------------------------------
    % 1. VIDEO SETTINGS
    % ---------------------------------------------------------

    videoFile  = videoSettings.file;
    frameStep  = videoSettings.frameStep;
    fps        = videoSettings.fps;
    colorLimit = videoSettings.colorLimit;
    nLevels    = videoSettings.levels;
    upsample   = videoSettings.upsample;
    figSize    = videoSettings.figureSize;

    if videoSettings.symmetric
        colorRange = [-colorLimit colorLimit];
    else
        colorRange = [0 colorLimit];
    end

    if strcmpi(videoSettings.colormap,'bwr')
        cmap = bwrColormap(256);
    else
        cmap = feval(videoSettings.colormap,256);
    end

    % Ensure valid frame dimensions
    targetWidth  = round(figSize(1));
    targetHeight = round(figSize(2));

    % Even dimensions are preferable for video encoding
    targetWidth  = 2*ceil(targetWidth/2);
    targetHeight = 2*ceil(targetHeight/2);

    % ---------------------------------------------------------
    % 2. GRID AND OBSTACLE GEOMETRY
    % ---------------------------------------------------------

    P = videoSettings.P;

    P1 = P(1);
    P2 = P(2);
    P3 = P(3);
    P4 = P(4);

    % Interior grid coordinates (cell-centred)
    x = ((0:Nx-7)+0.5)*h;
    y = ((0:Ny-7)+0.5)*h;

    % Physical obstacle boundaries
    xObstacle1 = (P1-4)*h;
    xObstacle2 = (P3-3)*h;

    yObstacle1 = (P2-4)*h;
    yObstacle2 = (P4-3)*h;

    % Fine grid for contour interpolation
    xFine = linspace(x(1),x(end), ...
        (length(x)-1)*upsample+1);

    yFine = linspace(y(1),y(end), ...
        (length(y)-1)*upsample+1);

    [XFine,YFine] = meshgrid(xFine,yFine);

    % ---------------------------------------------------------
    % 3. INITIALISE VIDEO
    % ---------------------------------------------------------

    video = VideoWriter(videoFile,'Motion JPEG AVI');

    video.FrameRate = fps;
    video.Quality = 95;

    open(video);

    figureAnimation = figure( ...
        'Visible','off', ...
        'Color','w', ...
        'Units','pixels', ...
        'Position',[100 100 targetWidth targetHeight], ...
        'Resize','off', ...
        'MenuBar','none', ...
        'ToolBar','none');

    ax = axes('Parent',figureAnimation);

    set(ax, ...
        'FontName','Times New Roman', ...
        'FontSize',12, ...
        'LineWidth',1);

    fixedFrameSize = [targetHeight targetWidth 3];

    peakValue = 0;

    % ---------------------------------------------------------
    % 4. WRITE FRAMES
    % ---------------------------------------------------------

    try

        frameIndices = 1:frameStep:length(t);

        for n = 1:length(frameIndices)

            k = frameIndices(n);

            % Interior field of this frame
            fieldK = fieldFcn(k);

            peakValue = max(peakValue,max(abs(fieldK(:))));

            % Convert to y-by-x orientation for contourf
            fieldK = fieldK';

            % Upsample field
            fieldFine = interp2(x,y,fieldK,XFine,YFine,'linear');

            % Plot field
            cla(ax);

            contourf(ax,XFine,YFine,fieldFine, ...
                nLevels,'LineColor','none');

            hold(ax,'on');

            % Fixed colour scale
            clim(ax,colorRange);

            % Draw obstacle in black
            patch(ax, ...
                [xObstacle1 xObstacle2 xObstacle2 xObstacle1], ...
                [yObstacle1 yObstacle1 yObstacle2 yObstacle2], ...
                'k', ...
                'EdgeColor','k');

            hold(ax,'off');

            % Axis formatting
            xlim(ax,[0 100]);
            ylim(ax,[0 50]);

            axis(ax,'equal');
            box(ax,'on');

            xlabel(ax,'$x\,(\mathrm{m})$');
            ylabel(ax,'$y\,(\mathrm{m})$');

            title(ax,sprintf( ...
                '$L_x=L_y=%d\\,\\mathrm{m},\\quad F=%.2f\\,\\mathrm{pedestrians/m/s},\\quad t=%.3f\\,\\mathrm{s}$', ...
                len,F,t(k)), ...
                'Interpreter','latex');

            colormap(ax,cmap);

            cb = colorbar(ax);
            cb.Label.String = videoSettings.colorbarLabel;
            cb.Label.Interpreter = 'latex';

            drawnow;

            % -------------------------------------------------
            % 5. CAPTURE AND NORMALISE FRAME DIMENSIONS
            % -------------------------------------------------

            frame = getframe(figureAnimation);

            frameData = frame.cdata;

            % Resize every frame to the SAME fixed dimensions.
            % This avoids VideoWriter dimension mismatch errors.
            if size(frameData,1) ~= targetHeight || ...
               size(frameData,2) ~= targetWidth

                frameData = resizeRGBFrame( ...
                    frameData,targetHeight,targetWidth);

            end

            % Final dimension verification
            if ~isequal(size(frameData),fixedFrameSize)

                frameData = resizeRGBFrame( ...
                    frameData,targetHeight,targetWidth);

            end

            % Write frame
            writeVideo(video,frameData);

            if mod(n,50) == 0 || n == length(frameIndices)

                fprintf('    Animation: %d / %d frames written\n', ...
                    n,length(frameIndices));

            end

        end

        % Close video after successful completion
        close(video);

        fprintf('  Animation successfully saved: %s\n',videoFile);
        fprintf('  Peak |value| in this video: %.4g  (colour limit = %.4g)\n', ...
            peakValue,colorLimit);

    catch ME

        % Close video and figure if an error occurs
        try
            close(video);
        catch
        end

        if isvalid(figureAnimation)
            close(figureAnimation);
        end

        rethrow(ME);

    end

    % ---------------------------------------------------------
    % 6. CLEANUP
    % ---------------------------------------------------------

    if isvalid(figureAnimation)
        close(figureAnimation);
    end

end


%% =========================================================
% FUNCTION: BLUE-WHITE-RED DIVERGING COLORMAP
% ==========================================================

function cmap = bwrColormap(n)

    half = floor(n/2);

    up   = linspace(0,1,half)';
    down = linspace(1,0,n-half)';

    cmap = [ up,   up,   ones(half,1);
             ones(n-half,1), down, down];

end


%% =========================================================
% FUNCTION: CUMULATIVE (RUNNING) TIME AVERAGE
% ==========================================================
%
%   Qavg(t) = 1/(t - t0) * integral_t0^t Q dt'      (trapezoidal rule,
%   non-uniform time steps). NaN before t0 (= tStart).

function xAvg = cumulativeAverage(t,x,tStart)

    t = t(:);
    x = x(:);

    xAvg = NaN(size(x));

    idx = find(t >= tStart);

    if numel(idx) < 2
        return;
    end

    tt = t(idx);
    xx = x(idx);

    integral_ = cumtrapz(tt,xx);

    xAvg(idx) = [xx(1); integral_(2:end)./(tt(2:end) - tt(1))];

end


%% =========================================================
% FUNCTION: CENTRED MOVING-WINDOW AVERAGE (NON-UNIFORM TIME STEPS)
% ==========================================================
%
% The signal is resampled to a uniform grid, averaged over a window of
% windowSec seconds (the window shrinks at both ends of the record) and
% interpolated back to the original times.

function xAvg = movingAverage(t,x,windowSec)

    t = t(:);
    x = x(:);

    dtU = median(diff(t));

    tU = (t(1):dtU:t(end))';
    xU = interp1(t,x,tU,'linear');

    nW = max(1,round(windowSec/dtU));

    xM = movmean(xU,nW,'Endpoints','shrink');

    xAvg = interp1(tU,xM,t,'linear');

end


%% =========================================================
% HELPER FUNCTION: RESIZE RGB FRAME WITHOUT IMRESIZE
% ==========================================================

function outputFrame = resizeRGBFrame(inputFrame,newHeight,newWidth)

    inputFrame = uint8(inputFrame);

    oldHeight = size(inputFrame,1);
    oldWidth  = size(inputFrame,2);

    % Original and target pixel coordinates
    xOld = 1:oldWidth;
    yOld = 1:oldHeight;

    xNew = linspace(1,oldWidth,newWidth);
    yNew = linspace(1,oldHeight,newHeight);

    [XNew,YNew] = meshgrid(xNew,yNew);

    outputFrame = zeros(newHeight,newWidth,3,'uint8');

    % Interpolate each RGB channel independently
    for channel = 1:3

        channelData = double(inputFrame(:,:,channel));

        resizedChannel = interp2( ...
            xOld,yOld,channelData, ...
            XNew,YNew,'linear');

        outputFrame(:,:,channel) = uint8( ...
            min(255,max(0,round(resizedChannel))));

    end

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