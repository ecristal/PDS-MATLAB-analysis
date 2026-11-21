---
type: data-import-workflow
status: validated
review_mode: runtime
tags: [daq, daphne, numpy, matlab, calibration]
---

# Importación DAQ — calibración November 2026

El DAQ constituye una fuente adicional para el análisis. Esta entrega contiene
waveforms ya extraídos y decodificados en NPZ; no requiere abrir los HDF5 del DAQ,
los binarios de adquisición ni instalar Waffles. Se conserva la procedencia en
los metadatos. El nuevo lector [[readDaqNpz]] entrega el contrato existente:
`data(evento,muestra)`, `mean_data` y `Tm`.

## Colección y auditoría

Directorio inspeccionado el 7 de noviembre de 2026:

```text
C:\Users\e_cri\OneDrive\Documents\INFN\ColdBoxVD\NOVEMBER2026_RUN\calibration\daq\presentation-vgain-fine-20261106
```

- 314 archivos `step-000.npz` a `step-313.npz`; 2.927.597.959 bytes comprimidos.
- `manifest.json`: tamaño, SHA-256 del NPZ, SHA-256 del binario de origen,
  etiqueta y conteos por canal. Los dos hashes corresponden a archivos diferentes.
- 9.743.808 waveforms de 256 muestras: 2.494.414.848 valores ADC.
- 123 pasos `pedestal_alignment` y 191 pasos `physics`.
- 37 valores VGAIN distintos, entre 500 y 2450. El barrido omite 1000, 1500
  y 2000; no es una rejilla completa de paso 50.
- Por grupo nominal: un dark de ocho canales y cuatro adquisiciones LED
  de dos canales, con 15.000 waveforms por canal. La alineación usa 512.
- El paso 000 es un dark con offsets originales. Los pasos 304–313 repiten
  VGAIN 500 al final, con nueva alineación: no combinar por etiqueta o VGAIN
  sin conservar `step_id`, offsets y orden de adquisición.

La auditoría completa comprobó tamaños y SHA-256 de **314/314** NPZ, dimensiones,
tipos, límites ADC, conteos y correspondencia entre manifiesto y recibos.
No encontró timestamps repetidos o decrecientes por canal: todos los intervalos
fueron de 1024 ticks. Todas las banderas `continuation` fueron falsas y los
`timing_tags` fueron 2. Esta comprobación verifica la entrega y su consistencia;
no vuelve a decodificar el HDF5 original.

## Estructura de cada NPZ

Un NPZ es un ZIP de arrays NPY. Abrirlo como un stream plano `.dat` o pasar por
`getDataFromWafflesPickleFile` no corresponde a este formato.

| Array | Tipo NumPy / MATLAB | Forma y significado |
| --- | --- | --- |
| `adc` | `uint16` | `N × 256`, una waveform por fila, valores de 14 bits: 0–16383 |
| `channels` | `uint8` | `N`, canal FPGA de cada fila |
| `timestamps` | `uint64` | `N`, ticks absolutos del reloj de 62,5 MHz |
| `stream_ids` | `uint8` | `N`, identificador del stream: 0 o 65 en esta colección |
| `timing_tags` | `uint8` | `N`, etiqueta de temporización |
| `continuation` | `bool` / `logical` | `N`, indicador de continuación del frame |
| `metadata_json` | Unicode escalar | JSON con recibo, configuración y mapa físico |

Los NPY de ADC observados usan `fortran_order=True`: el lector debe respetarlo.
Las filas de diferentes canales están intercaladas; `N` cuenta waveforms de
canal, no eventos multicanal. Para buscar coincidencias se deben cotejar los
timestamps de cada canal, en vez de asumir que filas independientes coinciden.

`metadata_json.receipt` registra `pds.calibration.step.v1`, frame v4,
`clock_hz`, `adc_bits`, `samples_per_frame`, `run`, `step_id`, `role`,
`coordinates`, offsets por canal, iluminación, conteos aceptados y procedencia
del HDF5/binario. El mapa físico está en `module_by_firmware_channel`.

## Numeración de canales

La entrada del lector es siempre el canal **legacy FPGA**, conforme al recibo.
El mapa observado, específico de esta adquisición, es:

| Canal FPGA | Canal panel | Canal físico | Stream |
| --- | --- | --- | --- |
| 0 | 0 | M2_CH1 | 0 |
| 1 | 1 | M2_CH2 | 0 |
| 2 | 2 | M1_CH1 | 0 |
| 3 | 3 | M1_CH2 | 0 |
| 24 | 16 | M5_CH1 | 65 |
| 25 | 17 | M5_CH2 | 65 |
| 26 | 18 | M6_CH1 | 65 |
| 27 | 19 | M6_CH2 | 65 |

No hay waveforms de M3/M4 en esta entrega. No trasladar automáticamente los
números de canal de las campañas anteriores a esta adquisición.

## Tiempo y precisión

- `Tm = 1/62.5e6 = 16 ns`; 256 bins cubren 4,096 µs. Los centros de muestras
  pueden representarse como `(0:255)*Tm`, con la última a 4,080 µs.
- Separación nominal entre frames de un canal: 1024 ticks = 16,384 µs,
  equivalente a 61.035,15625 waveforms/s. No confundirla con la frecuencia ADC.
- Hay una separación entre ventanas: no concatenarlas como una señal continua
  para calcular espectros. Procesar cada waveform respetando su ventana.
- Los timestamps son del orden de `1.12e17`, mayores que `flintmax`. Convertir
  el timestamp absoluto a `double` pierde ticks. Restar primero en `uint64`:
  `double(info.timestamps-info.timestamps(1))*Tm`.
- `info.metadata` usa `jsondecode`, que representa números JSON como `double`.
  Para tiempo exacto usar `info.timestamps`; el texto JSON original también
  se conserva en `info.metadataJson`.

## Importación MATLAB

```matlab
setupPDSAnalysisPath;
root = "C:\Users\e_cri\OneDrive\Documents\INFN\ColdBoxVD\NOVEMBER2026_RUN\calibration\daq\presentation-vgain-fine-20261106";

% VGAIN 1700, M1_CH1 con LED 780; FPGA channel 2.
[data, mean_data, Tm, info] = pds.io.readDaqNpz( ...
    fullfile(root, "step-188.npz"), 2);

% Dark del mismo grupo, mismo canal.
[dark, mean_dark, ~, darkInfo] = pds.io.readDaqNpz( ...
    fullfile(root, "step-187.npz"), 2);

t_us = (0:size(data,2)-1)*Tm*1e6;
plot(t_us, mean_data); xlabel('Tiempo [us]'); ylabel('ADC');

% Guardado opcional para scripts que cargan directamente un MAT:
save('M1_CH1_vgain1700_daq.mat', 'data', 'mean_data', 'Tm', 'info', '-v7.3');
```

El lector usa solo MATLAB. Extrae los NPY en un directorio temporal y lo elimina
al terminar; conserva el orden original de las filas seleccionadas. Devuelve
ADC como `double` para los algoritmos existentes, timestamps como `uint64`,
los demás arrays por fila y los metadatos completos. Un canal ausente genera
un error con los canales disponibles. Valida el esquema específico, tipos,
dimensiones, rango, conteos y orden temporal. La comprobación SHA-256 completa
se realiza con la herramienta de auditoría, no en cada importación.

## Preparación para el análisis

Los 256 puntos son más cortos que las capturas históricas de 1024/2048 puntos.
Revisar las ventanas de pedestal, integración, shaping y templates: una ventana
legacy de 300 muestras no cabe aquí. Deben definirse para estos datos antes de
comparar SNR o aplicar el filtro óptimo. El lector conserva pedestal y polaridad.

Como diagnóstico inicial, a VGAIN 500 los máximos del promedio iluminado de los
ocho canales aparecen en las muestras 150–168, con excursiones positivas de
aproximadamente 110–169 ADC respecto de la media de las medianas por waveform
en las primeras 32 muestras. Esto muestra respuesta temporal al LED en los
canales registrados; no establece una calibración single-P.E. ni una ventana
de pedestal definitiva. El CSV incluye estos diagnósticos para todos los pasos.

Existen waveforms con muestras en 0/16383. La máxima fracción por canal/paso es
4,30% en una alineación; entre pasos `physics`, 1,69% en el dark inicial sin
alinear. La entrega y el lector las conservan. Cuantificar el recorte por canal
y punto antes de decidir su selección; el CSV distingue fracción de muestras
y fracción de waveforms que tocan los límites.

Comparar dark y LED del mismo VGAIN y grupo de adquisición, preservando los
offsets y condiciones del recibo. No incorporar pasos `pedestal_alignment` al
ajuste de física. La entrega declara VD nominal +4 V, gain 1, ajustes de offsets
y atenuación por punto; el estado físico de potencia SoF no fue verificado de
forma independiente y los ajustes LED constan como provisionales.

## Reproducción y evidencia

```powershell
& 'C:\Users\e_cri\miniconda3\python.exe' tools/inspect_daq_npz.py `
  'C:\Users\e_cri\OneDrive\Documents\INFN\ColdBoxVD\NOVEMBER2026_RUN\calibration\daq\presentation-vgain-fine-20261106' `
  outputs/daq/presentation-vgain-fine-20261106
```

Requiere NumPy; usa `allow_pickle=False`. Genera `summary.json` y `steps.csv`
en `outputs/daq/presentation-vgain-fine-20261106/` (productos locales ignorados
por Git). El CSV tiene una fila por paso/canal; sus timestamps deben importarse
como enteros de 64 bits o texto, evitando su conversión automática a `double`.
El intérprete `python` predeterminado de esta sesión no tiene NumPy; el de
Miniconda indicado arriba sí lo tiene.

Validación MATLAB R2025b: **14/14 tests aprobados** (11 unitarios y 3 de
integración con datos reales), 0 fallos y 0 incompletos. `checkcode` devolvió
0 mensajes para el lector, su helper privado y ambos archivos de tests.

```matlab
results = runtests('tests/TestReadDaqNpz.m');
assertSuccess(results);
setenv('PDS_DAQ_REFERENCE_DIR', root);
results = runtests('tests/integration/TestDaqNpzReference.m');
assertSuccess(results);
```

Los tests sintéticos cubren orientación C/Fortran, ambos endianness, precisión
de timestamps por encima de `2^53`, selección de canal y rechazo de archivos
inconsistentes. La comprobación cruzada MATLAB/NumPy del paso 006, canal 2,
coincidió exactamente en sus **3.840.000 valores ADC**, 15.000 timestamps,
filas de origen y arrays auxiliares, además del promedio y `Tm`.
