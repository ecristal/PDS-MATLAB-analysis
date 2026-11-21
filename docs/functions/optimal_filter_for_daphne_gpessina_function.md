---
title: optimal_filter_for_daphne_gpessina_function
type: matlab-function
status: compatibility-wrapper
review_status: tested-runtime
repo_path: src/compat/optimal_filter_for_daphne_gpessina_function.m
legacy_path: legacy/functions/optimal_filter_for_daphne_gpessina_function/optimal_filter_for_daphne_gpessina_function.m
source_path: Scripts_analisis/data/optimal_filter_for_daphne_gpessina_function.m
tags: [matlab, optimal-filter, legacy, compatibility]
---

[Código fuente MATLAB](../../src/compat/optimal_filter_for_daphne_gpessina_function.m)

Wrapper deprecated para las firmas históricas de cinco a ocho argumentos. El código nuevo debe usar [`designOptimalFilter`](designOptimalFilter.md) y [`applyOptimalFilter`](applyOptimalFilter.md).

## Firma legacy

```matlab
h = optimal_filter_for_daphne_gpessina_function( ...
    signalWaveforms, noiseWaveforms, applyDecimation, decimationFactor, ...
    isInverted, applyLowPass, useNoise, pedestalSampleCount)
```

La firma completa contiene ocho argumentos. También se aceptan las variantes históricas de cinco a siete argumentos, con defaults `applyLowPass=false`, `useNoise=true` y `pedestalSampleCount=200`.

## Comportamiento del wrapper

- Promedia `signalWaveforms` por filas.
- Aplica inversión explícita cuando corresponde.
- `useNoise=true` usa PSD coloreada medida; `false` usa ruido blanco.
- Delega el diseño en `pds.signal.designOptimalFilter`.
- Devuelve coeficientes FIR con respuesta unitaria.
- No crea figuras.
- Emite warning de deprecación.

## Correcciones intencionales

La implementación histórica está preservada fuera del MATLAB path. Presentaba:

- mezcla de DFT bilateral con PSD unilateral;
- división por PSD sin regularización;
- ventana fija de longitud 4096;
- plotting dentro del cálculo;
- recortes/alineamientos no documentados;
- flag llamado `apply_decimation` que aplicaba un low-pass pero no decimaba;
- normalización final no definida.

El wrapper no reproduce estos errores. Los flags históricos de low-pass/“decimation” se rechazan explícitamente para impedir que una operación solicitada sea ignorada o reemplazada por procesamiento oculto.

## Arquitectura nueva

```text
reference/noise
  -> pds.signal.designOptimalFilter
  -> FIR coefficients
  -> pds.signal.applyOptimalFilter
  -> scores/histogram
```

Soporta ruido blanco, medido, PSD proporcionada, estimación desde pedestal, AR(1), power law, ventanas configurables y regularización explícita. Véase [`designOptimalFilter`](designOptimalFilter.md).

## Evidencia

- `TestOptimalFilterCompatibility`: 5 tests sobre firmas de 5–8 argumentos, respuesta unitaria, errores explícitos y wrappers DFT/IDFT.
- `TestDesignOptimalFilter`: 11 tests de modelos, normalización, preservación de pedestal y entradas/opciones enteras.
- `docs/validation/optimal-filter-daphne-reference.md`: test con 30,000 waveforms reales.

## Enlaces

- [`designOptimalFilter`](designOptimalFilter.md)
- [`applyOptimalFilter`](applyOptimalFilter.md)
- [`estimateNoisePsd`](estimateNoisePsd.md)
- [`mi_dft`](mi_dft.md)
- [`mi_idtft`](mi_idtft.md)
