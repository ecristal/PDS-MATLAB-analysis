---
type: validation-report
status: validated-runtime
review_status: tested-runtime
repo_paths:
  - tests/integration/TestColdBoxM3OptimalFilterContract.m
  - tests/helpers/runColdBoxM3OptimalFilterContractForTest.m
  - src/+pds/+signal/designCovarianceOptimalFilter.m
tags: [matlab, coldbox, daphne, optimal-filter, covariance, pedestal, snr]
---

# ColdBox M3: filtro óptimo con prior de ruido dedicado

## Objetivo

Aplicar un único contrato a los runs M3 de November 2025 y September 2026, manteniendo:

- pedestal calculado exclusivamente con las muestras `1:100`;
- template compartido `data/DAPHNE/ColdBox/Template/M3/template.csv`;
- separación entre registros impares de entrenamiento y pares de evaluación;
- parámetros idénticos para ambas adquisiciones;
- rechazo explícito de waveforms con pedestal contaminado o inestable;
- ruido dedicado de `September2026/M3_noise` como prior independiente de la covarianza;
- requisito `SNR >= 5.81` para November y mejora sobre `4.191467` para September.

## Entradas verificadas

| Entrada | Registros | SHA-256 |
|---|---:|---|
| `November2025/M3/channel_28.7z` | 30,000 | `1ab1606d7230b6dd3c848e7df4afb40a89148caa648bc8461167d933dad8e7fa` |
| `September2026/M3/channel_8.7z` | 30,000 | `c66985cc8ad5227a5a5f2c3d759ceb14f34d811b2e55841a4f95094924218ffb` |
| `September2026/M3_noise/channel_8.7z` | 50,000 | `07d6fc68eea9048ae25ba6f739618552e7346c9b5cf20001fb4cc6458b7566cb` |
| `Template/M3/template.csv` | 1 x 1024 | `168855b413af81e9957fe6e5a2e28e1b91f161042325b923afccbfa49cd41bf2` |
| `fit_filter_vars.mat` externo | coeficientes de shaping | `4ab1e972ae3f4453d2e549dafcb77b9c28033c18a18b486256e13423a82ac460` |

Los archivos originales se leen sin modificación. Los productos se escriben bajo `outputs/`, ignorado por Git.

## Contrato congelado

Identificador: `coldbox-m3-covariance-optimal-v1`.

| Parámetro | Valor |
|---|---:|
| Frecuencia de muestreo | 62.5 MHz |
| Longitud de waveform | 1024 muestras |
| Entrenamiento/evaluación | IDs impares / pares |
| Región de pedestal | muestras `1:100` |
| Estimador | median-of-means |
| Tamaño de bloque | 10 |
| Gate adicional de pedestal | cuantiles 15--85% calculados solo en entrenamiento |
| Longitud del filtro | 128 muestras |
| Pre-pico en la ventana | 10 muestras |
| Shrinkage diagonal | `1e-4` |
| Peso del prior dedicado | `0.25` |
| Ventana del ruido dedicado | muestras `501:628` |
| Bin normalizado | `0.02 PE` |
| SNR | `(mu1-mu0)/sigma0` |

### Flujo

1. `pds.preprocess.estimatePedestal` calcula el median-of-means por waveform en `1:100` y sus flags de calidad.
2. Se aceptan waveforms con `validEventMask` y pedestal dentro de los cuantiles de entrenamiento 15--85%.
3. Tras sustraer el pedestal con `pds.preprocess.subtractPedestal`, se conserva el shaping histórico para comparar sobre el mismo espacio temporal que el baseline.
4. La plantilla compartida se procesa de la misma forma y se recorta a 128 muestras.
5. Los candidatos de ruido de cada adquisición se seleccionan únicamente entre registros de entrenamiento compatibles con el pedestal.
6. Los 50,000 waveforms de `M3_noise` producen una covarianza independiente; 28,009 superan el gate de calidad. Su covarianza se normaliza por traza y contribuye un 25% a la covarianza final.
7. `pds.signal.designCovarianceOptimalFilter` construye el filtro de ganancia unidad.
8. Las clases 0-PE y 1-PE del entrenamiento fijan el origen, escala y ventanas de ajuste. La evaluación no participa en PSD, covarianza, alineamiento ni selección de ventanas.
9. Se reportan en paralelo todos los registros de evaluación y la población seleccionada por calidad.

La máscara de candidatos de ruido es una heurística basada en el ajuste preliminar del pedestal; reduce la contaminación por señal, pero no garantiza que cada registro seleccionado sea ruido puro. Su conteo y fracción se conservan en los artefactos para permitir auditoría.

El prior dedicado por sí solo no modela la contaminación presente durante la adquisición de September. Por ello se combina con los candidatos de la adquisición: el prior estabiliza la forma de covarianza sin reemplazar el ruido observado in situ.

## Resultados

| Dataset | Evaluación aceptada | Candidatos de ruido | `Delta` | `sigma0` | SNR óptimo | Baseline legacy | Cambio absoluto | Cambio relativo |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| November 2025 | 8,399 / 15,000 | 1,990 | 0.995571 | 0.169756 | **5.864722** | 5.814079 | +0.050644 | +0.87% |
| September 2026 | 7,759 / 15,000 | 1,594 | 0.996757 | 0.227147 | **4.388166** | 4.191467 | +0.196699 | +4.69% |

Criterios cumplidos:

- November: `5.864722 >= 5.81`;
- September: `4.388166 > 4.191467`;
- mismo algoritmo y parámetros para ambos datasets.

La mejora de September procede principalmente de reducir el ancho efectivo del pedestal conservando una separación próxima a un PE. No prueba por sí sola que la causa física sea una filtración de luz.

## Calidad y rechazo

En evaluación:

| Dataset | Contaminado | No estacionario | Outliers excesivos | Bloques inestables | Fracción total aceptada |
|---|---:|---:|---:|---:|---:|
| November 2025 | 1,658 | 535 | 27 | 1,909 | 55.99% |
| September 2026 | 2,604 | 812 | 20 | 2,125 | 51.73% |

September presenta más flags de contaminación, no estacionariedad y bloques inestables. Esto es consistente con un pedestal más perturbado, pero los flags pueden solaparse y no identifican causalidad física.

## Ajustes y plots

Los ajustes 0-PE y 1-PE usan ventanas fijadas desde entrenamiento y gaussianas independientes. El menor `R²=0.788709` de September refleja hombros y colas no gaussianas visibles; el valor de SNR se considera una métrica comparativa válida bajo el contrato, no una descripción completa de toda la distribución.

Artefactos:

- `outputs/validation/coldbox-m3-covariance-optimal-v1/november2025_optimal_filter.png`;
- `outputs/validation/coldbox-m3-covariance-optimal-v1/september2026_optimal_filter.png`;
- `outputs/validation/coldbox-m3-covariance-optimal-v1/summary.csv`;
- `outputs/validation/coldbox-m3-covariance-optimal-v1/summary.mat`;
- `outputs/validation/coldbox-m3-covariance-optimal-v1/summary.md`.

Cada plot separa la distribución de todos los registros pares de la distribución seleccionada por calidad, evitando ocultar las colas rechazadas.

## Límites

- La covarianza se estima después del shaping histórico y depende del archivo externo `fit_filter_vars.mat`; este contrato aún no es completamente autocontenido.
- La evaluación es holdout respecto al entrenamiento de cada ejecución, pero el desarrollo exploratorio previo observó ambos datasets. No debe presentarse como una evaluación ciega independiente.
- September mantiene estructura no gaussiana y un ajuste peor que November.
- La comparación demuestra robustez algorítmica, no la causa de la degradación física.

## Evidencia runtime

- `TestDesignCovarianceOptimalFilter`: respuesta unitaria, solución analítica, prior y validación.
- `TestColdBoxM3OptimalFilterContract`: contrato común, conteos, parámetros, artefactos y objetivos de SNR.
- MATLAB R2025b.

## Enlaces

- [[designCovarianceOptimalFilter]]
- [[coldbox-m3-legacy-contract-comparison]]
- [[coldbox-m3-november2025-legacy-reproduction]]
