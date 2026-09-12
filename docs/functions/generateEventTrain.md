---
type: matlab-function
status: validated-isolated
tags: [simulation, poisson, multiplicity, dark-counts, disturbances, ground-truth, matlab]
---

# `pds.simulation.generateEventTrain`

Estado del programa de pedestal: [[pedestal-estimation-refactor-status]].
Cierre y alcance de la auditoría: [[task12-audit-closure]].
Esta actualización de estado documental es posterior al snapshot auditado;
producción y tests permanecen sin cambios.

## Propósito

Genera trenes discretos de impulsos, por filas, manteniendo separados:

1. un evento objetivo con multiplicidad configurable;
2. dark counts como proceso puntual de Poisson;
3. perturbaciones grandes como un segundo proceso de Poisson independiente.

La función produce impulsos antes de aplicar baseline, ruido electrónico, respuesta
FIR/IIR, recorte o cuantización ADC.

```matlab
[eventTrain, truth] = pds.simulation.generateEventTrain( ...
    4096, 16e-9, EventCount=1000, ...
    ReferenceIndex=2048, ReferenceAmplitude=1, ...
    SignalMultiplicityDistribution="poisson", ...
    SignalMultiplicityLambda=1.5, ...
    DarkRateHz=1e5, LargeEventRateHz=50, ...
    LargeAmplitudeDistribution="uniform", ...
    LargeAmplitudeRange=[8000, 20000], Seed=1700);
```

La forma de `eventTrain` es `EventCount × sampleCount`.

## Multiplicidad del evento objetivo

`SignalMultiplicityDistribution` admite tres contratos:

- `"fixed"`: usa el entero no negativo `SignalMultiplicity` en todas las filas;
- `"poisson"`: muestrea un entero no negativo con media
  `SignalMultiplicityLambda` en `[0, 1e9]`; incluye naturalmente eventos de 0 PE;
- `"empirical-pmf"`: muestrea de `SignalMultiplicitySupport` usando
  `SignalMultiplicityPmf`.

El default es `"fixed"` con `SignalMultiplicity=1`. Este default reproduce el
contrato de Tarea 11 y no consume draws adicionales del RNG.

Para cada waveform `i`, el componente objetivo cumple exactamente:

```text
referenceComponent(i, ReferenceIndex)
    = ReferenceAmplitude * signalMultiplicity(i)
```

En modo Poisson:

```text
E[M] = Var[M] = SignalMultiplicityLambda
```

La PMF empírica exige soporte estrictamente creciente de enteros no negativos no
mayores que `flintmax`, probabilidades no negativas y suma 1. Puede asignar masa
explícita a 0 PE. Su media registrada es:

```text
E[M] = sum(SignalMultiplicitySupport .* SignalMultiplicityPmf)
```

`log-series` no está implementado ni se acepta como nombre de distribución. Solo se
incorporará si mejora cuantitativamente la descripción de datos holdout frente a
Poisson y la PMF empírica.

La multiplicidad fija y cada valor del soporte PMF deben ser `<= flintmax`, con la
misma política para entradas `double`, `single` o enteras. PTRS queda limitado a
`SignalMultiplicityLambda <= 1e9`: este techo evita la región donde la evaluación
log-PMF por diferencias de `gammaln` pierde precisión. La forma, paridad y varianza
se verifican en el propio techo. Un draw Poisson excepcional por encima de
`flintmax` se rechaza defensivamente en vez de degradar el ground truth.

## Convención temporal y proceso de Poisson

La duración progenitora es:

```text
T = sampleCount * samplePeriod
```

Para cada waveform y cada clase aleatoria se generan interarribos exponenciales
con su propia tasa. Solo se conservan tiempos continuos `t` con `0 <= t < T` y se
mapean al índice discreto:

```text
sampleIndex = floor(t / samplePeriod) + 1
```

Por ello el conteo esperado por waveform es:

```text
E[N_dark]  = DarkRateHz       * T
E[N_large] = LargeEventRateHz * T
```

Los procesos dark y large consumen realizaciones distintas del mismo stream local;
no comparten tasa, conteos ni amplitudes. Si varios eventos caen en el mismo sample,
sus amplitudes se suman. El evento objetivo se suma después con índice y amplitud
exactos.

Los dark counts tienen amplitud discreta exactamente igual a 1 SPE. La polaridad
del waveform aparecerá posteriormente al aplicar una respuesta 1 SPE cuya polaridad
se conserva; esta API representa multiplicidades positivas, no el waveform filtrado.

## Perturbaciones grandes

`LargeAmplitudeDistribution` admite:

- `"fixed"`: cada perturbación usa `LargeAmplitude`;
- `"uniform"`: cada amplitud se muestrea uniformemente con soporte efectivo
  `[minimum, maximum)` a partir de `LargeAmplitudeRange=[minimum maximum]`.

Los valores iniciales de stress test incluyen `8000`, `2^14` y valores superiores a
`2^14`. Estas amplitudes son provisionales y se expresan en las unidades que el
caller asigne al tren; no constituyen un modelo confirmado del ADC DAPHNE.

## Reproducibilidad

- `Seed` crea un `RandStream('mt19937ar', ...)` local.
- `RandomStream` usa el stream escalar proporcionado por el caller.
- `Seed` y `RandomStream` son mutuamente excluyentes.
- Sin ninguno se usa un stream local determinista con seed 0.
- El RNG global de MATLAB no cambia.

Un `RandomStream` proporcionado sí avanza su propio estado, como parte explícita del
contrato del caller.

En modos de multiplicidad aleatorios, la multiplicidad se muestrea antes de dark y
large. Las tres clases consumen draws distintos de un mismo stream local. Son
separadas en el modelo y en ground truth, pero no se promete estabilidad por
componente frente a cambios de parámetros: cambiar una distribución o tasa puede
desplazar las subsecuencias consumidas después.

## Double, wrap y saturación

La composición siempre ocurre en `double`. Sin `SaturationRange`, ningún valor se
recorta ni se convierte a entero, incluso por encima de `2^14`; no hay wrap
implícito.

Antes de consumir RNG se comprueba que
`ReferenceAmplitude * maximumRelevantMultiplicity` permanezca finito. Para fixed se
usa el valor fijo; para PMF, el mayor soporte con masa positiva; para Poisson con
media positiva, `flintmax` como límite defensivo. El overflow aritmético no puede
ocultarse detrás del clipping explícito.

`SaturationRange=[minimum maximum]` solicita clipping explícito al final de la
composición. En ese caso:

- `eventTrain` contiene el resultado saturado;
- `truth.unsaturatedEventTrain` conserva el valor previo;
- `truth.saturationMask` marca cada muestra que fue recortada;
- `truth.saturationRange` registra el rango solicitado.

Esto no implementa cuantización, encoding, signedness ni offset binario. Una etapa
ADC física completa permanece separada hasta conocer el contrato de hardware.

## Ground truth

```text
sampleCount, samplePeriod, durationSeconds, eventCount,
referenceIndex, referenceAmplitude,
signalMultiplicityDistribution, signalMultiplicity,
signalMultiplicityFixedValue, signalMultiplicityLambda,
signalMultiplicitySupport, signalMultiplicityPmf,
expectedSignalMultiplicity, referenceComponent,
darkComponent, largeEventComponent, darkEventMask, largeEventMask,
unsaturatedEventTrain, saturationMask, saturationRange,
darkEventCount, largeEventCount,
darkEventTimesSeconds, darkEventIndices, darkEventAmplitudes,
largeEventTimesSeconds, largeEventIndices, largeEventAmplitudes,
darkRateHz, largeEventRateHz,
expectedDarkEventCount, expectedLargeEventCount,
largeAmplitudeDistribution, largeAmplitude, largeAmplitudeRange,
randomSource, seed
```

La identidad reconstructiva antes del ADC es exacta:

```text
unsaturatedEventTrain = referenceComponent
                      + darkComponent
                      + largeEventComponent
```

Las listas de tiempos/índices/amplitudes preservan cada ocurrencia individual. Los
componentes preservan la suma discreta, incluidas colisiones. Las máscaras indican
presencia por clase, no multiplicidad.

Como la API genera la traza progenitora completa y no recorta, eventos anteriores a
un crop futuro permanecen en las listas, máscaras y componentes. La Tarea 13 será
responsable de filtrar y recortar conservando esta trazabilidad.

## Validación

Se rechazan antes de asignar memoria o consumir RNG:

- longitudes, conteos o índices no enteros/positivos;
- `ReferenceIndex > sampleCount`;
- periodo, amplitudes o tasas no finitos;
- tasas negativas;
- amplitudes no positivas;
- multiplicidad fija negativa, no entera o mayor que `flintmax`;
- lambda de multiplicidad negativa, no finita o mayor que `1e9`;
- soporte de multiplicidad vacío, no entero, negativo, repetido, no creciente o
  mayor que `flintmax`;
- PMF no finita, negativa, de longitud incompatible o cuya suma no sea 1;
- producto amplitud×multiplicidad que pueda desbordar `double`;
- distribuciones de multiplicidad distintas de `fixed`, `poisson` y
  `empirical-pmf`, incluido `log-series`;
- rangos no crecientes;
- distribuciones de amplitud large distintas de `fixed` y `uniform`;
- seed no entero/no negativo;
- stream inválido o conflicto seed/stream;
- enteros `int64`/`uint64` fuera del rango contiguo exacto de `double`.

El coste temporal incluye el muestreo de multiplicidad por waveform y el número total
de llegadas dark/large; los vectores de tiempos crecen dinámicamente. El muestreo
Poisson usa Knuth para medias menores que 10 y PTRS para medias mayores o iguales a
10. Su dominio validado termina en `1e9`; fuera de él la API falla antes del RNG. El
caller debe dimensionar memoria/tiempo incluso dentro del dominio soportado.

## Evidencia de Tareas 11 y 12

`tests/TestGenerateEventTrain.m` cubre diez comportamientos:

1. tasas cero, referencia exacta y ground truth vacío;
2. procesos separados, colisiones y reconstrucción independiente;
3. replay, RNG global y media/varianza Poisson para `1e3...1e5 Hz`;
4. amplitudes fijas/uniformes, stress alrededor de `2^14` y saturación explícita;
5. validaciones y enteros no representables exactamente;
6. eventos antes de un crop futuro y replay con `RandomStream`;
7. orden temporal, mapeo exacto tiempo→índice e incrementos Poisson independientes;
8. tasas dark/large distintas, covarianza cruzada y colisión explícita de tres clases;
9. equivalencia de enteros seguros, seed por defecto y preservación global para
   todos los modos RNG;
10. clipping inferior, fronteras exactas y saturación posterior a colisiones.

Resultado focalizado actual:

```text
TestGenerateEventTrain: 10/10
TestGenerateSignalMultiplicity: 16/16
checkcode:                0 mensajes / 3 archivos
```

`TestGenerateSignalMultiplicity` cubre:

1. multiplicidad fija y ground truth por waveform;
2. equivalencia exacta del default de Tarea 11 con `fixed=1` y estado del stream;
3. Poisson con masa en cero, media y varianza para `lambda=2.5`;
4. PMF empírica, masa en cero, frecuencias ensemble y masas exactamente nulas;
5. validación fail-fast y no consumo del stream ante error;
6. rama PTRS con `lambda=25`;
7. caso `lambda=0`, frontera Knuth/PTRS y medias `9.9`, `10` y `1000`;
8. techo Poisson `1e9`: forma central, varianza, paridad y rechazo inmediato;
9. CDF Poisson agrupada para `lambda=10` y `25`;
10. frontera de normalización PMF y truth normalizado;
11. replay con `Seed` y `RandomStream`, preservando el RNG global;
12. enteros seguros equivalentes en fixed/Poisson/PMF;
13. límites representables y prevención de overflow antes del RNG;
14. separación estadística y reconstructiva frente a dark/large;
15. multiplicidad aplicada antes de superposición y clipping explícito.

Este resultado valida el componente aislado. No constituye todavía validación del
simulador compuesto ni selección científica de un estimador de pedestal.


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
