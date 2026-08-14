---
type: matlab-function
status: validated
tags: [simulation, noise, psd, matlab]
---

# `pds.simulation.generateColoredNoise`

## Propósito

Genera ruido estacionario real, por filas, a partir de una PSD bilateral en orden FFT.

```matlab
[noise, diagnostics] = pds.simulation.generateColoredNoise( ...
    4096, 16e-9, NoisePsd=bilateralPsd, ...
    EventCount=1000, Seed=1700, OutputSampleCount=2048);
```

## Convención espectral

Para `N=sampleCount`, `Fs=1/samplePeriod` y coeficientes DFT `X_k`:

```text
E{|X_k|^2} = Fs * N * S_k
S_k units   = signal-units^2 / Hz
```

`NoisePsd` debe tener exactamente N bins, ser real, finita, no negativa, bilateral y hermíticamente simétrica. DC y Nyquist —cuando existe— son reales; los demás bins se construyen como pares conjugados. La salida es real por construcción.

La convención es la inversa estadística de `pds.signal.estimateNoisePsd(..., Window="rectangular")`. La validación correcta compara la PSD promedio de un ensemble, no una realización bin a bin.

## Reproducibilidad

- `Seed` crea un `RandStream` local.
- `RandomStream` acepta un stream proporcionado por el llamador.
- Son mutuamente excluyentes.
- Si ninguno se proporciona, se usa un stream local determinista con seed 0.
- El RNG global no cambia.

## RMS y recorte

`TargetRms` reescala cada evento usando el RMS de las muestras efectivamente
entregadas. Cuando existe recorte, el mismo factor se aplica a toda la realización
progenitora antes de devolver el segmento central; así no se introduce una
discontinuidad artificial en los límites del recorte. `normalizationScale` conserva
el factor por evento y `effectiveTargetPsd` aplica a la PSD solicitada la media de
los factores de potencia.

`OutputSampleCount < sampleCount` devuelve un recorte central de una realización más larga. Los diagnósticos conservan `generatedSampleCount`, `outputSampleCount` y `cropIndices`. Esto permite evitar entregar la unión periódica del bloque FFT.

## Diagnósticos

```text
sampleCount, generatedSampleCount, outputSampleCount, cropIndices,
eventCount, samplePeriod, sampleRateHz, frequencyHz, frequencyOrder,
psdSidedness, psdUnits, targetPsd, effectiveTargetPsd, realizedPsd,
realizedPsdPerEvent, deliveredFrequencyHz, deliveredRealizedPsd,
deliveredRealizedPsdPerEvent, realizedRms, targetRms, randomSource,
seed, normalization, normalizationScale
```

## Evidencia

Tests sintéticos:

- PSD blanca;
- N par e impar;
- AR(1);
- power-law;
- RMS objetivo;
- eventos por filas;
- seed/stream y preservación del RNG;
- rechazos de PSD inválida;
- generación larga y recorte central.

Validación DAPHNE:

```text
outputs/validation/colored-noise-daphne-fbk-vgain-1700/
```

Con la PSD medida sobre el pretrigger de los primeros 3000 registros del canal 24:

```text
log-PSD correlation: 0.99992
relative PSD L2 error: 0.02586
measured RMS:  4.4199 ADU
generated RMS: 4.4003 ADU
```

Esto demuestra reproducción estadística de la PSD medida; no constituye por sí solo un modelo físico de la electrónica.
