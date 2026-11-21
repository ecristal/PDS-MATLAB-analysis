---
type: project-status
status: active
updated: 2026-09-14
tags: [pedestal, simulation, refactor, validation, daphne, status]
---

# Estado de la refactorización de pedestal

## Resumen ejecutivo

Las Tareas 0–13 del plan de pedestal están implementadas. Las Tareas 0–10 viven en
el commit local verificado:

```text
2a9bf1bca977c542d88e36a5ef2b1fa046039200
[verified] feat: add scientific validation for pedestal, IIR, and noise
```

Las Tareas 11 y 12 están implementadas, verificadas y guardadas juntas en el
commit local `2c3a286d1a1a24e971070b708317c8d6e24905a2`. La Tarea 12 cuenta con
aprobación estática independiente del snapshot exacto; véase [[task12-audit-closure]].
La Tarea 13 está implementada y aprobada por revisión independiente de software,
sin stage ni commit; véase [[task13-audit-closure]]. No se realizó push.
La Tarea 14 está autorizada y en curso; protocolo y progreso en
[[task14-pedestal-comparison]].

## Tareas y progreso del proyecto

Los checks indican cumplimiento funcional del alcance de cada tarea, no aprobación
científica global de DAPHNE. Las tareas pendientes requieren autorización antes
de comenzar; la documentación/revisión final de Tarea 17 abarca todo el proyecto.

### Completadas

- [x] **Tarea 0 — Congelar y revisar el punto de partida.**
- [x] **Tarea 1 — Caracterizar la implementación legacy.**
- [x] **Tarea 2 — Selección y validación explícita del pretrigger.**
- [x] **Tarea 3 — Estimación por media y estadística básica.**
- [x] **Tarea 4 — Estimación por mediana.**
- [x] **Tarea 5 — Mediana de medias determinista.**
- [x] **Tarea 6 — Diagnósticos observacionales de calidad.**
- [x] **Tarea 7 — Sustracción de pedestal separada.**
- [x] **Tarea 8 — Preservación y caracterización del workflow NP02.**
- [x] **Tarea 9 — Identificación continua/discreta de funciones de transferencia.**
- [x] **Tarea 10 — Generador de ruido coloreado.**
- [x] **Tarea 11 — Dark counts y perturbaciones grandes.**
- [x] **Tarea 12 — Multiplicidad configurable.**

- [x] **Tarea 13 — Componer trazas largas y recortar waveforms.** Completada y auditada; sin commit.
  - [x] Inspeccionar promedios de todos los eventos y coeficientes manuales FBK/HPK.
  - [x] Comparar respuesta y undershoot sin reidentificación; originales preservados.
  - [x] Confirmar Ts=16 ns y alcance FBK VGAIN1700; duplicación accidental aclarada.
  - [x] Comprobar promedio de todas las multiplicidades y reajuste FBK1700 con registros disjuntos.
  - Evidencia específica de configuración: [[task13-fbk-vgain1700]].
  - [x] Implementar y verificar composición, burn-in, crop y ground truth mediante TDD.
  - [x] Gates runtime: 14/14 focalizados, 173/173 estándar; checkcode 0.
  - [x] Integración FBK1700: cuatro escenarios con parámetros sintéticos explícitos.
  - [x] Revisión independiente del snapshot G2 exacto: SPEC y QUALITY aprobados.
  - Cierre y trazabilidad: [[task13-audit-closure]]; sin stage ni commit.
  - Evidencia y límites: [[hd-mezzanine-manual-iir]].

### Pendientes

- [ ] **Tarea 14 — Comparar estimadores en datos sintéticos.** En curso.
  - [x] Fijar contrato de métricas y separación desarrollo/evaluación.
  - [ ] Verificar helper de comparación mediante TDD.
  - [ ] Ejecutar piloto FBK1700 y matriz ampliada con holdout.
  - [ ] Revisar resultados y snapshot final.
  - Protocolo: [[task14-pedestal-comparison]].
- [ ] **Tarea 15 — Validación exploratoria DAPHNE ampliada.**
- [ ] **Tarea 16 — Integración conservadora con el filtro.**
- [ ] **Tarea 17 — Documentación y revisión independiente final del proyecto.**

## APIs disponibles

### Pedestal

- [[estimatePedestal]] — métodos `mean`, `median` y `median-of-means`, con
  incertidumbres y diagnósticos observacionales.
- [[subtractPedestal]] — sustracción separada con contrato evento × muestra.
- [[calculateMedianPedestal]] — implementación legacy preservada y caracterizada;
  no es la API moderna autoritativa.

Los flags de calidad no eliminan eventos automáticamente. `validEventMask` permite
que una etapa posterior aplique una selección explícita manteniendo los diagnósticos.

### Simulación

- [[simulatePedestalStressWaveforms]] — composición FIR/IIR, baseline, ruido en parent,
  crop y clipping explícito; probado y auditado en G2, véase [[task13-audit-closure]].

- [[generateColoredNoise]] — ruido real con PSD bilateral, RNG local, RMS objetivo y
  recorte central trazable.
- [[generateEventTrain]] — multiplicidad objetivo fija, Poisson o PMF empírica,
  dark counts y perturbaciones grandes con componentes separados y ground truth.

`generateEventTrain` produce un tren discreto de impulsos. Todavía no aplica baseline,
ruido, respuesta FIR/IIR, burn-in, crop, cuantización ni encoding ADC; esa composición
pertenece a la Tarea 13.

## Evidencia de Tarea 11

La implementación se desarrolló mediante seis ciclos RED→GREEN y cuatro
caracterizaciones adicionales tras revisión científica independiente.

```text
TestGenerateEventTrain:  10/10
suite estándar:         143/143
integraciones DAPHNE:      3/3
checkcode:                 0/2
Wikilinks:               308/0 faltantes antes de esta nota
schema truth/docs:         31/0 faltantes
hashes protegidos:         PASS
git diff --check:           PASS
secretos detectados:          0
data/outputs trackeados:      0
```

La auditoría independiente fail-closed del snapshot funcional concluyó:

```text
passed:                       true
hashes_match:                 true
blocking_errors:                 0
security_concerns:               0
logic_errors:                    0
scientific_contract_errors:      0
documentation_errors:            0
preservation_errors:             0
remaining_coverage_gaps:         0
nonblocking_suggestions:         0
```

Snapshot funcional auditado antes de esta sincronización documental de Obsidian:

```text
9535f5964c01aab2226fd701a1606e6945b479c63942feb13c83a15fe2cbd4f9
```

El código de producción auditado al cierre de Tarea 11 tenía SHA-256:

```text
d2a89d4baa9fcbec63f0e2b06bf8ea3bf040b556c37f54bcc0adda9763fd75de
```

La Tarea 12 modifica intencionalmente esa API y añade
`TestGenerateSignalMultiplicity.m`; el hash anterior queda como evidencia del
punto de partida auditado, no como hash del candidato actual.

## Evidencia de Tarea 12

La multiplicidad objetivo se configura con `fixed`, `poisson` o `empirical-pmf`.
El default sigue siendo multiplicidad fija 1 y preserva la secuencia aleatoria de
Tarea 11. Poisson incluye 0 PE y la PMF empírica admite masa explícita en cero.
`log-series` se rechaza hasta que exista evidencia holdout a su favor.

Dos revisiones independientes tempranas detectaron cancelación numérica en PTRS
cerca de `flintmax` y overflow posible en amplitud×multiplicidad. Se corrigieron con
techo Poisson `1e9`, límites `flintmax` uniformes, guard de producto antes del RNG y
cobertura RED→GREEN. En total se ejecutaron seis ciclos RED→GREEN y nueve
caracterizaciones adicionales:

```text
TestGenerateSignalMultiplicity:      16/16
regresión TestGenerateEventTrain:    10/10
suite estándar:                     159/159
integraciones DAPHNE:                  3/3
checkcode:                             0/3
```

El ground truth conserva la multiplicidad de cada waveform, el modelo y sus
parámetros, además de la media esperada. La referencia se escala antes de sumar dark
counts y eventos grandes y antes de cualquier clipping explícito. La auditoría
independiente de Tarea 12 aprobó el snapshot final `830098f1…67b6d10`, con hashes
inicial/final idénticos; el certificado está en [[task12-audit-closure]].

## Estado científico

```text
scientificApproval = false
```

La identificación inicial documentada en [[iir-daphne-fbk-vgain-1700]] no reprodujo
adecuadamente el undershoot del dataset/template ensayado. No es una limitación
general de los IIR: el modelo manual y el reajuste sobre promedios de todas las
multiplicidades FBK VGAIN1700 reproducen su tendencia; véase [[task13-fbk-vgain1700]].
La cola fuera de la ventana observada sigue siendo extrapolación, y la aprobación
científica global permanece pendiente.

La validación de [[estimatePedestal]] sobre DAPHNE es exploratoria y está documentada
en [[pedestal-daphne-fbk-vgain-1700]]. El conjunto puede estar afectado por ruido
externo y sus métricas dependen de VGAIN y de la configuración electrónica. No debe
usarse como referencia científica universal.

Todavía no se eligió un estimador moderno definitivo. Esa decisión depende de la
comparación sintética con ground truth de la Tarea 14 y de la validación ampliada de
la Tarea 15.

## Estado Git y preservación

- Rama: `master`.
- Base de Tareas 0–10: `2a9bf1bca977c542d88e36a5ef2b1fa046039200`.
- Commit local conjunto de Tareas 11–12: `2c3a286d1a1a24e971070b708317c8d6e24905a2`.
- El seguimiento documental se actualiza por separado, sin cambiar producción/tests auditados.
- No se realizó `push`; no hay remotos configurados.
- `data/` y `outputs/` permanecen fuera de Git.
- El script histórico NP02 y sus `.mat` originales permanecen protegidos y no se
  ejecutaron durante esta tarea.
- El cambio preexistente de `docs/INDEX.md` permanece fuera del alcance de esta
  actualización.

## Próximo paso

Las auditorías de Tareas 12 y 13 están cerradas. La Tarea 13 implementa:
composición de trazas largas, baseline, ruido, FIR/IIR y crop con truth.
Integración FBK1700, gates y revisión independiente completados en G2.
La Tarea 14 está iniciada; no se han elegido método ni thresholds nuevos.
La autorización de Tarea 14 no incluye commit de Tarea 13 ni iniciar Tarea 15.

## Notas relacionadas

- [[estimatePedestal]]
- [[subtractPedestal]]
- [[generateColoredNoise]]
- [[generateEventTrain]]
- [[pedestal-daphne-fbk-vgain-1700]]
- [[iir-daphne-fbk-vgain-1700]]
- [[optimal-filter-daphne-reference]]
- [[analysis_daphne_data]]


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


## Nota de trazabilidad documental

Esta actualización de progreso es posterior al snapshot auditado. Los párrafos
fechados de reanudación y los hashes históricos se conservan como evidencia; el
estado vigente de las tareas es el checklist anterior y el certificado de cierre.
