# Staged sources for `analysis_daphne_data.mlx`

## Purpose

This workspace contains a byte-verified, non-refactored working copy of the primary DAPHNE Live Script and the MATLAB `.m` files found by static dependency resolution using the supplied MATLABPATH. No MATLAB test or execution was performed during staging.

## Layout

- `legacy/live-scripts/analysis_daphne_data.mlx` — preserved copy of the primary Live Script.
- `src/data/` — resolved helper files originating from `Scripts_analisis/data`.
- `src/daphne/` — resolved helper files originating from `Scripts_analisis/daphne`.
- `external/fiuna-pasantia-tesis-matlab/` — dependency resolved from the FIUNA MATLAB directory; provenance is retained by location.
- `setupPDSAnalysisPath.m` — explicit path setup function for these staged directories.

## MATLAB setup when execution is authorized

```matlab
addpath('C:\Users\e_cri\Documents\Proyectos\PDS-MATLAB-analysis');
setupPDSAnalysisPath;
```

Do not add the entire workspace recursively with `genpath`: that would also expose tests, inventories, and future experimental code.

## Provenance and limitations

`inventory/analysis_daphne_data_staged_sources.json` records every copied file, its original source path, destination, SHA-256 hash, and verification result.

`inventory/analysis_daphne_data_static_dependencies.json` records the static scan. Static resolution cannot prove runtime completeness: MATLAB built-ins/toolboxes, data files, dynamic function calls, runtime path changes, and branches not inspected at execution time may add requirements. Large `.mat`/`.npy` artifacts and aging-test files were intentionally not copied at this stage.
