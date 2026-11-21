---
type: exploratory-validation
status: exploratory
tags: [daphne, iir, undershoot, fbk, hpk, simulation]
---

# IIR manual HD mezzanine — entrada para Tarea 13

Relacionado: [[pedestal-estimation-refactor-status]], [[task12-audit-closure]].

## Confirmaciones posteriores del usuario

Ts=16 ns; alineamiento FBK aproximadamente confirmado; duplicación del canal 24
en HPK accidental. El alcance siguiente se limita a FBK VGAIN1700, sin trasladar
amplitudes ni PSD entre configuraciones. Véase [[task13-fbk-vgain1700]] para el
archivo correcto, el reajuste y la comprobación disjunta. La inspección inicial
y sus limitaciones se conservan abajo como evidencia histórica.

## Corrección de la hipótesis de identificación

El usuario aporta estimaciones FBK/HPK obtenidas a partir de la waveform media de
todos los eventos, no solo de la población single-PE. La limitación del undershoot
observada anteriormente correspondía a la plantilla y al procedimiento ensayados;
no demostraba incapacidad general del modelo IIR.

La forma temporal y la calibración de amplitud a 1 PE deben conservarse por
separado. Normalizar el promedio de una población mixta por su pico no demuestra
que esa amplitud original corresponda a 1 PE. La transferencia de forma entre
multiplicidades requiere la hipótesis de respuesta lineal y ausencia de distorsión
por selección, saturación o alineamiento.

## Inspección ejecutada

Entrada: `data/DAPHNE/IIR_estimation/HD_mezzanine/{FBK,HPK}`.
Se leyeron CSV de 2048 muestras y coeficientes suministrados, sin reidentificar el
modelo ni extraer los datos crudos. Comparación Python/SciPy mediante `lfilter`:

- Coeficientes interpretados provisionalmente como filtro discreto b/a.
- Tiempo en muestras; periodo de muestreo pendiente de confirmar.
- Promedio CSV dividido por su pico positivo, sin nueva sustracción de baseline.
- HPK: impulso unitario suministrado en muestra 405.
- FBK: impulso inferido en muestra 406 alineando los picos; no existe CSV de entrada.
- No se ajustaron ganancia ni baseline para mejorar la comparación.

| Magnitud | FBK | HPK |
|---|---:|---:|
| Ajuste global 100*(1-norm(y-model)/norm(y-mean(y))) | 97.8887 % | 98.6859 % |
| Área negativa postpico medida, amplitud normalizada × muestras | -9.84961 | -7.80741 |
| Área negativa postpico del modelo, misma ventana | -9.85845 | -7.79783 |
| Mínimo postpico medido normalizado | -0.0138400 | -0.0109372 |
| Mínimo postpico del modelo | -0.0093111 | -0.0079622 |
| Pico de respuesta a impulso unitario del modelo | 0.996443 | 1.002058 |
| Máximo módulo de polos bajo convención discreta | 0.9998930 | 0.9996219 |

La superposición visual reproduce la tendencia del undershoot y de la cola. El
mínimo puntual de los datos contiene fluctuaciones y no coincide exactamente con
el mínimo suave del modelo. La concordancia global no sustituye validación holdout.

Extrapolando exclusivamente los IIR suministrados, el último desplazamiento desde
el impulso con respuesta superior al 0.1 % del pico es 22260 muestras para FBK y
6738 para HPK, dentro de un horizonte de 100000. Esto informa la futura selección
de burn-in, pero no es una medición de settling fuera de la ventana observada.

## Procedencia y pendientes

- [x] CSV y modelos FBK/HPK inspeccionados y comparación generada.
- [x] Hashes iniciales/finales de todos los archivos de entrada idénticos.
- [ ] Confirmar periodo de muestreo y convención exacta de los coeficientes.
- [ ] Confirmar índice de impulso FBK y tratamiento de alineamiento/promediado.
- [ ] Resolver duplicación de archivos crudos: FBK/data/VGAIN_0/channel_24.7z y
  HPK/data/VGAIN_1700/channel_24.7z tienen el mismo SHA-256:
  `f006046b43a45f355fb793f0869fd781eff3005bf3ba4227cbe2314f611aea37`.
- [ ] Verificar metadatos de los objetos MAT: SciPy no pudo decodificarlos.
- [ ] Validación independiente antes de promover el modelo a referencia física.

`scientificApproval=false` de la validación anterior no se modifica automáticamente.
Estos modelos son candidatos aportados por el usuario para el simulador Tarea 13.
No se ejecutó MATLAB, no se alteró producción ni se implementó todavía Tarea 13.

## Artefactos locales reproducibles, fuera de Git

`outputs/validation/hd-mezzanine-manual-iir-review/` contiene:

- `review.py`: inspección y comparación, con supuestos explícitos.
- `summary.json`: métricas y manifiesto SHA-256 de las entradas.
- `comparison.png`: comparación completa y zoom del undershoot para ambas familias.

Ejecutado con `uv run --with numpy --with scipy --with matplotlib python
outputs/validation/hd-mezzanine-manual-iir-review/review.py`, exit code 0.
