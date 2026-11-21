---
type: validation
status: compared
workflow: coldbox-m3-legacy-shaping-v1
dataset: ColdBox-M3-November2025-September2026
tags: [daphne, coldbox, pedestal, gaussian-fit, snr, comparison]
---

# ColdBox M3: comparación con contrato legacy idéntico

## Objetivo

Aplicar sin cambios a `September2026/channel_8.7z` el contrato que reprodujo correctamente los picos fotoelectrónicos de `November2025/channel_28.7z`.

Ambas adquisiciones contienen 30,000 waveforms de 1,024 muestras a 62.5 MHz.

## Contrato congelado

Identificador: `coldbox-m3-legacy-shaping-v1`.

Los dos datasets usan exactamente:

1. corte RMS por cuantiles 15–85%;
2. pedestal por evento: media de las muestras 1:100 mediante `pds.preprocess.estimatePedestal`;
3. corte del pedestal por cuantiles 15–85%;
4. sustracción mediante `pds.preprocess.subtractPedestal`;
5. Butterworth low-pass de orden 3 y corte 2 MHz;
6. los mismos coeficientes IIR `planta_integrator` y `planta_movmean_hpk`;
7. score igual a dos veces la media de tres muestras alrededor del máximo del waveform medio filtrado;
8. bin widths candidatos `0.02:0.01:0.05`;
9. normalización por el segundo pico detectado;
10. el mismo ajuste `gaussian_fit_SNR` de seis componentes.

No se ajustó ningún parámetro para favorecer September 2026. Solo cambian el archivo de entrada, el canal y el índice temporal del máximo derivado de cada adquisición.

## Procedencia

| Dataset | Archivo | SHA-256 |
|---|---|---|
| November 2025, canal 28 | `data/DAPHNE/ColdBox/November2025/M3/channel_28.7z` | `1ab1606d7230b6dd3c848e7df4afb40a89148caa648bc8461167d933dad8e7fa` |
| September 2026, canal 8 | `data/DAPHNE/ColdBox/September2026/M3/channel_8.7z` | `c66985cc8ad5227a5a5f2c3d759ceb14f34d811b2e55841a4f95094924218ffb` |
| Coeficientes legacy | `DAPHNE test/daphne_configuration/Filters/fit_filter_vars.mat` | `4ab1e972ae3f4453d2e549dafcb77b9c28033c18a18b486256e13423a82ac460` |

## Resultados

| Dataset | Canal | Eventos seleccionados | mu0 | sigma0 | mu1 | Delta | SNR | R² | SNR > 5 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|:---:|
| November 2025 | 28 | 14,701 | -0.005359 | 0.181908 | 1.052268 | 1.057627 | 5.814079 | 0.988735 | Sí |
| September 2026 | 8 | 14,702 | -0.021311 | 0.245643 | 1.008293 | 1.029604 | 4.191467 | 0.955311 | No |

Con el mismo contrato:

- el SNR de September es 1.622612 menor, una reducción relativa de 27.91%;
- `sigma0` aumenta 35.04%;
- `Delta` disminuye solo 2.65%;
- el número de eventos seleccionados difiere en un único evento.

La degradación del SNR está dominada por el ensanchamiento del pedestal, no por una pérdida comparable de separación media entre los dos primeros picos. El histograma de September conserva estructura multi-PE visible, pero presenta picos más anchos, valles menos profundos y un fondo más elevado. Esto es consistente con mayor contaminación de ruido o luz, pero el análisis no identifica por sí solo la causa física.

## Artefactos

November 2025:

`outputs/validation/coldbox-m3-legacy-reproduction/`

September 2026:

`outputs/validation/coldbox-m3-legacy-contract-september2026/`

Cada directorio contiene el PNG, `summary.csv`, `summary.mat` y `summary.md`.

Implementación y prueba:

- `tests/helpers/runColdBoxM3LegacyContractForTest.m`
- `tests/integration/TestColdBoxM3LegacyReproduction.m`
