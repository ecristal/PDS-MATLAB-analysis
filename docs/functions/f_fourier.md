---
type: matlab-function
status: compatibility-wrapper
review_status: tested-runtime
review_mode: [static, runtime]
repo_path: src/compat/f_fourier.m
legacy_path: legacy/functions/f_fourier/f_fourier.m
replacement: src/+pds/+signal/computeSpectrum.m
plot_helper: src/+pds/+plotting/plotSpectrum.m
source_path: FIUNA/Pasantia-Tesis/MATLAB/f_fourier.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, fft, psd, runtime-validated, compatibility]
---

# f_fourier

## Estado actual

`f_fourier` es ahora un **wrapper de compatibilidad**. En código nuevo, el cálculo debe realizarse con:

```matlab
pds.signal.computeSpectrum
```

y la visualización debe realizarse separadamente con:

```matlab
pds.plotting.plotSpectrum
```

El wrapper delega únicamente el cálculo en `computeSpectrum`. Cuando recibe `doPlot=true`, implementa directamente con `semilogx` la rama histórica de plotting para no romper consumidores legacy; esa rama no usa `plotSpectrum`.

La implementación original fue preservada sin cambios en:

`legacy/functions/f_fourier/f_fourier.m`

Su SHA-256 sigue siendo:

`68fbfaf014c9e23d5090b6b1e46f1dcc769fa846bdfab1f0c9e275c372d183de`

El Live Script original `analysis_daphne_data.mlx` no fue modificado durante esta refactorización.

## Motivación de la refactorización

La revisión estática de la función original mostró:

- firma obligatoria de cinco argumentos, mientras los consumidores históricos usan entre dos y cuatro;
- cálculo y plotting acoplados;
- conversión de la salida a dBFS incluso con `do_plot=false`;
- referencia fija `2^14`;
- modificación de la salida `P1` por opciones de presentación;
- DC forzada a cero solamente para el cálculo RMS;
- integración mediante `trapz`, que aplica medio peso a bins extremos;
- tratamiento incorrecto del último bin para longitudes impares;
- interpretación incorrecta de un vector columna como múltiples registros de una muestra;
- PSD unilateral incompatible dimensionalmente con el consumidor del filtro óptimo.

En `analysis_daphne_data.mlx` se observó además una segunda aplicación de `20*log10(.../2^14)` sobre una salida que ya había sido convertida a dBFS. La corrección futura del workflow debe promediar amplitudes lineales y convertir una sola vez al visualizar.

## API nueva: cálculo

### Firma

```matlab
spectrum = pds.signal.computeSpectrum(waveforms, samplePeriod, Name=Value)
```

### Argumentos obligatorios

- `waveforms`: vector o matriz `registros × muestras`.
- `samplePeriod`: período de muestreo en segundos, escalar positivo y finito.

Un vector fila o columna se interpreta como un único registro.

### Opciones

| Opción | Default | Significado |
|---|---:|---|
| `RemoveMean` | `false` | Resta la media de cada registro antes de la FFT. |
| `Sidedness` | `"one-sided"` | `"one-sided"` o `"two-sided"`. |
| `InputUnit` | `"ADU"` | Metadato de unidades, por ejemplo `"ADU"` o `"V"`. |

### Estructura de salida

| Campo | Significado |
|---|---|
| `frequencyHz` | Frecuencias en Hz. En modo bilateral usa orden FFT. |
| `amplitudeMean` | Espectro de amplitud promedio en unidades lineales. |
| `psdMean` | PSD promedio en `unidad^2/Hz`. |
| `complexMean` | Una única FFT compleja media coherente; no se conservan FFT por evento. |
| `rmsPerRecord` | RMS de cada registro derivado de la PSD. |
| `samplePeriod` | Período de muestreo. |
| `sampleRateHz` | Frecuencia de muestreo. |
| `sampleCount` | Muestras por registro. |
| `recordCount` | Número de registros. |
| `inputUnit` | Unidad declarada por el usuario. |
| `sidedness` | Convención unilateral o bilateral. |
| `meanRemoved` | Indica si se eliminó la media antes de la FFT. |

La API computacional siempre devuelve amplitud y PSD lineales. No abre figuras ni convierte silenciosamente a dB.

## Convenciones matemáticas validadas

Para N muestras y frecuencia de muestreo `Fs = 1/samplePeriod`:

```matlab
Y = fft(waveforms, [], 2);
amplitudeTwoSided = abs(Y) / N;
psdTwoSided = abs(Y).^2 / (N * Fs);
```

Para la representación unilateral:

- DC no se duplica;
- Nyquist no se duplica cuando N es par;
- el último bin positivo sí se duplica cuando N es impar.

El RMS se obtiene mediante:

```matlab
rmsPerRecord = sqrt(sum(psdPerRecord, 2) * df);
```

Esto fue contrastado con el valor temporal `sqrt(mean(abs(x).^2,2))`.

DC no se fuerza a cero después de la FFT. Para excluirla se usa explícitamente:

```matlab
RemoveMean=true
```

## API nueva: visualización

```matlab
lineHandle = pds.plotting.plotSpectrum(spectrum, Name=Value)
```

Opciones principales:

| Opción | Valores |
|---|---|
| `Quantity` | `"amplitude"` o `"psd"` |
| `Scale` | `"linear"` o `"decibel"` |
| `ReferenceValue` | Referencia positiva expresada en la unidad de entrada |
| `ReferenceLabel` | Texto del eje, por ejemplo `"dBFS"` o `"dBV"` |
| `Normalize` | `"none"` o `"peak"` |
| `MinimumDecibels` | Floor opcional; default `-Inf` |
| `Axes` | Axes MATLAB existente |

Conversión de amplitud:

```matlab
20*log10(amplitude / ReferenceValue)
```

Conversión de PSD:

```matlab
10*log10(psd / ReferenceValue^2)
```

La función de plotting no modifica la estructura `spectrum`.

## Wrapper legacy

### Firma compatible

```matlab
[f, P1, Y, Pc1, rms_] = f_fourier(signal, Tm)
[f, P1, Y, Pc1, rms_] = f_fourier(signal, Tm, doPlot)
[f, P1, Y, Pc1, rms_] = f_fourier(signal, Tm, doPlot, yLabel)
[f, P1, Y, Pc1, rms_] = f_fourier(signal, Tm, doPlot, yLabel, normalize)
```

Defaults:

```matlab
doPlot = false;
yLabel = "abs";
normalize = false;
```

El wrapper emite el warning:

`PDS:f_fourier:Deprecated`

La compatibilidad numérica del cálculo no es una reproducción bit a bit del algoritmo original: el wrapper delega en el núcleo corregido, por lo que incorpora el tratamiento par/impar, Parseval, orientación de vectores y política DC de la API nueva. Para reproducir o investigar exactamente el cálculo anterior debe usarse la copia preservada fuera del path.

La rama de interfaz sí conserva convenciones históricas necesarias para no romper consumidores: RMS como vector fila, flags lógicos o `0`/`1`, `normalize` ignorado cuando `doPlot=false` y plotting normalizado con `20*log10` en la figura 3. Estas convenciones se mantienen solo en el wrapper; el código nuevo debe usar [[plotSpectrum]].

Cuando una llamada histórica solicita `"dBFS"`, el wrapper conserva temporalmente la referencia `2^14`. El código nuevo debe proporcionar siempre una referencia explícita a `plotSpectrum`.

## Entorno de prueba

- Fecha: 2026-08-11.
- Plataforma: `PCWIN64`.
- MATLAB: `25.2.0.3123386 (R2025b) Update 3`.
- MATLAB Test: 25.2 disponible.
- Signal Processing Toolbox: 25.2 disponible, pero el núcleo probado usa `fft` y operaciones MATLAB básicas.
- Ejecución: batch, sin interacción gráfica; las figuras de prueba fueron invisibles.

Comando final:

```bash
matlab -batch "cd('C:/Users/e_cri/Documents/Proyectos/PDS-MATLAB-analysis'); results=runtests('tests','IncludeSubfolders',true); assertSuccess(results);"
```

Resultado final:

```text
TEST_TOTAL=24
TEST_PASSED=24
TEST_FAILED=0
TEST_INCOMPLETE=0
```

## Tests realizados

### `TestComputeSpectrum` — 11 tests

1. Equivalencia entre vector fila y columna.
2. Tono centrado en bin para N par y amplitud conocida.
3. Último bin positivo para N impar.
4. PSD unilateral y RMS consistentes con Parseval.
5. Eliminación explícita de DC mediante `RemoveMean=true`.
6. Espectro bilateral en orden FFT y Parseval.
7. Señales cero, constante e impulso con amplitud/RMS esperados.
8. Ruido pseudoaleatorio con semilla fija, N impar y Parseval.
9. Tono fuera de bin: leakage distribuido con potencia conservada.
10. Rechazo de NaN, señales complejas, una sola muestra y arrays 3D.
11. Dos registros con fases opuestas: cancelación solo en `complexMean`, no en amplitud/PSD.

### `TestPlotSpectrum` — 4 tests

1. Plot lineal en axes proporcionados sin modificar la estructura.
2. Amplitud en dB usando `20*log10` y referencia explícita.
3. PSD en dB usando `10*log10` y referencia al cuadrado.
4. Normalización por pico antes de plotting.

### `TestFFourierCompatibility` — 5 tests

1. Firma de dos argumentos y cinco salidas.
2. Firmas de tres, cuatro y cinco argumentos; con `doPlot=false`, `normalize` conserva el comportamiento legacy y no modifica la salida.
3. `rmsPerRecord` conserva orientación fila `1 × recordCount` en el wrapper.
4. Los flags históricos aceptan tanto lógicos como valores numéricos `0`/`1`.
5. Con `doPlot=true` y `normalize=true`, se conserva la rama legacy: salida normalizada, etiqueta solicitada y gráfica de `20*log10` en la figura 3.

### `TestFFourierLegacyCharacterization` — 3 tests

1. La llamada de dos argumentos falla con `MATLAB:minrhs`, confirmando la incompatibilidad observada con consumidores históricos.
2. Una señal constante conserva su amplitud DC, pero la PSD fuerza DC a cero y el RMS legacy resulta cero.
3. Para N impar, el último bin positivo no se duplica y entrega la mitad de la amplitud física del tono.

### `TestSetupPDSAnalysisPath` — 1 test

1. Verifica que el path resuelve la API `+pds` y el wrapper del repositorio, sin añadir la implementación legacy preservada.

### Tolerancias

Las comparaciones numéricas principales usan tolerancia absoluta `1e-12` con señales sintéticas deterministas.

## Ejemplos claros de uso

### 1. Configurar el path

```matlab
addpath('C:\Users\e_cri\Documents\Proyectos\PDS-MATLAB-analysis');
setupPDSAnalysisPath;
```

No usar `genpath` sobre todo el repositorio.

### 2. Seno de amplitud conocida

```matlab
Fs = 62.5e6;
Tm = 1/Fs;
N = 1024;
n = 0:N-1;
frequencyBin = 80;
peakAmplitudeADU = 120;

waveform = peakAmplitudeADU*cos(2*pi*frequencyBin*n/N);
spectrum = pds.signal.computeSpectrum(waveform, Tm, InputUnit="ADU");

[measuredAmplitude, index] = max(spectrum.amplitudeMean);
measuredFrequencyHz = spectrum.frequencyHz(index);
```

Para un tono exactamente centrado en bin, `measuredAmplitude` debe ser aproximadamente `120 ADU`.

Salida observada al ejecutar este ejemplo en R2025b:

```text
measuredAmplitude = 120 ADU
measuredFrequencyHz = 4,882,812.5 Hz
```

### 3. Señal con pedestal/DC

```matlab
waveform = 8000 + 120*cos(2*pi*frequencyBin*n/N);

withDc = pds.signal.computeSpectrum(waveform, Tm, ...
    InputUnit="ADU", RemoveMean=false);

withoutDc = pds.signal.computeSpectrum(waveform, Tm, ...
    InputUnit="ADU", RemoveMean=true);
```

- `withDc.amplitudeMean(1)` representa la componente DC.
- `withoutDc.amplitudeMean(1)` debe ser aproximadamente cero.
- Los dos RMS representan magnitudes físicamente distintas: total y AC.

### 4. Varios eventos

```matlab
% Cada fila es un evento; las columnas son muestras.
waveforms = [event1; event2; event3];

spectrum = pds.signal.computeSpectrum(waveforms, Tm, ...
    InputUnit="ADU", RemoveMean=true);

meanAmplitude = spectrum.amplitudeMean;
meanNoisePsd = spectrum.psdMean;
rmsByEvent = spectrum.rmsPerRecord;
```

`complexMean` es una única media coherente. Las FFT individuales no se guardan en la salida.

### 5. PSD bilateral para procesamiento espectral

```matlab
noiseSpectrum = pds.signal.computeSpectrum(noiseWaveforms, Tm, ...
    InputUnit="ADU", RemoveMean=true, Sidedness="two-sided");

size(noiseSpectrum.psdMean)   % 1 × N
size(noiseSpectrum.complexMean) % 1 × N
```

La PSD está en orden FFT, lo cual permite alinear bins con `fft(...)`. El consumidor debe definir por separado regularización y tratamiento de bins cero.

### 6. Amplitud DAPHNE en dBFS

```matlab
spectrum = pds.signal.computeSpectrum(waveforms, Tm, ...
    InputUnit="ADU", RemoveMean=true);

pds.plotting.plotSpectrum(spectrum, ...
    Quantity="amplitude", ...
    Scale="decibel", ...
    ReferenceValue=2^14, ...
    ReferenceLabel="dBFS", ...
    MinimumDecibels=-140);
```

La referencia `2^14` se proporciona explícitamente. Si la convención física cambia, debe cambiarse `ReferenceValue`.

### 7. Señal en volts y dBV

```matlab
spectrumVolts = pds.signal.computeSpectrum(waveformsVolts, Tm, ...
    InputUnit="V", RemoveMean=true);

pds.plotting.plotSpectrum(spectrumVolts, ...
    Scale="decibel", ...
    ReferenceValue=1, ...
    ReferenceLabel="dBV");
```

### 8. Ruido blanco reproducible

```matlab
rng(42, "twister");
noise = randn(100, 1024);

noiseSpectrum = pds.signal.computeSpectrum(noise, Tm, ...
    InputUnit="ADU", RemoveMean=true);

mean(noiseSpectrum.rmsPerRecord)
pds.plotting.plotSpectrum(noiseSpectrum, Quantity="psd");
```

Este ejemplo sirve para explorar PSD y dispersión de RMS. No sustituye una validación con datos DAPHNE reales.

### 9. Compatibilidad temporal

```matlab
[f, P1, Y, Pc1, rms_] = f_fourier(waveform, Tm, false, "abs");
```

Esta llamada sigue funcionando, pero emite un warning de deprecación. El código nuevo debe utilizar la API namespaced.

## Limitaciones de la validación

- Se usaron señales sintéticas; no se ejecutó un dataset experimental DAPHNE.
- No se ejecutó de extremo a extremo `analysis_daphne_data.mlx`.
- El wrapper conserva deliberadamente la rama histórica `doPlot=true, normalize=true`; esta puede volver a aplicar `20*log10` y producir resultados poco intuitivos, especialmente combinada con `"dBFS"`. No debe usarse en código nuevo.
- No se modificó ni validó todavía `optimal_filter_for_daphne_gpessina_function`.
- La regularización de la PSD para filtros sigue pendiente.
- No se realizaron benchmarks de rendimiento o memoria.
- No se aplicaron ventanas ni se caracterizaron estimadores tipo Welch.
- No se comparó con `periodogram`/`pwelch`; la normalización se validó directamente con Parseval.

## Decisiones resueltas

- No existe otra versión histórica localizada de `f_fourier`.
- Los argumentos opcionales nuevos usan el patrón MATLAB `Name=Value` con bloque `arguments`.
- No se conservan FFT complejas por evento; solo `complexMean`.
- Las unidades se declaran con `InputUnit`.
- La normalización dB usa una referencia explícita en la API nueva.
- La copia original fue adoptada como código propio y preservada como referencia legacy.

## Riesgo pendiente en el filtro óptimo

[[optimal_filter_for_daphne_gpessina_function]] todavía llama la interfaz legacy con tres argumentos y mezcla una DFT bilateral con la PSD históricamente unilateral. La nueva API ya puede producir PSD bilateral, pero la migración del filtro debe hacerse durante su revisión individual, junto con una política explícita de regularización.

## Enlaces

- [[computeSpectrum]]
- [[plotSpectrum]]
- [[optimal_filter_for_daphne_gpessina_function]]
- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
- [[setupPDSAnalysisPath]]
