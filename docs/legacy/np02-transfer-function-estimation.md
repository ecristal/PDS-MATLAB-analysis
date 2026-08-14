---
type: legacy-workflow
status: legacy-reference-characterized
scientific-status: historical-configuration-specific
runtime-validation: protected-copy-inspection-only
tags:
  - np02
  - transfer-function
  - iir
  - preservation
---

# Workflow histórico NP02 de función de transferencia

## Original protegido

```text
C:\Users\e_cri\OneDrive\Documents\INFN\NP02\Simulations\selftriggering\timestamp_location\templates_tf\templates\np02_tf_estimation_pds_algorithm.m
```

Copia preservada:

```text
legacy/np02/np02_tf_estimation_pds_algorithm.m
```

Ambas tienen 6517 bytes y SHA-256:

```text
e5ebdfe276727602af6a67cc1759e16e111ad49221769523e232bcb8f6429302
```

La identidad se comprueba ejecutablemente en `TestNp02TransferFunctionLegacyCharacterization`. El script no se ejecuta como programa porque carga, cierra figuras, genera plots y sobrescribe `templates_np02_large_pulses.mat` mediante `save`.

## Contrato histórico observado

El script contiene decisiones hard-coded:

```text
spe_template_struct element: 16
waveform length observado:    1024 muestras
starting_point:               250
sample period:                16 ns
order variable:               4
shift scan:                   -10:20 muestras
```

Preprocesamiento observado:

```matlab
output_data = waveform/max(waveform);
output_data = output_data - mean(output_data(1:50));
```

El orden de esas operaciones implica que el baseline se resta después de dividir por el máximo bruto; no equivale necesariamente a sustraer baseline y luego normalizar el pico final a uno.

Identificación observada:

```matlab
data_to_est = iddata(output_data', circshift(input_data,i)', Tm);
tf_model = tfest(data_to_est, ord+1, ord);
tf_model_d = c2d(tf_model, Tm, 'zoh');
tf_model_d.Variable = 'z^-1';
```

Con `order=4`, el modelo continuo final tiene cinco polos y cuatro ceros antes de discretizarse. El script selecciona el shift por máximo `FitPercent` y después usa `circshift`, que envuelve muestras; las APIs nuevas usan padding de ceros para evitar ese efecto.

## Side effects y dependencias

Observados estáticamente:

- `load("templates_np02_large_pulses.mat")`;
- `close all`;
- figuras 1, 2 y 3;
- `butter`, `iddata`, `tfest`, `c2d`, `d2c`, `zpk`, `tf`;
- helper no localizado `generateFractionalZeroCompensator`;
- mutación de `spe_template_struct(16).tf`, `.num` y `.den`;
- `save("templates_np02_large_pulses.mat","spe_template_struct")`.

Por estas razones el archivo histórico no pertenece al MATLAB path autoritativo y no se ejecuta sobre sus datos originales.

## Modelo IIR histórico preservado

Se inspeccionaron copias temporales hash-verificadas de los tres `.mat` catalogados. Los hashes de los originales coincidieron antes/después; las copias temporales se eliminaron y ningún `.mat` se copió al repositorio.

El único modelo no vacío del elemento 16 entre esos tres archivos se observó en:

```text
templates_np02_large_pulses.mat
SHA-256: 89754d544c05a50ff593d49fd374c9b3741077de33b305a27e1a708a481c48cb
variable: spe_template_struct
field: tf
class: idtf
```

Se preservaron sus coeficientes exactos y metadatos en:

```text
legacy/np02/np02_iir_model_element16.json
SHA-256: da4e0bafa131b03fb0b3dd05ea03ca55064fcf709459cdb96597812e899f4106
```

La caracterización ejecutable fija este digest antes de decodificar el JSON y
contiene una prueba negativa que modifica un coeficiente en una copia temporal:
la copia debe rechazarse por `ArtifactHashMismatch`. También se recomputa el
módulo máximo de polo y se compara con el valor almacenado.

Características observadas:

```text
Ts:                         16 ns
variable:                   z^-1
orden del denominador:      5
coeficientes numerador:     6, con primer coeficiente cero
ceros finitos:              4
estable:                    sí
máximo módulo de polo:      0.99490267701232382
constante de tiempo polo dominante aproximada: 3.130895711827583 µs
```

La respuesta impulsional de 4096 muestras reconstruida desde el JSON produjo:

```text
pico:                       0.9675606477033245
índice de pico:             17 (one-based)
tiempo de pico:             0.256 µs
área negativa post-pico:    0
retorno permanente <1 %:    5.664 µs
```

La constante de tiempo se calculó como:

```text
tau = -Ts/log(max(abs(poles)))
```

El retorno <1 % se define como la primera muestra posterior a la última muestra cuya magnitud excede 1 % del pico, dentro de la ventana simulada.

## Comparación con la plantilla histórica

Desde una copia temporal, la plantilla del elemento 16 procesada en el mismo orden que el script mostró:

```text
pico normalizado observado:             0.9637277151947674
índice del pico:                        262
mínimo posterior al pico:              -0.0013652555416666656
índice del mínimo:                      782
área negativa post-pico:                -9.050760075969e-11 amplitud·s
valor final a 1024 muestras:            0.009138137268410854
```

Por contraste, el IIR almacenado reconstruido no cruza cero en 4096 muestras. Esta diferencia no prueba por sí sola por qué ocurrió —podría depender del fit, normalización, alineamiento, conversión o variante guardada—, pero sí demuestra que estabilidad y fit global no bastan para aprobar la reproducción del undershoot.

## Interpretación y límites

- **Observado:** hashes, código hard-coded, campos/coefs del elemento 16, estabilidad y respuestas reconstruidas descritas arriba.
- **Inferido:** el polo dominante representa una cola lenta de escala aproximada 3.13 µs.
- **No establecido:** fidelidad física general, validez en otras placas/canales/ganancias, cobertura frente a ruido, ni equivalencia con una identificación moderna directa discreta.
- Este modelo es una referencia legacy específica de su configuración; no es una recomendación científica final.

## APIs modernas relacionadas

- [[estimateContinuousTransferFunction]] identifica directamente en `s`.
- [[estimateDiscreteTransferFunction]] identifica directamente un IIR en `z^-1`; no usa `c2d`.
- Ambas limitan el número de polos mediante `MaxOrder` y usan una estructura de numerador por orden para evitar un sweep combinatorio.
- La infraestructura moderna ya dispone de extrapolación temporal, métricas específicas de pico/undershoot/cola y semántica separada de entrada en banda/asentamiento. Se aplicó al waveform promedio DAPHNE VGAIN 1700 con resultado no aprobado. La validación científica equivalente del artefacto NP02 histórico sigue pendiente y debe ejecutarse solo sobre copias controladas.

## Evidencia — 2026-08-13

```text
legacy characterization: 6/6 passed
identification + legacy focused post-fix: 17/17 passed
standard suite post-fix: 106/106 passed
checkcode new sources/tests: 0
MATLAB: R2025b (25.2)
```
