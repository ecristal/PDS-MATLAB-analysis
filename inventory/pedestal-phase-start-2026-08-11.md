# Snapshot inicial — fase de pedestal

- Fecha: 2026-08-11T22:55:36+02:00
- Repositorio: `C:\Users\e_cri\Documents\Proyectos\PDS-MATLAB-analysis`
- Rama: `master`
- HEAD: `cf19b8a8a4b9776dee1a37bdedcfb68390bf408e`
- Remotos: ninguno
- MATLAB: R2025b Update 3 (`25.2.0.3123386`)
- Estado científico: desarrollo y validación sintética; no medición de referencia

## Working tree al inicio

```text
 M docs/INDEX.md
?? .hermes/plans/2026-08-11_220343-pedestal-estimation-refactor.md
```

El cambio en `docs/INDEX.md` es previo/no relacionado y queda fuera de esta fase hasta revisión explícita.

## Protección

- `legacy/live-scripts/analysis_daphne_data.mlx`: no modificar ni ejecutar.
- `src/daphne/calculateMedianPedestal.m`: caracterizar antes de modificar.
- Originales NP02 en OneDrive: solo lectura; no ejecutar el script original ni escribir sus `.mat`.
- Datos y outputs: fuera de Git por defecto.

## Contratos

- Eventos por filas; muestras por columnas.
- ADC entero se valida y convierte a `double` antes de operaciones mixtas.
- Región de pedestal explícita.
- Estimación y sustracción separadas.
- RNG global no debe cambiar en APIs modernas.
- Normalización SPE inicial por pico.
- IIR autoritativo para undershoot/cola larga; FIR solo comparación.
- `lambda_dark`: 1e3–1e5 Hz.
- Grandes amplitudes: 8000 hasta valores mayores que `2^14`, sin saturación o wrap implícitos.
