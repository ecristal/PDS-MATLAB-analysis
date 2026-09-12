# Refactorización de estimación de pedestal — Plan de implementación

> **Para Hermes:** Implementar este plan mediante TDD y revisión científica independiente. No ejecutar MATLAB, modificar código, hacer commit ni tocar datos sin autorización explícita del usuario.

**Objetivo:** Crear una API MATLAB namespaced, determinista y diagnosticable para estimar y sustraer el pedestal por waveform, preservar y caracterizar el estimador histórico, proponer métodos más robustos y validarlos con un simulador controlado que reproduzca la respuesta SPE, el ruido coloreado, los dark counts y contaminaciones de gran amplitud en el pretrigger.

**Arquitectura:** La estimación vivirá en `pds.preprocess`; la identificación de una función de transferencia IIR discreta que preserve el undershoot y la cola larga en `pds.modeling`; y la generación reproducible de ruido/eventos/waveforms en `pds.simulation`. `estimatePedestal` calculará parámetros y diagnósticos; `subtractPedestal` aplicará valores ya estimados. El simulador será una infraestructura de validación del pedestal, no un sustituto de una simulación completa del detector ni una herramienta para optimizar SNR. La respuesta FIR medida se conservará para comparación y tests, pero la simulación científica usará prioritariamente el modelo IIR validado para no truncar la memoria larga. La integración posterior con `designOptimalFilter` y `applyOptimalFilter` preservará inicialmente el método medio actual y habilitará métodos robustos de forma explícita.

**Stack:** MATLAB R2025b Update 3, `matlab.unittest`, `iddata`/`tfest` cuando estén disponibles, Control System Toolbox, Signal Processing Toolbox, datos sintéticos deterministas, plantillas NP02 con procedencia verificada y datasets DAPHNE locales ignorados por Git.

---

## 1. Alcance científico

### Incluido

- Estimación del nivel de pedestal en una región de pretrigger explícita.
- Procesamiento de vectores y matrices `evento × muestra`.
- Métodos candidatos mínimos:
  - media del pretrigger;
  - mediana del pretrigger;
  - mediana de medias de bloques deterministas y no solapados.
- Estimación separada de:
  - nivel de pedestal por evento;
  - dispersión de las muestras del pretrigger;
  - incertidumbre del nivel estimado;
  - deriva lineal en el pretrigger;
  - contaminación/outliers y estabilidad del estimador.
- Sustracción del pedestal usando valores ya calculados.
- Caracterización de `calculateMedianPedestal` sin modificarla.
- Propuestas modernas robustas y comparación cuantitativa de estimadores.
- Preservación y refactorización de `np02_tf_estimation_pds_algorithm.m` como estimador reusable de función de transferencia/SPE.
- Generación de ruido real estacionario de longitud configurable a partir de una PSD bilateral estimada desde:
  - waveforms de ruido separados; o
  - waveforms pertenecientes a la población de pedestal (`0 PE`) seleccionada externamente.
- Generación de trazas sintéticas largas con ground truth conocido.
- Proceso puntual de dark counts y eventos contaminantes de gran amplitud.
- Recorte posterior a 2048 muestras con pretrigger parametrizable, inicialmente 100 muestras como caso de estudio.
- Integración conservadora posterior con el filtro óptimo.
- Documentación de unidades, dimensiones, calidad y procedencia.

### Excluido

- Identificación/fitting del pico de pedestal en histogramas como métrica final.
- Ajuste autoritativo de picos PE y medición final de SNR.
- ROC.
- Simulación completa de la física del SiPM, crosstalk, afterpulsing o electrónica no lineal; solo se incorporarán los procesos mínimos necesarios para estresar el estimador de pedestal.
- Cambios al Live Script `legacy/live-scripts/analysis_daphne_data.mlx`.
- Optimización del filtro o de sus ventanas/PSD.
- Versionado de plantillas NP02, archivos `.mat`, datos o resultados bajo `data/` y `outputs/` sin una política específica aprobada.

### Distinción obligatoria

No mezclar:

```text
pedestalLevel             = baseline estimado del waveform [ADU]
sampleNoiseSigma          = dispersión de muestras alrededor del baseline [ADU]
pedestalStandardError     = incertidumbre del baseline estimado [ADU]
pedestalPopulationSigma   = dispersión entre eventos o pico de histogramas [ADU]
```

La última cantidad pertenece a una etapa posterior de métricas y fitting.

---

## 2. Estado de partida y restricciones

- `calculateMedianPedestal` está en `src/daphne/calculateMedianPedestal.m` y solo cuenta con revisión estática.
- Usa ventanas aleatorias potencialmente solapadas, cambia el RNG global y devuelve el estado inmediatamente posterior al seeding, no el estado final.
- `applyOptimalFilter` y `designOptimalFilter` duplican una corrección basada en la media de las primeras `PedestalSampleCount` muestras.
- La integración DAPHNE actual utiliza explícitamente 300 muestras de pedestal.
- Registros son filas y muestras son columnas.
- Entradas ADC enteras se validan antes de convertirse a `double`.
- El dataset `FBK_SiPM/2` está afectado por ruido externo y no es referencia científica.
- La SNR preliminar del filtro no es un target para elegir el estimador.
- El working tree contiene un cambio no relacionado en `docs/INDEX.md`: un carácter `/` añadido en la línea 10. Debe resolverse o separarse antes de cualquier commit, pero no modificarse sin autorización.
- El script NP02 original se encuentra fuera del repositorio en:

```text
C:\Users\e_cri\OneDrive\Documents\INFN\NP02\Simulations\selftriggering\timestamp_location\templates_tf\templates\np02_tf_estimation_pds_algorithm.m
```

- SHA-256 observado del script: `e5ebdfe276727602af6a67cc1759e16e111ad49221769523e232bcb8f6429302`.
- El script carga `templates_np02_large_pulses.mat`, selecciona manualmente el elemento 16, usa `Tm=16 ns`, `starting_point=250`, orden 4 y un scan de shift `[-10,20]`.
- Mezcla carga, baseline, normalización, identificación `tfest`, selección de shift, conversión/modelado, compensación, plotting y escritura destructiva sobre el `.mat`.
- Usa `iddata`, `tfest`, `c2d`, `zpk`, `tf`, `d2c`, `butter` y `filter`; la función llamada `generateFractionalZeroCompensator` no fue localizada fuera del propio callsite y debe tratarse como dependencia no resuelta.
- Los `.mat` NP02 observados son MATLAB 5.0 y deben catalogarse, no copiarse ni versionarse por defecto.
- El README de plantillas grandes declara selección de pulsos LED, remoción de self-triggers, sustracción de baseline, limpieza, promedio y normalización con amplitud SPE de calibración NP02.

### Corrección conceptual sobre el ruido

En este plan, “PDS” en la frase “mismo PDS visto en la señal” se interpreta como **PSD** (power spectral density). Un escalar `mu0` no contiene información espectral y no permite reconstruir una PSD. `mu0` puede ayudar a seleccionar eventos pertenecientes a la población `0 PE`; la PSD se estima a partir de los waveforms residuales seleccionados o de una adquisición de ruido separada. Si solo se conoce `sigma0`, únicamente puede imponerse una potencia/RMS, no la forma espectral.

---

## 3. Contrato propuesto

### 3.1 Estimación

Crear:

```text
src/+pds/+preprocess/estimatePedestal.m
```

Firma preliminar:

```matlab
[pedestalLevel, diagnostics] = pds.preprocess.estimatePedestal( ...
    waveforms, ...
    SampleIndices=[], ...
    Method="mean", ...
    BlockSize=[], ...
    OutlierThreshold=3.5, ...
    Detrend=false)
```

Reglas:

1. Aceptar una matriz numérica real y finita; aceptar un vector fila como un solo waveform.
2. Rechazar vectores columna multielemento por ser ambiguos bajo el contrato `evento × muestra`; el usuario debe proporcionar explícitamente una fila para un waveform.
3. Exigir una selección explícita de pretrigger mediante `SampleIndices`; no aplicar un default implícito en análisis científico.
4. Validar índices enteros, únicos, crecientes y dentro de rango.
5. Convertir a `double` después de validar tipo, forma y dominio.
6. No modificar el RNG global.
7. No crear figuras ni escribir archivos.
8. Devolver `pedestalLevel` como vector columna, uno por evento.
9. Devolver diagnósticos por evento y metadatos globales.

Campos mínimos de `diagnostics`:

```matlab
diagnostics.method
diagnostics.sampleIndices
diagnostics.sampleCount
diagnostics.blockSize
diagnostics.blockCount
diagnostics.blockMeans
diagnostics.sampleNoiseSigma
diagnostics.pedestalStandardError
diagnostics.q25
diagnostics.q75
diagnostics.iqr
diagnostics.mad
diagnostics.slopePerSample
diagnostics.outlierFraction
diagnostics.qualityFlags
diagnostics.validEventMask
```

### 3.2 Métodos

#### `Method="mean"`

- Media aritmética del pretrigger.
- Preserva la semántica actual del filtro.
- Eficiente para ruido aproximadamente gaussiano, estacionario y sin contaminación.

#### `Method="median"`

- Mediana de muestras.
- Robusta frente a spikes aislados.
- Su relación con el nivel electrónico debe documentarse; no asumir equivalencia estadística con la media.

#### `Method="median-of-means"`

- Dividir el pretrigger en bloques deterministas contiguos y no solapados.
- Calcular la media de cada bloque.
- Usar la mediana de las medias como pedestal.
- No utilizar ventanas aleatorias ni depender de una semilla.
- Exigir que el número de muestras sea múltiplo de `BlockSize`; rechazar la configuración en vez de descartar muestras silenciosamente.

No declarar un método “mejor” hasta comparar sesgo, RMSE y estabilidad bajo escenarios controlados.

### 3.3 Sustracción

Crear:

```text
src/+pds/+preprocess/subtractPedestal.m
```

Firma:

```matlab
correctedWaveforms = pds.preprocess.subtractPedestal( ...
    waveforms, pedestalLevel)
```

Contrato:

- no reestima pedestal;
- exige un escalar para un waveform o un valor por fila;
- conserva matriz `evento × muestra`;
- devuelve `double` para evitar underflow de ADC enteros;
- rechaza valores no finitos y dimensiones incompatibles.

### 3.4 Identificación de la función de transferencia/SPE

Crear:

```text
src/+pds/+modeling/estimateTransferFunction.m
src/+pds/+plotting/plotTransferFunctionEstimate.m
```

Firma preliminar:

```matlab
[model, diagnostics] = pds.modeling.estimateTransferFunction( ...
    singlePeTemplate, samplePeriod, ...
    ModelOrder=4, ...
    ShiftCandidates=-10:20, ...
    InputSampleIndex=[], ...
    NormalizeAmplitude=true, ...
    StabilityPolicy="require-stable")
```

Reglas:

1. Recibir la plantilla numérica directamente; no cargar ni guardar `.mat` dentro del núcleo.
2. Sustraer el pedestal antes de normalizar.
3. La convención inicial será normalización por pico: la respuesta impulsional corregida de baseline tendrá pico de magnitud 1 SPE, conservando explícitamente la polaridad. Área y calibración externa podrán añadirse después como modos distintos, nunca mezclados silenciosamente.
4. Construir un impulso unitario y evaluar shifts configurables.
5. Registrar orden, número de polos/ceros, shift, fit percent, residuales, polos, ceros y estabilidad.
6. Determinar y documentar si `tfest` ya devuelve un modelo discreto para `iddata` con `Ts>0`; no aplicar `c2d` a un modelo discreto sin justificación.
7. Separar la compensación high-pass/fractional-zero del modelo SPE base; no incluir la dependencia no resuelta en la primera implementación.
8. No plottear ni modificar estructuras de entrada.
9. Conservar la plantilla FIR normalizada como baseline de comparación y para unit tests, pero no usarla como sustituto científico del IIR cuando el undershoot y el retorno largo sean relevantes.
10. Validar específicamente el undershoot: amplitud mínima, tiempo del mínimo, área negativa, residual de cola y tiempo de retorno a una banda alrededor de cero.
11. Si la respuesta no retorna a cero dentro del registro observado, distinguir entre una cola estable muy lenta (polo cercano a uno), un offset/step de baseline y un modelo marginal/inestable; no forzar un polo unitario sin evidencia.
12. La función de pérdida/selección de orden no puede estar dominada solo por el pico: debe incluir una métrica ponderada para la cola y el undershoot.

### 3.5 Generación de ruido coloreado

Crear:

```text
src/+pds/+simulation/generateColoredNoise.m
```

Firma preliminar:

```matlab
[noise, diagnostics] = pds.simulation.generateColoredNoise( ...
    sampleCount, samplePeriod, ...
    NoisePsd=noisePsd, ...
    TargetRms=[], ...
    EventCount=1, ...
    RandomStream=[])
```

Contrato:

- `NoisePsd` bilateral, N bins, orden FFT y simétrica para ruido real;
- generar coeficientes con simetría hermítica y normalización consistente, o colorear ruido blanco mediante `sqrt(PSD)` con convención documentada;
- devolver señales reales `evento × muestra`;
- permitir fijar RMS sin destruir la forma espectral;
- usar `RandStream` local o semilla explícita, nunca RNG global oculto;
- registrar PSD objetivo, PSD realizada, RMS objetivo/realizado, seed/stream y convenciones;
- para evitar periodicidad y bordes, generar la traza larga antes de recortar la ventana final.

Fuentes de PSD soportadas externamente:

1. `pds.signal.estimateNoisePsd` sobre waveforms de ruido separados.
2. `pds.signal.estimateNoisePsd` sobre waveforms `0 PE` seleccionados y corregidos de pedestal.
3. PSD proporcionada explícitamente.

La selección de eventos `0 PE` queda fuera del generador; este recibe una PSD ya construida y validada.

### 3.6 Generación de procesos de eventos

Crear:

```text
src/+pds/+simulation/generateEventTrain.m
```

Firma conceptual:

```matlab
[eventTrain, truth] = pds.simulation.generateEventTrain( ...
    sampleCount, samplePeriod, ...
    TargetEventIndex=[], ...
    TargetMultiplicity=1, ...
    DarkCountRateHz=0, ...
    LargeEventRateHz=0, ...
    LargeEventAmplitudeModel=[], ...
    RandomStream=[])
```

Reglas:

- dark counts como proceso de Poisson homogéneo: el número en un intervalo sigue Poisson y los tiempos/interarrivals deben ser consistentes con ese proceso;
- rango inicial de estudio `DarkCountRateHz = 1e3 ... 1e5 Hz`, con puntos logarítmicos representativos y valores adicionales configurables;
- permitir amplitud por dark count fija en 1 SPE o una distribución configurada;
- grandes perturbaciones con tasa y distribución de amplitud separadas;
- rango inicial de gran amplitud desde 8000 ADU hasta valores mayores que `2^14`; conservar primero la amplitud analógica/no recortada y aplicar un modelo ADC explícito posteriormente;
- nunca permitir overflow/wrap silencioso al convertir a enteros: el modelo de digitalización debe elegir explícitamente `none` o `saturate`, con rango ADC documentado;
- conservar en `truth` tiempos, amplitudes antes/después de saturación, clases y multiplicidades;
- permitir eventos antes del recorte para que sus colas y undershoot contaminen el pretrigger;
- no llamar “dark count” a ruido electrónico continuo.

### 3.7 Distribución de multiplicidad/amplitud

La hipótesis inicial para la multiplicidad del histograma será **Poisson**, con parámetro `SignalMultiplicityLambda` explícito. La arquitectura conservará además:

```text
fixed
poisson (modelo inicial)
empirical-pmf (cross-check no paramétrico)
logseries (solo si existe evidencia posterior)
```

Poisson incluye naturalmente masa en cero y poblaciones 1 PE, 2 PE, etc. La PMF empírica se usará como cross-check para separar errores del simulador de una hipótesis paramétrica incorrecta. La log-series queda como alternativa, no default, y requeriría masa explícita en cero si se usa para multiplicidades positivas. Los parámetros se estimarán con datos de entrenamiento y se comprobarán sobre datos holdout; no se elegirán por apariencia visual.

### 3.8 Composición y recorte de waveforms

Crear:

```text
src/+pds/+simulation/simulatePedestalStressWaveforms.m
```

Firma conceptual:

```matlab
[waveforms, truth, diagnostics] = ...
    pds.simulation.simulatePedestalStressWaveforms( ...
        EventCount, 2048, samplePeriod, ...
        ReferencePosition="center", ...
        PedestalWindowSampleCount=100, ...
        PedestalGuardSampleCount=0, ...
        LongPretriggerSampleCount=[], ...
        IirModel=singlePeIir, ...
        FirReference=singlePeTemplate, ...
        NoisePsd=noisePsd, ...
        SignalMultiplicityModel="poisson", ...
        DarkCountRateHz=lambdaDark, ...
        LargeEventRateHz=lambdaLarge, ...
        LargeEventAmplitudeAdc=largeAmplitude, ...
        AdcSaturationMode="none", ...
        ...)
```

Procedimiento:

1. Generar una traza larga con burn-in/pretrigger amplio.
2. Colocar el tiempo de referencia de la señal real/objetivo en el centro de la traza larga.
3. Añadir baseline verdadero y, en escenarios separados, drift/wander/steps.
4. Generar ruido electrónico coloreado sobre la traza larga.
5. Generar multiplicidad Poisson para la señal objetivo, dark counts y grandes perturbaciones.
6. Filtrar el tren de eventos con el modelo IIR discreto normalizado por pico; conservar la salida FIR solo como comparación diagnóstica.
7. Sumar todas las componentes de manera trazable en `double`, antes de cualquier digitalización.
8. Recortar N=2048 respecto a la referencia central y seleccionar explícitamente una región de pedestal de 100 muestras u otra longitud solicitada. Por defecto será una ventana inmediatamente anterior a la referencia, con `PedestalGuardSampleCount` configurable para excluir muestras cercanas al pulso.
9. Conservar por separado el índice de referencia, el pico resultante y los índices de pedestal; no asumir que coinciden por la latencia del IIR.
10. Aplicar saturación/cuantización ADC únicamente mediante una etapa explícita y conservar también el waveform previo a esa etapa.
11. Conservar ground truth antes y después del recorte.
12. Dimensionar el burn-in mediante el polo estable más lento y/o el tiempo de retorno del undershoot a una tolerancia; un criterio de energía por sí solo puede ocultar una cola pequeña pero muy larga.

Ground truth mínimo:

```matlab
truth.baselineAtEachSample
truth.pedestalTarget
truth.referenceEventIndex
truth.referencePeakIndex
truth.pedestalSampleIndices
truth.eventTimes
truth.eventAmplitudesPe
truth.largeEventAmplitudesAdcBeforeSaturation
truth.eventAmplitudesAfterSaturation
truth.eventClasses
truth.noiseRealization
truth.darkCountMask
truth.largeEventMask
truth.saturationMask
truth.iirInitialState
truth.pretriggerContaminated
```

La definición de `truth.pedestalTarget` debe ser explícita. Para baseline constante es el offset real; con drift se evaluarán por separado:

- media real del baseline en el pretrigger;
- baseline real extrapolado al tiempo del trigger.

---

## 4. Tareas TDD

### Tarea 0: Congelar y revisar el punto de partida

**Objetivo:** Garantizar que pruebas y resultados pertenezcan al mismo snapshot.

**Archivos:** ninguno.

**Pasos:**

1. Registrar `git status --short`, rama, HEAD y remotos.
2. Resolver con el usuario el `/` no relacionado de `docs/INDEX.md`.
3. Calcular SHA-256 de:
   - `src/daphne/calculateMedianPedestal.m`;
   - `src/+pds/+signal/designOptimalFilter.m`;
   - `src/+pds/+signal/applyOptimalFilter.m`;
   - tests que definen la integración actual.
4. Confirmar que `data/` y `outputs/` siguen ignorados.
5. No ejecutar MATLAB hasta autorización explícita.

**Criterio:** Snapshot estable y cambios ajenos separados.

### Tarea 1: Caracterizar la implementación legacy

**Objetivo:** Preservar el comportamiento observable de `calculateMedianPedestal` sin adoptarlo como diseño moderno.

**Crear:**

```text
tests/TestLegacyPedestalCharacterization.m
```

**Tests RED/GREEN de caracterización:**

1. Señal constante.
2. Resultado reproducible con semilla fija.
3. Salidas `pedestal`, Q25 y Q75.
4. Estado `out_seed` observado.
5. Cambio del RNG global.
6. Ventanas potencialmente repetidas/solapadas.
7. Vector fila y columna.
8. `pedestal_limit` inválido.
9. `average_width` demasiado grande.
10. `number_of_regions` inválido.
11. Parámetros no enteros: registrar comportamiento real.
12. Datos enteros y conversión implícita observada.

**Verificación focalizada futura:**

```matlab
runtests('tests/TestLegacyPedestalCharacterization.m')
```

**Criterio:** Caracterización documentada; archivo legacy sin modificaciones.

### Tarea 2: Implementar selección y validación del pretrigger

**Objetivo:** Fijar dimensiones, índices y clases antes del estimador.

**Crear:**

```text
tests/TestEstimatePedestal.m
src/+pds/+preprocess/estimatePedestal.m
```

**Ciclos TDD:**

1. Vector fila aceptado como un solo waveform con selección explícita.
2. Vector columna multielemento rechazado como ambiguo.
3. Matriz `evento × muestra`.
4. `SampleIndices` explícitos.
5. Rechazo de selección vacía efectiva.
6. Rechazo de índices repetidos, desordenados, fraccionarios o fuera de rango.
7. Rechazo de `NaN`, `Inf`, complejos y matrices vacías.
8. Conversión segura de `uint8/16/32`, `int8/16/32` y opciones enteras.
9. Ausencia de selección implícita: `SampleIndices` es obligatorio y queda registrado en diagnósticos.

**Criterio:** Validación con identificadores `pds:preprocess:estimatePedestal:*` propios.

### Tarea 3: Método de media y estadística básica

**Objetivo:** Crear una referencia determinista compatible con el comportamiento actual del filtro.

**Tests:**

1. Baseline constante exacto.
2. Múltiples offsets por evento.
3. Señal positiva y negativa.
4. `uint16` con sustracción posterior sin underflow.
5. Q25/Q75/IQR/MAD coherentes.
6. `sampleNoiseSigma` calculada sobre residuales del pretrigger.
7. `pedestalStandardError` distinta de `sampleNoiseSigma`.
8. Resultado independiente del RNG global.

**Implementación mínima:** `Method="mean"`.

**Criterio:** La salida reproduce `mean(waveforms(:,indices),2)` dentro de tolerancia.

### Tarea 4: Método de mediana

**Objetivo:** Añadir un estimador robusto simple sin mezclarlo con la media.

**Tests:**

1. Resultado exacto con número par e impar de muestras.
2. Spike aislado que sesga media pero no mediana.
3. Offsets múltiples por evento.
4. Unidades y forma de salida.
5. Incertidumbre reportada sin usar fórmulas de la media silenciosamente.

**Criterio:** Método explícito y diagnósticos consistentes.

### Tarea 5: Mediana de medias determinista

**Objetivo:** Reemplazar conceptualmente las ventanas aleatorias por bloques reproducibles.

**Tests:**

1. Partición exacta en bloques.
2. Rechazo de pretrigger no divisible por `BlockSize`.
3. Bloque contaminado por pulso.
4. Varios bloques contaminados hasta superar robustez.
5. `BlockSize=1` y un único bloque.
6. Tamaños inválidos.
7. Ausencia de cambio en RNG.
8. Repetibilidad bit a bit para entradas iguales.

**Criterio:** `blockMeans`, tamaño y cantidad de bloques trazables; ninguna muestra se descarta silenciosamente.

### Tarea 6: Diagnósticos de calidad

**Objetivo:** Detectar cuándo el pedestal estimado no es científicamente confiable.

**Tests sintéticos deterministas:**

1. Pretrigger estacionario limpio.
2. Deriva lineal conocida.
3. Step de baseline.
4. Spike aislado.
5. Pulso ancho en pretrigger.
6. Ruido heteroscedástico.
7. Región demasiado corta para evaluar estabilidad.

**Flags propuestos:**

```text
insufficient_samples
nonstationary_baseline
pretrigger_contaminated
excessive_outliers
unstable_blocks
```

**Reglas:**

- thresholds configurables y registrados;
- ningún flag debe cambiar silenciosamente el pedestal;
- `validEventMask` resume flags, pero conserva diagnósticos detallados;
- no descartar eventos automáticamente dentro del estimador.

**Estado 2026-08-14:** completada. `estimatePedestal` devuelve pendiente,
fracción de outliers, estadísticas de bloques, los cinco flags propuestos y
`validEventMask`, con thresholds configurables registrados. Los diagnósticos no
alteran el pedestal ni descartan eventos. La clase focalizada cubre los siete
escenarios sintéticos, contratos y región de una muestra. La integración DAPHNE
canal 24 analiza los primeros 3000 registros y genera PNG/FIG, CSV y JSON bajo
`outputs/validation/pedestal-daphne-fbk-vgain-1700/`.

### Tarea 7: Implementar sustracción separada

**Crear:**

```text
tests/TestSubtractPedestal.m
src/+pds/+preprocess/subtractPedestal.m
```

**Tests:**

1. Vector y pedestal escalar.
2. Matriz y pedestal por fila.
3. Datos enteros sin underflow.
4. Orientación de salida.
5. Dimensiones incompatibles.
6. Pedestal no finito.
7. Residual medio cero para caso compatible.

**Criterio:** Función pura, sin reestimación ni side effects.

### Tarea 8: Preservar y caracterizar el workflow NP02

**Objetivo:** Incorporar la procedencia y comportamiento del script sin ejecutar ni modificar los originales de OneDrive.

**Crear:**

```text
legacy/np02/np02_tf_estimation_pds_algorithm.m
inventory/np02-transfer-function-manifest.csv
docs/legacy/np02-transfer-function-estimation.md
```

**Pasos:**

1. Crear backup/manifest de script, loaders y `.mat` relacionados.
2. Verificar SHA-256 origen/copia del script: debe coincidir con `e5ebdfe...f6429302`.
3. Copiar únicamente código proyecto-propio aprobado; catalogar `.mat`, `.txt`, `.csv`, `.zip` y `.asv` sin versionarlos por defecto.
4. Registrar dependencias de toolboxes y `generateFractionalZeroCompensator` como no resuelta.
5. No ejecutar el script original porque hace `save` sobre `templates_np02_large_pulses.mat`.
6. Si se requiere caracterización runtime, trabajar exclusivamente sobre copias temporales de script y `.mat`, con hashes antes/después.
7. Documentar valores hard-coded y side effects.

**Criterio:** Originales NP02 intactos, código preservado byte a byte y datos fuera de Git.

**Estado 2026-08-13:** completado para preservación y caracterización no destructiva. El script origen/copia permanece idéntico (6517 bytes, SHA-256 `e5ebdfe...f6429302`). Los tres `.mat` catalogados se inspeccionaron solo mediante copias temporales con hashes antes/después. El IIR no vacío del elemento 16 se preservó como coeficientes textuales trazables en `legacy/np02/np02_iir_model_element16.json`; los `.mat` siguen fuera de Git. La caracterización legacy ejecutable pasa 6/6 sin ejecutar el script histórico.

### Tarea 9: Caracterizar y refactorizar la estimación de funciones de transferencia

**Crear:**

```text
tests/TestEstimateContinuousTransferFunction.m
tests/TestEstimateDiscreteTransferFunction.m
tests/integration/TestDaphneVgain1700TransferFunctionIdentification.m
src/+pds/+identification/estimateContinuousTransferFunction.m
src/+pds/+identification/estimateDiscreteTransferFunction.m
src/+pds/+plotting/plotTransferFunctionEstimate.m
docs/functions/estimateContinuousTransferFunction.md
docs/functions/estimateDiscreteTransferFunction.md
```

**Contrato común de identificación:**

1. APIs genéricas bajo `pds.identification`, sin nombres ni supuestos NP02.
2. Entradas SISO `inputSignal` y `outputSignal` en memoria, con `SampleTime` explícito.
3. Buscar `poleOrder=1:MaxOrder`; `MaxOrder` limita el número de polos y evita órdenes extremos.
4. Usar por defecto una sola estructura por orden, `zeroOrder=max(0,poleOrder-1)`, reproduciendo de forma acotada la relación histórica `tfest(data,ord+1,ord)` sin una búsqueda combinatoria de todos los numeradores.
5. Buscar cada orden sobre `DelayRange`, configurable y expresado en samples.
6. Seleccionar por defecto el menor orden cuyo fit de selección esté dentro de `FitTolerance` puntos porcentuales del mejor fit estable (`SelectionCriterion="parsimonious-fit"`).
7. Permitir criterios explícitos posteriores como `"best-fit"`, `"bic"` y `"aicc"`, pero no declararlos equivalentes sin tests.
8. Reportar si la solución alcanza `MaxOrder`, sin aumentar el límite automáticamente.
9. Mantener el núcleo libre de carga de archivos, plotting y persistencia.

**Separación de dominios:**

- `estimateContinuousTransferFunction` llama `tfest` con `Ts=0` y devuelve un modelo racional en `s`.
- `estimateDiscreteTransferFunction` llama `tfest` con `Ts=SampleTime`, identifica directamente el IIR discreto y devuelve coeficientes utilizables como `filter(B,A,u)` con variable `z^-1`.
- La API discreta no se implementa mediante `c2d` del modelo continuo. Una conversión continuo→discreto solo puede usarse como comparación diagnóstica separada.

**Ciclos TDD:**

1. Respuestas continuas y discretas sintéticas conocidas con impulso conocido.
2. Recuperación del delay exacto dentro de `DelayRange`.
3. Sweep determinista de `1:MaxOrder` con una estructura numerador/denominador por orden.
4. Selección parsimoniosa: escoger el menor orden dentro de `FitTolerance` del máximo.
5. Caso en que se alcanza `MaxOrder`, registrado en diagnósticos.
6. Modelos estables y respuestas impulsionales finitas; candidatos fallidos/inestables quedan registrados y no se seleccionan silenciosamente.
7. Modelo discreto expresado en `z^-1`; equivalencia de `filter(B,A,u)` con la respuesta del modelo.
8. Modelo continuo con `Ts=0` y modelo discreto con `Ts=SampleTime`.
9. Rechazo de señales incompatibles, degeneradas, no finitas o demasiado cortas.
10. Validación de `SampleTime`, `MaxOrder`, `DelayRange`, `FitTolerance` y criterio.
11. Ausencia de cambios en RNG, plotting y escritura desde el núcleo.
12. Diagnósticos reproducibles con tabla por candidato: dominio, órdenes, delay, fit, criterio, estabilidad, validez y fallo de estimación.
13. Comparación global mediante fit/NRMSE y residuales.
14. Comparación específica del undershoot: mínimo, índice temporal, área negativa y residual de cola.
15. Recuperación de una constante de tiempo larga sintética.
16. Normalización por pico igual a 1 SPE después de sustracción de baseline, con polaridad registrada, como etapa explícita de preparación/validación y no como efecto oculto del identificador.
17. Plotting probado separadamente con figura invisible.

**Caracterización histórica NP02:** conservar el script byte a byte y documentar su carga, selección fija, normalización, búsqueda de shift, relación de órdenes, `c2d`, representación `z^-1`, plotting, dependencia faltante y `save`. Cualquier reproducción se ejecutará solo sobre copias temporales verificadas; la validación moderna recibirá una plantilla ya importada en memoria.

**Criterio:** ambas APIs seleccionan modelos acotados y trazables; la respuesta IIR reproduce pico, undershoot y retorno largo dentro de tolerancias separadas. Ningún modelo se aprobará únicamente por un porcentaje global dominado por el pico.

**Estado 2026-08-13 — tracer bullet de identificación:**

- Implementadas `pds.identification.estimateContinuousTransferFunction` y `pds.identification.estimateDiscreteTransferFunction` con núcleo común privado.
- Búsqueda acotada a `MaxOrder × numel(DelayRange)` y una estructura `zeroOrder=max(0,poleOrder-1)` por orden de polos.
- Implementados `parsimonious-fit`, `best-fit`, BIC y AICc; todos los scores actuales son in-sample.
- El delay se aplica con padding de ceros y se reporta separadamente; no se usa wrapping circular.
- La API discreta identifica directamente en `z^-1`; no usa `c2d`.
- `tfest` se ejecuta con semilla interna fija y el RNG del llamador se restaura mediante `onCleanup`.
- Diagnósticos por candidato: órdenes, delay, fit, RMSE, NRMSE, BIC, AICc, estabilidad, validez y fallo.
- Revisión independiente detectó y se corrigió mediante RED/GREEN: validez indebidamente acoplada a AICc, sobreconteo discreto de un coeficiente fijo, residuales continuos FOH inconsistentes y protección insuficiente del JSON NP02.
- `valid` exige estimación estable y fit/RMSE finitos; NRMSE puede quedar indefinida sin acoplar la elegibilidad, y BIC/AICc exigen finitud solo para su propio criterio.
- Conteo BIC/AICc: continuo `np+nz+1`; discreto `np+1` para `nz=0` y `np+nz` para `nz>0` estrictamente propio.
- Residuales continuos y plots de integración usan explícitamente ZOH.
- El JSON NP02 está fijado por SHA-256 y una copia temporal con coeficiente alterado es rechazada por test.
- Los errores de selección sin score finito conservan el namespace de la API pública y restauran el RNG del llamador incluso tras la identificación interna.
- Integración local sobre la plantilla congelada DAPHNE FBK SiPM, VGAIN 1700, canal 24, para ambos dominios.
- La integración genera por dominio PNG/FIG de waveform+pico+cola, PNG/FIG del mapa orden-delay, CSV de candidatos y JSON de métricas bajo `outputs/validation/`, ignorado por Git.
- Hallazgo DAPHNE: ambos fits globales superan 90 %, pero ninguno reproduce el undershoot real de aproximadamente -2.30 %; esto queda fijado por assertions y plots revisables.
- Evidencia post-fix: 17/17 pruebas focalizadas identificación+legacy, 106/106 suite estándar, integración local separada 1/1 con 12 artefactos, y `checkcode=0` en MATLAB R2025b. `runtests('tests')` no descubre automáticamente el subdirectorio `tests/integration`, por lo que ambos gates se reportan separadamente.

**Cierre de infraestructura y evaluación 2026-08-14:**

1. `TrainingSampleCount` separa fitting/selección en el prefijo y métricas de
   extrapolación temporal en el sufijo; no se presenta como holdout independiente
   entre eventos.
2. `evaluateTransferFunctionResponse` mide pico, timing, undershoot, área
   negativa, RMSE global/cola, primera entrada en banda y asentamiento permanente.
3. La validación compara continuo directo, discreto directo y continuo→`c2d` ZOH.
4. `prepareSinglePeTemplate` hace explícitos baseline, polaridad y normalización
   1 SPE.
5. `plotTransferFunctionEstimate` es una API reusable probada con figura invisible.
6. Un test sintético recupera un polo lento conocido.
7. La evaluación DAPHNE identifica directamente sobre el waveform promedio
   congelado `average_single_PE_ch_24.fig` —sin waveforms individuales ni
   suavizado—, usando `1:1200` para entrenamiento y `1201:2048` para cola.
8. Se generan seis artefactos científicos adicionales bajo
   `outputs/validation/iir-daphne-fbk-vgain-1700/scientific-validation/`.

**Resultado científico:** infraestructura de Tarea 9 completada; modelo DAPHNE no
aprobado. El target promedio tiene undershoot `-0.0229539` y asentamiento en 2036,
mientras continuo/discreto predicen mínimos positivos de aproximadamente `3e-6`
y asentamiento prematuro en 846/848. `scientificApproval=false`. Completar la
evaluación no implica recomendar un IIR que contradice el waveform promedio.

La caracterización histórica detectó una diferencia relevante: la plantilla procesada del elemento 16 contiene mínimo post-pico negativo (`-0.001365...`), mientras que el IIR almacenado reconstruido no cruza cero en 4096 muestras. Por ello el tracer bullet de software no se presenta como aprobación científica del modelo.

### Tarea 10: Implementar generador de ruido coloreado

**Crear:**

```text
tests/TestGenerateColoredNoise.m
src/+pds/+simulation/generateColoredNoise.m
```

**Ciclos TDD:**

1. PSD blanca produce ruido real y de media compatible con cero.
2. N par e impar con simetría hermítica correcta.
3. PSD AR(1) sintética: PSD ensemble recuperada.
4. PSD power-law sintética: forma recuperada.
5. PSD medida bilateral proporcionada.
6. RMS objetivo dentro de tolerancia.
7. Múltiples eventos por filas.
8. Stream/seed local reproducible.
9. RNG global sin cambios.
10. Rechazo de PSD unilateral, no simétrica, negativa o degenerada.
11. Normalización de unidades documentada.
12. Generación larga + recorte sin discontinuidad periódica visible.

**Verificación estadística:** comparar PSD promedio de un ensemble, no exigir coincidencia bin a bin de una realización.

**Estado 2026-08-14:** completada. `generateColoredNoise` implementa PSD bilateral
hermítica, N par/impar, eventos por filas, RMS objetivo, seed/stream local sin
mutar RNG global y generación larga con recorte central. Los tests cubren PSD
blanca, AR(1), power-law, rechazos y recuperación ensemble. La integración usa la
PSD medida del pretrigger de los primeros 3000 registros DAPHNE canal 24 y genera
PNG/FIG, CSV y JSON bajo
`outputs/validation/colored-noise-daphne-fbk-vgain-1700/`; obtuvo correlación
log-PSD `0.9999246` y error L2 relativo `0.025861`.

**Gates del snapshot candidato 2026-08-14:**

```text
pruebas focalizadas Tareas 6/9/10+NP02: 52/52
suite estándar:                        133/133
integraciones DAPHNE:                     3/3
checkcode en 15 archivos .m:                 0
Wikilinks:                         308/308
artefactos nuevos no vacíos:         14/14
hashes NP02/template e ignores:        PASS
```

Los tres grupos de plots PNG/FIG se revisaron visualmente dos veces; la segunda
revisión no encontró defectos significativos. Los outputs permanecen ignorados y
no forman parte del snapshot de código/documentación.

La auditoría pre-commit añadió regresiones RED/GREEN para: RMS objetivo sobre el
recorte efectivamente entregado, trazabilidad de PSD antes/después del recorte,
conversión exacta de enteros en opciones/APIs nuevas, y área negativa post-pico
separada del área negativa total. La integración declara explícitamente sus
thresholds de pedestal y protege la limpieza para que solo opere bajo
`outputs/validation/`.

La revisión independiente del árbol anterior detectó que la pendiente diagnóstica
todavía usaba OLS. El hallazgo se cerró con una regresión RED donde un spike tardío
sesgaba la pendiente, seguida de un ajuste IRLS Tukey-bisquare GREEN. El cambio es
solo diagnóstico: el pedestal elegido no cambia. La integración DAPHNE fue
regenerada y sus fracciones observacionales/documentación se actualizaron.

### Tarea 11: Implementar procesos de dark counts y grandes perturbaciones

**Crear:**

```text
tests/TestGenerateEventTrain.m
src/+pds/+simulation/generateEventTrain.m
```

**Tests:**

1. Tasas cero producen solo el evento objetivo.
2. Índice/amplitud del evento objetivo exactos.
3. Superposición de eventos en un mismo sample.
4. Dark counts con amplitud 1 SPE.
5. Sweep de `lambda_dark` desde `1e3` hasta `1e5 Hz`.
6. Gran evento con amplitud fija conocida.
7. Sweep de gran amplitud desde 8000, alrededor de `2^14` y por encima de `2^14`.
8. Distribución configurable de gran amplitud.
9. Eventos antes del futuro recorte conservados.
10. Ground truth coincide exactamente con el tren discreto.
11. Reproducibilidad con stream local.
12. Ensamble grande: media/varianza del conteo compatibles con Poisson dentro de tolerancia estadística.
13. Conversión ADC no produce wrap; saturación solo cuando se solicita y con máscara explícita.
14. Tasas, amplitudes y multiplicidades inválidas rechazadas.

**Criterio:** La física implementada queda limitada y explícita; dark rate y large-event rate nunca se confunden.

**Estado 2026-08-14 — componente aislado completado:**

- `generateEventTrain` devuelve matrices evento × muestra en `double` y conserva
  componentes separados para referencia, dark counts y perturbaciones grandes.
- Los procesos dark/large son procesos puntuales de Poisson independientes en una
  traza progenitora; los tiempos continuos se discretizan con
  `floor(t/samplePeriod)+1` y las colisiones se suman.
- Dark counts tienen amplitud 1 SPE. Las perturbaciones grandes admiten amplitud
  fija o uniforme, con tests en 8000, `2^14` y 20000.
- Seed/stream son locales y mutuamente excluyentes; el RNG global no cambia.
- Sin saturación los valores superiores a `2^14` se preservan sin wrap. Una
  `SaturationRange` explícita conserva tren no saturado y máscara de clipping; no
  se infiere todavía cuantización ni encoding ADC.
- Ground truth conserva tiempos, índices, amplitudes, conteos, componentes,
  máscaras, conteos esperados y procedencia RNG. Eventos anteriores a un crop
  futuro permanecen trazables.
- Se ejecutaron seis ciclos RED/GREEN y, tras revisión científica independiente,
  cuatro caracterizaciones adicionales cerraron brechas de cobertura de mapeo,
  independencia, RNG, tipos seguros y clipping. Evidencia focalizada:
  `TestGenerateEventTrain` 10/10 y `checkcode` 0 mensajes en implementación/test.
- La documentación de contrato y límites está en
  `docs/functions/generateEventTrain.md`.

La integración con respuesta IIR/FIR, ruido, baseline y recorte pertenece a la
Tarea 13; este cierre no implica validar todavía el simulador compuesto ni elegir
un estimador de pedestal.

**Gates del snapshot candidato de Tarea 11:**

```text
TestGenerateEventTrain:            10/10
suite estándar:                  143/143
integraciones DAPHNE de regresión:  3/3
checkcode implementación/test:      0/2
Wikilinks:                        308/0 faltantes
artefactos previos no vacíos:       14/14
hashes NP02/template:               PASS
git diff --check:                   PASS
```

### Tarea 12: Implementar multiplicidad configurable

**Objetivo:** Reproducir ocupación sin imponer prematuramente una distribución logarítmica.

**Tests:**

1. Multiplicidad fija.
2. Poisson con `SignalMultiplicityLambda` conocida, incluyendo eventos 0 PE.
3. PMF empírica normalizada como cross-check.
4. PMF con masa en cero.
5. Log-series solo con parámetro válido y soporte positivo.
6. Modelo zero-inflated log-series explícito si se incorpora.
7. Frecuencias ensemble compatibles con la PMF.
8. Ground truth por evento.

**Criterio:** Poisson es el modelo paramétrico inicial del histograma; `empirical-pmf` sirve como control no paramétrico y log-series solo se promoverá si mejora cuantitativamente la descripción en datos holdout.

**Estado del candidato 2026-08-14:**

- Extensión implementada en `pds.simulation.generateEventTrain` sin cambiar el
  default de Tarea 11: `fixed` con multiplicidad 1 no consume draws adicionales.
- Modelos disponibles: `fixed`, `poisson` y `empirical-pmf`.
- La multiplicidad por waveform escala `ReferenceAmplitude`, conserva salida
  `double` y queda registrada en ground truth junto con parámetros y media esperada.
- Poisson incluye 0 PE y queda limitado al dominio numérico validado
  `SignalMultiplicityLambda <= 1e9`; la PMF empírica acepta masa explícita en
  cero y exige soporte entero creciente y normalización estricta.
- Fixed y soporte PMF se limitan a `flintmax` para todas las clases numéricas;
  el producto amplitud×multiplicidad se valida antes del RNG para impedir que
  overflow aritmético aparezca como saturación física.
- `log-series` se rechaza explícitamente: no se incorpora sin evidencia cuantitativa
  en holdout.
- La multiplicidad se aplica antes de la superposición y del clipping explícito;
  `unsaturatedEventTrain` continúa siendo reconstruible por componentes.
- Se completaron seis ciclos RED→GREEN (fixed, Poisson, PMF, validación
  fail-fast, techo PTRS y prevención de overflow) y nueve caracterizaciones
  adicionales, incluidas CDF agrupada, compatibilidad exacta con Tarea 11,
  frontera PMF, RNG, enteros, separación de clases y clipping.

**Gates del candidato de Tarea 12:**

```text
TestGenerateSignalMultiplicity:      16/16
regresión TestGenerateEventTrain:    10/10
suite estándar:                     159/159
integraciones DAPHNE de regresión:     3/3
checkcode implementación/tests:        0/3
```

La integración con respuesta FIR/IIR, baseline, ruido, burn-in y crop sigue fuera
hasta la Tarea 13. Estos gates no seleccionan todavía un estimador de pedestal ni
cambian `scientificApproval = false`.

### Tarea 13: Componer trazas largas y recortar waveforms

**Crear:**

```text
tests/TestSimulatePedestalStressWaveforms.m
src/+pds/+simulation/simulatePedestalStressWaveforms.m
```

**Tests:**

1. Sin ruido/eventos: baseline y referencia temporal exactos.
2. Filtrado IIR de impulso 1 PE produce pico unitario y undershoot esperado.
3. Comparación FIR/IIR confirma que el IIR conserva la cola más allá del soporte FIR.
4. N final exactamente 2048.
5. Señal de referencia colocada en el centro de la traza larga.
6. Región de pedestal exactamente de 100 muestras u otro valor solicitado, independiente del índice central.
7. `PedestalGuardSampleCount` desplaza la región sin cambiar su longitud y evita solapamiento con la referencia.
8. Región de pedestal, guard y N inválidos rechazados.
9. Evento previo al crop deja cola/undershoot en la región de pedestal.
10. Dark count dentro de la región de pedestal marcado en truth.
11. Gran evento dentro de la región de pedestal marcado en truth.
12. Ruido coloreado generado sobre traza larga antes del crop.
13. Burn-in suficiente según polo lento y retorno del undershoot.
14. Baseline constante, slope, wander y step como escenarios separados.
15. Componentes individuales suman exactamente el waveform final.
16. Amplitudes >`2^14` permanecen en `double` antes del ADC y se saturan solo con modo explícito.
17. Repetibilidad completa con configuración + seed.

**Criterio:** Cada waveform viene acompañado por ground truth suficiente para calcular el error real del estimador de pedestal.

### Tarea 14: Comparar estimadores en datos sintéticos

**Objetivo:** Elegir método por evidencia, no por intuición.

**Crear:**

```text
tests/validation/TestPedestalEstimatorSyntheticValidation.m
```

**Escenarios:**

- ruido blanco gaussiano;
- ruido coloreado con PSD conocida y con PSD medida;
- cuantización ADC;
- baseline constante, deriva, wander y steps;
- outliers impulsivos no correlacionados;
- dark count rate `lambda_dark` entre `1e3` y `1e5 Hz`, inicialmente con grilla logarítmica;
- eventos grandes con tasa `lambda_large` y amplitudes de 8000 ADU, cercanas a `2^14` y mayores que `2^14`;
- escenarios sin saturación y con saturación ADC explícita, analizados por separado;
- colas/undershoot de eventos ocurridos antes del recorte;
- señal de referencia centrada en la traza larga y región de pedestal de 50, 100, 200 y 300 muestras como puntos discretos iniciales;
- combinaciones diseñadas de contaminación y drift, evitando un producto cartesiano ciego.

**Métricas:**

```text
bias respecto al pedestal ground truth
RMSE
median absolute error
percentiles del error
failure/flag rate
false-valid y false-invalid rate de quality flags
coverage de incertidumbre
runtime
```

Separar los resultados por definición del estimando:

```text
baseline medio real del pretrigger
baseline real al tiempo del trigger
```

Usar streams/semillas fijas y tolerancias justificadas. Reservar configuraciones de simulación holdout para comparar métodos y evitar ajustar thresholds sobre el mismo ensemble. Esta validación no debe decidir mediante la SNR final del filtro.

**Productos:** únicamente bajo `outputs/validation/pedestal/`, ignorado por Git.

### Tarea 15: Validación exploratoria DAPHNE

**Objetivo:** Caracterizar el pedestal real sin promover el dataset a referencia.

**Datos:** señal y ruido separados de `data/DAPHNE/FBK_SiPM/2`.

**Procedimiento:**

1. Mantener split de entrenamiento/evaluación.
2. Analizar solo el pretrigger configurado, inicialmente 300 muestras.
3. Comparar métodos en:
   - distribución del nivel por evento;
   - `sampleNoiseSigma`;
   - pendiente del pretrigger;
   - fracción de eventos con flags;
   - diferencia entre adquisición de señal y ruido.
4. No seleccionar método por maximizar SNR sobre los mismos registros.
5. Generar plots diagnósticos, no de calibración.

**Caveat obligatorio:** VGAIN/electrónica específicos y ruido externo presente.

### Tarea 16: Integración conservadora con el filtro

**Objetivo:** Eliminar duplicación sin cambiar por defecto resultados validados.

**Modificar solo después de aprobar tareas 1–15:**

```text
src/+pds/+signal/designOptimalFilter.m
src/+pds/+signal/applyOptimalFilter.m
tests/TestDesignOptimalFilter.m
tests/TestApplyOptimalFilter.m
```

**Reglas:**

1. Default de integración: `PedestalMethod="mean"` para preservar semántica actual.
2. `PedestalMethod="median"` y `"median-of-means"` deben ser explícitos.
3. Reutilizar `pds.preprocess.estimatePedestal` y `subtractPedestal`.
4. No estimar dos veces el pedestal en la misma ruta.
5. Registrar método, región y flags en diagnósticos.
6. Mantener respuesta unitaria del filtro.
7. Mantener los resultados actuales como regresión de compatibilidad, no como referencia científica.

**Criterio:** Suite existente continúa verde con `Method="mean"`; diferencias robustas quedan en tests nuevos separados.

### Tarea 17: Documentación y revisión independiente

**Crear:**

```text
docs/functions/estimatePedestal.md
docs/functions/subtractPedestal.md
docs/functions/estimateTransferFunction.md
docs/functions/generateColoredNoise.md
docs/functions/generateEventTrain.md
docs/functions/simulatePedestalStressWaveforms.md
docs/validation/pedestal-estimation.md
docs/validation/np02-transfer-function-estimation.md
docs/validation/pedestal-simulation.md
```

**Modificar:**

```text
docs/INDEX.md
docs/functions/designOptimalFilter.md
docs/functions/applyOptimalFilter.md
```

**Documentar:**

- definición de cada estadístico;
- unidades ADU;
- dimensiones;
- región de pretrigger;
- método y parámetros;
- quality flags;
- diferencias frente a legacy;
- ejemplos de uso;
- evidencia exacta de tests;
- limitaciones científicas del dataset.

Después de la validación, actualizar la documentación Obsidian con la misma evidencia del snapshot.

**Revisión:** hashes iniciales/finales, tests focalizados, suite completa, `checkcode`, `git diff --check`, datos/outputs ignorados y revisión independiente read-only.

No hacer commit ni push sin autorización explícita.

---

## 5. Estrategia de aceptación

### Correctitud de software

- Entradas válidas e inválidas cubiertas.
- Datos y opciones enteras seguros.
- Sin RNG global ni plotting.
- Resultados deterministas.
- Diagnósticos completos.
- Ninguna duplicación de corrección de pedestal.

### Correctitud estadística

- Sesgo y RMSE conocidos en escenarios sintéticos.
- `sampleNoiseSigma` y `pedestalStandardError` no confundidos.
- Contaminación y deriva visibles mediante flags.
- Método robusto no elegido exclusivamente por un dataset.
- Comparación sobre configuraciones holdout no usadas para ajustar thresholds.

### Correctitud de modelado y simulación

- Respuesta IIR estable con peak-normalization a 1 PE explícita.
- Undershoot y retorno largo verificados con métricas específicas, no solo NRMSE global.
- FIR conservado como comparación, no como reemplazo de la memoria larga del IIR.
- PSD ensemble generada compatible con la PSD objetivo.
- RMS, unidades FFT y simetría hermítica verificados.
- Conteos de dark events compatibles con el proceso Poisson configurado.
- Eventos grandes separados de dark counts y ruido electrónico.
- Recorte de 2048 muestras y pretrigger parametrizable exactos.
- Ground truth completo y reproducible para cada waveform.
- Ninguna escritura sobre los originales NP02.

### Compatibilidad

- El método medio preserva el comportamiento actual de filtro.
- Legacy permanece intacto y fuera del path autoritativo.
- Cualquier diferencia con `calculateMedianPedestal` queda documentada.

### Validez científica

- Resultados DAPHNE etiquetados exploratorios.
- No usar la SNR como objetivo de entrenamiento del pedestal.
- No declarar referencia universal de pedestal o ruido.

---

## 6. Riesgos y decisiones abiertas

1. **Región de pretrigger:** 100 muestras es el caso inicial de stress test; 300 pertenece a la integración previa. Ambos deben ser parámetros, no reglas universales.
2. **Estimando con drift:** definir si se busca la media del pretrigger o el baseline al tiempo del trigger; se reportarán ambos antes de elegir.
3. **Método moderno preferido:** media, mediana o mediana de medias se decidirá tras validación, no antes.
4. **Drift:** inicialmente diagnosticar; cualquier extrapolación lineal será un método separado y explícito.
5. **Estimación de sigma:** acordar desviación estándar clásica, MAD escalada, ambas y/o PSD.
6. **Eventos inválidos:** inicialmente informar flags, no descartar automáticamente.
7. **RNG legacy:** preservar para caracterización, pero usar streams locales en API/simulación.
8. **Normalización 1 PE:** decisión actual: normalización por pico tras sustraer baseline, conservando la polaridad.
9. **Modelo `tfest`:** verificar dominio discreto, estabilidad y orden; el IIR es necesario para representar undershoot/retorno largo y debe evaluarse con métricas de cola.
10. **Dependencia faltante:** `generateFractionalZeroCompensator` no bloquea el núcleo y queda fuera hasta recuperar especificación/fuente.
11. **PSD de pedestal:** `mu0` selecciona población, pero la PSD proviene de waveforms; `sigma0` solo fija RMS si no hay forma espectral.
12. **Distribución de multiplicidad:** Poisson es la hipótesis inicial; PMF empírica será el cross-check y log-series solo una alternativa posterior.
13. **Dark noise:** rango decidido `1e3...1e5 Hz`; número de eventos en ventana es Poisson y los tiempos forman un proceso puntual.
14. **Grandes perturbaciones:** amplitud inicial desde 8000 hasta valores mayores que `2^14`; su tasa y PMF exactas siguen configurables.
15. **ADC:** aclarar hardware/codificación y límite efectivo antes de activar saturación. Hasta entonces, generar en `double`, conservar amplitud no recortada y no hacer wrap.
16. **Complejidad combinatoria:** usar escenarios diseñados y sweeps focalizados, no todas las combinaciones posibles.
17. **Integración:** no modificar el filtro hasta validar de forma aislada pedestal y simulador.
18. **Definición temporal:** decisión actual: colocar la señal real/de referencia en el centro de la traza larga. Mantener separados `referenceEventIndex`, `referencePeakIndex` y los 100 índices usados por el estimador de pedestal.

---

## 7. Orden de ejecución recomendado

```text
snapshot y preservación
  → caracterización legacy del pedestal
  → API de selección/validación
  → media
  → mediana
  → mediana de medias
  → diagnósticos de calidad
  → sustracción
  → preservación/caracterización NP02
  → función de transferencia IIR SPE normalizada por pico
  → verificación específica de undershoot y retorno largo
  → generador de ruido coloreado
  → dark counts y grandes perturbaciones
  → multiplicidad configurable
  → trazas largas y recorte N=2048/pretrigger configurable
  → validación sintética con ground truth
  → validación DAPHNE exploratoria
  → integración conservadora
  → documentación y revisión independiente
```

Los primeros entregables deben ser: (1) caracterización y contrato probado del pedestal; (2) preservación segura del workflow NP02; y (3) modelo IIR validado con énfasis en undershoot/cola larga antes de usar el simulador para conclusiones científicas. La plantilla FIR se utilizará únicamente como referencia de forma y soporte para tests iniciales.


## Reanudación de Tarea 12 — 2026-09-12

Se detectó y corrigió un tercer defecto numérico: para medias Poisson positivas
extremadamente pequeñas, `exp(-lambda)` puede redondearse a uno y el bucle Knuth
anterior devolvía -1. Ahora se ejecuta siempre el primer draw para lambda positiva;
la rama lambda=0 sigue sin consumir RNG. El séptimo ciclo RED→GREEN añade
`tinyPositivePoissonMeansNeverProduceNegativeCounts`, con realmin, 1e-20, eps/4 y eps.

Verificación ejecutada en esta reanudación: suite estándar 159/159 (incluye
multiplicidad 16/16 y Tarea 11 10/10), cero fallos/incompletos; checkcode cero
mensajes en los tres archivos. Las integraciones DAPHNE 3/3 son evidencia previa,
no repetida hoy. El snapshot anterior `888d45f7…4d82d` queda superado por esta
corrección y no autoriza aprobar los nuevos bytes. No hubo staging, commit ni push.
