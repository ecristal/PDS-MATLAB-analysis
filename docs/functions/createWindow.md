---
title: pds.signal.createWindow
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/createWindow.m
tags: [matlab, window, tukey, hann, hamming]
---

[Código fuente MATLAB](../../src/+pds/+signal/createWindow.m)

Genera ventanas espectrales sin requerir funciones de toolbox. Los vectores numéricos personalizados, `sampleCount` y `TukeyRatio`, incluidas clases enteras, se validan y convierten a `double`.

## Firma

```matlab
window = pds.signal.createWindow(N, specification, TukeyRatio=0.1)
```

## Ventanas soportadas

- `"rectangular"` o `"none"`;
- `"tukey"`;
- `"hann"`;
- `"hamming"`;
- vector numérico personalizado de N elementos.

## Tukey

`TukeyRatio` pertenece a `[0,1]`:

- 0 produce una ventana rectangular;
- 1 coincide con Hann;
- valores intermedios conservan una región central plana y suavizan los extremos.

```matlab
w = pds.signal.createWindow(2048, "tukey", TukeyRatio=0.25);
```

## Uso físico

- Para PSD, la corrección de potencia es `sum(window.^2)`; [`estimateNoisePsd`](estimateNoisePsd.md) la aplica automáticamente.
- Ventanear una plantilla modifica su forma. [`designOptimalFilter`](designOptimalFilter.md) no aplica una ventana a la señal de referencia silenciosamente.
- La ventana apropiada depende de estacionariedad, discontinuidades en bordes y fuga espectral.

## Evidencia

`TestCreateWindow`: 6 tests runtime para simetría, límites Tukey, ventana numérica, conversión de datos y opciones escalares enteras, y validación. Una comparación ad hoc contra `tukeywin`, `hann` y `hamming` de MATLAB obtuvo error máximo `1.9984e-15`.

## Enlaces

- [`estimateNoisePsd`](estimateNoisePsd.md)
- [`forwardDft`](forwardDft.md)
- [`designOptimalFilter`](designOptimalFilter.md)
