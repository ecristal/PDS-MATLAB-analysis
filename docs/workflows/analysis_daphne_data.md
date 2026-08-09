---
type: matlab-live-script
status: legacy-reference
review_status: reviewed-static
review_mode: static
repo_path: legacy/live-scripts/analysis_daphne_data.mlx
source_path: Scripts_analisis/Live_scripts/analysis_daphne_data.mlx
workflow_name: DAPHNE waveform characterization
tags: [matlab, live-script, daphne, workflow, pds]
---

# analysis_daphne_data

## Resumen cualitativo

Live Script monolítico para cargar, acondicionar y caracterizar waveforms producidos por DAPHNE V2A. Reúne en un único workspace configuración de campaña, ingestión desde varios formatos, pedestal, filtrado, integración de carga, trigger/ROC, ajustes gaussianos, SNR, dinámica y generación de figuras/resultados.

Esta ficha describe el XML interno del `.mlx` estáticamente. No se ejecutó MATLAB ni se validaron resultados numéricos.

## Propósito científico

**Inferido:** servir como banco de análisis flexible para comparar configuraciones de DAPHNE/PDS y obtener métricas como pedestal, señal promedio, distribución de integral, separación de fotoelectrones, SNR, rango dinámico y desempeño del trigger.

## Estructura observada

El Live Script contiene 14 celdas de código y aproximadamente 1.068 líneas de código/comentarios, sin celdas narrativas independientes. Sus bloques principales son:

1. **Inicialización:** `clear all`, `close all`, selección de canales y longitudes.
2. **Configuración de archivos/setup:** rutas para señal, template, ruido, trigger, ROC y modelo SPE; parámetros VGAIN, PDE, OV, Vbias, threshold y run.
3. **Selección de fuente:** datos DAPHNE `.dat/.7z/.gz`, CSV, pickle de waffles o binario de osciloscopio.
4. **Flags de análisis:** self-trigger, derivada, cuantiles, fitting automático, rango dinámico, filtro óptimo y media móvil.
5. **Configuración de nombres/salidas:** títulos, identificadores y nombres de figuras.
6. **Templates y filtros:** templates de señal/ruido, filtros de compensación y opciones experimentales comentadas.
7. **Pedestal y selección de eventos:** cálculo de pedestal/RMS, rechazo de outliers y preparación de ventanas.
8. **Trigger:** alineación y evaluación de señales de trigger o self-trigger.
9. **Loop principal:** filtrado por evento, matched/Wiener/fractional Fourier, integración y acumulación de waveforms.
10. **ROC:** matriz de confusión, sensibilidad, especificidad, accuracy y guardado de estructura ROC.
11. **Visualización:** waveform medio, ventanas de integración y figuras diagnósticas.
12. **Ajustes:** ramas manual/automática para histogramas y picos gaussianos.
13. **SPE/SNR/dinámica:** extracción de métricas y señal promedio de un fotoelectrón.
14. **Persistencia:** figuras `.fig/.png`, datos ROC y configuración `.mat`.

## Entradas

### Configuración directa en workspace

- Canales de señal, trigger, template y ruido.
- `waveforms_length` y tipo/endianness de datos.
- Rutas absolutas a archivos de señal, ruido, template, trigger, pickle, osciloscopio y resultados.
- Variables físicas/de setup: VGAIN, PDE, OV, Vbias, threshold, run y parámetros de ajuste.
- Numerosos flags booleanos que determinan ramas del pipeline.

### Formatos observados

- DAPHNE `.dat`, `.7z` y `.gz` mediante [[extract_and_import_DAPHNE_data]].
- Texto/CSV mediante `load`.
- Pickle/waffles mediante [[getDataFromWafflesPickleFile]].
- Binarios de osciloscopio R&S mediante [[readBinaryDataRSOsc]].
- Archivos `.mat` con templates, filtros, configuración y resultados previos.

## Salidas

- Variables en el workspace: matriz de waveforms, waveform medio, pedestal/RMS, integrales, fits, SNR y métricas de trigger.
- Figuras de trigger, waveform promedio, histogramas y SPE en `.fig` y `.png`.
- Estructuras ROC guardadas con `save`.
- Configuración de fitting/integración en `analysis_config.mat` u otra ruta configurada.

## Dependencias locales

Dependencias directas staged:

- [[extract_and_import_DAPHNE_data]]
- [[calculateMedianPedestal]]
- [[getDataFromWafflesPickleFile]]
- [[readBinaryDataRSOsc]]
- [[optimal_filter_for_daphne_gpessina_function]]
- [[f_fourier]]
- [[fit2SPE]]
- [[gaussian_fit_SNR]]
- [[my_gaussian_fit]]
- [[sum_fitted_data]]
- [[ROC_file_analysis]]

Las dependencias transitivas se muestran en [[analysis_daphne_data_dependencies]].

## Dependencias MATLAB y externas

**Observado/inferido por llamadas:** operaciones de Signal Processing (Butterworth, filtrado, ventanas, `findpeaks`, `filtfilt`, wavelet denoising), Curve Fitting (`fit`, modelos `gaussN`), Statistics (`normpdf`, `normfit`, cuantiles), System Identification (`goodnessOfFit`), interfaz Python, plotting y 7-Zip.

La lista exacta de toolboxes requiere validación posterior; no se consultó MATLAB.

## Rutas y estado implícito

- Contiene múltiples rutas absolutas bajo `C:\Users\e_cri\...` y rutas relativas dependientes de `pwd`.
- Usa el workspace como contrato implícito entre celdas.
- `clear all` y `close all` alteran el estado de sesión.
- Bloques comentados funcionan como alternativas manuales de configuración.
- La combinación de flags determina qué variables quedan definidas antes de bloques posteriores.
- Incluye una rama interactiva con `waitforbuttonpress` en análisis de self-trigger.

## Efectos secundarios

- Lee y puede extraer/eliminar archivos temporales.
- Abre numerosas figuras y modifica ejes/handles.
- Guarda figuras, `.mat` de configuración y resultados ROC.
- Puede ejecutar procesos externos e interfaz Python a través de dependencias.
- Modifica RNG global mediante [[calculateMedianPedestal]].

## Supuestos físicos, unidades y dimensiones

- Sample rate recurrente de 62.5 MHz (`Tm = 16 ns`) para datos DAPHNE; la rama de osciloscopio toma `Resolution` del header.
- Waveforms organizados como filas por evento y columnas por muestra.
- Amplitudes tratadas generalmente como cuentas ADC/ADU.
- Integrales combinan amplitud y tiempo; algunas variables usan valores del orden `e-10`, mientras ramas manuales usan escalas distintas, por lo que las unidades deben confirmarse.
- La separación entre gaussianas se interpreta como ganancia/señal de 1 PE y se usa para SNR.

## Riesgos y limitaciones

1. **Reproducibilidad:** configuración, rutas y flags están embebidos en el Live Script.
2. **Estado implícito:** ejecutar celdas fuera de orden puede reutilizar variables antiguas o dejar variables indefinidas.
3. **Carga incondicional de estado:** dos archivos `.mat` y `spe_model` se cargan sin condicionar la operación a los flags de filtrado; `load` sin lista de variables puede sobrescribir valores del workspace.
4. **Rama CSV incompleta:** la rama activa de CSV no inicializa `data_trigger`, pero bloques posteriores la indexan durante el filtrado por RMS.
5. **Desalineación de eventos:** `integral = integral(integral ~= 0)` elimina elementos sin aplicar la misma máscara a waveforms, pedestales o triggers; puede romper la correspondencia evento–resultado.
6. **Supuestos de fitting:** el modo automático accede a `peak_position(2)` y divide por ese valor sin comprobar que exista o sea distinto de cero.
7. **Índices sin límites:** ventanas alrededor de máximos, trigger e integración no están protegidas contra valores fuera de `[1,N]`; la configuración observada `int_low_limit=127` e `integration_window=1000` puede superar 1024 muestras en la rama clásica.
8. **RNG repetido:** [[calculateMedianPedestal]] recibe la misma semilla dentro del loop y reinicia el RNG; se reutilizan las mismas posiciones aleatorias entre eventos.
9. **Importación binaria:** [[import_data_daphne_func]] usa una llamada `fread` con posiciones de argumentos aparentemente incompatibles con el contrato MATLAB habitual.
10. **Filtro óptimo:** además de la firma 3-versus-5 de [[f_fourier]], existe una incompatibilidad N-versus-`floor(N/2)+1` entre espectro bilateral y PSD unilateral, y la división incluye una componente DC forzada a cero.
11. **Acoplamiento:** IO, procesamiento, fitting, plotting y persistencia conviven en un único archivo.
12. **Variantes inactivas:** abundante código comentado y ramas experimentales dificultan identificar el pipeline autoritativo.
13. **Rutas locales y archivos externos:** el workflow no es portable y depende de nombres/variables contenidos en `.mat` no versionados.
14. **Dimensiones/unidades:** varios índices y ventanas están hard-coded para campañas o longitudes concretas.
15. **Side effects:** figuras y archivos pueden sobrescribirse según `save_dir`/nombres.
16. **Dependencias estáticas incompletas:** funciones dinámicas y toolboxes pueden faltar.
17. **Validación pendiente:** no existe todavía un dataset/configuración baseline documentado para comparar resultados.

## Candidatos a refactorización

Sin modificar todavía el workflow, las fronteras naturales son:

- configuración de run/setup;
- lectores por formato;
- estimación de pedestal y selección de eventos;
- filtros/matched filter;
- integración y extracción de features;
- trigger y métricas ROC;
- fitting de picos/SNR;
- plotting y exportación.

El Live Script debería conservarse como workflow narrativo/entry point, delegando gradualmente cada bloque estable a funciones del futuro namespace `+pds`.

## Evidencia y grado de certeza

- **Observado:** celdas, flags, rutas, llamadas, fórmulas, plots y operaciones de guardado presentes en el XML del `.mlx`.
- **Inferido:** relación entre bloques y objetivos científicos de caracterización DAPHNE/PDS.
- **Desconocido:** ramas realmente utilizadas hoy, datasets autoritativos, tolerancias numéricas y significado final de algunos parámetros de campaña.

## Preguntas pendientes

- ¿Qué combinación de flags representa el análisis estándar actual?
- ¿Qué run/dataset pequeño puede actuar como baseline reproducible?
- ¿Cuáles figuras y métricas son resultados científicos obligatorios?
- ¿Qué unidades corresponden a cada integral, sigma y threshold?
- ¿Cuál es la versión autoritativa de `f_fourier`?
- ¿Qué bloques son históricos y cuáles siguen activos?
- ¿Qué rutas/datos pueden convertirse en configuración versionada y cuáles deben permanecer locales?

## Enlaces

- [[analysis_daphne_data_dependencies]]
- [[MATLAB_SCRIPT_CATALOG]]
- [[DOCUMENTATION_GUIDE]]
- [[STAGED_ANALYSIS_DAPHNE_DATA]]
