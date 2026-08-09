---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/daphne/import_data_daphne_func.m
source_path: Scripts_analisis/daphne/import_data_daphne_func.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, io, waveform, daphne]
---

# import_data_daphne_func

## Descripción cualitativa

Importa un stream plano de muestras DAPHNE desde un `.dat`, lo reorganiza en una matriz waveform × muestra y calcula el waveform promedio.

## Firma

```matlab
function [data, mean_data, Tm] = import_data_daphne_func( ...
    ch, waveforms_length, data_type, data_type_2, endianess, save_file, extract, filename_)
```

## Responsabilidad dentro del workflow

Es el lector de bajo nivel utilizado por [[extract_and_import_DAPHNE_data]].

## Entradas y salidas

- `ch`: canal usado para construir `channel_<ch>` cuando `extract` es verdadero.
- `waveforms_length`: muestras por waveform.
- `data_type`: selector lógico entre texto y binario.
- `data_type_2`: precisión pasada a `fread`.
- `endianess`: argumento de máquina para `fread`.
- `save_file`: habilita guardado `.mat`.
- `extract`, `filename_`: controlan la base del nombre.
- Devuelve matriz `data`, media por columna `mean_data` y `Tm = 1/62.5e6 s`.

## Algoritmo o procedimiento

1. Determina el nombre base.
2. Lee texto con `importdata` o binario con `fopen`/`fread`.
3. Calcula el número entero de waveforms.
4. Aplica `reshape` y transpone a filas por waveform.
5. Calcula la media.
6. Opcionalmente guarda `data`, `mean_data` y `Tm`.

## Dependencias

Funciones MATLAB de IO y manipulación matricial. Es llamada por [[extract_and_import_DAPHNE_data]].

## Efectos secundarios y rutas hard-coded

- Lee un archivo `.dat`.
- Puede escribir un `.mat` en el directorio derivado del nombre base.
- Usa un período fijo correspondiente a 62.5 MHz.

## Riesgos y limitaciones

- La llamada observada `fread(file,data_type_2,endianess)` no coincide con el contrato habitual `fread(fileID,sizeA,precision,skip,machinefmt)`: el tipo numérico ocupa la posición de tamaño y `'l'` la de precisión. Es una incompatibilidad estática crítica que debe comprobarse/corregirse en una fase posterior autorizada.
- `split(filename,'.')` conserva solo el primer segmento; rutas o nombres con puntos pueden truncarse.
- En modo `extract`, ignora `filename_` y depende de `channel_<ch>.dat` en `pwd`.
- No valida `fopen` ni protege `fclose` mediante cleanup si la lectura falla.
- Si la cantidad de muestras no es múltiplo de `waveforms_length`, `floor` no elimina el remanente y `reshape` falla; también falla con menos de un waveform completo.
- Los nombres `data_type` y `data_type_2` son ambiguos.
- `Tm` está hard-coded y no se obtiene de metadatos.

## Destino provisional en el paquete

Candidato a `+pds/+io/readDaphneDat.m`, con ruta explícita, validación de tamaño, sample rate configurable y opciones nominales.

## Evidencia y grado de certeza

- **Observado:** lectura, reshape, promedio, guardado opcional y sample rate fijo.
- **Inferido:** cada waveform ocupa un bloque contiguo de longitud constante.
- **Desconocido:** encabezados, padding, rango ADC y formatos numéricos oficiales.

## Preguntas pendientes

- ¿Todos los datos DAPHNE usan 62.5 MHz?
- ¿Qué tipos y endianness corresponden a cada firmware/formato?
- ¿Qué debe ocurrir con muestras sobrantes o archivos vacíos?

## Enlaces

- [[extract_and_import_DAPHNE_data]]
- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
