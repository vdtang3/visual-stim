function scaledData = scaledDoubleAnalogDataFromRawMexAppleSilicon( ...
        dataAsADCCounts,channelScales,scalingCoefficients)
%SCALEDDOUBLEANALOGDATAFROMRAWMEXAPPLESILICON Local MEX compatibility shim.
% The copied Apple Silicon MEX can be blocked by macOS code-signing policy.
% Delegate to the copied reference MATLAB implementation without changing
% its scaling algorithm.

scaledData = scaledDoubleAnalogDataFromRaw( ...
    dataAsADCCounts,channelScales,scalingCoefficients);
end
