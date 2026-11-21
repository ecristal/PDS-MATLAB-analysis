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

- [[DaphneWaveformReader]] — lectura por waveform de archivos DAPHNE `.dat` y `.7z`, con longitud explícita o de los metadatos.
- [[readDaqNpz]] / [[daq-npz-import]] — lector MATLAB y auditoría de la calibración DAQ NPZ de noviembre de 2026.
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

- [[designOptimalFilter]] — diseño autoritativo: ruido blanco, coloreado medido/estimado/proporcionado, AR(1) y 1/f.
- [[designCovarianceOptimalFilter]] — filtro de covarianza temporal completa con shrinkage y prior de ruido independiente.
- [[applyOptimalFilter]] — aplicación FIR y scores por evento.
- [[estimateNoisePsd]] — PSD bilateral con corrección de ventana.
- [[createWindow]] — Tukey, Hann, Hamming, rectangular y ventanas numéricas.
- [[forwardDft]] / [[inverseDft]] — transformadas discretas optimizadas.
- [[optimal_filter_for_daphne_gpessina_function]] — wrapper legacy deprecated.
- [[mi_dft]] / [[mi_idtft]] — wrappers deprecated y referencias preservadas.
- [[optimal-filter-daphne-reference]] — validación con 30,000 waveforms DAPHNE y SNR.
- [[coldbox-m3-november2025-legacy-reproduction]] — reproducción ColdBox M3 CH28 con pedestal en muestras 1:100 y SNR > 5.
- [[coldbox-m3-legacy-contract-comparison]] — comparación November 2025/September 2026 bajo un contrato de shaping y ajuste idéntico.
- [[coldbox-september2026-legacy-survey]] — análisis legacy de los 12 canales M1--M6, con low-pass solo para M3/M4 y average single-P.E.
- [[coldbox-september2026-pof-comparison]] — PoF_OFF/OLD/NEW/ALL comparison for M3 and M6, including fits and an SNR bar-chart summary.
- [[coldbox-m3-covariance-optimal-filter]] — contrato común con pedestal robusto, rechazo de waveforms espurios y prior de ruido dedicado.
- [[f_fourier]] — wrapper legacy, resultados de tests y ejemplos completos.
- [[computeSpectrum]] — API numérica namespaced y validada.
- [[plotSpectrum]] — visualización lineal/dB con referencia explícita.

## Estado de validación

La mayor parte del workflow histórico continúa en `review_mode: static`. Las APIs espectrales y de filtro óptimo ya cuentan con validación runtime aislada en MATLAB R2025b Update 3.

Última ejecución completa en MATLAB R2025b:

- Total: **190/190 tests aprobados**, 0 fallos y 0 incompletos.
- `checkcode`: 0 mensajes sobre el código y los tests del contrato ColdBox modificados.

Desglose histórico del primer milestone espectral/optimal-filter (74 tests):

- Baseline espectral previo: 24 tests.
- Transformadas DFT/IDFT: 13 tests.
- Ventanas y PSD de ruido: 13 tests.
- Diseño y aplicación del filtro: 15 tests.
- Compatibilidad del filtro legacy: 5 tests.
- Caracterización DFT/IDFT legacy preservada: 3 tests.
- Integración DAPHNE local: 1 test con 30,000 waveforms.


La validación DAPHNE obtuvo `SNR=5.38283353` con PSD coloreada estimada preservando la corrección de pedestal configurada, y documentó concordancia con el ajuste legacy. Véase [[optimal-filter-daphne-reference]].
