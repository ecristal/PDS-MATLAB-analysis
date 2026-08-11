---
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/applyOptimalFilter.m
tags: [matlab, optimal-filter, fir, daphne]
---

# applyOptimalFilter

Aplica coeficientes FIR producidos por [[designOptimalFilter]] a waveforms alineados. Las entradas numéricas enteras se convierten a `double` antes de corregir pedestal y filtrar.

## Firma

```matlab
[scores, filteredWaveforms] = pds.signal.applyOptimalFilter( ...
    waveforms, filterCoefficients, PedestalSampleCount=[])
```

## Convenciones

- Filas: eventos; columnas: muestras.
- Un vector representa un evento.
- El pedestal se calcula por evento con las primeras `PedestalSampleCount` muestras.
- `scores` es la última muestra del filtro FIR de N taps aplicado a N muestras.
- Esa muestra equivale al producto escalar entre el waveform corregido y `diagnostics.weights`.
- Si no se solicita `filteredWaveforms`, se utiliza directamente el producto matricial para evitar una matriz temporal grande.

## Ejemplos

```matlab
scores = pds.signal.applyOptimalFilter( ...
    waveforms, filterCoefficients, PedestalSampleCount=300);

histogram(scores);
xlabel('Filtered amplitude [1 PE normalized units]');
```

Waveforms filtrados completos:

```matlab
[scores, filteredWaveforms] = pds.signal.applyOptimalFilter( ...
    waveforms, filterCoefficients, PedestalSampleCount=300);
```

## Evidencia

`TestApplyOptimalFilter`: 4 tests runtime para producto escalar, múltiples eventos, pedestal, conversión segura desde enteros y validación.

## Enlaces

- [[designOptimalFilter]]
- [[optimal-filter-daphne-reference]]
