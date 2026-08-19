# Engineering notebook

## 2026-08-19 — Fast Gabor tiling's Response/RF view drops the continuous locator plot

The spatial PSTH grid originally shipped alongside a companion "Fitted RF
(continuous)" locator plot beside it (see the 2026-08-18 entry below). On
review this felt like the wrong place for it: the cell consensus panel
already exists specifically to show the model's conclusion as a
continuous azimuth/elevation position, and duplicating that here just
crowded a view meant to stay mostly about the raw per-position response
structure. Removed the locator axes and the now-unused `drawGaborLocator`
helper; the grid now uses the full width of the plot pane. The
dashed/solid three-tier outline on the grid tile nearest the fitted center
(`nearestGaborTile`) stays - a lightweight cross-reference back to the
consensus panel's conclusion, cheap enough that it doesn't compete with
the raw data the way a second full plot did. The moving-bar Response/RF
view's own RF overlay (a vertical line on a continuous position axis) is
unchanged either way.

## 2026-08-19 — uiaxes autoscale silently ignores handle-hidden data

The new moving-bar raster (see the 2026-08-18 entry below) looked almost
empty on real data - a handful of ticks instead of the dense raster
`patch-analysis`'s own script showed for the same recording - even though
the underlying spike-position data was independently confirmed correct
(hundreds of spikes per direction, spanning the full sweep range). The
per-spike tick marks were plotted with `HandleVisibility='off'` (to keep
them out of a legend, a habit carried over from regular-axes plotting
code). On `uiaxes`, `HandleVisibility='off'` also excludes an object from
`Children` and, in turn, from automatic axis-limit computation - so with
every tick hidden this way, the axes had nothing to scale to and sat at
their unscaled default `[0 1]`, clipping nearly all real data out of view.
Separately, even after making every plotted object handle-visible,
`uiaxes`' auto-scale recompute is asynchronous: reading `XLim` (or letting
`linkaxes` read it) immediately after plotting could still observe a
stale, not-yet-recomputed value, and `linkaxes` locks that value in across
the linked group rather than re-deriving it later. The fix was two-part:
stop hiding primary plotted data from `HandleVisibility` on `uiaxes`
(reserve it for reference lines like `xline` markers, which do not drive
autoscale the same way), and set an explicit `xlim` from the known data
range before calling `linkaxes`, rather than trusting automatic scaling to
resolve in time. Found by dumping the live `inspection` struct passed into
the renderer (`save(...)` at the top of the function, load and inspect
separately) to rule out a data bug before suspecting rendering, then
checking `axes.Children`/`XLim` directly at each step until the exact
divergence point was located.

## 2026-08-18 — Response/RF and Vm/Trials views replace the single selected-run plot

`VisualAnalysisGUI`'s selected-run display used to be one static plot
(`plotRunResult`): a scatter map or two orthogonal-axis profile scatter with
the fitted RF center overlaid. It answered "what did the model conclude"
but not "is this recording healthy" or "does the raw response actually
support that estimate." The selected-run pane is now two toggled views:

- **Response/RF** - for Moving bars, a per-direction spike-position
  raster (top row) and smoothed position PSTH with a bootstrap band
  (bottom row), one column per sweep direction; for Fast Gabor tiling, a
  spatial grid of onset-aligned PSTHs (one per tested position,
  orientation pooled) beside a continuous azimuth/elevation locator plot.
  Both overlay the RF fit's own center/ellipse with a three-tier style
  (`vstim.rfOverlayStyle`): solid green when usable and interior, dashed
  amber when `usableCenter` is true but `edgeWarning` is also true (the
  fit is pinned to the tested grid's edge - `usableCenter` is never
  downgraded for this by the estimator, so without a distinct style this
  case reads as equally confident as a clean interior fit), or solid olive
  when `usableCenter` is false. Other protocols keep the original
  `plotRunResult` plot unchanged.
- **Vm/Trials** - generic across every protocol: a decimated whole-
  recording overview (drift/instability/artifacts at a glance) plus a
  compact single-trial viewer (Prev/Next, a trial spinner, and a condition
  filter built from whichever trial-design columns that protocol happens
  to have), rather than a stack of every trial.

The RF estimator itself (`vstim.analyzeSpikeReceptiveField` and everything
under it) is untouched. The new views are built by three new `+vstim`
functions computed once, right alongside the RF fit, in
`analyzeSelectedPressed`: `vstim.buildTrialInspection` (generic) and
`vstim.analyzeMovingBarInspection`/`vstim.analyzeGaborMapInspection`
(protocol-specific), all consuming the same already-loaded/preprocessed
data the RF fit uses - no second H5 load. The moving-bar inspection reuses
the RF fit's own winning latency (`rfResult.preferredLatencyMs`) rather
than re-deriving one, so the raster reflects exactly the same spike-to-
position mapping the fit used.

Results are cached on `run.inspectionResult` (new field on `emptyRun`), not
recomputed on every mode toggle or session reload. To keep saved sessions
small, only lightweight derived products are stored: a min/max-envelope-
decimated whole-recording overview (~4000 points regardless of recording
length) and per-trial Vm windows capped at ~4000 samples each via the same
envelope decimation - never the full raw trace. This keeps a Vm/Trials
view usable immediately after loading an old session, with no H5 access
until the run is re-analyzed.

Plateau annotation was deliberately left out of the Vm/Trials view: it
needs `extractPlateausBetter` plus a second filter pass and baseline-mode
statistic (`plat_filt`, `vm_mode`) that `vstim.preprocessForAnalysis`
intentionally does not compute (it's the RF-only pipeline - see the
2026-08-12 entry below). Adding that would mean extending the RF-only
preprocessing pipeline for a secondary, optional annotation, which wasn't
worth the coupling. Burst annotation (`vstim.detectBurstSpikes`) has no
such dependency and is included.

## 2026-08-18 — One GUI configuration retains every stimulus protocol

The stimulation GUI now keeps an in-memory configuration for each protocol.
Changing protocols preserves the stimulus-specific edits for the protocol being
left, while display, TTL, session, and shared analysis settings remain common.
Saving writes the complete protocol collection to one timestamped MAT file, and
startup restores the newest collection automatically. The legacy top-level
`cfg` is retained in the file so existing single-protocol readers continue to
work; older configuration files are promoted to a one-entry collection when
loaded.

## 2026-08-12 — RF presentation geometry and quick-analysis timing

Flashed bars now use the same selected mapping rectangle as moving bars. The
orthogonal dimension spans that rectangle rather than the entire display, and
the final rectangle is clipped at all four mapping boundaries.

Moving-bar analysis now treats each Screen TTL as a sweep-onset marker only.
Within-sweep position is reconstructed from the per-frame flip timestamps and
bar centers already saved by presentation. This preserves delayed or extended
frame intervals. Old runs fall back to zero-based frame-index timing using the
measured display IFI, nominal frame rate, or finally duration divided by frame
count, and the result records that fallback.

RF preprocessing was separated from the vendored full sweep pipeline. The
visual-stim path keeps filtering, negative-artifact cleanup, drift adjustment,
and identical vendored spike detection/removal, but deliberately omits crop
tables, dataset validation, plateau/PSP processing, plateau extraction, and Vm
summary statistics.
