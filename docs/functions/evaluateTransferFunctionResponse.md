---
type: matlab-function
status: validated
tags: [identification, metrics, validation, matlab]
---

# `pds.identification.evaluateTransferFunctionResponse`

Compara una respuesta objetivo y una predicción usando métricas separadas del fit de identificación.

```matlab
metrics = pds.identification.evaluateTransferFunctionResponse( ...
    target, prediction, SampleTime=16e-9, ...
    TailStartIndex=1201, ReturnBand=0.01, ...
    ReturnConsecutiveSamples=10);
```

Métricas:

- amplitud e índice del pico;
- error de amplitud y timing del pico;
- mínimo de signo opuesto post-pico e índice;
- área negativa post-pico, usando el pico objetivo como frontera común;
- área negativa total, reportada por separado para conservar residuales pre-pico;
- RMSE global y de cola;
- amplitud al final del registro;
- primera entrada durante N muestras consecutivas en la banda;
- asentamiento que permanece en la banda hasta el final.

La API distingue:

```text
ReturnedToBand  = primera permanencia local de N muestras
SettledToBand   = desde el índice reportado, todo el resto permanece en banda
```

Si el registro termina antes de observar el criterio, el booleano es `false` y el índice/tiempo es `NaN`. Esto evita interpretar una entrada transitoria como retorno permanente.

`negativeAreaStartIndex` es el índice del pico objetivo. Los campos
`targetNegativeArea` y `predictedNegativeArea` integran desde esa frontera común
hasta el final; `targetTotalNegativeArea` y `predictedTotalNegativeArea` integran
el registro completo.

El undershoot se mide sobre el waveform proporcionado, sin suavizado implícito. En la validación DAPHNE se utiliza directamente el waveform promedio baseline-corregido y normalizado a 1 SPE.
