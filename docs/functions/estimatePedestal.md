# `pds.preprocess.estimatePedestal`

Estado: primer tracer bullet de la fase de pedestal.

## Contrato actual

```matlab
[level, diagnostics] = pds.preprocess.estimatePedestal( ...
    waveforms, SampleIndices=1:100, Method="mean");
```

- Filas: eventos.
- Columnas: muestras.
- `SampleIndices` es obligatorio, estrictamente creciente y define explícitamente la región temporal de pedestal.
- Entradas enteras se convierten a `double` después de validarse; valores `int64`/`uint64` fuera del rango entero exacto de `double` se rechazan explícitamente.
- Salida `level`: columna `evento × 1`, en las mismas unidades lineales de entrada.
- Métodos implementados: `"mean"`, `"median"` y `"median-of-means"`.
- `"median-of-means"` exige `BlockSize` como divisor entero de la cantidad de muestras para mantener bloques deterministas, no solapados y de igual tamaño.

## Diagnósticos

```text
method
sampleIndices
sampleCount
sampleNoiseSigma
pedestalStandardError
blockSize
blockCount
blockMeans
```

`sampleNoiseSigma` describe la dispersión de muestras: desviación estándar para la media y MAD escalada para métodos robustos. `pedestalStandardError` es una aproximación dependiente del método y todavía debe validarse por cobertura sintética; ninguna de estas cantidades representa la anchura de un pico de pedestal entre eventos.

## Evidencia inicial — 2026-08-11

- RED observado: `MATLAB:undefinedVarOrClass` antes de crear la API.
- Pruebas focalizadas: 14/14 passed, 0 failed, 0 incomplete.
- Suite completa: 88/88 passed, 0 failed, 0 incomplete.
- `checkcode` focalizado: 0.

## Pendiente

Flags de contaminación/deriva, validación de cobertura de incertidumbre, comparación sintética, generador IIR/ruido y posterior integración conservadora.
