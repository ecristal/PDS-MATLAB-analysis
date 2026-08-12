# `pds.preprocess.estimatePedestal`

Estado: primer tracer bullet de la fase de pedestal.

## Contrato actual

```matlab
[level, diagnostics] = pds.preprocess.estimatePedestal( ...
    waveforms, SampleIndices=1:100, Method="mean");
```

- Filas: eventos.
- Columnas: muestras.
- Un vector fila representa un único waveform; un vector columna multielemento se rechaza por ser ambiguo bajo el contrato `evento × muestra`.
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

`sampleNoiseSigma` describe la dispersión de muestras: desviación estándar para la media y MAD escalada, centrada en la mediana de las muestras, para métodos robustos. Para `mean`, `pedestalStandardError = sampleNoiseSigma/sqrt(N)` presupone muestras efectivamente independientes; la correlación temporal reduciría el tamaño efectivo. Para `median`, la aproximación añade el factor asintótico gaussiano `sqrt(pi/2)` y usa la MAD calibrada a Gauss; no es autoritativa fuera de esos supuestos. Para `median-of-means` se devuelve `NaN`: todavía no se asigna una incertidumbre autoritativa hasta validar por cobertura sintética una formulación basada en bloques. Ninguna de estas cantidades representa la anchura de un pico de pedestal entre eventos.

## Evidencia inicial — 2026-08-11

- RED observado: `MATLAB:undefinedVarOrClass` antes de crear la API.
- Pruebas focalizadas del pedestal: 16/16 passed (8 estimación + 3 sustracción + 5 caracterización legacy), 0 failed, 0 incomplete.
- Suite completa: 90/90 passed, 0 failed, 0 incomplete.
- `checkcode` focalizado: 0.

## Pendiente

Flags de contaminación/deriva, validación de cobertura de incertidumbre, comparación sintética, generador IIR/ruido y posterior integración conservadora.
