---
title: pds.signal.estimateNoisePsd
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/estimateNoisePsd.m
tags: [matlab, psd, noise, tukey, colored-noise]
---

[Código fuente MATLAB](../../src/+pds/+signal/estimateNoisePsd.m)

Estima una PSD de ruido bilateral a partir de waveforms por filas. Las matrices numéricas, `samplePeriod` y `TukeyRatio` enteros se convierten explícitamente a `double` antes de remover media, ventanear y aplicar FFT.

## Firma

```matlab
[noisePsd, frequencyHz, info] = pds.signal.estimateNoisePsd( ...
    noiseWaveforms, samplePeriod, ...
    Window="tukey", TukeyRatio=0.1, RemoveMean=true)
```

## Convención

Para cada registro `x_r[n]` y ventana `w[n]`:

```text
PSD_r[k] = |FFT{x_r[n] w[n]}|² / (Fs sum_n w[n]²)
PSD[k]   = promedio_r PSD_r[k]
```

- N bins en orden FFT.
- Unidades: unidad-de-entrada²/Hz.
- PSD media no negativa.
- La normalización de potencia de ventana es explícita.

## Ejemplos

PSD coloreada medida con Tukey:

```matlab
[noisePsd, frequencyHz, info] = pds.signal.estimateNoisePsd( ...
    noiseWaveforms, 16e-9, Window="tukey", TukeyRatio=0.25);
```

Comparación Hann/Tukey:

```matlab
psdHann = pds.signal.estimateNoisePsd(noiseWaveforms, 16e-9, Window="hann");
psdTukey = pds.signal.estimateNoisePsd( ...
    noiseWaveforms, 16e-9, Window="tukey", TukeyRatio=0.5);
```

## Evidencia

`TestEstimateNoisePsd`: 7 tests runtime para Parseval rectangular, normalización Tukey, ruido blanco, orientación, conversión segura de matrices y opciones escalares enteras, y errores.

## Enlaces

- [`createWindow`](createWindow.md)
- [`computeSpectrum`](computeSpectrum.md)
- [`designOptimalFilter`](designOptimalFilter.md)
- `docs/validation/optimal-filter-daphne-reference.md`
