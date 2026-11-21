---
type: exploratory-validation
status: software-audited
tags: [daphne, fbk, vgain1700, iir, simulation]
---

# Tarea 13 — FBK VGAIN 1700

Progreso: [[pedestal-estimation-refactor-status]]. Antecedente manual:
[[hd-mezzanine-manual-iir]].

## Alcance confirmado por el usuario

- Solo FBK, VGAIN 1700, Ts = 16 ns.
- Forma temporal a partir de promedios de **todas las multiplicidades**, no de
  una selección single-PE.
- Amplitud/calibración de 1 PE y perfil de ruido son propios de la configuración
  de ganancia/frontend. Ninguno es una verdad universal de DAPHNE.
- Índice de impulso manual FBK aproximadamente 406, confirmado por el usuario.
- La duplicación del archivo canal 24 en la carpeta HPK fue accidental.

## Datos seleccionados y preservación

Se usa `data/DAPHNE/FBK_SiPM/vgain_1700/channel_24.7z`, con configuración
`config.txt` que registra VGAIN 1700 para los AFEs. No se usa el archivo rotulado
VGAIN_0 para estimar amplitudes ni ruido de VGAIN 1700.

SHA-256 del archivo seleccionado:
`ce301d6525c14fa7da0b71963dcf9ddd252604842c8f26594bf1cbd23123039c`.

Se verificó un único miembro `channel_24.dat`, 122880000 bytes, 30000 registros
× 2048 muestras uint16 little-endian. Extracción temporal eliminada, hashes de
entradas sin cambios. Los originales no se escriben ni versionan.

## Observaciones específicas de esta adquisición

El promedio de todos los registros, restando su baseline en las primeras 100
muestras, tiene pico 17.136056 ADU. El promedio manual aportado tenía pico
178.355128 ADU. **Ninguno de esos picos es una calibración de 1 PE.**

Aplicar directamente el modelo manual normalizado al promedio VGAIN1700 da un
ajuste global de 96.9311 %, pero área negativa postpico del modelo -9.85845 frente
a -12.01133 de los datos (amplitud normalizada × muestras). La forma no se
transfiere exactamente entre configuraciones, aunque la tendencia se reproduce.

## Un reajuste acotado y una comprobación disjunta

Se ejecutó un único `tfest`, inicializado con el IIR manual FBK:

- 15000 registros impares para el promedio de ajuste; 15000 pares para el promedio
  de comprobación. Ambos contienen todas las multiplicidades.
- Baseline: primeras 100 muestras de cada promedio.
- Normalización: pico del promedio de entrenamiento, reutilizado sin reajuste en
  holdout. El holdout no seleccionó orden ni hiperparámetros.
- Impulso unitario en muestra 406, Ts 16 ns; misma estructura del IIR inicial.
- Condición inicial cero, estabilidad impuesta, máximo 50 iteraciones de búsqueda.
- No se realizó un barrido de modelos ni una nueva selección de SPE.

| Métrica | Resultado |
|---|---:|
| Ajuste global entrenamiento | 97.7034 % |
| Ajuste global holdout | 97.2236 % |
| Modelo manual inicial sobre el mismo holdout | 96.0731 % |
| Área negativa holdout | -11.42629 |
| Área negativa modelo reajustado | -12.35636 |
| Error relativo de área negativa | 8.1397 % |
| Mínimo postpico holdout | -0.0160797 |
| Mínimo postpico modelo | -0.0111896 |
| Media últimas 100 muestras holdout | -0.0105812 |
| Media últimas 100 muestras modelo | -0.0101645 |
| Máximo módulo de polos | 0.99979577 |

El IIR reproduce la tendencia del undershoot y mejora la transferencia directa
del modelo manual. Sus coeficientes para simulación se normalizan por el pico de
su respuesta a impulso, separado de la escala física de 1 PE.

El último desplazamiento por encima del 0.1 % del pico del modelo es 12976
muestras dentro de un horizonte de 100000. El retorno fuera de las 2048 muestras
observadas es **extrapolación del modelo**, no validación experimental de la cola
completa. El holdout es de registros disjuntos de la misma adquisición, no de una
configuración electrónica independiente. `scientificApproval=false` se mantiene;
no se ha establecido aquí un umbral físico de aceptación universal.

## Ruido: perfil explícitamente exploratorio

Se calculó una PSD bilateral de 300 bins FFT a partir de las primeras 300 muestras
de todos los registros, retirando la media de cada segmento. RMS conjunto:
4.376358 ADU. Es un **proxy de pretrigger de esta adquisición**, no una medición
certificada de ruido electrónico puro: puede contener dark counts y ruido externo.

No se mezcla con adquisiciones de otro canal/frontend aunque compartan VGAIN.
Cualquier remuestreo de la PSD a la malla de la traza progenitora y cualquier cambio
de RMS deben declararse en la configuración y en el truth del simulador.

## Checklist

- [x] Confirmar Ts, alcance FBK1700 y distinción forma/amplitud/ruido.
- [x] Verificar archivo y configuración; preservar originales.
- [x] Calcular promedio de todos los eventos y proxy de ruido del mismo canal.
- [x] Reajuste único con comprobación en registros disjuntos.
- [x] Inspeccionar visualmente undershoot y documentar límites.
- [x] Ejercitar estos coeficientes en el núcleo del simulador Tarea 13.
- [x] Verificar crop, burn-in, componentes, pedestal y saturación con truth.
- [x] Completar gates y revisión independiente del software; [[task13-audit-closure]].

## Integración del simulador ejecutada

[[simulatePedestalStressWaveforms]] pasó cuatro escenarios separados: constante,
slope, step y wander. Cada uno produjo 2048 muestras desde un parent de 813969,
con burn-in conservador de 405960 muestras. No se reajustó el modelo.

La PSD de 300 bins se interpoló linealmente en frecuencia absoluta desde sus 151
bins no negativos, reflejándola a la malla FFT del parent. Las frecuencias bajas
no resueltas por la adquisición corta son interpolación, no medición nueva.
RMS objetivo del parent: 4.37635758 ADU; el crop obtuvo 4.17667216 ADU en los tres
casos deterministas y 4.26896622 ADU en wander. El consumo del stream por wander
explica la realización de ruido distinta. El RMS del crop no se fuerza al del parent.

Amplitud de referencia/dark = **1 ADU sintético**, baseline = **7600 ADU sintético**
y perturbación grande = **30000 ADU sintéticos**. No son una calibración física ni
una estimación de la distribución de eventos. Las llegadas son fixtures diseñados,
con una anterior al crop y otras dentro del pedestal; no tasas medidas.

Se verificaron reconstrucción exacta preADC, máscaras de llegada distintas de
colas, baseline medio del pedestal distinto del baseline de referencia, ruido
antes de crop, replay exacto y clipping explícito [0,16383]. Las pruebas unitarias
cubren además la composición de procesos Poisson. No se compararon estimadores
(Tarea 14) ni se aprobó físicamente la configuración.

Ejecución reproducible desde la raíz:

```matlab
addpath('outputs/validation/task13-fbk-vgain1700');
verify_task13_integration;
```

Evidencia: `task13-integration.log`, `task13-integration-summary.json`,
`task13-constant-truth.mat` y `task13-{constant,slope,step,wander}.png`. El JSON
registra cada escenario y los parámetros sintéticos. El MAT conserva truth
completo antes/después del clipping para el caso constante.

Gates runtime tras corregir QUALITY-13-1: clase focalizada 14/14, suite estándar
173/173, sin fallos ni
incompletos; checkcode 0 sobre fuente/tests nuevos. La suite estándar emitió dos
warnings de deprecación del wrapper legacy existente. Integraciones antiguas
DAPHNE no se repitieron; los cuatro casos anteriores son la integración Tarea 13.
La revisión de requisitos previa aprobó los 17 criterios. La revisión de calidad
encontró QUALITY-13-1 (overflow en truth de eventos pese a waveform finita),
corregido mediante RED→GREEN y rechazo antes de avanzar el stream del usuario.
Se repitieron los cuatro escenarios: `task13-integration-quality-fixed.log`.
Revisión independiente del snapshot G2 aprobada; [[task13-audit-closure]].
Esta anotación de cierre es posterior al snapshot auditado; código, tests y métricas
no cambiaron.

## Artefactos locales, ignorados por Git

`outputs/validation/task13-fbk-vgain1700/`:

- `input_review.py`, `input-summary.json`: procedencia y comparación inicial.
- `all_event_mean.csv`, `training_all_multiplicities_mean.csv`,
  `holdout_all_multiplicities_mean.csv`.
- `pretrigger_noise_psd.csv`.
- `refit_fbk1700.m`, `refit.log`, `refit-summary.json`, `fbk1700_refit.mat`.
- `fbk1700_response_b.csv`, `fbk1700_response_a.csv`: respuesta normalizada.
- `fbk1700-input-comparison.png`, `fbk1700-refit-holdout.png`.

La primera ejecución del reajuste terminó exit 0 y produjo los resultados. Emitió
una advertencia al cerrar la figura durante la salida de MATLAB; se adelantó la
limpieza explícita de la figura. Esta corrección de presentación no reestima el
modelo ni modifica coeficientes; su comprobación focalizada quedó separada de la
evidencia de identificación. Verificación ad-hoc posterior: exit 0, modelo estable,
pico normalizado unitario, renderizado y limpieza de figura PASS, checkcode 0,
hashes de entrada intactos y ambos temporales eliminados. No se repitió `tfest`.
