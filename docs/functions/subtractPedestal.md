---
title: pds.preprocess.subtractPedestal
repo_path: src/+pds/+preprocess/subtractPedestal.m
---

[Código fuente MATLAB](../../src/+pds/+preprocess/subtractPedestal.m)

Sustrae niveles de pedestal ya conocidos sin volver a estimarlos.

```matlab
corrected = pds.preprocess.subtractPedestal(waveforms, pedestalLevel);
```

- Filas: eventos; columnas: muestras.
- `pedestalLevel` puede ser escalar o contener un valor por evento.
- Convierte entradas enteras a `double` antes de sustraer para evitar underflow/wrap; valores `int64`/`uint64` fuera del rango entero exacto de `double` se rechazan.
- No consulta el pretrigger, no estima ruido y no descarta eventos.

## Evidencia inicial — 2026-08-11

- RED observado: función inexistente.
- GREEN: caso `uint16` con residual negativo reproducido exactamente.
- Incluida en 16/16 pruebas focalizadas del pedestal (8 estimación + 3 sustracción + 5 caracterización legacy) y 90/90 pruebas completas.
- `checkcode` focalizado: 0.
