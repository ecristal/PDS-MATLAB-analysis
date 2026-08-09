---
type: matlab-function
status: repository-utility
review_status: reviewed-static
review_mode: static
repo_path: setupPDSAnalysisPath.m
source_path: repository-created
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, path, setup, repository]
---

# setupPDSAnalysisPath

## Descripción cualitativa

Función de bootstrap creada para añadir al MATLABPATH únicamente las carpetas staged necesarias para el workflow principal, evitando un `genpath` indiscriminado del repositorio.

## Firma

```matlab
function addedPaths = setupPDSAnalysisPath()
```

## Comportamiento

1. Deriva la raíz desde `mfilename('fullpath')`.
2. Construye rutas para el Live Script, helpers `src/data`, helpers `src/daphne` y dependencia FIUNA.
3. Verifica cada directorio con `isfolder`.
4. Emite warning si falta alguno.
5. Ejecuta `addpath` y devuelve las rutas añadidas como vector de strings.
6. Imprime el número de directorios configurados.

## Efectos secundarios

Modifica el path de la sesión MATLAB y escribe feedback en consola. No usa `savepath`, por lo que no persiste el cambio globalmente.

## Riesgos y limitaciones

- Las carpetas están enumeradas manualmente y deben actualizarse cuando se agreguen nuevas áreas de código.
- No detecta colisiones de nombres ni informa precedencia existente.
- No restaura el path previo.

## Destino provisional en el paquete

Mantener en la raíz como bootstrap explícito mientras se adopta una estructura de MATLAB Project o namespace `+pds`.

## Evidencia y grado de certeza

- **Observado:** lista explícita, `addpath`, warnings y retorno.
- **Inferido:** evita exponer tests, inventarios y código experimental.
- **Desconocido:** si en el futuro será reemplazada por un archivo `.prj`.

## Preguntas pendientes

- ¿Se utilizará MATLAB Project para gestionar path/dependencias?
- ¿Debe comprobar shadowing mediante `which -all` en una futura validación autorizada?

## Enlaces

- [[analysis_daphne_data]]
- [[STAGED_ANALYSIS_DAPHNE_DATA]]
- [[DOCUMENTATION_GUIDE]]
