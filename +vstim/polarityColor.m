function color = polarityColor(polarity, cfg)
%POLARITYCOLOR Convert -1/1 polarity into the configured luminance.
if polarity > 0
    color = cfg.display.whiteLevel;
else
    color = cfg.display.blackLevel;
end
end
