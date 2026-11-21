---
title: gaussian_fit_SNR
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/gaussian_fit_SNR.m
source_path: Scripts_analisis/data/gaussian_fit_SNR.m
workflow:
  - "docs/workflows/analysis_daphne_data.md"
tags: [matlab, snr, gaussian, histogram]
---

[Código fuente MATLAB](../../src/data/gaussian_fit_SNR.m)

## Descripción cualitativa

Construye y suaviza un histograma de integrales, detecta picos, ajusta una suma de gaussianas y deriva separación entre los dos primeros centros y una métrica SNR.

## Firma

```matlab
function [mu1, sigma1, mu2, sigma2, delta, SNR, x_hist_plot, ...
    gauss_fitted_curve, gof, center] = gaussian_fit_SNR( ...
    integral, histogram_bin, min_sep, min_localmax_peak_pos, ...
    x_axis_low_limit, x_axis_high_limit, center_min, center_max, ...
    init_sigma_2_sqrt, gaussN, eff)
```

## Responsabilidad dentro del workflow

Proporciona parámetros de poblaciones gaussianas y SNR para caracterización de respuesta/fotoelectrones en `docs/workflows/analysis_daphne_data.md`.

## Algoritmo o procedimiento

1. Crea un histograma gráfico de las integrales.
2. Selecciona un rango de cutoff según `eff`.
3. Prueba filtros Butterworth y desplazamientos, optimizando NRMSE contra el histograma original.
4. Filtra y desplaza el histograma.
5. Detecta máximos mediante [`find_peaks_hist_adaptive`](find_peaks_hist_adaptive.md).
6. Recorta el intervalo de ajuste.
7. Configura y ejecuta un modelo `gaussN` con Curve Fitting Toolbox.
8. Ordena centros, toma los dos primeros y calcula `delta = mu2-mu1`, `SNR = delta/sigma1`.

## Dependencias

- Local: [`find_peaks_hist_adaptive`](find_peaks_hist_adaptive.md).
- MATLAB/toolboxes: `histogram`, `butter`, `filter`, `goodnessOfFit`, `fitoptions`, `fit` y plotting; implica Signal Processing, Curve Fitting y posiblemente System Identification Toolboxes.

## Efectos secundarios

Crea/modifica un histograma y añade marcadores/limita los ejes actuales.

## Supuestos, unidades y dimensiones

Centros, sigmas y delta conservan la unidad de la integral. SNR es adimensional. El significado de `eff` se infiere como una configuración/eficiencia discreta.

## Riesgos y limitaciones

- `min_sep` y `min_localmax_peak_pos` aparecen en la firma pero no controlan la implementación activa.
- El acceso final está hard-coded a `b1:b3` y `c1:c3`, aunque `gaussN` es configurable.
- Puede indexar picos inexistentes mediante `center_start` o `center_start+i-1`.
- `center_max` solo se usa para localizar un centro inicial, no para recortar todos los picos.
- Calcula `SNR1` pero no lo devuelve.
- Mezcla selección heurística, ajuste, métrica y visualización.

## Destino provisional en el paquete

Candidato a dividirse en `+pds/+fitting/fitPhotoelectronPeaks.m` y `+pds/+metrics/computeSnr.m`, con resultados estructurados y trazabilidad de parámetros.

## Evidencia y grado de certeza

- **Observado:** histograma, filtrado heurístico, ajuste `gaussN` y fórmula SNR.
- **Inferido:** gaussianas consecutivas representan pedestal/1 PE o poblaciones de PE.
- **Desconocido:** definición autoritativa de `eff`, SNR y cantidad de gaussianas por campaña.

## Preguntas pendientes

- ¿Cuál centro corresponde al pedestal y cuál a 1 PE?
- ¿Debe SNR usar solo `sigma1` o ambas sigmas?
- ¿`gaussN` está restringido realmente a 3?

## Enlaces

- [`find_peaks_hist_adaptive`](find_peaks_hist_adaptive.md)
- `docs/workflows/analysis_daphne_data.md`
- `docs/dependency-maps/analysis_daphne_data_dependencies.md`
