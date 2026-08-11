---
type: matlab-script-catalog
status: active
review_mode: static
workflow:
  - "[[analysis_daphne_data]]"
tags: [catalog, matlab, inventory, pds, daphne]
---

# MATLAB Script Catalog

## Alcance

Catálogo cualitativo de los archivos MATLAB incluidos en el primer commit y relacionados con `analysis_daphne_data.mlx`. Complementa el inventario automático; no sustituye `inventory/MATLAB_FILES.md`.

La mayor parte del catálogo corresponde todavía a revisión estática. El conjunto `f_fourier`/`computeSpectrum`/`plotSpectrum` y la configuración de path cuentan además con validación runtime mediante MATLAB R2025b; el estado se indica por elemento.

## Catálogo

| Archivo | Tipo/rol | Descripción cualitativa | Estado | Destino provisional | Nota |
|---|---|---|---|---|---|
| `legacy/live-scripts/analysis_daphne_data.mlx` | Workflow legacy | Pipeline monolítico de ingestión, pedestal, filtrado, integración, trigger/ROC, fitting, SNR y gráficos para datos DAPHNE V2A | legacy-reference; reviewed-static | Conservar como entry point y extraer funciones gradualmente | [[analysis_daphne_data]] |
| `setupPDSAnalysisPath.m` | Utilidad del repositorio | Añade explícitamente API `+pds`, helpers staged y wrapper compatible, sin exponer la implementación legacy | repository-utility; tested-runtime | Bootstrap raíz o futura configuración MATLAB Project | [[setupPDSAnalysisPath]] |
| `src/daphne/calculateMedianPedestal.m` | Preprocesamiento | Estima pedestal y cuartiles desde medias de ventanas aleatorias de pretrigger | dependency; reviewed-static | `+pds/+preprocess` | [[calculateMedianPedestal]] |
| `src/daphne/extract_and_import_DAPHNE_data.m` | IO/fachada | Gestiona `.dat`, `.gz` y `.7z`, delega decodificación y limpia temporales | dependency; reviewed-static | `+pds/+io` | [[extract_and_import_DAPHNE_data]] |
| `src/daphne/import_data_daphne_func.m` | IO/lector | Lee stream DAPHNE, forma matriz de waveforms y calcula promedio | transitive-dependency; reviewed-static | `+pds/+io` | [[import_data_daphne_func]] |
| `src/daphne/sum_fitted_data.m` | Fitting | Suma dos gaussianas normalizadas por las áreas de curvas ajustadas | dependency; reviewed-static | `+pds/+fitting` | [[sum_fitted_data]] |
| `src/data/ROC_file_analysis.m` | Métricas de trigger | Selecciona umbral por accuracy y calcula curva/área ROC y Gini | dependency; reviewed-static | `+pds/+metrics` | [[ROC_file_analysis]] |
| `src/data/find_peaks_hist_adaptive.m` | Detección de picos | Detecta picos de histograma con suavizado y separación adaptativa en dos pasadas | transitive-dependency; reviewed-static | `+pds/+signal` | [[find_peaks_hist_adaptive]] |
| `src/data/fit2SPE.m` | Fitting SPE | Ajusta shift y amplitud de la respuesta de un modelo a un waveform SPE | dependency; reviewed-static | `+pds/+fitting` | [[fit2SPE]] |
| `src/data/gaussian_fit_SNR.m` | Fitting/métrica | Ajusta picos gaussianos de integrales y deriva separación y SNR | dependency; reviewed-static | Separar `+pds/+fitting` y `+pds/+metrics` | [[gaussian_fit_SNR]] |
| `src/data/getDataFromWafflesPickleFile.m` | IO Python | Deserializa pickle waffles y extrae dos canales sincronizados | dependency; reviewed-static | `+pds/+io` o conversor externo | [[getDataFromWafflesPickleFile]] |
| `src/data/my_gaussian_fit.m` | Fitting auxiliar | Ejecuta un ajuste `gauss1` ponderado alrededor de una región | dependency; reviewed-static | `+pds/+fitting` | [[my_gaussian_fit]] |
| `src/data/optimal_filter_for_daphne_gpessina_function.m` | Filtrado | Construye un filtro óptimo espectral, opcionalmente ponderado por PSD de ruido | dependency; reviewed-static | `+pds/+filter` | [[optimal_filter_for_daphne_gpessina_function]] |
| `src/data/readBinaryDataRSOsc.m` | IO instrumental | Lee encabezado XML y waveforms binarios de osciloscopio Rohde & Schwarz | dependency; reviewed-static | `+pds/+io` | [[readBinaryDataRSOsc]] |
| `src/data/mi_dft.m` | Transformada | DFT explícita con shift de fase y estimación de PSD | transitive-dependency; reviewed-static | `+pds/+signal` o reemplazo por FFT validado | [[mi_dft]] |
| `src/data/mi_idtft.m` | Transformada | IDFT explícita usada por el filtro óptimo | transitive-dependency; reviewed-static | `+pds/+signal` o reemplazo por IFFT validado | [[mi_idtft]] |
| `src/data/xmltools.m` | Parser XML de terceros | Parser/escritor XML legacy v2.5 usado por el lector R&S | external-dependency; license-review-pending | Aislar en `external/` o reemplazar | [[xmltools]] |
| `legacy/functions/f_fourier/f_fourier.m` | Referencia legacy preservada | Implementación original FFT/PSD/RMS procedente del trabajo FIUNA; SHA-256 preservado | legacy-reference; tested-characterization | Mantener fuera del MATLABPATH; 3 tests documentan firma, DC/RMS y N impar | [[f_fourier]] |
| `src/+pds/+signal/computeSpectrum.m` | API espectral | Calcula amplitud/PSD lineales, FFT coherente media y RMS con sidedness y DC explícitos | project-api; tested-runtime | Implementación autoritativa para código nuevo | [[computeSpectrum]] |
| `src/+pds/+plotting/plotSpectrum.m` | Visualización | Presenta amplitud o PSD lineal/dB con referencia explícita sin alterar resultados | project-api; tested-runtime | Helper de visualización autoritativo | [[plotSpectrum]] |
| `src/compat/f_fourier.m` | Wrapper de compatibilidad | Acepta las firmas históricas de 2–5 argumentos, delega el cálculo en `+pds` y reproduce la rama legacy de plotting | compatibility-wrapper; tested-runtime | Retirar tras migrar consumidores | [[f_fourier]] |

## Hallazgos transversales

1. **Portabilidad:** el Live Script contiene rutas absolutas y configuración embebida.
2. **Estado implícito:** celdas, flags y workspace forman parte del contrato de ejecución.
3. **IO acoplado:** extracción, decodificación, borrado temporal y guardado están mezclados.
4. **Toolboxes:** el workflow parece depender de Signal Processing, Curve Fitting, Statistics, System Identification, Wavelet e interfaz Python; debe confirmarse más adelante.
5. **Procedencia:** `xmltools.m` requiere revisión de origen/licencia; `f_fourier` fue confirmado como código propio, adoptado bajo `+pds` y preservado como referencia legacy.
6. **Importación binaria:** la llamada a `fread` en `import_data_daphne_func` presenta un orden de argumentos aparentemente incompatible con la API habitual.
7. **Filtro óptimo:** la API espectral nueva ya soporta PSD bilateral, pero el filtro staged continúa llamando el wrapper legacy con tres argumentos y todavía necesita revisión de regularización/DC.
8. **Alineación de eventos:** el Live Script elimina integrales cero sin aplicar la misma máscara a waveforms, pedestales y triggers.
9. **Unidades:** sample rate de 62.5 MHz y ADU son recurrentes, pero integrales/umbrales y algunas ventanas necesitan confirmación explícita.
10. **Validación:** el conjunto espectral cuenta con 24 tests runtime aprobados, incluidos 3 tests sobre la referencia legacy preservada y 5 sobre el wrapper de compatibilidad; todavía no existe un run pequeño end-to-end ni un conjunto de métricas baseline del workflow completo.

## Prioridades de documentación siguiente

- Confirmar con el autor qué flags definen el workflow estándar.
- Identificar datasets y configuraciones autoritativas sin versionar datos grandes.
- Registrar unidades y convenciones de dimensión.
- Resolver procedencia y versión de dependencias externas.
- Seleccionar un baseline antes de cualquier refactorización.

## Enlaces

- [[INDEX]]
- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
- [[DOCUMENTATION_GUIDE]]
