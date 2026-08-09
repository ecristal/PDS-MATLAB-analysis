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

La documentación inicial cubre el workflow histórico `analysis_daphne_data.mlx` y las dependencias `.m` copiadas al repositorio mediante resolución estática. No se ejecutó MATLAB y no se realizó validación numérica.

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
- [[f_fourier]]

## Estado de validación

Todas las fichas de esta etapa tienen `review_mode: static` y requieren confirmación científica y validación runtime posterior. Las expresiones “dependencia” y “utilizada por” se basan en el manifiesto de resolución estática, no en una ejecución de MATLAB.
