# Reproducción del análisis ColdBox de noviembre de 2026

Abre MATLAB desde la raíz de PDS-MATLAB-analysis y ejecuta
`setupPDSAnalysisPath`. Los ejemplos requieren MATLAB R2025b,
Signal Processing Toolbox, Statistics and Machine Learning Toolbox y
Curve Fitting Toolbox. La ejecución con hilos usa Parallel Computing
Toolbox. Los registros DAPHNE se leen desde la carpeta de la campaña en
formato `.dat` o `.7z`. La lectura de `.7z` requiere 7-Zip.

## Barrido por módulo

En MATLAB, asigna a `runRoot` la carpeta de la campaña y selecciona un
módulo de `M1` a `M6`. El perfil lee los canales y los valores de Vbias
y Vgain de `runs/VGAIN_SCANS/<módulo>/scan_metadata.txt`. Usa los valores
de Vgain adquiridos entre 500 y 2500 DAC. `cfg.ShaperFile` apunta a
[`november2026_shaper.mat`](../../src/+pds/+coldbox/private/november2026_shaper.mat).
El archivo contiene los vectores `numz_planta_integrator` y
`denz_planta_integrator`, idénticos a `bHp` y `aHp` en el `pipeline.mat`
del RUN de referencia. El notch y el filtro pasa bajos se diseñan a
partir de los parámetros del barrido. `analyzeScan` también admite la ruta
a otro archivo de coeficientes para una campaña diferente.

```matlab
setupPDSAnalysisPath;
module = "M4";
cfg = pds.coldbox.november2026(runRoot,module);
out = fullfile(pwd,"outputs","coldbox-november-2026");

[summary, scanRun, performance] = pds.coldbox.analyzeScan( ...
    cfg.ScanRoot, cfg.ShaperFile, out, ...
    Vbias=cfg.Vbias, Vgain=cfg.Vgain, Channels=cfg.ScanChannels, ...
    SamplePeriod=cfg.SamplePeriod, AdcBits=cfg.AdcBits, Campaign=cfg.Campaign, ...
    UseParallel=true, MaxWorkers=0, BootstrapCount=100);
figureFolder = pds.coldbox.plotScanSummary(scanRun);
```

`MaxWorkers=0` usa el máximo que permiten el límite de CPU de MATLAB y el
número de puntos. El límite automático por memoria se aplica en Windows.
En Linux puedes fijar `MaxWorkers` según la RAM disponible. Con
`UseParallel=false` se ejecuta el mismo análisis por punto en serie.
Para una prueba corta, elige `Vbias=cfg.Vbias(1), Vgain=cfg.Vgain(1)`
y conserva `Channels=cfg.ScanChannels`.

El flujo genera `pipeline.mat`, `summary.csv`, archivos de tiempos, un
informe y seis figuras por punto en PNG y FIG. `point_results.mat` guarda
los identificadores y los cortes de eventos, las ventanas, el ajuste de
0 y 1 PE y las formas de onda promedio. Para un módulo con dos canales,
se generan seis figuras globales a partir de `summary.csv`. Los puntos
sin ajuste válido se muestran como huecos.

## Selección de filtros del barrido

Las cinco etapas están activas por defecto. Cada opción controla la etapa
en todas las rutas donde se usa.

| Opción | Ruta | Configuración |
|---|---|---|
| `UseTukey` | SNR | La ventana usa el inicio del pulso estimado. |
| `UseNotch` | Diagnóstico, SNR y promedio de 1 PE | `NotchFrequencyHz=10.0098e6` y `NotchQ=15` |
| `UseLowPass` | Diagnóstico y SNR | `LowPassHz=2e6` Hz, Butterworth de tercer orden |
| `UseIntegrator` | SNR | Coeficientes IIR de `cfg.ShaperFile` |
| `UseBoxcar` | SNR | `BoxcarLength=18` muestras en total |

Este ejemplo analiza M1 con el notch desactivado, un corte de 1.5 MHz
y un boxcar causal de 12 muestras.

```matlab
cfg = pds.coldbox.november2026(runRoot,"M1");
[summary, scanRun, performance] = pds.coldbox.analyzeScan( ...
    cfg.ScanRoot, cfg.ShaperFile, out, ...
    Vbias=cfg.Vbias, Vgain=cfg.Vgain, Channels=cfg.ScanChannels, ...
    SamplePeriod=cfg.SamplePeriod, AdcBits=cfg.AdcBits, Campaign=cfg.Campaign, ...
    UseNotch=false, UseLowPass=true, LowPassHz=1.5e6, ...
    UseBoxcar=true, BoxcarLength=12, UseParallel=true, MaxWorkers=4);
```

`BoxcarLength` incluye la muestra actual. La opción anterior
`BoxcarPastSamples` sigue contando solo las muestras previas. Indica
una de las dos opciones. Con `UseIntegrator=false` se admite `""`
como ruta al archivo de coeficientes.

`pipeline.mat` guarda la configuración y los coeficientes usados.
El informe registra las etapas activas. El reprocesamiento de resultados
guardados usa los mismos escalares y el mismo ajuste del notch para el
promedio de 1 PE. Para cambiar la cadena de procesamiento, vuelve a
ejecutar el barrido desde los archivos DAPHNE.

## Barrido de LPF y boxcar para maximizar el SNR

Ejemplo para M3 a Vbias 796 DAC. Cada archivo DAPHNE de cada Vgain y
canal se lee una sola vez. Cada corte Butterworth tiene sus propios vetos
y se comparte el resultado previo al boxcar entre todas las longitudes.
El ajuste de 0 y 1 PE calcula el SNR con las reglas del barrido estándar.
El notch es obligatorio en el sweep de M3.

```matlab
cfg = pds.coldbox.november2026(runRoot,"M3");
out = fullfile(pwd,"outputs","coldbox-snr-sweep");
[best,sweepRun,performance] = pds.coldbox.sweepSNR( ...
    cfg.ScanRoot,cfg.ShaperFile,out,(1:0.5:10)*1e6,10:30, ...
    Vbias=796,Vgain=500:100:2500,Channels=cfg.ScanChannels, ...
    SamplePeriod=cfg.SamplePeriod,AdcBits=cfg.AdcBits,Campaign=cfg.Campaign, ...
    UseNotch=true,UseParallel=true,MaxWorkers=4);
disp(best);
disp(sweepRun);
```

El ejemplo evalúa 399 combinaciones por Vgain y canal. Con los dos
canales de M3 son 16 758 ajustes de cuadrícula y una malla por
Vgain y canal. Para una prueba corta, usa `[1.5 2]*1e6`, `[12 18]`,
`Vgain=500` y `Channels=8`. En otros módulos, usa los valores del perfil
y el estado del notch que corresponda al estudio.

`snr_grid.csv` registra cada combinación, incluidos los ajustes sin
resolver. `best_snr.csv` registra el mayor SNR observado por Vbias,
Vgain y canal y marca los máximos en el borde de la cuadrícula.
En caso de empate, se elige el menor corte y luego el boxcar más corto.
La malla omite los ajustes sin resolver. La cuadrícula usa el estimador
estándar sin las réplicas bootstrap ni los ajustes de diagnóstico.
Para regenerar las figuras y los máximos desde el CSV guardado, ejecuta
`pds.coldbox.plotSNRSweep(sweepRun)`.

## Comparación de ruido electrónico

```matlab
noiseRoot = fullfile(runRoot,"runs","enoise");
labels = ["M3_M4","M3_M4_ENOISE_N50000_L2048_CRP_OFF"];
folders = [fullfile(noiseRoot,labels(1),"AFE1_vbias_19p4v","vbias_500","vgain_500"), ...
           fullfile(noiseRoot,labels(2),"vbias_500","vgain_500")];
channels = 8:11;
titles = ["M3","M3","M4","M4"] + " DAPHNE CH " + string(channels);
spectra = pds.coldbox.compareElectronicNoise( ...
    folders, fullfile(out,"enoise"), Labels=labels, ...
    Channels=channels, ChannelTitles=titles, RoiMHz=6, ...
    Subtitle="ColdBox November 2026 | Vbias 500 DAC | Vgain 500 DAC", ...
    SamplePeriod=16e-9, AdcBits=14);
```

La comparación resta la media de cada tramo, usa la misma longitud de FFT
en ambas tomas y promedia las amplitudes lineales antes de convertir a
dBFS. Para noviembre de 2026 son 100 000 tramos de 1024 muestras por
toma y canal, una referencia de 16 384 ADU y una marca de 6 MHz.

## Reprocesamiento y verificación

```matlab
% Reajustar los escalares guardados, con la semilla del barrido.
refit = pds.coldbox.reprocessScan(scanRun,fullfile(out,"refit"), ...
    Mode="histogram",Vbias=cfg.Vbias(1),Vgain=cfg.Vgain(1),Channels=cfg.ScanChannels(1));

% Regenerar las medidas y figuras SPE con la selección guardada.
spe = pds.coldbox.reprocessScan(scanRun,fullfile(out,"spe"), ...
    Mode="spe",Vbias=cfg.Vbias(1),Vgain=cfg.Vgain(1),Channels=cfg.ScanChannels(1));

% Medir serie e hilos con la misma configuración y salidas.
comparison = pds.coldbox.benchmarkThreads(cfg.ScanRoot,cfg.ShaperFile,out, ...
    struct('Vbias',cfg.Vbias(1),'Vgain',cfg.Vgain(1), ...
        'Channels',cfg.ScanChannels(1),'MaxWorkers',4));
```

`reprocessScan` requiere una carpeta de salida nueva y acepta los
`point_results.mat` del RUN de referencia. Si necesita reconstruir el
promedio de 1 PE y los archivos fueron trasladados, se puede indicar la
nueva ruta del módulo con `ScanRoot`.

Para verificar los ajustes y las medidas SPE de los 336 puntos guardados,
asigna a `referenceRun` la carpeta `M3_20261119_185729_896_UTC` y ejecuta
la prueba de integración. La prueba parte de los escalares y promedios
guardados. El análisis desde archivos DAPHNE y el bootstrap se pueden
verificar con el subconjunto del ejemplo anterior.

```matlab
setenv("PDS_COLDBOX_NOV2026_REFERENCE",referenceRun);
results = runtests("tests/integration/TestColdBoxNovember2026Reproduction.m");
assertSuccess(results);
```

La prueba de los interruptores usa un punto real de M3 y verifica que
los valores del diagnóstico y del SNR se calculen directamente sobre la
señal centrada cuando todas las etapas están desactivadas.

```matlab
setenv("PDS_COLDBOX_NOV2026_RUN_ROOT",runRoot);
results = runtests("tests/integration/TestColdBoxScanFilters.m");
assertSuccess(results);
```

## Dónde mejorar cada algoritmo

- `pds.preprocess.vetLatePedestal` aplica el veto tardío y devuelve
  sus máscaras y escalas. El cálculo del pedestal inicial usa
  `pds.preprocess.estimatePedestal`.
- `pds.calibration.fitPhotoelectronPeaks` concentra el descubrimiento
  de picos, el binado adaptativo, la evaluación independiente y el
  bootstrap. Los modos de ejecución y el reprocesamiento reutilizan
  ese ajuste.
- `pds.calibration.measureSinglePe` concentra la amplitud pico a pico,
  el rango dinámico histórico y el margen de saturación. El notch
  se pasa por coeficientes desde el flujo de barrido.
- `pds.io.DaphneWaveformReader.readBlock` entrega registros contiguos
  y conserva el cursor de `next`. La FFT usa
  `pds.signal.computeSpectrum` y su representación usa
  `pds.plotting.plotSpectrum`.
