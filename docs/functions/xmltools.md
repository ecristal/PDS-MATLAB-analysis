---
type: matlab-function
status: external-dependency
review_status: reviewed-static
review_mode: static
repo_path: src/data/xmltools.m
source_path: Scripts_analisis/data/xmltools.m
workflow:
  - "[[analysis_daphne_data]]"
tags: [matlab, xml, parser, third-party]
---

# xmltools

## Descripción cualitativa

Parser/escritor XML genérico que representa nodos como estructuras MATLAB con `tag`, `value`, `attribs` y `child`. [[readBinaryDataRSOsc]] lo usa para leer metadatos del osciloscopio.

## Firma

```matlab
function z = xmltools(arg, out_file, varargin)
```

## Procedencia

El encabezado declara autoría de Charles-Albert Lehalle, versión 2.5, fechas marzo–septiembre de 2003 y proyecto “File parsing”. Aunque la copia estaba en `Scripts_analisis/data`, debe tratarse como código de terceros hasta revisar su licencia/origen.

## Modos observados

- `xmltools('filename.xml')`: lee y parsea XML.
- `xmltools(z,'filename.xml')`: escribe una estructura a XML.
- `xmltools(z,'get',...)` y `get-attrib`: consulta subconjuntos.
- Incluye rutinas locales para parsear tags/atributos, escapar valores, recorrer hijos y serializar.

## Dependencias y efectos secundarios

Usa IO de archivos o stdout. Puede leer XML y escribir XML según los argumentos.

## Supuestos, unidades y dimensiones

No maneja magnitudes físicas. El modelo XML es una estructura recursiva propia y preserva orden de hijos/atributos.

## Riesgos y limitaciones

- Código antiguo que usa `isstr` y un parser manual en lugar de APIs XML modernas.
- La firma multimodo y los argumentos posicionales dificultan validación.
- La compatibilidad con namespaces, encoding, CDATA, entidades y XML moderno debe confirmarse.
- Su índice posicional es consumido de forma frágil por [[readBinaryDataRSOsc]].
- Procedencia/licencia no están documentadas en el repositorio actual.
- No debe refactorizarse como si fuese código propio antes de resolver attribution/licencia.

## Destino provisional en el paquete

Mantener aislado como `external/` o reemplazar por `xmlread`/DOM/u otro parser mantenido. No incorporarlo directamente al namespace PDS sin decisión de licencia.

## Evidencia y grado de certeza

- **Observado:** encabezado de autor/versión y modos de lectura/escritura/consulta.
- **Inferido:** dependencia legacy de terceros copiada por necesidad instrumental.
- **Desconocido:** URL/licencia exacta, cobertura de XML y modificaciones locales.

## Preguntas pendientes

- ¿De dónde se descargó y bajo qué licencia?
- ¿Fue modificado respecto de la versión 2.5 original?
- ¿Puede sustituirse únicamente para el schema de R&S?

## Enlaces

- [[readBinaryDataRSOsc]]
- [[analysis_daphne_data]]
- [[analysis_daphne_data_dependencies]]
