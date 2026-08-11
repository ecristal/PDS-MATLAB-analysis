# Staged sources for `analysis_daphne_data.mlx`

## Purpose

This workspace contains a byte-verified working copy of the primary DAPHNE Live Script and the MATLAB `.m` files found by static dependency resolution using the supplied MATLABPATH. No MATLAB execution occurred during the original staging. Subsequent isolated runtime validation of the `f_fourier` refactor is documented in [[f_fourier]].

## Layout

- `legacy/live-scripts/analysis_daphne_data.mlx` — preserved copy of the primary Live Script.
- `src/data/` — resolved helper files originating from `Scripts_analisis/data`.
- `src/daphne/` — resolved helper files originating from `Scripts_analisis/daphne`.
- `legacy/functions/f_fourier/f_fourier.m` — implementación espectral histórica fuera del MATLABPATH.
- `legacy/functions/mi_dft/`, `mi_idtft/` y `optimal_filter_for_daphne_gpessina_function/` — referencias históricas preservadas fuera del MATLABPATH.
- `src/+pds/+signal/` — APIs de espectro, DFT/IDFT, ventaneo, PSD de ruido y filtro óptimo.
- `src/+pds/+plotting/` — API de plotting espectral.
- `src/compat/` — wrappers temporales para firmas históricas, incluidos los tres componentes del filtro.
- `tests/integration/` — validación opcional con datos locales ignorados.
- `setupPDSAnalysisPath.m` — configuración explícita; añade el Live Script preservado, pero no añade `legacy/functions`, tests ni datos.

## MATLAB setup when execution is authorized

```matlab
addpath('C:\Users\e_cri\Documents\Proyectos\PDS-MATLAB-analysis');
setupPDSAnalysisPath;
```

Do not add the entire workspace recursively with `genpath`: that would also expose tests, inventories, and future experimental code.

## Provenance and limitations

`inventory/analysis_daphne_data_staged_sources.json` registra cada archivo copiado, su ruta fuente original, destino inicial de staging, SHA-256 y resultado de verificación. El manifiesto conserva destinos históricos que ya no son el layout autoritativo: `f_fourier` apuntaba a `external/`, mientras `mi_dft`, `mi_idtft` y `optimal_filter_for_daphne_gpessina_function` apuntaban a `src/data/`. Los cuatro archivos byte-identical residen ahora bajo `legacy/functions/`; las APIs autoritativas viven bajo `+pds` y los wrappers bajo `src/compat`.

`inventory/analysis_daphne_data_static_dependencies.json` records the static scan. Static resolution cannot prove runtime completeness: MATLAB built-ins/toolboxes, data files, dynamic function calls, runtime path changes, and branches not inspected at execution time may add requirements. Large `.mat`/`.npy` artifacts and aging-test files were intentionally not copied at this stage.
