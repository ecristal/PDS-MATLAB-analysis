---
type: validation-note
status: exploratory-measurement
scientific-status: configuration-specific-not-reference
tags:
  - daphne
  - fbk-sipm
  - vgain-1700
  - iir
  - identification
---

# Validación exploratoria de funciones de transferencia — DAPHNE FBK SiPM VGAIN 1700

## Estado científico

Esta es una verificación de integración **específica de la adquisición**. No constituye una referencia universal del PDS/DAPHNE ni aprueba científicamente un modelo IIR. El SNR, la respuesta temporal y el ruido dependen de VGAIN, electrónica, canal, bias y condiciones externas.

La procedencia exacta de la selección de eventos usada para construir la `.fig` histórica no está disponible en esta etapa; por tanto, la plantilla es un oracle de regresión local, no una muestra calibrada de verdad física.

## Dataset local ignorado

```text
data/DAPHNE/FBK_SiPM/vgain_1700/
```

Git ignora todo `data/`; ningún dato ni figura se versionó.

Artefactos usados/inspeccionados:

| Artefacto | Bytes | SHA-256 | Uso |
|---|---:|---|---|
| `channel_24.7z` | 28,947,380 | `ce301d6525c14fa7da0b71963dcf9ddd252604842c8f26594bf1cbd23123039c` | integridad, inventario y streaming de formato |
| `config.txt` | 10,058 | `bb17b7ea1383517ef8ebdaeea7eb094816ac7bc8f57794dc4aadad5eb95d70ea` | configuración observada |
| `figures/average_single_PE_ch_24.fig` | 73,854 | `3170b4d8090140cf62a38651d4cdebe22ae6fc6ccaa53c94b45977bc504a2a2d` | plantilla 1-PE de integración |

## Configuración observada

En `config.txt`:

```text
channel:             24 para los datos usados
channel offsets:     2275
AFE VGAIN:           1700 en AFE 0–4
ADC_OUTPUT_FORMAT:   1
LPF_PROGRAMMABILITY: 4
PGA_INTEGRATOR_DISABLE: 1
PGA_CLAMP_LEVEL:     2
ACTIVE_TERMINATION_ENABLE: 0
LNA_INPUT_CLAMP_SETTING: 0
LNA_INTEGRATOR_DISABLE: 1
LNA_GAIN:            2
```

No se infiere aquí la traducción física completa de cada registro; se registra únicamente el valor devuelto por la configuración.

## Archivo raw

`7z t` reportó `Everything is Ok`. El archivo contiene un único miembro:

```text
channel_24.dat
uncompressed bytes: 122,880,000
```

La inspección se hizo por streaming (`7z x -so`), sin extraer el payload al repositorio.

**Fuertemente inferido:** almacenamiento `uint16` little-endian:

```text
sample count:                  61,440,000
waveforms if 2048 samples:     30,000 exactos
minimum:                       7462
maximum:                       7744
mean:                          7551.686782845052
fraction >= 2^14:              0
```

La interpretación big-endian produce rango 30–65309 y casi todas las muestras por encima de `2^14`, incoherente con la nube compacta observada para esta adquisición. El ancho de almacenamiento y endianidad son fuertes inferencias; la codificación ADC autoritativa debe confirmarse con firmware/documentación de adquisición.

## Plantilla 1-PE histórica

La `.fig` contiene una única línea de 2048 muestras:

```text
sample period:                     16 ns
baseline:                          mediana de primeras 100 muestras
polaridad:                         positiva
onset >=5 %:                       índice 407 (one-based)
pico:                              índice 414
pico después de normalización:     1
mínimo post-pico:                  -0.0229538955045469
índice del mínimo:                 1465
valor final:                       0.00900301109110442
```

La señal aún excede 1 % del pico cerca del final de la ventana; no se puede afirmar un tiempo de retorno permanente bajo 1 % usando solo estas 2048 muestras.

## Sweep exploratorio

Entradas comunes:

```text
input:              impulso unitario en onset >=5 %
SampleTime:         16 ns
MaxOrder:           6
DelayRange:         -4:4
FitTolerance:       0.5 puntos porcentuales
SelectionCriterion: parsimonious-fit
candidatos/dominio: 54
```

Resultados:

| Dominio | Orden polos/ceros | Delay | Fit seleccionado | Mejor fit | RMSE global | RMSE post-pico | Error de pico | Mínimo reconstruido | Runtime |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| continuo `s` | 4/3 | -1 | 91.1003 % | 91.2269 % | 0.0088880 | 0.0077669 | +0.0002043 | +2.74e-6 | 48.75 s |
| discreto `z^-1` | 4/3 | -1 | 90.9888 % | 91.1475 % | 0.0089994 | 0.0078124 | -0.0038420 | +3.04e-6 | 8.69 s |

El caso continuo generó una advertencia MATLAB: la dinámica identificada requeriría un periodo menor que aproximadamente 3.7 ns para su simulación sin undersampling. Por ese motivo no se promueve como regresión canónica con `Ts=16 ns`.

## Regresión local acotada y plots de revisión

`tests/integration/TestDaphneVgain1700TransferFunctionIdentification.m`
ejecuta las APIs continua y discreta con:

```text
MaxOrder=4
DelayRange=-2:2
candidatos=20
```

Este caso conserva la selección `orden 4`, `delay -1` en ambos dominios. En la
ejecución verificada, el test conjunto tardó aproximadamente 40.5 s dentro del
framework de tests en este host.

La prueba fija intencionalmente el hallazgo científico:

```text
fit global > 90 %
target minimum post-peak < -2 %
reconstructed minimum post-peak >= 0
difference in undershoot > 2 %
```

Por tanto, **un fit global alto no implica fidelidad del undershoot**.

Cada ejecución sobrescribe determinísticamente sus propios artefactos en:

```text
outputs/validation/iir-daphne-fbk-vgain-1700/
├── continuous/
└── discrete/
```

Cada dominio contiene:

```text
waveform-comparison.png   revisión rápida: señal completa, pico y cola
waveform-comparison.fig   inspección numérica/visual en MATLAB
candidate-fit-map.png     fit por orden y delay, con candidato seleccionado
candidate-fit-map.fig     versión MATLAB editable
candidate-table.csv       métricas de los 20 candidatos
selected-model-metrics.json
```

Los 12 artefactos son productos locales ignorados por Git. La prueba comprueba
que todos existen y son no vacíos. Los PNG de ambos dominios se inspeccionaron
visualmente: títulos, ejes, leyendas, colorbars y candidato seleccionado son
legibles; el zoom de cola muestra de forma explícita el undershoot que ninguno
de los modelos seleccionados reproduce.

La reconstrucción y los diagnósticos residuales del modelo continuo usan
explícitamente zero-order hold, igual que la convención de entrada del problema
de identificación. No se usa la interpolación FOH implícita de `lsim`.

## Conclusión

- La API discreta ejecuta un sweep acotado y determinista sobre una plantilla DAPHNE real ignorada por Git.
- El modelo describe bien el pico globalmente, pero no reproduce el undershoot/cola negativa observada.
- No debe seleccionarse ni aprobarse un modelo final usando solo `FitPercent`, BIC o AICc in-sample.
- La próxima etapa científica debe incluir métricas explícitas de undershoot/cola, validación holdout y una estrategia que no penalice la componente lenta frente al pico dominante.

## Evidencia de ejecución — 2026-08-13

```text
archive integrity: passed
local integration: 1/1 passed
integration checkcode: 0
review outputs: 12 non-empty files under ignored outputs/
plot visual QA: passed for both domains
standard suite (integration excluded by discovery): 106/106 passed
focused identification+legacy tests: 17/17 passed
data tracked by Git: none
```

## Relacionado

- [[estimateDiscreteTransferFunction]]
- [[estimateContinuousTransferFunction]]
- [[np02-transfer-function-estimation]]
