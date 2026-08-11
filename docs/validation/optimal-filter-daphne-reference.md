---
type: validation-report
status: tested-runtime
review_mode: matlab-runtime
dataset: local-ignored-daphne-reference
tags: [matlab, daphne, optimal-filter, histogram, snr]
---

# Optimal filter DAPHNE reference

## Dataset

Ruta local ignorada por Git:

```text
data/DAPHNE/FBK_SiPM/vgain_1700/channel_24.7z
```

Formato confirmado mediante lectura runtime:

```text
Canal:                 24
Formato:               uint16 little-endian
Waveforms:             30,000
Muestras por waveform: 2,048
Sample rate:           62.5 MHz
Sample period:         16 ns
Pedestal medio raw:    7551.40946 ADC counts
Pico promedio:         muestra 414
```

Los words se leen conservadoramente como `uint16`. En este archivo los dos bits superiores están en cero en todas las muestras, lo que es consistente con códigos ADC de 14 bits, pero la codificación exacta debe confirmarse con documentación autoritativa del firmware antes de asumir signed u offset-binary.

Los datos y figuras de entrada no se versionan. El test extrae el `.dat` únicamente en un directorio temporal.

## Procedimiento validado

1. Pedestal por evento con las primeras 300 muestras.
2. Filtro blanco preliminar.
3. Identificación del pico 1 PE y promedio de 8,949 waveforms para construir la plantilla.
4. Filtro blanco definitivo.
5. Selección de 26,536 registros candidatos dentro de la región `mu0 ± 2 sigma0` del pico pedestal preliminar.
6. PSD coloreada bilateral con ventana Hann, conservando la corrección por evento de las primeras 300 muestras (`RemoveMean=false` después de esa corrección).
7. Regularización relativa `1e-3`.
8. Filtro óptimo normalizado a respuesta unitaria.
9. Ajuste del pedestal y 1 PE.
10. Remoción final de `mu0` y repetición del ajuste.

## Resultado

```text
SNR filtro blanco:                    2.27921588
SNR filtro coloreado estimado:        5.38283353
mu0 después de remover pedestal:     -3.76993189e-17
mu1:                                  1.08953633
sigma0:                               0.202409443
SNR del ajuste legacy gauss3:         5.39912483
Herramienta legacy ejecutada:         sí
```

Definición:

```text
SNR = (mu1-mu0)/sigma0
```

El ajuste principal del test usa [[find_peaks_hist_adaptive]] y gaussianas acotadas. También se ejecutó correctamente `gaussian_fit_SNR`; la diferencia absoluta entre ambas SNR fue `0.01629130`.

El valor histórico visible en el plot de referencia era `SNR=4.8095`, pero correspondía al procesamiento histórico y no se impone como igualdad exacta. El valor nuevo difiere en `+0.57333353` (`+11.920855 %`). La prueba exige resolución de al menos dos picos, pedestal centrado, SNR > 4.5 y mejora respecto del filtro blanco.

## Plot generado

```text
outputs/validation/optimal_filter_reference_histogram.png
```

El plot muestra pedestal, 1 PE, gaussianas ajustadas, centros y picos adicionales hasta aproximadamente 10 PE. La inspección visual posterior a preservar la corrección de pedestal confirmó que los dos primeros picos están bien resueltos y que el título `SNR = 5.383` concuerda con el resultado numérico, sin defectos visuales obvios.

## Test

```text
tests/integration/TestOptimalFilterDaphneReference.m
```

Si el dataset local no existe, solo este test se filtra mediante assumption. En la máquina de desarrollo pasó completamente en MATLAB R2025b.

## Enlaces

- [[designOptimalFilter]]
- [[applyOptimalFilter]]
- [[estimateNoisePsd]]
- [[gaussian_fit_SNR]]
- [[find_peaks_hist_adaptive]]
