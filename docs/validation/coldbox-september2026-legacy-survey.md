---
type: validation-report
status: validated-runtime
workflow: coldbox-september2026-legacy-shaping-v1
dataset: ColdBox-September2026-M1-M6
tags: [daphne, coldbox, legacy, gaussian-fit, snr, single-pe]
---

# ColdBox September 2026: análisis legacy M1--M6

## Alcance

Se analizaron los 12 canales indicados para los módulos M1--M6. Cada archive contiene 30,000 waveforms de 1,024 muestras a 62.5 MHz. Los datos originales se leyeron sin modificarlos.

Correspondencia aplicada:

| Módulo | CH lógico 1 | CH lógico 2 |
|---|---:|---:|
| M1 | DAPHNE 2 | DAPHNE 3 |
| M2 | DAPHNE 0 | DAPHNE 1 |
| M3 | DAPHNE 8 | DAPHNE 9 |
| M4 | DAPHNE 10 | DAPHNE 11 |
| M5 | DAPHNE 18 | DAPHNE 19 |
| M6 | DAPHNE 20 | DAPHNE 21 |

## Contrato

El procesamiento común conserva el contrato legacy:

1. corte RMS 15--85%;
2. pedestal por evento calculado exclusivamente como la media de las muestras `1:100`;
3. corte de pedestal 15--85%;
4. sustracción del pedestal;
5. low-pass Butterworth de orden 3 y 2 MHz únicamente para M3 y M4;
6. integrador IIR y moving-mean HPK legacy para todos los módulos;
7. score de amplitud alrededor del máximo de la waveform media filtrada;
8. barrido común de bin widths `0.02:0.01:0.05`;
9. normalización por el segundo pico;
10. ajuste `gaussian_fit_SNR` de seis componentes;
11. `Delta = mu1-mu0` y `SNR = Delta/sigma0`.

Los títulos de cada histograma se generan en dos líneas, con la primera en negrita:

`Histogram - COLDBOX SEPT 2026`

`VBIAS=<value> - VGAIN <value> - Module M<number> CH<number>`

## Resultados

| Module | CH | DAPHNE | VBIAS | LP 2 MHz | Selected / 30,000 | mu0 | sigma0 | mu1 | Delta | SNR | R² | Estado |
|---|---:|---:|---:|:---:|---:|---:|---:|---:|---:|---:|---:|---|
| M1 | 1 | 2 | 1195 | No | 14,700 | 0.018190 | 0.180699 | 1.109833 | 1.091644 | no reportado | -0.028047 | fit inválido; estructura visible |
| M1 | 2 | 3 | 1195 | No | 14,701 | 0.003362 | 0.105392 | 0.993154 | 0.989792 | 9.391494 | 0.954433 | válido |
| M2 | 1 | 0 | 1195 | No | 14,700 | 0.009101 | 0.102573 | 1.078697 | 1.069596 | 10.427622 | 0.983279 | válido |
| M2 | 2 | 1 | 1195 | No | 14,700 | 0.012391 | 0.099878 | 0.997319 | 0.984928 | 9.861339 | 0.971493 | válido |
| M3 | 1 | 8 | 810 | Sí | 14,701 | -0.010654 | 0.236356 | 1.003593 | 1.014246 | 4.291179 | 0.966516 | válido |
| M3 | 2 | 9 | 810 | Sí | 14,701 | -0.020111 | 0.228236 | 0.983233 | 1.003344 | 4.396085 | 0.964678 | válido |
| M4 | 1 | 10 | 810 | Sí | 14,704 | 0.048759 | 0.166457 | 1.053358 | 1.004599 | 6.035169 | 0.960729 | válido |
| M4 | 2 | 11 | 810 | Sí | 14,701 | 0.019123 | 0.181752 | 1.028001 | 1.008878 | 5.550838 | 0.985956 | válido |
| M5 | 1 | 18 | 0 | No | 14,700 | -0.161370 | 0.324506 | 1.015138 | 1.176509 | 3.625540 | 0.983288 | válido |
| M5 | 2 | 19 | 0 | No | 14,700 | -0.106663 | 0.195607 | 1.046384 | 1.153047 | 5.894696 | 0.951000 | válido |
| M6 | 1 | 20 | 0 | No | 14,700 | -0.007848 | 0.189055 | 1.001325 | 1.009173 | 5.338000 | 0.967437 | válido |
| M6 | 2 | 21 | 0 | No | 14,700 | -0.037664 | 0.279318 | 1.114840 | 1.152504 | no reportado | 0.113812 | fit inválido; estructura visible |

Hay 10 ajustes válidos de 12. M1 CH1 y M6 CH2 muestran estructura multi-pico, pero el ajuste global no satisface el criterio común `R² > 0.95`; sus valores nominales de SNR, 6.041210 y 4.126129 respectivamente, se conservan solo como diagnóstico y no como mediciones.

## Síntesis

- M2 presenta la mejor separación: SNR 10.43 y 9.86, con los menores anchos de pedestal (`sigma0` aproximadamente 0.10).
- M1 CH2 también presenta separación alta, SNR 9.39. M1 CH1 no admite un SNR defendible con el fit común, pese a su estructura visual.
- M3 presenta el menor SNR entre los módulos con VBIAS=810: 4.29 y 4.40. El ensanchamiento de `sigma0` domina esta diferencia.
- M4 mejora respecto de M3: SNR 6.04 y 5.55.
- M5 es asimétrico entre canales: CH1 alcanza 3.63, mientras CH2 alcanza 5.89.
- M6 CH1 alcanza 5.34. M6 CH2 queda sin SNR reportado debido a un fit global inválido.
- Los códigos `VBIAS=0` de M5/M6 se reportan tal como constan en `config.txt`; no se interpretan como demostración de cero voltaje físico.
- Las waveforms single-P.E. de M3 y M4 incluyen la comparación raw frente a low-pass de 2 MHz. Para M1 CH1 y M6 CH2 se muestra una selección nominal claramente rotulada como procedente de un fit inválido.

## Cambio del archive M3 CH1

El archive actual `September2026/M3/channel_8.7z` tiene SHA-256:

`a0ba2889bb03226e62a1d17964f39def0113edbd66df09288b98b9261241af87`

No coincide con el hash histórico `c66985cc8ad5227a5a5f2c3d759ceb14f34d811b2e55841a4f95094924218ffb` documentado para el baseline anterior de SNR 4.191467. Por tanto, el resultado actual 4.291179 corresponde al nuevo archive y no reemplaza retroactivamente ese baseline histórico.

## Artefactos

Directorio:

`outputs/validation/coldbox-september2026-legacy-survey/`

Contiene:

- 12 histogramas individuales con fit;
- 12 plots de average single P.E.;
- CSV de waveform media por canal;
- `histograms_montage.png`;
- `average_single_pe_montage.png`;
- `summary.csv`, `summary.mat` y `summary.md`.

Implementación y prueba:

- `tests/helpers/runColdBoxSeptember2026LegacySurveyForTest.m`;
- `tests/integration/TestColdBoxSeptember2026LegacySurvey.m`.

La integración se ejecutó en MATLAB R2025b y pasó 1/1.