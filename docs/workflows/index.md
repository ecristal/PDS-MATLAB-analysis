---
title: Guías de análisis
---

## Preparar MATLAB {#preparar-matlab}

Con la raíz del repositorio como carpeta actual de MATLAB, ejecuta:

```matlab
setupPDSAnalysisPath;
```

El comando agrega al path los directorios necesarios para usar las APIs de la [referencia MATLAB](../functions/index.md).

## Compilar la documentación {#compilar-la-documentacion}

Instala [Quarto CLI](https://quarto.org/docs/download/) y abre una terminal en la raíz del repositorio. El sitio se compiló con Quarto 1.11.9 en Windows. Comprueba tu versión y abre la vista previa local:

```powershell
quarto --version
quarto preview
```

Detén la vista previa con `Ctrl+C`. Para generar el sitio estático, ejecuta:

```powershell
quarto render
```

El sitio se genera en `outputs/docs-html/`. La lista de páginas se define en `project.render` dentro de `_quarto.yml`. La compilación de estas páginas requiere Quarto CLI.
