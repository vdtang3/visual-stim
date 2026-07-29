function fit = fitGaussian1D(x, y)
%FITGAUSSIAN1D Fit a positive Gaussian plus constant using fminsearch.

x = double(x(:));
y = double(y(:));
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
fit = struct('center', NaN, 'sigma', NaN, 'amplitude', NaN, ...
    'baseline', NaN, 'rSquared', NaN, 'prediction', nan(size(y)), ...
    'success', false);
if numel(x) < 3 || numel(unique(x)) < 3
    return
end
dynamicRange = max(y)-min(y);
scale = max(1,max(abs(y)));
if dynamicRange <= 1e-9*scale
    fit.baseline = mean(y);
    fit.amplitude = 0;
    fit.prediction = repmat(mean(y),size(y));
    return
end

xRange = max(x)-min(x);
base0 = min(y);
weights = max(y-base0, 0);
if sum(weights) > 0
    center0 = sum(x.*weights)/sum(weights);
else
    [~, peak] = max(y);
    center0 = x(peak);
end
sigma0 = max(xRange/5, eps);
amp0 = max(max(y)-base0, eps);
p0 = [base0, log(amp0), center0, log(sigma0)];
objective = @(p) sum((y-model(p,x)).^2) + ...
    boundaryPenalty(p, min(x), max(x), xRange);
options = optimset('Display','off','MaxIter',1000,'MaxFunEvals',3000);
p = fminsearch(objective, p0, options);
prediction = model(p,x);
fit.baseline = p(1);
fit.amplitude = exp(p(2));
fit.center = p(3);
fit.sigma = exp(p(4));
fit.prediction = prediction;
fit.rSquared = 1-sum((y-prediction).^2)/sum((y-mean(y)).^2);
fit.success = isfinite(fit.center) && fit.center >= min(x) && ...
    fit.center <= max(x) && fit.amplitude > 1e-6*dynamicRange;
end

function y = model(p,x)
y = p(1) + exp(p(2))*exp(-0.5*((x-p(3))/exp(p(4))).^2);
end

function penalty = boundaryPenalty(p,lo,hi,span)
center = p(3);
sigma = exp(p(4));
penalty = 1e6*(max(0,lo-center)^2 + max(0,center-hi)^2 + ...
    max(0,span/100-sigma)^2 + max(0,sigma-2*span)^2);
end
