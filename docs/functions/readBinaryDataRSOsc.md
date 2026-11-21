---
title: readBinaryDataRSOsc
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/readBinaryDataRSOsc.m
source_path: Scripts_analisis/data/readBinaryDataRSOsc.m
workflow:
  - "docs/workflows/analysis_daphne_data.md"
tags: [matlab, io, oscilloscope, rohde-schwarz, xml]
---

[Código fuente MATLAB](../../src/data/readBinaryDataRSOsc.m)

## Descripción cualitativa

Lee un par de archivos de osciloscopio Rohde & Schwarz: un encabezado XML y un binario de waveforms. Extrae metadatos por posiciones fijas del árbol XML, decodifica el tipo numérico y devuelve una estructura con waveforms recortados y media.

## Firma

```matlab
function data = readBinaryDataRSOsc(dataInfo_filename, dataWaveform_filename)
```

## Algoritmo o procedimiento

1. Parsea XML con [`xmltools`](xmltools.md).
2. Extrae record lengths, resolución, formato, impedancia y muestras de settling mediante índices de hijos/atributos.
3. Deriva el tipo para `fread` desde el string de formato.
4. Lee el binario, descarta las dos primeras palabras y calcula cantidad de waveforms.
5. Aplica `reshape` y recorta settling inicial/final.
6. Calcula waveform medio.

## Dependencias

Local: [`xmltools`](xmltools.md). MATLAB: IO binario, strings, reshape y mean.

## Efectos secundarios

Abre y cierra archivos de entrada. No escribe resultados.

## Supuestos, unidades y dimensiones

- `Resolution` se interpreta en `docs/workflows/analysis_daphne_data.md` como período temporal.
- Todos los records tienen igual longitud.
- El binario contiene dos valores iniciales a descartar.

## Riesgos y limitaciones

- El acceso XML por índices como `child(67).attribs(5)` es extremadamente sensible a cambios de versión/orden del schema.
- No comprueba `fopen` ni divisibilidad del payload por record length.
- No especifica endianness en `fread`.
- `NumberOfWaveforms` puede no ser entero y provocar error en `reshape`.
- No valida que el recorte deje `SignalRecordLength` muestras.

## Destino provisional en el paquete

Candidato a `+pds/+io/readRsOscilloscopeBinary.m`, con parser por nombre de tag/atributo y validación explícita de schema.

## Evidencia y grado de certeza

- **Observado:** campos extraídos, lectura binaria, descarte, reshape y recorte.
- **Inferido:** archivos generados como pareja `.bin`/`.Wfm.bin` por un osciloscopio R&S.
- **Desconocido:** modelo/versión de firmware, schema y endianness oficiales.

## Preguntas pendientes

- ¿Qué representan las dos primeras palabras descartadas?
- ¿Existe documentación formal del XML de R&S?
- ¿El formato puede incluir canales intercalados?

## Enlaces

- [`xmltools`](xmltools.md)
- `docs/workflows/analysis_daphne_data.md`
- `docs/dependency-maps/analysis_daphne_data_dependencies.md`
