function [color,lineStyle,note] = rfOverlayStyle(result)
%RFOVERLAYSTYLE Three-tier visual style for an RF estimate's trustworthiness.
%   [COLOR,LINESTYLE,NOTE] = RFOVERLAYSTYLE(RESULT) returns a consistent
%   style for overlaying RESULT's fitted RF center on a response plot:
%     - solid green  ("usable")             usableCenter && ~edgeWarning
%     - dashed amber ("at grid edge,
%                      uncertain")           usableCenter && edgeWarning
%     - solid olive  ("flagged not usable")  ~usableCenter
%
%   RESULT.USABLECENTER is computed from fit success plus peak-response/
%   dynamic-range/fit-quality thresholds only (see e.g.
%   +vstim/analyzeGaborMapSpikes.m and +vstim/finalizeRFUncertainty.m) - it
%   is never downgraded for RESULT.EDGEWARNING, so a fit pinned to the edge
%   of the tested range (no real interior peak to anchor on) can still
%   read usableCenter=true. Treating that case identically to a clean
%   interior fit would repeat that blind spot, so it gets its own distinct
%   style here rather than being folded into either extreme.

if ~result.usableCenter
    color = [0.6 0.6 0.1];
    lineStyle = "-";
    note = "flagged not usable";
elseif result.edgeWarning
    color = [0.9 0.6 0.0];
    lineStyle = "--";
    note = "at grid edge, uncertain";
else
    color = [0.1 0.7 0.1];
    lineStyle = "-";
    note = "usable";
end
end
