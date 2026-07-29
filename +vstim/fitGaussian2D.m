function fit = fitGaussian2D(azimuthDeg, elevationDeg, response)
%FITGAUSSIAN2D Fit an axis-aligned positive elliptical Gaussian.

x = double(azimuthDeg(:));
y = double(elevationDeg(:));
z = double(response(:));
valid = isfinite(x) & isfinite(y) & isfinite(z);
x = x(valid); y = y(valid); z = z(valid);
fit = struct('centerAzimuthDeg',NaN,'centerElevationDeg',NaN, ...
    'sigmaAzimuthDeg',NaN,'sigmaElevationDeg',NaN,'amplitude',NaN, ...
    'baseline',NaN,'rSquared',NaN,'prediction',nan(size(z)), ...
    'success',false);
if numel(z) < 6 || numel(unique(x)) < 2 || numel(unique(y)) < 2
    return
end
dynamicRange = max(z)-min(z);
scale = max(1,max(abs(z)));
if dynamicRange <= 1e-9*scale
    fit.baseline = mean(z);
    fit.amplitude = 0;
    fit.prediction = repmat(mean(z),size(z));
    return
end

base0 = min(z);
w = max(z-base0,0);
if sum(w) == 0, w(:) = 1; end
cx0 = sum(x.*w)/sum(w);
cy0 = sum(y.*w)/sum(w);
xSpan = max(x)-min(x); ySpan = max(y)-min(y);
p0 = [base0, log(max(max(z)-base0,eps)), cx0, cy0, ...
    log(max(xSpan/5,eps)), log(max(ySpan/5,eps))];
objective = @(p) sum((z-model(p,x,y)).^2) + ...
    penalty(p,min(x),max(x),min(y),max(y),xSpan,ySpan);
options = optimset('Display','off','MaxIter',1500,'MaxFunEvals',5000);
p = fminsearch(objective,p0,options);
prediction = model(p,x,y);
fit.baseline = p(1);
fit.amplitude = exp(p(2));
fit.centerAzimuthDeg = p(3);
fit.centerElevationDeg = p(4);
fit.sigmaAzimuthDeg = exp(p(5));
fit.sigmaElevationDeg = exp(p(6));
fit.prediction = prediction;
fit.rSquared = 1-sum((z-prediction).^2)/sum((z-mean(z)).^2);
fit.success = fit.centerAzimuthDeg >= min(x) && ...
    fit.centerAzimuthDeg <= max(x) && ...
    fit.centerElevationDeg >= min(y) && ...
    fit.centerElevationDeg <= max(y) && ...
    fit.amplitude > 1e-6*dynamicRange;
end

function z = model(p,x,y)
z = p(1) + exp(p(2))*exp(-0.5*( ...
    ((x-p(3))/exp(p(5))).^2 + ((y-p(4))/exp(p(6))).^2));
end

function value = penalty(p,xlo,xhi,ylo,yhi,xspan,yspan)
sx = exp(p(5)); sy = exp(p(6));
value = 1e6*(max(0,xlo-p(3))^2 + max(0,p(3)-xhi)^2 + ...
    max(0,ylo-p(4))^2 + max(0,p(4)-yhi)^2 + ...
    max(0,xspan/100-sx)^2 + max(0,sx-2*xspan)^2 + ...
    max(0,yspan/100-sy)^2 + max(0,sy-2*yspan)^2);
end
