# Handoff para desarrollar la documentación HTML de PDS-MATLAB-analysis

## Objetivo

Generar con **Quarto** un sitio HTML estático en español a partir de las fichas y guías del repositorio. Cada ficha debe explicar cómo usar la función o clase, incluir un ejemplo MATLAB ejecutable, mostrar la gráfica que produce el ejemplo cuando corresponda y enlazar a las funciones relacionadas. La primera entrega es un piloto que se pueda compilar y revisar localmente. Sphinx queda fuera de esta fase por decisión del usuario.

## Punto de partida

- El [índice actual](INDEX.md) organiza la documentación por áreas. Las fichas de `docs/functions/` ya contienen firmas, convenciones, ejemplos y resultados de validación. `docs/workflows/` y `docs/validation/` reúnen guías de análisis y evidencia experimental.
- El inventario inicial encontró 63 archivos Markdown en `docs/`, 56 con al menos un `[[wikilink]]`. Hay enlaces en el texto y en metadatos YAML. El [formato de ficha existente](templates/MATLAB_FUNCTION_NOTE_TEMPLATE.md) sirve como base para la estructura HTML.
- Las APIs MATLAB se exponen mediante [setupPDSAnalysisPath](functions/setupPDSAnalysisPath.md). Las fichas de [DaphneWaveformReader](functions/DaphneWaveformReader.md), [computeSpectrum](functions/computeSpectrum.md) y [plotSpectrum](functions/plotSpectrum.md) ya tienen evidencia de ejecución en MATLAB R2025b. Usa los resultados documentados como referencia para la migración.
- Quarto todavía no está configurado en el repositorio y no se detectó en el `PATH` de la sesión de Windows. Verifica la instalación con `quarto --version` al iniciar el desarrollo y registra la versión probada en las instrucciones de compilación.

## Arquitectura propuesta

- Mantén `docs/` como fuente Markdown. Agrega `_quarto.yml` en la raíz y configura el tipo `website`, la navegación, la búsqueda y el resaltado de código. Usa una lista explícita de páginas para el piloto. Ubica la salida generada en `outputs/docs-html/`, bajo la carpeta que Git ya ignora.
- Define una portada con acceso rápido a las fichas y una navegación que pueda crecer por área. La estructura prevista incluye **Inicio**, **Referencia MATLAB**, **Guías de análisis** y **Validación**. En cada ficha muestra el nombre completo de la API, por ejemplo `pds.signal.computeSpectrum`, y un enlace al código fuente cuando se pueda resolver desde el sitio.
- En las fichas, usa el mismo orden para descripción, firma, entradas y salidas, ejemplo mínimo, resultado o figura y funciones relacionadas. Conserva las unidades, dimensiones, advertencias y el estado de validación de las fichas existentes. En los enlaces relacionados explica la conexión, por ejemplo «Visualizar la amplitud o PSD devuelta por `computeSpectrum`».
- Convierte los enlaces visibles de Obsidian a Markdown relativo, por ejemplo `[Visualizar el espectro](plotSpectrum.md)`. Para ampliar la migración, arma un inventario de destinos y revisa los enlaces con alias, encabezados o nombres ambiguos. Revisa por separado el YAML de cada ficha para conservar su información y normalizar las referencias que se muestran en el sitio. Si una página del piloto enlaza a una ficha de apoyo, inclúyela en la compilación o apunta a un destino existente y verificable.

## Implementación del piloto

1. **Importación por waveform.** Desarrolla la ficha de [DaphneWaveformReader](functions/DaphneWaveformReader.md) con un ejemplo que cree un `.dat` temporal de dos registros `uint16` little-endian. Abre el archivo con `SamplesPerWaveform`, lee el segundo registro por índice y recorre ambos registros con `hasNext()` y `next()`. Verifica los valores devueltos y cierra el lector. Conserva el ejemplo ColdBox como caso experimental y usa una variable `archivo` que el lector de la documentación pueda configurar. Documenta la prioridad de `SamplesPerWaveform`, `dma_format.json` y `config.txt`. Conserva la nota de 400 MB temporales y 2 MB de datos por waveform para el `.7z` original de 200 registros de un millón de muestras.
2. **Espectro con figura.** Conecta [computeSpectrum](functions/computeSpectrum.md) con [plotSpectrum](functions/plotSpectrum.md) en ambas direcciones. Parte del tono de la ficha actual, con `Fs = 62.5e6`, `N = 1024`, bin `50` y amplitud de `100 ADU`. Comprueba que el máximo del espectro unilateral aparece cerca de `3,052 MHz`. Usa `plotSpectrum` para generar la gráfica de amplitud y conserva unidades y escala explícitas. Muestra el mismo ejemplo en las dos fichas mediante una referencia al script compartido o un bloque de código incluido desde él.
3. **Figuras reproducibles.** Crea los scripts de ejemplo en `examples/docs/` y exporta las figuras desde MATLAB con `exportgraphics`. Usa SVG para las curvas y PNG para gráficos densos. Vincula las figuras desde `docs/assets/figures/` y acompáñalas con texto alternativo, unidades, pie y referencia al script. Versiona las figuras ligeras del piloto para que el sitio se pueda compilar sin MATLAB, OneDrive ni los archivos DAQ. Regenera las figuras y verifica los ejemplos en una ejecución separada con MATLAB R2025b. Usa datos sintéticos para los ejemplos principales y distingue su procedencia de los datos experimentales.

## Compilación y entrega

Desde la raíz del repositorio, documenta estos comandos una vez configurado Quarto.

```powershell
quarto --version
quarto preview
quarto render
```

Agrega instrucciones independientes para ejecutar los ejemplos y regenerar sus figuras con MATLAB. Evita rutas personales en los ejemplos, los recursos y el HTML. Usa rutas relativas al repositorio para los recursos versionados y variables configurables para los archivos locales de adquisición.

El piloto está listo para revisión cuando se cumplan estas verificaciones:

- El sitio compila desde una copia limpia con Quarto y se puede navegar y buscar en la vista previa local.
- Las tres fichas del piloto muestran descripción, ejemplo copiable y enlaces funcionales. La ficha de espectro muestra la figura generada desde el mismo código que se documenta.
- Los ejemplos de MATLAB verifican los registros esperados del `.dat` sintético y el pico del espectro. La página de importación documenta el caso sin JSON y el ciclo de vida de los archivos temporales.
- La comprobación del HTML termina sin enlaces internos, anclas ni figuras rotas. Las páginas migradas muestran los enlaces como hipervínculos y los recursos se resuelven también cuando el sitio se sirve desde un subdirectorio.
- La entrega incluye configuración, fichas, scripts, figuras e instrucciones de compilación. El directorio generado queda disponible para revisión local. El alojamiento y la publicación se deciden después de revisar el piloto.

Después de validar el piloto, migra las demás fichas por área y luego incorpora los workflows y las notas de validación que deban quedar en la navegación. Conserva sus nombres de archivo cuando sea práctico para reducir cambios de enlaces.

## Referencias de implementación

- [Proyectos web y enlaces entre páginas en Quarto](https://quarto.org/docs/websites/)
- [Figuras en Quarto](https://quarto.org/docs/authoring/figures.html)
- [Bloques de código HTML en Quarto](https://quarto.org/docs/output-formats/html-code.html)
- [Exportación de gráficas desde MATLAB](https://www.mathworks.com/help/matlab/ref/exportgraphics.html)
