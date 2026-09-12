---
type: audit-closure
status: approved-isolated
date: 2026-09-12
tags: [simulation, multiplicity, audit, matlab]
---

# Cierre de Tarea 12 — multiplicidad configurable

La Tarea 12 queda completada como componente aislado. Esta nota registra el
resultado posterior a la congelación y complementa [[pedestal-estimation-refactor-status]]
y [[generateEventTrain]], sin modificar los seis archivos auditados que aún
conservan el estado documental previo al dictamen.

## Dictamen independiente

- Revisión: `deleg_0b0ec6fc`.
- `approved=true`: aprobación estática independiente del snapshot exacto.
- Sin defectos bloqueantes de lógica o documentación dentro del alcance Tarea 12.
- Hash combinado inicial y final idénticos:

```text
830098f193f89b1dae5df4c65f05845a7186edba7e7615e0e5e628b7167b6d10
```

El auditor leyó implementación, ambos archivos de pruebas y documentación de
Tarea 12. No ejecutó MATLAB ni creó/modificó archivos. Los tests siguientes fueron
ejecutados por el implementador, no por el auditor.

## Evidencia ejecutada en la reanudación

- Suite estándar: 159/159; cero fallos e incompletos.
- Incluye multiplicidad 16/16 y regresión Tarea 11 10/10.
- `checkcode`: cero mensajes en implementación y ambos archivos de tests.
- RED7 reprodujo multiplicidad -1 para medias Poisson positivas diminutas;
  GREEN7 obliga el primer draw de Knuth y preserva la rama lambda=0 sin draws.
- Verificación ad-hoc posterior: cuatro medias diminutas, RNG global preservado,
  lambda=0 sin consumo; test focalizado 1/1 y checkcode cero en dos archivos.
  El script temporal se eliminó antes de las comprobaciones.
- Integraciones DAPHNE 3/3: evidencia anterior, no repetida en esta reanudación.

Se mantienen fixed, Poisson y PMF empírica, ground truth por waveform, separación
de procesos y clipping explícito. Se verificaron las correcciones de límites,
producto amplitud×multiplicidad y medias diminutas. Las pruebas de ensemble no
constituyen una calibración física del detector.

## Alcance y preservación

`scientificApproval=false` continúa vigente para DAPHNE. No se implementó Tarea 13,
no se ejecutaron scripts históricos sobre datos originales y no hubo staging,
commit ni push. Los tres artefactos protegidos comprobados (script NP02, JSON NP02
y FIG DAPHNE) coincidieron con sus hashes; data/outputs siguen sin archivos trackeados.

Esta nota es un certificado posterior, fuera del manifiesto auditado. No amplía
la aprobación a otros archivos ni a un commit. Próximo paso funcional: Tarea 13,
solo con autorización posterior.

## Manifiesto auditado

- `.hermes/plans/2026-08-11_220343-pedestal-estimation-refactor.md`
  SHA-256: `267eb0ce4c4bdf63c6aeaad33152d47d5a8f2358fbb2890ed716366f4ddee177`
- `docs/functions/generateEventTrain.md`
  SHA-256: `8398ea69741dce768df34b481d558668e56d419a614bb8dda94086df88b09034`
- `docs/status/pedestal-estimation-refactor-status.md`
  SHA-256: `fce10fb74a5216960baae296de1d2cc2092f2320d021937d212df7beddef63da`
- `src/+pds/+simulation/generateEventTrain.m`
  SHA-256: `d3c941a3e4c6602da0ba73f1fa384a32d341aed2831ba112521bd767054c955a`
- `tests/TestGenerateEventTrain.m`
  SHA-256: `5e8945cc9ab83e767adb498fce7919d3bfb909c639ea130f32a7d6e139fbb2d7`
- `tests/TestGenerateSignalMultiplicity.m`
  SHA-256: `b08b6cd7ff485b8b9cfb117f1ad19f5032cd93e91b129e8fc3f8cba1bc042853`
