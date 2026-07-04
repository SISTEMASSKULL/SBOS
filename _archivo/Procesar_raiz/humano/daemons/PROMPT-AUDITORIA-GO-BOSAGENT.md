Cuando te indique "revisar", ejecuta la siguiente tarea de auditoría técnica.

0. Naturaleza del permiso — solo lectura

Esta tarea es una auditoría de solo lectura. Tienes permiso completo de lectura sobre la totalidad del árbol de directorios indicado en el punto 1, sin restricción. Esta autorización total cubre exclusivamente la lectura — no cubre escritura, modificación, ni ejecución de herramientas que alteren cualquier archivo del proyecto auditado.

Método de revisión obligatorio: la revisión debe hacerse leyendo el código línea por línea, archivo por archivo, mediante inspección directa del contenido — abriendo y leyendo cada archivo del inventario tal como lo haría un revisor humano. No está permitido usar scripts de búsqueda automatizada, herramientas de análisis estático, linters, ni código en Python, Bash u otro lenguaje para escanear, filtrar, indexar o procesar el código de forma masiva o programática. La verificación de cada criterio del punto 2 (hardcodeo, espagueti, monolítico, documentación, manejo de errores, dependencias, tests, lint, nomenclatura, concurrencia) debe surgir de la lectura y comprensión directa de cada archivo, no de la salida de una herramienta automatizada. Esto incluye las verificaciones de linting del punto 2: en lugar de ejecutar go vet, golangci-lint o gofmt -l como herramienta automática, esas verificaciones también deben hacerse por lectura manual del código contra las reglas que esas herramientas aplicarían.

Bajo ninguna circunstancia debes escribir, modificar, mover, renombrar ni eliminar ningún archivo del proyecto auditado.

La única acción permitida más allá de la lectura es documentar — y únicamente bajo autorización explícita. Si en el transcurso de la auditoría identificas que sería apropiado generar o actualizar documentación (por ejemplo, completar un comentario faltante conforme al estándar DOC-SBOS-001 N3), no la generes ni la apliques directamente: regístrala como hallazgo en el informe (ver punto 6) y, por separado, solicita autorización explícita al usuario antes de redactar o aplicar cualquier documentación nueva. La autorización total de esta tarea es solo para lectura; cualquier acción de escritura, incluida la documentación, requiere pedir permiso de forma expresa y esperar confirmación antes de proceder.

Esta tarea es estrictamente de inspección y reporte. El agente no corrige, no refactoriza, no completa, ni reescribe ningún código bajo ningún concepto, sin importar cuán evidente o sencilla parezca la corrección. La única excepción posible a esta regla es la documentación del código, descrita en el párrafo anterior, y solo después de recibir autorización explícita. Todo lo demás —estructura, lógica, manejo de errores, modularización, valores hardcodeados— se limita a detectarse y describirse en el informe; nunca se modifica.

Código en desarrollo (work in progress): el proyecto está en proceso activo de desarrollo, por lo que es esperable encontrar código incompleto, funciones sin terminar, paquetes parcialmente implementados, marcadores como TODO, FIXME, panic("not implemented") o similares, y secciones evidentemente en construcción. La presencia de código inconcluso, por sí sola, no constituye un hallazgo ni debe reportarse como anomalía o señal de alarma — es un estado normal y esperado del proyecto en esta etapa. El agente no debe marcar como error, ni tratar de completar, ni sugerir terminar dicho código incompleto. Lo que sí corresponde evaluar, incluso dentro de código inconcluso, es si lo que ya está escrito cumple los criterios del punto 2 (por ejemplo, si la porción ya implementada de una función incompleta contiene valores hardcodeados, o si el paquete parcial ya muestra señales de estructura monolítica o espagueti en lo que lleva construido). El criterio para reportar un hallazgo es siempre la calidad estructural del código existente, nunca el hecho de que el desarrollo no haya concluido.

El único archivo que se escribe sin necesidad de autorización adicional es el informe final descrito en el punto 6, y ese archivo debe crearse en una ubicación de salida separada del árbol auditado, nunca dentro de él. Esta tarea no corrige nada — solo detecta, documenta como hallazgo, y reporta.

1. Alcance — exploración recursiva exhaustiva, sin excepción

Raíz de exploración: /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent

La exploración debe ser recursiva y total sobre el árbol completo de directorios y subdirectorios de esa ruta, sin omitir ningún nivel de profundidad. No está permitido seleccionar archivos de forma arbitraria, muestral, ni limitarse a los archivos "principales" o "más relevantes" a criterio propio. La regla es: todo archivo dentro del árbol se revisa, salvo que esté explícitamente excluido en el punto 1.2.

1.1 — Procedimiento de iteración obligatorio

Antes de iniciar el análisis, genera primero un inventario completo de todos los archivos a revisar, mediante recorrido recursivo del árbol de directorios (equivalente a find . -type f desde la raíz indicada, respetando las exclusiones del punto 1.2). Este inventario debe:

- Listar la ruta completa de cada archivo encontrado.
- Servir como checklist de control: cada archivo del inventario debe quedar marcado como revisado al finalizar.
- Presentarse como parte del informe final, indicando el total de archivos inventariados y el total efectivamente auditado — ambos números deben coincidir.

Si algún archivo del inventario no pudo revisarse (por ejemplo, por ser binario ilegible o estar corrupto), debe quedar explícitamente listado en el informe con el motivo de la exclusión — nunca omitido en silencio.

1.2 — Exclusiones explícitas (única lista válida de exclusión)

Únicamente se excluyen del análisis los siguientes directorios y patrones, por no ser código fuente propio del proyecto:

- vendor/ (dependencias vendorizadas de terceros)
- bin/ y dist/ (binarios compilados y artefactos de build)
- .git/ (metadatos de control de versiones)
- node_modules/ (si existiera, dependencias de terceros)
- Archivos binarios no legibles como texto (ejecutables, imágenes, certificados en formato binario)

Ninguna otra carpeta, subcarpeta o archivo puede excluirse por criterio propio del agente. Si surge una duda razonable sobre si algo debe excluirse, la decisión por defecto es incluirlo y señalarlo en el informe, no omitirlo.

1.3 — Cobertura por tipo de archivo

El proyecto se desarrolla principalmente en Go pero contiene archivos de otra naturaleza que también deben auditarse, cada uno con el criterio que le corresponda:

- .go: todos los criterios de la sección 2 (hardcodeo, espagueti, monolítico, documentación, manejo de errores, concurrencia, tests)
- go.mod / go.sum: gestión de dependencias (ver sección 2)
- .proto: coherencia de contratos gRPC con el modelo de sagas (ver sección 3)
- .json / .yaml / .yml / .toml de configuración: ausencia de valores sensibles o de entorno hardcodeados que deberían externalizarse
- .md y demás documentación: cumplimiento del estándar DOC-SBOS-001 N3, vigencia y coherencia con el código que documentan
- Scripts (.sh, .ps1, u otros) y Makefile: ausencia de valores hardcodeados, claridad y modularización equivalente a la exigida en código Go
- Cualquier otro archivo de texto no contemplado arriba: se revisa igualmente bajo el criterio más cercano de los anteriores; se documenta en el informe qué criterio se aplicó y por qué

2. Verificaciones obligatorias por archivo

- Valores hardcodeados: identifica cualquier valor (credenciales, URLs, puertos, rutas, timeouts, límites numéricos, claves, IDs) embebido directamente en el código en lugar de provenir de configuración, variables de entorno, o parámetros.
- Código espagueti: detecta flujos de control enredados, anidamientos excesivos, dependencias cruzadas no explícitas entre funciones, y lógica difícil de seguir linealmente.
- Código monolítico: identifica funciones, paquetes o archivos que concentran múltiples responsabilidades y deberían descomponerse según el principio de responsabilidad única.
- Modularización: confirma que el código esté organizado en paquetes coherentes, con interfaces claras, bajo acoplamiento entre componentes, y respeto a los límites de visibilidad de Go (identificadores exportados con mayúscula inicial usados solo cuando es necesario; uso apropiado de paquetes internal/ para restringir alcance).
- Documentación: verifica que todo el código (paquetes, funciones, parámetros, structs, interfaces, errores) cumpla el estándar DOC-SBOS-001 N3, con comentarios de documentación en español siguiendo la convención de Go (comentario inmediatamente antes de la declaración, iniciando con el nombre del elemento documentado), compatible con godoc.
- Manejo de errores idiomático en Go: confirma que los errores se manejen explícitamente y no se descarten con el operador blank identifier (_) de forma injustificada; verifica uso apropiado de errors.Is, errors.As y fmt.Errorf con %w para envolver errores; ausencia de panic() no justificado en rutas de producción (panic() solo debería usarse en condiciones verdaderamente irrecuperables); verifica que las funciones que pueden fallar retornen error como último valor, conforme a la convención del lenguaje.
- Gestión de dependencias: revisa go.mod en busca de versiones no fijadas innecesariamente, dependencias no utilizadas (go.sum desincronizado con go.mod), o módulos sin justificación clara de uso; verifica si el proyecto declara correctamente su versión mínima de Go requerida.
- Cobertura de pruebas: verifica la existencia de tests unitarios e de integración (archivos _test.go) para la lógica crítica, uso apropiado de table-driven tests donde corresponda, y que no haya lógica de negocio sin cobertura alguna.
- Linting: confirma que el código pase go vet, golangci-lint y gofmt sin advertencias relevantes ignoradas sin justificación.
- Consistencia de nomenclatura: verifica que nombres de variables, funciones, structs, interfaces y paquetes sigan las convenciones estándar de Go (MixedCaps o mixedCaps, nunca snake_case; nombres de paquete cortos, en minúsculas, sin guiones bajos; receptores de método consistentes y cortos) y sean semánticamente claros, no abreviaturas crípticas.
- Gestión de concurrencia: si el código usa goroutines, channels, sync.Mutex, sync.RWMutex, sync.WaitGroup u otras primitivas de concurrencia, verifica ausencia de condiciones de carrera evidentes, fugas de goroutines (goroutines que nunca terminan o cuyo canal nunca se cierra), interbloqueos potenciales, y uso correcto de context.Context para cancelación y propagación de límites de tiempo.

3. Alineación arquitectónica

Verifica que la modularización del código sea coherente con el modelo de sagas del proyecto, implementado mediante gRPC y JSON-RPC, asegurando que los límites entre paquetes respeten los contratos de comunicación entre servicios y no introduzcan acoplamiento directo que viole ese modelo.

4. Estándares de referencia

Toda la revisión debe alinearse con estándares y normas internacionales aplicables a desarrollo de software seguro y mantenible (por ejemplo, ISO/IEC 25010 para calidad de software, OWASP ASVS para seguridad de código, y las convenciones oficiales del lenguaje — Effective Go y Go Code Review Comments), además del estándar interno DOC-SBOS-001 N3 (SBOS-060).

5. Manejo de incidencias durante la ejecución

Si durante la auditoría ocurre cualquier situación que impida completar una verificación específica (por ejemplo, un comando de solo lectura falla, un archivo no puede abrirse, una herramienta no está disponible en el entorno), la tarea no se interrumpe ni se cancela: el agente debe registrar la incidencia en una sección dedicada del informe final, indicando qué verificación no pudo completarse, sobre qué archivo, y el motivo exacto, y continuar con el resto del inventario. Ninguna incidencia individual exime al agente de completar el resto de la auditoría.

6. Entregable — informe en formato Markdown con fecha y hora, y evidencia de cada hallazgo

Al finalizar, genera el informe completo como archivo en formato .md, cumpliendo lo siguiente:

- Nombre de archivo: debe incluir fecha y hora de generación en formato AAAA-MM-DD_HHMM, siguiendo el patrón INFORME-AUDITORIA-BOSAGENT-AAAA-MM-DD_HHMM.md.
- Ubicación de salida: fuera del árbol auditado (ver punto 0) — nunca dentro de BosAgent.
- Encabezado del documento: debe iniciar con un bloque de metadatos que incluya, como mínimo:
  - Fecha y hora exacta de inicio de la auditoría (AAAA-MM-DD HH:MM:SS).
  - Fecha y hora exacta de finalización de la auditoría (AAAA-MM-DD HH:MM:SS).
  - Duración total del proceso.
  - Ruta raíz auditada.
  - Estándar(es) de referencia aplicados (DOC-SBOS-001 N3 / SBOS-060, y los demás listados en el punto 4).
- Cuerpo del informe, en este orden:
  1. Inventario completo de archivos (punto 1.1), con conteo total inventariado vs. total auditado.
  2. Resumen ejecutivo con conteo total de hallazgos por severidad (crítico / alto / medio / bajo) y por categoría.
  3. Hallazgos por categoría (hardcodeo, espagueti, monolítico, documentación, manejo de errores, dependencias, tests, lint, nomenclatura, concurrencia), agrupados por archivo.
  4. Evidencia obligatoria por cada hallazgo — cada hallazgo individual debe presentarse con el siguiente formato fijo, sin excepción:
     - Archivo y línea: ruta completa del archivo y número de línea exacto donde se detectó el problema.
     - Categoría: a cuál de las verificaciones del punto 2 corresponde.
     - Severidad: crítico / alto / medio / bajo.
     - Fragmento de código: el bloque de código real donde se detectó el error, transcrito tal cual aparece en el archivo (con unas pocas líneas de contexto antes y después, no solo la línea aislada), presentado en bloque de código con resaltado de sintaxis correspondiente al tipo de archivo — esto sirve como prueba verificable del hallazgo, de forma que cualquier persona pueda confirmar el problema sin tener que abrir el archivo original.
     - Explicación del problema: por qué ese fragmento específico constituye una violación del estándar o de las buenas prácticas evaluadas.
     - Recomendación de corrección: cambio concreto sugerido para resolverlo.
  5. Incidencias de ejecución (punto 5), si las hubo.
  6. Lista de archivos excluidos del análisis (si los hubo) con su motivo, conforme al punto 1.1.
- Pie del documento: debe repetir la fecha y hora de generación del informe, a modo de marca de tiempo de cierre, para permitir trazabilidad entre distintas ejecuciones de la auditoría a lo largo del tiempo.
