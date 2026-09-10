clc;
clear;
close all;

%% ============================================================
%  File names
%  ============================================================
paperFile  = 'Density_At_33_Paper_Result.csv';
solverFile = 'Density_at_120.xlsx';


%% ============================================================
%  1. Read paper result
% =============================================================

paperData = readtable(paperFile);

% Column names in the CSV are:
% x   rho

x_paper   = paperData.x;
rho_paper = paperData.rho;


%% ============================================================
%  2. Read solver density data
% =============================================================

solverData = readmatrix(solverFile);

% Solver data should be:
% 50 rows x 100 columns

fprintf('Solver matrix size: %d rows x %d columns\n', ...
    size(solverData,1), size(solverData,2));


%% ============================================================
%  3. Extract rows 34 and 35
%
%     Because this is a staggered grid, the physical y = 33
%     lies between these two rows.
% =============================================================

rho_34 = solverData(34, :);
rho_35 = solverData(35, :);


%% ============================================================
%  4. Average the two staggered-grid values
% =============================================================

% rho_y33 = (rho_34 + rho_35) / 2;
rho_y33 = (rho_34 + rho_35) / 2;

%% ============================================================
%  5. x coordinates for solver
%
%     There are 100 columns corresponding to x = 1,...,100
% =============================================================

x_solver = 1:100;


%% ============================================================
%  6. Plot paper result and solver result together
% =============================================================

figure('Color','w');

plot(x_paper, rho_paper, ...
    'o', ...
    'LineWidth', 1.5);

hold on;

plot(x_solver, rho_y33, ...
    'r-', ...
    'LineWidth', 1.5);

hold off;


%% ============================================================
%  7. Plot formatting
% =============================================================

xlabel('x');
ylabel('Density');

title('Density at y = 33');

legend( ...
    'Paper result', ...
    'Solver result: average of rows 34 and 35', ...
    'Location', 'best');

xlim([0 100]);

grid on;
box on;

set(gca, 'FontSize', 12);


%% ============================================================
%  8. Display some information in Command Window
% =============================================================

fprintf('\nPaper data points  : %d\n', length(x_paper));
fprintf('Solver x points    : %d\n', length(x_solver));
fprintf('Averaged rows      : 34 and 35\n');
fprintf('Solver x range     : %d to %d\n', ...
    x_solver(1), x_solver(end));