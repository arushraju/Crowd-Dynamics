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
%   - Plain strings  '...'              -> SINGLE backslash  (\rho, \,)
%   - Inside sprintf(...) / compose(...) -> DOUBLE backslash  (\\rho, \\,)
% ---------------------------------------------------------

%% ---------------------------------------------------------
% 1. GENERAL PARAMETERS
% ----------------------------------------------------------

folderNames = {'D_2','D_3','D_4','D_5'};
doorLengths = [2 3 4 5];

F_values = 0.5:0.5:9.5;

Nx = 67;
Ny = 67;

% Grid spacing
dx = 15/61;
dy = 15/61;

% Capture frequency for animation
videoFPS = 10;

% Density thresholds for congestion
congestionThresholds = [5 8 9.9];

% Initial density values to display in selected plots
plotF_values = [1 3 5 7 9];
[~,plotF_indices] = ismember(plotF_values,F_values);

% Choking criterion
chokingThreshold = 10;

% Evacuation criterion
evacuationTolerance = 1e-6;

% X-velocity column used for door flux
fluxColumn = 34;

% Door indices
P_values = [
    12 20 47 55;   % Ly = 2 m
    10 22 45 57;   % Ly = 3 m
     8 24 43 59;   % Ly = 4 m
     6 26 41 61    % Ly = 5 m
];

% Colors for the 19 initial density cases
colors = lines(length(F_values));

% Main results folder
mainResultsFolder = fullfile(pwd,'Results');

if ~exist(mainResultsFolder,'dir')
    mkdir(mainResultsFolder);
end

% Storage for comparison between door lengths
ChokingTimes = NaN(length(doorLengths),length(F_values));
EvacuationTimes = NaN(length(doorLengths),length(F_values));


%% ---------------------------------------------------------
% 2. LOOP OVER ALL FOUR DOOR CONFIGURATIONS
% ----------------------------------------------------------

for l = 1:length(doorLengths)

    L = doorLengths(l);
    inputFolder = folderNames{l};

    fprintf('\n');
    fprintf('============================================\n');
    fprintf('PROCESSING DOOR LENGTH: %.2f m\n',L);
    fprintf('============================================\n');

    % -----------------------------------------------------
    % Create output folders
    % -----------------------------------------------------

    resultFolder = fullfile(mainResultsFolder, ...
        sprintf('result_%d',l));

    animationFolder = fullfile(resultFolder,'Animations');
    populationFolder = fullfile(resultFolder,'Population');
    congestionFolder = fullfile(resultFolder,'Congestion');
    flowFolder = fullfile(resultFolder,'Door_Flow');
    dataFolder = fullfile(resultFolder,'Data');

    outputFolders = {
        resultFolder
        animationFolder
        populationFolder
        congestionFolder
        flowFolder
        dataFolder
    };

    for k = 1:length(outputFolders)

        if ~exist(outputFolders{k},'dir')
            mkdir(outputFolders{k});
        end

    end

    % -----------------------------------------------------
    % Door coordinates
    % -----------------------------------------------------

    P1 = P_values(l,1);
    P2 = P_values(l,2);
    P3 = P_values(l,3);
    P4 = P_values(l,4);

    % Based on the obstacle definition:
    %
    % obstacle(1:P1,33:34) = true;
    % obstacle(P2:P3,33:34) = true;
    % obstacle(P4:Ny,33:34) = true;
    %
    % Therefore, the open rows are:

    Door1_rows = (P1+1):(P2-1);
    Door2_rows = (P3+1):(P4-1);

    % -----------------------------------------------------
    % Storage for all 19 initial density cases
    % -----------------------------------------------------

    Time_values = cell(length(F_values),1);
    TotalPopulation = cell(length(F_values),1);

    CongestionArea = cell( ...
        length(congestionThresholds),length(F_values));

    Q_Door1 = cell(length(F_values),1);
    Q_Door2 = cell(length(F_values),1);

    MaximumDensity = cell(length(F_values),1);


    %% =====================================================
    % 3. LOOP OVER INITIAL DENSITY rho_initial
    % ======================================================

    for f = 1:length(F_values)

        F = F_values(f);

        fprintf('\nProcessing Ly = %.2f, rho_initial = %.2f\n',L,F);

        % -------------------------------------------------
        % File names
        % -------------------------------------------------
        % Keep the original input-file naming convention so
        % that the script reads the existing solver outputs.

        densityAFile = fullfile(inputFolder, ...
            sprintf('Density_A_Contour_L_%.2f_F_%.2f.csv',L-1,F));

        densityBFile = fullfile(inputFolder, ...
            sprintf('Density_B_Contour_L_%.2f_F_%.2f.csv',L-1,F));

        xVelocityAFile = fullfile(inputFolder, ...
            sprintf('X_Velocity_A_Contour_L_%.2f_F_%.2f.csv',L-1,F));

        % -------------------------------------------------
        % Check files
        % -------------------------------------------------

        if ~isfile(densityAFile)
            error('Missing file: %s',densityAFile);
        end

        if ~isfile(densityBFile)
            error('Missing file: %s',densityBFile);
        end

        if ~isfile(xVelocityAFile)
            error('Missing file: %s',xVelocityAFile);
        end

        % -------------------------------------------------
        % Read CSV files
        % -------------------------------------------------

        [timeA,DensityAFrames] = readCSVFrames( ...
            densityAFile,Ny,Nx);

        [timeB,DensityBFrames] = readCSVFrames( ...
            densityBFile,Ny,Nx);

        [timeVelocity,XVelocityAFrames] = readCSVFrames( ...
            xVelocityAFile,Ny,Nx);

        % -------------------------------------------------
        % Check time consistency within this simulation
        % -------------------------------------------------

        if length(timeA) ~= length(timeB) || ...
                length(timeA) ~= length(timeVelocity)

            error('Different frame counts for Ly=%.2f, rho_initial=%.2f',L,F);

        end

        if any(abs(timeA-timeB) > 1e-9) || ...
                any(abs(timeA-timeVelocity) > 1e-9)

            error('Time values do not match between files for Ly=%.2f, rho_initial=%.2f',L,F);

        end

        numberOfFrames = length(timeA);

        % -------------------------------------------------
        % Allocate storage
        % -------------------------------------------------

        population = zeros(numberOfFrames,1);
        maximumDensity = zeros(numberOfFrames,1);

        congestionAreaCurrent = zeros( ...
            length(congestionThresholds),numberOfFrames);

        flowDoor1 = zeros(numberOfFrames,1);
        flowDoor2 = zeros(numberOfFrames,1);

        % Successfully processed frames
        processedFrames = 0;

        % Current simulation choking information
        simulationChoked = false;
        chokingTime = NaN;

        % -------------------------------------------------
        % Create density animation
        % -------------------------------------------------

        videoFile = fullfile(animationFolder, ...
            sprintf('Total_Density_Ly_%.2f_rho_initial_%.2f.avi',L,F));

        video = VideoWriter(videoFile,'Motion JPEG AVI');
        video.FrameRate = videoFPS;
        video.Quality = 90;

        open(video);

        figureAnimation = figure( ...
            'Visible','off', ...
            'Color','w', ...
            'Position',[100 100 800 650]);


        % -------------------------------------------------
        % Process every time frame
        % -------------------------------------------------

        for t = 1:numberOfFrames

            Density_A = DensityAFrames(:,:,t);
            Density_B = DensityBFrames(:,:,t);

            XVelocity_A = XVelocityAFrames(:,:,t);

            % Total density
            Density_Total = Density_A + Density_B;

            % Interior region
            Density_Interior = Density_Total( ...
                4:Ny-3,4:Nx-3);

            % ------------------------------------------------
            % CHOKING CONDITION
            % ------------------------------------------------

            if any(Density_Interior(:) > chokingThreshold)

                simulationChoked = true;
                chokingTime = timeA(t);

                fprintf('\n');
                fprintf('============================================\n');
                fprintf('SIMULATION CHOKED\n');
                fprintf('============================================\n');

                fprintf('Door length Ly: %.2f m\n',L);
                fprintf('Initial density rho_initial: %.2f\n',F);
                fprintf('Choking time: %.6f s\n',chokingTime);

                fprintf('Maximum density: %.12g\n', ...
                    max(Density_Interior(:)));

                fprintf('Processed frames before choking: %d\n', ...
                    processedFrames);

                fprintf('Moving to the next simulation...\n');

                break;

            end

            % ------------------------------------------------
            % A. TOTAL POPULATION
            % ------------------------------------------------

            population(t) = sum(Density_Interior(:))*dx*dy;

            % ------------------------------------------------
            % B. MAXIMUM DENSITY
            % ------------------------------------------------

            maximumDensity(t) = max(Density_Interior(:));

            % ------------------------------------------------
            % C. AREA OF CONGESTION
            % ------------------------------------------------

            for c = 1:length(congestionThresholds)

                threshold = congestionThresholds(c);

                numberOfCongestedCells = ...
                    sum(Density_Interior(:) >= threshold);

                congestionAreaCurrent(c,t) = ...
                    numberOfCongestedCells*dx*dy;

            end

            % ------------------------------------------------
            % D. CROWD A FLOW THROUGH BOTH DOORS
            % ------------------------------------------------
            %
            % Q_A = sum(rho_A * u_A) * dy
            % Signed flow is retained.

            flowDoor1(t) = sum( ...
                Density_A(Door1_rows,fluxColumn) .* ...
                XVelocity_A(Door1_rows,fluxColumn)) * dy;

            flowDoor2(t) = sum( ...
                Density_A(Door2_rows,fluxColumn) .* ...
                XVelocity_A(Door2_rows,fluxColumn)) * dy;

            % ------------------------------------------------
            % E. TOTAL DENSITY ANIMATION
            % ------------------------------------------------

            figure(figureAnimation);
            clf;

            contourf(Density_Interior,20, ...
                'LineColor','none');

            % Jet colormap: dark blue through red
            colormap(figureAnimation,jet(256));

            clim([0 10]);   % use caxis([0 10]) on MATLAB older than R2022a

            % Axis labels (plain strings -> single backslash)
            xlabel('$x\,(\mathrm{m})$', ...
                'Interpreter','latex', ...
                'FontSize',13);

            ylabel('$y\,(\mathrm{m})$', ...
                'Interpreter','latex', ...
                'FontSize',13);

            % Title (inside sprintf -> double backslash)
            title(sprintf([ ...
                '$\\mathrm{TOTAL\\ DENSITY}$ - ' ...
                '$L_y=%.2f\\,\\mathrm{m}$ - ' ...
                '$\\rho_{\\mathrm{initial}}=%.2f\\,\\mathrm{pedestrians/m^2}$ - ' ...
                '$t=%.3f\\,\\mathrm{s}$'], ...
                L,F,timeA(t)), ...
                'Interpreter','latex', ...
                'FontSize',13);

            % Axis formatting
            axis equal tight;

            set(gca, ...
                'FontName','Times New Roman', ...
                'FontSize',12, ...
                'LineWidth',1.0, ...
                'TickLabelInterpreter','latex');

            % Colorbar formatting
            cb = colorbar;

            cb.Label.String = '$\rho_{\mathrm{total}}\,(\mathrm{pedestrians/m^2})$';
            cb.Label.Interpreter = 'latex';
            cb.Label.FontSize = 12;

            cb.TickLabelInterpreter = 'latex';
            cb.FontName = 'Times New Roman';

            frame = getframe(figureAnimation);
            writeVideo(video,frame);

            % Mark this frame as successfully processed
            processedFrames = t;

        end

        % -------------------------------------------------
        % Close video and animation figure
        % -------------------------------------------------

        close(video);
        close(figureAnimation);

        % -------------------------------------------------
        % Retain only successfully processed frames
        % -------------------------------------------------

        timeA = timeA(1:processedFrames);
        population = population(1:processedFrames);
        maximumDensity = maximumDensity(1:processedFrames);

        congestionAreaCurrent = ...
            congestionAreaCurrent(:,1:processedFrames);

        flowDoor1 = flowDoor1(1:processedFrames);
        flowDoor2 = flowDoor2(1:processedFrames);

        % -------------------------------------------------
        % Store results
        % -------------------------------------------------

        Time_values{f} = timeA;
        TotalPopulation{f} = population;
        MaximumDensity{f} = maximumDensity;

        Q_Door1{f} = flowDoor1;
        Q_Door2{f} = flowDoor2;

        for c = 1:length(congestionThresholds)

            CongestionArea{c,f} = ...
                congestionAreaCurrent(c,:)';

        end


        %% ================================================
        % 4. CHOKING TIME
        % ================================================

        if simulationChoked
            ChokingTimes(l,f) = chokingTime;
        else
            ChokingTimes(l,f) = NaN;
        end


        %% ================================================
        % 5. TOTAL EVACUATION TIME
        % ================================================

        if ~isempty(population)

            initialPopulation = population(1);

            evacuationThreshold = ...
                evacuationTolerance*initialPopulation;

            evacuationIndex = find( ...
                population <= evacuationThreshold,1,'first');

            if ~isempty(evacuationIndex)
                evacuationTime = timeA(evacuationIndex);
            else
                evacuationTime = NaN;
            end

        else
            evacuationTime = NaN;
        end

        EvacuationTimes(l,f) = evacuationTime;


        %% ================================================
        % 6. SAVE INDIVIDUAL SIMULATION DATA
        % ================================================

        simulationTable = table( ...
            timeA(:), ...
            population(:), ...
            maximumDensity(:), ...
            congestionAreaCurrent(1,:)', ...
            congestionAreaCurrent(2,:)', ...
            congestionAreaCurrent(3,:)', ...
            flowDoor1(:), ...
            flowDoor2(:), ...
            'VariableNames',{ ...
            'Time_s', ...
            'TotalPopulation_pedestrians', ...
            'MaximumDensity_pedestrians_m2', ...
            'Area_rho5_m2', ...
            'Area_rho8_m2', ...
            'Area_rho9_9_m2', ...
            'Door1_FlowA_pedestrians_s', ...
            'Door2_FlowA_pedestrians_s'});

        simulationCSV = fullfile(dataFolder, ...
            sprintf('Results_Ly_%.2f_rho_initial_%.2f.csv',L,F));

        writetable(simulationTable,simulationCSV);

        fprintf('\nCompleted rho_initial = %.2f\n',F);
        fprintf('Successfully processed frames: %d / %d\n', ...
            processedFrames,numberOfFrames);

        if simulationChoked
            fprintf('Status: CHOKED at %.6f s\n',chokingTime);
        else
            fprintf('Status: NOT CHOKED\n');
        end

    end


    %% =====================================================
    % 7. TOTAL POPULATION VS TIME
    % ======================================================

    figurePopulation = figure('Color','w');
    hold on;
    grid on;
    box on;

    populationLegend = {};

    for k = 1:length(plotF_indices)

        f = plotF_indices(k);

        if ~isempty(Time_values{f})

            plot(Time_values{f},TotalPopulation{f}, ...
                'Color',colors(f,:), ...
                'LineWidth',1.4);

            populationLegend{end+1} = sprintf( ...
                '$\\rho_{\\mathrm{initial}}=%.1f$',F_values(f)); %#ok<SAGROW>

        end

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$N_{\mathrm{total}}\,(\mathrm{pedestrians})$');

    title(sprintf( ...
        '$\\mathrm{TOTAL\\ POPULATION\\ vs\\ TIME}$ - $L_y=%.2f\\,\\mathrm{m}$',L), ...
        'Interpreter','latex');

    if ~isempty(populationLegend)
        legend(populationLegend, ...
            'Location','eastoutside', ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    saveas(figurePopulation,fullfile(populationFolder, ...
        sprintf('Total_Population_Ly_%.2f.png',L)));

    close(figurePopulation);


    %% =====================================================
    % 8. CONGESTION AREA VS TIME
    % ======================================================

    for c = 1:length(congestionThresholds)

        threshold = congestionThresholds(c);

        figureCongestion = figure('Color','w');
        hold on;
        grid on;
        box on;

        congestionLegend = {};

        for k = 1:length(plotF_indices)

            f = plotF_indices(k);

            if ~isempty(Time_values{f})

                plot(Time_values{f},CongestionArea{c,f}, ...
                    'Color',colors(f,:), ...
                    'LineWidth',1.4);

                congestionLegend{end+1} = sprintf( ...
                    '$\\rho_{\\mathrm{initial}}=%.1f$',F_values(f)); %#ok<SAGROW>

            end

        end

        xlabel('$t\,(\mathrm{s})$');
        ylabel('$A_{\mathrm{congestion}}\,(\mathrm{m}^2)$');

        xlim([0 6]);

        title(sprintf([ ...
            '$\\mathrm{CONGESTION\\ AREA\\ vs\\ TIME}$ - ' ...
            '$\\rho\\geq %.1f\\,\\mathrm{pedestrians/m^2}$ - ' ...
            '$L_y=%.2f\\,\\mathrm{m}$'], ...
            threshold,L), ...
            'Interpreter','latex');

        if ~isempty(congestionLegend)
            legend(congestionLegend, ...
                'Location','eastoutside', ...
                'Interpreter','latex');
        end

        set(gca,'FontName','Times New Roman','FontSize',11);

        saveas(figureCongestion,fullfile(congestionFolder, ...
            sprintf('Congestion_Area_Rho_%.1f_Ly_%.2f.png', ...
            threshold,L)));

        close(figureCongestion);

    end


    %% =====================================================
    % 9. CROWD A FLOW THROUGH BOTH DOORS
    % ======================================================

    figureFlow = figure('Color','w');
    hold on;
    grid on;
    box on;

    flowLegend = {};

    for k = 1:length(plotF_indices)

        f = plotF_indices(k);
        F = F_values(f);

        if ~isempty(Time_values{f})

            % Door 1: solid line
            plot(Time_values{f},Q_Door1{f}, ...
                'Color',colors(f,:), ...
                'LineStyle','-', ...
                'LineWidth',1.4);

            flowLegend{end+1} = sprintf( ...
                '$\\mathrm{Door\\ 1},\\ \\rho_{\\mathrm{initial}}=%.2f$',F); %#ok<SAGROW>

            % Door 2: dashed line
            plot(Time_values{f},Q_Door2{f}, ...
                'Color',colors(f,:), ...
                'LineStyle','--', ...
                'LineWidth',1.4);

            flowLegend{end+1} = sprintf( ...
                '$\\mathrm{Door\\ 2},\\ \\rho_{\\mathrm{initial}}=%.2f$',F); %#ok<SAGROW>

        end

    end

    xlabel('$t\,(\mathrm{s})$');
    ylabel('$Q_A\,(\mathrm{pedestrians/s})$');

    title(sprintf( ...
        '$\\mathrm{CROWD\\ A\\ FLOW\\ RATE}$ - $L_y=%.2f\\,\\mathrm{m}$',L), ...
        'Interpreter','latex');

    if ~isempty(flowLegend)
        legend(flowLegend, ...
            'Location','eastoutside', ...
            'FontSize',7, ...
            'Interpreter','latex');
    end

    set(gca,'FontName','Times New Roman','FontSize',11);

    saveas(figureFlow,fullfile(flowFolder, ...
        sprintf('Crowd_A_Door_Flow_Ly_%.2f.png',L)));

    close(figureFlow);


    %% =====================================================
    % 10. SAVE CHOKING AND EVACUATION DATA FOR THIS Ly
    % ======================================================

    chokingTable = table( ...
        F_values(:), ...
        ChokingTimes(l,:)', ...
        'VariableNames',{'rho_initial','ChokingTime_s'});

    writetable(chokingTable,fullfile(resultFolder, ...
        'Choking_Times.csv'));

    evacuationTable = table( ...
        F_values(:), ...
        EvacuationTimes(l,:)', ...
        'VariableNames',{'rho_initial','EvacuationTime_s'});

    writetable(evacuationTable,fullfile(resultFolder, ...
        'Evacuation_Times.csv'));


    fprintf('\nFinished all analyses for Ly = %.2f m\n',L);

end


%% =========================================================
% 11. CHOKING TIME VS INITIAL DENSITY
% ==========================================================

figureChoking = figure('Color','w');
hold on;
grid on;
box on;

for l = 1:length(doorLengths)

    plot(F_values,ChokingTimes(l,:), ...
        '-o', ...
        'LineWidth',1.6, ...
        'MarkerSize',5);

end

xlabel('$\rho_{\mathrm{initial}}\,(\mathrm{pedestrians/m^2})$');
ylabel('$t_{\mathrm{choking}}\,(\mathrm{s})$');

title('$\mathrm{CHOKING\ TIME\ vs\ INITIAL\ DENSITY}$', ...
    'Interpreter','latex');

legend(compose('$L_y=%.0f\\,\\mathrm{m}$',doorLengths), ...
    'Location','best', ...
    'Interpreter','latex');

set(gca,'FontName','Times New Roman','FontSize',11);

saveas(figureChoking,fullfile(mainResultsFolder, ...
    'Choking_Time_Comparison.png'));

close(figureChoking);


%% =========================================================
% 12. TOTAL EVACUATION TIME VS INITIAL DENSITY
% ==========================================================

figureEvacuation = figure('Color','w');
hold on;
grid on;
box on;

for l = 1:length(doorLengths)

    plot(F_values,EvacuationTimes(l,:), ...
        '-o', ...
        'LineWidth',1.6, ...
        'MarkerSize',5);

end

xlabel('$\rho_{\mathrm{initial}}\,(\mathrm{pedestrians/m^2})$');
ylabel('$t_{\mathrm{evacuation}}\,(\mathrm{s})$');

title('$\mathrm{TOTAL\ EVACUATION\ TIME\ vs\ INITIAL\ DENSITY}$', ...
    'Interpreter','latex');

legend(compose('$L_y=%.0f\\,\\mathrm{m}$',doorLengths), ...
    'Location','best', ...
    'Interpreter','latex');

set(gca,'FontName','Times New Roman','FontSize',11);

saveas(figureEvacuation,fullfile(mainResultsFolder, ...
    'Evacuation_Time_Comparison.png'));

close(figureEvacuation);


%% =========================================================
% 13. SAVE COMPARISON DATA
% ==========================================================

chokingComparisonTable = array2table( ...
    [F_values(:),ChokingTimes'], ...
    'VariableNames',{ ...
    'rho_initial', ...
    'Ly_2m', ...
    'Ly_3m', ...
    'Ly_4m', ...
    'Ly_5m'});

writetable(chokingComparisonTable,fullfile(mainResultsFolder, ...
    'Choking_Time_Comparison.csv'));


evacuationComparisonTable = array2table( ...
    [F_values(:),EvacuationTimes'], ...
    'VariableNames',{ ...
    'rho_initial', ...
    'Ly_2m', ...
    'Ly_3m', ...
    'Ly_4m', ...
    'Ly_5m'});

writetable(evacuationComparisonTable,fullfile(mainResultsFolder, ...
    'Evacuation_Time_Comparison.csv'));


%% =========================================================
% 14. COMPLETION
% ==========================================================

fprintf('\n');
fprintf('=================================================\n');
fprintf('ALL POST-PROCESSING COMPLETED SUCCESSFULLY\n');
fprintf('=================================================\n');

fprintf('Results saved in: %s\n',mainResultsFolder);


%% =========================================================
% FUNCTION: READ CSV FRAMES
% ==========================================================

function [timeValues,frames] = readCSVFrames(filename,Ny,Nx)

    fid = fopen(filename,'r');

    if fid == -1
        error('Could not open file: %s',filename);
    end

    timeValues = [];
    frames = zeros(Ny,Nx,0);

    while ~feof(fid)

        % Read time line
        line = fgetl(fid);

        if ~ischar(line)
            break;
        end

        if isempty(strtrim(line))
            continue;
        end

        currentTime = str2double(strtrim(line));

        if isnan(currentTime)
            fclose(fid);
            error('Invalid time value in file: %s',filename);
        end

        % Read matrix
        currentFrame = zeros(Ny,Nx);

        for i = 1:Ny

            line = fgetl(fid);

            if ~ischar(line)
                fclose(fid);
                error('Incomplete frame in file: %s',filename);
            end

            values = str2double(strsplit(strtrim(line),','));

            if length(values) ~= Nx
                fclose(fid);
                error('Incorrect number of columns in file: %s',filename);
            end

            if any(isnan(values))
                fclose(fid);
                error('Invalid matrix values in file: %s',filename);
            end

            currentFrame(i,:) = values;

        end

        timeValues(end+1,1) = currentTime; %#ok<AGROW>
        frames(:,:,end+1) = currentFrame;  %#ok<AGROW>

    end

    fclose(fid);

end