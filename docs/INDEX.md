---
type: documentation-index
status: active
tags:
  - index
  - matlab
  - pds
  - daphne
---


# PDS MATLAB Analysis — Documentation Index

## Alcance actual

La documentación cubre el workflow histórico `analysis_daphne_data.mlx` y las dependencias `.m` copiadas mediante resolución estática. El workflow completo continúa sin ejecución end-to-end, pero la primera refactorización aislada —`f_fourier` → `computeSpectrum`/`plotSpectrum`— cuenta con validación runtime en MATLAB R2025b.

## Cómo navegar

- [[DOCUMENTATION_GUIDE]] — convenciones, estados y grados de evidencia.
- [[MATLAB_SCRIPT_CATALOG]] — catálogo cualitativo de los archivos staged.
- [[analysis_daphne_data]] — ficha del Live Script principal.
- [[analysis_daphne_data_dependencies]] — mapa estático de dependencias.
- [[STAGED_ANALYSIS_DAPHNE_DATA]] — procedencia y proceso de staging.

## Workflow principal

- [[analysis_daphne_data]]
- [[setupPDSAnalysisPath]] — configuración local del MATLABPATH staged.

## Ingesta y acceso a datos

- [[extract_and_import_DAPHNE_data]]
- [[import_data_daphne_func]]
- [[getDataFromWafflesPickleFile]]
- [[readBinaryDataRSOsc]]
- [[xmltools]]

## Pedestal, señal y métricas

- [[calculateMedianPedestal]]
- [[fit2SPE]]
- [[gaussian_fit_SNR]]
- [[find_peaks_hist_adaptive]]
- [[my_gaussian_fit]]
- [[sum_fitted_data]]
- [[ROC_file_analysis]]

## Procesamiento espectral y filtrado

- [[optimal_filter_for_daphne_gpessina_function]]
- [[mi_dft]]
- [[mi_idtft]]
- [[f_fourier]] — wrapper legacy, resultados de tests y ejemplos completos.
- [[computeSpectrum]] — API numérica namespaced y validada.
- [[plotSpectrum]] — visualización lineal/dB con referencia explícita.

## Estado de validación

La mayoría de las fichas continúa en `review_mode: static`. Las expresiones “dependencia” y “utilizada por” del workflow se basan en resolución estática, no en una ejecución end-to-end.

Validación runtime completada para el primer foco:

- `TestComputeSpectrum`: 11/11.
- `TestPlotSpectrum`: 4/4.
- `TestFFourierCompatibility`: 5/5.
- `TestFFourierLegacyCharacterization`: 3/3.
- `TestSetupPDSAnalysisPath`: 1/1.
- Total: 24/24 tests aprobados en MATLAB R2025b Update 3.

Véase [[f_fourier]] para entorno, tolerancias, limitaciones y ejemplos.
