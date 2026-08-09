---
type: matlab-function
status: external-dependency
review_status: reviewed-static
review_mode: static
repo_path: external/fiuna-pasantia-tesis-matlab/f_fourier.m
source_path: FIUNA/Pasantia-Tesis/MATLAB/f_fourier.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, fft, psd, external-provenance]
---

# f_fourier

## Descripción cualitativa

Calcula FFT, espectro unilateral de amplitud, PSD unilateral y RMS integrado para uno o varios registros. Opcionalmente grafica en amplitud absoluta o dBFS.

## Firma

```matlab
function [f, P1, Y, Pc1, rms_] = f_fourier( ...
    senhal, Tm, do_plot, y_label, normalize)
```

## Procedencia

Fue copiada desde `OneDrive/Documents/FIUNA/Pasantia-Tesis/MATLAB`, fuera del árbol original `Scripts_analisis`. Se conserva en `external/` hasta aclarar autoría, licencia y relación con el paquete.

## Entradas y salidas

- `senhal`: matriz registros × muestras o un registro.
- `Tm`: período de muestreo en segundos.
- `do_plot`, `y_label`, `normalize`: control de visualización/escala.
- Devuelve vector de frecuencia, amplitud unilateral media, FFT compleja media, PSD unilateral media y RMS por registro.

## Algoritmo o procedimiento

1. Calcula FFT por fila.
2. Convierte a amplitud y PSD unilaterales duplicando bins interiores.
3. Anula DC solo para integración de RMS.
4. Integra PSD con `trapz(Pc1)*df`.
5. Promedia espectros entre registros.
6. Opcionalmente convierte P1 a dBFS respecto a `2^14` y grafica.

## Dependencias y efectos secundarios

Usa funciones MATLAB básicas y plotting. Con `do_plot=true` modifica la figura 3.

## Supuestos, unidades y dimensiones

- `Tm` en segundos y `f` en Hz.
- Referencia dBFS fija a ADC de 14 bits.
- Filas representan registros independientes.

## Riesgos y limitaciones

- [[optimal_filter_for_daphne_gpessina_function]] la llama con tres argumentos, pero esta copia exige cinco; además `y_label` se evalúa aunque `do_plot=false`, por lo que esa rama no puede asumirse ejecutable.
- Devuelve una PSD unilateral de longitud `floor(N/2)+1`, mientras el filtro óptimo intenta dividir por ella un espectro bilateral de longitud N.
- La componente DC de `Pc1` se fuerza a cero; usarla como denominador genera una singularidad si no se regulariza.
- La lógica de duplicación del último bin no distingue explícitamente N par/impar.
- Se promedia FFT compleja entre eventos, lo que puede cancelar fases.
- `normalize` modifica `P1` durante plotting, alterando también la salida.
- No protege `log10(0)` ni normalización por máximo cero.

## Destino provisional en el paquete

Mantener como dependencia externa hasta resolver procedencia. Si se adopta, separar cálculo de plotting en `+pds/+signal/computeSpectrum.m` y hacer explícita la referencia ADC.

## Evidencia y grado de certeza

- **Observado:** firma de cinco argumentos, FFT/PSD/RMS y referencia 14-bit.
- **Inferido:** utilidad genérica reutilizada desde un trabajo FIUNA.
- **Desconocido:** licencia, autoría original y versión compatible esperada por el filtro óptimo.

## Preguntas pendientes

- ¿Existe otra versión de tres argumentos en el MATLABPATH histórico?
- ¿Debe la FFT compleja promediarse o conservarse por evento?
- ¿La referencia ADC es siempre 14 bits?

## Enlaces

- [[optimal_filter_for_daphne_gpessina_function]]
- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
