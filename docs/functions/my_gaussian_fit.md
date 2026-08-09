---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/my_gaussian_fit.m
source_path: Scripts_analisis/data/my_gaussian_fit.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, fitting, gaussian]
---

# my_gaussian_fit

## Descripción cualitativa

Configura un ajuste gaussiano simple (`gauss1`) con parámetros iniciales suministrados y pesos no nulos solo alrededor de una región central.

## Firma

```matlab
function [mu1, sigma1, snr_gauss_fit] = my_gaussian_fit( ...
    x_hist, y_hist, max_value, max_value_x_pos, init_sigma_2_sqrt)
```

## Entradas y salidas

- `x_hist`, `y_hist`: datos del histograma.
- `max_value`: amplitud inicial.
- `max_value_x_pos`: se usa simultáneamente como centro inicial y como índice de vector.
- `init_sigma_2_sqrt`: parámetro inicial `c1` y semiancho entero para pesos.
- Devuelve centro `mu1`, sigma física interpretada como `c1/sqrt(2)` y objeto de ajuste.

## Algoritmo o procedimiento

1. Crea opciones de `gauss1`.
2. Asigna StartPoint `[amplitud, centro, c]`.
3. Construye pesos 0/1 en una ventana centrada.
4. Ajusta X/Y.
5. Extrae `b1` y convierte `c1` a sigma.

## Dependencias

Curve Fitting Toolbox: `fitoptions` y `fit`.

## Efectos secundarios

No grafica ni escribe archivos.

## Supuestos, unidades y dimensiones

X, centro y sigma deben compartir unidades. La implementación presupone que el centro puede usarse como índice entero de MATLAB.

## Riesgos y limitaciones

- `max_value_x_pos` parece mezclar coordenada X con posición de índice.
- Los límites de pesos pueden ser no enteros, menores que 1 o exceder el vector.
- No valida longitudes, rango o sigma.
- El nombre `init_sigma_2_sqrt` refleja el parámetro `c` de `gauss1`, no directamente sigma.

## Destino provisional en el paquete

Candidato a `+pds/+fitting/fitGaussianPeak.m`, separando índice del bin y valor X y usando límites explícitos.

## Evidencia y grado de certeza

- **Observado:** ajuste `gauss1`, ventana de pesos y conversión de sigma.
- **Inferido:** auxiliar para un único pico del histograma.
- **Desconocido:** si `max_value_x_pos` se pasa como índice o coordenada en el workflow activo.

## Preguntas pendientes

- ¿La entrada debe ser `max_index` y derivar el centro desde `x_hist(max_index)`?
- ¿Los pesos fuera de la ventana deben ser cero o simplemente menores?

## Enlaces

- [[analysis_daphne_data]]
- [[gaussian_fit_SNR]]
- [[analysis_daphne_data_dependencies]]
