function yp = fit_logreg_oof(X, y, fold, method)
%FIT_LOGREG_OOF Grouped-CV out-of-fold logistic regression predictions
%   yp = fit_logreg_oof(X, y, fold, method)
%   Port of the Python oof_predict: leave-one-fold-out over trial-grouped
%   folds, training a logistic regression on each training fold and
%   predicting the held-out fold.
%
%   method = 'ecoc' (default) fitcecoc + fitclinear (L2-regularized
%                      logistic learners, balanced class weights,
%                      one-vs-one ECOC coding). Matches the regularized +
%                      class-weighted flavour of sklearn
%                      LogisticRegression(C=0.5, class_weight='balanced').
%                      (This R2021b install lacks fitmnr, so ECOC with
%                      linear logistic learners is the main estimator.)
%
%   Degenerate folds (empty / single-class training set) fall back to the
%   true labels, mirroring the Python guard.

if nargin < 4
    method = 'ecoc';
end
n = numel(y);
yp = cellstr(string(y));               % preallocate with true labels
folds = unique(fold);
for f = folds(:).'
    tr = fold ~= f;
    te = fold == f;
    ytr = y(tr);
    if ~any(tr) || ~any(te) || numel(unique(ytr)) < 2
        continue;
    end
    Xtr = X(tr, :);
    switch lower(method)
        case 'ecoc'
            % balanced class weights w_i = n / (K * n_{c(i)}) (sklearn)
            [cls, ~, ic] = unique(ytr);
            K = numel(cls);
            cnt = accumarray(ic, 1);
            w = numel(ytr) ./ (K * cnt(ic));
            t = templateLinear('Learner', 'logistic', ...
                               'Regularization', 'ridge', 'Lambda', 1.0);
            mdl = fitcecoc(Xtr, categorical(ytr), 'Learners', t, 'Weights', w);
            yp(te) = cellstr(predict(mdl, X(te, :)));
        otherwise
            error('unknown method: %s', method);
    end
end
yp = reshape(string(yp), size(y));
end
