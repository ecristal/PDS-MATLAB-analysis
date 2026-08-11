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

- [[designOptimalFilter]] — diseño autoritativo: ruido blanco, coloreado medido/estimado/proporcionado, AR(1) y 1/f.
- [[applyOptimalFilter]] — aplicación FIR y scores por evento.
- [[estimateNoisePsd]] — PSD bilateral con corrección de ventana.
- [[createWindow]] — Tukey, Hann, Hamming, rectangular y ventanas numéricas.
- [[forwardDft]] / [[inverseDft]] — transformadas discretas optimizadas.
- [[optimal_filter_for_daphne_gpessina_function]] — wrapper legacy deprecated.
- [[mi_dft]] / [[mi_idtft]] — wrappers deprecated y referencias preservadas.
- [[optimal-filter-daphne-reference]] — validación con 30,000 waveforms DAPHNE y SNR.
- [[f_fourier]] — wrapper legacy, resultados de tests y ejemplos completos.
- [[computeSpectrum]] — API numérica namespaced y validada.
- [[plotSpectrum]] — visualización lineal/dB con referencia explícita.

## Estado de validación

La mayor parte del workflow histórico continúa en `review_mode: static`. Las APIs espectrales y de filtro óptimo ya cuentan con validación runtime aislada en MATLAB R2025b Update 3.

Resultados actuales:

- Baseline espectral previo: 24 tests.
- Transformadas DFT/IDFT: 13 tests.
- Ventanas y PSD de ruido: 13 tests.
- Diseño y aplicación del filtro: 15 tests.
- Compatibilidad del filtro legacy: 5 tests.
- Caracterización DFT/IDFT legacy preservada: 3 tests.
- Integración DAPHNE local: 1 test con 30,000 waveforms.
- Total: **74/74 tests aprobados**, 0 fallos y 0 incompletos.
- `checkcode`: 0 mensajes sobre código y tests revisados.

La validación DAPHNE obtuvo `SNR=5.38283353` con PSD coloreada estimada preservando la corrección de pedestal configurada, y documentó concordancia con el ajuste legacy. Véase [[optimal-filter-daphne-reference]].
