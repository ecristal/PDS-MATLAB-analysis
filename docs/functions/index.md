---
title: Referencia MATLAB
---

Ejecuta [`setupPDSAnalysisPath`](setupPDSAnalysisPath.md) desde la raíz del repositorio antes de usar las APIs del proyecto.

## Importación por waveform {#importacion-por-waveform}

- [`pds.io.DaphneWaveformReader`](DaphneWaveformReader.md) lee waveforms individuales de un canal DAPHNE desde un `.dat` o `.7z`.
- [`pds.io.readDaqNpz`](readDaqNpz.md) importa un canal desde un archivo de calibración DAQ en formato `.npz`.
- [`extract_and_import_DAPHNE_data`](extract_and_import_DAPHNE_data.md) extrae y carga archivos DAPHNE comprimidos.
- [`import_data_daphne_func`](import_data_daphne_func.md) lee archivos binarios DAPHNE.
- [`getDataFromWafflesPickleFile`](getDataFromWafflesPickleFile.md) recupera waveforms de un archivo pickle de Waffles.
- [`readBinaryDataRSOsc`](readBinaryDataRSOsc.md) lee registros binarios del osciloscopio.
- [`xmltools`](xmltools.md) lee o escribe los metadatos XML.

## Pedestal

- [`pds.preprocess.estimatePedestal`](estimatePedestal.md) estima el pedestal y diagnostica la calidad por evento.
- [`pds.preprocess.subtractPedestal`](subtractPedestal.md) sustrae niveles de pedestal conocidos.
- [`calculateMedianPedestal`](calculateMedianPedestal.md) calcula un pedestal por mediana para el análisis histórico.

## Análisis espectral {#analisis-espectral}

- [`pds.signal.computeSpectrum`](computeSpectrum.md) calcula amplitud, PSD, media FFT coherente y RMS.
- [`pds.plotting.plotSpectrum`](plotSpectrum.md) presenta amplitud o PSD en escala lineal o en decibelios.
- [`pds.signal.estimateNoisePsd`](estimateNoisePsd.md) estima una PSD bilateral de ruido.
- [`pds.signal.createWindow`](createWindow.md) construye ventanas de análisis.
- [`pds.signal.forwardDft`](forwardDft.md) y [`pds.signal.inverseDft`](inverseDft.md) calculan la DFT y su inversa.

## Filtro óptimo

- [`pds.signal.designOptimalFilter`](designOptimalFilter.md) diseña un filtro óptimo a partir de una plantilla y un modelo de ruido.
- [`pds.signal.designCovarianceOptimalFilter`](designCovarianceOptimalFilter.md) usa una covarianza temporal completa.
- [`pds.signal.applyOptimalFilter`](applyOptimalFilter.md) aplica el filtro FIR y devuelve los scores por evento.

## Función de transferencia

- [`pds.identification.prepareSinglePeTemplate`](prepareSinglePeTemplate.md) prepara una plantilla de un fotoelectrón.
- [`pds.identification.estimateContinuousTransferFunction`](estimateContinuousTransferFunction.md) estima un modelo continuo.
- [`pds.identification.estimateDiscreteTransferFunction`](estimateDiscreteTransferFunction.md) estima un modelo discreto.
- [`pds.identification.evaluateTransferFunctionResponse`](evaluateTransferFunctionResponse.md) evalúa la respuesta y sus métricas.
- [`pds.plotting.plotTransferFunctionEstimate`](plotTransferFunctionEstimate.md) grafica el resultado de la estimación.

## Simulación

- [`pds.simulation.generateEventTrain`](generateEventTrain.md) simula trenes de impulsos.
- [`pds.simulation.generateColoredNoise`](generateColoredNoise.md) genera ruido a partir de una PSD bilateral.
- [`pds.simulation.simulatePedestalStressWaveforms`](simulatePedestalStressWaveforms.md) genera waveforms para probar el estimador de pedestal.

## Ajustes y métricas

- [`fit2SPE`](fit2SPE.md) alinea y escala la respuesta de un modelo para ajustarla a una señal de un fotoelectrón.
- [`find_peaks_hist_adaptive`](find_peaks_hist_adaptive.md) detecta máximos de un histograma.
- [`gaussian_fit_SNR`](gaussian_fit_SNR.md) estima el SNR mediante ajustes gaussianos.
- [`my_gaussian_fit`](my_gaussian_fit.md) ajusta una distribución gaussiana.
- [`ROC_file_analysis`](ROC_file_analysis.md) resume un barrido de umbral y calcula métricas ROC.
- [`sum_fitted_data`](sum_fitted_data.md) reúne los resultados de ajuste.

## Compatibilidad

- [`f_fourier`](f_fourier.md) conserva la interfaz de análisis espectral histórica.
- [`mi_dft`](mi_dft.md) y [`mi_idtft`](mi_idtft.md) conservan las interfaces DFT e inversa.
- [`optimal_filter_for_daphne_gpessina_function`](optimal_filter_for_daphne_gpessina_function.md) conserva la interfaz histórica del filtro óptimo.
