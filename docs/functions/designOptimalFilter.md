---
type: matlab-function
status: project-api
review_status: tested-runtime
repo_path: src/+pds/+signal/designOptimalFilter.m
tags: [matlab, optimal-filter, matched-filter, psd, colored-noise, daphne]
---

# designOptimalFilter

Diseña un matched/optimal filter FIR para una plantilla real alineada.

## Firma resumida

```matlab
[filterCoefficients, diagnostics] = pds.signal.designOptimalFilter( ...
    referenceSignal, noiseWaveforms, ...
    SamplePeriod=16e-9, ...
    PedestalSampleCount=[], ...
    NoiseModel="auto", ...
    Window="tukey", TukeyRatio=0.1, ...
    RegularizationFraction=1e-6)
```

## Formulación

Con plantilla corregida `s`, DFT `S` y PSD bilateral regularizada `P`:

```text
w = IDFT{S/P}
w = w/(w·s)
b = reverse(w)
```

- `w` son pesos del estimador de amplitud.
- `b` son los coeficientes FIR causales devueltos.
- La normalización garantiza `w·s = 1`.
- [[applyOptimalFilter]] devuelve uno para la plantilla alineada dentro de tolerancia.

No se aplica `conj(S)` en la construcción de los pesos: la conjugación/reversión aparece al expresar el producto escalar como FIR causal. Esta distinción evita mezclar pesos, correlación y coeficientes de convolución.

Las entradas numéricas enteras se convierten explícitamente a `double` después de validarse: plantilla, waveforms, PSD proporcionada, `SamplePeriod`, `PedestalSampleCount`, regularización, selección sigma y parámetros AR(1)/power-law. Esto permite trabajar directamente con words ADC sin provocar operaciones mixtas entre enteros y flotantes.

## Modos de ruido

### Automático

```matlab
[b, info] = pds.signal.designOptimalFilter(referenceSignal, noiseWaveforms);
```

- con `noiseWaveforms`: PSD medida;
- con estimación solicitada y candidatos: PSD estimada del pedestal;
- sin información de ruido: PSD blanca.

### Ruido blanco

```matlab
[b, info] = pds.signal.designOptimalFilter( ...
    referenceSignal, [], NoiseModel="white");
```

Usa PSD plana unitaria. El resultado es el matched filter convencional.

### Ruido coloreado medido

```matlab
[b, info] = pds.signal.designOptimalFilter( ...
    referenceSignal, noiseWaveforms, ...
    NoiseModel="measured", ...
    Window="tukey", TukeyRatio=0.25);
```

La PSD se estima con [[estimateNoisePsd]], N bins y corrección de potencia de ventana. `PedestalSampleCount` define la corrección por registro y se llama a la estimación con `RemoveMean=false`; así la media del registro completo no cancela silenciosamente la corrección de pedestal configurada.

### PSD coloreada proporcionada

```matlab
[b, info] = pds.signal.designOptimalFilter( ...
    referenceSignal, [], ...
    NoiseModel="provided", NoisePsd=bilateralNoisePsd);
```

`NoisePsd` debe contener N valores reales, no negativos y simétricos en orden FFT.

### Modelo AR(1)

```matlab
[b, info] = pds.signal.designOptimalFilter( ...
    referenceSignal, [], NoiseModel="parametric", ...
    ColoredNoiseModel="ar1", ArCoefficient=0.9);
```

Forma espectral:

```text
P(omega) proportional to (1-a²)/|1-a exp(-j omega)|²,  |a|<1
```

### Modelo 1/f o power law

```matlab
[b, info] = pds.signal.designOptimalFilter( ...
    referenceSignal, [], NoiseModel="parametric", ...
    ColoredNoiseModel="powerlaw", ...
    PowerLawExponent=1, ...
    PowerLawCornerFrequencyHz=100e3);
```

La frecuencia de esquina evita una singularidad en DC.

### Ruido estimado desde los eventos

```matlab
[b, info] = pds.signal.designOptimalFilter( ...
    referenceSignal, [], NoiseModel="estimated", ...
    CandidateWaveforms=waveforms, ...
    NoiseSelectionSigma=2, ...
    Window="hann");
```

Procedimiento:

1. filtro preliminar blanco;
2. histograma de scores;
3. estimación local de `mu0` y `sigma0` mediante ajuste cuadrático de `log(conteos)` sobre el pico gaussiano contiguo, evitando colas y picos PE vecinos;
4. selección `abs(score-mu0)<=2*sigma0`;
5. PSD coloreada de los waveforms seleccionados;
6. rediseño del filtro.

La máscara, el número de candidatos y los parámetros quedan en `diagnostics`. La selección identifica la región compatible con el pedestal; no garantiza una clasificación pura si el filtro blanco preliminar no separa bien pedestal y señal.

## Regularización

```text
floor = RegularizationFraction max(P)
P_regularizada = max(P,floor)
```

`diagnostics` registra el floor, `regularizedBinMask`, el número de bins regularizados y ambas PSD. No existe división silenciosa por cero.

## Ventanas

- PSD medida/estimada: rectangular, Tukey, Hann, Hamming o vector personalizado.
- Tukey se controla con `TukeyRatio`.
- La plantilla física no se ventanea silenciosamente.
- En la validación DAPHNE se escogió Hann después de comprobar el histograma; Tukey permanece disponible y probado.

## Diagnósticos principales

```matlab
info.noiseSource
info.noisePsd
info.regularizedNoisePsd
info.psdFloor
info.regularizedBinMask
info.weights
info.filterCoefficients
info.gainBeforeNormalization
info.predictedNoiseVariance
info.normalization
info.scoreIndex
info.latencySamples
info.windowName
info.windowPower
info.selectedNoiseMask
info.selectedNoiseCount
info.pedestalMean
info.pedestalSigma
```

Con PSD expresada en amplitud²/Hz, `predictedNoiseVariance = Fs/gainBeforeNormalization`. Para la PSD blanca unitaria y modelos usados solo como forma espectral, esta cifra conserva una escala arbitraria; los pesos normalizados no dependen de esa escala global.

## Evidencia

`TestDesignOptimalFilter`: 11 tests runtime para blanco, medido, proporcionado, AR(1), power law, regularización, selección de pedestal, preservación de `PedestalSampleCount`, conversión segura de datos y opciones escalares enteras, y validación.

El test local DAPHNE está documentado en [[optimal-filter-daphne-reference]].

## Enlaces

- [[applyOptimalFilter]]
- [[estimateNoisePsd]]
- [[createWindow]]
- [[forwardDft]]
- [[inverseDft]]
- [[optimal_filter_for_daphne_gpessina_function]]
