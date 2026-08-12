# `pds.preprocess.subtractPedestal`

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
- Incluida en 14/14 pruebas focalizadas y 88/88 pruebas completas.
- `checkcode` focalizado: 0.
