# Reproducción del análisis ColdBox de noviembre de 2026

Abre MATLAB desde la raíz de PDS-MATLAB-analysis y ejecuta
`setupPDSAnalysisPath`. Los ejemplos requieren MATLAB R2025b, 7-Zip,
Signal Processing Toolbox, Statistics and Machine Learning Toolbox y
Curve Fitting Toolbox. La ejecución con hilos usa Parallel Computing
Toolbox. Los registros DAPHNE se leen desde la carpeta de la campaña.

## Barrido del módulo M3

En MATLAB, asigna a `runRoot` la carpeta `NOVEMBER2026_RUN`. El perfil
proporciona `cfg.ShaperFile`, que apunta a
[`november2026_shaper.mat`](../../src/+pds/+coldbox/private/november2026_shaper.mat).
El archivo contiene los vectores `numz_planta_integrator` y
`denz_planta_integrator`, idénticos a `bHp` y `aHp` en el `pipeline.mat`
del RUN de referencia. El notch y el filtro pasa bajos se diseñan a
partir de los parámetros del barrido. `analyzeScan` también admite la ruta
a otro archivo de coeficientes para una campaña diferente.

```matlab
setupPDSAnalysisPath;
cfg = pds.coldbox.november2026(runRoot);
out = fullfile(pwd,"outputs","coldbox-november-2026");

[summary, scanRun, performance] = pds.coldbox.analyzeScan( ...
    cfg.ScanRoot, cfg.ShaperFile, out, ...
    Vbias=cfg.Vbias, Vgain=cfg.Vgain, Channels=cfg.ScanChannels, ...
    SamplePeriod=cfg.SamplePeriod, AdcBits=cfg.AdcBits, Campaign=cfg.Campaign, ...
    UseParallel=true, MaxWorkers=0, BootstrapCount=100);
figureFolder = pds.coldbox.plotScanSummary(scanRun);
```

`MaxWorkers=0` permite usar el máximo que determine MATLAB en función del
límite de CPU, la memoria disponible y el número de puntos. Con
`UseParallel=false` se ejecuta el mismo análisis por punto en serie.
Para una prueba corta, selecciona `Vbias=770, Vgain=[1700 2200], Channels=[8 9]`.

El flujo genera `pipeline.mat`, `summary.csv`, archivos de tiempos, un
informe y seis figuras por punto en PNG y FIG. `point_results.mat` guarda
los identificadores y los cortes de eventos, las ventanas, el ajuste de
0 y 1 PE y las formas de onda promedio. Las seis figuras globales usan
`summary.csv` y dejan huecos donde el ajuste queda sin resolver.

## Comparación de ruido electrónico

```matlab
spectra = pds.coldbox.compareElectronicNoise( ...
    cfg.NoiseFolders, fullfile(out,"enoise"), Labels=cfg.NoiseLabels, ...
    Channels=cfg.NoiseChannels, ChannelTitles=cfg.NoiseChannelTitles, ...
    Subtitle=cfg.NoiseSubtitle, RoiMHz=cfg.NoiseRoiMHz, ...
    SamplePeriod=cfg.SamplePeriod, AdcBits=cfg.AdcBits);
```

La comparación resta la media de cada tramo, usa la misma longitud de FFT
en ambas tomas y promedia las amplitudes lineales antes de convertir a
dBFS. Para noviembre de 2026 son 100 000 tramos de 1024 muestras por
toma y canal, una referencia de 16 384 ADU y una marca de 6 MHz.

## Reprocesamiento y verificación

```matlab
% Reajustar los escalares guardados, con la semilla del barrido.
refit = pds.coldbox.reprocessScan(scanRun,fullfile(out,"refit"), ...
    Mode="histogram",Vbias=770,Vgain=1700,Channels=8);

% Regenerar las medidas y figuras SPE con la selección guardada.
spe = pds.coldbox.reprocessScan(scanRun,fullfile(out,"spe"), ...
    Mode="spe",Vbias=860,Vgain=500,Channels=8);

% Medir serie e hilos con la misma configuración y salidas.
comparison = pds.coldbox.benchmarkThreads(cfg.ScanRoot,cfg.ShaperFile,out, ...
    struct('Vbias',860,'Vgain',500,'Channels',8,'MaxWorkers',0));
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
