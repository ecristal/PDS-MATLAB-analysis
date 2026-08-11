---
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/inverseDft.m
tags: [matlab, idft, ifft, spectral]
---

# inverseDft

Transformada discreta inversa optimizada mediante `ifft`. MATLAB convierte las entradas numéricas enteras a salida `double`; la API conserva siempre una fila canónica.

## Firma

```matlab
waveform = pds.signal.inverseDft(coefficients, RealOutput=false)
```

## Contrato

- Entrada: vector de N coeficientes complejos en orden FFT.
- Salida: vector fila.
- La normalización `1/N` es la estándar de MATLAB.
- `RealOutput=false` conserva una salida compleja.
- `RealOutput=true` verifica primero simetría hermítica; no descarta silenciosamente una parte imaginaria significativa.

## Ejemplos

```matlab
X = pds.signal.forwardDft(waveform, 16e-9);
reconstructed = pds.signal.inverseDft(X, RealOutput=true);
```

Respuesta compleja intencional:

```matlab
complexWaveform = pds.signal.inverseDft(complexCoefficients);
```

## Corrección nominal

La función histórica `mi_idtft` implementaba una IDFT finita, no una DTFT inversa. El nombre nuevo refleja el algoritmo real.

## Evidencia

`TestInverseDft`: 6 tests runtime, incluidos round-trip par/impar, conversión segura desde enteros y rechazo de espectros no hermíticos.

## Enlaces

- [[forwardDft]]
- [[mi_idtft]]
- [[designOptimalFilter]]
