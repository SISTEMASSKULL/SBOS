# Manual JSON-RPC — Parte 4: Cadena de Eventos y Flujos de Negocio

> **Parte de:** Manual JSON-RPC (ver Partes 1–3 para fundamentos, autenticación y CRUD)

---

## Tabla de Contenidos

1. [El Concepto de Cadena de Eventos](#1-el-concepto-de-cadena-de-eventos)
2. [Anatomía de un Eslabón](#2-anatomía-de-un-eslabón)
3. [Tipos de Eslabones](#3-tipos-de-eslabones)
4. [Diseño de Máquinas de Estado](#4-diseño-de-máquinas-de-estado)
5. [Ejemplo Completo: Ciclo de Venta](#5-ejemplo-completo-ciclo-de-venta)
6. [Implementación de la cadena en cuatro lenguajes](#6-implementación-de-la-cadena-en-cuatro-lenguajes)
7. [Asistentes de Múltiples Pasos (Wizards)](#7-asistentes-de-múltiples-pasos-wizards)
8. [Generación de Reportes y Documentos](#8-generación-de-reportes-y-documentos)

---

## 1. El Concepto de Cadena de Eventos

El verdadero poder de JSON-RPC no está en las llamadas individuales sino en cómo se encadenan para construir flujos de negocio completos. Cada llamada es un **eslabón**: recibe datos del eslabón anterior, ejecuta su lógica, y produce datos para el siguiente.

```
Eslabón 1 → Eslabón 2 → Eslabón 3 → Eslabón N
  salida       entrada     salida      resultado
              =              =          final
           eslabón 1      eslabón 2
```

Este modelo tiene tres ventajas clave:

**Reutilización.** Cada eslabón puede participar en múltiples cadenas. Un método `confirmar_venta` es el mismo independientemente de si lo llama la interfaz web, una app móvil o un script de integración nocturno.

**Trazabilidad.** Cada llamada tiene un `id` correlacionable. En los logs del servidor, se puede reconstruir exactamente qué eslabones se ejecutaron, en qué orden y con qué resultado.

**Reversibilidad.** Si un eslabón falla, los anteriores ya completaron su transacción y el sistema quedó en un estado conocido. La cadena puede retomarse desde el punto de falla.

### La cadena como estructura JSON declarativa

Un punto central de este modelo es que la cadena de pasos puede **definirse como datos**, no solo ejecutarse como código. Un array JSON describe exactamente qué procedimientos deben ejecutarse en qué orden para producir un resultado determinado.

Esto significa que una interfaz — un botón "Facturar y Pagar e Imprimir" en la pantalla de ventas — puede representarse internamente como una cadena de tres eslabones definida en JSON, no como tres llamadas independientes dispersas en el código del frontend:

```json
[
  {"id": 1, "method": "model.factura.post",   "params": [[301], {}]},
  {"id": 2, "method": "model.factura.pay",    "params": [[301], {}]},
  {"id": 3, "method": "report.factura.execute", "params": [[301], {"formato": "pdf"}, {}]}
]
```

El servidor recibe estos tres eslabones en un solo HTTP POST (batch request, Parte 1 §3.5), los ejecuta en orden, y devuelve los tres resultados. El frontend solo recibe la respuesta final y la muestra.

**La consecuencia arquitectónica es profunda:** la lógica de qué pasos componen un proceso de negocio vive en la definición de la cadena, no en el código de la interfaz. Un mismo proceso puede ejecutarse desde un botón web, desde una llamada de línea de comandos, o desde una integración nocturna — todos usando exactamente la misma cadena JSON.

```
Botón "Facturar, Pagar e Imprimir"
          │
          │  un solo POST con la cadena de 3 eslabones
          ▼
  [factura.post, factura.pay, report.execute]
          │
          ▼
  Servidor ejecuta en orden → devuelve 3 resultados
          │
          ▼
  Frontend muestra el PDF generado
```

Cada procedimiento del servidor (`factura.post`, `factura.pay`, `report.execute`) es completamente independiente. No sabe si lo llaman desde un botón, desde un script o como parte de una cadena mayor. Esa independencia es lo que permite combinarlos en cualquier orden sin modificar el servidor.

---

## 2. Anatomía de un Eslabón

```
┌──────────────────────────────────────────────────────────┐
│                      ESLABÓN N                           │
│                                                          │
│  Entrada                                                 │
│  ─────────────────────────────────────────────────────   │
│  IDs o datos del eslabón anterior                        │
│                                                          │
│  Procesamiento                                           │
│  ─────────────────────────────────────────────────────   │
│  • Validar que el estado actual permite la transición    │
│  • Ejecutar la lógica de negocio                         │
│  • Persisitir el nuevo estado                            │
│  • Generar registros derivados si corresponde            │
│                                                          │
│  Salida                                                  │
│  ─────────────────────────────────────────────────────   │
│  Nuevos IDs / nuevo estado / datos para el siguiente     │
└──────────────────────────────────────────────────────────┘
```

### Patrón de llamada de un eslabón

```json
{
  "id": 5,
  "method": "model.venta.confirm",
  "params": [
    [42],
    {"company": 1, "language": "es_BO"}
  ]
}
```

La entrada es el ID del registro (o lista de IDs). La salida típica es `true` (éxito) o el nuevo ID de registros generados.

---

## 3. Tipos de Eslabones

| Tipo | Método | Propósito |
|------|--------|-----------|
| **Creación** | `model.X.create` | Crear el registro inicial de la cadena |
| **Transición de estado** | `model.X.confirmar` | Avanzar el registro a un nuevo estado |
| **Generación** | `model.X.generar_Y` | Crear registros derivados (facturas, envíos) |
| **Lectura** | `model.X.read` | Obtener datos para el siguiente eslabón |
| **Asistente** | `wizard.X.execute` | Procesos de múltiples pasos con interfaz de usuario |
| **Reporte** | `report.X.execute` | Generar documentos en PDF, ODS, XLSX |

---

## 4. Diseño de Máquinas de Estado

Los flujos de negocio complejos se modelan como máquinas de estados. Cada transición es un método RPC.

### Ejemplo: ciclo de vida de una venta

```
         create()
[nuevo] ──────────► [borrador]
                        │
                    quote()
                        │
                        ▼
                   [cotizacion]
                        │
                   confirm()
                        │
                        ▼
                   [confirmada] ──── cancel() ──► [cancelada]
                        │
                   process()
                        │
                        ▼
                   [en_proceso]
                   /           \
          (genera)              (genera)
              │                    │
              ▼                    ▼
          [envio]             [factura]
              │                    │
         enviar()              publicar()
              │                    │
              ▼                    ▼
          [entregado]          [publicada]
                                   │
                                pagar()
                                   │
                                   ▼
                               [pagada]
```

### Reglas de transición

Cada método de transición debe verificar que el estado actual permite la transición y lanzar un error descriptivo si no:

```
Llamada: model.venta.confirm([42])
Verificación del servidor:
  ¿venta_42.estado == "cotizacion"?
    Sí → confirmar, estado = "confirmada", devolver true
    No → error: "Solo se pueden confirmar ventas en estado cotización.
                 La venta 42 está en estado 'borrador'."
```

Este comportamiento garantiza que la cadena no puede avanzar en un orden incorrecto, independientemente de quién la invoque.

---

## 5. Ejemplo Completo: Ciclo de Venta

Este es el flujo completo desde la creación hasta la factura pagada, expresado como una secuencia de llamadas JSON-RPC.

### Diagrama de la cadena

```
[1] Login
    │
    ▼
[2] Buscar cliente y producto
    │
    ▼
[3] create() → Venta [borrador]
    │
    ▼
[4] quote() → Venta [cotizacion]
    │
    ▼
[5] confirm() → Venta [confirmada]
    │
    ▼
[6] process() → Venta [en_proceso]
    │
    ├───────────────────────────┐
    ▼                           ▼
[7] Envío [esperando]      Factura [borrador]
    │                           │
[8] assign()              [9] post()
    │                           │
[8] pack()                      ▼
    │                      Factura [publicada]
[8] done()                      │
    │                     [10] pay()
    ▼                           │
Envío [entregado]               ▼
                           Factura [pagada]
[11] Logout
```

### Llamadas JSON-RPC de la cadena

**Eslabón 1 — Login:**
```json
{"id": 1, "method": "common.auth.login",
 "params": ["usuario", {"password": "contraseña"}]}
→ result: [7, "a3f8c2d1..."]
```

**Eslabón 2 — Buscar cliente:**
```json
{"id": 2, "method": "model.cliente.search",
 "params": [[["nombre", "ilike", "%ABC%"]], 0, 1, null, {}]}
→ result: [5]
```

**Eslabón 2b — Buscar producto:**
```json
{"id": 3, "method": "model.producto.search",
 "params": [[["nombre", "=", "Laptop Pro X"]], 0, 1, null, {}]}
→ result: [42]
```

**Eslabón 3 — Crear venta:**
```json
{"id": 4, "method": "model.venta.create",
 "params": [[{"cliente": 5, "moneda": 1,
              "lineas": [["create", [{"producto": 42, "cantidad": 2}]]]}], {}]}
→ result: [101]
```

**Eslabón 4 — Cotizar:**
```json
{"id": 5, "method": "model.venta.quote",
 "params": [[101], {}]}
→ result: true
```

**Eslabón 5 — Confirmar:**
```json
{"id": 6, "method": "model.venta.confirm",
 "params": [[101], {}]}
→ result: true
```

**Eslabón 6 — Procesar (genera envío y factura):**
```json
{"id": 7, "method": "model.venta.process",
 "params": [[101], {}]}
→ result: true
```

**Eslabón 7 — Leer IDs generados:**
```json
{"id": 8, "method": "model.venta.read",
 "params": [[101], ["envios", "facturas"], {}]}
→ result: [{"id": 101, "envios": [201], "facturas": [301]}]
```

**Eslabón 8 — Procesar envío:**
```json
{"id": 9,  "method": "model.envio.assign", "params": [[201], {}]}
{"id": 10, "method": "model.envio.pack",   "params": [[201], {}]}
{"id": 11, "method": "model.envio.done",   "params": [[201], {}]}
→ result: true (cada uno)
```

**Eslabón 9 — Publicar factura:**
```json
{"id": 12, "method": "model.factura.post",
 "params": [[301], {}]}
→ result: true
```

**Eslabón 10 — Pagar factura:**
```json
{"id": 13, "method": "model.factura.pay",
 "params": [[301], {}]}
→ result: true
```

**Eslabón 11 — Logout:**
```json
{"id": 14, "method": "common.auth.logout", "params": []}
→ result: true
```

---

## 6. Implementación de la Cadena en Cuatro Lenguajes

### Python

```python
import base64
import requests

URL = "https://api.miapp.com/rpc/"

class CadenaVenta:
    def __init__(self, url: str):
        self.url = url
        self.uid = None
        self.session = None
        self.username = None
        self._n = 0

    def _id(self):
        self._n += 1
        return self._n

    def _call(self, method, params, ctx=None, autenticado=True):
        if ctx is not None:
            params = params + [ctx]
        headers = {"Content-Type": "application/json"}
        if autenticado and self.session:
            creds = f"{self.username}:{self.uid}:{self.session}"
            headers["Authorization"] = "Basic " + base64.b64encode(creds.encode()).decode()
        payload = {"id": self._id(), "method": method, "params": params}
        resp = requests.post(self.url, json=payload, headers=headers)
        data = resp.json()
        if data.get("error"):
            raise Exception(f"[{method}] {data['error']['message']}")
        return data["result"]

    def ejecutar(self, usuario, contrasena, nombre_cliente, nombre_producto):
        ctx = {"company": 1, "language": "es_BO"}

        # 1. Login
        resultado = self._call("common.auth.login",
                               [usuario, {"password": contrasena}],
                               autenticado=False)
        self.uid, self.session = resultado
        self.username = usuario
        print(f"[1] Autenticado como {usuario} (uid={self.uid})")

        # 2. Buscar cliente
        clientes = self._call("model.cliente.search",
                              [[["nombre", "ilike", f"%{nombre_cliente}%"]], 0, 1, None], ctx)
        cliente_id = clientes[0]
        print(f"[2] Cliente encontrado: id={cliente_id}")

        # 2b. Buscar producto
        productos = self._call("model.producto.search",
                               [[["nombre", "=", nombre_producto]], 0, 1, None], ctx)
        producto_id = productos[0]
        print(f"[2b] Producto encontrado: id={producto_id}")

        # 3. Crear venta
        venta_ids = self._call("model.venta.create", [[{
            "cliente": cliente_id,
            "moneda":  1,
            "lineas":  [["create", [{"producto": producto_id,
                                     "cantidad": 2.0,
                                     "precio_unit": "1500.00"}]]]
        }]], ctx)
        venta_id = venta_ids[0]
        print(f"[3] Venta creada: id={venta_id} (borrador)")

        # 4-6. Transiciones de estado
        for eslabón, metodo in enumerate(["quote", "confirm", "process"], start=4):
            self._call(f"model.venta.{metodo}", [[venta_id]], ctx)
            print(f"[{eslabón}] model.venta.{metodo} completado")

        # 7. Leer IDs generados
        datos = self._call("model.venta.read", [[venta_id], ["envios", "facturas"]], ctx)
        envio_ids   = datos[0]["envios"]
        factura_ids = datos[0]["facturas"]
        print(f"[7] Generados: envíos={envio_ids}, facturas={factura_ids}")

        # 8. Procesar envío
        if envio_ids:
            envio_id = envio_ids[0]
            for metodo in ["assign", "pack", "done"]:
                self._call(f"model.envio.{metodo}", [[envio_id]], ctx)
            print(f"[8] Envío {envio_id} entregado")

        # 9-10. Factura
        if factura_ids:
            fac_id = factura_ids[0]
            self._call("model.factura.post", [[fac_id]], ctx)
            self._call("model.factura.pay",  [[fac_id]], ctx)
            print(f"[9-10] Factura {fac_id} publicada y pagada")

        # 11. Logout
        self._call("common.auth.logout", [])
        print("[11] Sesión cerrada\n✓ Cadena completada exitosamente")


CadenaVenta(URL).ejecutar("ana", "secret", "ABC", "Laptop Pro X")
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

const URL = "https://api.miapp.com/rpc/"

type Cadena struct {
    Username string
    UID      int
    Session  string
    n        int
}

func (c *Cadena) nextID() int { c.n++; return c.n }

func (c *Cadena) call(method string, params []interface{}) (interface{}, error) {
    body, _ := json.Marshal(map[string]interface{}{
        "id": c.nextID(), "method": method, "params": params,
    })
    req, _ := http.NewRequest("POST", URL, bytes.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    if c.Session != "" {
        raw  := fmt.Sprintf("%s:%d:%s", c.Username, c.UID, c.Session)
        req.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte(raw)))
    }
    resp, err := http.DefaultClient.Do(req)
    if err != nil { return nil, err }
    defer resp.Body.Close()
    var out struct {
        Result interface{}            `json:"result"`
        Error  map[string]interface{} `json:"error"`
    }
    json.NewDecoder(resp.Body).Decode(&out)
    if out.Error != nil { return nil, fmt.Errorf("%v", out.Error["message"]) }
    return out.Result, nil
}

func intSlice(v interface{}) []int {
    arr := v.([]interface{})
    out := make([]int, len(arr))
    for i, x := range arr { out[i] = int(x.(float64)) }
    return out
}

func main() {
    c   := &Cadena{}
    ctx := map[string]interface{}{"company": 1, "language": "es_BO"}

    // Login
    r, _ := c.call("common.auth.login", []interface{}{"ana", map[string]string{"password": "secret"}})
    arr   := r.([]interface{})
    c.Username, c.UID, c.Session = "ana", int(arr[0].(float64)), arr[1].(string)
    fmt.Printf("[1] Autenticado uid=%d\n", c.UID)

    // Buscar cliente
    cids, _ := c.call("model.cliente.search",
        []interface{}{[]interface{}{[]interface{}{"nombre", "ilike", "%ABC%"}}, 0, 1, nil, ctx})
    clienteID := intSlice(cids)[0]
    fmt.Printf("[2] Cliente id=%d\n", clienteID)

    // Buscar producto
    pids, _ := c.call("model.producto.search",
        []interface{}{[]interface{}{[]interface{}{"nombre", "=", "Laptop Pro X"}}, 0, 1, nil, ctx})
    productoID := intSlice(pids)[0]

    // Crear venta
    lineas := []interface{}{[]interface{}{"create", []interface{}{
        map[string]interface{}{"producto": productoID, "cantidad": 2.0, "precio_unit": "1500.00"},
    }}}
    vr, _ := c.call("model.venta.create", []interface{}{
        []interface{}{map[string]interface{}{"cliente": clienteID, "moneda": 1, "lineas": lineas}}, ctx,
    })
    ventaID := intSlice(vr)[0]
    fmt.Printf("[3] Venta id=%d\n", ventaID)

    // Transiciones
    for i, m := range []string{"quote", "confirm", "process"} {
        c.call("model.venta."+m, []interface{}{[]interface{}{ventaID}, ctx})
        fmt.Printf("[%d] venta.%s\n", 4+i, m)
    }

    // Leer generados
    datos, _ := c.call("model.venta.read",
        []interface{}{[]interface{}{ventaID}, []string{"envios", "facturas"}, ctx})
    mapa     := datos.([]interface{})[0].(map[string]interface{})
    envios   := intSlice(mapa["envios"])
    facturas := intSlice(mapa["facturas"])

    // Envío
    if len(envios) > 0 {
        eid := envios[0]
        for _, m := range []string{"assign", "pack", "done"} {
            c.call("model.envio."+m, []interface{}{[]interface{}{eid}, ctx})
        }
        fmt.Printf("[8] Envío %d entregado\n", eid)
    }

    // Factura
    if len(facturas) > 0 {
        fid := facturas[0]
        c.call("model.factura.post", []interface{}{[]interface{}{fid}, ctx})
        c.call("model.factura.pay",  []interface{}{[]interface{}{fid}, ctx})
        fmt.Printf("[9-10] Factura %d pagada\n", fid)
    }

    c.call("common.auth.logout", []interface{}{})
    fmt.Println("[11] Sesión cerrada. ✓ Cadena completada.")
}
```

---

### Rust

```rust
use base64::{engine::general_purpose, Engine};
use reqwest::blocking::Client;
use serde_json::{json, Value};
use std::sync::atomic::{AtomicU64, Ordering};

static N: AtomicU64 = AtomicU64::new(0);
fn nid() -> u64 { N.fetch_add(1, Ordering::SeqCst) + 1 }

struct Cadena { client: Client, url: String, username: String, uid: u64, session: String }

impl Cadena {
    fn new(url: &str) -> Self {
        Cadena { client: Client::new(), url: url.to_string(),
                 username: String::new(), uid: 0, session: String::new() }
    }

    fn call(&self, method: &str, params: Value) -> Result<Value, String> {
        let mut req = self.client.post(&self.url)
            .header("Content-Type", "application/json")
            .json(&json!({"id": nid(), "method": method, "params": params}));
        if !self.session.is_empty() {
            let raw = format!("{}:{}:{}", self.username, self.uid, self.session);
            req = req.header("Authorization",
                format!("Basic {}", general_purpose::STANDARD.encode(raw.as_bytes())));
        }
        let resp: Value = req.send().map_err(|e| e.to_string())?
                             .json().map_err(|e| e.to_string())?;
        if let Some(e) = resp.get("error").filter(|e| !e.is_null()) {
            return Err(e["message"].as_str().unwrap_or("error").to_string());
        }
        Ok(resp["result"].clone())
    }

    fn ejecutar(&mut self) -> Result<(), String> {
        let ctx = json!({"company": 1, "language": "es_BO"});

        // Login
        let r = self.call("common.auth.login", json!(["ana", {"password": "secret"}]))?;
        self.username = "ana".to_string();
        self.uid      = r[0].as_u64().unwrap();
        self.session  = r[1].as_str().unwrap().to_string();
        println!("[1] uid={}", self.uid);

        // Buscar cliente y producto
        let cids = self.call("model.cliente.search",
            json!([[["nombre", "ilike", "%ABC%"]], 0, 1, null, ctx]))?;
        let cliente_id = cids[0].as_u64().unwrap();

        let pids = self.call("model.producto.search",
            json!([[["nombre", "=", "Laptop Pro X"]], 0, 1, null, ctx]))?;
        let producto_id = pids[0].as_u64().unwrap();

        // Crear venta
        let vr = self.call("model.venta.create", json!([[{
            "cliente": cliente_id, "moneda": 1,
            "lineas": [["create", [{"producto": producto_id,
                                    "cantidad": 2.0, "precio_unit": "1500.00"}]]]
        }], ctx]))?;
        let venta_id = vr[0].as_u64().unwrap();
        println!("[3] Venta id={}", venta_id);

        // Transiciones
        for (i, m) in ["quote", "confirm", "process"].iter().enumerate() {
            self.call(&format!("model.venta.{}", m), json!([[venta_id], ctx]))?;
            println!("[{}] venta.{}", 4 + i, m);
        }

        // Leer generados
        let datos = self.call("model.venta.read",
            json!([[venta_id], ["envios", "facturas"], ctx]))?;
        let envios:   Vec<u64> = datos[0]["envios"].as_array().unwrap()
            .iter().map(|v| v.as_u64().unwrap()).collect();
        let facturas: Vec<u64> = datos[0]["facturas"].as_array().unwrap()
            .iter().map(|v| v.as_u64().unwrap()).collect();

        // Envío
        if let Some(&eid) = envios.first() {
            for m in &["assign", "pack", "done"] {
                self.call(&format!("model.envio.{}", m), json!([[eid], ctx]))?;
            }
            println!("[8] Envío {} entregado", eid);
        }

        // Factura
        if let Some(&fid) = facturas.first() {
            self.call("model.factura.post", json!([[fid], ctx]))?;
            self.call("model.factura.pay",  json!([[fid], ctx]))?;
            println!("[9-10] Factura {} pagada", fid);
        }

        self.call("common.auth.logout", json!([]))?;
        println!("[11] ✓ Cadena completada");
        Ok(())
    }
}

fn main() {
    Cadena::new("https://api.miapp.com/rpc/").ejecutar().unwrap();
}
```

---

### PHP

```php
<?php

const URL = 'https://api.miapp.com/rpc/';

class Cadena {
    private string $username = '';
    private int    $uid      = 0;
    private string $session  = '';
    private int    $n        = 0;

    private function id(): int { return ++$this->n; }

    private function call(string $method, array $params): mixed {
        $headers = ['Content-Type: application/json'];
        if (!empty($this->session)) {
            $creds     = "{$this->username}:{$this->uid}:{$this->session}";
            $headers[] = 'Authorization: Basic ' . base64_encode($creds);
        }
        $payload = json_encode(['id' => $this->id(), 'method' => $method, 'params' => $params]);
        $ch = curl_init(URL);
        curl_setopt_array($ch, [CURLOPT_POST => true, CURLOPT_POSTFIELDS => $payload,
                                 CURLOPT_HTTPHEADER => $headers, CURLOPT_RETURNTRANSFER => true]);
        $data = json_decode(curl_exec($ch), true);
        curl_close($ch);
        if (!empty($data['error'])) throw new RuntimeException("[{$method}] {$data['error']['message']}");
        return $data['result'];
    }

    public function ejecutar(): void {
        $ctx = ['company' => 1, 'language' => 'es_BO'];

        // Login
        [$this->uid, $this->session] =
            $this->call('common.auth.login', ['ana', ['password' => 'secret']]);
        $this->username = 'ana';
        echo "[1] uid={$this->uid}\n";

        // Buscar cliente y producto
        $clienteId  = $this->call('model.cliente.search',
            [[['nombre', 'ilike', '%ABC%']], 0, 1, null, $ctx])[0];
        $productoId = $this->call('model.producto.search',
            [[['nombre', '=', 'Laptop Pro X']], 0, 1, null, $ctx])[0];

        // Crear venta
        $ventaId = $this->call('model.venta.create', [[
            ['cliente' => $clienteId, 'moneda' => 1,
             'lineas'  => [['create', [['producto' => $productoId,
                                        'cantidad' => 2.0, 'precio_unit' => '1500.00']]]]]], $ctx])[0];
        echo "[3] Venta id=$ventaId\n";

        // Transiciones
        foreach (['quote', 'confirm', 'process'] as $i => $m) {
            $this->call("model.venta.$m", [[$ventaId], $ctx]);
            echo "[" . (4 + $i) . "] venta.$m\n";
        }

        // Leer generados
        $datos    = $this->call('model.venta.read', [[$ventaId], ['envios', 'facturas'], $ctx])[0];
        $envios   = $datos['envios'];
        $facturas = $datos['facturas'];

        // Envío
        if (!empty($envios)) {
            $eid = $envios[0];
            foreach (['assign', 'pack', 'done'] as $m) $this->call("model.envio.$m", [[$eid], $ctx]);
            echo "[8] Envío $eid entregado\n";
        }

        // Factura
        if (!empty($facturas)) {
            $fid = $facturas[0];
            $this->call('model.factura.post', [[$fid], $ctx]);
            $this->call('model.factura.pay',  [[$fid], $ctx]);
            echo "[9-10] Factura $fid pagada\n";
        }

        $this->call('common.auth.logout', []);
        echo "[11] ✓ Cadena completada\n";
    }
}

(new Cadena())->ejecutar();
```

---

## 7. Asistentes de Múltiples Pasos (Wizards)

Para procesos que requieren varias etapas de interacción con el usuario (formularios en varios pasos, confirmaciones intermedias, etc.), se usa el espacio de nombres `wizard.*`.

### Flujo de un wizard

```
wizard.X.create([])        → session_id
wizard.X.execute(session_id, {datos_paso_1}, "siguiente")  → {campos_paso_2}
wizard.X.execute(session_id, {datos_paso_2}, "finalizar")  → {resultado_final}
```

### Ejemplo: wizard de facturación masiva

```json
{"id": 1, "method": "wizard.facturacion.create", "params": [[], {}]}
→ result: {"session_id": "wiz-abc123"}

{"id": 2, "method": "wizard.facturacion.execute",
 "params": [{"session_id": "wiz-abc123"},
            {"fecha_factura": "2024-12-01", "grupo_venta": "mensual"},
            "siguiente", {}]}
→ result: {"estado": "confirmacion", "ventas_a_facturar": 47, "total": "125430.00"}

{"id": 3, "method": "wizard.facturacion.execute",
 "params": [{"session_id": "wiz-abc123"}, {}, "finalizar", {}]}
→ result: {"facturas_creadas": [3001, 3002, ..., 3047]}
```

---

## 8. Generación de Reportes y Documentos

Los reportes se generan en el espacio de nombres `report.*` y devuelven el documento en Base64:

```json
{
  "id": 20,
  "method": "report.venta.execute",
  "params": [
    [101],
    {"formato": "pdf"},
    {}
  ]
}
```

Respuesta:

```json
{
  "id": 20,
  "result": {
    "content": "JVBERi0xLjQK...",
    "content_type": "application/pdf",
    "filename": "venta-101.pdf"
  },
  "error": null
}
```

El cliente decodifica el Base64 y guarda o muestra el archivo:

```python
import base64

resultado = cliente.call("report.venta.execute", [[101], {"formato": "pdf"}])
with open(resultado["filename"], "wb") as f:
    f.write(base64.b64decode(resultado["content"]))
```

---

*Continúa en la Parte 5: Arquitectura del Servidor JSON-RPC.*

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
