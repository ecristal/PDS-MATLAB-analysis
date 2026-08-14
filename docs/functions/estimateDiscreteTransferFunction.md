---
type: matlab-function
status: tracer-bullet-validated
tags:
  - identification
  - iir
  - discrete-time
  - inverse-z
  - matlab
---

# `pds.identification.estimateDiscreteTransferFunction`

## Propósito

Identifica directamente un modelo IIR SISO discreto expresado en `z^-1`. No discretiza primero un modelo continuo y no contiene carga de archivos, plotting ni persistencia.

```matlab
[model, diagnostics] = ...
    pds.identification.estimateDiscreteTransferFunction( ...
    inputSignal, outputSignal, ...
    SampleTime=16e-9, ...
    MaxOrder=6, ...
    DelayRange=-10:20, ...
    FitTolerance=0.5, ...
    SelectionCriterion="parsimonious-fit");
```

El modelo seleccionado cumple:

```matlab
model.Ts == SampleTime
string(model.Variable) == "z^-1"
```

Sus coeficientes son aplicables como:

```matlab
yEstimated = filter(model.Numerator, model.Denominator, shiftedInput);
```

`shiftedInput` debe usar `diagnostics.selectedDelaySamples` con padding de ceros. El delay se usa para alinear los datos durante la identificación y no queda codificado automáticamente como una propiedad separada del modelo devuelto.

## Diferencia respecto de la API continua

```text
estimateContinuousTransferFunction → tfest(..., Ts=0)          → modelo en s
estimateDiscreteTransferFunction   → tfest(..., Ts=SampleTime) → IIR directo en z^-1
```

La API discreta no llama `c2d`. Una futura comparación continuo→discretizado será solo un diagnóstico separado, no la definición del identificador discreto.

## Búsqueda y coste

Se evalúa una estructura por orden:

```text
poleOrder = 1:MaxOrder
zeroOrder = max(0, poleOrder - 1)
```

junto con todos los delays solicitados. El número nominal de candidatos es:

```text
MaxOrder × numel(DelayRange)
```

Esto evita probar automáticamente todos los órdenes de numerador para cada denominador. `MaxOrder` limita polos y nunca aumenta de forma automática. `diagnostics.maxOrderReached` informa si el modelo seleccionado llegó al límite.

## Selección y métricas

Los criterios disponibles son:

- `"parsimonious-fit"` — predeterminado;
- `"best-fit"`;
- `"bic"`;
- `"aicc"`.

Los diagnósticos y validaciones son los mismos que en [[estimateContinuousTransferFunction]]. La tabla por candidato incluye fit, RMSE, NRMSE, BIC, AICc, estabilidad, validez y mensaje de fallo. `valid` no depende de que AICc sea finita; cada criterio usa solamente el score que necesita.

El conteo de coeficientes libres usado para BIC/AICc es:

```text
zeroOrder == 0: parameterCount = poleOrder + 1
zeroOrder > 0:  parameterCount = poleOrder + zeroOrder
```

En el segundo caso, el coeficiente líder `z^0` del numerador estrictamente
propio es cero fijo y no se cuenta como parámetro libre. Este contrato está
verificado mediante recomputación independiente de BIC y AICc.

Estas métricas se calculan sobre las muestras de entrenamiento. `TrainingSampleCount`
puede reservar el sufijo para extrapolación temporal: fitting y selección ven
solo el prefijo, mientras `validationRmse`, `validationNrmse` y
`validationFitPercent` se calculan sobre el sufijo de la predicción completa.
Esto no equivale a un holdout independiente entre eventos.

## Contratos numéricos

- Señales reales, finitas, no degeneradas y de igual longitud.
- `SampleTime` positivo y explícito.
- `MaxOrder` entero positivo y menor que la longitud de señal.
- `DelayRange` de enteros únicos dentro de la longitud de señal.
- `FitTolerance` no negativa.
- `TrainingSampleCount=[]` o entero entre 4 y `N-1`.
- Validación previa a conversión de `int64`/`uint64`.
- Identificación determinista con restauración del RNG global.

## Limitaciones científicas actuales

- El delay puede confundirse con ceros/polos adicionales si la excitación no separa ambas contribuciones.
- La recuperación exacta del delay está probada con una respuesta impulsional sintética conocida.
- Las métricas específicas de pico, undershoot, área negativa, cola, primera
  entrada en banda y asentamiento final se proporcionan mediante
  [[evaluateTransferFunctionResponse]], pero no participan todavía en la
  selección de candidatos.
- La equivalencia `filter(B,A,u)` está verificada sobre un IIR sintético y existe una integración específica DAPHNE FBK SiPM, VGAIN 1700. Esa integración no constituye aprobación científica general.
- No se realiza normalización de 1 SPE ni sustracción de baseline dentro de esta función.
- En DAPHNE, la estimación usa el waveform promedio congelado preparado con
  [[prepareSinglePeTemplate]]; no usa waveforms individuales ni suavizado.

## Evidencia del snapshot candidato — 2026-08-14

- Pruebas focalizadas Tareas 6/9/10 + NP02: 52/52 passed.
- Suite estándar: 133/133 passed, 0 failed, 0 incomplete.
- Integraciones DAPHNE: 3/3 passed.
- `checkcode`: 0 mensajes en 15 archivos MATLAB modificados/nuevos.
- Artefactos nuevos de revisión Tareas 6/9/10: 14/14 no vacíos bajo
  `outputs/validation/`, ignorados por Git.
- Identificación directa `z^-1`, estabilidad, equivalencia con `filter`, delay con
  zero-padding y holdout temporal sin leakage para delays negativo, cero y
  positivo probados.
- La regresión de 8 muestras comprueba que `best-fit` puede seleccionar un candidato estable con AICc infinita.
- BIC/AICc discretos se recomputan independientemente en tests con el número real de coeficientes libres.
- Si el criterio solicitado no tiene ningún score finito, el error conserva el namespace de esta API (`pds:identification:estimateDiscreteTransferFunction:NoFiniteSelectionScore`) y el RNG del llamador queda restaurado.
- La integración obtiene fit discreto >90 %, pero el plot de cola demuestra que el modelo no reproduce el undershoot real.
- Un test sintético recupera un polo discreto lento conocido y su constante de
  tiempo; la validación DAPHNE compara además el IIR discreto directo con el
  modelo continuo discretizado mediante ZOH.
- MATLAB: R2025b, versión 25.2.

## Relacionado

- [[estimateContinuousTransferFunction]]
- [[np02-transfer-function-estimation]]
- [[iir-daphne-fbk-vgain-1700]]
