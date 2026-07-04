# TOKEN bAuth — Comandos de Prueba

**Fecha:** 2026-06-27 · **Binario:** `/usr/local/bin/bauth` · **Socket:** `/tmp/bauth/bauth.sock`

Todos los comandos se ejecutan en la VPS (`ssh root@13.140.128.230`).

---

## 1. EMISIÓN BÁSICA — Token liviano (solo identidad)

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -m json.tool
```

**Esperado:**
- `algorithm`: `EdDSA`
- `jwt_size_chars`: ~1112
- `jwt`: string JWT con 3 partes separadas por `.`
- `merkle_leaf_keccak256`: hash de 64 caracteres hex
- `token_sha256`: hash de 64 caracteres hex
- `valid`: True (si se valida después)

---

## 2. EMISIÓN CON ROLBITMASK — Cookie para contingencia offline

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","include_mask":true},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -m json.tool
```

**Esperado adicional:**
- `rolbitmask.active_count`: 42
- `rolbitmask.base64`: string de 968 caracteres (RolBitMask one-hot)
- `rolbitmask.active_positions`: array con las posiciones activas (42 elementos)

---

## 3. VALIDACIÓN DEL TOKEN

```bash
# Paso 1: Guardar el JWT en variable
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

# Paso 2: Validarlo
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$JWT\"},\"id\":2}" | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -m json.tool
```

**Esperado:**
- `valid`: True
- `subject`: `019f06db-62a6-77b1-b581-4c37e3aeee9f`
- `issuer`: `bauth.sbos.bo`

---

## 4. USUARIOS DISPONIBLES PARA PRUEBAS

| Usuario | UUID | Rol | mask_active |
|---------|------|-----|:---:|
| test_superadmin | `019f06db-62a6-77b1-b581-4c37e3aeee9f` | supervisor (SU) | 42 |
| test_cajero | `019f06db-62a9-73ab-a85a-f5d12f20233d` | cajero (BIZ_N5) | 8 |
| test_contador | `019f06db-62a9-7323-90a3-1c8b2880408f` | contador (BIZ_N4) | 22 |
| test_gerente | `019f06db-62a9-729c-89ea-1a2fcc714c12` | gerente (BIZ_N1) | 42 |
| test_cliente | `019f06db-62a9-7551-b33c-12583be0ed1f` | sin rol | 0 |

Para ver todos:
```bash
echo '{"jsonrpc":"2.0","method":"bauth.user.list","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -m json.tool
```

---

## 5. VERIFICACIÓN CRIPTOGRÁFICA MANUAL

```bash
# Obtener JWT y hashes
RESP=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5)
JWT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")
SHA256_CLAIM=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['token_sha256'])")
MERKLE_CLAIM=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['merkle_leaf_keccak256'])")

# Verificar SHA-256
echo -n "$JWT" | sha256sum
echo "Claim:  $SHA256_CLAIM"
# Deben coincidir

# Verificar Keccak-256 (SHA3-256) del SHA-256
echo -n "$JWT" | sha256sum | awk '{print $1}' | xxd -r -p | sha3sum -a 256
echo "Claim:  $MERKLE_CLAIM"
# Deben coincidir
```

---

## 6. DECODIFICAR JWT MANUALMENTE

```bash
JWT=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt'])")

# Header
echo "$JWT" | cut -d. -f1 | base64 -d 2>/dev/null | python3 -m json.tool

# Payload (agregar padding si es necesario)
PADDED=$(echo "$JWT" | cut -d. -f2 | sed 's/-/+/g; s/_/\//g')
while [ $(( ${#PADDED} % 4 )) -ne 0 ]; do PADDED="${PADDED}="; done
echo "$PADDED" | base64 -d 2>/dev/null | python3 -m json.tool
```

**Claims esperados en el payload:**
- `sub`: UUID del usuario
- `iss`: `bauth.sbos.bo`
- `ctx_id`: string con formato `ctx-<uuid>`
- `loa`: 2
- `acr`: `sbos_aal2`
- `tenant_id`: UUID del tenant
- `iat`, `exp`, `nbf`, `jti`

**NO debe contener:**
- `bos_rol_bitmask`
- `bos_atom_bitmask`
- `rolbitmask`
- `permissions`

---

## 7. PRUEBA DE CONCURRENCIA

```bash
# Emitir 50 tokens en paralelo
for i in $(seq 1 50); do
  echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":'$i'}' | nc -U /tmp/bauth/bauth.sock -w 5 > /dev/null 2>&1 &
done
wait

# Verificar que sigue respondiendo
echo '{"jsonrpc":"2.0","method":"bauth.health.check","id":100}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['status'])"
# Debe decir: operativo
```

---

## 8. COMPARACIÓN DE TAMAÑOS

```bash
# Token sin mask (liviano)
SIZE_SIN=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f"},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt_size_chars'])")

# Token con mask (contingencia)
SIZE_CON=$(echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a6-77b1-b581-4c37e3aeee9f","include_mask":true},"id":1}' | nc -U /tmp/bauth/bauth.sock -w 5 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['jwt_size_chars'])")

echo "Token liviano: $SIZE_SIN chars"
echo "Token + mask:  $SIZE_CON chars"
echo "RolBitMask:    $((SIZE_CON - SIZE_SIN)) chars adicionales en respuesta (NO en JWT)"
```

---

## 9. JWKS — Clave pública para verificación externa

```bash
echo '{"jsonrpc":"2.0","method":"bauth.token.jwks","id":1}' | nc -U /tmp/bauth/bauth.sock -w 3 | python3 -m json.tool
```

**Esperado:**
- `keys[0].kty`: `OKP` (Octet Key Pair = Ed25519)
- `keys[0].crv`: `Ed25519`
- `keys[0].alg`: `EdDSA`
- `keys[0].use`: `sig`
- `keys[0].x`: clave pública en base64url

---

## 10. FLUJO COMPLETO: Token → Validación → Autorización

```bash
SOCK=/tmp/bauth/bauth.sock

# 1. Emitir token para cajero
echo '{"jsonrpc":"2.0","method":"bauth.token.issue","params":{"user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":1}' | nc -U $SOCK -w 5 > /tmp/token.json
JWT=$(python3 -c "import json; print(json.load(open('/tmp/token.json'))['result']['jwt'])")

# 2. Validar token
echo "{\"jsonrpc\":\"2.0\",\"method\":\"bauth.token.validate\",\"params\":{\"jwt\":\"$JWT\"},\"id\":2}" | nc -U $SOCK -w 3

# 3. Evaluar átomo D1 (cajero TIENE átomo 1: tryton.g1.d1.nuevo)
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d1.nuevo","user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":3}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f\"{r['veredicto']}: {r['motivo']}\")"

# 4. Evaluar átomo D3 (cajero NO tiene átomo 43)
echo '{"jsonrpc":"2.0","method":"bauth.access.evaluate","params":{"atom_slug":"tryton.g1.d3.nuevo","user_uuid":"019f06db-62a9-73ab-a85a-f5d12f20233d"},"id":4}' | nc -U $SOCK -w 3 | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print(f\"{r['veredicto']}: {r['motivo']}\")"
```

**Esperado:**
- Paso 1: JWT emitido
- Paso 2: valid = True
- Paso 3: PERMITIDO — átomo 1 presente en RolBitMask
- Paso 4: DENEGADO — átomo 43 ausente del RolBitMask
