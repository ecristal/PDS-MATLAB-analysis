---
title: pds.signal.forwardDft
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/forwardDft.m
tags: [matlab, dft, fft, spectral]
---

[Código fuente MATLAB](../../src/+pds/+signal/forwardDft.m)

Transformada discreta directa bilateral optimizada mediante `fft`. Las entradas numéricas enteras —waveform, ventana, `samplePeriod` y `SampleShift`— se validan y convierten explícitamente a `double` antes de las operaciones de punto flotante.

## Firma

```matlab
[coefficients, frequencyHz] = pds.signal.forwardDft( ...
    waveform, samplePeriod, ...
    Window=[], SampleShift=0)
```

## Convenciones

- Entrada vector fila o columna; salida canónica fila.
- N bins en orden FFT.
- Para N=8 y Fs=8 Hz: `[0 1 2 3 4 -3 -2 -1]` Hz.
- `SampleShift=m` equivale a `fft(circshift(waveform.*window,m))`.
- Una ventana numérica se multiplica realmente por la señal.
- No calcula PSD; usar [`estimateNoisePsd`](estimateNoisePsd.md) o [`computeSpectrum`](computeSpectrum.md).

## Ejemplos

```matlab
samplePeriod = 16e-9;
[X, frequencyHz] = pds.signal.forwardDft(waveform, samplePeriod);
```

Con Tukey y desplazamiento de dos muestras:

```matlab
w = pds.signal.createWindow(numel(waveform), "tukey", TukeyRatio=0.25);
[X, frequencyHz] = pds.signal.forwardDft( ...
    waveform, 16e-9, Window=w, SampleShift=2);
```

## Correcciones respecto de `mi_dft`

- O(N log N), frente a O(N²).
- La ventana se aplica a la señal, no solo al denominador de la PSD.
- La transformada y la estimación PSD están separadas.
- Longitudes, finitud, ventana, período y shift se validan explícitamente.

## Evidencia

`TestForwardDft`: 7 tests runtime para FFT, orientación, ventana, shift, conversión segura de waveforms y opciones escalares enteras, y errores.

## Enlaces

- [`inverseDft`](inverseDft.md)
- [`createWindow`](createWindow.md)
- [`estimateNoisePsd`](estimateNoisePsd.md)
- [`mi_dft`](mi_dft.md)
- [`designOptimalFilter`](designOptimalFilter.md)
