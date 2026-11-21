---
title: find_peaks_hist_adaptive
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/find_peaks_hist_adaptive.m
source_path: Scripts_analisis/data/find_peaks_hist_adaptive.m
workflow:
  - "docs/workflows/analysis_daphne_data.md"
tags: [matlab, histogram, peaks, signal-processing]
---

[Código fuente MATLAB](../../src/data/find_peaks_hist_adaptive.m)

## Descripción cualitativa

Detecta picos en un histograma mediante suavizado configurable y dos pasadas de `findpeaks`. La primera estima una separación característica; la segunda impone esa separación adaptativa.

## Firma

```matlab
function [locs, pks, widths, proms, min_sep] = ...
    find_peaks_hist_adaptive(x_hist, y_hist, varargin)
```

## Entradas y salidas

- `x_hist`, `y_hist`: centros de bins y conteos, de igual longitud.
- Opciones Name-Value: tipo/ventana de suavizado, prominencia mínima, ancho, separación mínima y estrategia basada en anchos.
- Devuelve posiciones, alturas suavizadas, anchos, prominencias y separación elegida en unidades X.

## Algoritmo o procedimiento

1. Convierte entradas en vectores columna y valida longitudes.
2. Normaliza la ventana a entero impar.
3. Suaviza con mediana móvil, media móvil o Savitzky–Golay.
4. Estima `dx`, prominencia y ancho mínimo.
5. Primera pasada permisiva de `findpeaks`.
6. Calcula separación desde anchos o mediana de distancias.
7. Segunda pasada con `MinPeakDistance`.
8. Ordena resultados por posición.

## Dependencias

`inputParser`, `smoothdata`, `findpeaks`; esta última requiere Signal Processing Toolbox.

## Efectos secundarios

No grafica ni escribe archivos.

## Supuestos, unidades y dimensiones

- `x_hist` debería ser creciente y aproximadamente uniforme.
- `dx` y los resultados conservan la unidad de X.
- `y_hist` representa alturas/conteos no necesariamente normalizados.

## Riesgos y limitaciones

- No valida monotonía ni uniformidad de X; si `dx` es inválido usa 1 sin advertir.
- `max(yS)=0` produce prominencia mínima cero, fuera de la intención del validador.
- Los defaults son heurísticos y sensibles al binning.
- El suavizado puede desplazar o fusionar picos.

## Destino provisional en el paquete

Candidato a `+pds/+signal/findHistogramPeaks.m`, acompañado por parámetros de campaña configurables.

## Evidencia y grado de certeza

- **Observado:** opciones, dos pasadas y cálculo adaptativo.
- **Inferido:** orientada a separar poblaciones de fotoelectrones.
- **Desconocido:** configuración validada para cada sensor/setup.

## Preguntas pendientes

- ¿Qué conjunto de parámetros es autoritativo para DAPHNE?
- ¿Debe informar el histograma suavizado para trazabilidad?

## Enlaces

- [`gaussian_fit_SNR`](gaussian_fit_SNR.md)
- `docs/workflows/analysis_daphne_data.md`
- `docs/dependency-maps/analysis_daphne_data_dependencies.md`
