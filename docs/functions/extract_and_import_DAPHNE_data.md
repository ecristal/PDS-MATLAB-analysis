---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/daphne/extract_and_import_DAPHNE_data.m
source_path: Scripts_analisis/daphne/extract_and_import_DAPHNE_data.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, io, extraction, daphne]
---

# extract_and_import_DAPHNE_data

## Descripción cualitativa

Adaptador de entrada que acepta archivos DAPHNE `.dat`, `.dat.gz`/`.gz` o `.7z`, descomprime cuando corresponde y delega la lectura del contenido en [[import_data_daphne_func]].

## Firma

```matlab
function [data, mean_data, Tm] = extract_and_import_DAPHNE_data( ...
    ch, waveforms_length, filename, data_format, data_type, endianess, save_mat)
```

## Responsabilidad dentro del workflow

Es la ruta principal de ingestión de waveforms archivados para [[analysis_daphne_data]]. Oculta parcialmente la diferencia entre un `.dat` directo y un archivo comprimido.

## Entradas y salidas

- Entradas: canal, longitud de waveform, ruta, indicador de formato binario/texto, tipo numérico, endianness e indicador de guardado `.mat`.
- Salidas: matriz `data`, waveform medio `mean_data` y período de muestreo `Tm`, producidos por [[import_data_daphne_func]].

## Algoritmo o procedimiento

1. Determina la última extensión mediante `fileparts`.
2. Para `.7z`, llama al ejecutable externo 7-Zip y espera `channel_<ch>.dat` en el directorio actual.
3. Para `.gz`, usa `gunzip` y busca el `.dat` resultante.
4. Para `.dat`, importa directamente.
5. Delega la lectura y reshape.
6. Elimina el `.dat` temporal cuando hubo extracción.

## Dependencias

- Local: [[import_data_daphne_func]].
- MATLAB: `fileparts`, `gunzip`, `isfile`, `delete`, `system`.
- Externa: `C:\Program Files\7-Zip\7z.exe`.

## Efectos secundarios y rutas hard-coded

- Ejecuta un proceso externo.
- Escribe archivos temporales en el directorio de trabajo y luego los elimina.
- Contiene una ruta hard-coded a 7-Zip.
- La extracción `.7z` depende de `pwd` y de la convención `channel_<ch>.dat`.

## Supuestos, unidades y dimensiones

La función no interpreta unidades; presupone que `waveforms_length`, `data_type` y `endianess` describen correctamente el payload.

## Riesgos y limitaciones

- El nombre del archivo `.7z` no se entrecomilla explícitamente en el comando y puede fallar con espacios.
- No inspecciona el código de salida de 7-Zip.
- Extraer en `pwd` puede sobrescribir o borrar un archivo homónimo preexistente.
- La extensión `.gz` se asume compatible con un `.dat` resultante.
- Se mezclan extracción, política de archivos temporales e importación.

## Destino provisional en el paquete

Candidato a `+pds/+io/readDaphneArchive.m`, separando extracción segura, selección del archivo extraído y decodificación binaria.

## Evidencia y grado de certeza

- **Observado:** ramas `.7z`, `.gz`, `.dat`, llamada al importador y borrado temporal.
- **Inferido:** actúa como fachada principal para datos DAPHNE archivados.
- **Desconocido:** estructura permitida dentro de cada `.7z` y política ante múltiples canales.

## Preguntas pendientes

- ¿Cada archivo contiene exactamente un `channel_<ch>.dat`?
- ¿Debe extraerse siempre a un directorio temporal aislado?
- ¿Se necesita soportar rutas configurables de 7-Zip?

## Enlaces

- [[analysis_daphne_data]]
- [[import_data_daphne_func]]
- [[analysis_daphne_data_dependencies]]
