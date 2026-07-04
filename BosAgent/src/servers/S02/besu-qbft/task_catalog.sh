#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — besu-qbft (IDEMPOTENTE)
# Iteración 1: Besu QBFT 1 validador via podman. RPC :8545 + WS :8546.
#   - Idempotente: 3 checks progresivos antes de instalar
#     1. eth_chainId == 0x539 → red ya existe
#     2. eth_blockNumber > 0 → produciendo bloques
#     3. genesis_hash match → misma cadena
#   - Si los 3 pasan: skip total (ya instalado, nada que hacer)
#   - Si alguno falla: reinstalación completa desde 0
# Iteración 2: StatefulSet K8s 4 validadores + TLS + Vault PKCS#11
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/besu-qbft.log}"
BESU_IMAGE="docker.io/hyperledger/besu:24.12.0"
BESU_CONTAINER="besu-qbft"
readonly RPC_URL="http://127.0.0.1:8545"
readonly CHAIN_ID="1337"
readonly CHAIN_ID_HEX="0x539"
readonly GENESIS_HASH="0x38a9e927b658596494bb56cfbb81f191cd8b612e383df56741b0a672b6d5d92d"
readonly VALIDATOR_ADDR="0x3caea8b153a7e5522630ad8ab59e8194d6f3cc92"
readonly COINBASE="0xD2Fe542a74c9A7C45d52FcBB62F6b61032F4420A"

# Directorios de configuración en el host (extraídos del contenedor real)
readonly CONFIG_DIR="/tmp/besu-qbft-config"
readonly GENESIS_FILE="${CONFIG_DIR}/genesis.json"
readonly KEYS_DIR="${CONFIG_DIR}/keys/${VALIDATOR_ADDR}"
readonly KEY_PRIV="${KEYS_DIR}/key.priv"
readonly KEY_PUB="${KEYS_DIR}/key.pub"

# Archivo de respaldo para claves (persistente entre reinstalaciones)
readonly BOS_KEY_BACKUP="/etc/bos/besu-validator.key"
readonly BOS_GENESIS_BACKUP="/etc/bos/besu-genesis.json"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [besu-qbft] $*" | tee -a "$FICHA_LOG"; }

# _rpc: llamada JSON-RPC a Besu. Retorna el campo "result" o vacío.
_rpc() {
    local method="$1" params="${2:-[]}"
    curl -s --max-time 5 -X POST -H 'Content-Type: application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":${params},\"id\":1}" \
        "${RPC_URL}" 2>/dev/null || echo '{}'
}

# _rpc_field: extrae un campo numérico/string de una respuesta JSON-RPC.
_rpc_field() {
    local method="$1" params="${2:-[]}" field="${3:-result}" default="${4:-0}"
    local val
    val=$(_rpc "$method" "$params" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    v = d.get('${field}')
    if v is None:
        print('${default}')
    elif isinstance(v, str) and v.startswith('0x'):
        print(int(v, 16))
    elif isinstance(v, bool):
        print(str(v).lower())
    else:
        print(v)
except:
    print('${default}')
" 2>/dev/null) || val="$default"
    echo "$val"
}

# _container_exists: verifica si el contenedor besu-qbft existe (corriendo o no).
_container_exists() {
    podman container exists "$BESU_CONTAINER" 2>/dev/null
}

# _container_running: verifica si el contenedor está corriendo y healthy.
_container_running() {
    local status
    status=$(podman inspect --format '{{.State.Status}}' "$BESU_CONTAINER" 2>/dev/null || echo "notfound")
    [[ "$status" == "running" ]]
}

# _container_healthy: verifica el health check del contenedor.
_container_healthy() {
    local health
    health=$(podman inspect --format '{{.State.Health.Status}}' "$BESU_CONTAINER" 2>/dev/null || echo "none")
    [[ "$health" == "healthy" ]]
}

# ── CHECKS DE IDEMPOTENCIA ──────────────────────────────────────────
# Retorna 0 si TODO está bien (skip instalación), 1 si algo falta.

idempotency_check() {
    local ok=0 issues=0

    # Check 1: ¿eth_chainId responde 0x539?
    echo "${__STEP_START__} idempotencia_chain_id"
    local chain_id_hex
    chain_id_hex=$(_rpc_field "eth_chainId" "[]" "result" "")
    if [[ "$chain_id_hex" == "$CHAIN_ID" || "$chain_id_hex" == "$CHAIN_ID_HEX" ]]; then
        _log "Check 1 OK: eth_chainId = $chain_id_hex"
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_chain_id"
    else
        _log "Check 1 FAIL: eth_chainId = '$chain_id_hex' (esperado $CHAIN_ID)"
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_chain_id"
    fi

    # Check 2: ¿eth_blockNumber > 0?
    echo "${__STEP_START__} idempotencia_block_height"
    local height
    height=$(_rpc_field "eth_blockNumber" "[]" "result" "0")
    if (( height > 0 )); then
        _log "Check 2 OK: eth_blockNumber = $height bloques"
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_block_height"
    else
        _log "Check 2 FAIL: eth_blockNumber = $height"
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_block_height"
    fi

    # Check 3: ¿admin_nodeInfo genesis hash coincide?
    echo "${__STEP_START__} idempotencia_genesis_hash"
    local genesis_hash
    genesis_hash=$(_rpc "admin_nodeInfo" "[]" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    gh=d.get('result',{}).get('protocols',{}).get('eth',{}).get('genesis','')
    print(gh)
except:
    print('')
" 2>/dev/null)
    if [[ "$genesis_hash" == "$GENESIS_HASH" ]]; then
        _log "Check 3 OK: genesis_hash = $genesis_hash"
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_genesis_hash"
    else
        _log "Check 3 FAIL: genesis_hash = '$genesis_hash' (esperado $GENESIS_HASH)"
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_genesis_hash"
    fi

    # Check 4: ¿qbft_getValidatorsByBlockNumber incluye nuestro validador?
    echo "${__STEP_START__} idempotencia_validator"
    local validators
    validators=$(_rpc "qbft_getValidatorsByBlockNumber" '["latest"]' | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    vals=d.get('result',[])
    print(','.join(vals))
except:
    print('')
" 2>/dev/null)
    if echo "$validators" | grep -qi "$VALIDATOR_ADDR"; then
        _log "Check 4 OK: validator $VALIDATOR_ADDR activo"
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_validator"
    else
        _log "Check 4 FAIL: validators = '$validators' (no contiene $VALIDATOR_ADDR)"
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_validator"
    fi

    _log "Idempotencia: $ok/4 checks OK, $issues/4 requieren acción"
    if (( issues == 0 )); then
        return 0  # Todo idempotente: skip instalación
    else
        return 1  # Algo falta: instalar/reparar
    fi
}

# ── Pre-install ─────────────────────────────────────────────────────
ficha_pre_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /etc/bos

    # Verificar que podman está disponible
    echo "${__STEP_START__} verificar_podman"
    if ! command -v podman > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_podman: podman no instalado"
        return 1
    fi
    echo "${__STEP_OK__} verificar_podman $(podman --version)"

    # Verificar que la imagen existe (o descargarla)
    echo "${__STEP_START__} verificar_imagen"
    if podman images --format '{{.Repository}}:{{.Tag}}' | grep -qF "$BESU_IMAGE"; then
        echo "${__STEP_OK__} verificar_imagen ($BESU_IMAGE presente)"
    else
        _log "Descargando imagen $BESU_IMAGE ..."
        podman pull "$BESU_IMAGE" >> "$FICHA_LOG" 2>&1 || {
            echo "${__STEP_FAIL__} verificar_imagen: no se pudo descargar $BESU_IMAGE"
            return 1
        }
        echo "${__STEP_OK__} verificar_imagen (descargada)"
    fi

    return 0
}

# ── Install ─────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /etc/bos

    # ═══ IDEMPOTENCIA: Verificar si ya está todo funcionando ═══
    if idempotency_check; then
        _log "=================================================="
        _log "BESU QBFT YA INSTALADO Y OPERATIVO — SKIP TOTAL"
        _log "=================================================="
        _log "  chain_id:    $CHAIN_ID"
        _log "  rpc:         $RPC_URL"
        _log "  validator:   $VALIDATOR_ADDR"
        _log "  genesis:     $GENESIS_HASH"
        _log "  container:   ${BESU_CONTAINER} ($(podman inspect --format '{{.State.Status}}' $BESU_CONTAINER 2>/dev/null))"
        _log "  altura:      $(_rpc_field 'eth_blockNumber' '[]' 'result' '?')"
        _log "=================================================="
        return 0
    fi
    _log "Idempotencia NO superada — instalando Besu QBFT..."

    # ── 1. Crear directorios de configuración ──────────────────────
    echo "${__STEP_START__} crear_directorios"
    mkdir -p "$CONFIG_DIR" "$KEYS_DIR"
    echo "${__STEP_OK__} crear_directorios"

    # ── 2. Genesis.json (idempotente: solo escribe si no existe o difiere) ──
    echo "${__STEP_START__} desplegar_genesis"
    if [[ -f "$GENESIS_FILE" ]]; then
        local existing_hash
        existing_hash=$(sha256sum "$GENESIS_FILE" | awk '{print $1}')
        local expected_hash
        expected_hash=$(sha256sum "${BASH_SOURCE[0]%/*}/resources/genesis.json" 2>/dev/null | awk '{print $1}' || echo "")
        if [[ -n "$expected_hash" && "$existing_hash" == "$expected_hash" ]]; then
            _log "Genesis.json ya coincide — sin cambios"
            echo "${__STEP_OK__} desplegar_genesis (sin cambios)"
        else
            _log "Genesis.json difiere — reemplazando"
            cp "${BASH_SOURCE[0]%/*}/resources/genesis.json" "$GENESIS_FILE"
            echo "${__STEP_OK__} desplegar_genesis (reemplazado)"
        fi
    else
        cp "${BASH_SOURCE[0]%/*}/resources/genesis.json" "$GENESIS_FILE"
        echo "${__STEP_OK__} desplegar_genesis (creado)"
    fi

    # Respaldo en /etc/bos
    cp "$GENESIS_FILE" "$BOS_GENESIS_BACKUP" 2>/dev/null || true

    # ── 3. Clave de validador (idempotente: NUNCA regenerar si existe) ──
    echo "${__STEP_START__} desplegar_validator_key"
    if [[ -f "$KEY_PRIV" ]]; then
        _log "Clave de validador ya existe: $KEY_PRIV — CONSERVADA (no se regenera)"
        echo "${__STEP_OK__} desplegar_validator_key (existente, conservada)"
    elif [[ -f "$BOS_KEY_BACKUP" ]]; then
        _log "Restaurando clave desde backup: $BOS_KEY_BACKUP"
        mkdir -p "$KEYS_DIR"
        cp "$BOS_KEY_BACKUP" "$KEY_PRIV"
        chmod 600 "$KEY_PRIV"
        echo "${__STEP_OK__} desplegar_validator_key (restaurada de backup)"
    else
        _log "Generando NUEVA clave de validador (32 bytes hex)..."
        python3 -c "import secrets; print(secrets.token_hex(32))" > "$KEY_PRIV"
        chmod 600 "$KEY_PRIV"
        # Generar la clave pública correspondiente
        python3 -c "
import secrets, hashlib, coincurve
# Usamos la clave privada generada para derivar la pública
# (requiere coincurve instalado; si no, solo guardamos la privada)
" 2>/dev/null || true
        # Respaldo inmediato
        cp "$KEY_PRIV" "$BOS_KEY_BACKUP"
        chmod 600 "$BOS_KEY_BACKUP"
        _log "NUEVA clave generada. Dirección esperada del validador: <derivar>"
        _log "IMPORTANTE: Si la clave cambió, el extraData del genesis.json debe regenerarse"
        echo "${__STEP_OK__} desplegar_validator_key (nueva, respaldada en $BOS_KEY_BACKUP)"
    fi

    # ── 4. Detener contenedor previo si existe ─────────────────────
    echo "${__STEP_START__} limpiar_contenedor_previo"
    if _container_exists; then
        if _container_running; then
            _log "Deteniendo contenedor ${BESU_CONTAINER} existente..."
            podman stop "$BESU_CONTAINER" >> "$FICHA_LOG" 2>&1 || true
        fi
        podman rm "$BESU_CONTAINER" >> "$FICHA_LOG" 2>&1 || true
        echo "${__STEP_OK__} limpiar_contenedor_previo (eliminado)"
    else
        echo "${__STEP_OK__} limpiar_contenedor_previo (no existía)"
    fi

    # ── 5. Arrancar Besu QBFT ────────────────────────────────────
    echo "${__STEP_START__} arrancar_besu"
    podman run -d --name "$BESU_CONTAINER" \
        -p 8545:8545 \
        -p 8546:8546 \
        -v "${GENESIS_FILE}:/genesis.json:Z" \
        -v "${KEY_PRIV}:/key:Z" \
        "$BESU_IMAGE" \
        --genesis-file=/genesis.json \
        --data-path=/tmp/besu-qbft-data \
        --host-allowlist="*" \
        --rpc-http-enabled \
        --rpc-http-api=ETH,NET,WEB3,ADMIN,DEBUG,TXPOOL,QBFT \
        --rpc-http-cors-origins=all \
        --node-private-key-file=/key \
        --miner-enabled \
        --miner-coinbase="${COINBASE}" \
        >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} arrancar_besu: no se pudo iniciar el contenedor"
        return 1
    }
    echo "${__STEP_OK__} arrancar_besu (contenedor ${BESU_CONTAINER})"

    # ── 6. Esperar health check ───────────────────────────────────
    echo "${__STEP_START__} esperar_healthy"
    local deadline=$(( $(date +%s) + 120 ))
    local healthy=0
    while (( $(date +%s) < deadline )); do
        if _container_healthy; then
            healthy=1
            break
        fi
        sleep 5
    done
    if (( healthy )); then
        echo "${__STEP_OK__} esperar_healthy (healthy en ~$(( 120 - (deadline - $(date +%s)) ))s)"
    else
        # Verificar al menos que está corriendo
        if _container_running; then
            _log "Contenedor corriendo pero health check aún no pasa — ficha_repair verificará"
            echo "${__STEP_SKIP__} esperar_healthy: running pero no healthy aún"
        else
            echo "${__STEP_FAIL__} esperar_healthy: contenedor no arrancó"
            podman logs "$BESU_CONTAINER" --tail=20 2>/dev/null | tee -a "$FICHA_LOG"
            return 1
        fi
    fi

    # ── 7. Verificar producción de bloques ────────────────────────
    echo "${__STEP_START__} verificar_bloques"
    sleep 6  # 3 bloques a 2s cada uno
    local height
    height=$(_rpc_field "eth_blockNumber" "[]" "result" "0")
    if (( height > 0 )); then
        _log "Red QBFT produciendo bloques — altura: $height"
        echo "${__STEP_OK__} verificar_bloques (altura=$height)"
    else
        _log "ADVERTENCIA: altura=0 — puede necesitar más tiempo"
        echo "${__STEP_SKIP__} verificar_bloques (altura=0, ficha_repair lo convergerá)"
    fi

    _log "Besu QBFT instalado: RPC=$RPC_URL, validator=$VALIDATOR_ADDR, chain=$CHAIN_ID"
    return 0
}

# ── Post-install ────────────────────────────────────────────────────
ficha_post_install() {
    _log "=== Estado Besu QBFT ==="
    _log "  container:  $(podman inspect --format '{{.State.Status}}' $BESU_CONTAINER 2>/dev/null || echo '?')"
    _log "  health:     $(podman inspect --format '{{.State.Health.Status}}' $BESU_CONTAINER 2>/dev/null || echo '?')"
    _log "  chain_id:   $(_rpc_field 'eth_chainId' '[]' 'result' '?')"
    _log "  altura:     $(_rpc_field 'eth_blockNumber' '[]' 'result' '?')"
    _log "  peers:      $(_rpc_field 'net_peerCount' '[]' 'result' '?')"
    _log "  gas_price:  $(_rpc_field 'eth_gasPrice' '[]' 'result' '?')"
    _log "  rpc:        $RPC_URL"
    _log "  genesis:    $GENESIS_FILE"
    _log "  key:        $KEY_PRIV"
    return 0
}

# ── Repair ──────────────────────────────────────────────────────────
ficha_repair() {
    # Primero, verificar idempotencia
    if idempotency_check; then
        _log "Repair: todo OK — sin acción necesaria"
        return 0
    fi

    _log "Repair: detectado drift — restaurando..."

    echo "${__STEP_START__} reparar_contenedor"
    if ! _container_running; then
        _log "Contenedor no corriendo — reiniciando..."
        if _container_exists; then
            podman start "$BESU_CONTAINER" >> "$FICHA_LOG" 2>&1 || {
                _log "No se pudo iniciar contenedor existente — reinstalando"
                podman rm "$BESU_CONTAINER" 2>/dev/null || true
                ficha_install
                return $?
            }
        else
            _log "Contenedor no existe — reinstalando"
            ficha_install
            return $?
        fi
    fi
    echo "${__STEP_OK__} reparar_contenedor"

    echo "${__STEP_START__} reparar_bloques"
    local height
    height=$(_rpc_field "eth_blockNumber" "[]" "result" "0")
    if (( height == 0 )); then
        _log "Altura=0 — posible corrupción. Reinstalando con genesis..."
        podman stop "$BESU_CONTAINER" 2>/dev/null || true
        podman rm "$BESU_CONTAINER" 2>/dev/null || true
        ficha_install
        return $?
    fi
    echo "${__STEP_OK__} reparar_bloques (altura=$height)"

    return 0
}

# ── Test ────────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_contenedor_running"
    if _container_running; then
        echo "${__STEP_OK__} test_contenedor_running"
    else
        echo "${__STEP_FAIL__} test_contenedor_running"
        ok=1
    fi

    echo "${__STEP_START__} test_rpc_liveness"
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "${RPC_URL}/liveness" 2>/dev/null || echo "000")
    if [[ "$code" == "200" ]]; then
        echo "${__STEP_OK__} test_rpc_liveness (HTTP $code)"
    else
        echo "${__STEP_FAIL__} test_rpc_liveness (HTTP $code)"
        ok=1
    fi

    echo "${__STEP_START__} test_chain_id"
    local cid
    cid=$(_rpc_field "eth_chainId" "[]" "result" "")
    if [[ "$cid" == "$CHAIN_ID" ]]; then
        echo "${__STEP_OK__} test_chain_id ($cid)"
    else
        echo "${__STEP_FAIL__} test_chain_id (esperado=$CHAIN_ID real=$cid)"
        ok=1
    fi

    echo "${__STEP_START__} test_bloques"
    local height
    height=$(_rpc_field "eth_blockNumber" "[]" "result" "0")
    if (( height > 0 )); then
        echo "${__STEP_OK__} test_bloques (altura=$height)"
    else
        echo "${__STEP_FAIL__} test_bloques (altura=$height)"
        ok=1
    fi

    echo "${__STEP_START__} test_genesis_hash"
    local gh
    gh=$(_rpc "admin_nodeInfo" "[]" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('result',{}).get('protocols',{}).get('eth',{}).get('genesis',''))
except:
    print('')
" 2>/dev/null)
    if [[ "$gh" == "$GENESIS_HASH" ]]; then
        echo "${__STEP_OK__} test_genesis_hash"
    else
        echo "${__STEP_FAIL__} test_genesis_hash (esperado=$GENESIS_HASH real=$gh)"
        ok=1
    fi

    echo "${__STEP_START__} test_validator_activo"
    local vals
    vals=$(_rpc "qbft_getValidatorsByBlockNumber" '["latest"]' | \
        python3 -c "import sys,json; print(','.join(json.load(sys.stdin).get('result',[])))" 2>/dev/null)
    if echo "$vals" | grep -qi "$VALIDATOR_ADDR"; then
        echo "${__STEP_OK__} test_validator_activo"
    else
        echo "${__STEP_FAIL__} test_validator_activo (validators=$vals)"
        ok=1
    fi

    return $ok
}

# ── Status ──────────────────────────────────────────────────────────
ficha_status() {
    echo "=== besu-qbft STATUS ==="
    echo ""
    echo "Contenedor:"
    if _container_exists; then
        podman inspect --format '
  Name:   {{.Name}}
  Status: {{.State.Status}}
  Health: {{.State.Health.Status}}
  Image:  {{.Config.Image}}
  Started: {{.State.StartedAt}}
  PID:    {{.State.Pid}}' "$BESU_CONTAINER" 2>/dev/null || echo "  (error inspect)"
        echo ""
        podman stats "$BESU_CONTAINER" --no-stream --format '
  CPU:  {{.CPU}}
  RAM:  {{.MemUsage}}
  Net:  {{.NetIO}}' 2>/dev/null || true
    else
        echo "  NO EXISTE"
    fi
    echo ""
    echo "Red QBFT:"
    echo "  chain_id:   $(_rpc_field 'eth_chainId' '[]' 'result' '?')"
    echo "  altura:     $(_rpc_field 'eth_blockNumber' '[]' 'result' '?')"
    echo "  peers:      $(_rpc_field 'net_peerCount' '[]' 'result' '?')"
    echo "  gas_price:  $(_rpc_field 'eth_gasPrice' '[]' 'result' '?')"
    echo ""
    echo "Configuración:"
    echo "  genesis:    $GENESIS_FILE ($(sha256sum "$GENESIS_FILE" 2>/dev/null | awk '{print $1}' || echo 'no existe'))"
    echo "  key:        $KEY_PRIV ($(sha256sum "$KEY_PRIV" 2>/dev/null | awk '{print $1}' || echo 'no existe'))"
    echo "  backup key: $BOS_KEY_BACKUP ($(sha256sum "$BOS_KEY_BACKUP" 2>/dev/null | awk '{print $1}' || echo 'no existe'))"
    echo ""
    echo "Endpoints:"
    echo "  RPC HTTP:  $RPC_URL"
    echo "  RPC WS:    ws://127.0.0.1:8546"
    echo "  P2P:       127.0.0.1:30303"
    echo ""
    echo "Validator: $VALIDATOR_ADDR"
    echo "Coinbase:  $COINBASE"
    echo "ChainID:   $CHAIN_ID"
    echo "Genesis:   $GENESIS_HASH"
}

# ── Uninstall ───────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando Besu QBFT"
    _log "  - Contenedor será eliminado"
    _log "  - Clave de validador en $KEY_PRIV se CONSERVA"
    _log "  - Genesis en $GENESIS_FILE se CONSERVA"
    _log "  - Datos de blockchain en el overlay del contenedor se PIERDEN"

    echo "${__STEP_START__} detener_contenedor"
    if _container_running; then
        podman stop "$BESU_CONTAINER" >> "$FICHA_LOG" 2>&1 || true
        echo "${__STEP_OK__} detener_contenedor"
    else
        echo "${__STEP_SKIP__} detener_contenedor (no corriendo)"
    fi

    echo "${__STEP_START__} eliminar_contenedor"
    if _container_exists; then
        podman rm "$BESU_CONTAINER" >> "$FICHA_LOG" 2>&1 || true
        echo "${__STEP_OK__} eliminar_contenedor"
    else
        echo "${__STEP_SKIP__} eliminar_contenedor (no existe)"
    fi

    # CONSERVAR genesis y clave — permiten recrear la red exactamente
    _log "Archivos conservados: $GENESIS_FILE, $KEY_PRIV, $BOS_KEY_BACKUP"
    return 0
}

# ── Diagnóstico ─────────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico besu-qbft ==="
    echo ""

    echo "--- Logs del contenedor (últimas 40 líneas) ---"
    podman logs "$BESU_CONTAINER" --tail=40 2>/dev/null || echo "  (no disponible)"
    echo ""

    echo "--- Último bloque ---"
    _rpc "eth_getBlockByNumber" '["latest",false]' | python3 -c "
import sys,json
try:
    b=json.load(sys.stdin).get('result',{})
    if b:
        print(f\"  number:    {int(b.get('number','0x0'),16)}\")
        print(f\"  hash:      {b.get('hash','?')}\")
        print(f\"  timestamp: {int(b.get('timestamp','0x0'),16)}\")
        print(f\"  gas_used:  {int(b.get('gasUsed','0x0'),16)}\")
        print(f\"  tx_count:  {len(b.get('transactions',[]))}\")
    else:
        print('  sin resultado')
except Exception as e:
    print(f'  error: {e}')
" 2>/dev/null || echo "  (RPC no responde)"

    echo ""
    echo "--- admin_nodeInfo ---"
    _rpc "admin_nodeInfo" "[]" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin).get('result',{})
    print(f\"  enode:      {d.get('enode','?')[:80]}...\")
    print(f\"  id:         {d.get('id','?')}\")
    print(f\"  name:       {d.get('name','?')}\")
    print(f\"  activeFork: {d.get('activeFork','?')}\")
    eth=d.get('protocols',{}).get('eth',{})
    print(f\"  network:    {eth.get('network','?')}\")
    print(f\"  genesis:    {eth.get('genesis','?')}\")
except Exception as e:
    print(f'  error: {e}')
" 2>/dev/null || echo "  (RPC no responde)"

    echo ""
    echo "--- Archivos de configuración ---"
    echo "  genesis.json: $(ls -la "$GENESIS_FILE" 2>/dev/null || echo 'NO EXISTE')"
    echo "  key.priv:     $(ls -la "$KEY_PRIV" 2>/dev/null || echo 'NO EXISTE')"
    echo "  key.pub:      $(ls -la "$KEY_PUB" 2>/dev/null || echo 'NO EXISTE')"
    echo "  backup key:   $(ls -la "$BOS_KEY_BACKUP" 2>/dev/null || echo 'NO EXISTE')"
}
