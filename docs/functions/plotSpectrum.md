---
type: matlab-function
status: project-api
review_status: tested-runtime
review_mode: [static, runtime]
repo_path: src/+pds/+plotting/plotSpectrum.m
input: "[[computeSpectrum]]"
tags: [matlab, plotting, spectrum, decibel, runtime-validated]
---

# plotSpectrum

## Propósito

Visualiza amplitud o PSD producida por [[computeSpectrum]] sin modificar la estructura numérica original.

## Firma

```matlab
lineHandle = pds.plotting.plotSpectrum(spectrum, Name=Value)
```

## Opciones

```matlab
Quantity="amplitude"      % o "psd"
Scale="linear"            % o "decibel"
ReferenceValue=1
ReferenceLabel=""
Normalize="none"          % o "peak"
MinimumDecibels=-Inf
Axes=[]
```

## Convenciones dB

Amplitud:

```matlab
20*log10(amplitude/ReferenceValue)
```

PSD:

```matlab
10*log10(psd/ReferenceValue^2)
```

`ReferenceValue` siempre se expresa en la unidad de amplitud de entrada. La API no infiere bits ADC.

Con `Normalize="peak"`, la cantidad lineal se divide primero por su máximo. Si además se solicita escala dB, normalmente debe usarse `ReferenceValue=1`, porque la referencia se aplica después de esa normalización.

Los valores cero producen `-Inf` por defecto. `MinimumDecibels` permite aplicar un floor únicamente al dato mostrado.

## Ejemplo dBFS

```matlab
pds.plotting.plotSpectrum(spectrum, ...
    Quantity="amplitude", ...
    Scale="decibel", ...
    ReferenceValue=2^14, ...
    ReferenceLabel="dBFS", ...
    MinimumDecibels=-140);
```

## Ejemplo PSD lineal

```matlab
figure;
ax = axes;
pds.plotting.plotSpectrum(noiseSpectrum, ...
    Quantity="psd", Axes=ax);
```

## Ejemplos con eje X logarítmico

`plotSpectrum` controla la cantidad y la escala vertical, pero actualmente no expone una opción específica para la escala del eje X. Para frecuencias en escala logarítmica, proporciona un objeto `Axes` y configúralo después del plotting.

### Amplitud lineal con frecuencia logarítmica

```matlab
fig = figure;
ax = axes(fig);

pds.plotting.plotSpectrum(spectrum, ...
    Quantity="amplitude", ...
    Scale="linear", ...
    Axes=ax);

ax.XScale = 'log';

% El espectro unilateral contiene el bin DC en f = 0.
positiveFrequency = spectrum.frequencyHz(spectrum.frequencyHz > 0);
ax.XLim = [positiveFrequency(1), positiveFrequency(end)];
```

### Recuperar los ejes desde el handle devuelto

No es obligatorio crear los ejes previamente:

```matlab
lineHandle = pds.plotting.plotSpectrum(spectrum);
ax = ancestor(lineHandle, 'axes');

ax.XScale = 'log';
positiveFrequency = spectrum.frequencyHz(spectrum.frequencyHz > 0);
ax.XLim = [positiveFrequency(1), positiveFrequency(end)];
```

### Amplitud en dBFS con frecuencia logarítmica

```matlab
fig = figure;
ax = axes(fig);

pds.plotting.plotSpectrum(spectrum, ...
    Quantity="amplitude", ...
    Scale="decibel", ...
    ReferenceValue=2^14, ...
    ReferenceLabel="dBFS", ...
    MinimumDecibels=-140, ...
    Axes=ax);

ax.XScale = 'log';
positiveFrequency = spectrum.frequencyHz(spectrum.frequencyHz > 0);
ax.XLim = [positiveFrequency(1), positiveFrequency(end)];
```

`ReferenceValue=2^14` es solo un ejemplo compatible con la convención histórica de DAPHNE. Para un análisis nuevo debe usarse el full scale físico correspondiente a la adquisición.

### PSD en dB con frecuencia logarítmica

```matlab
fig = figure;
ax = axes(fig);

pds.plotting.plotSpectrum(noiseSpectrum, ...
    Quantity="psd", ...
    Scale="decibel", ...
    ReferenceValue=1, ...
    ReferenceLabel="dB re 1 ADU", ...
    MinimumDecibels=-160, ...
    Axes=ax);

ax.XScale = 'log';
positiveFrequency = noiseSpectrum.frequencyHz( ...
    noiseSpectrum.frequencyHz > 0);
ax.XLim = [positiveFrequency(1), positiveFrequency(end)];
```

### Nota sobre espectros bilaterales

Un eje logarítmico no puede mostrar frecuencias negativas. Los ejemplos anteriores están destinados a resultados creados con `Sidedness="one-sided"`. Para un espectro bilateral debe seleccionarse explícitamente la rama positiva o utilizar una representación lineal centrada mediante `fftshift`.

## Evidencia runtime

Probado en MATLAB R2025b Update 3 mediante `TestPlotSpectrum`: 4/4 tests aprobados.

Casos cubiertos:

- axes explícitos;
- inmutabilidad de la estructura;
- factor 20 para amplitud;
- factor 10 y referencia al cuadrado para PSD;
- floor en dB;
- normalización por pico.

## Limitaciones

- No aplica ventanas ni estima PSD: solo presenta resultados existentes.
- Para `Sidedness="two-sided"`, el vector permanece en orden FFT y no es monótono; `plotSpectrum` lo grafica en ese mismo orden. El caller debe reordenar frecuencias y datos si necesita una vista centrada/monótona.
- No selecciona automáticamente dBFS/dBV.
- El caller conserva responsabilidad sobre la referencia física correcta.

## Enlaces

- [[computeSpectrum]]
- [[f_fourier]]
