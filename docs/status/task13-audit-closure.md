---
type: audit-closure
status: software-approved
updated: 2026-09-14
tags: [pedestal, simulation, task13, audit, fbk]
---

# Tarea 13 — cierre de software

Relacionado: [[pedestal-estimation-refactor-status]],
[[simulatePedestalStressWaveforms]], [[task13-fbk-vgain1700]].

## Dictamen y alcance

Tarea 13 completada: SPEC preservada (17/17 criterios) y QUALITY aprobada en el
snapshot G2. QUALITY-13-1 cerrado mediante RED→GREEN: el overflow en truth de
eventos se rechaza antes de avanzar el stream del usuario, aunque el baseline
opuesto pudiera dejar finita la waveform final.

La aprobación corresponde al árbol de trabajo definido por el manifiesto, no al
HEAD por sí solo. Base: `9056031ce7d670c94d28938d791c77b833e68520`, rama `master`.
No se realizó stage, commit ni push de la Tarea 13.

## Evidencia del mismo snapshot

| Gate | Resultado |
|---|---|
| Pruebas focalizadas | 14/14, 0 fallos, 0 incompletos |
| Suite estándar | 173/173, 0 fallos, 0 incompletos |
| checkcode fuente/tests nuevos | 0 mensajes |
| Integración FBK1700 | 4/4: constant, slope, step, wander |
| Revisión independiente G2 | approved=true, specPreserved=true, qualityApproved=true |
| Hashes inicial/final de revisión | 142/142 idénticos |
| Revalidación final del controlador antes del cierre documental | 142/142 idénticos |

MATLAB: R2025b Update 3, 25.2.0.3123386. Dos warnings de deprecación provienen de
la prueba del wrapper legacy existente. El revisor reutilizó logs y no ejecutó
MATLAB; las ejecuciones RED/GREEN, suite e integración tienen sus propios logs.
No se atribuye al revisor ejecución runtime que no realizó.

`outputs/validation/task13-core/` (ignorado por Git):

- `16-quality-red.log`: reproducción del defecto antes del fix.
- `17-quality-green.log`: regresión y suite focalizada, checkcode.
- `18-quality-full-suite.log`: suite estándar posterior al fix.
- `gate-summary-g2.json`: gates agregados.
- `review-manifest-g2.json`: manifiesto auditado.
- `review-quality-g2.json`: certificado independiente con hashes inicial/final.

Integración posterior al fix:
`outputs/validation/task13-fbk-vgain1700/task13-integration-quality-fixed.log`.
El JSON de métricas quedó byte-idéntico al anterior; la integración sí se repitió
sobre los bytes corregidos. El reajuste `tfest` no se repitió.

SHA-256 del manifiesto G2:
`d54c4226361f3cbcc407cb3f7f4df7e422aa9de701b0c353d36c2dd23a578603`.

SHA-256 del certificado independiente:
`97a1cc673d9ae48c1c6a12479ab8750b04dcc9d24ee5201430858fc692dba33d`.

Fuente aprobada:
`71d91245cb39f60d3a03221d7c7a447eb653decf6a8d44028628e7073a41a23d`.

Tests aprobados:
`53b1f1f9bf7716dbd4564ad58aaf2dc2a0413d9f50701365a7d80d4989534083`.

## Límites científicos y preservación

Solo FBK VGAIN1700, canal 24 y Ts=16 ns en la integración. La forma temporal usa
promedios de todas las multiplicidades. Amplitud de 1 PE, baseline y amplitudes de
perturbación de la integración son elecciones sintéticas explícitas, no
calibración medida. Ganancia y ruido dependen del frontend/configuración.

El perfil de pretrigger es un proxy susceptible a dark counts y ruido externo;
la interpolación espectral y el settling fuera de la ventana observada son modelo,
no nueva evidencia experimental. `scientificApproval=false` se mantiene.
No se eligió estimador de pedestal ni se comenzó la Tarea 14.

Los archivos de entrada conservan sus hashes. El Live Script y el script NP02
permanecen byte-idénticos al HEAD. Cuatro funciones de texto legacy tienen CRLF
en checkout y LF en Git: sus blobs filtrados coinciden; eso no se confunde con
igualdad binaria. `data/` y `outputs/` permanecen ignorados, no versionados.

## Cierre documental posterior a la auditoría

Después de verificar los 142 hashes se actualizaron únicamente los estados/checks
y textos de cierre en estas notas:

- `docs/status/pedestal-estimation-refactor-status.md`;
- `docs/functions/simulatePedestalStressWaveforms.md`;
- `docs/validation/task13-fbk-vgain1700.md`.

Sus bytes auditados originales se preservan bajo
`outputs/validation/task13-core/frozen-g2-docs/`, manteniendo las rutas relativas.
Esta nota es nueva y también posterior a la auditoría. No se presenta el cierre
documental como parte del snapshot revisado ni se altera el manifiesto G2 para
crear una aprobación circular. `closure-verification.json` registra los hashes
actuales del cierre y confirma que el resto del manifiesto auditado no cambió.
El cambio preexistente de `docs/INDEX.md` se preservó sin editar.
