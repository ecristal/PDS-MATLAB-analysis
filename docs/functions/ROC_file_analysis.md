---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/ROC_file_analysis.m
source_path: Scripts_analisis/data/ROC_file_analysis.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, roc, trigger, metrics]
---

# ROC_file_analysis

## Descripción cualitativa

Resume un barrido de umbral de trigger: selecciona el umbral de máxima accuracy, extrae TPR/FPR y calcula indicadores basados en el área de la curva ROC.

## Firma

```matlab
function [estimated_threshold_position, pos_accuracy, pos_tpr, pos_fpr, ...
    pauc, pauc_n, gini] = ROC_file_analysis(roc, threshold_level, plot_data)
```

## Responsabilidad dentro del workflow

Convierte la estructura de conteos/métricas producida durante el estudio de trigger en un punto operativo y métricas ROC resumidas.

## Entradas y salidas

- `roc`: celda/estructura con `roc{threshold_level}.data`; cada entrada debe contener `accuracy`, `sensitivity`, `specificity` y `virtual_trigger_pos`.
- `threshold_level`: índice del conjunto analizado.
- `plot_data`: habilita gráficos.
- Salidas: umbral óptimo por accuracy, métricas en ese punto, área `pauc`, versión normalizada `pauc_n` y `gini`.

## Algoritmo o procedimiento

1. Extrae accuracy, sensibilidad y `1-specificity`.
2. Reconstruye un vector de umbrales asumiendo paso constante.
3. Selecciona el máximo de accuracy.
4. Descarta TPR donde FPR es NaN y ordena por FPR.
5. Integra TPR(FPR) con `trapz` y aplica una normalización.
6. Opcionalmente grafica accuracy y ROC.

## Dependencias

Funciones MATLAB de celdas, ordenamiento, integración y plotting.

## Efectos secundarios

Con `plot_data=true` abre/modifica las figuras 1 y 2.

## Supuestos, unidades y dimensiones

El umbral se etiqueta en ADU. Se presupone un barrido uniformemente espaciado y al menos dos puntos.

## Riesgos y limitaciones

- La reconstrucción `init:step:last` puede no coincidir con todos los `virtual_trigger_pos` si el barrido no es uniforme.
- Se calcula `min_fpr_pos` pero no se utiliza.
- No se ordenan/filtran pares antes de seleccionar el punto de máxima accuracy.
- La fórmula de `pauc_n` requiere revisar su definición y puede dividir por cero en rangos degenerados.
- No valida estructura ni celdas vacías.

## Destino provisional en el paquete

Candidato a `+pds/+metrics/analyzeRocSweep.m`, conservando una definición documentada de AUC parcial y Gini.

## Evidencia y grado de certeza

- **Observado:** extracción de métricas, máximo de accuracy, integración y plots.
- **Inferido:** optimización de umbral virtual para trigger DAPHNE.
- **Desconocido:** definición científica exacta de `threshold_level` y `pauc_n`.

## Preguntas pendientes

- ¿La métrica es AUC completa o parcial?
- ¿Los umbrales son siempre equidistantes?
- ¿Qué criterio debe resolver empates de accuracy?

## Enlaces

- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
- [[MATLAB_SCRIPT_CATALOG]]
