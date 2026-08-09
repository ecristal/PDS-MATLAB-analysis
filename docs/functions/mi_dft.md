---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/mi_dft.m
source_path: Scripts_analisis/data/mi_dft.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, dft, spectral]
---

# mi_dft

## Descripción cualitativa

Implementación directa de la DFT que calcula vector de frecuencias, espectro complejo y densidad espectral de potencia; incorpora un desplazamiento temporal como fase adicional.

## Firma

```matlab
function [f, p, pds] = mi_dft(waveform, window_f, fs, n_desplazamiento)
```

## Algoritmo o procedimiento

Construye frecuencias angulares discretas y evalúa explícitamente la suma DFT para cada bin. Normaliza `|p|²` por `fs` y la energía cuadrática de `window_f`.

## Entradas y salidas

- `waveform`: vector de N muestras.
- `window_f`: vector de N coeficientes usado para normalización; no multiplica el waveform.
- `fs`: frecuencia de muestreo en Hz.
- `n_desplazamiento`: shift expresado en muestras mediante fase.
- Salidas: frecuencia, DFT compleja y PSD bilateral.

## Dependencias y efectos secundarios

Solo funciones MATLAB básicas. No grafica ni escribe archivos.

## Supuestos, unidades y dimensiones

`f` en Hz; `pds` en amplitud²/Hz si la amplitud de entrada y normalización son correctas. `waveform` y `window_f` deben tener igual longitud.

## Riesgos y limitaciones

- Complejidad O(N²), muy inferior a `fft` para waveforms largos.
- `window_f` solo afecta la normalización y no se aplica a la señal.
- No valida longitudes ni energía cero de ventana.
- Convención de signo del desplazamiento requiere documentarse.

## Destino provisional en el paquete

Mantener inicialmente como referencia matemática en `+pds/+signal/dftWithShift.m`; evaluar sustitución por `fft` con prueba de equivalencia futura.

## Evidencia y grado de certeza

- **Observado:** sumas DFT y fórmula PSD.
- **Inferido:** función didáctica/de control para validar desplazamientos.
- **Desconocido:** necesidad de conservarla frente a una implementación FFT.

## Preguntas pendientes

- ¿La ventana debía aplicarse también al waveform?
- ¿Qué convención de shift utiliza el filtro óptimo?

## Enlaces

- [[optimal_filter_for_daphne_gpessina_function]]
- [[mi_idtft]]
- [[analysis_daphne_data_dependencies]]
