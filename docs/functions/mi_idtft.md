---
type: matlab-function
status: dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/mi_idtft.m
source_path: Scripts_analisis/data/mi_idtft.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, inverse-dft, spectral]
---

# mi_idtft

## Descripción cualitativa

Implementación explícita de la transformada discreta inversa, utilizada para llevar al dominio temporal espectros construidos por el filtro óptimo.

## Firma

```matlab
function x = mi_idtft(ft_function)
```

## Algoritmo o procedimiento

Para cada muestra temporal suma todos los bins complejos con fase positiva y divide el resultado por N.

## Entradas y salidas

- `ft_function`: vector complejo de N bins.
- `x`: vector complejo de N muestras; el llamante puede tomar su parte real.

## Dependencias y efectos secundarios

Solo funciones MATLAB básicas. No realiza IO ni plotting.

## Supuestos, unidades y dimensiones

Aplica la convención IDFT estándar con normalización 1/N. Trata la entrada como vector lineal.

## Riesgos y limitaciones

- Complejidad O(N²); `ifft` debería ser equivalente bajo la misma convención.
- No valida forma, finitud ni simetría hermítica.
- No fuerza salida real, aunque el espectro represente una señal real.

## Destino provisional en el paquete

Mantener temporalmente como referencia en `+pds/+signal/idft.m`; evaluar sustitución por `ifft` tras comparación autorizada.

## Evidencia y grado de certeza

- **Observado:** suma IDFT completa y división por N.
- **Inferido:** función de validación/didáctica.
- **Desconocido:** razón para no usar `ifft`.

## Preguntas pendientes

- ¿Existen casos donde difiera intencionalmente de `ifft`?
- ¿Debe devolver explícitamente `real(x)`?

## Enlaces

- [[mi_dft]]
- [[optimal_filter_for_daphne_gpessina_function]]
- [[analysis_daphne_data_dependencies]]
