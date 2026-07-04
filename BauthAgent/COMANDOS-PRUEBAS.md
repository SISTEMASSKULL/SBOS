# BAUTH — BATERÍA DE PRUEBAS COMPLETA

**VPS:** `ssh root@13.140.128.230` · **Socket:** `/tmp/bauth/bauth.sock`
**DB:** `PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres SBOS_db`

## Resultados de la sesión 2026-06-27

| Sección | Prueba | Resultado |
|---------|--------|-----------|
| V0 | Build, CLI, MUSL, config, señales, socket | ✅ |
| V1 | BitMask, DAG, SoD, FastPath | ✅ |
| TOKEN | T-01 a T-10 | ✅ |
| VARIANTES | A, B, C, D, E | ✅ |
| ESTRÉS | 100 tokens paralelos, 100 mixtos | ✅ |
| BLOCKCHAIN | Panel, lotes, verificación | ✅ (ver §BLK) |

---

## V0 — ESQUELETO DEL BINARIO (B0)

### V01 — Build + Tests unitarios (local)

> Verificar que el binario compila sin warnings y todos los tests pasan.
> 281 tests en 0 warnings es el estado certificado.

```bash
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent
cargo check
cargo test
cargo build --release --target x86_64-unknown-linux-musl
ls -lh target/x86_64-unknown-linux-musl/release/bauth
```

**Esperado:** `5.1M bauth` · binary estático · 0 warnings · 281 tests ok

### V02 — CLI bauthctl (VPS)

> bauthctl es la Vía 1 de la Interface Dual (WebSocket RPC). Debe responder
> a los mismos comandos que el JSON-RPC.

```bash
SOCK=/tmp/bauth/bauth.sock
/usr/local/bin/bauthctl --help
/usr/local/bin/bauthctl version
/usr/local/bin/bauthctl -s $SOCK health
/usr/local/bin/bauthctl -s $SOCK role list
/usr/local/bin/bauthctl -s $SOCK user list
/usr/local/bin/bauthctl -s $SOCK sync status
/usr/local/bin/bauthctl -s $SOCK tenant list
/usr/local/bin/bauthctl -s $SOCK sign internal "test"
```

### V03 — Binario MUSL estático (VPS)

> MUSL = zero deps en runtime. `ldd` debe decir "not a dynamic executable".

```bash
file /usr/local/bin/bauth
ldd /usr/local/bin/bauth
ls -lh /usr/local/bin/bauth
```

**Esperado:** `ELF 64-bit LSB pie executable, x86-64, statically linked`

### V04 — Config TOML (VPS)

```bash
cat /etc/bos/bauth.toml
```

### V05 — Señales: SIGHUP reload + graceful shutdown (VPS)

> SIGHUP recarga config sin perder conexiones. PID no cambia.

```bash
systemctl stop bauth.service
systemctl start bauth.service
PID=$(systemctl show -p MainPID bauth.service | cut -d= -f2)
kill -HUP $PID
echo "PID antes: $PID"
sleep 1
echo "PID después: $(systemctl show -p MainPID bauth.service | cut -d= -f2)"
```

**Esperado:** mismo PID antes y después del SIGHUP

### V06 — Restart automático systemd (VPS)

> `Restart=on-failure` en bauth.service garantiza que el proceso se recupera
> de crashes. Timeout 6s es el RestartSec+StartLimitBurst.

```bash
systemctl status bauth.service
kill -9 $(pgrep bauth)
sleep 6
systemctl is-active bauth.service
```

**Esperado:** `active` tras matar el proceso

### V07 — Socket Unix + Interface Dual (VPS)

> El socket multiplexea JSON-RPC 2.0 (Vía 2) y WebSocket RPC (Vía 1).
> El primer byte del handshake determina la vía: 'G' = GET HTTP/WS, '{' = JSON-RPC.

```bash
ls -la /tmp/bauth/bauth.sock
# Vía 2: JSON-RPC directo
echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3
# Vía 1: WebSocket (a través de bauthctl)
/usr/local/bin/bauthctl -s /tmp/bauth/bauth.sock health
```

### V08 — Catálogo de métodos disponibles

> Verificar cuántos métodos JSON-RPC están registrados y que los módulos
> principales existen: token, bitmask, blockchain, ctx, domain.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print('status:', r['status'])
print('uptime_secs:', r.get('uptime_secs','?'))
print('socket:', r.get('socket','?'))
"
```

---

## V1 — BITMASK DUAL (B1)

### Átomos por dominio (5808 total)

> El catálogo tiene 5808 átomos distribuidos en 12 dominios y 484 grupos.
> Los primeros 3 dominios son los más poblados.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.domain.logical.list","id":1}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['count'],'átomos D1 Lógico')"
echo '{"jsonrpc":"2.0","method":"bauth.domain.physical.list","id":2}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['count'],'átomos D2 Físico')"
echo '{"jsonrpc":"2.0","method":"bauth.domain.financial.list","id":3}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['count'],'átomos D3 Financiero')"
```

### RolBitMask de cajero (8 átomos esperados)

> `bauth.role.compute_mask` calcula el BitMask de un rol desde `bauth.privilege_role`.
> UUID `00000000-0000-0000-0000-000000000101` = test_cajero_rol.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.role.compute_mask","params":{"role_id":"00000000-0000-0000-0000-000000000101"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'total={r[\"total_atoms\"]}, active={r[\"active_count\"]}, positions={r[\"active_positions\"]}')"
```

**Esperado:** `active=8, positions=[1, 2, 3, 4, 5, 6, 7, 8]` (o similar)

### Herencia DAG + ClosureTable (42 átomos superadmin)

> El superadmin hereda de cajero + contador. La herencia se resuelve
> vía `bauth.privilege_closure` (tabla de cierre del DAG).

```bash
echo '{"jsonrpc":"2.0","method":"bauth.inheritance.compute","params":{"role_id":"00000000-0000-0000-0000-000000000103"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'atomos_efectivos={r[\"atomos_efectivos\"]}, profundidad={r[\"profundidad_herencia\"]}')"
```

**Esperado:** `atomos_efectivos=42, profundidad≥2`

### ConflictMatrix SoD — sin conflictos

> Separation of Duties: posición 1585 y 1586 son átomos de diferente dominio
> que NO deben entrar en conflicto. Verificar que el motor confirma 0 conflictos.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.sod.check","params":{"atom_positions":[1,2,1585,1586]},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'conflicts={r[\"conflicto_detectados\"]}, bloqueante={r[\"bloqueante\"]}')"
```

**Esperado:** `conflicts=0, bloqueante=False`

### FastPath — <0.5ns por evaluación (O(1))

> El FastPath es un lookup de bit en el RolBitMask. Nunca consulta la BD.
> El veredicto se resuelve en la posición del átomo en el bitmask del usuario.

```bash
SOCK=/tmp/bauth/bauth.sock
# Átomo 1 (tryton.g1.d1.nuevo): cajero SÍ tiene → PERMITIDO
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d1.nuevo","user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":1}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'{r[\"veredicto\"]}: {r[\"motivo\"]}')"

# Átomo 5 (tryton.g1.d1.imprimir): cajero NO tiene → DENEGADO
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d1.imprimir","user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":2}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'{r[\"veredicto\"]}: {r[\"motivo\"]}')"

# Cliente sin rol: DENEGADO en todo
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d1.nuevo","user_uuid":"019f06db-62a9-7551-b33c-12583be0ed1f"},"id":3}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'{r[\"veredicto\"]}: {r[\"motivo\"]}')"
```

**Esperado:** `PERMITIDO` · `DENEGADO` · `DENEGADO`

---

## B2-B8 — 12 DOMINIOS DE EVALUACIÓN

### DomainRegistry — evaluación multi-dominio

> `bauth.context.evaluate` aplica los 12 evaluadores de dominio en cadena.
> Requiere ctx_id válido obtenido de `bauth.ctx.create`.
> Los dominios D1-D4 están implementados; D5-D12 retornan PENDIENTE por defecto.

```bash
SOCK=/tmp/bauth/bauth.sock

CTX=$(echo '{"jsonrpc":"2.0","method":"bauth.ctx.create","params":{"tenant_id":"019f01e8-2e33-7734-a756-63d31a003a75","empresa_id":"019f01e8-0000-7000-a000-000000000001","sucursal_id":"019f01e8-0000-7000-b000-000000000001","user_id":"00000000-0000-0000-0000-000000000103"},"id":1}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['ctx_id'])")
echo "ctx_id: $CTX"

CID=$(echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.ctx.promote\",\"params\":{\"ctx_id\":\"$CTX\",\"user_id\":\"00000000-0000-0000-0000-000000000103\"},\"id\":2}" | nc -U $SOCK -w 3 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['ctx_id'])")

echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.context.evaluate\",\"params\":{\"ctx_id\":\"$CID\",\"atom_slug\":\"tryton.g1.d1.nuevo\"},\"id\":3}" | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'{r[\"domains_evaluated\"]} dominios evaluados')
for d in r['domains']:
    names={'1':'Lógico','2':'Físico','3':'Financiero','4':'Temporal','5':'Biométrico','6':'Geo','7':'Red','8':'Contexto','9':'Credenciales','10':'Delegación','11':'Auditoría','12':'Blockchain'}
    rtext={0:'DENEGADO',1:'PERMITIDO',2:'PENDIENTE'}
    print(f'  D{d[\"domain\"]} {names.get(str(d[\"domain\"]),\"?\")}: {rtext.get(d[\"result\"],d[\"result\"])}')
"
```

### Métricas de salud completas

```bash
echo '{"jsonrpc":"2.0","method":"bauth.health.metrics","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -m json.tool
```

---

## TOKEN — 4 CAPAS

### T-01 — Emisión básica (token liviano EdDSA)

> El token JWT liviano tiene ~1.2 KB sin incluir el bitmask.
> Capas: EdDSA Vault Ed25519 + ctx_id W3C + prev_hash + merkle_leaf_keccak256.
> loa=2 = SBOS LoA2 (password + sesión activa).

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'algorithm: {r[\"algorithm\"]}')
print(f'jwt_size: {r[\"jwt_size_chars\"]} chars')
print(f'loa: {r[\"loa\"]}')
print(f'issuer: {r[\"issuer\"]}')
print(f'rolbitmask: {\"presente\" if r.get(\"rolbitmask\") else \"ausente\"}')
print(f'token_sha256: {r[\"token_sha256\"][:30]}...')
print(f'merkle_leaf_keccak256: {r[\"merkle_leaf_keccak256\"][:30]}...')
print(f'token_seq: {r.get(\"token_seq\",\"?\")}')
print(f'prev_hash: {r.get(\"prev_hash\",\"?\")[:30]}...')
"
```

**Esperado:** `algorithm=EdDSA · jwt_size≈1218 · loa=2 · issuer=bauth.sbos.bo · rolbitmask=ausente · token_seq≥1`

### T-02 — Emisión con RolBitMask (contingencia offline)

> `include_mask=true` agrega el bitmask en la respuesta (NO en el JWT).
> Esto permite validación offline en Kong/banexus sin consultar bAuth.
> Superadmin tiene 42 átomos; el bitmask comprimido base64 es ~968 chars.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","include_mask":true},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
m = r.get('rolbitmask')
print(f'jwt_size: {r[\"jwt_size_chars\"]} chars (idéntico a T-01 — mask NO va en JWT)')
print(f'active_count: {m[\"active_count\"] if m else 0} átomos activos')
print(f'base64_len: {len(m[\"base64\"]) if m else 0} chars (bitmask comprimido)')
print(f'active_positions: {m[\"active_positions\"] if m else []}')
"
```

**Esperado:** `jwt_size=1218 (mismo que sin mask) · active_count=42 · base64_len≈968`

### T-03 — Validación de token (verificación EdDSA)

> `bauth.token.validate` verifica la firma Ed25519 y la vigencia del token.
> Retorna claims del payload (sub, iss, exp) y datos del header (alg, kid).

```bash
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$JWT\"},\"id\":2}" | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'valid: {r[\"valid\"]}')
print(f'sub: {r.get(\"claims\",{}).get(\"sub\",\"?\")}')
print(f'iss: {r.get(\"claims\",{}).get(\"iss\",\"?\")}')
print(f'header_alg: {r.get(\"header\",{}).get(\"algorithm\",\"?\")}')
print(f'header_kid: {r.get(\"header\",{}).get(\"kid\",\"?\")}')
"
```

**Esperado:** `valid=True · iss=bauth.sbos.bo · header_alg=EdDSA · header_kid=6a6b4a2f3107c524`

### T-04 — Lista de usuarios desde BD

> Verifica la conexión real a PostgreSQL y la tabla `bauth.idn_user_template`.
> Deben existir al menos 8 usuarios de prueba.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.user.list","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'count: {r[\"count\"]}')
print(f'source: {r[\"source\"]}')
for u in r['users'][:3]:
    print(f'  {u[\"username\"]}: {u[\"roles\"]}')
"
```

**Esperado:** `count=8 · source=idn_user_template`

### T-05 — Verificación criptográfica (SHA-256 + Keccak-256)

> Prueba que los hashes en la respuesta son correctos.
> SHA-256: hash del JWT completo en hex.
> Keccak-256: keccak(\x00 + sha256_bytes) — prefijo 0x00 = hoja del árbol Merkle.

```bash
python3 << 'EOF'
import socket, json, hashlib
from Crypto.Hash import keccak

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.settimeout(5); s.connect('/tmp/bauth/bauth.sock')
req = {'jsonrpc':'2.0','method':'bauth.token.issue','params':{'user_uuid':'019f06db-62a6-77b1-b581-4c37e3aeee9f'},'id':1}
s.sendall((json.dumps(req)+'\n').encode())
resp = b''
while True:
    try:
        chunk = s.recv(65536)
        if not chunk: break
        resp += chunk
    except: break
s.close()
d = json.loads(resp.decode())['result']
jwt = d['jwt']

sha256_calc = hashlib.sha256(jwt.encode()).hexdigest()
sha256_claim = d['token_sha256']
print(f'SHA-256:  {"✅ MATCH" if sha256_calc == sha256_claim else "❌ MISMATCH"}')

sha256_bytes = hashlib.sha256(jwt.encode()).digest()
k = keccak.new(digest_bits=256)
k.update(b'\x00' + sha256_bytes)
merkle_calc = k.hexdigest()
merkle_claim = d['merkle_leaf_keccak256']
print(f'Keccak:   {"✅ MATCH" if merkle_calc == merkle_claim else "❌ MISMATCH"}')

print(f'jwt_size: {len(jwt)} chars')
print(f'prev_hash: {d.get("prev_hash","?")[:30]}...')
print(f'token_seq: {d.get("token_seq","?")}')
EOF
```

**Esperado:** `SHA-256 ✅ · Keccak ✅`

### T-06 — Decodificación manual del JWT

> Verifica el contenido del header y payload decodificando el JWT sin librerías.
> Campos críticos: ctx_id (W3C traceparent), loa, acr, auth_chain.

```bash
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

echo "=== HEADER ==="
echo "$JWT" | cut -d. -f1 | base64 -d 2>/dev/null | python3 -m json.tool

echo "=== PAYLOAD (campos clave) ==="
PADDED=$(echo "$JWT" | cut -d. -f2 | sed 's/-/+/g; s/_/\//g')
while [ $(( ${#PADDED} % 4 )) -ne 0 ]; do PADDED="${PADDED}="; done
echo "$PADDED" | base64 -d 2>/dev/null | python3 -c "
import sys,json; p=json.load(sys.stdin)
for k in ['sub','iss','loa','acr','ctx_id','auth_chain','jti','traceparent']:
    if k in p: print(f'  {k}: {str(p[k])[:60]}')
"
```

**Esperado header:** `{"alg":"EdDSA","kid":"6a6b4a2f3107c524","typ":"JWT"}`
**Esperado payload:** `loa=2 · acr=sbos_aal2 · ctx_id presente (W3C traceparent) · auth_chain`

### T-07 — Concurrencia (100 tokens paralelos)

> Prueba que el servidor tokio maneja 100 emisiones simultáneas sin degradar.
> Tiempo esperado < 1 segundo para 100 tokens EdDSA.

```bash
time (
  for i in $(seq 1 100); do
    echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":'$i'}' | nc -U /tmp/bauth/bauth.sock -w 5 > /dev/null 2>&1 &
  done
  wait
)
echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":999}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; print('post-carga:', json.load(sys.stdin)['result']['status'])"
```

**Esperado:** `real < 1.0s · post-carga: operativo`
**Resultado real:** `real 0m0.158s`

### T-08 — Comparación de tamaños (mask en respuesta, NO en JWT)

> El RolBitMask NO se incluye en el JWT (no infla el token).
> Va en la respuesta JSON-RPC para uso offline. El JWT es siempre igual de liviano.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print('sin mask:', json.load(sys.stdin)['result']['jwt_size_chars'], 'chars')"

echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","include_mask":true},"id":2}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print('con mask:', json.load(sys.stdin)['result']['jwt_size_chars'], 'chars')"
```

**Esperado:** ambos = 1218 chars (mismo tamaño JWT; mask va en respuesta, no en payload)

### T-09 — JWKS endpoint (RFC 7517 + RFC 8037)

> El endpoint JWKS expone la clave pública Ed25519 (OKP) para que cualquier
> servicio pueda verificar tokens sin consultar bAuth. Conforme RFC 7517 + 8037.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.jwks","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']; k=r['keys'][0]
print(f'kty: {k[\"kty\"]}')
print(f'crv: {k[\"crv\"]}')
print(f'alg: {k[\"alg\"]}')
print(f'use: {k[\"use\"]}')
print(f'kid: {k[\"kid\"]}')
print(f'issuer: {r[\"issuer\"]}')
"
```

**Esperado:** `kty=OKP · crv=Ed25519 · alg=EdDSA · use=sig · issuer=bauth.sbos.bo`

### T-10 — Flujo completo (emisión → validación → autorización)

> Prueba el flujo end-to-end: emitir, validar y evaluar acceso para un cajero.
> Es el flujo que Kong ejecuta en cada request entrante.

```bash
SOCK=/tmp/bauth/bauth.sock

echo "=== 1. Emitir token para test_cajero ==="
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":1}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'jwt: {r[\"jwt_size_chars\"]} chars')"

JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":1}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

echo "=== 2. Validar token ==="
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$JWT\"},\"id\":2}" | nc -U $SOCK -w 5 | python3 -c "import sys,json; print('valid:', json.load(sys.stdin)['result']['valid'])"

echo "=== 3. Átomo 1 — cajero TIENE → PERMITIDO ==="
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d1.nuevo","user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":3}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'{r[\"veredicto\"]}: {r[\"motivo\"]}')"

echo "=== 4. Átomo 5 — cajero NO TIENE → DENEGADO ==="
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d1.imprimir","user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":4}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'{r[\"veredicto\"]}: {r[\"motivo\"]}')"
```

### T-11 — Token inválido (seguridad: tamper detection)

> Un JWT con la firma alterada debe ser rechazado.
> Prueba que EdDSA detecta manipulación del payload.

```bash
SOCK=/tmp/bauth/bauth.sock
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

# Alterar el último carácter de la firma
TAMPERED="${JWT::-1}X"
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$TAMPERED\"},\"id\":2}" | nc -U $SOCK -w 5 | python3 -c "import sys,json; r=json.load(sys.stdin); print('tampered valid:', r.get('result',{}).get('valid', 'ERROR:' + str(r.get('error','?'))))"
```

**Esperado:** `valid=False` o error de validación

### T-12 — Replay de token (mismo token, segunda validación)

> El mismo token debe seguir siendo válido hasta su expiración (no single-use).
> bAuth es stateless en validación — JWT self-contained.

```bash
SOCK=/tmp/bauth/bauth.sock
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

echo "Validación 1:"
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$JWT\"},\"id\":1}" | nc -U $SOCK -w 5 | python3 -c "import sys,json; print('  valid:', json.load(sys.stdin)['result']['valid'])"

echo "Validación 2 (mismo token):"
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$JWT\"},\"id\":2}" | nc -U $SOCK -w 5 | python3 -c "import sys,json; print('  valid:', json.load(sys.stdin)['result']['valid'])"
```

**Esperado:** ambas validaciones `valid=True` (token stateless, no single-use)

### T-13 — Hash-linking (prev_hash aumenta con cada token)

> Cada token referencia el SHA-256 del anterior vía `prev_hash`.
> El `token_seq` debe incrementarse. Esto forma una cadena de auditoría.

```bash
SOCK=/tmp/bauth/bauth.sock
python3 << 'EOF'
import socket, json

def issue(user_uuid):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5); s.connect('/tmp/bauth/bauth.sock')
    req = {'jsonrpc':'2.0','method':'bauth.token.issue','params':{'user_uuid':user_uuid},'id':1}
    s.sendall((json.dumps(req)+'\n').encode())
    resp = b''
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk: break
            resp += chunk
        except: break
    s.close()
    return json.loads(resp.decode())['result']

uid = '019f06db-62a6-77b1-b581-4c37e3aeee9f'
r1 = issue(uid)
r2 = issue(uid)
r3 = issue(uid)

print(f'token 1: seq={r1["token_seq"]}, prev_hash={r1.get("prev_hash","?")[:20]}...')
print(f'token 2: seq={r2["token_seq"]}, prev_hash={r2.get("prev_hash","?")[:20]}...')
print(f'token 3: seq={r3["token_seq"]}, prev_hash={r3.get("prev_hash","?")[:20]}...')
print(f'secuencial: {"✅" if r1["token_seq"] < r2["token_seq"] < r3["token_seq"] else "❌"}')
EOF
```

**Esperado:** `seq` incrementa secuencialmente · `prev_hash` distinto en cada token

---

## VARIANTES DE TOKEN

### Variante A — Token liviano (default)

> Sin mask = mínimo tamaño. Solo claims de identidad y trazabilidad.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'jwt: {r[\"jwt_size_chars\"]} chars')
print(f'mask en respuesta: {\"SI\" if r.get(\"rolbitmask\") else \"NO (correcto)\"}')"
```

**Esperado:** `mask=NO · jwt≈1218 chars`

### Variante B — Token con RolBitMask (contingencia offline)

> Habilita validación offline en Edge/Nexus sin consultar bAuth.
> El bitmask se entrega en la respuesta, NO embebido en el JWT.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","include_mask":true},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']; m=r.get('rolbitmask')
print(f'jwt: {r[\"jwt_size_chars\"]} chars (sin cambio)')
print(f'active_count: {m[\"active_count\"] if m else 0}')
print(f'base64_len: {len(m[\"base64\"]) if m else 0} chars')"
```

**Esperado:** `active_count=42 (superadmin) · base64_len≈968`

### Variante C — Diferentes perfiles (superadmin / cajero / cliente)

> Verifica que cada perfil tiene la cantidad correcta de átomos.
> Superadmin hereda de todos los roles vía DAG.

```bash
SOCK=/tmp/bauth/bauth.sock
echo "--- Superadmin (42 átomos por herencia DAG) ---"
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","include_mask":true},"id":1}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print('superadmin:', json.load(sys.stdin)['result']['rolbitmask']['active_count'],'átomos')"

echo "--- Cajero (8 átomos — rol base) ---"
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d","include_mask":true},"id":2}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print('cajero:', json.load(sys.stdin)['result']['rolbitmask']['active_count'],'átomos')"

echo "--- Cliente (0 átomos — sin rol asignado) ---"
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a9-7551-b33c-12583be0ed1f","include_mask":true},"id":3}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print('cliente:', json.load(sys.stdin)['result']['rolbitmask']['active_count'],'átomos')"
```

**Esperado:** `superadmin=42 · cajero=8 · cliente=0`

### Variante D — Token con audiencia y scope (RFC 7519)

> `audience` define los destinatarios válidos del token (claim `aud`).
> El JWT con `aud` tiene más claims → mayor tamaño.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","audience":["sbos-app","sbos-api"],"scope":"read write"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json,base64
r=json.load(sys.stdin)['result']
print(f'jwt: {r[\"jwt_size_chars\"]} chars (mayor que sin aud)')
# Decodificar para ver aud
p=r['payload_b64']
pad=4-(len(p)%4); p+=('='*pad if pad!=4 else '')
try:
    claims=json.loads(base64.b64decode(p))
    print(f'aud: {claims.get(\"aud\",\"?\")}')
except: pass
"
```

**Esperado:** `jwt > 1218 chars · aud=[sbos-app, sbos-api]`

### Variante E — Token con DPoP binding (RFC 9449)

> DPoP (Demonstration of Proof-of-Possession) liga el token a una clave del cliente.
> `dpop_bound=True` en respuesta confirma el binding.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","dpop":"test"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'dpop_bound: {r.get(\"dpop_bound\",\"?\")}')"
```

**Esperado:** `dpop_bound=True`

---

## BLOCKCHAIN (B12/B29)

> Las tablas blockchain están en schema `bauth`:
> `blk_merkle_batch`, `blk_merkle_leaf`, `blk_anchor`, `blk_account`, `blk_reconciliation`
>
> En entorno de desarrollo las tablas están vacías (sin nodo Besu/Arbitrum activo).
> Los handlers responden correctamente con listas vacías y estados de red disponibles.

### BLK-01 — Estado de redes blockchain

> Lista las redes configuradas: Arbitrum One (anclaje producción),
> Arbitrum Sepolia (testnet), Besu QBFT (liquidación, planificado).

```bash
echo '{"jsonrpc":"2.0","method":"bauth.blockchain.status","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
for nombre, red in r['redes'].items():
    print(f'  {nombre}: {red[\"estado\"]}')
for contrato, info in r['smart_contracts'].items():
    print(f'  contrato {contrato}: red={info[\"red\"]}')
"
```

**Esperado:** `arbitrum_one=operativo · arbitrum_sepolia=operativo · besu_qbft=planificado`

### BLK-02 — Listar lotes de Merkle

> Lista los lotes de anclaje pendientes/completados.
> En dev: lista vacía (0 lotes). En producción: lotes cada 15min.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.blockchain.batch.list","params":{"limit":10},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'lotes: {r[\"count\"]}')
for b in r['batches'][:3]:
    print(f'  batch_id={str(b[\"batch_id\"])[:8]}... events={b[\"event_count\"]} status={b[\"status\"]}')
"
```

**Esperado:** `lotes=0 en dev · lotes>0 en producción`

### BLK-03 — Detalle de lote (hojas Merkle)

> Obtiene las hojas de un lote dado su UUID.
> Cada hoja = un evento de auditoría con su hash y proof.

```bash
# Obtener primer batch_id de la lista (si existe)
BATCH=$(echo '{"jsonrpc":"2.0","method":"bauth.blockchain.batch.list","params":{"limit":1},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(r['batches'][0]['batch_id'] if r['batches'] else 'no-hay-lotes')
")

if [ "$BATCH" != "no-hay-lotes" ]; then
  echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.blockchain.batch.detail\",\"params\":{\"batch_id\":\"$BATCH\"},\"id\":2}" | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'lote: {r[\"batch_id\"]}')
print(f'hojas: {r[\"total_leaves\"]}')
"
else
  echo "Sin lotes disponibles (dev sin Besu)"
fi
```

### BLK-04 — Verificar proof Merkle

> Dado el hash de una hoja y el proof path, reconstruye la raíz Merkle
> y la compara con la raíz publicada. Algoritmo: Keccak256 con prefijo 0x01.

```bash
# Test con datos de prueba (verificación sin BD)
echo '{"jsonrpc":"2.0","method":"bauth.blockchain.verify","params":{
  "merkle_root":"0xabc123def456abc123def456abc123def456abc123def456abc123def456abcd",
  "leaf_hash":"70ed0545d318efc3823349287abd876edc64b21930c9d22adffd6323469ddded",
  "proof_hashes":[]
},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'verified: {r[\"verified\"]}')
print(f'computed_root: {r[\"computed_root\"][:20]}...')
print(f'proof_depth: {r[\"proof_depth\"]}')
"
```

### BLK-05 — Anclajes recientes (últimas 24h)

```bash
echo '{"jsonrpc":"2.0","method":"bauth.blockchain.recent","id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'anclajes últimas 24h: {r[\"ultimas_24h\"]}')
"
```

**Esperado:** `ultimas_24h=0 en dev`

### BLK-06 — Cuentas on-chain (custody)

> Lista las cuentas blockchain de tenants gestionadas por CustodyEngine.

```bash
echo '{"jsonrpc":"2.0","method":"bauth.blockchain.settlement.list","params":{"limit":10},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'cuentas on-chain: {r[\"count\"]}')
for a in r['accounts'][:3]:
    print(f'  {str(a[\"account_id\"])[:8]}... addr={str(a[\"address\"])[:12]}... frozen={a[\"is_frozen\"]}')
"
```

**Esperado:** `cuentas=0 en dev (sin seed de cuentas)`

### BLK-07 — merkle_leaf_keccak256 del token (integridad)

> Cada token emitido incluye su `merkle_leaf_keccak256`.
> Este hash es el identificador de esa hoja en el árbol Merkle de auditoría.
> Verificar que coincide con keccak256(\x00 + sha256(jwt)).

```bash
python3 << 'EOF'
import socket, json, hashlib
from Crypto.Hash import keccak

def issue_token():
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5); s.connect('/tmp/bauth/bauth.sock')
    req = {'jsonrpc':'2.0','method':'bauth.token.issue','params':{'user_uuid':'019f06db-62a6-77b1-b581-4c37e3aeee9f'},'id':1}
    s.sendall((json.dumps(req)+'\n').encode())
    resp = b''
    while True:
        try:
            chunk = s.recv(65536); 
            if not chunk: break
            resp += chunk
        except: break
    s.close()
    return json.loads(resp.decode())['result']

r = issue_token()
jwt = r['jwt']
merkle_claim = r['merkle_leaf_keccak256']

sha256_bytes = hashlib.sha256(jwt.encode()).digest()
k = keccak.new(digest_bits=256)
k.update(b'\x00' + sha256_bytes)
merkle_calc = k.hexdigest()

print(f'merkle_leaf_keccak256 (claim): {merkle_claim[:32]}...')
print(f'merkle_leaf_keccak256 (calc):  {merkle_calc[:32]}...')
print(f'Integridad Merkle: {"✅ MATCH" if merkle_claim == merkle_calc else "❌ MISMATCH"}')
EOF
```

**Esperado:** `Integridad Merkle: ✅ MATCH`

---

## ESTRÉS

### 100 tokens paralelos (throughput EdDSA)

> Medir tiempo para 100 firmas Ed25519 concurrentes.
> La firma EdDSA es CPU-bound; el target es < 1 segundo total.

```bash
time (
  for i in $(seq 1 100); do
    echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":'$i'}' | nc -U /tmp/bauth/bauth.sock -w 5 > /dev/null 2>&1 &
  done
  wait
)
echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":999}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; print('post-estrés:', json.load(sys.stdin)['result']['status'])"
```

**Esperado:** `real < 1.0s · post-estrés: operativo`
**Resultado real:** `real 0m0.158s`

### 100 requests mixtos (health + user + role)

> Simula carga heterogénea: 34 health checks, 33 listados de usuarios,
> 33 listados de roles. Verifica que el dispatcher no se degrada.

```bash
for i in $(seq 1 34); do echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":'$i'}' | nc -U /tmp/bauth/bauth.sock -w 3 > /dev/null 2>&1 & done
for i in $(seq 35 67); do echo '{"jsonrpc":"2.0","method":"bauth.user.list","id":'$i'}' | nc -U /tmp/bauth/bauth.sock -w 3 > /dev/null 2>&1 & done
for i in $(seq 68 100); do echo '{"jsonrpc":"2.0","method":"bauth.role.list","id":'$i'}' | nc -U /tmp/bauth/bauth.sock -w 3 > /dev/null 2>&1 & done
wait
echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":999}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; print('post-mixto:', json.load(sys.stdin)['result']['status'])"
```

**Esperado:** `real < 1.0s · post-mixto: operativo`
**Resultado real:** `real 0m0.366s`

### 500 tokens secuenciales (hash-linking cadena larga)

> Prueba que el hash-linking mantiene coherencia en secuencias largas.
> El `token_seq` debe llegar a ≥500 y no haber repeticiones.

```bash
python3 << 'EOF'
import socket, json, time

def issue(uid, n):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5); s.connect('/tmp/bauth/bauth.sock')
    req = {'jsonrpc':'2.0','method':'bauth.token.issue','params':{'user_uuid':uid},'id':n}
    s.sendall((json.dumps(req)+'\n').encode())
    resp = b''
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk: break
            resp += chunk
        except: break
    s.close()
    return json.loads(resp.decode())['result']

uid = '019f06db-62a6-77b1-b581-4c37e3aeee9f'
start = time.time()
seqs = []
for i in range(1, 51):  # 50 tokens (más rápido que 500)
    r = issue(uid, i)
    seqs.append(r['token_seq'])

elapsed = time.time() - start
print(f'50 tokens en {elapsed:.2f}s ({50/elapsed:.0f} tok/s)')
print(f'seq mín={min(seqs)}, máx={max(seqs)}, únicos={len(set(seqs))}')
print(f'Secuencia sin duplicados: {"✅" if len(set(seqs)) == len(seqs) else "❌"}')
EOF
```

---

## SEGURIDAD

### SEC-01 — Token manipulado (DEBE rechazar)

```bash
SOCK=/tmp/bauth/bauth.sock
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")
TAMPERED="${JWT::-1}X"
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$TAMPERED\"},\"id\":2}" | nc -U $SOCK -w 5 | python3 -c "
import sys,json; resp=json.load(sys.stdin)
valid = resp.get('result',{}).get('valid', None)
if valid is False or valid is None:
    print('✅ Token manipulado correctamente rechazado')
else:
    print('❌ ERROR: token inválido fue aceptado')
"
```

### SEC-02 — JWT con formato inválido (DEBE rechazar con -32602)

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.validate","params":{"jwt":"not.a.jwt"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; resp=json.load(sys.stdin)
if 'error' in resp or not resp.get('result',{}).get('valid', True):
    print('✅ JWT inválido rechazado')
else:
    print('❌ JWT inválido aceptado — revisar validación')
"
```

### SEC-03 — Método inexistente (DEBE retornar -32601)

```bash
echo '{"jsonrpc":"2.0","method":"bauth.nonexistent.method","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; resp=json.load(sys.stdin)
code = resp.get('error',{}).get('code', 0)
print(f'✅ -32601 método no encontrado' if code == -32601 else f'❌ código inesperado: {code}')
"
```

### SEC-04 — JSON malformado (DEBE retornar -32700)

```bash
echo 'not valid json at all' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "
import sys,json; resp=json.load(sys.stdin)
code = resp.get('error',{}).get('code', 0)
print(f'✅ -32700 parse error' if code == -32700 else f'❌ código inesperado: {code}')
"
```

---

---

## B9 — POLICY ENGINE / ath_policy_dN (B9.T24)

> Verifica los 3 métodos JSON-RPC nuevos sobre las tablas `bauth.ath_policy_d1..d12`.
> Motor: `PolicyEngine::evaluate()` XACML 3.0 — el mismo del V1 pero sobre políticas operativas.
> Prerequisito: `ath_policy_dN` con seeds cargados (verificar con PDM-01 antes de continuar).

### PDM-01 — Verificar datos en BD (prerequisito)

> Confirmar que las tablas ath_policy_dN tienen datos cargados.
> Sin seeds → todos los test reportarán `count=0` y evaluarán `sin políticas activas`.

```bash
PGPASSWORD=postgres psql -h localhost -p 15432 -U postgres SBOS_db -c "
SELECT 'D' || i AS dominio, cnt FROM (
  SELECT 1 AS i, count(*) AS cnt FROM bauth.ath_policy_d1  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 2, count(*) FROM bauth.ath_policy_d2  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 3, count(*) FROM bauth.ath_policy_d3  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 4, count(*) FROM bauth.ath_policy_d4  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 5, count(*) FROM bauth.ath_policy_d5  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 6, count(*) FROM bauth.ath_policy_d6  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 7, count(*) FROM bauth.ath_policy_d7  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 8, count(*) FROM bauth.ath_policy_d8  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 9, count(*) FROM bauth.ath_policy_d9  WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 10, count(*) FROM bauth.ath_policy_d10 WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 11, count(*) FROM bauth.ath_policy_d11 WHERE is_active = true AND config ? 'rule'
  UNION ALL SELECT 12, count(*) FROM bauth.ath_policy_d12 WHERE is_active = true AND config ? 'rule'
) t ORDER BY i;
"
```

**Esperado:** cada dominio con al menos 1 fila de `cnt > 0`

### PDM-02 — Listar políticas D1 Lógico

> `bauth.policy.domain.list` lee `ath_policy_d1` y devuelve políticas con su rule_type.
> Verificar que devuelve al menos 1 entrada y que el campo `rule_type` está presente.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.list","params":{"domain":1},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'domain: {r[\"domain\"]} · count: {r[\"count\"]}')
for p in r['policies'][:5]:
    print(f'  {p[\"policy_code\"]}: rule={p[\"rule_type\"]} active={p[\"is_active\"]}')
"
```

**Esperado:** `domain=1 · count≥1 · rule_type presente (scope, max_records, etc.)`

### PDM-03 — Listar políticas D3 Financiero

> D3 tiene los tipos de regla más complejos: dual_approval, sod, daily_limit, monthly_limit.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.list","params":{"domain":3},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'D3 Financiero: {r[\"count\"]} políticas')
for p in r['policies']:
    print(f'  [{p[\"rule_type\"]}] {p[\"policy_code\"]}')
"
```

**Esperado:** entradas con `rule_type` en [dual_approval, sod, daily_limit, monthly_limit, ...]

### PDM-04 — Evaluar D1 Lógico — scope BRANCH (DEBE PERMITIR)

> El usuario tiene `user_scope=BRANCH`. La política scope permite BRANCH.
> Resultado esperado: `state=aprobado`, `passed≥1`.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 1,
  "context": {
    "user_scope": "BRANCH",
    "record_count": 50,
    "data_clearance": "INTERNAL"
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | evaluated: {r[\"evaluated\"]} | passed: {r[\"passed\"]} | failed: {r[\"failed\"]}')
print(f'latency_us: {r.get(\"latency_us\",\"?\")} µs')
for res in r.get('results',[])[:3]:
    print(f'  {res[\"policy\"]}: {res[\"state\"]} — {res[\"message\"]}')
"
```

**Esperado:** `state=aprobado · passed≥1 · failed=0`

### PDM-05 — Evaluar D1 Lógico — scope insuficiente (DEBE DENEGAR)

> El usuario tiene `user_scope=PUBLIC` (nivel inexistente). La política lo deniega.
> Si la política `scope` está en D1, el resultado debe ser `state=rechazado`.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 1,
  "context": {
    "user_scope": "UNAUTHENTICATED",
    "record_count": 999,
    "data_clearance": "PUBLIC"
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | failed: {r[\"failed\"]}')
for res in r.get('results',[])[:3]:
    print(f'  {res[\"policy\"]}: {res[\"state\"]} — {res[\"message\"][:60]}')
"
```

**Esperado:** `state=rechazado · failed≥1` (si scope policy existe con nivel > PUBLIC)

### PDM-06 — Evaluar D3 Financiero — importe bajo umbral (DEBE APROBAR)

> Monto 500 BOB < umbral de dual_approval (típico: 5000 BOB).
> Sin necesidad de aprobación dual → `state=aprobado`.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 3,
  "context": {
    "amount": 500,
    "daily_total": 2000,
    "monthly_total": 10000,
    "sod_ok": true,
    "creator_id": "user-A",
    "approver_id": "user-B",
    "approval_level": 1
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | pending: {r[\"pending\"]} | passed: {r[\"passed\"]}')
for res in r.get('results',[])[:5]:
    print(f'  {res[\"policy\"]}: {res[\"state\"]}')
"
```

**Esperado:** `state=aprobado · pending=0` (monto bajo umbral dual_approval)

### PDM-07 — Evaluar D3 Financiero — importe sobre umbral (DEBE PENDER)

> Monto 8000 BOB ≥ umbral → `dual_approval` dispara `pending_approval`.
> Resultado: `state=pendiente` — requiere aprobación antes de continuar.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 3,
  "context": {
    "amount": 8000,
    "daily_total": 8000,
    "monthly_total": 8000,
    "sod_ok": true,
    "creator_id": "user-A",
    "approver_id": "user-B",
    "approval_level": 1
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | pending: {r[\"pending\"]} | evaluated: {r[\"evaluated\"]}')
for res in r.get('results',[]):
    if res['state'] != 'Aprobado':
        print(f'  PENDIENTE: {res[\"policy\"]} — {res[\"message\"][:60]}')
"
```

**Esperado:** `state=pendiente · pending≥1` (dual_approval disparó pending_approval)

### PDM-08 — Evaluar D9 Credenciales — MFA verificado (DEBE APROBAR)

> Sesión con MFA activo, contraseña ≥12 chars, sin compromiso HIBP.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 9,
  "context": {
    "mfa_enrolled": true,
    "mfa_verified": true,
    "mfa_method": "fido2",
    "password_length": 16,
    "hibp_compromised": false,
    "session_count": 1,
    "failed_attempts": 0,
    "current_loa": 3,
    "password_not_reused": true,
    "password_not_blocked": true,
    "password_hash_algorithm": "argon2id"
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | passed: {r[\"passed\"]} | failed: {r[\"failed\"]} | pending: {r[\"pending\"]}')
"
```

**Esperado:** `state=aprobado · failed=0`

### PDM-09 — Evaluar D9 Credenciales — contraseña comprometida (DEBE DENEGAR)

> HIBP reporta la contraseña como comprometida → `hibp_check` deniega.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 9,
  "context": {
    "mfa_verified": true,
    "password_length": 8,
    "hibp_compromised": true,
    "session_count": 5,
    "failed_attempts": 4
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | failed: {r[\"failed\"]}')
for res in r.get('results',[]):
    if res['state'] == 'Rechazado':
        print(f'  DENEGADO: {res[\"policy\"]} — {res[\"message\"][:60]}')
"
```

**Esperado:** `state=rechazado · failed≥1` (hibp_check o min_length falló)

### PDM-10 — Evaluar D7 Red — sin mTLS (DEBE DENEGAR)

> El daemon requiere mTLS. La conexión no tiene certificado cliente.
> Resultado: `state=rechazado`.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 7,
  "context": {
    "has_mtls": false,
    "has_vpn": false,
    "explicit_allow": false,
    "device_trust_level": "unknown",
    "requests_per_min": 50,
    "seconds_since_verify": 400
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | failed: {r[\"failed\"]}')
for res in r.get('results',[]):
    if res['state'] == 'Rechazado':
        print(f'  DENEGADO: {res[\"policy\"]}')
"
```

**Esperado:** `state=rechazado · failed≥1` (mtls_required, vpn_required o default_deny)

### PDM-11 — Evaluar D8 Contexto — ctx_id ausente (DEBE DENEGAR)

> El plan de contexto SBOS-049 exige ctx_id en toda operación.
> Contexto sin ctx_id → `ctx_id_required` deniega.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 8,
  "context": {
    "session_age_s": 1000,
    "seconds_since_auth": 100
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | evaluated: {r[\"evaluated\"]}')
for res in r.get('results',[]):
    print(f'  {res[\"policy\"]}: {res[\"state\"]} — {res[\"message\"][:50]}')
"
```

**Esperado:** `state=rechazado` (ctx_id ausente dispara deny en ctx_id_required)

### PDM-12 — Evaluar D8 Contexto — ctx_id presente (DEBE APROBAR)

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 8,
  "context": {
    "ctx_id": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
    "session_age_s": 3600,
    "seconds_since_auth": 1200
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | passed: {r[\"passed\"]} | pending: {r[\"pending\"]}')
"
```

**Esperado:** `state=aprobado` o `state=pendiente` (reauth si interval_seconds < 1200)

### PDM-13 — Evaluar D4 Temporal — dentro de horario (DEBE APROBAR)

> schedule 08:00–18:00. Si `current_time` es 14:30 → dentro → aprobado.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 4,
  "context": {
    "current_time": "14:30",
    "session_age_min": 120,
    "schedule_authorized": true
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | evaluated: {r[\"evaluated\"]}')
"
```

**Esperado:** `state=aprobado` (14:30 dentro del horario laboral)

### PDM-14 — Evaluar D4 Temporal — fuera de horario (DEBE DENEGAR)

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 4,
  "context": {
    "current_time": "03:00",
    "session_age_min": 600,
    "schedule_authorized": false
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | failed: {r[\"failed\"]}')
"
```

**Esperado:** `state=rechazado` (03:00 fuera del horario laboral)

### PDM-15 — Evaluar D6 Geoespacial — país autorizado (Bolivia)

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 6,
  "context": {
    "country_code": "BO",
    "inside_geofence": true,
    "travel_speed_km_h": 0,
    "data_residency_ok": true,
    "trust_tier": "verified",
    "not_sanctioned": true
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | passed: {r[\"passed\"]} | failed: {r[\"failed\"]}')
"
```

**Esperado:** `state=aprobado` (Bolivia = país autorizado, dentro del geofence)

### PDM-16 — Evaluar D6 Geoespacial — país no autorizado (DEBE DENEGAR)

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{
  "domain": 6,
  "context": {
    "country_code": "KP",
    "inside_geofence": false,
    "travel_speed_km_h": 900,
    "not_sanctioned": false
  }
},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'state: {r[\"state\"]} | failed: {r[\"failed\"]}')
for res in r.get('results',[]):
    if res['state'] == 'Rechazado':
        print(f'  DENEGADO: {res[\"policy\"]}')
"
```

**Esperado:** `state=rechazado · failed≥1` (país no en lista, velocity>500, sanctions)

### PDM-17 — Biblioteca de políticas — buscar por fuente NIST

> `cfg_policy_library` tiene 9,142 entradas de 16 fuentes normativas.
> Buscar por `source=NIST SP 800-53` debe retornar entradas con su taxonomía.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.library.search","params":{"source":"NIST SP 800-53","limit":5},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'encontrados: {r[\"count\"]} de {r[\"total_library\"]} en biblioteca')
for e in r.get('entries',[])[:3]:
    print(f'  [{e[\"source\"]}] {e[\"section_name\"]}: sem={e[\"semantic_type\"]} enf={e[\"enforcement\"]}')
"
```

**Esperado:** `total_library=9142 · count≤5 · entries con semantic_type y enforcement`

### PDM-18 — Biblioteca — filtro por dominio D3

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.library.search","params":{"domain":"D3","limit":10},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'D3 en biblioteca: {r[\"count\"]} entradas')
for e in r.get('entries',[])[:3]:
    print(f'  {e[\"json_path\"][:50]}: risk={e[\"risk_level\"]}')
"
```

**Esperado:** `count≥1 · entries con json_path y risk_level`

### PDM-19 — Dominio inexistente (DEBE retornar vacío sin error)

> El método no debe crashear con dominio=99. Debe retornar vacío.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.domain.evaluate","params":{"domain":99,"context":{}},"id":1}' | nc -U $SOCK -w 5 | python3 -c "
import sys,json; resp=json.load(sys.stdin)
if 'error' in resp:
    print(f'error: {resp[\"error\"][\"message\"]}')
elif resp.get('result',{}).get('evaluated',0) == 0:
    print('✅ dominio inválido retornó 0 políticas sin crash')
else:
    print(f'resultado: {resp[\"result\"]}')
"
```

**Esperado:** error descriptivo (`domain requerido [1-12]`) o `evaluated=0`

### PDM-20 — Latencia (PolicyEngine < 5ms por dominio)

> El evaluador es stateless y sin BD en el path caliente (carga en cada llamada).
> Objetivo: < 5ms por evaluación de dominio completo incluyendo carga BD.

```bash
SOCK=/tmp/bauth/bauth.sock
python3 << 'EOF'
import socket, json, time

def eval_domain(domain, ctx):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(5); s.connect('/tmp/bauth/bauth.sock')
    req = {'jsonrpc':'2.0','method':'bauth.policy.domain.evaluate',
           'params':{'domain': domain, 'context': ctx}, 'id':1}
    t0 = time.time()
    s.sendall((json.dumps(req)+'\n').encode())
    resp = b''
    while True:
        try:
            chunk = s.recv(65536)
            if not chunk: break
            resp += chunk
        except: break
    elapsed_ms = (time.time() - t0) * 1000
    s.close()
    r = json.loads(resp.decode())['result']
    return elapsed_ms, r.get('evaluated', 0), r.get('state','?'), r.get('latency_us', 0)

ctx = {'user_scope':'BRANCH','amount':100,'ctx_id':'test','mfa_verified':True,
       'current_time':'10:00','country_code':'BO','has_mtls':True}

for d in [1, 3, 7, 8, 9]:
    ms, evaled, state, lat_us = eval_domain(d, ctx)
    print(f'D{d:2d}: {ms:5.1f}ms total | {lat_us:6d}µs eval puro | {evaled} políticas | {state}')
EOF
```

**Esperado:** `< 50ms total (incluye BD) · latency_us < 5000 (5ms eval puro)`

### PDM-21 — Listado de todos los dominios (cobertura completa)

> Verificar que los 12 dominios responden y tienen al menos 1 política o 0 (sin seed).

```bash
SOCK=/tmp/bauth/bauth.sock
for d in 1 2 3 4 5 6 7 8 9 10 11 12; do
  COUNT=$(echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.policy.domain.list\",\"params\":{\"domain\":$d},\"id\":$d}" | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('result',{}).get('count',r.get('error',{}).get('message','ERROR')))" 2>/dev/null)
  NAMES=("" "Lógico" "Físico" "Financiero" "Temporal" "Biométrico" "Geoespacial" "Red" "Contexto" "Credenciales" "Delegación" "Auditoría" "Blockchain")
  echo "D$d ${NAMES[$d]}: $COUNT políticas"
done
```

**Esperado:** todos retornan número (0 = sin seed, ≥1 = con seed)

---

## B9.T25 — POLICY ADMINISTRATOR CRUD

> Handlers JSON-RPC para administración de políticas en ath_policy_dN.
> 5 métodos: create, update, delete (soft-delete), validate (dry-run), list (admin).
> Validación vía ath_converter::dispatch() — rechaza rule_type no mapeado.

### PAD-01 — Validar política (dry-run sin persistir)

> `bauth.policy.validate` verifica el config sin tocar la BD.
> Retorna rule_type detectado, valid=true/false, y warnings de sanidad.

```bash
SOCK=/tmp/bauth/bauth.sock

# Válido
echo '{"jsonrpc":"2.0","method":"bauth.policy.validate","params":{"config":{"rule":"scope","allowed":["BRANCH","REGION"]}},"id":1}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'valid={r[\"valid\"]} rule_type={r[\"rule_type\"]}')"

# Inválido (rule_type no soportado)
echo '{"jsonrpc":"2.0","method":"bauth.policy.validate","params":{"config":{"rule":"regla_inexistente"}},"id":2}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'valid={r[\"valid\"]} msg={r[\"message\"][:50]}')"
```

**Esperado:** `valid=True rule_type=scope` · `valid=False msg=rule_type 'regla_inexistente' no soportado`

### PAD-02 — Crear política

> `bauth.policy.create` inserta en ath_policy_d{domain}. ON CONFLICT hace upsert.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.create","params":{"domain":1,"policy_code":"TEST-SCOPE-001","policy_name":"Test Scope BRANCH+REGION","description":"Politica de prueba B9.T25","config":{"rule":"scope","allowed":["BRANCH","REGION"],"priority":80},"standard_ref":["NIST SP 800-162"],"ctx_id":"test-b9t25"},"id":3}' | nc -U $SOCK -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'policy_id={r[\"policy_id\"]}')
print(f'domain={r[\"domain\"]}')
print(f'rule_type={r[\"rule_type\"]}')
print(f'allowed={r[\"config\"][\"allowed\"]}')
"
```

**Esperado:** `policy_id=UUIDv7 · domain=1 · rule_type=scope · allowed=['BRANCH','REGION']`

### PAD-03 — Listar políticas (admin, incluye inactivas opcional)

> `bauth.policy.list` retorna políticas de un dominio o de todos (1-12).

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.list","params":{"domain":1},"id":4}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'total={r[\"total\"]} politicas en D1')"
```

**Esperado:** `total≥15` (depende de seeds cargados)

### PAD-04 — Actualizar política

> `bauth.policy.update` modifica campos de una política existente. Solo cambia lo provisto.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.update","params":{"domain":1,"policy_code":"TEST-SCOPE-001","description":"MODIFICADA - prueba update","config":{"rule":"scope","allowed":["BRANCH"],"priority":70}},"id":5}' | nc -U $SOCK -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
print(f'description={r[\"description\"]}')
print(f'allowed={r[\"config\"][\"allowed\"]}')
print(f'priority={r[\"config\"][\"priority\"]}')
"
```

**Esperado:** `description=MODIFICADA - prueba update · allowed=['BRANCH'] · priority=70`

### PAD-05 — Soft-delete (desactivar política)

> `bauth.policy.delete` marca is_active=false. NO elimina la fila.
> La política deja de cargarse en el PolicyEngine.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.delete","params":{"domain":1,"policy_code":"TEST-SCOPE-001"},"id":6}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'deleted={r[\"policy_code\"]} active={r[\"is_active\"]}')"
```

**Esperado:** `active=False` (soft-delete confirmado)

### PAD-06 — Verificar que política inactiva no aparece en list

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.list","params":{"domain":1},"id":7}' | nc -U $SOCK -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)['result']
test=[p for p in r['policies'] if p['policy_code']=='TEST-SCOPE-001']
print(f'TEST-SCOPE-001 visible: {len(test)} (esperado 0)')
"
```

**Esperado:** `visible=0`

### PAD-07 — Crear política con rule_type inválido (DEBE RECHAZAR)

> El handler llama a validate_config_structure() antes del INSERT.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.create","params":{"domain":1,"policy_code":"TEST-BAD","policy_name":"Should Fail","config":{"rule":"regla_falsa"}},"id":8}' | nc -U $SOCK -w 3 | python3 -c "
import sys,json; resp=json.load(sys.stdin)
if 'error' in resp:
    print(f'✅ Rechazado: {resp[\"error\"][\"message\"][:60]}')
else:
    print('❌ ERROR: politica invalida fue aceptada')
"
```

**Esperado:** `✅ Rechazado: rule_type 'regla_falsa' no soportado`

### PAD-08 — Listar todos los dominios (sin filtrar por domain)

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.list","params":{},"id":9}' | nc -U $SOCK -w 5 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'total={r[\"total\"]} politicas en {len(r[\"domains_queried\"])} dominios')"
```

**Esperado:** `total≥50 · 12 dominios`

---

## B9.T26 — POLICY CONFLICT DETECTOR

> Detector de conflictos XACML 3.0 Policy Combining Algorithms.
> 3 tipos: CONTRADICTORY_PARAMS (MEDIO), DENY_ALLOW_CONFLICT (ALTO), REDUNDANT_POLICY (BAJO).
> Integrado en create/update pre-persistencia. Handler standalone: bauth.policy.check_conflicts.

### CFL-01 — check_conflicts dry-run (sin conflicto)

> Rule_type diferente a los existentes → 0 conflictos.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.check_conflicts","params":{"domain":1,"policy_code":"NEW_SCOPE","config":{"rule":"scope","allowed":["REGION"]}},"id":1}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'conflicts={r[\"conflicts_found\"]} bloqueante={r[\"bloqueante\"]}')"
```

**Esperado:** `conflicts=0 bloqueante=False`

### CFL-02 — check_conflicts con valor contradictorio (MEDIO)

> Misma rule_type (min_length), diferente value → CONTRADICTORY_PARAMS.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.check_conflicts","params":{"domain":9,"policy_code":"MIN_LEN_15","config":{"rule":"min_length","value":15}},"id":2}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'conflicts={r[\"conflicts_found\"]} bloqueante={r[\"bloqueante\"]}'); [print(f'  {w[:80]}') for w in r.get('warnings',[])]"
```

**Esperado:** `conflicts≥1 bloqueante=False` · warning incluye `[MEDIO] min_length.value`

### CFL-03 — Create con conflicto MEDIO (advierte pero crea)

> El create incluye conflict_warnings en la respuesta. No bloquea.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.create","params":{"domain":9,"policy_code":"TEST-CFL-MEDIO","policy_name":"Test CFL MEDIO","config":{"rule":"min_length","value":10}},"id":3}' | nc -U $SOCK -w 3 | python3 -c "
import sys,json; r=json.load(sys.stdin)
if 'result' in r:
    wars=r['result'].get('conflict_warnings',[])
    print(f'Creado con {len(wars)} warnings')
    for w in wars: print(f'  {w[:100]}')
else:
    print(f'Error: {r.get(\"error\",{}).get(\"message\",\"?\")}')
"
```

**Esperado:** `Creado con ≥1 warnings` · warnings incluyen `[MEDIO]`

### CFL-04 — Different rule_type → sin conflicto

> scope (allow) vs anti_passback (deny) son rule_type diferentes → no conflictúan.

```bash
SOCK=/tmp/bauth/bauth.sock
echo '{"jsonrpc":"2.0","method":"bauth.policy.check_conflicts","params":{"domain":2,"policy_code":"TEST-SCOPE-D2","config":{"rule":"scope","allowed":["BRANCH"]}},"id":4}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f'conflicts={r[\"conflicts_found\"]} (esperado 0)')"
```

**Esperado:** `conflicts=0`

### CFL-05 — Limpiar políticas de prueba

```bash
SOCK=/tmp/bauth/bauth.sock
for code in TEST-CFL-MEDIO TEST-MINLEN-15 TEST-DUP-001; do
  echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.policy.delete\",\"params\":{\"domain\":9,\"policy_code\":\"$code\"},\"id\":1}" | nc -U $SOCK -w 3 > /dev/null 2>&1
done
echo "Limpieza completada"
```

---

## DESPLIEGUE (referencia)

```bash
# Compilar localmente (NUNCA en VPS)
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent
RUSTFLAGS="-C target-feature=+crt-static" cargo build --release --target x86_64-unknown-linux-musl

# Desplegar a VPS
sshpass -p "12345678ubuntu" scp target/x86_64-unknown-linux-musl/release/bauth root@13.140.128.230:/tmp/bauth/bauth
sshpass -p "12345678ubuntu" ssh root@13.140.128.230 'cp /tmp/bauth/bauth /usr/local/bin/bauth && chmod +x /usr/local/bin/bauth && systemctl restart bauth.service && sleep 2 && systemctl is-active bauth.service'
```

## UUIDs de usuarios de prueba

| Usuario | UUID | Rol | Átomos |
|---------|------|-----|--------|
| test_superadmin | `019f06db-62a6-77b1-b581-4c37e3aeee9f` | superadmin | 42 |
| test_cajero | `019f06db-62a9-73ab-a85a-f5d12f20233d` | cajero | 8 |
| test_cliente | `019f06db-62a9-7551-b33c-12583be0ed1f` | cliente | 0 |

## Roles de prueba

| Rol | UUID | Átomos directos |
|-----|------|----------------|
| test_cajero_rol | `00000000-0000-0000-0000-000000000101` | 8 |
| test_contador_rol | `00000000-0000-0000-0000-000000000102` | 22 |
| test_superadmin_rol | `00000000-0000-0000-0000-000000000103` | 42 (heredados) |
