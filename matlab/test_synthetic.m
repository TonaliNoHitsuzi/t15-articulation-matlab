% test_synthetic.m -- synthetic-data unit smoke test (no T15 data needed)
% Verifies articulation_table / fit_logreg_oof / bootstrap_balacc_ci /
% plot_results. Run: matlab -batch "run('test_synthetic.m')"
clear; clc;
here = fileparts(mfilename('fullpath'));
addpath(here);

%% 1. articulation_table
T = articulation_table();
assert(numel(T.phons) == 41, 'phons must have 41 entries');
nman = sum(~cellfun(@isempty, T.manner));
assert(nman == 39, 'expected 39 phonemes with features, got %d', nman);
assert(isempty(T.manner{1}) && isempty(T.manner{41}), 'BLANK/boundary empty');
fprintf('[test1] articulation_table OK (39/41 have features)\n');

%% 2. fit_logreg_oof (separable synthetic data, expect high accuracy)
rng(7);
n = 1200;  d = 32;
lab3 = {'a'; 'b'; 'c'};
yraw = lab3(randi(3, n, 1));
centers = [repmat(-1, 1, d); repmat(0, 1, d); repmat(1, 1, d)];
y = categorical(yraw);
X = centers(double(y), :) + 0.35 * randn(n, d);
tid = reshape(repmat(1:120, 10, 1), [], 1);          % 120 trials
ut = unique(tid); ut = ut(randperm(numel(ut)));
foldMap = containers.Map(arrayfun(@num2str, ut, 'UniformOutput', false), ...
    num2cell(mod(0:numel(ut)-1, 3)));
fold = cellfun(@(t) foldMap(num2str(t)), num2cell(tid));

yp = fit_logreg_oof(X, yraw, fold, 'ecoc');
acc = mean(string(yp) == string(yraw));
fprintf('[test2] ecoc: acc=%.3f\n', acc);
assert(acc > 0.85, 'ecoc accuracy too low: %.3f', acc);
fprintf('[test2] fit_logreg_oof OK\n');

%% 3. bootstrap_balacc_ci
classes = {'a', 'b', 'c'};
out = bootstrap_balacc_ci(yraw, cellstr(yp), tid, classes, 500, 1);
fprintf('[test3] balacc=%.3f CI=[%.3f, %.3f] chance=%.3f\n', ...
    out.balacc, out.balacc_lo, out.balacc_hi, out.chance);
assert(out.balacc_lo <= out.balacc + 1e-9 && out.balacc <= out.balacc_hi + 1e-9, ...
    'CI must cover the point estimate');
assert(abs(out.balacc - 1/3) > 0.05, 'separable data must beat chance');
assert(isfield(out.per_class, 'a') && isfield(out.per_class, 'b'), ...
    'per_class fields missing');
fprintf('[test3] bootstrap_balacc_ci OK\n');

%% 4. plot_results smoke (synthetic res)
GNAME = {'g1', 'g2'};
res = struct();
for g = GNAME
    r = struct('balacc', 0.3, 'balacc_lo', 0.27, 'balacc_hi', 0.33);
    r.per_class = struct('a', struct('acc', 0.3, 'lo', 0.27, 'hi', 0.33), ...
                         'b', struct('acc', 0.31, 'lo', 0.28, 'hi', 0.34));
    res.(g{1}).manner = r;
    r2 = r; r2.balacc = 0.25; r2.balacc_lo = 0.22; r2.balacc_hi = 0.28;
    res.(g{1}).place = r2;
end
outdir = tempdir;
plot_results(res, GNAME, {'a', 'b'}, {'a', 'b'}, outdir);
assert(exist(fullfile(outdir, 'bars_balacc_ci.png'), 'file') == 2, 'bar fig missing');
assert(exist(fullfile(outdir, 'heatmap_region_manner.png'), 'file') == 2, ...
    'heatmap missing');
fprintf('[test4] plot_results OK (figures written)\n');

fprintf('\n=== ALL UNIT TESTS PASSED ===\n');
