% This will plot the chocking time and inflow flux
initial_density = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5];
% These are the time of chocking for each of them
door_1_choking = [NaN, NaN, 2.95, 1.91, 1.72, 1.48, 1.66, 1.97, 1.41, 1.54, 1.35, 1.84, 1.23, 1.11, 1.11, 1.41, 1.23, 1.05, 1.23];
door_2_choking = [NaN, NaN, NaN, 3.69, 2.15, 2.58, 1.66, 1.29, 1.23, 1.17, 0.92, 1.23, 1.11, 1.29, 1.29, 1.11, 1.05, 1.48, 1.29];
door_3_choking = [NaN, NaN, NaN, NaN, NaN, 2.58, 2.46, 1.48, 1.48, 1.04, 1.05, 0.98, 0.92, 1.29, 1.05, 0.92, 0.92, 0.80, 1.11];
door_4_choking = [NaN, NaN, NaN, NaN, NaN, 3.44, 2.83, 3.26, 1.11, 1.97, 1.04, 1.35, 0.86, 1.29, 0.98, 0.86, 1.11, 0.98, 1.11];

figure;
hold on;

plot(initial_density, door_1_choking, 'o-', 'DisplayName', 'D = 2m');
plot(initial_density, door_2_choking, 's-', 'DisplayName', 'D = 3m');
plot(initial_density, door_3_choking, '^-', 'DisplayName', 'D = 4m');
plot(initial_density, door_4_choking, 'd-', 'DisplayName', 'D = 5m');
title("Choking Time VS Initial Density for different Door Lenght", 'Interpreter', 'latex');
xlabel('$\rho$ (Initial Density)', 'Interpreter', 'latex');
ylabel('$t_{\mathrm{C}}$ (Choking Time)', 'Interpreter', 'latex');
legend('Location', 'best');
grid on;

hold off;
% Save the figure
saveas(gcf, "Choking_Time_vs_Initial_Density.png");

% --- Initialize Figure for Total Evacuation Time ---
fig_total_evac = figure;
hold on;
door_colors = lines(4);
density_markers = {'o', 's', '^', 'd', 'v'}; % Shapes for densities 0.5, 1.0, 1.5, 2.0, 2.5
densities_all = 0.5:0.5:2.5;

% Plot escaped pedestrians and their time derivatives for each door
for door = 1:4

    door_folder = sprintf("Door_%d", door);

    % Create separate figures for Escaped Pedestrians and their Derivatives
    fig_esc = figure;
    hold on;

    fig_deriv = figure;
    hold on;

    switch door
        case 1
            final_density = 1;
            max_d_idx = 2;
        case 2
            final_density = 1.5;
            max_d_idx = 3;
        case 3
            final_density = 2.5; % Updated final density to 2.5 for D = 4m (Door 3)[cite: 1]
            max_d_idx = 5;
        case 4
            final_density = 2.5;
            max_d_idx = 5;
    end

    densities = 0.5:0.5:final_density;
    density_colors = lines(numel(densities));
    
    door_evac_times = zeros(size(densities));

    for k = 1:numel(densities)

        escape_ped = densities(k);
        this_color = density_colors(k, :);

        % Crowd A data
        fileName_A = fullfile( ...
            door_folder, ...
            sprintf("Escaped_pedestrians_D_%.2f_rho_%.2f_Crowd_A.csv", door, escape_ped));
        data_A = readmatrix(fileName_A);

        time_A = data_A(:, 2);
        esc_ped_A = data_A(:, 1);

        % Crowd B data
        fileName_B = fullfile( ...
            door_folder, ...
            sprintf("Escaped_pedestrians_D_%.2f_rho_%.2f_Crowd_B.csv", door, escape_ped));
        data_B = readmatrix(fileName_B);

        time_B = data_B(:, 2);
        esc_ped_B = data_B(:, 1);

        % --- 1. Plot Escaped Pedestrians vs Time ---
        figure(fig_esc);
        plot(time_A, esc_ped_A, '-', ...
            'Color', this_color, ...
            'DisplayName', sprintf('\\rho = %.1f (Crowd A)', escape_ped));

        plot(time_B, -esc_ped_B, ':', ...
            'Color', this_color, ...
            'DisplayName', sprintf('\\rho = %.1f (Crowd B)', escape_ped));

        % --- 2. Calculate Derivatives (Escape Rates) ---
        rate_A = gradient(esc_ped_A, time_A);
        rate_B = gradient(esc_ped_B, time_B);

        % --- 3. Plot Derivatives vs Time ---
        figure(fig_deriv);
        plot(time_A, rate_A, '-', ...
            'Color', this_color, ...
            'DisplayName', sprintf('\\rho = %.1f (Crowd A)', escape_ped));

        plot(time_B, -rate_B, ':', ...
            'Color', this_color, ...
            'DisplayName', sprintf('\\rho = %.1f (Crowd B)', escape_ped));

        % --- 4. Calculate Total Evacuation Time for this density ---
        % Find time when rate becomes zero again (after peak)
        [~, peak_idx_A] = max(rate_A);
        post_peak_rates_A = rate_A(peak_idx_A:end);
        post_peak_times_A = time_A(peak_idx_A:end);
        zero_indices_A = find(abs(post_peak_rates_A) < 1e-2);
        if ~isempty(zero_indices_A)
            evac_time_A = post_peak_times_A(zero_indices_A(1));
        else
            evac_time_A = time_A(end);
        end

        [~, peak_idx_B] = max(rate_B);
        post_peak_rates_B = rate_B(peak_idx_B:end);
        post_peak_times_B = time_B(peak_idx_B:end);
        zero_indices_B = find(abs(post_peak_rates_B) < 1e-2);
        if ~isempty(zero_indices_B)
            evac_time_B = post_peak_times_B(zero_indices_B(1));
        else
            evac_time_B = time_B(end);
        end

        % Take maximum of both Crowd A and Crowd B completion times
        door_evac_times(k) = max(evac_time_A, evac_time_B);
    end

    % --- Format and Save Escaped Pedestrians Figure ---
    figure(fig_esc);
    xlabel('$t$ (Time)', 'Interpreter', 'latex');
    ylabel('No. of Escaped Pedestrians', 'Interpreter', 'latex');
    title(sprintf('No. of Escaped Pedestrians vs Time ( D = %dm )', door + 1), ...
        'Interpreter', 'latex');
    grid on;
    lgd_esc = legend('Location', 'eastoutside');
    lgd_esc.Interpreter = 'latex';
    hold off;
    
    plot_name_esc = sprintf('Ped_Esc_VS_Door_%d.png', door);
    saveas(fig_esc, plot_name_esc);

    % --- Format and Save Derivative Figure ---
    figure(fig_deriv);
    xlabel('$t$ (Time)', 'Interpreter', 'latex');
    ylabel('Derivative of Escaped Pedestrians (Flow Rate)', 'Interpreter', 'latex');
    title(sprintf('Derivative of Escaped Pedestrians vs Time ( D = %dm )', door + 1), ...
        'Interpreter', 'latex');
    grid on;
    lgd_deriv = legend('Location', 'eastoutside');
    lgd_deriv.Interpreter = 'latex';
    hold off;

    plot_name_deriv = sprintf('Ped_Esc_Derivative_VS_Door_%d.png', door);
    saveas(fig_deriv, plot_name_deriv);

    % --- Plot on Total Evacuation Time Figure ---
    figure(fig_total_evac);
    plot(densities, door_evac_times, '-', ...
        'Color', door_colors(door, :), ...
        'LineWidth', 1.5, ...
        'DisplayName', sprintf('D = %dm', door + 1));
    
    for k = 1:numel(densities)
        plot(densities(k), door_evac_times(k), density_markers{k}, ...
            'Color', door_colors(door, :), ...
            'MarkerFaceColor', door_colors(door, :), ...
            'HandleVisibility', 'off');
    end

end

% --- Format and Save Total Evacuation Time Figure ---
figure(fig_total_evac);
xlabel('$\rho$ (Initial Density)', 'Interpreter', 'latex');
ylabel('$t_{\mathrm{evac}}$ (Total Evacuation Time)', 'Interpreter', 'latex');
title('Total Evacuation Time vs Initial Density for Different Door Lengths', 'Interpreter', 'latex');
grid on;
lgd_tot = legend('Location', 'best');
lgd_tot.Interpreter = 'latex';
hold off;

saveas(fig_total_evac, 'Total_Evacuation_Time_vs_Initial_Density.png');