---
type: matlab-function
status: project-api
review_status: tested-runtime
review_mode: [static, runtime]
repo_path: src/+pds/+signal/computeSpectrum.m
replaces: "[[f_fourier]]"
tags: [matlab, fft, psd, rms, pds, runtime-validated]
---

# computeSpectrum

## Propósito

Núcleo numérico namespaced que calcula espectro de amplitud, PSD, media FFT coherente y RMS sin realizar plotting ni conversión a dB.

## Firma

```matlab
spectrum = pds.signal.computeSpectrum(waveforms, samplePeriod, Name=Value)
```

## Contrato dimensional

- Vector fila o columna: un registro.
- Matriz: `registros × muestras`.
- Mínimo dos muestras por registro.
- Solo datos numéricos, reales y finitos.
- La FFT se calcula sobre la segunda dimensión.

## Opciones

```matlab
RemoveMean=false
Sidedness="one-sided"
InputUnit="ADU"
```

`Sidedness="two-sided"` devuelve frecuencias y PSD en orden FFT.

## Resultados

```matlab
spectrum.frequencyHz
spectrum.amplitudeMean
spectrum.psdMean
spectrum.complexMean
spectrum.rmsPerRecord
spectrum.samplePeriod
spectrum.sampleRateHz
spectrum.sampleCount
spectrum.recordCount
spectrum.inputUnit
spectrum.sidedness
spectrum.meanRemoved
```

`complexMean` es una única media coherente. No se devuelven FFT por evento.

## Normalización

```matlab
Y = fft(waveforms, [], 2);
amplitudeTwoSided = abs(Y)/N;
psdTwoSided = abs(Y).^2/(N*Fs);
```

El espectro unilateral duplica únicamente los bins que representan pares positivo/negativo. DC no se duplica; Nyquist no se duplica para N par; el último bin positivo sí se duplica para N impar.

El RMS satisface:

```matlab
rmsPerRecord.^2 == sum(psdPerRecord,2)*df
```

hasta precisión numérica.

## Evidencia runtime

Probado en MATLAB R2025b Update 3 (`PCWIN64`) mediante `TestComputeSpectrum`: 11/11 tests aprobados, con tolerancia absoluta principal `1e-12`.

Casos cubiertos:

- fila/columna;
- N par/impar;
- tono centrado y tono fuera de bin;
- señales cero, constante e impulso;
- ruido con semilla fija;
- Parseval unilateral/bilateral;
- eliminación de media/DC;
- fases opuestas;
- validación de entradas.

## Ejemplo mínimo

```matlab
Fs = 62.5e6;
Tm = 1/Fs;
N = 1024;
n = 0:N-1;
waveform = 100*cos(2*pi*50*n/N);

spectrum = pds.signal.computeSpectrum(waveform, Tm, ...
    InputUnit="ADU", RemoveMean=true);
```

## Limitaciones

- Sin ventanas ni Welch.
- No acepta señales complejas.
- Sin detrending lineal: solo eliminación de media.
- Aún sin baseline experimental DAPHNE.

## Enlaces

- [[f_fourier]]
- [[plotSpectrum]]
- [[optimal_filter_for_daphne_gpessina_function]]
