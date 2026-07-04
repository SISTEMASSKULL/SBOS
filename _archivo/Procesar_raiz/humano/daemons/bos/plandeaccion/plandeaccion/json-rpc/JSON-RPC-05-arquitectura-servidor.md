# Manual JSON-RPC — Parte 5: Arquitectura del Servidor

> **Parte de:** Manual JSON-RPC  
> **Audiencia:** Arquitectos y desarrolladores que diseñan el lado servidor de una API JSON-RPC

---

## Tabla de Contenidos

1. [El Problema Arquitectónico Central](#1-el-problema-arquitectónico-central)
2. [Las Tres Capas del Servidor](#2-las-tres-capas-del-servidor)
3. [Capa de Dominio](#3-capa-de-dominio)
4. [Capa de Exposición RPC](#4-capa-de-exposición-rpc)
5. [Capa de Transporte](#5-capa-de-transporte)
6. [El Registro de Métodos](#6-el-registro-de-métodos)
7. [El Dispatcher](#7-el-dispatcher)
8. [Contexto de Ejecución](#8-contexto-de-ejecución)
9. [Estructura de Directorios de Referencia](#9-estructura-de-directorios-de-referencia)
10. [Implementaciones del Servidor](#10-implementaciones-del-servidor)

---

## 1. El Problema Arquitectónico Central

Cuando se diseña una aplicación que debe ser operada tanto desde una interfaz propia como desde sistemas externos, surge la pregunta: **¿dónde vive la lógica de negocio?**

```
❌ Opción A — Lógica en la interfaz
   La UI conoce las reglas. Los sistemas externos no pueden reutilizarlas.
   Resultado: duplicación, inconsistencias.

❌ Opción B — Lógica distribuida
   Cada punto de entrada implementa sus propias reglas.
   Resultado: divergencia, mantenimiento imposible.

✅ Opción C — Lógica en el motor central
   La lógica vive en un núcleo independiente de toda interfaz.
   Todas las interfaces consumen ese mismo motor via JSON-RPC.
   Resultado: consistencia garantizada, integraciones naturales.
```

JSON-RPC materializa la opción C: expone el motor como procedimientos invocables desde cualquier cliente, sin importar el lenguaje o la plataforma.

### El principio de paridad

**La interfaz propia no tiene privilegios especiales.** Llama al motor exactamente igual que cualquier sistema externo. Lo que funciona desde la UI funciona desde la integración. No puede existir una operación "solo disponible desde la interfaz".

```
┌─────────────────────────────────────────────────────┐
│                 MOTOR DE NEGOCIO                    │
│   Modelos │ Reglas │ Flujos │ Validaciones          │
│   No sabe nada de HTTP, UI ni de quién lo llama.    │
└─────────────────────┬───────────────────────────────┘
                      │  expuesto vía JSON-RPC
                      ▼
┌─────────────────────────────────────────────────────┐
│                  CAPA JSON-RPC                      │
│  Serialización │ Auth │ Enrutamiento │ Permisos     │
└───────┬─────────────────────────────────────┬───────┘
        │                                     │
        ▼                                     ▼
┌──────────────┐                    ┌──────────────────┐
│  UI propia   │                    │  Sistemas        │
│  (web/móvil) │                    │  externos        │
└──────────────┘                    └──────────────────┘
```

---

## 2. Las Tres Capas del Servidor

### Capa 1 — Dominio (el Motor)

- Modelos de datos y entidades del negocio
- Lógica de negocio: validaciones, transformaciones, cálculos
- Máquinas de estado: ciclo de vida de los registros
- Eventos y disparadores

Esta capa es **completamente independiente** de cualquier protocolo de comunicación. Puede ser probada de forma unitaria sin levantar ningún servidor.

### Capa 2 — Exposición RPC (el Contrato)

- Registro de métodos: qué procedimientos del dominio se exponen
- Descriptores: lectura/escritura, permisos, caché, documentación
- Adaptadores: traducen parámetros recibidos al formato del dominio
- Transformadores: convierten respuestas del dominio al formato del cliente

### Capa 3 — Transporte (la Infraestructura)

- Servidor HTTP: recibe `POST /rpc/`
- Dispatcher: analiza `method`, localiza el descriptor, ejecuta
- Serializador: JSON ↔ objetos del dominio
- Gestor de sesiones: valida tokens, vincula llamadas a usuarios
- Manejador de errores: convierte excepciones en respuestas JSON-RPC

---

## 3. Capa de Dominio

### Modelo de dominio puro

Un modelo de dominio no importa nada de HTTP ni de JSON. Es una clase ordinaria con su lógica encapsulada:

```python
# dominio/venta.py — Python puro, sin dependencias de servidor

from dataclasses import dataclass, field
from decimal import Decimal
from enum import Enum
from datetime import datetime
from typing import List, Optional


class EstadoVenta(Enum):
    BORRADOR   = "borrador"
    COTIZACION = "cotizacion"
    CONFIRMADA = "confirmada"
    EN_PROCESO = "en_proceso"
    CANCELADA  = "cancelada"


@dataclass
class LineaVenta:
    producto_id: int
    cantidad: Decimal
    precio_unit: Decimal

    @property
    def subtotal(self) -> Decimal:
        return self.cantidad * self.precio_unit


@dataclass
class Venta:
    id: Optional[int]
    cliente_id: int
    lineas: List[LineaVenta] = field(default_factory=list)
    estado: EstadoVenta = EstadoVenta.BORRADOR
    numero: Optional[str] = None

    @property
    def total(self) -> Decimal:
        return sum(l.subtotal for l in self.lineas)

    def cotizar(self):
        if self.estado != EstadoVenta.BORRADOR:
            raise ValueError(f"No se puede cotizar en estado '{self.estado.value}'")
        if not self.lineas:
            raise ValueError("Se requiere al menos una línea.")
        self.estado = EstadoVenta.COTIZACION

    def confirmar(self):
        if self.estado != EstadoVenta.COTIZACION:
            raise ValueError("Solo se confirman ventas en cotización.")
        self.numero = f"V-{datetime.now().strftime('%Y%m%d')}-{self.id:05d}"
        self.estado = EstadoVenta.CONFIRMADA

    def procesar(self):
        if self.estado != EstadoVenta.CONFIRMADA:
            raise ValueError("Solo se procesan ventas confirmadas.")
        self.estado = EstadoVenta.EN_PROCESO

    def cancelar(self):
        if self.estado == EstadoVenta.EN_PROCESO:
            raise ValueError("No se puede cancelar una venta en proceso.")
        self.estado = EstadoVenta.CANCELADA
```

### Servicios de aplicación

Los servicios orquestan operaciones que involucran múltiples modelos. Son el punto de entrada desde la capa RPC:

```python
# aplicacion/servicio_ventas.py

class ServicioVentas:
    def __init__(self, repo_ventas, repo_envios, repo_facturas):
        self.repo_ventas   = repo_ventas
        self.repo_envios   = repo_envios
        self.repo_facturas = repo_facturas

    def crear(self, valores_lista: list, ctx: dict) -> list:
        ids = []
        for valores in valores_lista:
            venta = Venta(id=None, cliente_id=valores["cliente"],
                          lineas=[LineaVenta(**l) for l in valores.get("lineas_datos", [])])
            ids.append(self.repo_ventas.guardar(venta))
        return ids

    def confirmar(self, ids: list, ctx: dict) -> bool:
        for vid in ids:
            venta = self.repo_ventas.obtener(vid)
            venta.confirmar()
            self.repo_ventas.guardar(venta)
        return True

    def procesar(self, ids: list, ctx: dict) -> bool:
        for vid in ids:
            venta = self.repo_ventas.obtener(vid)
            venta.procesar()
            self.repo_ventas.guardar(venta)
            self.repo_envios.crear_desde_venta(venta)
            self.repo_facturas.crear_desde_venta(venta)
        return True
```

---

## 4. Capa de Exposición RPC

### Descriptor de método

Cada método expuesto tiene un descriptor que declara su comportamiento:

```python
from dataclasses import dataclass, field
from typing import Callable, List


@dataclass
class DescriptorRPC:
    funcion:        Callable
    solo_lectura:   bool       = True    # True: solo SELECT en BD
    permisos:       List[str]  = field(default_factory=list)
    cache_segundos: int        = 0       # 0 = sin caché
    descripcion:    str        = ""
```

### Catálogo de un módulo

El catálogo declara qué métodos del servicio se exponen y con qué configuración:

```python
# rpc/catalogos/ventas.py

from rpc.registro import registro, DescriptorRPC

class CatalogoVentas:
    def __init__(self, servicio):
        self.svc = servicio
        self._registrar()

    def _registrar(self):
        defs = [
            ("model.venta.create",  self.crear,     False, ["ventas", "admin"]),
            ("model.venta.read",    self.leer,       True,  ["ventas", "admin", "reportes"]),
            ("model.venta.write",   self.actualizar, False, ["ventas", "admin"]),
            ("model.venta.delete",  self.eliminar,   False, ["admin"]),
            ("model.venta.search",  self.buscar,     True,  ["ventas", "admin", "reportes"]),
            ("model.venta.search_read", self.buscar_leer, True, ["ventas", "admin", "reportes"]),
            ("model.venta.quote",   self.cotizar,    False, ["ventas", "admin"]),
            ("model.venta.confirm", self.confirmar,  False, ["ventas", "admin"]),
            ("model.venta.process", self.procesar,   False, ["ventas", "admin"]),
            ("model.venta.cancel",  self.cancelar,   False, ["ventas", "admin"]),
        ]
        for nombre, func, solo_lectura, perms in defs:
            registro.registrar(nombre, DescriptorRPC(
                funcion=func, solo_lectura=solo_lectura, permisos=perms
            ))

    def crear(self, params, ctx):
        return self.svc.crear(params[0], ctx)

    def confirmar(self, params, ctx):
        return self.svc.confirmar(params[0], ctx)

    def procesar(self, params, ctx):
        return self.svc.procesar(params[0], ctx)

    # ... resto de adaptadores
```

---

## 5. Capa de Transporte

El servidor HTTP es un componente delgado. Su único trabajo es recibir peticiones y pasarlas al dispatcher:

```python
# servidor/http_server.py — Flask como ejemplo

from flask import Flask, request, jsonify
from rpc.dispatcher import DispatcherRPC

app = Flask(__name__)

@app.route("/rpc/", methods=["POST", "OPTIONS"])
def rpc_endpoint():
    if request.method == "OPTIONS":
        resp = app.make_response("")
        resp.headers["Access-Control-Allow-Origin"]  = "*"
        resp.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        return resp

    resultado = dispatcher.despachar(
        cuerpo=request.get_data(as_text=True),
        headers=dict(request.headers)
    )
    return app.response_class(resultado, mimetype="application/json")
```

---

## 6. El Registro de Métodos

El registro es el catálogo central que asocia nombres de métodos con sus descriptores:

```python
# rpc/registro.py

from typing import Dict, Optional

class RegistroRPC:
    def __init__(self):
        self._metodos: Dict[str, DescriptorRPC] = {}

    def registrar(self, nombre: str, descriptor: DescriptorRPC):
        if nombre in self._metodos:
            raise ValueError(f"Método '{nombre}' ya registrado.")
        self._metodos[nombre] = descriptor

    def obtener(self, nombre: str) -> Optional[DescriptorRPC]:
        return self._metodos.get(nombre)

    def listar(self) -> list:
        return sorted(self._metodos.keys())

registro = RegistroRPC()  # Instancia global
```

---

## 7. El Dispatcher

El dispatcher es el corazón del servidor. Su responsabilidad es única y bien definida:

```python
# rpc/dispatcher.py

import json
import traceback


class DispatcherRPC:
    METODOS_PUBLICOS = {"common.auth.login", "common.server.version", "system.listMethods"}

    def __init__(self, registro, gestor_sesiones):
        self.registro        = registro
        self.gestor_sesiones = gestor_sesiones

    def despachar(self, cuerpo: str, headers: dict) -> str:
        call_id = None
        try:
            # 1. Parsear
            try:
                peticion = json.loads(cuerpo)
            except json.JSONDecodeError as e:
                return self._error(None, -32700, "ParseError", f"JSON inválido: {e}")

            call_id = peticion.get("id")
            metodo  = peticion.get("method", "")
            params  = peticion.get("params", [])

            # 2. Localizar método
            descriptor = self.registro.obtener(metodo)
            if descriptor is None:
                return self._error(call_id, -32601, "MethodNotFound",
                                   f"Método '{metodo}' no encontrado.")

            # 3. Autenticación
            sesion = None
            if metodo not in self.METODOS_PUBLICOS:
                sesion = self.gestor_sesiones.validar(headers.get("Authorization", ""))
                if sesion is None:
                    return self._error(call_id, -32000, "Unauthorized",
                                       "Sesión inválida o expirada.", http_status=401)

            # 4. Permisos
            if descriptor.permisos and sesion:
                if not any(rol in sesion.roles for rol in descriptor.permisos):
                    return self._error(call_id, -32000, "AccessDenied",
                                       "Sin permisos para este método.")

            # 5. Extraer contexto (último param si es dict)
            ctx = {}
            if params and isinstance(params[-1], dict):
                ctx    = params[-1]
                params = params[:-1]
            if sesion:
                ctx["_user_id"] = sesion.user_id
                ctx["_roles"]   = sesion.roles

            # 6. Ejecutar
            resultado = descriptor.funcion(params, ctx)
            return json.dumps({"id": call_id, "result": resultado, "error": None})

        except ValueError as e:
            return self._error(call_id, -32000, "UserError", str(e))
        except PermissionError as e:
            return self._error(call_id, -32000, "AccessDenied", str(e))
        except Exception:
            traceback.print_exc()
            return self._error(call_id, -32603, "InternalError",
                               "Error interno del servidor.")

    def _error(self, call_id, code, name, message, http_status=200):
        return json.dumps({
            "id": call_id, "result": None,
            "error": {"code": code, "name": name, "message": message}
        })
```

---

## 8. Contexto de Ejecución

El contexto viaja desde la petición del cliente hasta el dominio. Permite que un mismo método se comporte diferente según quién lo llama y en qué configuración:

```
Petición del cliente
    │  params = [..., {"language": "es_BO", "company": 1}]
    ▼
Dispatcher
    │  extrae contexto, añade _user_id, _roles
    ▼
Catálogo/Adaptador
    │  pasa ctx al servicio
    ▼
Servicio de dominio
    │  usa ctx["company"] para filtrar datos
    ▼
Repositorio
       filtra por empresa, idioma, etc.
```

### Propagación explícita

El contexto se pasa explícitamente en cada capa. No se usan variables globales ni contextos de hilo implícitos:

```python
def despachar(self, cuerpo, headers):
    # ...
    resultado = descriptor.funcion(params, ctx)   # ctx se pasa siempre

def crear(self, params, ctx):                      # catálogo recibe ctx
    return self.svc.crear(params[0], ctx)          # y lo pasa al servicio

def crear(self, valores, ctx):                     # servicio lo usa
    empresa = ctx.get("company", 1)
    # ...
```

---

## 9. Estructura de Directorios de Referencia

```
proyecto/
│
├── dominio/                    ← Capa 1: Motor puro (sin HTTP, sin JSON)
│   ├── modelos/
│   │   ├── venta.py
│   │   ├── producto.py
│   │   └── cliente.py
│   ├── servicios/
│   │   ├── servicio_ventas.py
│   │   └── servicio_inventario.py
│   └── repositorios/           ← Interfaces (sin implementación)
│       ├── i_repo_ventas.py
│       └── i_repo_productos.py
│
├── rpc/                        ← Capa 2: Contrato público
│   ├── registro.py             ← Catálogo central
│   ├── descriptor.py           ← DescriptorRPC
│   ├── dispatcher.py           ← Núcleo del servidor RPC
│   ├── sesion.py               ← Gestión de sesiones
│   ├── sistema.py              ← listMethods, methodHelp, version
│   └── catalogos/
│       ├── ventas.py
│       ├── inventario.py
│       └── contabilidad.py
│
├── infraestructura/            ← Implementaciones concretas
│   ├── repositorios/
│   │   ├── repo_ventas_psql.py
│   │   └── repo_ventas_mem.py  ← Para tests
│   └── cache/
│       └── cache_lru.py
│
├── servidor/                   ← Capa 3: Transporte HTTP
│   ├── app_flask.py            ← Flask / FastAPI / cualquier framework
│   ├── wsgi.py
│   └── middleware/
│       ├── cors.py
│       └── rate_limiting.py
│
├── tests/
│   ├── dominio/                ← Tests unitarios (sin servidor)
│   └── rpc/                    ← Tests de integración
│
└── main.py                     ← Ensamblaje y arranque
```

---

## 10. Implementaciones del Servidor

### Python — servidor mínimo con Flask

```python
# main.py

from flask import Flask, request
from rpc.registro import registro, DescriptorRPC
from rpc.dispatcher import DispatcherRPC
from rpc.sesion import GestorSesiones
from infraestructura.repositorios.repo_ventas_psql import RepositorioVentasPSQL
from dominio.servicios.servicio_ventas import ServicioVentas
from rpc.catalogos.ventas import CatalogoVentas

# Ensamblar capas
repo    = RepositorioVentasPSQL(dsn="postgresql://localhost/miapp")
svc     = ServicioVentas(repo_ventas=repo)
CatalogoVentas(svc)   # registra model.venta.*

# Métodos del sistema
registro.registrar("system.listMethods", DescriptorRPC(
    funcion=lambda p, c: registro.listar(), solo_lectura=True))
registro.registrar("common.server.version", DescriptorRPC(
    funcion=lambda p, c: "1.0.0", solo_lectura=True))

gestor     = GestorSesiones(...)
dispatcher = DispatcherRPC(registro, gestor)

# Servidor HTTP
app = Flask(__name__)

@app.route("/rpc/", methods=["POST", "OPTIONS"])
def rpc():
    if request.method == "OPTIONS":
        return ("", 200, {
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        })
    resultado = dispatcher.despachar(request.get_data(as_text=True), dict(request.headers))
    return app.response_class(resultado, mimetype="application/json")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
```

---

### Go — servidor mínimo con net/http

```go
package main

import (
    "encoding/json"
    "fmt"
    "io"
    "net/http"
)

// Registro global de métodos
var metodos = map[string]func([]interface{}, map[string]interface{}) (interface{}, error){}

func registrar(nombre string, fn func([]interface{}, map[string]interface{}) (interface{}, error)) {
    metodos[nombre] = fn
}

func despachar(body []byte, headers http.Header) []byte {
    var req struct {
        ID     interface{}   `json:"id"`
        Method string        `json:"method"`
        Params []interface{} `json:"params"`
    }
    if err := json.Unmarshal(body, &req); err != nil {
        out, _ := json.Marshal(map[string]interface{}{
            "id": nil, "result": nil,
            "error": map[string]interface{}{"code": -32700, "message": "JSON inválido"},
        })
        return out
    }

    fn, ok := metodos[req.Method]
    if !ok {
        out, _ := json.Marshal(map[string]interface{}{
            "id": req.ID, "result": nil,
            "error": map[string]interface{}{"code": -32601, "message": "Método no encontrado"},
        })
        return out
    }

    // Extraer contexto
    params := req.Params
    ctx := map[string]interface{}{}
    if len(params) > 0 {
        if c, ok := params[len(params)-1].(map[string]interface{}); ok {
            ctx    = c
            params = params[:len(params)-1]
        }
    }

    result, err := fn(params, ctx)
    if err != nil {
        out, _ := json.Marshal(map[string]interface{}{
            "id": req.ID, "result": nil,
            "error": map[string]interface{}{"code": -32000, "message": err.Error()},
        })
        return out
    }
    out, _ := json.Marshal(map[string]interface{}{"id": req.ID, "result": result, "error": nil})
    return out
}

func main() {
    // Registrar métodos
    registrar("common.server.version", func(p []interface{}, c map[string]interface{}) (interface{}, error) {
        return "1.0.0", nil
    })
    registrar("system.listMethods", func(p []interface{}, c map[string]interface{}) (interface{}, error) {
        keys := make([]string, 0, len(metodos))
        for k := range metodos { keys = append(keys, k) }
        return keys, nil
    })
    registrar("model.producto.buscar", func(p []interface{}, c map[string]interface{}) (interface{}, error) {
        // lógica real aquí
        return []int{1, 2, 3}, nil
    })

    http.HandleFunc("/rpc/", func(w http.ResponseWriter, r *http.Request) {
        if r.Method == "OPTIONS" {
            w.Header().Set("Access-Control-Allow-Origin", "*")
            w.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS")
            w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
            return
        }
        body, _ := io.ReadAll(r.Body)
        resp := despachar(body, r.Header)
        w.Header().Set("Content-Type", "application/json")
        w.Write(resp)
    })

    fmt.Println("Servidor JSON-RPC en http://localhost:8000/rpc/")
    http.ListenAndServe(":8000", nil)
}
```

---

### Rust — servidor mínimo con Axum

```rust
use axum::{
    extract::Json,
    http::{HeaderMap, StatusCode},
    response::IntoResponse,
    routing::post,
    Router,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{collections::HashMap, net::SocketAddr, sync::Arc};

type Handler = Arc<dyn Fn(Vec<Value>, Value) -> Result<Value, String> + Send + Sync>;

struct Registro {
    metodos: HashMap<String, Handler>,
}

impl Registro {
    fn new() -> Self { Registro { metodos: HashMap::new() } }

    fn registrar<F>(&mut self, nombre: &str, f: F)
    where F: Fn(Vec<Value>, Value) -> Result<Value, String> + Send + Sync + 'static {
        self.metodos.insert(nombre.to_string(), Arc::new(f));
    }

    fn obtener(&self, nombre: &str) -> Option<&Handler> {
        self.metodos.get(nombre)
    }
}

#[derive(Deserialize)]
struct RpcReq { id: Value, method: String, #[serde(default)] params: Vec<Value> }

#[derive(Serialize)]
struct RpcResp { id: Value, result: Value, error: Value }

async fn rpc_handler(
    headers: HeaderMap,
    Json(req): Json<RpcReq>,
    axum::extract::State(reg): axum::extract::State<Arc<Registro>>,
) -> impl IntoResponse {
    let Some(handler) = reg.obtener(&req.method) else {
        return Json(RpcResp {
            id: req.id,
            result: Value::Null,
            error: json!({"code": -32601, "message": "Método no encontrado"}),
        });
    };

    let mut params = req.params;
    let ctx = if params.last().map(|v| v.is_object()).unwrap_or(false) {
        params.pop().unwrap()
    } else { json!({}) };

    match handler(params, ctx) {
        Ok(result) => Json(RpcResp { id: req.id, result, error: Value::Null }),
        Err(msg)   => Json(RpcResp {
            id: req.id,
            result: Value::Null,
            error: json!({"code": -32000, "message": msg}),
        }),
    }
}

#[tokio::main]
async fn main() {
    let mut reg = Registro::new();

    reg.registrar("common.server.version", |_, _| Ok(json!("1.0.0")));
    reg.registrar("model.producto.buscar", |params, ctx| {
        // lógica real aquí
        Ok(json!([1, 2, 3]))
    });

    let state = Arc::new(reg);
    let app = Router::new()
        .route("/rpc/", post(rpc_handler))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 8000));
    println!("Servidor JSON-RPC en http://{}/rpc/", addr);
    axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
}
```

---

### PHP — servidor mínimo

```php
<?php
// public/rpc.php — apuntar el servidor web aquí

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    exit;
}

// ── Registro de métodos ───────────────────────────────────────────────────────
$metodos = [];

function registrar(string $nombre, callable $fn): void {
    global $metodos;
    $metodos[$nombre] = $fn;
}

registrar('common.server.version', fn($p, $ctx) => '1.0.0');
registrar('system.listMethods',    fn($p, $ctx) => array_keys($GLOBALS['metodos']));

registrar('model.producto.buscar', function($params, $ctx) {
    // lógica real aquí
    return [1, 2, 3];
});

// ── Dispatcher ────────────────────────────────────────────────────────────────
function despachar(array $req): array {
    global $metodos;
    $id     = $req['id'] ?? null;
    $method = $req['method'] ?? '';
    $params = $req['params'] ?? [];

    if (!isset($metodos[$method])) {
        return ['id' => $id, 'result' => null,
                'error' => ['code' => -32601, 'message' => "Método '$method' no encontrado."]];
    }

    // Extraer contexto
    $ctx = [];
    if (!empty($params) && is_array(end($params)) && array_keys(end($params)) !== range(0, count(end($params)) - 1)) {
        $ctx    = array_pop($params);
    }

    try {
        $resultado = ($metodos[$method])($params, $ctx);
        return ['id' => $id, 'result' => $resultado, 'error' => null];
    } catch (Throwable $e) {
        return ['id' => $id, 'result' => null,
                'error' => ['code' => -32000, 'name' => 'UserError', 'message' => $e->getMessage()]];
    }
}

$cuerpo = file_get_contents('php://input');
$req    = json_decode($cuerpo, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(['id' => null, 'result' => null,
                      'error' => ['code' => -32700, 'message' => 'JSON inválido']]);
    exit;
}

echo json_encode(despachar($req));
```

---

*Continúa en la Parte 6: Manejo de Errores y Buenas Prácticas.*

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
