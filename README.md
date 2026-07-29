# Adaptive visual stimulation

Readable MATLAB/Psychtoolbox tools for receptive-field mapping during in vivo
whole-cell recordings. The package provides six configurable protocols:

1. Bidirectional moving bars
2. Flashed bars
3. Locally sparse multi-tile noise
4. Fast Gabor tiling
5. Targeted Gabor grid
6. Classical/inverse/full-field Gabor stimuli

## First-time installation

Run:

```matlab
cd('C:\path\to\harnett_in_vivo_patch')  % use the actual package folder
installVisualStim
```

The installer selects and validates Psychtoolbox, activates the bundled
in-vivo-patch analysis functions, then configures the monitor, stimulus
screen, optional Arduino TTL output, and default output directory.
Settings are saved in the readable file `config/installation.json`.

Display geometry uses head-centered coordinates. The installer asks for the
straight-line eye-to-monitor-center distance, monitor-center horizontal offset
(positive toward animal-right), and vertical offset (positive upward). The
monitor is modeled as vertical and horizontally rotated so its face normal
points toward the animal. Azimuth/elevation center and visible monitor edges
are derived from those measurements. Automatically generated bar, tile, and
Gabor positions begin at the calculated monitor center and tile outward.

For sparse noise, `autoGridFromDisplay=true` makes `gridSize` a manual-only
setting. With the default `lockGridSpacingToTileSize=true`, changing
`tileSizeDeg` also changes grid spacing and the number of grid locations.
Tile dimensions and spacing are converted once at the monitor center and
remain constant in physical/pixel units over the entire display. Outermost
tiles may be clipped rather than resized.

`forceSquareTiles=true` is the default. The actual fullscreen resolution is
queried before sparse-sequence generation, and one shared pixel side length
is used for tile width, tile height, and (when locked) center spacing.

Optional display warping uses a Psychtoolbox calibration MAT file through:

```matlab
PsychImaging('AddTask', 'AllViews', 'GeometryCorrection', calibrationFile)
```

Select the file during `installVisualStim`, or set
`geometryCorrectionEnabled` and `geometryCalibrationFile` in the Display tab.

Fast Gabors drift by advancing spatial phase at `temporalFrequencyHz` while
holding contrast constant. Their Gaussian envelope remains stationary.

If MATLAB cannot persist its search path, run `setupVisualStim` at the start
of future MATLAB sessions.

## Windows and MATLAB R2023b

Both GUIs support 64-bit Windows with MATLAB R2023b. On each Windows
acquisition computer:

1. Install a Windows-compatible Psychtoolbox release.
2. Keep the package's bundled `vendor/in_vivo_patch` folder intact.
3. Connect the Arduino and note its `COM` port in Windows Device Manager.
4. Run `installVisualStim` on that machine rather than copying an installation
   configuration from macOS.
5. Run `checkVisualStimCompatibility` before the first experiment.

Saved installation and stimulus-GUI configurations are tagged by platform so
Unix paths and serial ports are not silently autoloaded on Windows. Cell
analysis sessions are portable: when moved, their runData and H5 pointers are
rebased to files beside the session MAT file. The analysis loader prefers the
normal WaveSurfer Windows scaling MEX and automatically falls back to readable
MATLAB scaling if that MEX is unavailable.

## Start the GUI

In MATLAB:

```matlab
cd('C:\path\to\harnett_in_vivo_patch')  % use the actual package folder
VisualStimGUI
```

The GUI edits a plain MATLAB configuration structure. Use **Preview sequence**
before a recording, then **Run stimulus** after WaveSurfer acquisition has
started.

## GUI configurations

All configuration files live under one hierarchy:

```text
config/
├── installation.json       machine, Psychtoolbox, monitor, and Arduino setup
└── gui/
    ├── default_config.json built-in-default descriptor
    └── *.mat               timestamped experiment configurations
```

**Save configuration** writes every current GUI parameter to `config/gui/`.
The newest saved configuration is loaded automatically when the GUI starts.
**Load configuration** selects any saved file manually.

## Synchronization contract

The Arduino is treated as a stateless serial-to-TTL adapter:

- `a` sets the output high.
- `b` sets the output low.
- Every run explicitly starts low and ends low.
- Moving, flashed-bar, and Gabor trials use an epoch-high TTL.
- Sparse-noise patterns with no gray interval use a short onset pulse.
- Analysis does not assume that the first recorded edge is trial 1. If
  opening the Arduino serial port produces reset pulses, it selects the
  contiguous TTL block whose onset intervals and epoch durations best match
  the saved protocol, and reports how many leading/trailing edges it ignored.

WaveSurfer's recorded `Screen` digital input is the authoritative clock for
aligning stimuli to electrophysiology. Psychtoolbox flip timestamps and the
complete generated sequence are also saved for reconstruction and diagnostics.

Classical and inverse stimuli share one Psychtoolbox alpha-aperture texture.
`diameterDeg` controls the classical patch and `inverseDiameterDeg` controls
the inverse gray region independently. For the inverse stimulus,
`inverseDiameterDeg` is the completely gray core; `edgeBlurDeg` starts at
that boundary and fades outward. Thus a 20-degree inverse diameter always
contains a solid 20-degree gray circle.

On macOS 26, the package records timestamp-derived long-frame diagnostics and
emits a platform warning. Current Psychtoolbox releases identify macOS 26
display timing as unreliable; use a supported Windows or Linux stimulus
computer for experimental data collection when those stalls are present.

## Saved files

Each completed or interrupted run saves a MAT file containing `runData`:

```text
runData.params       complete GUI configuration
runData.sequence     exact planned sequence
runData.presentation actual flip and TTL timestamps
runData.sync         TTL mode and serial settings
runData.status       completion and abort information
```

The output directory and optional WaveSurfer sweep label are set in the GUI.

## Quick receptive-field analysis

Start the separate analysis application with:

```matlab
VisualAnalysisGUI
```

Select the saved stimulus `runData` MAT file first. If its metadata points to
an existing WaveSurfer H5, the GUI shows that match and asks whether to use it
or choose a different H5. A missing or moved H5 can always be selected
manually.

The quick analysis uses the copied laboratory `loadws` followed by the copied
standard `preprocess(data,"sweep",true)` implementation. These files and their
complete MATLAB/MEX dependency set are stored under
`vendor/in_vivo_patch/`; the original repository is not required at runtime.
Dataset exclusion remains bypassed. Detected spikes are the only response
source in this version; spike-removed Vm is reserved as a future fallback.

Implemented quick analyses are moving bars, flashed bars, sparse noise, fast
Gabor tiling, and targeted Gabor grids. Fast and targeted Gabor responses are
pooled across orientation at each location—orientation preference is not
estimated. Classical/inverse/full-field stimuli are intentionally left for
offline analysis.

Results include a spike RF center, Gaussian widths, bootstrap 95% confidence
interval and ellipse, split-half reliability, fit quality, TTL-match
diagnostics, and an edge warning. Results are saved alongside the stimulus run
by default and retain pointers to both the runData MAT and selected H5.

The analysis GUI is an accumulating cell workspace. Add and analyze one run,
return after the next stimulus protocol, and add the next run without losing
the earlier results. **Save session** stores the run/H5 pairings and completed
analyses so the cell can be reopened and extended later.

Use the protocol selector to page between moving-bar, flashed-bar,
sparse-noise, and Gabor mapping runs. Every run has its own editable
**Analysis parameters** page. Flashed-bar and Gabor baseline/response windows
start from the settings saved with that stimulus run and are constrained to
its actual stimulus/blank timing so the defaults do not enter an adjacent
trial. Moving-bar latency settings and sparse-noise lag, bin, regularization,
and cross-validation settings are exposed in the same editor. Editing a
parameter invalidates only that run's previous result.

The **Data metrics** page reports stimulus timing before analysis. After
analysis it also reports recording duration, sampling rate, spike count and
rate, TTL matching, spike-detector thresholds, spike-removed Vm statistics,
baseline/response/evoked firing rates where those windows apply, and the
selected peak-response lag for moving bars and sparse noise.

RF centers pass explicit response-quality gates before they are labeled
usable. Flat maps, insufficient peak response, insufficient spatial dynamic
range, or poor fits withhold the center and confidence interval. These
thresholds are editable per run. Previously saved analysis results that
predate these gates are invalidated when the cell session is loaded and must
be reanalyzed.

After at least two usable runs have been analyzed, **Generate consensus RF**
first combines repeat recordings within their mapping-protocol family and then
combines the protocol-family estimates. Both stages use bootstrap center
covariance for weighting. If component centers disagree more than their
uncertainties predict, the consensus covariance is inflated and the
disagreement is reported. Fast and targeted Gabor maps belong to one Gabor
mapping family; moving bars, flashed bars, and sparse noise remain separate
families. The cross-protocol stage also caps extreme precision and robustly
downweights a family that is separated from several agreeing methods; its
weight and a warning are saved with the consensus result.

## Simulated analysis session

`test_data/simulated_rf/` contains five paired WaveSurfer-style H5 and
`runData` MAT files representing one synthetic cell with a known RF center at
azimuth +5 degrees and elevation -5 degrees. It includes moving bars, flashed
bars, sparse noise, fast Gabor tiling, and a targeted Gabor grid. Every
recording is 72 seconds or shorter.

Run `tests/generateSimulatedAnalysisDatasets` to recreate the files and
`tests/validateSimulatedAnalysisDatasets` to exercise H5 loading,
preprocessing, TTL alignment, and RF recovery end to end.

## Code layout

- `VisualStimGUI.m` — programmatic GUI
- `VisualAnalysisGUI.m` — runData-first spike RF analysis GUI
- `+vstim/defaultConfig.m` — all defaults
- `+vstim/generateSequence.m` — protocol dispatcher
- `+vstim/generate*.m` — readable sequence generators
- `+vstim/runProtocol.m` — shared Psychtoolbox presentation loop
- `+vstim/drawStimulus.m` — protocol-specific drawing
- `+vstim/TTLController.m` — safe Arduino control
- `+vstim/loadRun.m` — saved-run loader
- `+vstim/emptyAnalysisResult.m` — common offline-result schema
- `vendor/in_vivo_patch/` — unchanged copied WaveSurfer loading and standard
  preprocessing functions, including platform-specific scaling MEX files

The sequence generators do not require Psychtoolbox and can be tested on an
analysis computer.
