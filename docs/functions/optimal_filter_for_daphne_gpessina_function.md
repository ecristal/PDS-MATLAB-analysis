---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/optimal_filter_for_daphne_gpessina_function.m
source_path: Scripts_analisis/data/optimal_filter_for_daphne_gpessina_function.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, optimal-filter, spectral, daphne]
---

# optimal_filter_for_daphne_gpessina_function

## Descripción cualitativa

Construye un filtro óptimo en frecuencia a partir de un waveform de señal y un conjunto de ruido, siguiendo el comentario de “G. Pessina lectures”. Puede ponderar por PSD de ruido y aplicar filtrado adicional.

## Firma

```matlab
function h_filt = optimal_filter_for_daphne_gpessina_function( ...
    signal_waveforms, noise_waveforms, apply_decimation, n_decimation, ...
    is_inverted, filt, use_noise, pedestal_value)
```

## Algoritmo o procedimiento

1. Corrige pedestal e inversión de la señal.
2. Recorta el ruido a la longitud de señal y sustrae su media.
3. Opcionalmente aplica un Butterworth antialias antes de la decimación indicada, aunque no realiza `downsample` en esa rama.
4. Genera una ventana Tukey y calcula DFT/desplazamiento mediante [[mi_dft]].
5. Calcula PSD de ruido con [[f_fourier]].
6. Forma `conj(S)/PSD_ruido` o `conj(S)`.
7. Vuelve al tiempo con [[mi_idtft]].
8. Opcionalmente aplica un low-pass con `filtfilt`, recorta desde el máximo y grafica.

## Dependencias

- Locales: [[mi_dft]], [[mi_idtft]], [[f_fourier]].
- MATLAB/toolboxes: `butter`, `filter`, `filtfilt`, `tukeywin`, plotting; Signal Processing Toolbox.

## Efectos secundarios

Abre/modifica la figura 2 y grafica siempre `h_filt`.

## Supuestos, unidades y dimensiones

- Sample rate fijo de 62.5 MHz y período 16 ns en llamadas internas.
- `signal_waveforms` se trata como un vector; `noise_waveforms` como matriz waveform × muestra.
- `pedestal_value` se usa como cantidad de muestras iniciales, pese al nombre.

## Riesgos y limitaciones

- La versión staged de [[f_fourier]] requiere cinco argumentos, mientras esta función le pasa tres; la llamada es incompatible.
- [[mi_dft]] devuelve un espectro bilateral de longitud N, pero [[f_fourier]] devuelve una PSD unilateral de longitud `floor(N/2)+1`; la división elemento a elemento no es dimensionalmente compatible.
- [[f_fourier]] fuerza a cero la componente DC de la PSD. Incluso armonizando longitudes, la división directa puede producir infinito/NaN en DC o ante bins muy pequeños; no existe regularización.
- La ventana para la segunda llamada `mi_dft` está fija a longitud 4096, que puede no coincidir con la señal.
- `apply_decimation` diseña/aplica filtro, pero no decima explícitamente.
- Variables de IDFT intermedias se calculan sin afectar la salida.
- Mezcla diseño del filtro, diagnóstico y plotting.
- La sustracción de media del ruido usa `mean` matricial y puede depender de dimensiones/expansión implícita.

## Destino provisional en el paquete

Candidato a `+pds/+filter/designOptimalFilter.m`, con sample rate, regularización y política de normalización explícitos; plotting separado.

## Evidencia y grado de certeza

- **Observado:** construcción conjugada/PSD, DFT/IDFT y sample rate fijo.
- **Inferido:** aproximación de matched/optimal filter para maximizar SNR.
- **Desconocido:** derivación matemática exacta, normalización requerida y conjunto de ruido representativo.

## Preguntas pendientes

- ¿Qué regularización se aplica cuando la PSD se acerca a cero?
- ¿Debe normalizarse `h_filt` por ganancia, energía o respuesta a 1 PE?
- ¿`n_decimation` implica decimación real en otra etapa?

## Enlaces

- [[analysis_daphne_data]]
- [[mi_dft]]
- [[mi_idtft]]
- [[f_fourier]]
- [[analysis_daphne_data_dependencies]]
