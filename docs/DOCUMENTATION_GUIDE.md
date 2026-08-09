---
type: documentation-guide
status: active
tags:
  - documentation
  - obsidian
  - matlab
---

# Guía de documentación

## Propósito

Este repositorio utiliza Markdown estándar compatible con Obsidian. Las notas viven junto al código para que la documentación, el inventario y las decisiones evolucionen bajo control de versiones.

## Capas documentales

1. `inventory/MATLAB_FILES.md`: inventario automático; no se edita manualmente.
2. `docs/catalog/MATLAB_SCRIPT_CATALOG.md`: catálogo cualitativo y estado de revisión.
3. `docs/workflows/`: workflows científicos y sus etapas.
4. `docs/functions/`: una ficha por función o script MATLAB staged.
5. `docs/dependency-maps/`: relaciones estáticas entre workflows y funciones.
6. `docs/decisions/`: decisiones futuras sobre arquitectura y migración.

## Convención de evidencia

- **Observado:** está expresado directamente en el código o manifiesto.
- **Inferido:** interpretación razonable pendiente de confirmación científica.
- **Desconocido:** no puede establecerse mediante revisión estática.

La documentación inicial no implica que el código haya sido ejecutado ni validado numéricamente.

## Estados documentales

- `legacy-reference`: workflow o código histórico conservado como referencia.
- `dependency`: dependencia staged del workflow principal.
- `external-dependency`: dependencia con procedencia externa al árbol original del análisis.
- `reviewed-static`: revisión estática completada.
- `runtime-validation-pending`: requiere una futura ejecución autorizada.
- `refactor-candidate`: posible candidato, no decisión definitiva, para extracción o mejora.

## Reglas de nomenclatura y enlaces

- Los nombres de las notas siguen el nombre del archivo MATLAB sin extensión.
- Los enlaces internos usan Wikilinks: `[[analysis_daphne_data]]`.
- Las rutas de código se escriben relativas a la raíz del repositorio.
- Cada ficha enlaza el workflow que la utiliza y el mapa de dependencias correspondiente.
- Las fichas no duplican el archivo fuente ni sustituyen su ayuda MATLAB.

## Reglas para la revisión

1. No ejecutar MATLAB durante la revisión estática.
2. No modificar los archivos staged al documentarlos.
3. Registrar rutas hard-coded, efectos secundarios y estado implícito.
4. Anotar dimensiones, unidades y convenciones solamente cuando sean observables; de lo contrario, marcarlas como inferidas o desconocidas.
5. Separar defectos aparentes de decisiones científicas todavía no confirmadas.
6. Mantener preguntas pendientes para revisión con el autor y futura validación.
7. Actualizar el catálogo cuando cambie el estado de una ficha.

## Configuración de Obsidian

Puede abrirse la raíz `PDS-MATLAB-analysis` como vault. La carpeta local `.obsidian/` está ignorada por Git para no versionar preferencias de interfaz o workspace.
