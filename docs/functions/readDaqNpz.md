---
title: pds.io.readDaqNpz
type: matlab-function
status: active
review_mode: runtime
repo_path: src/+pds/+io/readDaqNpz.m
tags: [matlab, io, daq, daphne]
---

[Código fuente MATLAB](../../src/+pds/+io/readDaqNpz.m)

```matlab
[data, mean_data, Tm, info] = pds.io.readDaqNpz(filename, channel)
```

Importa un canal legacy FPGA de un archivo de calibración DAQ NPZ
`pds.calibration.step.v1`, frame v4, 256 muestras, ADC de 14 bits y 62,5 MHz.
Usa MATLAB sin dependencias Python; no lee HDF5 ni binarios DAQ crudos.

- `data`: matriz `double`, waveform × muestra; valores ADC sin corregir.
- `mean_data`: promedio de las filas seleccionadas.
- `Tm`: 16 ns, validado contra el recibo.
- `info`: canal FPGA, canales disponibles, módulo y canal panel, índices de filas
  originales, timestamps `uint64`, tiempo relativo en segundos, stream IDs,
  timing tags, continuation, metadatos decodificados y JSON original.

No cambia polaridad, pedestal, recorte ni orden de las filas. Comprueba esquema,
arrays, conteos, rango ADC y monotonía temporal. No comprueba SHA-256: usar
`tools/inspect_daq_npz.py` para auditar la colección completa. El helper privado
NPY soporta únicamente los tipos numéricos/Unicode necesarios para esta entrega;
no es un lector NumPy de propósito general.

Ver `docs/workflows/daq-npz-import.md` para formato, mapa de canales, barrido, ejemplos de
importación y validación. Tests: `tests/TestReadDaqNpz.m` y
`tests/integration/TestDaqNpzReference.m`.
