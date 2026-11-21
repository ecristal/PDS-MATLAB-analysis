---
title: mi_idtft
type: matlab-function
status: compatibility-wrapper
review_status: tested-runtime
repo_path: src/compat/mi_idtft.m
legacy_path: legacy/functions/mi_idtft/mi_idtft.m
source_path: Scripts_analisis/data/mi_idtft.m
tags: [matlab, idft, legacy, compatibility]
---

[Código fuente MATLAB](../../src/compat/mi_idtft.m)

Wrapper deprecated que delega en [`inverseDft`](inverseDft.md).

## Firma

```matlab
waveform = mi_idtft(coefficients)
```

## Corrección nominal y computacional

El algoritmo histórico era una IDFT finita O(N²), aunque el nombre hacía referencia a una DTFT inversa. `pds.signal.inverseDft` usa `ifft`, conserva la convención `1/N` y ofrece validación hermítica cuando se solicita salida real.

## Preservación

```text
legacy/functions/mi_idtft/mi_idtft.m
```

El blob Git se verificó antes y después del movimiento.

## Evidencia

- `TestInverseDft`: 6 tests.
- `TestOptimalFilterCompatibility`: equivalencia del wrapper con `ifft`.
- `TestDftLegacyCharacterization`: reconstrucción runtime usando las dos referencias históricas preservadas.

## Enlaces

- [`inverseDft`](inverseDft.md)
- [`forwardDft`](forwardDft.md)
- [`designOptimalFilter`](designOptimalFilter.md)
- [`mi_dft`](mi_dft.md)
