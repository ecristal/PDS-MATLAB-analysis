---
title: fit2SPE
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/fit2SPE.m
source_path: Scripts_analisis/data/fit2SPE.m
workflow:
  - "docs/workflows/analysis_daphne_data.md"
tags: [matlab, spe, fitting, filter]
---

[Código fuente MATLAB](../../src/data/fit2SPE.m)

## Descripción cualitativa

Alinea y escala la respuesta impulsional de un modelo discreto para aproximar una señal SPE. Realiza primero un barrido de desplazamiento y luego un barrido fino de amplitud usando NRMSE.

## Firma

```matlab
function fitted_single_pe = fit2SPE(model, spe_signal)
```

## Entradas y salidas

- `model`: objeto/estructura con `Numerator{1}` y `Denominator{1}`.
- `spe_signal`: waveform SPE de referencia.
- `fitted_single_pe`: respuesta filtrada con desplazamiento y amplitud seleccionados.

## Algoritmo o procedimiento

1. Localiza máximo y posición del waveform.
2. Construye un impulso en esa posición.
3. Barre 31 desplazamientos y evalúa `1-goodnessOfFit(...,'NRMSE')`.
4. Fija el mejor desplazamiento.
5. Barre amplitud alrededor de ±3 con paso 0.1.
6. Devuelve la mejor respuesta y la superpone gráficamente a la señal.

## Dependencias

`filter`, `circshift`, `goodnessOfFit` y plotting. `goodnessOfFit` se asocia normalmente con System Identification Toolbox.

## Efectos secundarios

Grafica siempre sobre los ejes actuales mediante `plot` y `hold on`.

## Supuestos, unidades y dimensiones

Modelo SISO discreto; amplitud del resultado en las mismas unidades que `spe_signal`.

## Riesgos y limitaciones

- La preasignación de `horizontal_gof` usa un rango que mezcla `max_spe_pos` con `max_spe_value`; puede tener tamaño incorrecto.
- El desplazamiento está limitado a 30 muestras y la amplitud a ±3 unidades sin parámetros configurables.
- No valida que la posición permita el rango o que el modelo posea las propiedades requeridas.
- Mezcla ajuste y visualización.

## Destino provisional en el paquete

Candidato a `+pds/+fitting/fitSinglePhotoelectronTemplate.m`, separando cálculo, opciones de búsqueda y plotting.

## Evidencia y grado de certeza

- **Observado:** búsquedas discretas de shift y amplitud por NRMSE.
- **Inferido:** el modelo representa la respuesta electrónica a 1 PE.
- **Desconocido:** tipo concreto del modelo y justificación de rangos.

## Preguntas pendientes

- ¿La métrica deseada debe maximizar `1-NRMSE`?
- ¿Los límites de 30 muestras y ±3 son universales?

## Enlaces

- `docs/workflows/analysis_daphne_data.md`
- `docs/dependency-maps/analysis_daphne_data_dependencies.md`
- `docs/catalog/MATLAB_SCRIPT_CATALOG.md`
