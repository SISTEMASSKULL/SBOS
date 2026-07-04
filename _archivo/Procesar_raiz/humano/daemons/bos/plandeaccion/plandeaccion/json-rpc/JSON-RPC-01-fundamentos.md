# Manual JSON-RPC — Parte 1: Fundamentos del Protocolo

> **Versión:** 2.0  
> **Protocolo:** JSON-RPC 1.0 / 2.0  
> **Público objetivo:** Desarrolladores que diseñan o integran aplicaciones bajo el modelo JSON-RPC  
> **Lenguajes de ejemplo:** Python, Go, Rust, PHP

---

## Tabla de Contenidos

1. [¿Qué es JSON-RPC?](#1-qué-es-json-rpc)
2. [JSON-RPC vs REST: cuándo elegir cada uno](#2-json-rpc-vs-rest-cuándo-elegir-cada-uno)
3. [Estructura del Mensaje](#3-estructura-del-mensaje)
4. [Convenciones de Nomenclatura](#4-convenciones-de-nomenclatura)
5. [Transporte HTTP](#5-transporte-http)
6. [Verificar que el servidor responde](#6-verificar-que-el-servidor-responde)

---

## 1. ¿Qué es JSON-RPC?

JSON-RPC es un protocolo de llamada a procedimientos remotos (Remote Procedure Call) que usa JSON como formato de serialización. Es deliberadamente minimalista: define solo cómo se estructura el mensaje de petición y el de respuesta, dejando libre la elección del transporte (HTTP, WebSockets, TCP, stdio).

**Principio central:** el cliente no accede a *recursos* sino que invoca *procedimientos*. En lugar de hacer un `GET /ventas/42/confirmar`, el cliente llama `model.venta.confirmar` pasando el ID como parámetro.

Esta distinción es fundamental para aplicaciones centradas en lógica de negocio: confirmar una venta es una *acción*, no la lectura de un recurso. JSON-RPC modela el mundo de acciones de forma directa.

```
Cliente                          Servidor
  │                                 │
  │  POST /rpc/                     │
  │  {"method": "venta.confirmar",  │
  │   "params": [42],               │
  │   "id": 1}                      │
  │ ──────────────────────────────► │
  │                                 │  ejecuta venta.confirmar(42)
  │  {"result": true, "error": null}│
  │ ◄────────────────────────────── │
  │                                 │
```

### Versiones del protocolo

| Versión | Diferencia clave |
|---------|-----------------|
| JSON-RPC 1.0 | `id` siempre presente; sin campo `jsonrpc` |
| JSON-RPC 2.0 | Añade `"jsonrpc": "2.0"`; notificaciones sin `id`; batch requests |

La mayoría de implementaciones robustas son compatibles con ambas versiones. Los ejemplos de este manual usan la estructura 2.0 pero omiten el campo `jsonrpc` para mayor claridad; añadirlo es trivial.

---

## 2. JSON-RPC vs REST: cuándo elegir cada uno

| Criterio | JSON-RPC | REST |
|----------|----------|------|
| Modelo mental | Acciones / procedimientos | Recursos / representaciones |
| Lógica de negocio compleja | Encaja naturalmente | Requiere verbos artificiales (`POST /confirmar`) |
| CRUD simple | Funciona pero es más verboso | Encaja naturalmente |
| Descubrimiento de API | Via `system.listMethods` | Via OpenAPI / HAL |
| Caché HTTP nativo | Limitado (todo es POST) | Total (GET es cacheable) |
| Tipado fuerte | Requiere esquemas externos | Igual |
| Interoperabilidad con browsers | Requiere CORS | Nativo |

**Regla práctica:** elige JSON-RPC cuando tu dominio está orientado a acciones secuenciales (confirmar, procesar, facturar, aprobar) y cuando múltiples tipos de clientes deben ejecutar la misma lógica de negocio sin duplicarla.

---

## 3. Estructura del Mensaje

### 3.1 Petición (Request)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "model.venta.confirmar",
  "params": [42, {"empresa": 1, "idioma": "es"}]
}
```

| Campo | Tipo | Obligatorio | Descripción |
|-------|------|-------------|-------------|
| `jsonrpc` | string | No (v1) / Sí (v2) | Versión del protocolo |
| `id` | int / string / null | Sí (salvo notificaciones) | Correlaciona petición con respuesta |
| `method` | string | Sí | Nombre del procedimiento a invocar |
| `params` | array / object | No | Argumentos del procedimiento |

**Sobre el campo `id`:** debe ser único dentro de una sesión de trabajo para que el cliente pueda correlacionar respuestas asíncronas. Un contador entero incremental es suficiente en la mayoría de los casos.

**Sobre `params`:** puede ser un array posicional (`[arg1, arg2]`) o un objeto nombrado (`{"nombre": "valor"}`). Los ejemplos de este manual usan arrays posicionales, que es el estilo más común en implementaciones maduras.

### 3.2 Respuesta exitosa (Response)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": true,
  "error": null
}
```

### 3.3 Respuesta de error (Error Response)

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": null,
  "error": {
    "code": -32600,
    "name": "UserError",
    "message": "La venta 42 ya fue confirmada.",
    "data": null
  }
}
```

El campo `error` sigue la especificación JSON-RPC 2.0 con un código numérico estándar:

| Código | Nombre estándar | Uso |
|--------|----------------|-----|
| `-32700` | Parse error | JSON malformado |
| `-32600` | Invalid Request | La petición no cumple el protocolo |
| `-32601` | Method not found | El método no existe |
| `-32602` | Invalid params | Los parámetros son incorrectos |
| `-32603` | Internal error | Error inesperado del servidor |
| `-32000` a `-32099` | Server error | Errores de aplicación personalizados |

En la práctica, muchas implementaciones añaden los campos `name` y `data` para enriquecer el error sin salirse del protocolo.

### 3.4 Notificaciones (sin respuesta)

Una petición sin `id` (o con `id: null`) es una *notificación*: el servidor la procesa pero no envía respuesta.

```json
{
  "method": "log.evento",
  "params": ["usuario_conectado", {"user": "ana"}]
}
```

Útil para telemetría, logging remoto o eventos de "dispara y olvida".

### 3.5 Batch Requests (JSON-RPC 2.0)

Se pueden enviar múltiples llamadas en un solo HTTP POST:

```json
[
  {"jsonrpc": "2.0", "id": 1, "method": "venta.buscar", "params": [[["estado", "=", "borrador"]]]},
  {"jsonrpc": "2.0", "id": 2, "method": "inventario.consultar", "params": [["prod-01", "prod-02"]]}
]
```

El servidor responde con un array de resultados, no necesariamente en el mismo orden. El `id` es el mecanismo de correlación.

---

## 4. Convenciones de Nomenclatura

Una de las decisiones más importantes en el diseño de una API JSON-RPC es el esquema de nombres de métodos. La convención recomendada usa puntos como separadores jerárquicos:

```
espacio_de_nombres.modelo.accion
```

### 4.1 Espacios de nombres estándar

| Prefijo | Propósito | Ejemplos |
|---------|-----------|---------|
| `common.*` | Operaciones de servidor y sesión | `common.server.version`, `common.auth.login` |
| `system.*` | Introspección del API | `system.listMethods`, `system.methodHelp` |
| `model.<entidad>.*` | Operaciones sobre entidades de negocio | `model.venta.create`, `model.producto.search` |
| `wizard.<flujo>.*` | Asistentes de múltiples pasos | `wizard.facturacion.execute` |
| `report.<nombre>.*` | Generación de documentos | `report.venta.execute` |

### 4.2 Acciones estándar para modelos

Todos los modelos que se expongan deben implementar las seis acciones base con estos nombres exactos:

| Acción | Descripción |
|--------|-------------|
| `create` | Crear uno o más registros |
| `read` | Leer campos de registros por ID |
| `write` | Actualizar registros |
| `delete` | Eliminar registros |
| `search` | Buscar IDs según criterios |
| `search_read` | Buscar y leer en una sola llamada |

La consistencia aquí es crítica: un desarrollador que sabe usar `model.venta.create` puede deducir `model.producto.create` sin consultar documentación adicional.

### 4.3 Acciones de transición de estado

Los métodos que avanzan el ciclo de vida de un registro se nombran con el verbo de la transición en infinitivo:

```
model.venta.quote       →  borrador → cotización
model.venta.confirm     →  cotización → confirmada
model.venta.process     →  confirmada → en proceso
model.venta.cancel      →  cualquier estado activo → cancelada
```

---

## 5. Transporte HTTP

JSON-RPC es agnóstico al transporte, pero HTTP es el más común. La convención es:

- **Método HTTP:** siempre `POST`
- **Content-Type:** `application/json`
- **URL:** un endpoint único, usualmente `/rpc/` o `/<base_de_datos>/rpc/`
- **Autenticación:** header `Authorization` (Basic, Bearer o esquema propio)

```
POST /rpc/ HTTP/1.1
Host: api.miapp.com
Content-Type: application/json
Authorization: Basic <credenciales_en_base64>

{"id": 1, "method": "model.venta.search", "params": [...]}
```

La respuesta siempre tiene código HTTP 200, incluso en errores de negocio (el error va en el cuerpo JSON). Solo se usan códigos HTTP para errores de infraestructura:

| Código HTTP | Cuándo |
|-------------|--------|
| 200 | Siempre (éxito y errores de negocio) |
| 401 | Sesión inválida o expirada |
| 404 | El endpoint `/rpc/` no existe |
| 500 | Error de infraestructura del servidor |

### CORS para clientes web

Si la API será consumida desde un navegador, el servidor debe responder a las peticiones OPTIONS con los headers correctos:

```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

---

## 6. Verificar que el servidor responde

El método `common.server.version` es el "ping" estándar de una API JSON-RPC. No requiere autenticación y devuelve la versión del servidor:

```bash
curl -X POST https://api.miapp.com/rpc/ \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "method": "common.server.version", "params": []}'
```

Respuesta esperada:

```json
{
  "id": 1,
  "result": "2.1.0",
  "error": null
}
```

Si el servidor responde correctamente a esta llamada, el transporte está funcionando. Todos los demás problemas serán de autenticación o lógica de negocio.

---

*Continúa en la Parte 2: Autenticación y Gestión de Sesiones.*

---

## Índice de todos los documentos del manual

| Documento | Contenido |
|-----------|-----------|
| `JSON-RPC-01-fundamentos.md` | Qué es JSON-RPC, estructura del mensaje, convenciones, transporte HTTP |
| `JSON-RPC-02-autenticacion.md` | Login, tokens, headers de autorización, logout, implementaciones en 4 lenguajes |
| `JSON-RPC-03-crud-contexto.md` | Contexto de ejecución, create/read/write/delete/search, relaciones, ejemplos en 4 lenguajes |
| `JSON-RPC-04-cadena-eventos.md` | Eslabones, máquinas de estado, flujo completo de venta, wizards, reportes |
| `JSON-RPC-05-arquitectura-servidor.md` | Motor de dominio, capas, dispatcher, registro de métodos, servidores en 4 lenguajes |
| `JSON-RPC-06-errores-produccion.md` | Tipos de error, manejo por lenguaje, reintentos, seguridad, logging, checklist |
| `JSON-RPC-07-arquitectura-hibrida-integraciones.md` | Arquitectura híbrida, patrón adaptador, archivos binarios, integración SIAT Bolivia |
| `JSON-RPC-08-ecosistema-y-estrategia-de-adopcion.md` | Filosofía de ecosistema, motores puros, Tryton nativo, apps nuevas, Fachada-RPC para legados |
| `JSON-RPC-09-orquestacion-multi-motor.md` | Motor de orquestación, flujos multi-motor, saga con compensación, contexto distribuido, 4 lenguajes |

---

*Manual JSON-RPC — Diseño, Implementación e Integración*  
*Versión 2.0 — Aplicable a cualquier sistema que adopte JSON-RPC como protocolo de comunicación*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
