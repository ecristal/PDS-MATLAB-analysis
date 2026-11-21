---
title: pds.signal.designCovarianceOptimalFilter
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/designCovarianceOptimalFilter.m
tags: [matlab, optimal-filter, covariance, shrinkage, noise-prior]
---

[Código fuente MATLAB](../../src/+pds/+signal/designCovarianceOptimalFilter.m)

Diseña un estimador FIR de amplitud de ganancia unidad usando la matriz de covarianza temporal completa del ruido.

## Firma

```matlab
[b, diagnostics] = pds.signal.designCovarianceOptimalFilter( ...
    referenceSignal, noiseWaveforms, ...
    ShrinkageFraction=1e-4, ...
    PriorCovariance=[], PriorWeight=0)
```

Cada fila de `noiseWaveforms` debe representar un registro de ruido con la misma longitud que `referenceSignal`. La corrección de pedestal debe realizarse explícitamente antes de llamar a esta función.

Las entradas enteras se convierten a `double` después de validarse. Valores `uint64` o `int64` fuera del intervalo entero contiguo exactamente representable, `[-flintmax, flintmax]`, se rechazan con `InexactIntegerConversion` para evitar que dos words distintos produzcan silenciosamente el mismo filtro.

## Formulación

Para la plantilla columna `s` y la covarianza empírica `C_e`:

```text
C_e = (X - mean(X))' (X - mean(X)) / M
C_p,scaled = C_p trace(C_e) / trace(C_p)
C = (1-alpha) C_e + alpha C_p,scaled
C_reg = C + lambda mean(diag(C)) I
w = C_reg^-1 s / (s' C_reg^-1 s)
b = reverse(w)
```

- `lambda` es `ShrinkageFraction`.
- `alpha` es `PriorWeight`.
- `C_p` es `PriorCovariance`.
- La normalización por traza permite combinar la forma espectral del prior con el nivel de ruido de los candidatos de la adquisición.
- `b` usa la orientación causal esperada por [`applyOptimalFilter`](applyOptimalFilter.md).
- La respuesta de la plantilla es uno dentro de precisión numérica.

## Prior independiente

```matlab
[~, priorInfo] = pds.signal.designCovarianceOptimalFilter( ...
    template, dedicatedNoise, ShrinkageFraction=1e-4);

[b, info] = pds.signal.designCovarianceOptimalFilter( ...
    template, acquisitionNoiseCandidates, ...
    ShrinkageFraction=1e-4, ...
    PriorCovariance=priorInfo.empiricalCovariance, ...
    PriorWeight=0.25);
```

El prior debe ser real, finito, simétrico, semidefinido positivo y de tamaño `N x N`. Un `PriorWeight` distinto de cero sin prior es un error explícito.

## Diagnósticos

La salida `diagnostics` incluye:

- `empiricalCovariance`;
- `priorCovariance`, `priorWeight` y `priorScale`;
- `covariance` combinada y `regularizedCovariance`;
- `noiseMean` y `noiseRecordCount`;
- `weights` y `filterCoefficients`;
- `gainBeforeNormalization`;
- `predictedNoiseVariance`;
- `normalization`, `scoreIndex` y `latencySamples`.

## Evidencia

`tests/TestDesignCovarianceOptimalFilter.m` verifica:

- respuesta unitaria y orientación FIR;
- solución analítica para una covarianza diagonal;
- mezcla de prior independiente normalizado por traza;
- validación de dimensiones, shrinkage y prior.
- rechazo previo a conversión de referencias, ruido y priors `uint64`/`int64` no representables exactamente.

La aplicación a datos ColdBox está documentada en `docs/validation/coldbox-m3-covariance-optimal-filter.md`.

## Enlaces

- [`designOptimalFilter`](designOptimalFilter.md)
- [`applyOptimalFilter`](applyOptimalFilter.md)
- `docs/validation/coldbox-m3-covariance-optimal-filter.md`
