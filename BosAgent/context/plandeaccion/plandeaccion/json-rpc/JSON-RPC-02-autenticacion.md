# Manual JSON-RPC — Parte 2: Autenticación y Gestión de Sesiones

> **Parte de:** Manual JSON-RPC (ver Parte 1 para fundamentos del protocolo)

---

## Tabla de Contenidos

1. [El Modelo de Sesión](#1-el-modelo-de-sesión)
2. [Login](#2-login)
3. [Construcción del Header de Autorización](#3-construcción-del-header-de-autorización)
4. [Llamadas Autenticadas](#4-llamadas-autenticadas)
5. [Logout](#5-logout)
6. [Manejo de Sesión Expirada](#6-manejo-de-sesión-expirada)
7. [Implementaciones por lenguaje](#7-implementaciones-por-lenguaje)

---

## 1. El Modelo de Sesión

Una API JSON-RPC bien diseñada centraliza la autenticación en un único método de login que devuelve un token de sesión. Ese token se incluye en cada llamada posterior.

```
┌─────────────────────────────────────────────────────────┐
│  Flujo de sesión                                        │
│                                                         │
│  1. common.auth.login(usuario, contraseña)              │
│        → devuelve: [user_id, session_token]             │
│                                                         │
│  2. Todas las llamadas siguientes incluyen:             │
│        Authorization: Basic base64(user:id:token)       │
│                                                         │
│  3. common.auth.logout()                                │
│        → invalida el token en el servidor               │
└─────────────────────────────────────────────────────────┘
```

El servidor mantiene el estado de las sesiones activas. Cada token:
- Está asociado a un usuario y sus roles/permisos
- Tiene un tiempo de vida configurable (típicamente 8 horas)
- Se invalida explícitamente con logout o automáticamente al expirar

---

## 2. Login

### Petición

```json
{
  "id": 1,
  "method": "common.auth.login",
  "params": ["nombre_usuario", {"password": "contraseña_segura"}]
}
```

El segundo parámetro es un objeto en lugar de una cadena plana para permitir extensiones futuras (autenticación multifactor, tokens TOTP, etc.) sin cambiar la firma del método.

### Respuesta exitosa

```json
{
  "id": 1,
  "result": [7, "a3f8c2d1e9b4567890abcdef12345678"],
  "error": null
}
```

El resultado es un array con dos elementos:

| Posición | Valor | Descripción |
|----------|-------|-------------|
| `[0]` | `7` | ID del usuario en el sistema |
| `[1]` | `"a3f8c2..."` | Token de sesión (hexadecimal, 32+ caracteres) |

### Respuesta fallida

```json
{
  "id": 1,
  "result": null,
  "error": {
    "code": -32000,
    "name": "AuthenticationError",
    "message": "Credenciales inválidas."
  }
}
```

---

## 3. Construcción del Header de Autorización

El esquema de autorización combina nombre de usuario, ID de usuario y token en una cadena codificada en Base64:

```
Authorization: Basic base64(username:user_id:session_token)
```

Este esquema es extensión del estándar HTTP Basic Auth, adaptado para incluir el token de sesión en lugar de la contraseña plana. Tiene las ventajas de ser compatible con cualquier cliente HTTP y no requerir headers personalizados.

### Ejemplo de construcción

Datos de entrada:
- username: `ana`
- user_id: `7`
- token: `a3f8c2d1e9b4567890abcdef12345678`

Cadena a codificar: `ana:7:a3f8c2d1e9b4567890abcdef12345678`

Header resultante:
```
Authorization: Basic YW5hOjc6YTNmOGMyZDFlOWI0NTY3ODkwYWJjZGVmMTIzNDU2Nzg=
```

---

## 4. Llamadas Autenticadas

Toda llamada posterior al login debe incluir el header de autorización:

```bash
curl -X POST https://api.miapp.com/rpc/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic YW5hOjc6YTNmOGMyZDFlOWI0NTY3ODkwYWJjZGVmMTIzNDU2Nzg=" \
  -d '{
    "id": 2,
    "method": "model.venta.search",
    "params": [[["estado", "=", "confirmada"]], 0, 10, null, {}]
  }'
```

El último elemento de `params` es el **contexto** (ver Parte 3). En llamadas simples puede ser un objeto vacío `{}`.

---

## 5. Logout

Al finalizar la sesión, se invalida el token en el servidor:

```json
{
  "id": 99,
  "method": "common.auth.logout",
  "params": []
}
```

Respuesta:

```json
{
  "id": 99,
  "result": true,
  "error": null
}
```

Después del logout, cualquier llamada con el token invalidado recibirá un `401 Unauthorized`.

---

## 6. Manejo de Sesión Expirada

Cuando el servidor devuelve `401 Unauthorized`, el cliente debe:

1. Ejecutar el login nuevamente para obtener un token fresco
2. Reintentar la llamada que falló con el nuevo token
3. Si el relogin también falla, notificar al usuario

```
Llamada API
    │
    ▼
¿Error 401?
    │
   Sí → login() → ¿Éxito?
    │                │
    │               Sí → reintentar llamada original
    │                │
    │               No → notificar al usuario / terminar sesión
    │
   No → procesar resultado normal
```

---

## 7. Implementaciones por Lenguaje

### Python

```python
import base64
import requests

class ClienteRPC:
    def __init__(self, url: str):
        self.url = url
        self.user_id = None
        self.session = None
        self.username = None
        self._call_id = 0

    def _next_id(self) -> int:
        self._call_id += 1
        return self._call_id

    def _auth_header(self) -> dict:
        if not self.session:
            return {}
        credenciales = f"{self.username}:{self.user_id}:{self.session}"
        encoded = base64.b64encode(credenciales.encode()).decode()
        return {"Authorization": f"Basic {encoded}"}

    def login(self, username: str, password: str) -> bool:
        payload = {
            "id": self._next_id(),
            "method": "common.auth.login",
            "params": [username, {"password": password}]
        }
        resp = requests.post(
            self.url,
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        data = resp.json()
        if data.get("error") or not data.get("result"):
            return False
        self.username = username
        self.user_id, self.session = data["result"]
        return True

    def call(self, method: str, params: list, context: dict = None) -> any:
        if context is not None:
            params = params + [context]
        payload = {
            "id": self._next_id(),
            "method": method,
            "params": params
        }
        headers = {"Content-Type": "application/json", **self._auth_header()}
        resp = requests.post(self.url, json=payload, headers=headers)

        if resp.status_code == 401:
            raise PermissionError("Sesión expirada. Vuelva a autenticarse.")

        data = resp.json()
        if data.get("error"):
            error = data["error"]
            raise Exception(f"[{error.get('name', 'Error')}] {error.get('message', '')}")
        return data["result"]

    def logout(self):
        if self.session:
            self.call("common.auth.logout", [])
            self.session = None
            self.user_id = None


# Uso
cliente = ClienteRPC("https://api.miapp.com/rpc/")
cliente.login("ana", "contraseña_segura")

ventas = cliente.call(
    "model.venta.search",
    [[["estado", "=", "confirmada"]], 0, 10, None],
    {"empresa": 1, "idioma": "es"}
)
print("IDs de ventas confirmadas:", ventas)

cliente.logout()
```

---

### Go

```go
package main

import (
    "bytes"
    "encoding/base64"
    "encoding/json"
    "errors"
    "fmt"
    "net/http"
    "sync/atomic"
)

type ClienteRPC struct {
    URL      string
    Username string
    UserID   int
    Session  string
    callID   atomic.Int64
}

type rpcRequest struct {
    ID     int64       `json:"id"`
    Method string      `json:"method"`
    Params interface{} `json:"params"`
}

type rpcError struct {
    Code    int    `json:"code"`
    Name    string `json:"name"`
    Message string `json:"message"`
}

type rpcResponse struct {
    ID     int64           `json:"id"`
    Result json.RawMessage `json:"result"`
    Error  *rpcError       `json:"error"`
}

func (c *ClienteRPC) nextID() int64 {
    return c.callID.Add(1)
}

func (c *ClienteRPC) authHeader() string {
    if c.Session == "" {
        return ""
    }
    raw := fmt.Sprintf("%s:%d:%s", c.Username, c.UserID, c.Session)
    return "Basic " + base64.StdEncoding.EncodeToString([]byte(raw))
}

func (c *ClienteRPC) Login(username, password string) error {
    params := []interface{}{username, map[string]string{"password": password}}
    var result [2]interface{}
    err := c.call("common.auth.login", params, &result, false)
    if err != nil {
        return err
    }
    c.Username = username
    c.UserID = int(result[0].(float64))
    c.Session = result[1].(string)
    return nil
}

func (c *ClienteRPC) Call(method string, params []interface{}, out interface{}) error {
    return c.call(method, params, out, true)
}

func (c *ClienteRPC) call(method string, params interface{}, out interface{}, auth bool) error {
    body, _ := json.Marshal(rpcRequest{
        ID:     c.nextID(),
        Method: method,
        Params: params,
    })

    req, _ := http.NewRequest("POST", c.URL, bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    if auth && c.Session != "" {
        req.Header.Set("Authorization", c.authHeader())
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    if resp.StatusCode == 401 {
        return errors.New("sesión expirada, vuelva a autenticarse")
    }

    var rpcResp rpcResponse
    if err := json.NewDecoder(resp.Body).Decode(&rpcResp); err != nil {
        return err
    }
    if rpcResp.Error != nil {
        return fmt.Errorf("[%s] %s", rpcResp.Error.Name, rpcResp.Error.Message)
    }
    if out != nil {
        return json.Unmarshal(rpcResp.Result, out)
    }
    return nil
}

func (c *ClienteRPC) Logout() {
    if c.Session != "" {
        c.Call("common.auth.logout", nil, nil)
        c.Session = ""
        c.UserID = 0
    }
}

func main() {
    cliente := &ClienteRPC{URL: "https://api.miapp.com/rpc/"}

    if err := cliente.Login("ana", "contraseña_segura"); err != nil {
        panic(err)
    }
    defer cliente.Logout()

    params := []interface{}{
        []interface{}{[]interface{}{"estado", "=", "confirmada"}},
        0, 10, nil,
        map[string]interface{}{"empresa": 1, "idioma": "es"},
    }

    var ids []int
    if err := cliente.Call("model.venta.search", params, &ids); err != nil {
        panic(err)
    }
    fmt.Println("IDs de ventas confirmadas:", ids)
}
```

---

### Rust

```rust
use base64::{engine::general_purpose, Engine};
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::sync::atomic::{AtomicU64, Ordering};

static CALL_ID: AtomicU64 = AtomicU64::new(0);

fn next_id() -> u64 {
    CALL_ID.fetch_add(1, Ordering::SeqCst) + 1
}

#[derive(Debug, Serialize)]
struct RpcRequest {
    id: u64,
    method: String,
    params: Value,
}

#[derive(Debug, Deserialize)]
struct RpcError {
    code: Option<i32>,
    name: Option<String>,
    message: String,
}

#[derive(Debug, Deserialize)]
struct RpcResponse {
    id: u64,
    result: Option<Value>,
    error: Option<RpcError>,
}

struct ClienteRPC {
    url: String,
    username: String,
    user_id: u64,
    session: String,
    http: Client,
}

impl ClienteRPC {
    fn new(url: &str) -> Self {
        ClienteRPC {
            url: url.to_string(),
            username: String::new(),
            user_id: 0,
            session: String::new(),
            http: Client::new(),
        }
    }

    fn auth_header(&self) -> Option<String> {
        if self.session.is_empty() {
            return None;
        }
        let raw = format!("{}:{}:{}", self.username, self.user_id, self.session);
        Some(format!("Basic {}", general_purpose::STANDARD.encode(raw.as_bytes())))
    }

    fn call_raw(&self, method: &str, params: Value, auth: bool) -> Result<Value, String> {
        let body = RpcRequest {
            id: next_id(),
            method: method.to_string(),
            params,
        };

        let mut builder = self.http.post(&self.url).json(&body);
        if auth {
            if let Some(header) = self.auth_header() {
                builder = builder.header("Authorization", header);
            }
        }

        let resp = builder.send().map_err(|e| e.to_string())?;

        if resp.status() == 401 {
            return Err("Sesión expirada. Vuelva a autenticarse.".to_string());
        }

        let rpc_resp: RpcResponse = resp.json().map_err(|e| e.to_string())?;
        if let Some(err) = rpc_resp.error {
            return Err(format!(
                "[{}] {}",
                err.name.unwrap_or_else(|| "Error".to_string()),
                err.message
            ));
        }
        rpc_resp.result.ok_or_else(|| "Respuesta vacía".to_string())
    }

    fn login(&mut self, username: &str, password: &str) -> Result<(), String> {
        let params = json!([username, {"password": password}]);
        let result = self.call_raw("common.auth.login", params, false)?;
        let arr = result.as_array().ok_or("Formato de respuesta inválido")?;
        self.username = username.to_string();
        self.user_id = arr[0].as_u64().ok_or("user_id inválido")?;
        self.session = arr[1].as_str().ok_or("token inválido")?.to_string();
        Ok(())
    }

    fn call(&self, method: &str, params: Value) -> Result<Value, String> {
        self.call_raw(method, params, true)
    }

    fn logout(&mut self) {
        if !self.session.is_empty() {
            let _ = self.call("common.auth.logout", json!([]));
            self.session.clear();
            self.user_id = 0;
        }
    }
}

fn main() -> Result<(), String> {
    let mut cliente = ClienteRPC::new("https://api.miapp.com/rpc/");
    cliente.login("ana", "contraseña_segura")?;

    let params = json!([
        [["estado", "=", "confirmada"]],
        0, 10, null,
        {"empresa": 1, "idioma": "es"}
    ]);

    let ids = cliente.call("model.venta.search", params)?;
    println!("IDs de ventas confirmadas: {}", ids);

    cliente.logout();
    Ok(())
}
```

---

### PHP

```php
<?php

class ClienteRPC {
    private string $url;
    private string $username = '';
    private int $userId = 0;
    private string $session = '';
    private int $callId = 0;

    public function __construct(string $url) {
        $this->url = $url;
    }

    private function nextId(): int {
        return ++$this->callId;
    }

    private function authHeader(): string {
        if (empty($this->session)) return '';
        $credentials = "{$this->username}:{$this->userId}:{$this->session}";
        return 'Basic ' . base64_encode($credentials);
    }

    private function doRequest(string $method, array $params, bool $auth = true): mixed {
        $payload = json_encode([
            'id'     => $this->nextId(),
            'method' => $method,
            'params' => $params,
        ]);

        $headers = ['Content-Type: application/json'];
        if ($auth && !empty($this->session)) {
            $headers[] = 'Authorization: ' . $this->authHeader();
        }

        $ch = curl_init($this->url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 30,
        ]);

        $raw      = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode === 401) {
            throw new RuntimeException('Sesión expirada. Vuelva a autenticarse.');
        }

        $response = json_decode($raw, true);
        if (!empty($response['error'])) {
            $err = $response['error'];
            throw new RuntimeException("[{$err['name']}] {$err['message']}");
        }

        return $response['result'];
    }

    public function login(string $username, string $password): bool {
        $result = $this->doRequest(
            'common.auth.login',
            [$username, ['password' => $password]],
            false
        );
        if (!$result) return false;
        $this->username = $username;
        [$this->userId, $this->session] = $result;
        return true;
    }

    public function call(string $method, array $params, array $context = []): mixed {
        if (!empty($context)) {
            $params[] = $context;
        }
        return $this->doRequest($method, $params);
    }

    public function logout(): void {
        if (!empty($this->session)) {
            $this->call('common.auth.logout', []);
            $this->session = '';
            $this->userId  = 0;
        }
    }
}

// Uso
$cliente = new ClienteRPC('https://api.miapp.com/rpc/');
$cliente->login('ana', 'contraseña_segura');

$ids = $cliente->call(
    'model.venta.search',
    [[['estado', '=', 'confirmada']], 0, 10, null],
    ['empresa' => 1, 'idioma' => 'es']
);

echo 'IDs de ventas confirmadas: ' . implode(', ', $ids) . PHP_EOL;

$cliente->logout();
```

---

*Continúa en la Parte 3: Operaciones CRUD y Contexto de Ejecución.*

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
