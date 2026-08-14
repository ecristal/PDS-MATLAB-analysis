---
type: matlab-function
status: validated
tags: [plotting, identification, validation, matlab]
---

# `pds.plotting.plotTransferFunctionEstimate`

Genera una figura reusable, sin escribir archivos, para revisar una o más reconstrucciones frente a un target.

```matlab
[figureHandle, axesHandles] = pds.plotting.plotTransferFunctionEstimate( ...
    target, predictions, SampleTime=16e-9, ...
    ModelLabels=["continuous", "discrete"], ...
    TrainingSampleCount=1200, TailStartIndex=1201, ...
    Visible="off");
```

Paneles:

1. waveform completo;
2. región de pico;
3. cola y undershoot.

El límite train/holdout solo se dibuja cuando cae dentro del rango visible del
panel. El llamador controla labels, título, comienzo de cola y visibilidad. La
región de pico se calcula internamente alrededor del máximo absoluto del target.
La función no persiste PNG/FIG ni contiene carga de archivos.
