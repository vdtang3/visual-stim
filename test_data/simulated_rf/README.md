# Simulated receptive-field test session

These files form one synthetic cell with a known receptive-field center:

- Expected azimuth: **+5 degrees**
- Expected elevation: **-5 degrees**
- Sampling rate: **20 kHz**
- Analog channel: **Vm**
- Digital channel: **Screen**

Each H5 uses the minimal WaveSurfer layout read by the existing `loadws`
function. Its paired MAT file contains `runData` with an H5 metadata pointer,
so it can be added directly through `VisualAnalysisGUI`.

For the fastest start, use **Load session** and select
`simcell_rf_session.mat`. It contains all five run/H5 pairings in the same
order, ready to analyze.

| Sweep | Protocol | Approximate duration |
|---|---|---:|
| `simcell_0001` | Moving bars | 48.0 s |
| `simcell_0002` | Flashed bars | 48.0 s |
| `simcell_0003` | Sparse noise | 40.0 s |
| `simcell_0004` | Fast Gabor tiling | 72.0 s |
| `simcell_0005` | Targeted Gabor grid | 32.4 s |

All recordings are below the requested three-minute maximum. Noise and spike
counts are deterministic because the generator uses a fixed random seed.

To test the GUI, add the paired `*_runData.mat` files in sequence. Accept the
detected H5 for each run, reduce bootstrap repetitions if desired, and analyze
the runs. Generate the consensus RF after at least two runs are complete.

To regenerate the data:

```matlab
addpath('tests')
generateSimulatedAnalysisDatasets
```

To validate the complete H5 loading, preprocessing, TTL alignment, and RF
analysis path:

```matlab
addpath('tests')
validateSimulatedAnalysisDatasets
```
