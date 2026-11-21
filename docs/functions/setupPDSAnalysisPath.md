---
title: setupPDSAnalysisPath
type: matlab-function
status: repository-utility
review_status: tested-runtime
review_mode: [static, runtime]
repo_path: setupPDSAnalysisPath.m
source_path: repository-created
workflow:
  - "docs/workflows/analysis_daphne_data.md"
tags: [matlab, path, setup, repository, runtime-validated]
---

## Descripción cualitativa

Función de bootstrap que añade al MATLABPATH únicamente el workflow staged, la API namespaced `+pds`, los helpers seleccionados y la capa de compatibilidad. Evita `genpath` indiscriminado y mantiene la implementación legacy de `f_fourier` fuera del path.

## Firma

```matlab
function addedPaths = setupPDSAnalysisPath()
```

## Directorios añadidos

```text
legacy/live-scripts
src
src/data
src/daphne
src/compat
```

El orden de inserción deja `src/compat` con precedencia para que `f_fourier` resuelva al wrapper del repositorio y no a una copia histórica existente en el MATLABPATH del usuario.

## Comportamiento

1. Deriva la raíz mediante `mfilename('fullpath')`.
2. Construye una lista explícita de cinco directorios.
3. Verifica cada directorio con `isfolder`.
4. Emite `PDSAnalysis:MissingDirectory` si falta alguno.
5. Ejecuta `addpath` y devuelve las rutas añadidas como vector de strings.
6. Imprime el número de directorios configurados.

## Uso

Con la raíz del repositorio como carpeta actual de MATLAB:

```matlab
addedPaths = setupPDSAnalysisPath();
```

Verificación manual opcional:

```matlab
which pds.signal.computeSpectrum
which pds.plotting.plotSpectrum
which f_fourier
```

`f_fourier` debe resolver a:

`src/compat/f_fourier.m`

## Evidencia runtime

Validado en MATLAB R2025b Update 3 mediante `TestSetupPDSAnalysisPath`:

- añade `src`;
- añade `src/compat`;
- no añade la antigua carpeta `external`;
- resuelve `pds.signal.computeSpectrum` correctamente;
- resuelve `f_fourier` al wrapper compatible.

Resultado: 1/1 test aprobado.

## Efectos secundarios

Modifica el path de la sesión MATLAB y escribe feedback en consola. No usa `savepath`; el cambio no se persiste globalmente.

## Riesgos y limitaciones

- La lista es manual y debe mantenerse al agregar nuevas áreas.
- No restaura automáticamente el path previo.
- No elimina otras copias de funciones; usa precedencia de path.
- El wrapper legacy debe retirarse cuando todos los consumidores se migren.

## Enlaces

- `docs/workflows/analysis_daphne_data.md`
- `docs/STAGED_ANALYSIS_DAPHNE_DATA.md`
- [`f_fourier`](f_fourier.md)
- [`computeSpectrum`](computeSpectrum.md)
- [`plotSpectrum`](plotSpectrum.md)
- `docs/DOCUMENTATION_GUIDE.md`
