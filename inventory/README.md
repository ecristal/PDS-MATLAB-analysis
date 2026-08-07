# Scripts_analisis — Initial Preservation Manifest

This report is a read-only inventory of the source tree. No source file was moved, edited, or initialized as a Git repository while generating it.

## Scope

- Source: `C:\Users\e_cri\OneDrive\Documents\PhD\Investigacion\MATLAB\Scripts_analisis`
- Generated (UTC): `2026-08-07T07:47:07.994157Z`
- Files catalogued: **234**
- Project-owned MATLAB candidates (`.m`/`.mlx`, excluding detected vendor roots): **121**

## Preliminary classification

- data/calibration/reference artifact: 2
- experiment/prototype or workflow (review required): 15
- maintained analysis/workflow (review required): 14
- reusable project function or helper (review required): 81
- temporary/backup: 13
- test/validation: 11
- third-party/vendor: 68
- unknown/review required: 30

## File extensions

- `.asv`: 13
- `.ipynb`: 1
- `.m`: 121
- `.mat`: 2
- `.md`: 4
- `.mlx`: 14
- `.npy`: 42
- `.png`: 1
- `.py`: 1
- `.sample`: 13
- `.txt`: 2
- `.yml`: 1
- `[none]`: 19

## Immediate review priorities

1. `Live_scripts/analysis_daphne_data.mlx` — designated primary reference workflow.
2. DAPHNE/NP04 import helpers, channel mapping utilities, matched-filter variants, and the VGAIN/NP04 analysis family — map their call relationships before extraction/refactoring.
3. Determine whether `daphne/` is project-owned code, a dependency, or data/configuration; it requires explicit classification.
4. Verify origins/licenses for `ParforProgMon/`, `npy-matlab-master/`, and `data/EditorSessionManager/` before deciding whether they appear in a future repository.
5. Do not add `.mat`, `.npy`, `*.asv`, or generated results to Git by default; review each artifact's role first.

## Largest files

| Path | Bytes | Preliminary class |
|---|---:|---|
| `data/npy-matlab-master/adc_data_run_24062_srcid_4_ch_36_0000.npy` | 290,600,128 | third-party/vendor |
| `data/daphneV2_fbk_45pde_int_on.mat` | 38,729,204 | data/calibration/reference artifact |
| `Live_scripts/analysis_daphne_data_vgain_scan_np04.mlx` | 22,577,191 | maintained analysis/workflow (review required) |
| `data/npy-matlab-master/tests/data/chelsea_float64.npy` | 3,247,280 | third-party/vendor |
| `data/npy-matlab-master/tests/data/chelsea_int64.npy` | 3,247,280 | third-party/vendor |
| `data/npy-matlab-master/tests/data/chelsea_uint64.npy` | 3,247,280 | third-party/vendor |
| `data/npy-matlab-master/tests/data/matlab_chelsea_float64.npy` | 3,247,280 | third-party/vendor |
| `data/npy-matlab-master/tests/data/matlab_chelsea_int64.npy` | 3,247,280 | third-party/vendor |
| `data/npy-matlab-master/tests/data/matlab_chelsea_uint64.npy` | 3,247,280 | third-party/vendor |
| `data/daphne_1.mat` | 3,017,684 | data/calibration/reference artifact |
| `Live_scripts/analysis_daphne_data_vgain_scan.mlx` | 2,952,267 | maintained analysis/workflow (review required) |
| `Live_scripts/analysis_daphne_data_multivar.mlx` | 2,693,840 | maintained analysis/workflow (review required) |
| `data/npy-matlab-master/tests/npy.ipynb` | 2,458,493 | third-party/vendor |
| `data/npy-matlab-master/tests/data/chelsea_float32.npy` | 1,623,680 | third-party/vendor |
| `data/npy-matlab-master/tests/data/chelsea_int32.npy` | 1,623,680 | third-party/vendor |

## Full manifest

The machine-readable manifest, including SHA-256 checksums and timestamps for every file, is `manifest.csv` in this directory. It is the preservation baseline to compare against before and after future reorganizations.
