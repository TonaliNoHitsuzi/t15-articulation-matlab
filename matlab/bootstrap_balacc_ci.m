function out = bootstrap_balacc_ci(y, yp, trialId, classes, B, seed)
%BOOTSTRAP_BALACC_CI Bootstrap 95% CI for balanced accuracy over trials
%   out = bootstrap_balacc_ci(y, yp, trialId, classes, B, seed)
%   Line-by-line port of the Python boot_ci/_counts:
%     - aggregate per trial into (T x C) true-count Nt and correct-count Nc
%     - B bootstrap replicates: resample trial indices -> matrix product
%       sums -> per-class recall -> mean = balanced accuracy
%     - report point estimate and 2.5/97.5 percentiles
%
%   out fields: balacc / balacc_lo / balacc_hi / chance /
%               per_class.<class>.{acc, lo, hi}

if nargin < 5, B = 1000; end
if nargin < 6, seed = 1; end

y  = string(y(:));   yp = string(yp(:));   trialId = double(trialId(:));
C  = numel(classes);
cls = string(classes(:));

[tfy, yc] = ismember(y, cls);    yc(~tfy) = 0;   % class index, 0 = outside
[tfp, pc] = ismember(yp, cls);   pc(~tfp) = 0;
ok = (yc > 0) & (pc > 0);
yc = yc(ok);  pc = pc(ok);  trialId = trialId(ok);

[ut, ~, tix] = unique(trialId);
T = numel(ut);
Nt = accumarray([tix, yc], 1, [T, C]);
Nc = accumarray([tix, yc], double(yc == pc), [T, C]);

rec = sum(Nc, 1) ./ max(sum(Nt, 1), 1);      % per-class recall (point est.)
rec(sum(Nt,1) == 0) = NaN;
out.balacc = mean(rec, 'omitnan');
out.chance = 1 / C;

rng(seed);                                   % bootstrap over trials
idx = randi(T, B, T);
M   = zeros(B, T);
lin = repmat((1:B).', 1, T);
ind = sub2ind([B, T], lin(:), idx(:));
M(ind) = 1;
St = M * Nt;   Sc = M * Nc;
rB = Sc ./ max(St, 1);
rB(St == 0) = NaN;
bal = mean(rB, 2, 'omitnan');
out.balacc_lo = prctile(bal, 2.5);
out.balacc_hi = prctile(bal, 97.5);

out.per_class = struct();
for k = 1:C
    s = struct('acc', rec(k), ...
               'lo',  prctile(rB(St(:,k) > 0, k), 2.5), ...
               'hi',  prctile(rB(St(:,k) > 0, k), 97.5));
    out.per_class.(matlab.lang.makeValidName(classes{k})) = s;
end
end
