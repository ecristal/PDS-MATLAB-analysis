---
title: Validación
---

Las fichas Markdown del repositorio registran las pruebas de estas APIs en MATLAB R2025b.

## Importación por waveform

Las pruebas de [`pds.io.DaphneWaveformReader`](../functions/DaphneWaveformReader.md#validación) incluyen la comparación muestra por muestra con los datos extraídos de un archivo ColdBox, la apertura con longitud explícita y la limpieza de los archivos temporales.

## Análisis espectral

Las pruebas de [`pds.signal.computeSpectrum`](../functions/computeSpectrum.md#evidencia-runtime) incluyen la normalización de la FFT unilateral y bilateral, la eliminación de la media y la identidad de Parseval. Las de [`pds.plotting.plotSpectrum`](../functions/plotSpectrum.md#evidencia-runtime) incluyen las conversiones a decibelios para amplitud y PSD, y la normalización por pico.

Consulta la [referencia MATLAB](../functions/index.md) para localizar las APIs cubiertas por estas pruebas.
