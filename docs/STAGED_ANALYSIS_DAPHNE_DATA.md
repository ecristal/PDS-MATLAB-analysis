# Staged sources for `analysis_daphne_data.mlx`

## Purpose

This workspace contains a byte-verified working copy of the primary DAPHNE Live Script and the MATLAB `.m` files found by static dependency resolution using the supplied MATLABPATH. No MATLAB execution occurred during the original staging. Subsequent isolated runtime validation of the `f_fourier` refactor is documented in [[f_fourier]].

## Layout

- `legacy/live-scripts/analysis_daphne_data.mlx` — preserved copy of the primary Live Script.
- `src/data/` — resolved helper files originating from `Scripts_analisis/data`.
- `src/daphne/` — resolved helper files originating from `Scripts_analisis/daphne`.
- `legacy/functions/f_fourier/f_fourier.m` — byte-preserved implementation originally staged from the FIUNA MATLAB directory; kept outside MATLABPATH.
- `src/+pds/+signal/` — project-owned spectral computation API.
- `src/+pds/+plotting/` — project-owned spectral plotting API.
- `src/compat/` — temporary wrappers for historical call signatures.
- `setupPDSAnalysisPath.m` — explicit path setup function for staged and project-owned code.

## MATLAB setup when execution is authorized

```matlab
addpath('C:\Users\e_cri\Documents\Proyectos\PDS-MATLAB-analysis');
setupPDSAnalysisPath;
```

Do not add the entire workspace recursively with `genpath`: that would also expose tests, inventories, and future experimental code.

## Provenance and limitations

`inventory/analysis_daphne_data_staged_sources.json` records every copied file, its original source path, staging destination, SHA-256 hash, and verification result. For `f_fourier`, the manifest retains the original staging destination under `external/`; the byte-identical file now resides under `legacy/functions/f_fourier/` after adoption of the project-owned API.

`inventory/analysis_daphne_data_static_dependencies.json` records the static scan. Static resolution cannot prove runtime completeness: MATLAB built-ins/toolboxes, data files, dynamic function calls, runtime path changes, and branches not inspected at execution time may add requirements. Large `.mat`/`.npy` artifacts and aging-test files were intentionally not copied at this stage.
