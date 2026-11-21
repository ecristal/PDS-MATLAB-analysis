---
title: pds.io.DaphneWaveformReader
type: matlab-class
status: active
review_mode: runtime
repo_path: src/+pds/+io/DaphneWaveformReader.m
tags: [matlab, io, waveform, daphne, dma]
---

`pds.io.DaphneWaveformReader` abre un archivo binario DAPHNE de un canal y
devuelve una waveform por llamada. Cada waveform es una fila `uint16` con
los códigos ADC almacenados. Acepta archivos `.dat` con registros contiguos
de longitud fija, sin encabezados y en orden little-endian, o un `.7z` con
un miembro `.dat` del mismo nombre base. Por ejemplo, `channel_8.7z`
contiene `channel_8.dat`.

[Código fuente MATLAB](../../src/+pds/+io/DaphneWaveformReader.m)

## Ejemplo con las capturas largas de ColdBox

Abre MATLAB en la raíz del repositorio. Ajusta `archivo` a la ubicación
de `channel_8.7z` de la captura ColdBox.

```matlab
setupPDSAnalysisPath;

archivo = "channel_8.7z";

lector = pds.io.DaphneWaveformReader(archivo, SamplesPerWaveform=1e6);
disp(lector.WaveformCount);  % 200
wv = lector.read(100);       % Fila uint16 de 1.000.000 de muestras
lector.close();
```

Para recorrer el archivo en orden, sustituye la lectura por índice y el
cierre del ejemplo por este bloque. Procesa `wv` dentro del bucle para
reutilizar la misma variable en cada iteración.

```matlab
while lector.hasNext()
    [wv, indice] = lector.next();
    % Procesar wv e indice.
end
lector.close();
```

## Longitud y archivos auxiliares

`SamplesPerWaveform` admite un entero positivo y tiene prioridad sobre los
archivos auxiliares. Puedes usarlo con el `.7z` o `.dat` por sí solo. Si
omites la opción, el lector busca primero `capture_contracts.<canal>.samples`
en `dma_format.json` para un archivo llamado `channel_<canal>`, y luego una
entrada `waveform_length=<entero>` sin ambigüedad en `config.txt`. Busca
ambos archivos en la carpeta del archivo de entrada. Si la longitud no está
disponible, debes indicarla al abrir el lector.

El tamaño del `.dat` debe ser un múltiplo positivo de
`2 * SamplesPerWaveform` bytes. El lector calcula `WaveformCount` a partir
de ese tamaño. Si más de una longitud divide el tamaño, identifica la
correcta a partir de la configuración de adquisición.

## Métodos y propiedades

| API | Comportamiento |
| --- | --- |
| `read(indice)` | Lee una waveform por índice MATLAB, desde `1` hasta `WaveformCount`. La posición de `next()` se conserva. |
| `[wv, indice] = next()` | Lee la waveform en `NextIndex` y avanza el índice tras una lectura exitosa. Empieza en `1`. |
| `hasNext()` | Devuelve `true` si quedan waveforms disponibles para lectura secuencial. |
| `close()` | Cierra el archivo y elimina la copia temporal de la extracción, cuando corresponde. |
| `SamplesPerWaveform`, `WaveformCount`, `NextIndex` | Longitud de cada waveform, cantidad de waveforms en el archivo y próximo índice secuencial. |

## Memoria y extracción

Con un `.dat`, el lector salta directamente al registro y lee sus muestras.
Con un `.7z`, usa 7-Zip y la JVM de MATLAB para extraer el `.dat` una vez
por apertura. Las lecturas posteriores acceden a la copia temporal en disco.
Para el archivo del ejemplo son **400 MB de disco temporal** y **2 MB de datos
por waveform** en memoria. `TempDirectory` permite indicar una carpeta
existente en otra unidad. `SevenZipExecutable` permite indicar la ruta a
7-Zip cuando no se encuentra en la ubicación habitual de Windows ni en `PATH`.

## Validación

En MATLAB R2025b, `channel_8.7z` abrió como 200 waveforms de 1.000.000 de
muestras. Las waveforms 1, 100 y 200 coincidieron muestra por muestra con
el `.dat` leído directamente desde 7-Zip como `uint16` little-endian.
También se comprobó la apertura de `.dat` y `.7z` sin JSON con longitud
explícita, la lectura de `waveform_length` desde `config.txt`, el rechazo de
un tamaño incompatible y la limpieza de la extracción temporal.

## Funciones relacionadas

- [`pds.io.readDaqNpz`](readDaqNpz.md) importa waveforms de la calibración DAQ en formato `.npz`. El procedimiento figura en `docs/workflows/daq-npz-import.md`.
