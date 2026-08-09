---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/daphne/calculateMedianPedestal.m
source_path: Scripts_analisis/daphne/calculateMedianPedestal.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, pedestal, preprocessing, daphne]
---

# calculateMedianPedestal

## Descripción cualitativa

Estima un pedestal robusto muestreando ventanas aleatorias dentro de una región de pretrigger. Resume las medias de esas ventanas mediante mediana y cuartiles.

## Firma

```matlab
function [pedestal, pedestal_25, pedestal_75, out_seed] = ...
    calculateMedianPedestal(signal, pedestal_limit, average_width, number_of_regions, in_seed)
```

## Responsabilidad dentro del workflow

[[analysis_daphne_data]] la utiliza para caracterizar el nivel de pedestal y su dispersión antes de integrar o filtrar waveforms.

## Entradas

- `signal`: vector de muestras.
- `pedestal_limit`: última muestra permitida para las ventanas de pedestal.
- `average_width`: número exacto de muestras por ventana.
- `number_of_regions`: cantidad de ventanas aleatorias.
- `in_seed`: semilla del generador aleatorio.

## Salidas

- `pedestal`: mediana de las medias regionales.
- `pedestal_25`, `pedestal_75`: cuartiles 25 % y 75 %.
- `out_seed`: estado de RNG capturado inmediatamente después de aplicar la semilla y antes de generar las regiones.

## Algoritmo o procedimiento

1. Valida límites, ancho y número de regiones.
2. Inicializa el RNG global con `rng(in_seed,'multFibonacci')`.
3. Selecciona comienzos uniformemente distribuidos mediante `randi`.
4. Calcula la media de cada ventana.
5. Obtiene los cuartiles `[0.25, 0.5, 0.75]`.

## Dependencias

Funciones MATLAB: `rng`, `randi`, `mean`, `quantile` y `error`.

## Efectos secundarios y rutas hard-coded

No contiene rutas. Modifica el estado global del generador aleatorio.

## Supuestos, unidades y dimensiones

- Se trata `signal` como un vector lineal; no se valida explícitamente su orientación.
- La unidad del pedestal es la misma que la amplitud de `signal`, presumiblemente ADU dentro del workflow.
- Los límites y anchos están expresados en muestras.

## Riesgos y limitaciones

- Ventanas aleatorias pueden solaparse.
- `out_seed` no representa el estado posterior al muestreo, por lo que el nombre/comentario puede inducir a error.
- No se exige que los parámetros de conteo sean enteros.
- Cambia el RNG global en lugar de usar un stream local.

## Destino provisional en el paquete

Candidato a una función de preprocesamiento, por ejemplo `+pds/+preprocess/estimatePedestal.m`, después de definir con precisión reproducibilidad y unidades.

## Evidencia y grado de certeza

- **Observado:** validaciones, muestreo aleatorio, cálculo de medias y cuartiles.
- **Inferido:** uso de ADU y región de pretrigger dentro del workflow.
- **Desconocido:** criterio físico para seleccionar ancho, límite, número de regiones y semilla.

## Preguntas pendientes

- ¿Debe `out_seed` ser la semilla inicial o el estado final?
- ¿Se permiten ventanas solapadas deliberadamente?
- ¿Cuál es la convención de orientación de los waveforms?

## Enlaces

- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
- [[MATLAB_SCRIPT_CATALOG]]
