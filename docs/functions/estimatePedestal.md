---
title: pds.preprocess.estimatePedestal
repo_path: src/+pds/+preprocess/estimatePedestal.m
---

[Código fuente MATLAB](../../src/+pds/+preprocess/estimatePedestal.m)

Estado: API validada con diagnósticos de calidad de Tarea 6. Seguimiento global en
`docs/status/pedestal-estimation-refactor-status.md`.

## Uso

```matlab
[level, diagnostics] = pds.preprocess.estimatePedestal( ...
    waveforms, SampleIndices=1:300, Method="median");
```

- Filas: eventos.
- Columnas: muestras.
- `SampleIndices` define explícitamente la región de pedestal.
- `level` es una columna `evento × 1` en las unidades de entrada.
- Métodos: `"mean"`, `"median"` y `"median-of-means"`.
- `median-of-means` exige `BlockSize` entero que divida el número de muestras.
- La entrada se convierte a `double` solo después de validar enteros exactamente representables.

## Diagnósticos de estimación

```text
method, sampleIndices, sampleCount,
sampleNoiseSigma, pedestalStandardError,
blockSize, blockCount, blockMeans
```

`sampleNoiseSigma` es desviación estándar para `mean` y MAD escalada para métodos robustos. La incertidumbre de `median-of-means` permanece `NaN` hasta disponer de validación de cobertura.

## Diagnósticos de calidad

Opciones configurables:

```text
MinimumQualitySampleCount = 8
NonstationarityThreshold = 3
OutlierThreshold = 3.5
MaximumOutlierFraction = 0.10
QualityBlockCount = 4
BlockLocationThreshold = 3
BlockScaleRatioThreshold = 3
```

Todos los thresholds se registran en `diagnostics.thresholds`. La API devuelve:

```text
slopePerSample
outlierFraction
blockLocationScore
blockScaleRatio
qualityBlockMeans
qualityBlockScales
qualityFlags
validEventMask
```

Flags por evento:

```text
insufficientSamples
nonstationaryBaseline
pretriggerContaminated
excessiveOutliers
unstableBlocks
```

Reglas del contrato:

1. Los flags no cambian el pedestal estimado.
2. No se descartan eventos dentro del estimador.
3. `validEventMask` es el AND de los flags negados, pero todos los diagnósticos detallados se conservan.
4. La pendiente usa los índices temporales declarados y un ajuste robusto
   iteratively reweighted con pesos Tukey-bisquare; spikes aislados no cambian
   silenciosamente la tendencia reportada.
5. Los outliers se calculan sobre residuales detrendidos con escala robusta.
6. Los bloques diagnósticos consumen todas las muestras y son independientes de los bloques de `median-of-means`.
7. Una región de una muestra sigue siendo numéricamente segura y se marca insuficiente.

## Validación

Casos sintéticos deterministas cubiertos:

- pretrigger limpio;
- deriva lineal;
- step de baseline;
- spike aislado;
- pulso ancho contaminante;
- ruido heteroscedástico;
- región demasiado corta.

Validación DAPHNE local:

```text
outputs/validation/pedestal-daphne-fbk-vgain-1700/
```

Sobre los primeros 3000 registros del canal 24 y 300 muestras de pretrigger, con thresholds de validación explícitos (`3`, `3.5`, `0.10`, `4`, `3`, `3` en el orden documentado arriba):

```text
validEventFraction:              0.7843
pretriggerContaminated fraction: 0.2143
nonstationaryBaseline fraction:  0.0020
excessiveOutliers fraction:      0.0010
unstableBlocks fraction:         0.0147
median pedestal:                 7549 ADU
median sampleNoiseSigma:         4.4478 ADU
```

Estos valores son diagnósticos específicos de configuración, no una calibración ni thresholds físicos universales.
