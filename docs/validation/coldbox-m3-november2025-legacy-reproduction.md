---
type: validation
status: reproduced
workflow: coldbox-m3-legacy-histogram
dataset: ColdBox-M3-November2025-channel28
tags: [daphne, coldbox, pedestal, gaussian-fit, snr, legacy-reproduction]
---

# ColdBox M3 November 2025: reproducción del histograma legacy

## Objetivo

Reproducir el histograma multi-PE adjunto para el canal 28 del módulo M3 y verificar que la adquisición de November 2025 permite separar el pedestal y las poblaciones fotoelectrónicas.

Esta reproducción usa la media de las primeras 100 muestras de cada waveform como pedestal, según lo solicitado.

## Entradas y procedencia

| Entrada | SHA-256 |
|---|---|
| `data/DAPHNE/ColdBox/November2025/M3/channel_28.7z` | `1ab1606d7230b6dd3c848e7df4afb40a89148caa648bc8461167d933dad8e7fa` |
| `data/DAPHNE/ColdBox/November2025/M3/histogram_ch_28.png` | `552e07e063c2623dc9582ad6fa8b3462eb066f923896f34cce54912f4ea6286e` |
| `DAPHNE test/daphne_configuration/Filters/fit_filter_vars.mat` | `4ab1e972ae3f4453d2e549dafcb77b9c28033c18a18b486256e13423a82ac460` |

El archivo de datos contiene exactamente `30,000 × 1,024` muestras `uint16`, little-endian, a 62.5 MHz. La extracción se realiza en un directorio temporal y se limpia automáticamente.

## Método reproducido

1. Calcular RMS por waveform y conservar el intervalo de cuantiles 15–85% usado por el workflow legacy.
2. Estimar un pedestal por evento con `pds.preprocess.estimatePedestal`, método `mean`, muestras `1:100`.
3. Conservar el intervalo de cuantiles 15–85% del pedestal.
4. Sustraer el pedestal con `pds.preprocess.subtractPedestal`.
5. Aplicar la cadena legacy observada en `analysis_daphne_data.mlx`:
   - Butterworth low-pass de orden 3, corte 2 MHz;
   - IIR `planta_integrator`;
   - IIR `planta_movmean_hpk`.
6. Extraer el escalar de cada evento como dos veces la media de tres muestras alrededor del máximo del waveform medio filtrado.
7. Probar bin widths `0.02:0.01:0.05`, seleccionar el que maximiza el SNR legacy, normalizar por el segundo pico detectado y ejecutar `gaussian_fit_SNR` con seis componentes.
8. Calcular `SNR = (mu1-mu0)/sigma0`.

## Resultado

| Eventos iniciales | Eventos seleccionados | mu0 | sigma0 | mu1 | Delta | SNR | R² |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 30,000 | 14,701 | -0.005359 | 0.181908 | 1.052268 | 1.057627 | 5.814079 | 0.988735 |

El resultado reproduce la separación visible entre pedestal y picos de 1, 2, 3 y 4 PE. Cumple el criterio `SNR > 5` y confirma que la adquisición de November 2025 no es `unresolved`.

El plot de referencia indica `SNR = 5.4565`; esta ejecución queda 0.357579 por encima, una diferencia relativa de 6.55%. No se exige igualdad exacta porque se sustituyó la estimación de pedestal legacy por la media explícita de las primeras 100 muestras y el ajuste depende del bin width seleccionado.

## Diagnóstico del intento anterior

El resultado anterior era incorrecto como reproducción del plot adjunto porque mezclaba un contrato diferente:

- filtro óptimo de 1,024 coeficientes y score en la última muestra;
- PSD estimada con una selección automática que aceptó aproximadamente 96% de los eventos de entrenamiento;
- ausencia de los cortes legacy de RMS y pedestal;
- ajuste independiente de dos shoulders locales en vez del ajuste multi-Gaussiano normalizado.

El plot adjunto fue producido por una cadena de shaping/integración legacy, no por el contrato moderno de `pds.signal.designOptimalFilter`. Por tanto, esta reproducción valida la separabilidad del dataset, pero no convierte la reproducción legacy en una validación del filtro óptimo moderno. Esa comparación debe tratarse como una prueba separada y con contratos de procesamiento explícitos.

## Artefactos

Directorio ignorado:

`outputs/validation/coldbox-m3-legacy-reproduction/`

- `november2025_legacy_reproduction.png`
- `summary.csv`
- `summary.mat`
- `summary.md`

Implementación reproducible:

- `tests/integration/TestColdBoxM3LegacyReproduction.m`
- `tests/helpers/runColdBoxM3LegacyContractForTest.m`

El mismo contrato se aplicó sin cambios a September 2026 en [[coldbox-m3-legacy-contract-comparison]].
