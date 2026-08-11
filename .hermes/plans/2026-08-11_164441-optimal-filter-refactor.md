# Refactorización del filtro óptimo DAPHNE — Plan de implementación

> **Estado:** Implementado y validado el 2026-08-11. Resultado: 74/74 tests aprobados, `checkcode` sin mensajes y test DAPHNE local con SNR coloreada 5.38283353. La implementación incluye ruido blanco, PSD coloreada estimada desde pedestal sin cancelar la corrección `PedestalSampleCount`, PSD coloreada proporcionada y modelos paramétricos AR(1)/1/f, además de ventanas rectangular, Tukey, Hann, Hamming y custom.

> **Para Hermes:** Usar desarrollo guiado por tests (TDD) y revisión independiente antes de cada commit.

**Objetivo:** Sustituir `optimal_filter_for_daphne_gpessina_function`, `mi_dft` y `mi_idtft` por APIs numéricas validadas dentro de `pds.signal`, preservando las versiones históricas, y demostrar el filtro con el dataset local DAPHNE mediante un histograma de fotoelectrones y la métrica `SNR = (mu1-mu0)/sigma0`.

**Arquitectura:** Separar transformadas, diseño del filtro, aplicación del filtro, estimación opcional de ruido y validación/histogramas. El filtro nuevo utilizará la formulación de matched/optimal filter para una plantilla conocida y ruido estacionario, PSD bilateral regularizada y normalización de ganancia unitaria. Los datos de referencia permanecerán locales e ignorados por Git.

**Stack:** MATLAB R2025b, `matlab.unittest`, `fft`/`ifft`, `pds.signal.computeSpectrum`, Signal Processing Toolbox y, únicamente para el test especializado, las herramientas legacy de ajuste gaussiano/Curve Fitting Toolbox.

---

## 1. Contexto observado y límites

### Código actual

- `src/data/optimal_filter_for_daphne_gpessina_function.m`
  - recibe ocho argumentos posicionales;
  - mezcla pedestal, inversión, filtrado, DFT, PSD, IDFT y plotting;
  - usa una frecuencia fija de 62.5 MHz;
  - divide una DFT bilateral por una PSD históricamente unilateral;
  - divide directamente por PSD sin regularización;
  - crea siempre la figura 2;
  - aplica un filtro cuando `apply_decimation=true`, pero no decima;
  - recorta arbitrariamente desde `n_disp` y no documenta la ganancia final.
- `src/data/mi_dft.m`
  - implementa DFT en O(N²);
  - aplica el phase shift, pero la ventana solo aparece en la normalización y no multiplica el waveform;
  - mezcla coeficientes DFT y estimación de PSD.
- `src/data/mi_idtft.m`
  - implementa una IDFT en O(N²);
  - el nombre `idtft` sugiere una DTFT inversa, pero el algoritmo es una IDFT discreta estándar.

### Dataset local observado

Ruta local, actualmente sin seguimiento Git:

```text
data/DAPHNE/FBK_SiPM/vgain_1700/
```

Contenido relevante:

```text
channel_24.7z                         28 MiB comprimido
  channel_24.dat                     122,880,000 bytes sin comprimir
figures/average_PE_ch_24.fig/.png
figures/average_single_PE_ch_24.fig/.png
figures/histogram_ch_24.fig/.png
config.txt
```

Inferencia que deberá confirmarse en runtime: si el `.dat` contiene `uint16` little-endian y 2048 muestras por evento, corresponde exactamente a 30,000 waveforms. Esta interpretación no se dará por cierta hasta compararla con los plots y rangos esperados.

Referencias visuales observadas:

- Pulso promedio positivo alrededor de 6.5 µs, pico aproximado de 12.2 ADU y cola exponencial.
- Histograma histórico con pedestal cerca de 0 y picos aproximados en 0.92, 1.88, 2.75 y 3.69 ADU.
- Anotación histórica: `Delta=0.92103`, `sigma0=0.1915`, `SNR=4.8095`.

Estos valores son un baseline de referencia, no un target que deba forzarse artificialmente para el filtro nuevo.

### Fuera de alcance

- No refactorizar todavía `gaussian_fit_SNR`, `find_peaks_hist_adaptive`, `extract_and_import_DAPHNE_data` ni `import_data_daphne_func`.
- No modificar el Live Script `analysis_daphne_data.mlx` durante esta etapa.
- No versionar el archivo `.7z`, `.dat`, `.fig`, `.png` ni otros datos/productos locales.
- No afirmar una mejora de SNR hasta medirla con el dataset.

---

## 2. API propuesta

### 2.1 Transformada directa

Archivo nuevo:

```text
src/+pds/+signal/forwardDft.m
```

Firma propuesta:

```matlab
[coefficients, frequencyHz] = pds.signal.forwardDft( ...
    waveform, samplePeriod, ...
    Window=ones(1, numel(waveform)), ...
    SampleShift=0)
```

Contrato:

- usa `fft`, no sumas O(N²);
- acepta un vector fila o columna y conserva una salida fila canónica;
- aplica realmente `Window` al waveform;
- exige que la ventana tenga N elementos y energía positiva;
- `SampleShift=m` equivale a `fft(circshift(windowedWaveform,m))`;
- devuelve frecuencia bilateral en orden FFT;
- no calcula PSD: esa responsabilidad permanece en `pds.signal.computeSpectrum`.

### 2.2 Transformada inversa

Archivo nuevo:

```text
src/+pds/+signal/inverseDft.m
```

Firma propuesta:

```matlab
waveform = pds.signal.inverseDft(coefficients, RealOutput=false)
```

Contrato:

- usa `ifft` con normalización MATLAB estándar;
- acepta espectros complejos finitos;
- `RealOutput=true` exige simetría hermítica dentro de tolerancia y devuelve una salida real;
- no oculta partes imaginarias significativas mediante `real(...)` silencioso.

### 2.3 Diseño del filtro óptimo

Archivo nuevo:

```text
src/+pds/+signal/designOptimalFilter.m
```

Firma propuesta:

```matlab
[filterCoefficients, diagnostics] = pds.signal.designOptimalFilter( ...
    referenceSignal, noiseWaveforms, ...
    SamplePeriod=16e-9, ...
    PedestalSampleCount=[], ...
    NoiseModel="auto", ...
    NoisePsd=[], ...
    ColoredNoiseModel="ar1", ...
    ArCoefficient=0.9, ...
    PowerLawExponent=1, ...
    Window="tukey", ...
    TukeyRatio=0.1, ...
    RegularizationFraction=1e-6, ...
    EstimateNoiseFromSignals=false, ...
    CandidateWaveforms=[], ...
    NoiseSelectionSigma=2)
```

Reglas:

1. `referenceSignal` es un waveform promedio real.
2. `noiseWaveforms` es una matriz `evento × muestra` o `[]`.
3. Cada waveform tiene su pedestal estimado y removido por fila usando `PedestalSampleCount`.
4. Si `PedestalSampleCount=[]`, usar inicialmente el primer 10% del registro, documentando el valor efectivo en `diagnostics`; el test DAPHNE establecerá explícitamente el intervalo para no depender de esta heurística.
5. La opción `Window` será explícita (`"rectangular"`, `"tukey"`, `"hann"`, `"hamming"` o vector numérico). Para PSD medida/estimada, Tukey será el default con `TukeyRatio=0.1`; la PSD se normalizará por `sampleRate*sum(window.^2)`. La plantilla no se ventaneará silenciosamente: cualquier ventana aplicada a la referencia quedará como opción separada y registrada.
6. `NoiseModel` distinguirá:
   - `"white"`: PSD plana unitaria;
   - `"measured"`: PSD bilateral promediada de `noiseWaveforms`;
   - `"estimated"`: selección ±N sigma desde `CandidateWaveforms` y PSD coloreada resultante;
   - `"provided"`: PSD bilateral de N bins entregada en `NoisePsd`;
   - `"parametric"`: PSD coloreada AR(1) o 1/f generada de manera explícita;
   - `"auto"`: medida si hay `noiseWaveforms`, estimada si se solicitó y hay candidatos, blanca en otro caso.
7. Para AR(1), usar una PSD bilateral proporcional a `1/abs(1-a*exp(-j*omega)).^2`, con `abs(a)<1`. Para 1/f, usar una frecuencia de esquina/floor explícita que evite la singularidad DC y un exponente positivo configurable. La escala global se elimina bajo normalización de ganancia unitaria, pero la forma y los parámetros se registran.
8. Si se proporciona ruido, estimar su PSD bilateral con los periodogramas ventaneados de todos los registros y comprobar que su longitud sea N.
9. Regularizar:

```matlab
floorValue = RegularizationFraction * max(noisePsd);
regularizedPsd = max(noisePsd, floorValue);
```

   Registrar el floor y la cantidad de bins afectados. Permitir una opción futura de floor absoluto, pero no incorporarla hasta que exista un caso que la requiera.
8. Construir los pesos del estimador de amplitud:

```matlab
whitenedTemplate = inverseDft(forwardDft(template)./regularizedPsd);
weights = real(whitenedTemplate);
weights = weights / dot(weights, template);
filterCoefficients = fliplr(weights);
```

9. La normalización por defecto garantiza respuesta unitaria para la plantilla:

```matlab
filter(filterCoefficients, 1, template)
```

   evaluado al final del registro debe producir 1 dentro de tolerancia.
10. No crear figuras ni aplicar low-pass Butterworth oculto.
11. Devolver `diagnostics` con plantilla corregida, PSD original/regularizada, frecuencia, pesos, floor, bins regularizados, ganancia, fuente de ruido y selección opcional de ruido.

### 2.4 Aplicación del filtro

Archivo nuevo:

```text
src/+pds/+signal/applyOptimalFilter.m
```

Firma propuesta:

```matlab
[scores, filteredWaveforms] = pds.signal.applyOptimalFilter( ...
    waveforms, filterCoefficients, ...
    PedestalSampleCount=[])
```

Contrato:

- waveforms por filas;
- remoción de pedestal por evento;
- aplica `filter(...,[],2)`;
- `scores` toma la muestra final, equivalente al producto escalar con los pesos alineados;
- opcionalmente devuelve el waveform filtrado completo;
- no grafica ni crea histogramas.

Esta función fija de manera explícita cómo debe usarse el vector devuelto por `designOptimalFilter` y evita ambigüedad entre correlación, convolución y producto escalar.

### 2.5 Estimación opcional de ruido desde señales

Cuando se cumplan simultáneamente:

```text
noiseWaveforms=[]
EstimateNoiseFromSignals=true
CandidateWaveforms no vacío
```

usar un procedimiento de dos pasadas:

1. Diseñar un matched filter inicial con PSD blanca.
2. Filtrar `CandidateWaveforms`.
3. Estimar el modo del pico de pedestal en el histograma de scores.
4. Ajustar iterativamente una gaussiana local alrededor de ese modo para obtener `mu0` y `sigma0`.
5. Seleccionar eventos con:

```matlab
abs(score-mu0) <= NoiseSelectionSigma*sigma0
```

6. Usar los waveforms originales seleccionados como vectores de ruido.
7. Calcular su PSD bilateral y rediseñar el filtro.
8. Devolver máscara, índices, `mu0`, `sigma0`, cantidad de eventos y filtro preliminar en `diagnostics`.

La selección interna no dependerá de `gaussian_fit_SNR`, porque esa función legacy mezcla plotting y ajuste y es frágil para uso dentro de una API numérica. El test especializado sí la utilizará para la métrica científica final, conforme a la solicitud.

---

## 3. Preservación y compatibilidad

### Archivos legacy

Mover con Git, sin cambiar contenido:

```text
src/data/mi_dft.m
  -> legacy/functions/mi_dft/mi_dft.m

src/data/mi_idtft.m
  -> legacy/functions/mi_idtft/mi_idtft.m

src/data/optimal_filter_for_daphne_gpessina_function.m
  -> legacy/functions/optimal_filter_for_daphne_gpessina_function/
     optimal_filter_for_daphne_gpessina_function.m
```

Verificar blobs Git y SHA-256 antes/después.

### Wrappers temporales

Crear:

```text
src/compat/mi_dft.m
src/compat/mi_idtft.m
src/compat/optimal_filter_for_daphne_gpessina_function.m
```

Criterios:

- emitir warnings `PDS:*:Deprecated`;
- mantener firmas históricas para no romper consumidores;
- delegar en las APIs `pds.signal` cuando la traducción sea inequívoca;
- documentar diferencias numéricas intencionales;
- mantener los originales fuera del MATLAB path;
- no prometer equivalencia bit a bit para errores matemáticos corregidos.

Para el wrapper del filtro óptimo, mapear:

- `pedestal_value` -> `PedestalSampleCount`;
- `noise_waveforms` -> ruido medido;
- `use_noise=false` -> PSD blanca;
- `n_decimation` -> ajustar `SamplePeriod` solo si representa una decimación previa confirmada;
- `apply_decimation` no realizará una decimación oculta;
- `filt` y el low-pass adicional se marcarán como comportamiento deprecated y no formarán parte del núcleo nuevo;
- `is_inverted` se aplicará a la plantilla antes de delegar.

La traducción exacta del par `apply_decimation/n_decimation` se caracterizará con tests antes de implementarla; si es ambigua, el wrapper emitirá un error explícito en vez de adivinar.

---

## 4. Plan TDD por tareas

### Tarea 1: Proteger los datos locales

**Archivos:**

- Modificar: `.gitignore`

**Pasos:**

1. Escribir una comprobación que demuestre que `data/DAPHNE/...` no está ignorado.
2. Agregar:

```gitignore
# Local raw/reference DAPHNE data and generated plots
/data/
```

3. Verificar con:

```bash
git check-ignore -v data/DAPHNE/FBK_SiPM/vgain_1700/channel_24.7z
```

4. Confirmar que `git status --short` no muestra archivos dentro de `data/`.
5. No agregar excepciones para figuras ni config; toda la carpeta queda local.

### Tarea 2: Caracterizar `mi_dft` y `mi_idtft`

**Archivos:**

- Crear: `tests/TestLegacyDftCharacterization.m`

**Tests de caracterización:**

- vector impulso;
- seno centrado en bin;
- longitud par e impar;
- phase shift positivo/negativo;
- round-trip DFT/IDFT;
- confirmar que la ventana legacy no multiplica el waveform;
- orientación de salidas.

Ejecutar primero sobre los originales preservados. Registrar cuáles resultados representan bugs y cuáles son contratos de interfaz.

### Tarea 3: Implementar `forwardDft` con TDD

**Archivos:**

- Crear: `tests/TestForwardDft.m`
- Crear: `src/+pds/+signal/forwardDft.m`

Ciclos RED/GREEN independientes:

1. Equivalencia con `fft` sin shift/ventana.
2. Equivalencia fila/columna.
3. Ventana multiplicada realmente por la señal.
4. Shift equivalente a `circshift`.
5. Frecuencia bilateral en orden FFT.
6. Errores para ventana incompatible, energía cero, no finitos, señal compleja si queda fuera del contrato y períodos inválidos.

### Tarea 4: Implementar `inverseDft` con TDD

**Archivos:**

- Crear: `tests/TestInverseDft.m`
- Crear: `src/+pds/+signal/inverseDft.m`

Ciclos:

1. Equivalencia con `ifft`.
2. Round-trip con `forwardDft` para N par e impar.
3. Preservación de señal compleja cuando `RealOutput=false`.
4. Salida real solo para espectro hermítico válido.
5. Validación de contenido y dimensiones.

### Tarea 5: Definir y probar la aplicación del filtro

**Archivos:**

- Crear: `tests/TestApplyOptimalFilter.m`
- Crear: `src/+pds/+signal/applyOptimalFilter.m`

Ciclos:

1. Producto escalar equivalente para un evento.
2. Matriz de eventos por filas.
3. Remoción de pedestal por evento.
4. Coherencia entre score y última muestra del waveform filtrado.
5. Errores de longitudes, no finitos y dimensiones.

### Tarea 6: Diseñar filtro para ruido blanco

**Archivos:**

- Crear: `tests/TestDesignOptimalFilter.m`
- Crear: `src/+pds/+signal/designOptimalFilter.m`

Ciclos:

1. Sin ruido, el filtro es proporcional al matched filter temporal de la plantilla.
2. Respuesta a la plantilla igual a 1.
3. Pedestal constante no altera el resultado cuando se remueve correctamente.
4. Señal invertida produce un filtro de signo consistente sin opción especial.
5. Diagnósticos y dimensiones correctos.

### Tarea 7: Añadir PSD medida y regularización

Ciclos en `TestDesignOptimalFilter`:

1. Ruido blanco medido converge al caso PSD unitaria salvo escala normalizada.
2. Ruido coloreado sintético reduce el peso de bins contaminados.
3. PSD con bins cero produce coeficientes finitos mediante floor.
4. Cambiar `RegularizationFraction` cambia únicamente bins bajo el floor.
5. PSD bilateral mantiene exactamente N bins para N par e impar.
6. Matriz de ruido procesa y centra cada registro de forma independiente.

### Tarea 8: Estimar ruido desde `CandidateWaveforms`

Ciclos sintéticos:

1. Mezcla determinista de ruido y pulsos, con semilla fija.
2. Primera pasada con ruido blanco identifica el modo del pedestal.
3. Máscara final coincide mayoritariamente con eventos de ruido conocidos.
4. Todos los seleccionados cumplen `abs(score-mu0)<=2*sigma0`.
5. El filtro final usa PSD estimada y declara `noiseSource="estimated"`.
6. Error claro si no hay suficientes eventos en el pico de ruido.
7. Si `EstimateNoiseFromSignals=false`, la ausencia de ruido usa modelo blanco.

### Tarea 9: Preservar legacy y añadir wrappers

**Archivos:**

- Mover los tres originales a `legacy/functions/...`.
- Crear los tres wrappers en `src/compat/`.
- Modificar: `setupPDSAnalysisPath.m` solo si se requieren rutas adicionales.
- Crear: `tests/TestLegacyOptimalFilterCompatibility.m`.

Verificaciones:

- blobs originales idénticos;
- path resuelve wrappers, no originales;
- warnings de deprecación;
- firmas históricas aceptadas;
- diferencias matemáticas intencionales documentadas;
- ningún plotting automático en la API nueva.

### Tarea 10: Caracterizar el archivo DAPHNE local

**Test/helper local:**

```text
tests/integration/TestOptimalFilterDaphneReference.m
tests/helpers/readDaphneReferenceForTest.m
```

Procedimiento:

1. Detectar `data/DAPHNE/FBK_SiPM/vgain_1700/channel_24.7z`.
2. Si no existe, usar una assumption de `matlab.unittest` para marcar únicamente este test como incompleto, no fallar los tests unitarios.
3. Extraer `channel_24.dat` a un directorio temporal, nunca al repositorio.
4. Probar/confirmar formato `uint16`, little-endian y longitud 2048 contra:
   - 30,000 registros esperados bajo esa hipótesis;
   - pedestal aproximado coherente con offset 2275;
   - waveform promedio y pulso coherentes con los PNG/FIG de referencia.
5. Eliminar siempre el `.dat` temporal mediante `onCleanup`.
6. Mantener el reader como helper de test; no refactorizar todavía el IO legacy.

### Tarea 11: Construir plantilla de referencia y filtro DAPHNE

En el test especializado:

1. Leer waveforms.
2. Estimar y remover pedestal por evento usando un rango anterior al pulso.
3. Construir una métrica de integración simple e independiente del filtro óptimo.
4. Identificar la población de 1 PE mediante los primeros picos del histograma de integración.
5. Promediar esos waveforms para obtener `referenceSignal`.
6. Diseñar:
   - filtro para ruido blanco;
   - filtro con ruido estimado automáticamente desde eventos del pedestal;
   - opcionalmente filtro con vectores de ruido proporcionados explícitamente.
7. Verificar respuesta unitaria, finitud y reproducibilidad.

Como control adicional, comparar la plantilla extraída con `average_single_PE_ch_24.fig` si MATLAB puede abrir la figura de forma invisible; la figura no será la fuente única de verdad.

### Tarea 12: Histograma, ajuste gaussiano y SNR especializado

Procedimiento:

1. Aplicar el filtro a todos los waveforms mediante `applyOptimalFilter`.
2. Ejecutar primero `gaussian_fit_SNR`/`find_peaks_hist_adaptive` desde `src/data` sin refactorizarlos.
3. Interpretar los dos primeros centros ordenados como pedestal y 1 PE:

```matlab
mu0 = firstPeakMean;
mu1 = secondPeakMean;
sigma0 = firstPeakSigma;
snr = (mu1-mu0)/sigma0;
```

4. Remover el pedestal de los scores:

```matlab
centeredScores = scores-mu0;
```

5. Reajustar y verificar que el pedestal final quede centrado en cero dentro de tolerancia relativa a `sigma0`.
6. Si la herramienta legacy falla por sus supuestos hard-coded, crear únicamente:

```text
tests/helpers/fitGaussianPeaksForTest.m
```

   con un ajuste acotado a los primeros picos. No mover esa lógica a producción en esta etapa.
7. Generar una figura invisible con:
   - histograma;
   - curvas gaussianas;
   - marcadores de `mu0` y `mu1`;
   - anotación de `sigma0` y SNR;
   - título con canal, VGAIN y modelo de ruido.
8. Guardar el resultado local en:

```text
outputs/validation/optimal_filter_reference_histogram.png
```

   `outputs/` ya está ignorado por Git.

Criterios iniciales del test:

- al menos dos picos gaussianos identificables;
- `mu1 > mu0`;
- `sigma0 > 0`;
- SNR finita y positiva;
- pedestal centrado tras la corrección;
- resultado determinista dentro de tolerancias acordadas en repeticiones.

No fijar todavía `SNR >= 4.8095`: el valor histórico corresponde al método de referencia observado y no necesariamente al mismo estimador. El test registrará tanto el valor histórico como los valores obtenidos con ruido blanco y PSD estimada. Una comparación de “mejora” se convertirá en criterio solo después de revisar los resultados físicos.

### Tarea 13: Documentación Obsidian

**Crear:**

```text
docs/functions/forwardDft.md
docs/functions/inverseDft.md
docs/functions/designOptimalFilter.md
docs/functions/applyOptimalFilter.md
docs/validation/optimal-filter-daphne-reference.md
```

**Actualizar:**

```text
docs/functions/mi_dft.md
docs/functions/mi_idtft.md
docs/functions/optimal_filter_for_daphne_gpessina_function.md
docs/INDEX.md
docs/catalog/MATLAB_SCRIPT_CATALOG.md
docs/dependency-maps/analysis_daphne_data_dependencies.md
docs/workflows/analysis_daphne_data.md
```

Documentar:

- derivación y convención del filtro;
- diferencia entre pesos y coeficientes FIR invertidos;
- remoción de pedestal;
- PSD bilateral y regularización;
- ruido medido, blanco y estimado;
- normalización de ganancia;
- resultado del dataset y plot generado;
- limitaciones y toolboxes;
- separación entre validado, observado e inferido.

### Tarea 14: Verificación final y revisión independiente

Ejecutar:

```matlab
results = runtests('tests','IncludeSubfolders',true);
assertSuccess(results);
```

Además:

- `checkcode` sobre APIs, wrappers y tests;
- `git diff --check`;
- escaneo de secretos/ejecución shell añadida;
- verificación de Wikilinks;
- comprobación de que `data/` no está staged;
- comprobación de que `outputs/` no está staged;
- revisión independiente centrada en:
  - derivación de matched/optimal filter;
  - normalización y alineación;
  - PSD bilateral;
  - regularización;
  - selección ±2 sigma;
  - ausencia de data leakage en el test especializado.

No realizar commit hasta presentar al usuario los resultados científicos y obtener aprobación.

---

## 5. Criterios de aceptación

1. `forwardDft` e `inverseDft` sustituyen las sumas O(N²) y están probadas para N par/impar y shifts.
2. `designOptimalFilter` devuelve coeficientes FIR finitos y normalizados a respuesta unitaria.
3. El ruido medido utiliza PSD bilateral de N bins y regularización explícita.
4. Sin ruido proporcionado, se obtiene un matched filter de ruido blanco.
5. Con `EstimateNoiseFromSignals=true`, los waveforms seleccionados cumplen la banda ±2 sigma del pico pedestal.
6. La API nueva no grafica ni altera datos de entrada.
7. El test DAPHNE extrae datos solo a un directorio temporal y genera un histograma local ignorado por Git.
8. Se obtienen `mu0`, `mu1`, `sigma0` y `SNR=(mu1-mu0)/sigma0` de forma reproducible.
9. Los originales quedan preservados y fuera del MATLAB path.
10. `data/` y `outputs/` no aparecen en el commit.
11. Todos los tests unitarios pasan; el test especializado pasa en esta máquina con el dataset presente.
12. La documentación distingue claramente resultados históricos y resultados del filtro nuevo.

---

## 6. Riesgos y decisiones abiertas

### Riesgos

- Formato binario del `.dat` aún inferido, no confirmado en runtime.
- El ajuste legacy está hard-coded para tres gaussianas y puede fallar con los cinco picos visibles.
- El filtro óptimo asume ruido estacionario y alineación temporal de la plantilla.
- La selección automática de ruido puede sesgar la PSD si el pico pedestal contiene señales pequeñas.
- Una regularización relativa fija puede necesitar revisión física posterior.
- El SNR histórico y el nuevo pueden usar escalas/estadísticos distintos.

### Decisiones propuestas para aprobación

1. **Nombres:** `forwardDft`, `inverseDft`, `designOptimalFilter`, `applyOptimalFilter`, todos en `pds.signal`.
2. **Representación:** la salida principal es un vector FIR causal; `diagnostics.weights` conserva los pesos del producto escalar.
3. **Normalización:** ganancia unitaria para la plantilla por defecto.
4. **Ruido ausente:** PSD blanca unitaria.
5. **Ruido estimado:** diseño inicial blanco, selección pedestal ±2 sigma y rediseño con PSD medida.
6. **Regularización inicial:** floor relativo `1e-6*max(PSD)`, configurable y registrado.
7. **Datos:** `/data/` completo en `.gitignore`; plots generados en `/outputs/`.
8. **Validación científica:** registrar SNR histórica y nueva sin imponer de antemano que la nueva sea mayor.

## 7. Punto de control antes de implementar

Antes de iniciar TDD, confirmar con el usuario:

- aprobación de los cuatro nombres propuestos;
- aprobación de ganancia unitaria como normalización autoritativa;
- aprobación de la selección automática en dos pasadas;
- si `SamplePeriod=16e-9` debe ser default DAPHNE o argumento obligatorio;
- si el test debe comparar formalmente la SNR nueva con 4.8095 o solo reportar ambas en esta primera etapa.
