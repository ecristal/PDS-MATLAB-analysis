---
type: validation
status: exploratory
tags: [daphne, pedestal, quality, validation]
---

# Diagnósticos de pedestal DAPHNE FBK SiPM VGAIN 1700

## Alcance

Validación exploratoria de [[estimatePedestal]] sobre los primeros 3000 registros del canal 24 de:

```text
data/DAPHNE/FBK_SiPM/vgain_1700/channel_24.7z
```

Cada registro tiene 2048 muestras; se usan las primeras 300 como pretrigger. Los datos no se versionan y se extraen únicamente a un directorio temporal durante el test.

## Configuración

```text
Method:                       median
MinimumQualitySampleCount:    8
NonstationarityThreshold:     3
OutlierThreshold:             3.5
MaximumOutlierFraction:       0.10
QualityBlockCount:            4
BlockLocationThreshold:       3
BlockScaleRatioThreshold:     3
```

Estos thresholds son parámetros diagnósticos explícitos de esta validación. No son calibraciones físicas universales.

## Resultados

```text
recordCount:                       3000
medianPedestal:                    7549 ADU
medianSampleNoiseSigma:            4.4478 ADU
validEventFraction:                0.78433
insufficientSamples fraction:      0
nonstationaryBaseline fraction:    0.00200
pretriggerContaminated fraction:   0.21433
excessiveOutliers fraction:        0.00100
unstableBlocks fraction:           0.01467
```

`pretriggerContaminated` significa que existe al menos una muestra cuyo residual detrendido excede el threshold robusto. No implica que esa fracción de las adquisiciones deba descartarse automáticamente. `validEventMask` es un resumen conservador de los flags bajo esta configuración.

La pendiente y los residuales se obtienen mediante detrending robusto IRLS con
pesos Tukey-bisquare. Frente al ajuste OLS transitorio usado durante desarrollo,
el pedestal mediano y la escala de ruido permanecen iguales; cambian las
fracciones observacionales de flags porque spikes aislados ya no sesgan la
pendiente antes de evaluar contaminación.

## Artefactos para revisión

```text
outputs/validation/pedestal-daphne-fbk-vgain-1700/
├── pedestal-quality-diagnostics.png
├── pedestal-quality-diagnostics.fig
├── pedestal-event-diagnostics.csv
└── pedestal-quality-metrics.json
```

El PNG/FIG muestra distribución de pedestal, escala robusta de ruido, pendiente, fracción de outliers y fracciones de flags. La segunda revisión visual confirmó labels, orden de flags y anotaciones legibles.

## Reproducción

```matlab
r = runtests( ...
    'tests/integration/TestDaphneVgain1700Tasks6To10Validation.m');
assertSuccess(r)
```

La prueba regenera únicamente su propia carpeta bajo `outputs/validation/`.

## Interpretación

Este conjunto puede estar afectado por ruido externo y su comportamiento depende de VGAIN y configuración electrónica. Los resultados sirven para revisar la utilidad de los diagnósticos, no para fijar thresholds globales ni seleccionar todavía un estimador final.
