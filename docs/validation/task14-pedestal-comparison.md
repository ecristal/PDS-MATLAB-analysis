---
type: validation-protocol
status: in-progress
updated: 2026-09-14
tags: [pedestal, simulation, comparison, fbk, vgain1700]
---

# Tarea 14 — comparación de estimadores de pedestal

Estado: iniciada por autorización del usuario. Antecedente aprobado:
[[task13-audit-closure]]. APIs: [[estimatePedestal]],
[[simulatePedestalStressWaveforms]]. Progreso: [[pedestal-estimation-refactor-status]].

## Alcance y primer incremento

Se comparan media, mediana y mediana de medias sobre las mismas waveforms y región.
La única procedencia experimental admitida sigue siendo FBK VGAIN1700, canal 24,
Ts=16 ns. El modelo temporal procede de promedios de todas las multiplicidades;
la amplitud física de 1 PE no se infiere de esos promedios. Ruido y amplitud dependen
del frontend y la ganancia. Los controles analíticos sintéticos no representan
adquisiciones de otros SiPMs.

Primero se verifica un helper de comparación y métricas mediante TDD. Después se
realiza un piloto acotado con el IIR FBK1700 para verificar la cadena completa.
El piloto no cierra por sí solo la Tarea 14 ni justifica elegir un método definitivo.
No se modifica el filtro, el estimador aprobado ni el simulador de Tarea 13.

## Contrato estadístico fijado antes del piloto

- Dos estimandos separados: baseline medio real en la región de pedestal y
  baseline real al tiempo de referencia. Nunca se sustituye uno por otro.
- Error = estimación − verdad; bias = media del error; RMSE = raíz de media de
  error al cuadrado; mediana y percentiles 90, 95 y 99 del error absoluto.
- Reportar todos los eventos: los flags no filtran silenciosamente las métricas.
- Comparaciones pareadas: idénticos datos por método, mismo pretrigger y bloques
  de mediana de medias definidos antes de evaluar.
- Cobertura exploratoria de estimación ±1.96×error estándar. Las fórmulas actuales
  de media/mediana no garantizan 95 % con ruido correlacionado o contaminación.
  Mediana de medias devuelve error estándar NaN: su cobertura se registra no
  disponible y se cuentan esas filas, sin reemplazarla por cero.
- False-valid = fracción de eventos marcados válidos entre los etiquetados no
  aceptables por el truth; false-invalid = fracción marcada inválida entre los
  aceptables. Registrar denominadores vacíos como no disponible (NaN).
- Las etiquetas aceptables se entregan explícitamente desde el diseño/truth, no
  se deducen del error observado del método evaluado. El umbral debe declararse
  como decisión del ensayo, no como especificación física de DAPHNE.
- El runtime mide la llamada de estimación y diagnósticos, no generación ni I/O;
  no se exige replay bit a bit de tiempos de ejecución.

## Desarrollo y evaluación reservada

Los seeds, parámetros y particiones se fijan antes de inspeccionar resultados.
No se ajustan thresholds de calidad sobre el holdout. Cambiar un umbral después
requiere un nuevo holdout, no relabelar el mismo ensemble.

Separar independencia de realizaciones (seeds distintos) de independencia de
configuraciones (parámetros reservados distintos). Un piloto con seeds distintos
pero misma configuración no equivale a la validación final entre configuraciones.
La forma IIR y PSD FBK compartidas son condicionantes del modelo, no una validación
experimental independiente. Mantener `scientificApproval=false`.

## Cobertura pendiente del bloque completo

- [ ] Ruido blanco y coloreado (PSD conocida y proxy medido).
- [ ] Pedestal de 50, 100, 200 y 300 muestras.
- [ ] Baseline constante, slope, wander y step, separados.
- [ ] Outliers impulsivos no correlacionados.
- [ ] Tasas dark representativas entre 1e3 y 1e5 Hz.
- [ ] Grandes perturbaciones: 8000 ADU, próximas a 2^14 y superiores.
- [ ] Casos sin saturación y clipping explícito.
- [ ] Cuantización explícita: paso y redondeo documentados, sin wrap entero.
- [ ] Colas/undershoot de eventos anteriores al crop.
- [ ] Combinaciones diseñadas de drift y contaminación, sin producto cartesiano ciego.
- [ ] Configuraciones holdout reservadas y comparación de incertidumbres/flags.
- [ ] Resultados por escenario, sin elegir por SNR downstream.
- [ ] Gates reproducibles y revisión independiente del snapshot final.

## Productos

Código de validación y tests bajo `tests/`; resultados numéricos, figuras y logs
solo bajo `outputs/validation/pedestal/` y `outputs/validation/task14-development/`,
ignorados por Git. El helper devolverá tablas agregadas y resultados por evento
para comprobar que los agregados son reproducibles.

- [ ] Helper de métricas con RED→GREEN y contratos verificados.
- [ ] Piloto FBK1700 ejecutado y artefactos inspeccionados.
- [ ] Matriz ampliada y holdout ejecutados.
- [ ] Decisión condicional de método sustentada por resultados, o límites que
  impiden decidir documentados explícitamente.

La autorización de esta tarea no incluye stage, commit, push ni iniciar Tareas 15–17.
