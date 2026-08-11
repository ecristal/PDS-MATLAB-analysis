# Refactorización de `f_fourier` — Plan de implementación

> **Estado:** Implementado y validado el 2026-08-11 en MATLAB R2025b Update 3. Resultado final: 24/24 tests aprobados, incluidos 3 tests de caracterización de la referencia legacy y 5 del wrapper compatible. La migración de `optimal_filter_for_daphne_gpessina_function` queda fuera de este alcance.

> **Para Hermes:** Ejecutar únicamente con autorización explícita para crear y ejecutar tests MATLAB. Aplicar TDD y no modificar el Live Script original.

**Objetivo:** Sustituir gradualmente `f_fourier` por una API MATLAB namespaced, validada y científicamente explícita para espectro de amplitud, PSD y RMS, preservando compatibilidad temporal con los workflows legacy.

**Arquitectura:** Mantener una copia legacy inmutable de la función actual, implementar el cálculo puro en `pds.signal.computeSpectrum`, separar la visualización en `pds.plotting.plotSpectrum` y proporcionar un wrapper temporal `f_fourier` para llamadas antiguas. La API nueva devuelve resultados lineales y metadatos en una estructura; la conversión a dB utiliza una referencia explícita y nunca modifica los resultados computacionales.

**Tech Stack:** MATLAB R2025b, bloques `arguments`, opciones `Name=Value`, `matlab.unittest`, Git.

---

## 1. Estado y decisiones confirmadas

- `f_fourier` es código propio y puede adoptarse bajo `src/+pds`.
- Solo existe una versión localizada de la función.
- La FFT compleja no debe conservarse por evento.
- La referencia de amplitud no es siempre un ADC de 14 bits.
- La conversión depende de las unidades de entrada y de una referencia explícita.
- No se ejecutará MATLAB sin autorización explícita.
- El `.mlx` original bajo `legacy/` no se modificará.

## 2. Impacto estático observado

Se localizaron 41 llamadas bajo el árbol fuente histórico `Scripts_analisis`:

- llamadas con 2 argumentos;
- llamadas con 3 argumentos;
- llamadas con 4 argumentos;
- ninguna llamada histórica localizada proporciona los 5 argumentos de la firma staged.

En el repositorio staged existen tres consumidores:

```matlab
[~, fourier_] = f_fourier(data_i,Tm,false,"dBFS");
[freq, ~] = f_fourier(data(1,:),Tm,false,"dBFS");
[~,~,~,pds_noise,~] = f_fourier(noise,16e-9,false);
```

Riesgos observados:

1. Incompatibilidad de número de argumentos.
2. Conversión a dBFS dentro de la función incluso con `do_plot=false`.
3. Segunda conversión a dBFS en `analysis_daphne_data.mlx`.
4. Manejo incorrecto del último bin cuando N es impar.
5. DC eliminada después de la FFT sin contrato explícito.
6. RMS integrado con `trapz`, que da medio peso a los extremos.
7. Vectores columna interpretados como múltiples registros de una muestra.
8. Salidas modificadas por decisiones de plotting.
9. PSD unilateral usada por un consumidor que requiere PSD bilateral.
10. División futura por una componente DC anulada en el filtro óptimo.

## 3. Contrato de la nueva función

### Archivo

Crear:

`src/+pds/+signal/computeSpectrum.m`

### Firma propuesta

```matlab
function spectrum = computeSpectrum(waveforms, samplePeriod, options)
arguments
    waveforms {mustBeNumeric, mustBeNonempty}
    samplePeriod (1,1) double {mustBePositive, mustBeFinite}
    options.RemoveMean (1,1) logical = false
    options.Sidedness (1,1) string ...
        {mustBeMember(options.Sidedness,["one-sided","two-sided"])} = "one-sided"
    options.InputUnit (1,1) string = "ADU"
end
```

### Convención dimensional

- Un vector fila o columna representa un único registro.
- Una matriz representa `records × samples`.
- La dimensión FFT es siempre la segunda.
- Debe haber al menos dos muestras por registro.

### Salida propuesta

```matlab
spectrum.frequencyHz
spectrum.amplitudeMean
spectrum.psdMean
spectrum.complexMean
spectrum.rmsPerRecord
spectrum.samplePeriod
spectrum.sampleRateHz
spectrum.sampleCount
spectrum.recordCount
spectrum.inputUnit
spectrum.sidedness
spectrum.meanRemoved
```

`complexMean` es una única media coherente entre registros. No se almacenan FFT complejas por evento.

### Resultados lineales

`computeSpectrum` no debe:

- convertir a dB o dBFS;
- normalizar por el máximo;
- abrir figuras;
- alterar amplitud/PSD por opciones de presentación.

## 4. Definiciones matemáticas propuestas

Para una matriz `x` de A registros y N muestras, con `Fs = 1/Tm`:

```matlab
Y = fft(x, [], 2);
amplitudeTwoSided = abs(Y) / N;
psdTwoSided = abs(Y).^2 / (N * Fs);
```

### Espectro unilateral

Usar bins `1:floor(N/2)+1`.

Factor de duplicación:

- DC nunca se duplica.
- Si N es par, Nyquist nunca se duplica.
- Si N es impar, el último bin positivo sí se duplica.

### Eliminación de DC

- `RemoveMean=true`: sustraer la media de cada registro antes de la FFT.
- `RemoveMean=false`: conservar DC.
- Nunca anular `PSD(1)` después del cálculo.

### RMS

Calcular por registro:

```matlab
rmsPerRecord = sqrt(sum(psd, 2) * df);
```

La suma de bins debe ser consistente con Parseval para espectro unilateral o bilateral.

### Promedios

- `amplitudeMean = mean(amplitudePerRecord,1)`.
- `psdMean = mean(psdPerRecord,1)`.
- `complexMean = mean(Y,1)`.

No promediar magnitudes en dB.

## 5. Visualización separada

### Archivo

Crear:

`src/+pds/+plotting/plotSpectrum.m`

### Interfaz propuesta

```matlab
lineHandle = pds.plotting.plotSpectrum(spectrum, ...
    Quantity="amplitude", ...
    Scale="linear", ...
    ReferenceValue=1, ...
    ReferenceLabel="", ...
    Normalize="none", ...
    Axes=[]);
```

Opciones:

- `Quantity`: `"amplitude"` o `"psd"`.
- `Scale`: `"linear"` o `"decibel"`.
- `ReferenceValue`: referencia numérica en la unidad de entrada.
- `ReferenceLabel`: por ejemplo `"dBFS"`, `"dBV"` o `"dB re 1 ADU"`.
- `Normalize`: `"none"` o `"peak"`.
- `Axes`: axes existente; crear uno solo si se omite.

Conversiones:

```matlab
amplitudeDb = 20*log10(amplitude/referenceValue);
psdDb = 10*log10(psd/referenceValue^2);
```

No inferir automáticamente full scale desde el número de bits. El workflow DAPHNE debe proporcionar la referencia acordada.

## 6. Compatibilidad legacy

### Preservación

Relocalizar mediante Git la implementación original a una carpeta legacy que no se añada al MATLABPATH, conservando el contenido byte a byte:

`legacy/functions/f_fourier/f_fourier.m`

### Wrapper

Crear:

`src/compat/f_fourier.m`

El wrapper debe aceptar entre 2 y 5 argumentos:

```matlab
f_fourier(signal, Tm)
f_fourier(signal, Tm, doPlot)
f_fourier(signal, Tm, doPlot, yLabel)
f_fourier(signal, Tm, doPlot, yLabel, normalize)
```

Defaults legacy:

```matlab
doPlot = false;
yLabel = "abs";
normalize = false;
```

Responsabilidades:

1. Llamar a `pds.signal.computeSpectrum`.
2. Adaptar la estructura a `[f,P1,Y,Pc1,rms_]`.
3. Emitir un warning de deprecación identificable.
4. Mantener temporalmente la referencia legacy de 14 bits únicamente cuando se solicite `"dBFS"` mediante la API antigua.
5. No usar el wrapper en código nuevo.

La semántica exacta de `P1` en modo `dBFS` debe quedar caracterizada por tests antes de implementar el wrapper.

## 7. Integración con los consumidores staged

### `analysis_daphne_data.mlx`

No modificar el archivo legacy.

En una futura copia de trabajo/entry point:

1. Calcular espectro lineal dentro del procesamiento.
2. Acumular/promediar amplitudes lineales.
3. Convertir a dB una sola vez al visualizar.
4. Eliminar la segunda aplicación de `20*log10(.../2^14)`.
5. Reutilizar el vector de frecuencias ya calculado, evitando una FFT adicional de `data(1,:)`.

### `optimal_filter_for_daphne_gpessina_function.m`

No modificar durante la refactorización aislada de `f_fourier`.

Durante su propia revisión:

1. Solicitar `Sidedness="two-sided"`.
2. Verificar orden FFT de la PSD.
3. Definir regularización explícita.
4. Evitar división por cero/DC.
5. Definir normalización del filtro.

## 8. Estrategia TDD

No crear producción antes de observar cada test fallar por la razón esperada.

### Task 1 — Contrato de vector y frecuencia

**Test:** `tests/TestComputeSpectrum.m`

Casos:

- vector fila;
- vector columna equivalente;
- matriz records × samples;
- vector de frecuencia con longitud y resolución correctas.

**RED:** ejecutar el test antes de crear `computeSpectrum`.

**GREEN:** implementar únicamente normalización dimensional, metadatos y frecuencia.

### Task 2 — Tono en bin exacto con N par

Generar un coseno de amplitud pico conocida y frecuencia exactamente bin-centered.

Verificar:

- bin de frecuencia;
- amplitud unilateral;
- DC/Nyquist no duplicados.

### Task 3 — N impar

Verificar que el último bin positivo se duplica y que la potencia se conserva.

### Task 4 — PSD y Parseval

Comparar:

```matlab
mean(abs(x).^2,2)
```

contra:

```matlab
sum(psd,2)*df
```

para sidedness unilateral y bilateral.

### Task 5 — RemoveMean

Con señal `offset + tono`:

- `RemoveMean=false` conserva DC y RMS total.
- `RemoveMean=true` retira DC y conserva RMS AC.

### Task 6 — Promedio de registros

Usar registros con fases opuestas:

- `complexMean` puede cancelarse coherentemente;
- `amplitudeMean` no debe cancelarse;
- `psdMean` no debe cancelarse;
- no se exponen FFT por evento.

### Task 7 — Validaciones

Casos de error:

- entrada vacía;
- una sola muestra;
- NaN/Inf;
- sample period cero, negativo o no finito;
- sidedness inválido.

### Task 8 — Plotting

Tests sobre axes invisibles:

- la función usa axes proporcionados;
- amplitud dB usa factor 20;
- PSD dB usa factor 10;
- la referencia es obligatoriamente positiva;
- el resultado `spectrum` no cambia;
- no aparecen `Inf` sin una política explícita para ceros.

### Task 9 — Wrapper legacy

Probar llamadas con 2, 3, 4 y 5 argumentos y las cinco salidas históricas.

### Task 10 — Integración estática

- Confirmar que `setupPDSAnalysisPath` añade `src` y `src/compat` explícitamente.
- Confirmar que no existe shadowing con la copia legacy.
- Buscar consumidores staged y migrarlos solo en sus revisiones correspondientes.

## 9. Comandos de validación previstos

Solo después de autorización para ejecutar MATLAB:

```bash
matlab -batch "results=runtests('tests/TestComputeSpectrum.m'); assertSuccess(results)"
```

Después del plotting:

```bash
matlab -batch "results=runtests({'tests/TestComputeSpectrum.m','tests/TestPlotSpectrum.m'}); assertSuccess(results)"
```

Después del wrapper:

```bash
matlab -batch "results=runtests({'tests/TestComputeSpectrum.m','tests/TestPlotSpectrum.m','tests/TestFFourierCompatibility.m'}); assertSuccess(results)"
```

## 10. Criterios de aceptación

- La implementación original queda preservada y fuera del path.
- API nueva namespaced y sin plotting.
- Entradas validadas y dimensiones explícitas.
- N par/impar tratados correctamente.
- PSD/RMS cumplen Parseval dentro de tolerancia.
- DC controlada solo mediante `RemoveMean`.
- Conversión dB exige referencia explícita.
- No se almacenan FFT por evento.
- Wrapper cubre llamadas legacy de 2–5 argumentos.
- Ningún `.mlx` original se modifica.
- Tests escritos primero, RED observado y luego GREEN.
- Cambios divididos en commits pequeños y revisables.

## 11. Decisiones adoptadas

- El wrapper legacy conserva `2^14` como referencia únicamente cuando una llamada antigua solicita `"dBFS"`.
- La API nueva no infiere una referencia desde el número de bits: toda conversión a dB exige `ReferenceValue` explícito.
- `complexMean` permanece como una única media coherente; no se exponen FFT por evento.
- Los bins cero producen `-Inf` por defecto al convertir a dB; `MinimumDecibels` permite aplicar un floor solo durante plotting.
- El namespace definitivo para este componente es `+pds`.
- La ejecución de tests MATLAB fue autorizada y completada.

## 12. Archivos previstos

- Create: `src/+pds/+signal/computeSpectrum.m`
- Create: `src/+pds/+plotting/plotSpectrum.m`
- Create: `src/compat/f_fourier.m`
- Move preserving history: `external/fiuna-pasantia-tesis-matlab/f_fourier.m` → `legacy/functions/f_fourier/f_fourier.m`
- Modify: `setupPDSAnalysisPath.m`
- Create: `tests/TestComputeSpectrum.m`
- Create: `tests/TestPlotSpectrum.m`
- Create: `tests/TestFFourierCompatibility.m`
- Modify: `docs/functions/f_fourier.md`
- Modify: `docs/catalog/MATLAB_SCRIPT_CATALOG.md`
- Modify: `docs/dependency-maps/analysis_daphne_data_dependencies.md`

No se modificará `legacy/live-scripts/analysis_daphne_data.mlx` durante este trabajo.
