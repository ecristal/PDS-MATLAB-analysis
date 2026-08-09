---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/daphne/sum_fitted_data.m
source_path: Scripts_analisis/daphne/sum_fitted_data.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, fitting, gaussian, daphne]
---

# sum_fitted_data

## Descripción cualitativa

Construye una curva formada por la suma de dos gaussianas. Conserva como normalización el área numérica de dos curvas ajustadas de entrada y utiliza medias y sigmas suministradas por separado.

## Firma

```matlab
function [x_data_fit, y_data_fit] = sum_fitted_data( ...
    fit1, fit2, mu1, sigma1, mu2, sigma2)
```

## Responsabilidad dentro del workflow

Auxiliar para representar o combinar dos componentes ajustadas durante el análisis de distribuciones de carga/fotoelectrones.

## Entradas y salidas

- `fit1`, `fit2`: objetos con propiedades `XData` y `YData`.
- `mu1`, `sigma1`, `mu2`, `sigma2`: parámetros gaussianos.
- `x_data_fit`: malla común refinada.
- `y_data_fit`: suma de las dos densidades gaussianas escaladas por área.

## Algoritmo o procedimiento

1. Extrae datos X/Y de ambos objetos.
2. Integra cada curva mediante `trapz`.
3. Usa un paso igual a un quinto del menor espaciado inicial.
4. Evalúa `normpdf` para cada componente.
5. Suma ambas contribuciones.

## Dependencias

`trapz`, `normpdf`, `min`; `normpdf` puede requerir Statistics and Machine Learning Toolbox según la versión MATLAB.

## Efectos secundarios y rutas hard-coded

No escribe archivos ni contiene rutas.

## Supuestos, unidades y dimensiones

Las unidades de X, medias y sigmas deben coincidir. Las áreas de las curvas de entrada se interpretan como normalizaciones de las gaussianas de salida.

## Riesgos y limitaciones

- Supone al menos dos puntos y espaciado representativo en ambos `XData`.
- La malla comienza en `x_data1(1)` y termina en `x_data2(end)`; depende del orden y cobertura de los fits.
- No valida sigmas positivos ni compatibilidad de unidades.
- La densidad gaussiana escalada por área no reproduce necesariamente las curvas originales fuera de sus dominios.

## Destino provisional en el paquete

Candidato a `+pds/+fitting/combineGaussianComponents.m` si se confirma que esta normalización es parte del método científico.

## Evidencia y grado de certeza

- **Observado:** integración, nueva malla, dos `normpdf` y suma.
- **Inferido:** representación de dos poblaciones/fotoelectrones.
- **Desconocido:** tipo exacto de `fit1`/`fit2` y razón física de refinar el paso por cinco.

## Preguntas pendientes

- ¿Los objetos de entrada son líneas gráficas u otro tipo de objeto?
- ¿Las áreas representan conteos, probabilidad o una normalización visual?

## Enlaces

- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
- [[MATLAB_SCRIPT_CATALOG]]
