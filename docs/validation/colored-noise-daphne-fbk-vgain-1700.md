---
type: validation
status: exploratory
tags: [daphne, noise, psd, simulation, validation]
---

# Ruido coloreado DAPHNE FBK SiPM VGAIN 1700

## Alcance

Validación estadística de [[generateColoredNoise]] usando la PSD bilateral medida sobre el pretrigger de los primeros 3000 registros del canal 24:

```text
data/DAPHNE/FBK_SiPM/vgain_1700/channel_24.7z
```

Se sustrae la mediana por registro y se estima la PSD con ventana rectangular para mantener la convención espectral exacta del generador.

## Convención

```text
samplePeriod:   16 ns
sampleCount:    300
PSD:            bilateral, orden FFT, ADU^2/Hz
ensemble:       3000 registros generados
seed local:     1700
```

La comparación se realiza sobre la PSD promedio del ensemble. No se exige coincidencia bin a bin de una realización individual.

## Resultados

```text
logPsdCorrelationPositiveNonDc: 0.9999246
relativePsdL2Error:             0.025861
measuredRms:                    4.4199 ADU
generatedRms:                   4.4003 ADU
```

La correlación se calcula en bins positivos no DC y el error L2 sobre la PSD bilateral completa.

## Artefactos para revisión

```text
outputs/validation/colored-noise-daphne-fbk-vgain-1700/
├── measured-psd-colored-noise-validation.png
├── measured-psd-colored-noise-validation.fig
├── measured-vs-generated-psd.csv
└── colored-noise-validation-metrics.json
```

El gráfico compara PSD medida/generada y tres pares de registros temporales con color emparejado y estilo sólido/discontinuo. La segunda revisión visual no encontró defectos significativos.

## Reproducción

```matlab
r = runtests( ...
    'tests/integration/TestDaphneVgain1700Tasks6To10Validation.m');
assertSuccess(r)
```

## Interpretación

La prueba demuestra reproducción estadística de una PSD medida bajo esta adquisición. No convierte la PSD en un modelo físico universal de la electrónica ni elimina la necesidad de validar otras configuraciones, canales y condiciones de ruido.
