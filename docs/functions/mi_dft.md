---
type: matlab-function
status: compatibility-wrapper
review_status: tested-runtime
repo_path: src/compat/mi_dft.m
legacy_path: legacy/functions/mi_dft/mi_dft.m
source_path: Scripts_analisis/data/mi_dft.m
tags: [matlab, dft, legacy, compatibility]
---

# mi_dft

Wrapper deprecated para la DFT histórica. El reemplazo autoritativo es [[forwardDft]]; para PSD se usa [[estimateNoisePsd]].

## Firma

```matlab
[frequencyHz, coefficients, psd] = mi_dft( ...
    waveform, windowFunction, sampleRateHz, sampleShift)
```

## Correcciones

- reemplaza sumas O(N²) por `fft`;
- conserva el eje histórico no negativo `0:Fs/N:Fs-Fs/N` en el wrapper;
- aplica la ventana al waveform;
- normaliza PSD mediante `Fs*sum(window.^2)`;
- valida entradas;
- emite `PDS:mi_dft:Deprecated`.

La versión histórica solo utilizaba la ventana en la normalización, no en la señal. Por ello el wrapper corregido no es bit-equivalente cuando la ventana no es rectangular.

## Preservación

```text
legacy/functions/mi_dft/mi_dft.m
```

El blob Git se verificó antes y después del movimiento.

## Evidencia

- `TestForwardDft`: 7 tests.
- `TestOptimalFilterCompatibility`: delegación, ventana, frecuencia y PSD.
- `TestDftLegacyCharacterization`: fórmula histórica, eje 0…Fs-dF y defecto de ventana solo en el denominador.

## Enlaces

- [[forwardDft]]
- [[inverseDft]]
- [[estimateNoisePsd]]
- [[designOptimalFilter]]
