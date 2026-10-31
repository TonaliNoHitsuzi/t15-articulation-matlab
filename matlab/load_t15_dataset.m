function [segs, manner, place, trialId, meta] = load_t15_dataset(hdf5Root, varargin)
%LOAD_T15_DATASET Parse all T15 sessions' data_train.hdf5 into phoneme segments
%   [segs, manner, place, trialId] = load_t15_dataset(hdf5Root)
%   Line-by-line port of module1_articulation/full_analysis.py:
%     - each trial's input_features (Tx512) aligned with seq_class_ids/seq_len
%     - after dropping BLANK and ' | ', the time axis is split evenly
%       among the remaining phonemes
%     - segment feature = mean of the 512-dim features in that window
%   Name-value options:
%     'MaxSessions'  only first N sessions (smoke test)
%     'MaxTrials'    only first N trials per session (smoke test)
%     'MinFrames'    minimum frames per trial (default 20)
%   meta records session names and total trial count.

p = inputParser;
p.addParameter('MaxSessions', inf);
p.addParameter('MaxTrials', inf);
p.addParameter('MinFrames', 20);
p.parse(varargin{:});
opt = p.Results;

T = articulation_table();
phons = T.phons;

sessions = dir(hdf5Root);
sessions = sessions([sessions.isdir] & ~ismember({sessions.name}, {'.','..'}));
sessions = sort({sessions.name});
if numel(sessions) > opt.MaxSessions
    sessions = sessions(1:opt.MaxSessions);
end
fprintf('[data] %d sessions to load\n', numel(sessions));

segList = {};  manList = {};  plaList = {};  tidList = {};
meta = struct('sessions',{{}}, 'n_trials', 0);

for si = 1:numel(sessions)
    fp = fullfile(hdf5Root, sessions{si}, 'data_train.hdf5');
    if ~exist(fp, 'file')
        continue;
    end
    info = h5info(fp);
    keys = strrep({info.Groups.Name}, '/', '');   % trial group names
    if numel(keys) > opt.MaxTrials
        keys = keys(1:opt.MaxTrials);
    end
    nkept = 0;
    for ti = 1:numel(keys)
        gname = ['/' keys{ti}];
        try
            X   = h5read(fp, [gname '/input_features']);   % Tx512
            seq = h5read(fp, [gname '/seq_class_ids']);    % 1xLmax double
            L   = h5readatt(fp, gname, 'seq_len');
        catch
            continue;
        end
        seq = double(seq(:)).';
        L = double(L);
        nfrm = size(X, 1);
        if nfrm < opt.MinFrames
            continue;
        end
        ids = seq(1:L) + 1;                     % MATLAB 1-based index
        manCell = T.manner(ids);
        keepIdx = find(~cellfun(@isempty, manCell));
        if isempty(keepIdx)
            continue;
        end
        keepSym = phons(ids(keepIdx));
        % Python: b = np.linspace(0,T,n+1).astype(int) (truncation)
        b = floor(linspace(0, nfrm, numel(keepSym) + 1));
        for j = 1:numel(keepSym)
            lo = b(j) + 1;                      % 0-based -> 1-based
            hi = max(b(j) + 1, b(j+1));         % closed interval end (1-based)
            segList{end+1} = mean(X(lo:hi, :), 1); %#ok<AGROW>
        end
        for j = 1:numel(keepSym)
            f = phoneme_feat(keepSym{j});
            manList{end+1} = f{1}; %#ok<AGROW>
            plaList{end+1} = f{2}; %#ok<AGROW>
        end
        tidList{end+1} = repmat(si * 100000 + ti, 1, numel(keepSym)); %#ok<AGROW>
        nkept = nkept + 1;
    end
    meta.n_trials = meta.n_trials + nkept;
    fprintf('  [%2d/%2d] %-24s trials=%d segs=%d\n', si, numel(sessions), ...
        sessions{si}, nkept, numel(segList));
end
meta.sessions = sessions;

segs   = vertcat(segList{:});
manner = vertcat(manList{:});
place  = vertcat(plaList{:});
trialId = vertcat(tidList{:});
fprintf('[data] done: segments=%d trials=%d\n', size(segs,1), numel(unique(trialId)));
end

function f = phoneme_feat(sym)
% Single-phoneme lookup, same table as articulation_table (kept as a
% persistent Map so the table is built only once).
persistent tab
if isempty(tab)
    tab = containers.Map('KeyType','char','ValueType','any');
    m = { {'AA','VOWEL','back'},{'AE','VOWEL','front'},{'AH','VOWEL','central'},...
          {'AO','VOWEL','back'},{'AW','VOWEL','back'},{'AY','VOWEL','front'},...
          {'EH','VOWEL','front'},{'ER','VOWEL','central'},{'EY','VOWEL','front'},...
          {'IH','VOWEL','front'},{'IY','VOWEL','front'},{'OW','VOWEL','back'},...
          {'OY','VOWEL','back'},{'UH','VOWEL','back'},{'UW','VOWEL','back'},...
          {'B','STOP','LABIAL'},{'P','STOP','LABIAL'},{'D','STOP','DENTAL_ALV'},...
          {'T','STOP','DENTAL_ALV'},{'G','STOP','VELAR'},{'K','STOP','VELAR'},...
          {'F','FRICATIVE','LABIAL'},{'V','FRICATIVE','LABIAL'},...
          {'TH','FRICATIVE','DENTAL_ALV'},{'DH','FRICATIVE','DENTAL_ALV'},...
          {'S','FRICATIVE','DENTAL_ALV'},{'Z','FRICATIVE','DENTAL_ALV'},...
          {'SH','FRICATIVE','POSTALV_PAL'},{'ZH','FRICATIVE','POSTALV_PAL'},...
          {'HH','FRICATIVE','GLOTTAL'},{'CH','AFFRICATE','POSTALV_PAL'},...
          {'JH','AFFRICATE','POSTALV_PAL'},{'M','NASAL','LABIAL'},...
          {'N','NASAL','DENTAL_ALV'},{'NG','NASAL','VELAR'},...
          {'L','APPROXIMANT','DENTAL_ALV'},{'R','APPROXIMANT','DENTAL_ALV'},...
          {'W','APPROXIMANT','LABIAL'},{'Y','APPROXIMANT','POSTALV_PAL'} };
    for k = 1:numel(m)
        tab(m{k}{1}) = {m{k}{2}, m{k}{3}};
    end
end
f = tab(sym);
end
