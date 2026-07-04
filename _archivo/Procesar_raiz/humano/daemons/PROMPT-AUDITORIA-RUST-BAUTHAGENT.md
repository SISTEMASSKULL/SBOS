Cuando te indique "revisar", ejecuta la siguiente tarea de auditoría técnica.

0. Naturaleza del permiso — solo lectura

Esta tarea es una auditoría de solo lectura. Tienes permiso completo de lectura sobre la totalidad del árbol de directorios indicado en el punto 1, sin restricción. Esta autorización total cubre exclusivamente la lectura — no cubre escritura, modificación, ni ejecución de herramientas que alteren cualquier archivo del proyecto auditado.

Método de revisión obligatorio: la revisión debe hacerse leyendo el código línea por línea, archivo por archivo, mediante inspección directa del contenido — abriendo y leyendo cada archivo del inventario tal como lo haría un revisor humano. No está permitido usar scripts de búsqueda automatizada, herramientas de análisis estático, linters, ni código en Python, Bash u otro lenguaje para escanear, filtrar, indexar o procesar el código de forma masiva o programática. La verificación de cada criterio del punto 2 (hardcodeo, espagueti, monolítico, documentación, manejo de errores, unsafe, dependencias, tests, lint, nomenclatura, concurrencia) debe surgir de la lectura y comprensión directa de cada archivo, no de la salida de una herramienta automatizada. Esto incluye las verificaciones de linting del punto 2: en lugar de ejecutar cargo clippy o cargo fmt --check como herramienta automática, esas verificaciones también deben hacerse por lectura manual del código contra las reglas que esas herramientas aplicarían.

Bajo ninguna circunstancia debes escribir, modificar, mover, renombrar ni eliminar ningún archivo del proyecto auditado.

La única acción permitida más allá de la lectura es documentar — y únicamente bajo autorización explícita. Si en el transcurso de la auditoría identificas que sería apropiado generar o actualizar documentación (por ejemplo, completar un comentario faltante conforme al estándar DOC-SBOS-001 N3), no la generes ni la apliques directamente: regístrala como hallazgo en el informe (ver punto 6) y, por separado, solicita autorización explícita al usuario antes de redactar o aplicar cualquier documentación nueva. La autorización total de esta tarea es solo para lectura; cualquier acción de escritura, incluida la documentación, requiere pedir permiso de forma expresa y esperar confirmación antes de proceder.

Esta tarea es estrictamente de inspección y reporte. El agente no corrige, no refactoriza, no completa, ni reescribe ningún código bajo ningún concepto, sin importar cuán evidente o sencilla parezca la corrección. La única excepción posible a esta regla es la documentación del código, descrita en el párrafo anterior, y solo después de recibir autorización explícita. Todo lo demás —estructura, lógica, manejo de errores, modularización, valores hardcodeados— se limita a detectarse y describirse en el informe; nunca se modifica.

Código en desarrollo (work in progress): el proyecto está en proceso activo de desarrollo, por lo que es esperable encontrar código incompleto, funciones sin terminar, módulos parcialmente implementados, marcadores como TODO, FIXME, unimplemented!(), todo!() o similares, y secciones evidentemente en construcción. La presencia de código inconcluso, por sí sola, no constituye un hallazgo ni debe reportarse como anomalía o señal de alarma — es un estado normal y esperado del proyecto en esta etapa. El agente no debe marcar como error, ni tratar de completar, ni sugerir terminar dicho código incompleto. Lo que sí corresponde evaluar, incluso dentro de código inconcluso, es si lo que ya está escrito cumple los criterios del punto 2 (por ejemplo, si la porción ya implementada de una función incompleta contiene valores hardcodeados, o si el módulo parcial ya muestra señales de estructura monolítica o espagueti en lo que lleva construido). El criterio para reportar un hallazgo es siempre la calidad estructural del código existente, nunca el hecho de que el desarrollo no haya concluido.

El único archivo que se escribe sin necesidad de autorización adicional es el informe final descrito en el punto 6, y ese archivo debe crearse en una ubicación de salida separada del árbol auditado, nunca dentro de él. Esta tarea no corrige nada — solo detecta, documenta como hallazgo, y reporta.

1. Alcance — exploración recursiva exhaustiva, sin excepción

Raíz de exploración: /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent

La exploración debe ser recursiva y total sobre el árbol completo de directorios y subdirectorios de esa ruta, sin omitir ningún nivel de profundidad. No está permitido seleccionar archivos de forma arbitraria, muestral, ni limitarse a los archivos "principales" o "más relevantes" a criterio propio. La regla es: todo archivo dentro del árbol se revisa, salvo que esté explícitamente excluido en el punto 1.2.

1.1 — Procedimiento de iteración obligatorio

Antes de iniciar el análisis, genera primero un inventario completo de todos los archivos a revisar, mediante recorrido recursivo del árbol de directorios (equivalente a find . -type f desde la raíz indicada, respetando las exclusiones del punto 1.2). Este inventario debe:

- Listar la ruta completa de cada archivo encontrado.
- Servir como checklist de control: cada archivo del inventario debe quedar marcado como revisado al finalizar.
- Presentarse como parte del informe final, indicando el total de archivos inventariados y el total efectivamente auditado — ambos números deben coincidir.

Si algún archivo del inventario no pudo revisarse (por ejemplo, por ser binario ilegible o estar corrupto), debe quedar explícitamente listado en el informe con el motivo de la exclusión — nunca omitido en silencio.

1.2 — Exclusiones explícitas (única lista válida de exclusión)

Únicamente se excluyen del análisis los siguientes directorios y patrones, por no ser código fuente propio del proyecto:

- target/ (artefactos de compilación de Cargo)
- .git/ (metadatos de control de versiones)
- node_modules/ (si existiera, dependencias de terceros)
- Archivos binarios no legibles como texto (ejecutables, imágenes, certificados en formato binario)

Ninguna otra carpeta, subcarpeta o archivo puede excluirse por criterio propio del agente. Si surge una duda razonable sobre si algo debe excluirse, la decisión por defecto es incluirlo y señalarlo en el informe, no omitirlo.

1.3 — Cobertura por tipo de archivo

El proyecto se desarrolla principalmente en Rust pero contiene archivos de otra naturaleza que también deben auditarse, cada uno con el criterio que le corresponda:

- .rs: todos los criterios de la sección 2 (hardcodeo, espagueti, monolítico, documentación, manejo de errores, unsafe, tests)
- Cargo.toml / Cargo.lock: gestión de dependencias (ver sección 2)
- .proto: coherencia de contratos gRPC con el modelo de sagas (ver sección 3)
- .json / .yaml / .yml / .toml de configuración: ausencia de valores sensibles o de entorno hardcodeados que deberían externalizarse
- .md y demás documentación: cumplimiento del estándar DOC-SBOS-001 N3, vigencia y coherencia con el código que documentan
- Scripts (.sh, .ps1, u otros): ausencia de valores hardcodeados, claridad y modularización equivalente a la exigida en código Rust
- Cualquier otro archivo de texto no contemplado arriba: se revisa igualmente bajo el criterio más cercano de los anteriores; se documenta en el informe qué criterio se aplicó y por qué

2. Verificaciones obligatorias por archivo

- Valores hardcodeados: identifica cualquier valor (credenciales, URLs, puertos, rutas, timeouts, límites numéricos, claves, IDs) embebido directamente en el código en lugar de provenir de configuración, variables de entorno, o parámetros.
- Código espagueti: detecta flujos de control enredados, anidamientos excesivos, dependencias cruzadas no explícitas entre funciones, y lógica difícil de seguir linealmente.
- Código monolítico: identifica funciones, módulos o archivos que concentran múltiples responsabilidades y deberían descomponerse según el principio de responsabilidad única.
- Modularización: confirma que el código esté organizado en módulos coherentes, con interfaces claras y bajo acoplamiento entre componentes.
- Documentación: verifica que todo el código (módulos, funciones, parámetros, structs, traits, errores) cumpla el estándar DOC-SBOS-001 N3, con comentarios de documentación en español (/// y //! según corresponda).
- Manejo de errores idiomático en Rust: confirma uso correcto de Result/Option, ausencia de .unwrap() o .expect() no justificados en rutas de producción, y propagación de errores mediante ? o tipos de error personalizados en lugar de panic! evitable.
- Uso de unsafe: localiza todo bloque unsafe y verifica que esté justificado, acotado al mínimo necesario, y documentado explicando por qué es seguro en ese contexto.
- Gestión de dependencias: revisa Cargo.toml en busca de versiones no fijadas innecesariamente, dependencias no utilizadas, o crates sin justificación clara de uso.
- Cobertura de pruebas: verifica la existencia de tests unitarios e de integración para la lógica crítica, y que no haya lógica de negocio sin cobertura alguna.
- Linting: confirma que el código pase cargo clippy sin advertencias relevantes ignoradas sin justificación, y que siga el formateo estándar de cargo fmt.
- Consistencia de nomenclatura: verifica que nombres de variables, funciones, structs, traits y módulos sigan las convenciones estándar de Rust (snake_case, CamelCase según corresponda) y sean semánticamente claros, no abreviaturas crípticas.
- Gestión de concurrencia: si el código usa async/await, hilos, Mutex, RwLock, canales u otras primitivas de concurrencia, verifica ausencia de condiciones de carrera evidentes, interbloqueos potenciales, y uso correcto de Send/Sync.

3. Alineación arquitectónica

Verifica que la modularización del código sea coherente con el modelo de sagas del proyecto, implementado mediante gRPC y JSON-RPC, asegurando que los límites entre módulos respeten los contratos de comunicación entre servicios y no introduzcan acoplamiento directo que viole ese modelo.

4. Estándares de referencia

Toda la revisión debe alinearse con estándares y normas internacionales aplicables a desarrollo de software seguro y mantenible (por ejemplo, ISO/IEC 25010 para calidad de software, OWASP ASVS para seguridad de código, y las convenciones oficiales de la comunidad Rust — Rust API Guidelines), además del estándar interno DOC-SBOS-001 N3 (SBOS-060).

5. Manejo de incidencias durante la ejecución

Si durante la auditoría ocurre cualquier situación que impida completar una verificación específica (por ejemplo, un comando de solo lectura falla, un archivo no puede abrirse, una herramienta no está disponible en el entorno), la tarea no se interrumpe ni se cancela: el agente debe registrar la incidencia en una sección dedicada del informe final, indicando qué verificación no pudo completarse, sobre qué archivo, y el motivo exacto, y continuar con el resto del inventario. Ninguna incidencia individual exime al agente de completar el resto de la auditoría.

6. Entregable — informe en formato Markdown con fecha y hora, y evidencia de cada hallazgo

Al finalizar, genera el informe completo como archivo en formato .md, cumpliendo lo siguiente:

- Nombre de archivo: debe incluir fecha y hora de generación en formato AAAA-MM-DD_HHMM, siguiendo el patrón INFORME-AUDITORIA-BAUTHAGENT-AAAA-MM-DD_HHMM.md.
- Ubicación de salida: fuera del árbol auditado (ver punto 0) — nunca dentro de BauthAgent.
- Encabezado del documento: debe iniciar con un bloque de metadatos que incluya, como mínimo:
  - Fecha y hora exacta de inicio de la auditoría (AAAA-MM-DD HH:MM:SS).
  - Fecha y hora exacta de finalización de la auditoría (AAAA-MM-DD HH:MM:SS).
  - Duración total del proceso.
  - Ruta raíz auditada.
  - Estándar(es) de referencia aplicados (DOC-SBOS-001 N3 / SBOS-060, y los demás listados en el punto 4).
- Cuerpo del informe, en este orden:
  1. Inventario completo de archivos (punto 1.1), con conteo total inventariado vs. total auditado.
  2. Resumen ejecutivo con conteo total de hallazgos por severidad (crítico / alto / medio / bajo) y por categoría.
  3. Hallazgos por categoría (hardcodeo, espagueti, monolítico, documentación, manejo de errores, unsafe, dependencias, tests, lint, nomenclatura, concurrencia), agrupados por archivo.
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
