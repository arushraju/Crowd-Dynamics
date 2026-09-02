clc;
clear;
close all;

% Category 1
x1 = [4, 4.5, 5];
y1 = [241.795, 127.14, 110.63];

% Category 2
x2 = [3.5, 4.0, 4.5, 5];
y2 = [277.07, 177.90, 128.99, 98.99];

% Category 3
x3 = [2.5, 3.0, 3.5, 4.0, 4.5, 5];
y3 = [283.49, 177.24, 135.24, 107.99, 87.25, 69.75];

% Category 4
x4 = [1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0];
y4 = [246.75, 161.75, 123.50, 105.50, 89, 75.25, 63.50, 50.50];

% Plot
figure;
hold on;
grid on;
box on;

plot(x1, y1, '-o', 'LineWidth', 1.5, 'MarkerSize', 7);
plot(x2, y2, '-s', 'LineWidth', 1.5, 'MarkerSize', 7);
plot(x3, y3, '-^', 'LineWidth', 1.5, 'MarkerSize', 7);
plot(x4, y4, '-d', 'LineWidth', 1.5, 'MarkerSize', 7);


ylim([0 300])
xlim([1.4 5.1])

xlabel('Inflow Flux (ped/m.s)');
ylabel('Time of Chocking (s)');
title('Time of Chocking VS Inflow Flux (for L = 10,20,30,40m)');

legend('L = 20m', 'L = 30m', 'L = 40m', 'L = 50m','Location', 'best');

hold off;