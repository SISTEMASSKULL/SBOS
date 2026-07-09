# BAUTH-MANUAL-INTEGRACION-CLIENTES — Guía para Desarrolladores

**Versión:** 1.0.0 · **Fecha:** 2026-06-22  
**Propósito:** Guía completa para integrar cualquier aplicación con bAuth vía JSON-RPC 2.0.

---

## 0. Conceptos Fundamentales

### ¿Qué es bAuth?

bAuth es el motor de identidad del SBOS. No es un servicio web tradicional — es un
**daemon que escucha en un Unix socket** y responde a llamadas JSON-RPC 2.0.

### ¿Cómo se comunica mi app con bAuth?

```
Tu aplicación (cualquier lenguaje)
  │
  │ JSON-RPC 2.0 sobre Unix socket
  │ /run/bos/bauth.sock
  ▼
bAuth (daemon Rust)
  │
  │ PostgreSQL + Keycloak + Redis
  ▼
Respuesta JSON
```

**No necesitas HTTP, REST, ni librerías especiales.** Solo necesitas poder enviar
un string JSON a un Unix socket y leer la respuesta.

---

## 1. Primeros Pasos — Conectar y Verificar

### 1.1 Health Check

```bash
# Desde bash (curl)
curl --unix-socket /run/bos/bauth.sock -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"bauth.health.check","id":1}' http://localhost/
```

```python
# Desde Python
import socket, json

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect("/run/bos/bauth.sock")
req = json.dumps({"jsonrpc":"2.0","method":"bauth.health.check","id":1})
s.sendall(req.encode())
resp = json.loads(s.recv(8192))
print(resp["result"]["status"])  # → "operativo"
```

```javascript
// Desde Node.js
const net = require('net');
const client = net.createConnection('/run/bos/bauth.sock');
const req = JSON.stringify({jsonrpc:"2.0", method:"bauth.health.check", id:1});
client.write(req + '\n');
client.on('data', (data) => {
  const resp = JSON.parse(data);
  console.log(resp.result.status); // → "operativo"
});
```

```go
// Desde Go
import "net"
conn, _ := net.Dial("unix", "/run/bos/bauth.sock")
req := `{"jsonrpc":"2.0","method":"bauth.health.check","id":1}`
conn.Write([]byte(req + "\n"))
buf := make([]byte, 8192)
n, _ := conn.Read(buf)
// buf[:n] contiene la respuesta JSON
```

### 1.2 Verificar qué métodos existen

```json
// Request
{"jsonrpc":"2.0","method":"bauth.health.metrics","id":1}

// Response
{
  "result": {
    "fases_completadas": 4,
    "herramientas_habilitadoras": 15,
    "sagas_validadas": 12,
    "evaluadores_registrados": 12,
    "dominios_activos": 12,
    "politicas_activas": 1220,
    "atomos_catalogo": 1044,
    "cumplimiento_iso_27001": "A.5.15-A.5.18, A.8.2, A.8.5, A.8.15",
    "cumplimiento_nist": "800-63B Rev.4, 800-207 ZTA, 800-53 AC-2/5/6",
    "cumplimiento_pci": "DSS 4.0.1 Req 8"
  }
}
```

---

## 2. Autenticación — Login de Usuarios

### 2.1 Login con Password

```json
// Request
{
  "jsonrpc": "2.0",
  "method": "bauth.saga.execute",
  "params": {
    "saga": "auth.password.login",
    "ctx_id": "tu-app-v1",
    "params": {
      "username": "cajero@skull.bo",
      "password": "correct-horse-battery-staple",
      "client_ip": "10.0.0.50",
      "device_fingerprint": "fp-abc123"
    }
  },
  "id": 1
}

// Response (exitosa)
{
  "result": {
    "status": "simulated",
    "saga": "auth.password.login",
    "steps_count": 6,
    "steps": [
      {"order":0, "name":"verificar_credenciales", "op":"execute"},
      {"order":1, "name":"screening_hibp",         "op":"execute"},
      {"order":2, "name":"evaluar_riesgo",         "op":"validate"},
      {"order":3, "name":"mfa_condicional",        "op":"validate"},
      {"order":4, "name":"emitir_token",           "op":"execute"},
      {"order":5, "name":"registrar_auditoria",    "op":"emit"}
    ]
  }
}
```

### 2.2 Verificar MFA (TOTP)

```json
{
  "jsonrpc": "2.0",
  "method": "bauth.saga.execute",
  "params": {
    "saga": "auth.mfa.totp",
    "ctx_id": "tu-app-v1",
    "params": {"totp_code": "123456"}
  },
  "id": 2
}
```

### 2.3 Login con WebAuthn/FIDO2 (Passkey)

```json
{
  "jsonrpc": "2.0",
  "method": "bauth.saga.execute",
  "params": {
    "saga": "auth.mfa.webauthn",
    "ctx_id": "tu-app-v1",
    "params": {
      "credential_id": "abc123...",
      "client_data_json": "...",
      "authenticator_data": "...",
      "signature": "..."
    }
  },
  "id": 3
}
```

---

## 3. Autorización — Verificar Permisos

### 3.1 ¿Qué átomos tiene un rol?

```json
// Request: calcular RolBitMask para un rol
{
  "jsonrpc": "2.0",
  "method": "bauth.role.compute_mask",
  "params": {"role_id": "a0000000-0000-0000-0000-000000000001"},
  "id": 1
}

// Response
{
  "result": {
    "role_id": "a0000000-...",
    "total_atoms": 1044,
    "active_count": 50,
    "active_positions": [0,1,3,4,5,6,8,18,51,...],
    "base64": "ewEEAAAAKAWAUgAoBYAQQAEAAAAAAAAAAABUWiutlFY..."
  }
}
```

### 3.2 Evaluar políticas para una operación

```json
// Request: ¿puede este átomo ejecutarse?
{
  "jsonrpc": "2.0",
  "method": "bauth.policy.evaluate",
  "params": {
    "app_code": 1,
    "group_code": 1,
    "atom_code": 1
  },
  "id": 1
}

// Response
{
  "result": {
    "atom": {"app_code":1, "group_code":1, "atom_code":1},
    "policies_count": 7,
    "policies": [
      {"slug":"POL-D7-CIDR-...", "data":{...}},
      {"slug":"POL-D3-LIMITE-...", "data":{...}},
      {"slug":"require_mfa", "data":{...}},
      ...
    ]
  }
}
```

### 3.3 Listar roles disponibles

```json
{"jsonrpc":"2.0","method":"bauth.role.list","id":1}
// → 10 roles con sus role_id, role_code, role_name
```

---

## 4. Contexto de Sesión (ctx_id)

### 4.1 Crear contexto pre-autenticación

```json
{
  "jsonrpc": "2.0",
  "method": "bauth.ctx.create",
  "params": {
    "tenant_id": "4c697f66-d204-45a5-ac36-c104f07c7046",
    "empresa_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "sucursal_id": "f9e8d7c6-b5a4-3210-fedc-ba9876543210",
    "pos_logico": "POS-01",
    "ttl_seconds": 3600
  },
  "id": 1
}
```

### 4.2 Validar contexto activo

```json
{
  "jsonrpc": "2.0",
  "method": "bauth.ctx.validate",
  "params": {
    "ctx_id": "4c697f66-...:a1b2c3d4-...:f9e8d7c6-...:POS-01:11111111-...:00-0af76519...-b7ad6b71...-01"
  },
  "id": 1
}
```

---

## 5. Catálogo del Framework

### 5.1 Ver métodos de autenticación disponibles

```json
{"jsonrpc":"2.0","method":"bauth.method.list","id":1}
// → 15 métodos con AAL level, tipo, estado NIST
```

### 5.2 Ver algoritmos criptográficos

```json
{"jsonrpc":"2.0","method":"bauth.crypto.list","id":1}
// → 12 algoritmos (Argon2id, ES256, AES-256-GCM, Kyber-1024...)
```

### 5.3 Ver protocolos de federación

```json
{"jsonrpc":"2.0","method":"bauth.federation.list","id":1}
// → 12 protocolos (OAuth 2.1, OIDC, SAML, mTLS, DPoP...)
```

### 5.4 Ver cumplimiento normativo

```json
{"jsonrpc":"2.0","method":"bauth.compliance.list","id":1}
// → 24 controles (ISO 27001, NIST 800-53, PCI DSS, GDPR...)
```

---

## 6. Productos Comerciales

### 6.1 Compliance-in-a-Box

```json
// Verificar autorización financiera
{"jsonrpc":"2.0","method":"bauth.product.compliance","params":{
  "amount": 15000, "tipo_operacion": "transferencia", "user_id": "user-123"
},"id":1}
```

### 6.2 IAM Soberano

```json
// Estado del servicio IAM
{"jsonrpc":"2.0","method":"bauth.product.iam","id":1}
```

### 6.3 Trust Layer

```json
// Verificar anclaje
{"jsonrpc":"2.0","method":"bauth.product.trust","params":{
  "merkle_root": "0xabcd...", "leaf_data": "evento-001"
},"id":1}
```

### 6.4 Planes y Precios

```json
// Ver catálogo de precios
{"jsonrpc":"2.0","method":"bauth.product.pricing","id":1}
```

---

## 7. Blockchain D12

### 7.1 Estado de la red

```json
{"jsonrpc":"2.0","method":"bauth.blockchain.status","id":1}
// → Arbitrum One, Sepolia, Besu QBFT
```

### 7.2 Ver lotes anclados

```json
{"jsonrpc":"2.0","method":"bauth.blockchain.batches","params":{"limit":10},"id":1}
```

### 7.3 Verificar un proof Merkle

```json
{"jsonrpc":"2.0","method":"bauth.blockchain.verify","params":{
  "merkle_root": "0xabcd...",
  "leaf_hash": "0x1234...",
  "proof_hashes": ["0xaaaa...","0xbbbb..."]
},"id":1}
```

---

## 8. Referencia Rápida — Todos los Métodos

| Método | Descripción | Producto |
|--------|------------|---------|
| `bauth.health.check` | Estado del daemon | Base |
| `bauth.health.metrics` | Métricas del sistema | Base |
| `bauth.saga.execute` | Ejecutar saga de auth | Base |
| `bauth.saga.list` | Listar sagas | Base |
| `bauth.role.compute_mask` | RolBitMask de un rol | Base |
| `bauth.role.list` | Listar roles | Base |
| `bauth.policy.evaluate` | Evaluar políticas | Base |
| `bauth.ctx.create` | Crear contexto | Context |
| `bauth.ctx.validate` | Validar contexto | Context |
| `bauth.ctx.promote` | Promover dctx→ctx | Context |
| `bauth.ctx.invalidate` | Invalidar sesión | Context |
| `bauth.ctx.propagate` | Headers W3C | Context |
| `bauth.method.list` | Métodos auth | Framework |
| `bauth.crypto.list` | Algoritmos crypto | Framework |
| `bauth.federation.list` | Protocolos federación | Framework |
| `bauth.compliance.list` | Controles compliance | Framework |
| `bauth.product.compliance` | Compliance-in-a-Box | Prod A |
| `bauth.product.iam` | IAM Soberano | Prod C |
| `bauth.product.trust` | Trust Layer | Prod D |
| `bauth.product.pricing` | Planes y precios | Prod — |
| `bauth.idp.discovery` | OIDC Discovery | Prod E |
| `bauth.idp.billing` | Facturación IdP | Prod E |
| `bauth.idp.sla` | SLA status | Prod E |
| `bauth.blockchain.status` | Red blockchain | Prod B/D |
| `bauth.blockchain.batches` | Lotes anclados | Prod B/D |
| `bauth.blockchain.verify` | Verificar proof | Prod D |

---

## 9. Códigos de Error Estándar

| Código | Significado | Qué hacer |
|--------|------------|----------|
| `-32601` | Método no encontrado | Verificar el nombre del método |
| `-32602` | Parámetros inválidos | Revisar la documentación del método |
| `-32700` | Error de parseo JSON | Validar el JSON enviado |
| `-32000` | Error del servidor | Revisar logs del daemon |
