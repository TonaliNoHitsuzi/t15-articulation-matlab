%% main_t15_analysis.m -- T15 intracortical neural signal phoneme-feature classification (MATLAB)
%  Main pipeline, port of module1_articulation/full_analysis.py:
%    1. parse all sessions under hdf5_data_final -> phoneme segment features
%    2. classify {manner, place} for 8 region groups (4 arrays x {TC, power})
%    3. ECOC logistic regression + 3-fold trial-grouped CV -> OOF predictions
%    4. balanced accuracy + 1000x trial bootstrap 95% CI
%    5. figures (2 heatmaps + bar chart) and results saved to ../results/
%
%  Requirements:
%    - MATLAB R2019b+ (tested on R2021b)
%    - Statistics and Machine Learning Toolbox
%    - data: hdf5_data_final/ unzipped from Dryad t15_copyTask_neuralData.zip
%  Usage:
%    set SMOKE=true for a 2-session smoke run, then run this script.

clear; clc; close all;

SMOKE = false;                    % true = only first 2 sessions
METHOD = 'ecoc';                  % fitcecoc + fitclinear (L2 logistic, balanced)
HERE = fileparts(mfilename('fullpath'));
OUTDIR = fullfile(HERE, '..', 'results');
if ~exist(OUTDIR, 'dir'), mkdir(OUTDIR); end

%% 1. Data
% Data root resolution (order):
%   a) <project>/data/hdf5_data_final            (recommended)
%   b) config/data_root.txt (UTF-8, one line with the absolute path)
HDF5_ROOT = fullfile(HERE, '..', 'data', 'hdf5_data_final');
if exist(HDF5_ROOT, 'dir') ~= 7
    cfg = fullfile(HERE, '..', 'config', 'data_root.txt');
    if exist(cfg, 'file') == 2
        fid = fopen(cfg, 'r', 'n', 'UTF-8');
        HDF5_ROOT = strtrim(fgetl(fid));
        fclose(fid);
    end
end
if exist(HDF5_ROOT, 'dir') ~= 7
    error(['hdf5 data root not found. Put hdf5_data_final under ', ...
        '<project>/data/ or create config/data_root.txt (UTF-8) ', ...
        'pointing to it. Tried: %s'], HDF5_ROOT);
end

cacheFile = fullfile(OUTDIR, 'segments_cache.mat');
if exist(cacheFile, 'file')
    S = load(cacheFile);
    segs = S.segs; manner = S.manner; place = S.place; trialId = S.trialId;
    fprintf('[cache] loaded %d segments\n', size(segs, 1));
else
    if SMOKE
        [segs, manner, place, trialId] = load_t15_dataset(HDF5_ROOT, ...
            'MaxSessions', 2);
    else
        [segs, manner, place, trialId] = load_t15_dataset(HDF5_ROOT);
    end
    save(cacheFile, 'segs', 'manner', 'place', 'trialId', '-v7.3');
end

%% 2. Trial-grouped folds (mirrors Python make_folds: shuffle trials, i mod 3)
rng(0);
ut = unique(trialId);
ut = ut(randperm(numel(ut)));
foldMap = containers.Map(arrayfun(@num2str, ut, 'UniformOutput', false), ...
    num2cell(mod(0:numel(ut)-1, 3)));
fold = cellfun(@(t) foldMap(num2str(t)), num2cell(trialId));

%% 3. Classification: 8 region groups x {manner, place}
GROUPS = struct( ...
    'v6_TC',  {{1, 64}},   'a4_TC',  {{65, 128}}, ...
    '55b_TC', {{129,192}}, 'd6v_TC', {{193,256}}, ...
    'v6_pow', {{257,320}}, 'a4_pow', {{321,384}}, ...
    '55b_pow',{{385,448}}, 'd6v_pow',{{449,512}});
GNAME = fieldnames(GROUPS)';
MANNER_ORDER = {'VOWEL','STOP','FRICATIVE','AFFRICATE','NASAL','APPROXIMANT'};
PLACE_ORDER  = {'LABIAL','DENTAL_ALV','POSTALV_PAL','VELAR','GLOTTAL', ...
                'front','central','back'};

B = 1000;                         % bootstrap replicates
t0 = tic;
res = struct();
for gi = 1:numel(GNAME)
    g = GNAME{gi};
    idx = GROUPS.(g);
    Xg = segs(:, idx{1}:idx{2});
    ypM = fit_logreg_oof(Xg, manner, fold, METHOD);
    res.(g).manner = bootstrap_balacc_ci(manner, ypM, trialId, ...
        MANNER_ORDER, B, 1);
    ypP = fit_logreg_oof(Xg, place, fold, METHOD);
    res.(g).place = bootstrap_balacc_ci(place, ypP, trialId, ...
        PLACE_ORDER, B, 1);
    fprintf('[group] %-7s manner=%.3f [%.3f,%.3f]  place=%.3f [%.3f,%.3f] (%.0fs)\n', ...
        g, res.(g).manner.balacc, res.(g).manner.balacc_lo, res.(g).manner.balacc_hi, ...
        res.(g).place.balacc, res.(g).place.balacc_lo, res.(g).place.balacc_hi, toc(t0));
end

%% 4. Figures and results
plot_results(res, GNAME, MANNER_ORDER, PLACE_ORDER, OUTDIR);
summary = struct('n_segments', size(segs,1), 'n_trials', numel(ut), ...
    'classifier', METHOD, 'boot', B, 'created', string(datetime('now')), ...
    'res', res);
save(fullfile(OUTDIR, 'summary.mat'), 'summary', '-v7.3');
fid = fopen(fullfile(OUTDIR, 'summary.json'), 'w', 'n', 'UTF-8');
fwrite(fid, jsonencode(summary, 'PrettyPrint', true), 'char');
fclose(fid);

fprintf('\n[done] classifier=%s bootstrap=%d total %.0f s\nresults: %s\n', ...
    METHOD, B, toc(t0), OUTDIR);
disp(cellfun(@(g) sprintf('%-7s manner=%.3f place=%.3f', g, ...
    res.(g).manner.balacc, res.(g).place.balacc), GNAME, ...
    'UniformOutput', false))
