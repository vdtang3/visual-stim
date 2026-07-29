function data = preprocessForAnalysis(data)
%PREPROCESSFORANALYSIS Run the vendored forced sweep preprocessing.
% force=true preserves the approved quick-analysis behavior and bypasses
% dataset exclusion.

data = preprocess(data,"sweep",true);
end
