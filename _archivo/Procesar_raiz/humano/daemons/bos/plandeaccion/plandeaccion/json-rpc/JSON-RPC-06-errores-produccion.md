# Manual JSON-RPC — Parte 6: Manejo de Errores, Buenas Prácticas y Producción

> **Parte de:** Manual JSON-RPC (documento final de la serie)

---

## Tabla de Contenidos

1. [Tipos de Error](#1-tipos-de-error)
2. [Manejo de Errores en el Cliente](#2-manejo-de-errores-en-el-cliente)
3. [Reintento con Backoff Exponencial](#3-reintento-con-backoff-exponencial)
4. [Buenas Prácticas de Diseño](#4-buenas-prácticas-de-diseño)
5. [Introspección del Servidor](#5-introspección-del-servidor)
6. [Versionado y Evolución de la API](#6-versionado-y-evolución-de-la-api)
7. [Seguridad en Producción](#7-seguridad-en-producción)
8. [Logging Estructurado](#8-logging-estructurado)
9. [Lista de Verificación Completa](#9-lista-de-verificación-completa)
10. [Referencia Rápida de Métodos Estándar](#10-referencia-rápida-de-métodos-estándar)

---

## 1. Tipos de Error

### 1.1 Errores de protocolo (códigos negativos, especificación JSON-RPC 2.0)

| Código | Nombre | Cuándo se produce |
|--------|--------|-------------------|
| `-32700` | ParseError | El cuerpo de la petición no es JSON válido |
| `-32600` | InvalidRequest | La petición no tiene `method` o tiene estructura incorrecta |
| `-32601` | MethodNotFound | El método solicitado no existe en el registro |
| `-32602` | InvalidParams | Los parámetros no tienen el tipo o cantidad esperada |
| `-32603` | InternalError | Error inesperado en el servidor (bug no manejado) |

### 1.2 Errores de aplicación (rango `-32000` a `-32099`)

| Nombre sugerido | Descripción |
|----------------|-------------|
| `UserError` | Error de negocio: validación fallida, estado incorrecto, restricción |
| `UserWarning` | Advertencia que el usuario puede optar por ignorar |
| `AuthenticationError` | Credenciales inválidas al hacer login |
| `Unauthorized` | Sesión expirada o token inválido |
| `AccessDenied` | El usuario no tiene permisos para el método |
| `ConcurrencyError` | El registro fue modificado por otro proceso entre la lectura y la escritura |
| `ValidationError` | Los datos enviados no pasan la validación de esquema |

### 1.3 Errores HTTP (infraestructura)

| Código HTTP | Cuándo |
|-------------|--------|
| `200` | Siempre (éxito y errores de negocio) |
| `401` | Sesión inválida o expirada (el body también lleva el error JSON) |
| `404` | El endpoint `/rpc/` no existe en esta URL |
| `429` | Rate limiting: demasiadas peticiones |
| `500` | Error catastrófico del servidor que impidió responder JSON |

---

## 2. Manejo de Errores en el Cliente

### Python

```python
import requests
import base64

class ErrorRPC(Exception):
    def __init__(self, codigo, nombre, mensaje):
        super().__init__(mensaje)
        self.codigo  = codigo
        self.nombre  = nombre
        self.mensaje = mensaje

class ErrorNegocio(ErrorRPC):     pass  # UserError, ValidationError
class ErrorPermiso(ErrorRPC):     pass  # Unauthorized, AccessDenied
class ErrorConcurrencia(ErrorRPC): pass  # ConcurrencyError
class ErrorMetodo(ErrorRPC):      pass  # MethodNotFound

def clasificar_error(error: dict) -> ErrorRPC:
    nombre  = error.get("name", "UnknownError")
    mensaje = error.get("message", str(error))
    codigo  = error.get("code", -32000)
    if nombre in ("UserError", "ValidationError"):
        return ErrorNegocio(codigo, nombre, mensaje)
    if nombre in ("Unauthorized", "AccessDenied"):
        return ErrorPermiso(codigo, nombre, mensaje)
    if nombre == "ConcurrencyError":
        return ErrorConcurrencia(codigo, nombre, mensaje)
    if nombre == "MethodNotFound":
        return ErrorMetodo(codigo, nombre, mensaje)
    return ErrorRPC(codigo, nombre, mensaje)


def llamada_segura(url, method, params, headers, call_id=1):
    try:
        resp = requests.post(url, json={"id": call_id, "method": method, "params": params},
                             headers=headers, timeout=30)
    except requests.Timeout:
        raise TimeoutError("El servidor no respondió a tiempo.")
    except requests.ConnectionError:
        raise ConnectionError("No se puede conectar al servidor.")

    if resp.status_code == 401:
        raise ErrorPermiso(-32000, "Unauthorized", "Sesión expirada.")
    if resp.status_code != 200:
        raise ConnectionError(f"HTTP {resp.status_code}: {resp.text}")

    data = resp.json()
    if data.get("error"):
        raise clasificar_error(data["error"])

    return data["result"]


# Uso con manejo diferenciado por tipo de error
try:
    resultado = llamada_segura(URL, "model.venta.confirm", [[42]], headers)

except ErrorNegocio as e:
    print(f"Error de negocio: {e.mensaje}")
    # Mostrar al usuario, no reintentar

except ErrorConcurrencia:
    print("Conflicto. Recargando y reintentando...")
    # Recargar el registro y reintentar

except ErrorPermiso:
    print("Sesión expirada. Reautenticando...")
    # Hacer login y reintentar

except ErrorMetodo as e:
    print(f"Método no existe: {e.mensaje}")
    # Error de programación, no de usuario

except Exception as e:
    print(f"Error inesperado: {e}")
```

---

### Go

```go
package main

import (
    "encoding/json"
    "errors"
    "fmt"
)

type ErrorRPC struct {
    Codigo  int
    Nombre  string
    Mensaje string
}
func (e *ErrorRPC) Error() string { return fmt.Sprintf("[%s] %s", e.Nombre, e.Mensaje) }

var (
    ErrNegocio      = errors.New("error de negocio")
    ErrPermiso      = errors.New("error de permiso")
    ErrConcurrencia = errors.New("error de concurrencia")
    ErrMetodo       = errors.New("método no encontrado")
)

func clasificarError(rpcErr map[string]interface{}) error {
    nombre  := fmt.Sprintf("%v", rpcErr["name"])
    mensaje := fmt.Sprintf("%v", rpcErr["message"])
    codigo  := 0
    if c, ok := rpcErr["code"].(float64); ok { codigo = int(c) }

    base := &ErrorRPC{Codigo: codigo, Nombre: nombre, Mensaje: mensaje}
    switch nombre {
    case "UserError", "ValidationError":
        return fmt.Errorf("%w: %s", ErrNegocio, base)
    case "Unauthorized", "AccessDenied":
        return fmt.Errorf("%w: %s", ErrPermiso, base)
    case "ConcurrencyError":
        return fmt.Errorf("%w: %s", ErrConcurrencia, base)
    case "MethodNotFound":
        return fmt.Errorf("%w: %s", ErrMetodo, base)
    }
    return base
}

// Uso:
// err := llamarRPC(...)
// if errors.Is(err, ErrConcurrencia) { // reintentar }
// if errors.Is(err, ErrPermiso) { // reautenticar }
```

---

### Rust

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ErrorRPC {
    #[error("Error de negocio: {0}")]
    Negocio(String),
    #[error("Error de permiso: {0}")]
    Permiso(String),
    #[error("Conflicto de concurrencia: {0}")]
    Concurrencia(String),
    #[error("Método no encontrado: {0}")]
    Metodo(String),
    #[error("Error interno: {0}")]
    Interno(String),
    #[error("Error HTTP {codigo}: {mensaje}")]
    Http { codigo: u16, mensaje: String },
    #[error("Timeout de conexión")]
    Timeout,
}

fn clasificar(nombre: &str, mensaje: &str) -> ErrorRPC {
    match nombre {
        "UserError" | "ValidationError" => ErrorRPC::Negocio(mensaje.to_string()),
        "Unauthorized" | "AccessDenied" => ErrorRPC::Permiso(mensaje.to_string()),
        "ConcurrencyError"              => ErrorRPC::Concurrencia(mensaje.to_string()),
        "MethodNotFound"                => ErrorRPC::Metodo(mensaje.to_string()),
        _                               => ErrorRPC::Interno(mensaje.to_string()),
    }
}

// Uso con match:
// match resultado {
//     Err(ErrorRPC::Concurrencia(_)) => { /* reintentar */ }
//     Err(ErrorRPC::Permiso(_))      => { /* reautenticar */ }
//     Err(ErrorRPC::Negocio(msg))    => { /* mostrar al usuario */ }
//     Ok(valor) => { /* procesar */ }
// }
```

---

### PHP

```php
<?php

class ErrorRPC extends RuntimeException {
    public function __construct(
        public readonly int    $codigo,
        public readonly string $nombre,
        string                 $mensaje
    ) { parent::__construct($mensaje); }
}

class ErrorNegocio      extends ErrorRPC {}
class ErrorPermiso      extends ErrorRPC {}
class ErrorConcurrencia extends ErrorRPC {}
class ErrorMetodo       extends ErrorRPC {}

function clasificarError(array $error): ErrorRPC {
    $nombre  = $error['name']    ?? 'UnknownError';
    $mensaje = $error['message'] ?? 'Error desconocido';
    $codigo  = $error['code']    ?? -32000;

    return match(true) {
        in_array($nombre, ['UserError', 'ValidationError']) => new ErrorNegocio($codigo, $nombre, $mensaje),
        in_array($nombre, ['Unauthorized', 'AccessDenied']) => new ErrorPermiso($codigo, $nombre, $mensaje),
        $nombre === 'ConcurrencyError'                      => new ErrorConcurrencia($codigo, $nombre, $mensaje),
        $nombre === 'MethodNotFound'                        => new ErrorMetodo($codigo, $nombre, $mensaje),
        default                                             => new ErrorRPC($codigo, $nombre, $mensaje),
    };
}

// Uso:
// try {
//     $resultado = $cliente->call('model.venta.confirm', [[$id]]);
// } catch (ErrorConcurrencia $e) { /* reintentar */ }
//   catch (ErrorPermiso $e)      { /* reautenticar */ }
//   catch (ErrorNegocio $e)      { /* mostrar mensaje al usuario */ }
```

---

## 3. Reintento con Backoff Exponencial

Para errores transitorios (`ConcurrencyError`, timeouts de red), se implementa reintento automático con espera creciente:

### Python

```python
import time

def con_reintento(fn, max_intentos=3, errores_reintentables=(ErrorConcurrencia, TimeoutError)):
    for intento in range(max_intentos):
        try:
            return fn()
        except errores_reintentables as e:
            if intento == max_intentos - 1:
                raise
            espera = 2 ** intento  # 1s, 2s, 4s
            print(f"Reintentando en {espera}s (intento {intento + 1}/{max_intentos}): {e}")
            time.sleep(espera)

# Uso:
resultado = con_reintento(lambda: llamada_segura(URL, "model.venta.confirm", [[42]], headers))
```

### Go

```go
func conReintento(fn func() (interface{}, error), maxIntentos int) (interface{}, error) {
    for i := 0; i < maxIntentos; i++ {
        result, err := fn()
        if err == nil { return result, nil }
        if !errors.Is(err, ErrConcurrencia) { return nil, err }
        if i == maxIntentos-1 { return nil, err }
        time.Sleep(time.Duration(1<<i) * time.Second)
    }
    return nil, errors.New("máximo de intentos alcanzado")
}
```

---

## 4. Buenas Prácticas de Diseño

### 4.1 Gestión de sesiones

- **No crear una sesión por llamada.** Una sesión debe reutilizarse durante toda la vida útil del proceso o usuario.
- **Implementar renovación automática** al recibir `401 Unauthorized`.
- **Cerrar sesión explícitamente** cuando el proceso termine.
- **No almacenar sesiones en logs.** Los tokens son credenciales.

### 4.2 Minimizar llamadas

- Usar `search_read` en lugar de `search` + `read` por separado.
- Leer solo los campos necesarios; evitar pedir todos los campos.
- Crear múltiples registros en una sola llamada `create([datos1, datos2, ...])`.
- Usar batch requests (JSON-RPC 2.0) cuando se necesitan múltiples operaciones independientes.

### 4.3 Contexto correcto

Siempre pasar el contexto con los datos relevantes para la operación:

```json
{"language": "es_BO", "company": 1, "timezone": "America/La_Paz"}
```

El contexto incorrecto puede producir datos en el idioma equivocado, filtros de empresa incorrectos o fechas en zona horaria inválida.

### 4.4 Consistencia de nombres

El catálogo de métodos debe seguir convenciones uniformes en toda la aplicación. Si un módulo usa `crear` en español y otro usa `create` en inglés, los clientes no pueden deducir los nombres. Elegir un idioma y mantenerlo.

### 4.5 Granularidad de métodos

Un método debe hacer exactamente una cosa. Evitar métodos "navaja suiza" que hacen cosas diferentes según parámetros de control:

```
❌ model.venta.procesar_todo(accion="confirmar")
❌ model.venta.procesar_todo(accion="facturar")

✅ model.venta.confirm([ids])
✅ model.venta.generate_invoice([ids])
```

### 4.6 Validación en el servidor

**Nunca confiar exclusivamente en la validación del cliente.** El servidor debe validar todos los datos en cada llamada, independientemente de quién la origine. Las restricciones de negocio viven en el dominio, no en la interfaz.

---

## 5. Introspección del Servidor

Toda API JSON-RPC bien diseñada debe implementar métodos de introspección que permitan a los clientes descubrir las capacidades del servidor en tiempo de ejecución:

```json
{"id": 1, "method": "system.listMethods", "params": []}
```

Respuesta:

```json
{
  "id": 1,
  "result": [
    "common.auth.login",
    "common.auth.logout",
    "common.server.version",
    "model.cliente.create",
    "model.cliente.delete",
    "model.cliente.read",
    "model.cliente.search",
    "model.cliente.search_read",
    "model.cliente.write",
    "model.venta.cancel",
    "model.venta.confirm",
    "model.venta.create",
    "model.venta.process",
    "model.venta.quote",
    "model.venta.search",
    "model.venta.search_read",
    "system.listMethods",
    "system.methodHelp"
  ],
  "error": null
}
```

```json
{"id": 2, "method": "system.methodHelp",
 "params": ["model.venta.confirm"]}
```

Respuesta:

```json
{
  "id": 2,
  "result": {
    "name":        "model.venta.confirm",
    "description": "Confirma ventas en estado cotización. Transición: cotizacion → confirmada.",
    "readonly":    false,
    "permissions": ["ventas", "admin"]
  },
  "error": null
}
```

### Métodos de introspección estándar

| Método | Descripción |
|--------|-------------|
| `common.server.version` | Versión del servidor (sin autenticación) |
| `system.listMethods` | Lista completa de métodos disponibles |
| `system.methodHelp` | Descripción, permisos y firma de un método |

---

## 6. Versionado y Evolución de la API

### 6.1 Regla de compatibilidad

**Nunca eliminar ni cambiar la firma de un método existente.** Los clientes existentes dependen de esa firma. En su lugar:

- Añadir métodos nuevos con nombres nuevos.
- Deprecar métodos viejos documentando la alternativa.
- Mantener métodos obsoletos funcionando hasta el próximo ciclo de vida mayor.

### 6.2 Adiciones compatibles (no rompen clientes existentes)

- Añadir nuevos métodos al registro.
- Añadir nuevos campos opcionales a las respuestas.
- Añadir nuevos parámetros opcionales al contexto.

### 6.3 Cambios incompatibles (requieren versión nueva)

- Cambiar el tipo o significado de un parámetro existente.
- Eliminar campos de la respuesta que los clientes pueden estar leyendo.
- Cambiar el nombre de un método.

### 6.4 Versionado por espacio de nombres

Cuando un cambio incompatible es inevitable:

```
model.venta.confirm       ← v1 (mantener, no eliminar)
model.v2.venta.confirm    ← v2 con nueva firma
```

### 6.5 Detección de versión por el cliente

```python
version = cliente.call("common.server.version", [])
mayor, menor, parche = [int(x) for x in version.split(".")]

if mayor >= 2:
    resultado = cliente.call("model.v2.venta.confirm", params_v2)
else:
    resultado = cliente.call("model.venta.confirm", params_v1)
```

---

## 7. Seguridad en Producción

### 7.1 HTTPS obligatorio

Todo el tráfico JSON-RPC debe ir sobre TLS en producción. El servidor de aplicación no maneja TLS directamente; lo hace el proxy inverso:

```nginx
server {
    listen 443 ssl http2;
    server_name api.miapp.com;

    ssl_certificate     /etc/ssl/certs/miapp.crt;
    ssl_certificate_key /etc/ssl/private/miapp.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    location /rpc/ {
        proxy_pass         http://127.0.0.1:8000/rpc/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_read_timeout 120s;
        client_max_body_size 10m;
    }
}
```

### 7.2 Rate limiting

Proteger el endpoint de abuso y ataques de fuerza bruta:

```nginx
# En nginx — limitar a 60 peticiones por minuto por IP
limit_req_zone $binary_remote_addr zone=rpc:10m rate=60r/m;

location /rpc/ {
    limit_req zone=rpc burst=20 nodelay;
    proxy_pass http://127.0.0.1:8000/rpc/;
}
```

### 7.3 Credenciales en variables de entorno

```python
import os

DB_URL   = os.environ["DATABASE_URL"]
RPC_USER = os.environ["RPC_ADMIN_USER"]
RPC_PASS = os.environ["RPC_ADMIN_PASS"]
```

```bash
# .env (nunca en el repositorio)
DATABASE_URL=postgresql://localhost/miapp
RPC_ADMIN_USER=admin
RPC_ADMIN_PASS=contraseña_muy_segura
```

### 7.4 Niveles de autorización

```
Nivel 1 — Autenticación
  ¿Tiene el usuario un token válido y no expirado?
  Sin token → 401.

Nivel 2 — Permisos de método
  ¿Tiene el usuario alguno de los roles requeridos por este método?
  Sin permiso → AccessDenied.

Nivel 3 — Permisos de datos (en el dominio)
  ¿Puede este usuario ver/modificar ESTOS registros específicos?
  Un vendedor solo puede ver sus propias ventas, aunque tenga acceso al método.
  Esta lógica vive en el servicio, no en el dispatcher.
```

### 7.5 Nunca exponer stack traces

Los errores que llegan al cliente deben ser mensajes controlados, nunca trazas de pila:

```python
# INCORRECTO:
except Exception as e:
    return error_response(str(e))  # puede exponer rutas, SQL, etc.

# CORRECTO:
except Exception:
    logger.exception("Error inesperado en %s", metodo)
    return error_response("Error interno del servidor.")
```

---

## 8. Logging Estructurado

Cada llamada RPC debe registrarse con suficiente información para auditoría y debugging:

```python
import logging
import time
import json

logger = logging.getLogger("rpc")

def despachar_con_log(self, cuerpo, headers):
    inicio = time.perf_counter()
    metodo = None
    error  = None

    try:
        peticion = json.loads(cuerpo)
        metodo   = peticion.get("method")
        resultado = self._despachar_interno(peticion, headers)
        return resultado
    except Exception as e:
        error = str(e)
        raise
    finally:
        duracion_ms = round((time.perf_counter() - inicio) * 1000, 2)
        logger.info(json.dumps({
            "event":    "rpc_call",
            "method":   metodo,
            "user_id":  getattr(self, "_sesion_actual", {}).get("user_id"),
            "duration": duracion_ms,
            "error":    error,
            "success":  error is None,
        }))
```

Ejemplo de log en producción:

```json
{"event": "rpc_call", "method": "model.venta.confirm", "user_id": 7, "duration": 45.3, "error": null, "success": true}
{"event": "rpc_call", "method": "model.venta.delete",  "user_id": 3, "duration": 2.1,  "error": "Sin permisos", "success": false}
```

---

## 9. Lista de Verificación Completa

### Protocolo y Estructura

- [ ] Toda petición tiene `id`, `method` y `params`.
- [ ] El contexto es siempre el último elemento de `params`.
- [ ] Las respuestas de error tienen `code`, `name` y `message`.
- [ ] Los errores de negocio devuelven HTTP 200 (no 4xx/5xx).

### Catálogo de Métodos

- [ ] Todo modelo expuesto tiene los seis métodos base: `create`, `read`, `write`, `delete`, `search`, `search_read`.
- [ ] Las transiciones de estado tienen nombres verbales consistentes.
- [ ] Existe `system.listMethods` y `system.methodHelp`.
- [ ] Existe `common.server.version` (sin autenticación).
- [ ] Los nombres de métodos son uniformes en toda la API.

### Autenticación y Seguridad

- [ ] Ningún método de negocio es accesible sin sesión válida.
- [ ] Los tokens de sesión expiran automáticamente.
- [ ] Los tokens se invalidan explícitamente con logout.
- [ ] Los permisos se verifican en el dispatcher, no en el dominio.
- [ ] Los stack traces nunca llegan al cliente.
- [ ] Las credenciales no están en el código fuente.

### Dominio

- [ ] La lógica de negocio no importa nada de HTTP o JSON.
- [ ] Las transiciones de estado validan el estado actual antes de ejecutar.
- [ ] Los modelos pueden ser probados de forma unitaria sin servidor.
- [ ] Las validaciones del servidor son la fuente de verdad (el cliente no puede saltarlas).

### Producción

- [ ] Todo el tráfico va sobre HTTPS.
- [ ] Hay rate limiting por usuario o IP.
- [ ] Cada llamada se loguea con método, usuario, duración y resultado.
- [ ] Hay un mecanismo de reintento para errores de concurrencia y timeouts.
- [ ] El proxy inverso está configurado con timeouts adecuados.

---

## 10. Referencia Rápida de Métodos Estándar

### Métodos del sistema (sin autenticación)

| Método | Descripción |
|--------|-------------|
| `common.server.version` | Versión del servidor |
| `system.listMethods` | Lista todos los métodos disponibles |
| `common.auth.login` | Iniciar sesión → `[user_id, token]` |

### Métodos del sistema (con autenticación)

| Método | Descripción |
|--------|-------------|
| `common.auth.logout` | Invalidar la sesión actual |
| `system.methodHelp` | Descripción y permisos de un método |

### Métodos de modelos (con autenticación)

| Método | Firma resumida | Descripción |
|--------|---------------|-------------|
| `model.X.create` | `([valores])` | Crear registros → `[ids]` |
| `model.X.read` | `([ids], [campos])` | Leer campos → `[{...}]` |
| `model.X.write` | `([ids], {valores})` | Actualizar → `true` |
| `model.X.delete` | `([ids])` | Eliminar → `true` |
| `model.X.search` | `(dominio, offset, limit, order)` | Buscar → `[ids]` |
| `model.X.search_read` | `(dominio, [campos], offset, limit, order)` | Buscar y leer → `[{...}]` |
| `model.X.copy` | `([ids], {defaults})` | Duplicar → `[ids]` |
| `model.X.default_get` | `([campos])` | Valores por defecto → `{...}` |
| `model.X.fields_get` | `([campos])` | Metadatos de campos → `{...}` |
| `model.X.<accion>` | `([ids])` | Transición de estado → `true` |

### Métodos de asistentes

| Método | Descripción |
|--------|-------------|
| `wizard.X.create` | Iniciar una sesión de asistente → `{session_id}` |
| `wizard.X.execute` | Ejecutar un paso → `{campos_siguiente_paso}` |

### Métodos de reportes

| Método | Descripción |
|--------|-------------|
| `report.X.execute` | Generar documento → `{content: base64, content_type, filename}` |

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
