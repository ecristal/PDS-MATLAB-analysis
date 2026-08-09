---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/getDataFromWafflesPickleFile.m
source_path: Scripts_analisis/data/getDataFromWafflesPickleFile.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, python, pickle, waffles, io]
---

# getDataFromWafflesPickleFile

## Descripción cualitativa

Carga mediante la interfaz Python de MATLAB un pickle de waffles, busca dos canales dentro de cada conjunto de waveforms y devuelve ADCs y metadatos alineados por timestamp/endpoint.

## Firma

```matlab
function [signal1, signal2, timestamp, channels, endpoint] = ...
    getDataFromWafflesPickleFile(channel_1, channel_2, pickle_file)
```

## Algoritmo o procedimiento

1. Inicializa Python e importa `waffles.data_classes.Waveform` y `pickle`.
2. Abre y deserializa el archivo.
3. Convierte la lista Python a celda MATLAB.
4. Preasigna dos matrices de 1024 muestras y metadatos.
5. Exige 40 waveforms por elemento.
6. Busca ambos canales y convierte ADCs/timestamps/endpoint.
7. Verifica presencia, timestamp coincidente y endpoint coincidente.

## Dependencias

Python configurado en MATLAB, paquete `waffles` importable y módulo estándar `pickle`.

## Efectos secundarios

Abre un archivo Python; el handle no se cierra explícitamente. La deserialización pickle ejecuta el protocolo Python y solo debe realizarse con archivos confiables.

## Supuestos, unidades y dimensiones

- Exactamente 40 waveforms por set y 1024 muestras por canal.
- ADCs se convierten a `int16` y finalmente se almacenan como `double`.
- Canales y endpoints se almacenan en `int8`; timestamps en `int64`.

## Riesgos y limitaciones

- Pickle no es seguro para contenido no confiable.
- Tamaños 40/1024 están hard-coded.
- `int8` puede desbordar identificadores mayores que 127.
- Si existen duplicados de canal, conserva la última coincidencia.
- Preasigna una fila por set aunque falten canales; en ese caso termina con `assert`.
- El archivo queda abierto hasta que Python lo libere.

## Destino provisional en el paquete

Candidato a `+pds/+io/readWafflesPickle.m`, aunque convendría considerar exportar desde Python a un formato interoperable y seguro.

## Evidencia y grado de certeza

- **Observado:** integración Python, asserts, tamaños y conversiones.
- **Inferido:** cada elemento representa un evento con múltiples canales sincronizados.
- **Desconocido:** versión de waffles/pickle y esquema oficial de los objetos.

## Preguntas pendientes

- ¿Debe reemplazarse pickle por HDF5/NPY/Parquet u otro formato estable?
- ¿Todos los endpoints/canales caben en `int8`?
- ¿La longitud 1024 es configurable en otras campañas?

## Enlaces

- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
- [[MATLAB_SCRIPT_CATALOG]]
