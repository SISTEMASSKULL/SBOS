# Manual JSON-RPC — Parte 3: Operaciones CRUD y Contexto de Ejecución

> **Parte de:** Manual JSON-RPC (ver Parte 1 para fundamentos, Parte 2 para autenticación)

---

## Tabla de Contenidos

1. [El Contexto de Ejecución](#1-el-contexto-de-ejecución)
2. [Crear Registros — `create`](#2-crear-registros--create)
3. [Leer Registros — `read`](#3-leer-registros--read)
4. [Buscar Registros — `search`](#4-buscar-registros--search)
5. [Buscar y Leer — `search_read`](#5-buscar-y-leer--search_read)
6. [Actualizar Registros — `write`](#6-actualizar-registros--write)
7. [Eliminar Registros — `delete`](#7-eliminar-registros--delete)
8. [Relaciones entre Registros](#8-relaciones-entre-registros)
9. [Ejemplos completos en cuatro lenguajes](#9-ejemplos-completos-en-cuatro-lenguajes)

---

## 1. El Contexto de Ejecución

El contexto es el último parámetro de toda llamada a la API. Es un objeto JSON que transporta metadatos sobre el entorno de ejecución: idioma, empresa, zona horaria, etc.

```json
{
  "language": "es_BO",
  "company":  1,
  "timezone": "America/La_Paz",
  "employee": null
}
```

El contexto es **siempre el último elemento** del array `params`. Esta convención permite que los clientes lo omitan en llamadas simples (se usa un objeto vacío por defecto) y que el servidor lo extraiga de forma predecible:

```json
{
  "method": "model.venta.search",
  "params": [
    [["estado", "=", "confirmada"]],
    0,
    50,
    null,
    {"language": "es_BO", "company": 1}
  ]
}
```

### Campos estándar del contexto

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `language` | string | Código de idioma para traducción de campos (`es_BO`, `en_US`, etc.) |
| `company` | int | ID de la empresa activa (en sistemas multi-empresa) |
| `timezone` | string | Zona horaria para la presentación de fechas |
| `employee` | int/null | ID del empleado que origina la acción |

El servidor puede añadir campos internos al contexto (prefijados con `_`) que no son enviados por el cliente:

```python
# Añadido por el dispatcher tras validar la sesión:
contexto["_user_id"] = sesion.user_id
contexto["_roles"]   = sesion.roles
```

---

## 2. Crear Registros — `create`

### Firma

```
model.<entidad>.create([lista_de_valores], contexto)
```

El primer parámetro es siempre un **array de objetos**, incluso cuando se crea un solo registro. Esto permite crear múltiples registros en una sola llamada.

### Petición

```json
{
  "id": 10,
  "method": "model.cliente.create",
  "params": [
    [
      {
        "nombre":     "Empresa ABC S.A.",
        "nit":        "1234567890",
        "telefono":   "+591-2-2220000",
        "activo":     true
      }
    ],
    {"language": "es_BO", "company": 1}
  ]
}
```

### Respuesta

```json
{
  "id": 10,
  "result": [5],
  "error": null
}
```

El resultado es un **array de IDs** de los registros creados, en el mismo orden que los valores enviados.

### Crear múltiples registros

```json
{
  "id": 11,
  "method": "model.cliente.create",
  "params": [
    [
      {"nombre": "Empresa ABC S.A.", "nit": "1234567890"},
      {"nombre": "Distribuciones XYZ", "nit": "9876543210"},
      {"nombre": "Comercial DEF Ltda.", "nit": "5555555555"}
    ],
    {"language": "es_BO"}
  ]
}
```

Respuesta:

```json
{
  "id": 11,
  "result": [5, 6, 7],
  "error": null
}
```

---

## 3. Leer Registros — `read`

### Firma

```
model.<entidad>.read([lista_de_ids], [lista_de_campos], contexto)
```

### Petición

```json
{
  "id": 12,
  "method": "model.cliente.read",
  "params": [
    [5, 6],
    ["nombre", "nit", "telefono", "direcciones"],
    {"language": "es_BO"}
  ]
}
```

### Respuesta

```json
{
  "id": 12,
  "result": [
    {
      "id":          5,
      "nombre":      "Empresa ABC S.A.",
      "nit":         "1234567890",
      "telefono":    "+591-2-2220000",
      "direcciones": [10, 11]
    },
    {
      "id":          6,
      "nombre":      "Distribuciones XYZ",
      "nit":         "9876543210",
      "telefono":    null,
      "direcciones": [20]
    }
  ],
  "error": null
}
```

Los campos de tipo relación (`direcciones`) devuelven IDs. Para obtener los datos de esos registros relacionados, se hace una segunda llamada `read` sobre el modelo correspondiente.

**Buenas prácticas:**
- Solicitar solo los campos que se van a usar. Evitar pedir todos los campos si solo se necesitan tres.
- Para leer un solo registro, pasar un array de un elemento: `[5]`.

---

## 4. Buscar Registros — `search`

### Firma

```
model.<entidad>.search(dominio, offset, limit, order, contexto)
```

### El dominio de búsqueda

El dominio es una lista de condiciones en forma de tripletas `[campo, operador, valor]`:

```json
[["nombre", "ilike", "%ABC%"], ["activo", "=", true]]
```

Múltiples condiciones se combinan con `AND` por defecto. Para usar `OR`:

```json
["OR",
  ["nombre", "ilike", "%ABC%"],
  ["nit", "=", "1234567890"]
]
```

Para grupos mixtos:

```json
[
  ["activo", "=", true],
  ["OR",
    ["pais", "=", "BO"],
    ["pais", "=", "PE"]
  ]
]
```

### Operadores disponibles

| Operador | Significado |
|----------|-------------|
| `=` | Igual |
| `!=` | Distinto |
| `<`, `<=`, `>`, `>=` | Comparación numérica o de fecha |
| `like` | Patrón (sensible a mayúsculas, `%` como comodín) |
| `ilike` | Patrón (insensible a mayúsculas) |
| `in` | El valor está en una lista |
| `not in` | El valor no está en una lista |
| `child_of` | El registro es hijo del ID dado (jerarquías) |

### Petición completa

```json
{
  "id": 13,
  "method": "model.cliente.search",
  "params": [
    [["nombre", "ilike", "%ABC%"], ["activo", "=", true]],
    0,
    50,
    [["nombre", "ASC"]],
    {"language": "es_BO"}
  ]
}
```

| Parámetro | Valor | Descripción |
|-----------|-------|-------------|
| dominio | `[["nombre", "ilike", "%ABC%"], ...]` | Filtros |
| offset | `0` | Registros a saltar (paginación) |
| limit | `50` | Máximo de resultados (`null` = sin límite) |
| order | `[["nombre", "ASC"]]` | Ordenamiento |

### Respuesta

```json
{
  "id": 13,
  "result": [5, 12, 23],
  "error": null
}
```

`search` devuelve solo IDs. Para obtener los datos, se combina con `read` o se usa `search_read`.

---

## 5. Buscar y Leer — `search_read`

Combina `search` y `read` en una sola llamada HTTP, minimizando la latencia:

### Firma

```
model.<entidad>.search_read(dominio, [campos], offset, limit, order, contexto)
```

### Petición

```json
{
  "id": 14,
  "method": "model.cliente.search_read",
  "params": [
    [["activo", "=", true]],
    ["nombre", "nit", "telefono"],
    0,
    100,
    [["nombre", "ASC"]],
    {"language": "es_BO"}
  ]
}
```

### Respuesta

```json
{
  "id": 14,
  "result": [
    {"id": 5,  "nombre": "Distribuciones XYZ", "nit": "9876543210", "telefono": null},
    {"id": 12, "nombre": "Empresa ABC S.A.",   "nit": "1234567890", "telefono": "+591-2-2220000"}
  ],
  "error": null
}
```

Usar `search_read` siempre que se necesite buscar y obtener datos en la misma operación. Es el método más eficiente para listar registros.

---

## 6. Actualizar Registros — `write`

### Firma

```
model.<entidad>.write([lista_de_ids], {diccionario_de_valores}, contexto)
```

### Petición

```json
{
  "id": 15,
  "method": "model.cliente.write",
  "params": [
    [5, 12],
    {"telefono": "+591-2-2221111"},
    {"company": 1}
  ]
}
```

Actualiza el campo `telefono` en los registros con IDs 5 y 12 simultáneamente.

### Respuesta

```json
{
  "id": 15,
  "result": true,
  "error": null
}
```

`write` devuelve `true` si la operación fue exitosa. Si algún registro no pasa las validaciones del servidor, toda la operación falla y se revierte (comportamiento transaccional).

---

## 7. Eliminar Registros — `delete`

### Firma

```
model.<entidad>.delete([lista_de_ids], contexto)
```

### Petición

```json
{
  "id": 16,
  "method": "model.cliente.delete",
  "params": [
    [99],
    {}
  ]
}
```

### Respuesta

```json
{
  "id": 16,
  "result": true,
  "error": null
}
```

Si el servidor tiene restricciones de integridad referencial (el registro tiene datos relacionados que lo bloquean), recibirá un error `UserError` con el mensaje descriptivo. El borrado no se realiza de forma parcial.

---

## 8. Relaciones entre Registros

Cuando se crea o actualiza un registro que tiene campos de relación (uno-a-muchos, muchos-a-muchos), se usa una sintaxis especial de comandos relacionales dentro del array de valores:

| Comando | Formato | Acción |
|---------|---------|--------|
| Crear y vincular | `["create", [{datos}]]` | Crea nuevos registros relacionados y los vincula |
| Vincular existentes | `["add", [id1, id2]]` | Añade registros existentes a la relación |
| Desvincular | `["remove", [id1]]` | Quita de la relación sin eliminar |
| Eliminar vinculados | `["delete", [id1]]` | Elimina los registros relacionados |
| Reemplazar todo | `["set", [id1, id2]]` | Reemplaza la relación completa |

### Ejemplo: crear una venta con líneas

```json
{
  "id": 20,
  "method": "model.venta.create",
  "params": [
    [
      {
        "cliente":      5,
        "moneda":       1,
        "termino_pago": 1,
        "lineas": [
          ["create", [
            {
              "producto":     42,
              "cantidad":     2.0,
              "precio_unit":  "1500.00",
              "descripcion":  "Laptop Pro X"
            },
            {
              "producto":     43,
              "cantidad":     1.0,
              "precio_unit":  "250.00",
              "descripcion":  "Mouse Ergonómico"
            }
          ]]
        ]
      }
    ],
    {"company": 1, "language": "es_BO"}
  ]
}
```

El comando `["create", [...]]` dentro del campo `lineas` indica al servidor que debe crear los registros de línea y vincularlos a la venta en la misma transacción.

---

## 9. Ejemplos Completos en Cuatro Lenguajes

Los siguientes ejemplos muestran un flujo completo: buscar un cliente, buscar un producto, crear una venta con líneas, y leer el resultado.

### Python

```python
import base64
import requests

URL = "https://api.miapp.com/rpc/"

def rpc(method, params, user_id, session, username, call_id=1, ctx=None):
    if ctx is not None:
        params = params + [ctx]
    creds = f"{username}:{user_id}:{session}"
    auth  = "Basic " + base64.b64encode(creds.encode()).decode()
    resp  = requests.post(URL, json={"id": call_id, "method": method, "params": params},
                          headers={"Content-Type": "application/json", "Authorization": auth})
    data  = resp.json()
    if data.get("error"):
        raise Exception(data["error"]["message"])
    return data["result"]

# Login
login = requests.post(URL, json={"id": 1, "method": "common.auth.login",
                                  "params": ["ana", {"password": "secret"}]},
                      headers={"Content-Type": "application/json"}).json()
uid, session = login["result"]
ctx = {"company": 1, "language": "es_BO"}

# Buscar cliente
clientes = rpc("model.cliente.search_read",
               [[["nombre", "ilike", "%ABC%"]], ["id", "nombre"], 0, 1, None],
               uid, session, "ana", call_id=2, ctx=ctx)
cliente_id = clientes[0]["id"]
print(f"Cliente: {clientes[0]['nombre']} (id={cliente_id})")

# Buscar producto
productos = rpc("model.producto.search",
                [[["nombre", "=", "Laptop Pro X"]], 0, 1, None],
                uid, session, "ana", call_id=3, ctx=ctx)
producto_id = productos[0]

# Crear venta
venta_ids = rpc("model.venta.create",
                [[{
                    "cliente": cliente_id,
                    "moneda":  1,
                    "lineas":  [["create", [{"producto": producto_id,
                                             "cantidad": 2.0,
                                             "precio_unit": "1500.00"}]]]
                }]],
                uid, session, "ana", call_id=4, ctx=ctx)
venta_id = venta_ids[0]
print(f"Venta creada: id={venta_id}")

# Leer la venta creada
venta = rpc("model.venta.read",
            [[venta_id], ["numero", "estado", "total"]],
            uid, session, "ana", call_id=5, ctx=ctx)
print(f"Venta: {venta[0]}")

# Logout
rpc("common.auth.logout", [], uid, session, "ana", call_id=6)
```

---

### Go

```go
package main

import (
    "bytes"
    "encoding/base64"
    "encoding/json"
    "fmt"
    "net/http"
)

const RPCURL = "https://api.miapp.com/rpc/"

type Ctx = map[string]interface{}

func callRPC(method string, params []interface{}, username string, uid int, session string, id int) (interface{}, error) {
    creds := fmt.Sprintf("%s:%d:%s", username, uid, session)
    auth  := "Basic " + base64.StdEncoding.EncodeToString([]byte(creds))

    body, _ := json.Marshal(map[string]interface{}{
        "id": id, "method": method, "params": params,
    })
    req, _ := http.NewRequest("POST", RPCURL, bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", auth)

    resp, _ := http.DefaultClient.Do(req)
    defer resp.Body.Close()

    var out struct {
        Result interface{}            `json:"result"`
        Error  map[string]interface{} `json:"error"`
    }
    json.NewDecoder(resp.Body).Decode(&out)
    if out.Error != nil {
        return nil, fmt.Errorf("%v", out.Error["message"])
    }
    return out.Result, nil
}

func main() {
    // Login
    body, _ := json.Marshal(map[string]interface{}{
        "id": 1, "method": "common.auth.login",
        "params": []interface{}{"ana", map[string]string{"password": "secret"}},
    })
    resp, _ := http.Post(RPCURL, "application/json", bytes.NewReader(body))
    var loginResp struct{ Result []interface{} `json:"result"` }
    json.NewDecoder(resp.Body).Decode(&loginResp)
    resp.Body.Close()

    uid     := int(loginResp.Result[0].(float64))
    session := loginResp.Result[1].(string)
    ctx     := Ctx{"company": 1, "language": "es_BO"}

    // Buscar cliente
    clientes, _ := callRPC("model.cliente.search_read",
        []interface{}{[]interface{}{[]interface{}{"nombre", "ilike", "%ABC%"}},
            []string{"id", "nombre"}, 0, 1, nil, ctx},
        "ana", uid, session, 2)

    clienteMap := clientes.([]interface{})[0].(map[string]interface{})
    clienteID  := int(clienteMap["id"].(float64))
    fmt.Printf("Cliente: %v (id=%d)\n", clienteMap["nombre"], clienteID)

    // Buscar producto
    productos, _ := callRPC("model.producto.search",
        []interface{}{[]interface{}{[]interface{}{"nombre", "=", "Laptop Pro X"}}, 0, 1, nil, ctx},
        "ana", uid, session, 3)
    productoID := int(productos.([]interface{})[0].(float64))

    // Crear venta
    lineas := []interface{}{[]interface{}{"create", []interface{}{
        map[string]interface{}{"producto": productoID, "cantidad": 2.0, "precio_unit": "1500.00"},
    }}}
    ventaIds, _ := callRPC("model.venta.create",
        []interface{}{[]interface{}{map[string]interface{}{
            "cliente": clienteID, "moneda": 1, "lineas": lineas,
        }}, ctx},
        "ana", uid, session, 4)

    ventaID := int(ventaIds.([]interface{})[0].(float64))
    fmt.Printf("Venta creada: id=%d\n", ventaID)

    // Logout
    callRPC("common.auth.logout", []interface{}{}, "ana", uid, session, 5)
}
```

---

### Rust

```rust
use base64::{engine::general_purpose, Engine};
use reqwest::blocking::Client;
use serde_json::{json, Value};

const RPC_URL: &str = "https://api.miapp.com/rpc/";

fn call(
    client: &Client,
    method: &str,
    params: Value,
    username: &str,
    uid: u64,
    session: &str,
    id: u64,
) -> Result<Value, String> {
    let creds = format!("{}:{}:{}", username, uid, session);
    let auth  = format!("Basic {}", general_purpose::STANDARD.encode(creds.as_bytes()));

    let body  = json!({"id": id, "method": method, "params": params});
    let resp  = client
        .post(RPC_URL)
        .header("Content-Type", "application/json")
        .header("Authorization", auth)
        .json(&body)
        .send()
        .map_err(|e| e.to_string())?;

    let data: Value = resp.json().map_err(|e| e.to_string())?;
    if let Some(err) = data.get("error").filter(|e| !e.is_null()) {
        return Err(err["message"].as_str().unwrap_or("Error").to_string());
    }
    Ok(data["result"].clone())
}

fn main() -> Result<(), String> {
    let client = Client::new();

    // Login
    let login_body = json!({
        "id": 1,
        "method": "common.auth.login",
        "params": ["ana", {"password": "secret"}]
    });
    let login_resp: Value = client.post(RPC_URL).json(&login_body).send()
        .map_err(|e| e.to_string())?.json().map_err(|e| e.to_string())?;

    let result  = &login_resp["result"];
    let uid     = result[0].as_u64().unwrap();
    let session = result[1].as_str().unwrap().to_string();
    let ctx     = json!({"company": 1, "language": "es_BO"});

    // Buscar cliente
    let clientes = call(&client, "model.cliente.search_read",
        json!([[["nombre", "ilike", "%ABC%"]], ["id", "nombre"], 0, 1, null, ctx]),
        "ana", uid, &session, 2)?;

    let cliente_id = clientes[0]["id"].as_u64().unwrap();
    println!("Cliente: {} (id={})", clientes[0]["nombre"], cliente_id);

    // Buscar producto
    let productos = call(&client, "model.producto.search",
        json!([[["nombre", "=", "Laptop Pro X"]], 0, 1, null, ctx]),
        "ana", uid, &session, 3)?;
    let producto_id = productos[0].as_u64().unwrap();

    // Crear venta
    let venta_ids = call(&client, "model.venta.create",
        json!([[{
            "cliente": cliente_id,
            "moneda": 1,
            "lineas": [["create", [{"producto": producto_id, "cantidad": 2.0, "precio_unit": "1500.00"}]]]
        }], ctx]),
        "ana", uid, &session, 4)?;

    let venta_id = venta_ids[0].as_u64().unwrap();
    println!("Venta creada: id={}", venta_id);

    // Logout
    call(&client, "common.auth.logout", json!([]), "ana", uid, &session, 5)?;
    Ok(())
}
```

---

### PHP

```php
<?php

const RPC_URL = 'https://api.miapp.com/rpc/';

function rpc(string $method, array $params, string $username, int $uid,
             string $session, int $id, array $ctx = []): mixed
{
    if (!empty($ctx)) $params[] = $ctx;
    $creds   = "{$username}:{$uid}:{$session}";
    $auth    = 'Basic ' . base64_encode($creds);
    $payload = json_encode(['id' => $id, 'method' => $method, 'params' => $params]);

    $ch = curl_init(RPC_URL);
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $payload,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/json', "Authorization: $auth"],
        CURLOPT_RETURNTRANSFER => true,
    ]);
    $data = json_decode(curl_exec($ch), true);
    curl_close($ch);

    if (!empty($data['error'])) throw new RuntimeException($data['error']['message']);
    return $data['result'];
}

// Login
$loginPayload = json_encode(['id' => 1, 'method' => 'common.auth.login',
                              'params' => ['ana', ['password' => 'secret']]]);
$ch = curl_init(RPC_URL);
curl_setopt_array($ch, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => $loginPayload,
                         CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
                         CURLOPT_RETURNTRANSFER => true]);
$login  = json_decode(curl_exec($ch), true);
curl_close($ch);

[$uid, $session] = $login['result'];
$ctx = ['company' => 1, 'language' => 'es_BO'];

// Buscar cliente
$clientes  = rpc('model.cliente.search_read',
    [[['nombre', 'ilike', '%ABC%']], ['id', 'nombre'], 0, 1, null],
    'ana', $uid, $session, 2, $ctx);
$clienteId = $clientes[0]['id'];
echo "Cliente: {$clientes[0]['nombre']} (id=$clienteId)\n";

// Buscar producto
$productos  = rpc('model.producto.search',
    [[['nombre', '=', 'Laptop Pro X']], 0, 1, null],
    'ana', $uid, $session, 3, $ctx);
$productoId = $productos[0];

// Crear venta
$ventaIds = rpc('model.venta.create',
    [[['cliente' => $clienteId, 'moneda' => 1,
       'lineas' => [['create', [['producto' => $productoId,
                                  'cantidad' => 2.0,
                                  'precio_unit' => '1500.00']]]]]]],
    'ana', $uid, $session, 4, $ctx);
echo "Venta creada: id={$ventaIds[0]}\n";

// Logout
rpc('common.auth.logout', [], 'ana', $uid, $session, 5);
```

---

*Continúa en la Parte 4: Cadena de Eventos y Flujos de Negocio.*

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
