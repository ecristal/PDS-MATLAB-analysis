---
type: matlab-function
status: validated
tags: [identification, single-pe, preprocessing, matlab]
---

# `pds.identification.prepareSinglePeTemplate`

Prepara explícitamente una plantilla promedio 1 SPE antes de identificar modelos.

```matlab
[template, diagnostics] = pds.identification.prepareSinglePeTemplate( ...
    averageWaveform, BaselineIndices=1:100, Polarity="positive");
```

La función:

1. valida un vector real y finito;
2. estima el baseline mediante la mediana de índices explícitos;
3. resta el baseline;
4. registra polaridad `positive`, `negative` o `auto`;
5. normaliza por la magnitud del pico;
6. preserva la polaridad —no invierte silenciosamente el waveform—;
7. devuelve un vector fila canónico.

Diagnósticos:

```text
baseline, baselineIndices, requestedPolarity, detectedPolarity,
polarity, normalization, peakIndex,
peakAmplitudeBeforeNormalization, peakMagnitudeBeforeNormalization,
normalizationScale, sampleCount
```

`detectedPolarity` registra el signo del extremo de mayor magnitud tras restar el
baseline. `polarity` registra el signo efectivamente usado: coincide con
`requestedPolarity` salvo cuando se solicita `auto`. La amplitud conserva el
signo; la magnitud y `normalizationScale` son positivas.

Para DAPHNE VGAIN 1700, la estimación de Tarea 9 utiliza directamente el waveform promedio congelado `average_single_PE_ch_24.fig`, baseline-corregido con las primeras 100 muestras y normalizado a pico 1 SPE. No se estima el modelo a partir de waveforms individuales ni de una versión suavizada.
