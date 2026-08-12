# Workflow histórico NP02 de función de transferencia

## Original protegido

```text
C:\Users\e_cri\OneDrive\Documents\INFN\NP02\Simulations\selftriggering\timestamp_location\templates_tf\templates\np02_tf_estimation_pds_algorithm.m
```

SHA-256:

```text
e5ebdfe276727602af6a67cc1759e16e111ad49221769523e232bcb8f6429302
```

Copia preservada byte a byte:

```text
legacy\np02\np02_tf_estimation_pds_algorithm.m
```

Los hashes origen/copia coinciden. Los `.mat` asociados fueron catalogados en `inventory/np02-transfer-function-manifest.csv`; no se copiaron ni modificaron.

## Comportamiento manual identificado

- Selección fija del elemento 16.
- `Tm=16 ns`, `starting_point=250`, orden 4 y scan de shift `-10:20`.
- Mezcla carga, corrección de baseline, normalización, `tfest`, plotting, compensación y persistencia.
- Ejecuta `save` sobre `templates_np02_large_pulses.mat`; por eso no debe ejecutarse en su ubicación original.
- Dependencia no localizada: `generateFractionalZeroCompensator`.

## Dirección de refactorización

El núcleo futuro recibirá arrays en memoria, será libre de plotting/persistencia y producirá un IIR discreto estable normalizado por pico. La aceptación evaluará por separado pico, undershoot, cola, tiempo de retorno y polo lento; una FIR se usará solo como comparación.
