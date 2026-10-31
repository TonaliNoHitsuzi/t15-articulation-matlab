function plot_results(res, groups, mannerOrder, placeOrder, outdir)
%PLOT_RESULTS Figures: region x class heatmaps (x2) + grouped bar chart
%   Port of the Python draw_heatmap / draw_bars.
%   res.(group).manner / .place hold bootstrap_balacc_ci outputs.

%% Heatmaps (per-class balanced acc + 95% CI annotations)
plot_one_heatmap(res, groups, mannerOrder, 'manner', ...
    'Region-group x Manner (per-class bal-acc, 95% CI)', ...
    fullfile(outdir, 'heatmap_region_manner.png'));
plot_one_heatmap(res, groups, placeOrder, 'place', ...
    'Region-group x Place (per-class bal-acc, 95% CI)', ...
    fullfile(outdir, 'heatmap_region_place.png'));

%% Bar chart (8 groups, manner/place bal-acc with CI)
gm  = arrayfun(@(r) r.manner.balacc, res);
gmlo = arrayfun(@(r) r.manner.balacc - r.manner.balacc_lo, res);
gmhi = arrayfun(@(r) r.manner.balacc_hi - r.manner.balacc, res);
gp  = arrayfun(@(r) r.place.balacc, res);
gplo = arrayfun(@(r) r.place.balacc - r.place.balacc_lo, res);
gphi = arrayfun(@(r) r.place.balacc_hi - r.place.balacc, res);
gname = groups(:)';

f = figure('Position', [50 80 1000 460], 'Color', 'w');
hold on;
x = 1:numel(gname);  w = 0.38;
bar(x - w/2, gm, w, 'FaceColor', [0.2 0.5 0.4], 'EdgeColor', 'none');
bar(x + w/2, gp, w, 'FaceColor', [0.2 0.4 0.8], 'EdgeColor', 'none');
errorbar(x - w/2, gm, gmlo, gmhi, 'k', 'LineWidth', 0.8, 'CapSize', 4);
errorbar(x + w/2, gp, gplo, gphi, 'k', 'LineWidth', 0.8, 'CapSize', 4);
% chance reference lines, colour-matched to their bar groups:
% green dashed = manner chance (1/6), blue dotted = place chance (1/8)
yline(1/6, '--', 'Color', [0.05 0.40 0.28], 'LineWidth', 1.3, ...
    'HandleVisibility', 'off');
yline(1/8, ':',  'Color', [0.05 0.25 0.60], 'LineWidth', 1.5, ...
    'HandleVisibility', 'off');
text(numel(gname) + 0.55, 1/6 + 0.006, '1/6', 'Color', [0.05 0.40 0.28], ...
    'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
text(numel(gname) + 0.55, 1/8 + 0.006, '1/8', 'Color', [0.05 0.25 0.60], ...
    'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
xlim([0.4 numel(gname) + 0.6]);
ylim([0 0.5]);
xticks(x); xticklabels(gname); xtickangle(30);
ylabel('balanced accuracy');
legend({'manner (green dashed = chance 1/6)', ...
        'place (blue dotted = chance 1/8)'}, ...
    'Location', 'northeast', 'Color', [0.97 0.97 0.97], 'EdgeColor', [0.4 0.4 0.4]);
title('Region-group articulation decodability (95% CI, bootstrap over trials)');
exportgraphics(f, fullfile(outdir, 'bars_balacc_ci.png'), 'Resolution', 140);
end

function plot_one_heatmap(res, groups, classes, fieldname, ttl, path)
M = nan(numel(groups), numel(classes));
LO = M;  HI = M;
for i = 1:numel(groups)
    pc = res(i).(fieldname).per_class;
    for j = 1:numel(classes)
        s = pc.(matlab.lang.makeValidName(classes{j}));
        M(i,j) = s.acc;  LO(i,j) = s.lo;  HI(i,j) = s.hi;
    end
end
f = figure('Position', [60 60 340 + 130*numel(classes) 120 + 56*numel(groups)], ...
    'Color', 'w');
imagesc(M);
colormap(viridis_like());
caxis([0 1]); axis image;
set(gca, 'XAxisLocation', 'top', 'XTick', 1:numel(classes), ...
    'XTickLabel', classes, 'YTick', 1:numel(groups), 'YTickLabel', groups, ...
    'FontSize', 9);
for i = 1:numel(groups)
    for j = 1:numel(classes)
        v = M(i,j);
        if isnan(v), continue; end
        txt = sprintf('%.2f\n[%.2f,%.2f]', v, LO(i,j), HI(i,j));
        if v < 0.5
            tcolor = 'w';
        else
            tcolor = 'k';
        end
        text(j, i, txt, 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle', 'FontSize', 8, 'Color', tcolor, ...
            'Interpreter', 'none');
    end
end
cb = colorbar;
cb.Label.String = 'per-class balanced acc (95% CI)';
title(ttl);
exportgraphics(f, path, 'Resolution', 140);
end

function cmap = viridis_like()
% Fixed viridis-like colormap (dependency-free)
stops = [0.267 0.005 0.329; 0.283 0.141 0.458; 0.254 0.265 0.530; ...
         0.207 0.372 0.553; 0.164 0.471 0.558; 0.128 0.567 0.551; ...
         0.135 0.659 0.518; 0.267 0.749 0.441; 0.478 0.821 0.318; ...
         0.741 0.873 0.150; 0.993 0.906 0.144];
n = 256;
tq = linspace(1, size(stops,1), n);
cmap = interp1(1:size(stops,1), stops, tq, 'linear');
end
