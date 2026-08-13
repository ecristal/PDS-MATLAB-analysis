---
type: matlab-function
status: tracer-bullet-validated
tags:
  - identification
  - transfer-function
  - continuous-time
  - matlab
---

# `pds.identification.estimateContinuousTransferFunction`

## Propósito

Identifica un modelo SISO continuo, estable y racional en `s` a partir de señales de entrada/salida ya cargadas en memoria. La API no contiene carga de archivos, plotting ni persistencia.

```matlab
[model, diagnostics] = ...
    pds.identification.estimateContinuousTransferFunction( ...
    inputSignal, outputSignal, ...
    SampleTime=16e-9, ...
    MaxOrder=6, ...
    DelayRange=-10:20, ...
    FitTolerance=0.5, ...
    SelectionCriterion="parsimonious-fit");
```

## Contrato

- `inputSignal` y `outputSignal`: vectores numéricos reales, finitos, no vacíos, de igual longitud y al menos cuatro muestras.
- La orientación de entrada se canonicaliza a columna.
- `SampleTime`: periodo de muestreo positivo y explícito, en segundos.
- `MaxOrder`: máximo número de polos. Debe ser entero positivo y menor que la longitud de la señal.
- `DelayRange`: shifts enteros únicos, expresados en muestras, con valor absoluto menor que la longitud de la señal.
- `FitTolerance`: tolerancia no negativa en puntos porcentuales.
- Enteros `int64`/`uint64` fuera del rango entero contiguo exactamente representable por `double` se rechazan antes de convertir.

## Búsqueda acotada

Por defecto se evalúa una sola estructura por orden de polos:

```text
poleOrder = 1:MaxOrder
zeroOrder = max(0, poleOrder - 1)
```

Para cada estructura se evalúa cada valor de `DelayRange`. Por tanto, la cantidad nominal de candidatos es:

```text
MaxOrder × numel(DelayRange)
```

No se realiza un producto cartesiano exhaustivo de todos los órdenes posibles del numerador. Esto conserva la relación histórica NP02 `tfest(data,ord+1,ord)` interpretada como polos=`ord+1`, ceros=`ord`, pero limita explícitamente el máximo.

Los shifts se aplican a la entrada con padding de ceros, no mediante `circshift`; no se envuelven muestras del final al principio. El modelo devuelto representa la dinámica estimada después del alineamiento. Para reproducir la predicción sobre la entrada original se debe aplicar `diagnostics.selectedDelaySamples` con la misma convención de padding.

## Dominio y estabilidad

El motor llama `tfest(...,'Ts',0)` y devuelve un `idtf` continuo con `model.Ts == 0`. Se solicita `EnforceStability=true`. Candidatos fallidos, inestables o con RMSE no finita quedan registrados y no se seleccionan. `valid` representa estimación estable con fit y RMSE finitos; no exige que NRMSE, BIC o AICc sean finitos.

## Selección

Criterios disponibles:

- `"parsimonious-fit"` — predeterminado. Escoge el menor orden cuyo `FitPercent` esté a no más de `FitTolerance` puntos porcentuales del mejor candidato estable; dentro de ese orden escoge el mayor fit.
- `"best-fit"` — máximo `FitPercent`.
- `"bic"` — mínimo BIC calculado con residuales sample-domain.
- `"aicc"` — mínimo AICc calculado con residuales sample-domain.

`"parsimonious-fit"` y `"best-fit"` usan todos los candidatos `valid`. BIC y
AICc añaden, respectivamente, el requisito de que su propio score sea finito;
una AICc indefinida no descarta un candidato para selección por fit o BIC.

Para los modelos continuos, la predicción usada por RMSE, NRMSE, BIC y AICc se
simula explícitamente con zero-order hold (`lsim(...,'zoh')`), coherente con la
convención de entrada del `iddata` usado por `tfest`.

`FitPercent`, BIC y AICc son actualmente métricas **in-sample**. No equivalen a rendimiento de validación holdout. El conteo usado en BIC/AICc es:

```text
parameterCount = poleOrder + zeroOrder + 1
```

Este conteo corresponde a los coeficientes libres de la transferencia continua
normalizada por el coeficiente líder del denominador.

## Diagnósticos

```text
domain
sampleTime
maxOrder
delayRange
fitTolerance
selectionCriterion
numeratorOrderPolicy
selectedPoleOrder
selectedZeroOrder
selectedDelaySamples
selectedFitPercent
selectedRmse
selectedNrmse
selectedBic
selectedAicc
bestFitPercent
maxOrderReached
candidateTable
```

`candidateTable` contiene por candidato:

```text
poleOrder, zeroOrder, delaySamples, fitPercent,
rmse, nrmse, bic, aicc, stable, valid, failureMessage
```

`maxOrderReached=true` es una advertencia diagnóstica: la búsqueda no aumenta el límite automáticamente.

## Determinismo

`tfest` consume el RNG global. El núcleo fija una semilla interna para la identificación y restaura mediante `onCleanup` el estado RNG del llamador, incluso si ocurre un error. Las mismas entradas/opciones producen el mismo sweep sin cambiar el RNG externo.

## Limitaciones científicas actuales

- El delay seleccionado no es identificable de manera universal: una dinámica suficientemente flexible puede absorber parte de un retardo si la excitación no es informativa. La recuperación exacta está caracterizada con un impulso sintético conocido.
- Todavía no existe partición train/holdout.
- Todavía no se calculan ni seleccionan candidatos por métricas específicas de pico, undershoot, área negativa, polo lento o cola.
- Un fit global alto no aprueba por sí solo un modelo para NP02/DAPHNE.
- La preparación de la plantilla —baseline, polaridad y normalización— debe ser explícita y externa a esta API.

## Evidencia del tracer bullet — 2026-08-13

- RED inicial: API ausente (`MATLAB:undefinedVarOrClass`).
- RED de determinismo: `tfest` modificaba el RNG del llamador.
- GREEN focalizado combinado identificación/legacy después de la revisión independiente: 17/17 passed.
- Regresiones añadidas: selección por fit independiente de AICc, conteo discreto de parámetros, residuales continuos ZOH y rechazo de JSON NP02 modificado.
- Suite estándar post-fix: 106/106 passed, 0 failed, 0 incomplete.
- Integración DAPHNE FBK SiPM, VGAIN 1700: 1/1 passed para ambos dominios; 12 artefactos visuales/numéricos generados bajo `outputs/validation/iir-daphne-fbk-vgain-1700/`.
- La integración obtiene fit continuo >91 %, pero el plot de cola demuestra que el modelo no reproduce el undershoot real; no es una aprobación científica.
- `checkcode` de fuentes/tests nuevos: 0 mensajes.
- MATLAB: R2025b, versión 25.2.

## Relacionado

- [[estimateDiscreteTransferFunction]]
- [[np02-transfer-function-estimation]]
- [[iir-daphne-fbk-vgain-1700]]
