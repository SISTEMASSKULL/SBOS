#!/usr/bin/env bash
# ============================================================================
# init_channels.sh — Configuracion de Mattermost SBOS
# IDEMPOTENTE: ejecutar N veces = mismo resultado. Sin duplicados.
# Soporta: install (primera vez) y update (reconfiguracion).
# ============================================================================
set -euo pipefail

MATTERMOST_URL="${MATTERMOST_URL:-http://localhost:8065}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@sbos.bo}"
ADMIN_PASS="${ADMIN_PASS:-Admin12345!}"
WEBHOOK_OUTPUT="${WEBHOOK_OUTPUT:-/etc/bos/mattermost-webhooks.json}"
MM_CONFIG_DIR="${MM_CONFIG_DIR:-/etc/bos/mattermost}"

echo "[mattermost] ========================================"
echo "[mattermost] Configuracion (idempotente)"
echo "[mattermost] ========================================"

mkdir -p "$MM_CONFIG_DIR"

# ── API helpers ───────────────────────────────────────────────

api() {
  local method="$1" path="$2" data="${3:-}"
  if [ -n "$data" ]; then
    curl -sf -X "$method" "$MATTERMOST_URL/api/v4/$path" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "$data" 2>/dev/null || true
  else
    curl -sf -X "$method" "$MATTERMOST_URL/api/v4/$path" \
      -H "Authorization: Bearer $TOKEN" 2>/dev/null || true
  fi
}

get_or_create_channel() {
  local team=$1 name=$2 display=$3 purpose=$4 type=${5:-O}
  local existing=$(api GET "teams/$team/channels/name/$name" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
  if [ -n "$existing" ]; then
    echo "$existing"
  else
    api POST "channels" "{\"team_id\":\"$team\",\"name\":\"$name\",\"display_name\":\"$display\",\"type\":\"$type\",\"purpose\":\"$purpose\"}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null
  fi
}

get_or_create_webhook() {
  local channel_id=$1 display=$2 desc=$3
  local existing=$(api GET "hooks/incoming?team_id=$TEAM" | python3 -c "
import sys,json
for h in json.load(sys.stdin):
    if h.get('channel_id') == '$channel_id' and h.get('display_name','').startswith('bnotify'):
        print(h['id']); break
" 2>/dev/null)
  if [ -n "$existing" ]; then
    echo "$existing"
  else
    api POST "hooks/incoming" "{\"channel_id\":\"$channel_id\",\"display_name\":\"$display\",\"description\":\"$desc\"}" \
      | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null
  fi
}

# ── 1. Autenticar ─────────────────────────────────────────────

TOKEN=$(curl -s -i -X POST "$MATTERMOST_URL/api/v4/users/login" \
  -H "Content-Type: application/json" \
  -d "{\"login_id\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
  | grep "^Token:" | awk '{print $2}' | tr -d '\r\n' || true)

if [ -z "$TOKEN" ]; then
  echo "[mattermost] Creando admin..."
  api POST "users" "{\"email\":\"$ADMIN_EMAIL\",\"username\":\"admin\",\"password\":\"$ADMIN_PASS\",\"first_name\":\"SBOS\",\"last_name\":\"Admin\"}" > /dev/null
  sleep 30
  TOKEN=$(curl -s -i -X POST "$MATTERMOST_URL/api/v4/users/login" \
    -H "Content-Type: application/json" \
    -d "{\"login_id\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" \
    | grep "^Token:" | awk '{print $2}' | tr -d '\r\n' || true)
fi

if [ -z "$TOKEN" ]; then
  echo "[mattermost] ERROR: No se pudo autenticar."
  exit 1
fi
echo "[mattermost] Autenticado."

# ── 2. Equipo SBOS ────────────────────────────────────────────

TEAM=$(api GET "teams/name/sbos" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)
if [ -z "$TEAM" ]; then
  TEAM=$(api POST "teams" '{"name":"sbos","display_name":"SBOS","type":"O","allow_open_invite":true}' \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))")
  echo "[mattermost] Equipo SBOS creado: $TEAM"
else
  echo "[mattermost] Equipo SBOS: $TEAM"
fi

# ── 3. Canales globales ───────────────────────────────────────

declare -A HOOKS

echo "[mattermost] Canales globales:"
for ch_data in \
  "monitoreo|Monitoreo|Alertas automaticas: health checks, metricas, SLO. Solo bots." \
  "seguridad|Seguridad|Eventos criticos: auth failures, bloqueos, tokens. bAuth." \
  "infraestructura|Infraestructura|Estado servicios: PostgreSQL, Redis, Kong, Vault, K8s." \
  "general|General|Anuncios, releases, discusiones del equipo SBOS."
do
  IFS="|" read -r name display purpose <<< "$ch_data"
  CH_ID=$(get_or_create_channel "$TEAM" "$name" "$display" "$purpose")
  HOOK_ID=$(get_or_create_webhook "$CH_ID" "bnotify-$name" "Webhook $display")
  HOOKS["$name"]="$HOOK_ID"
  echo "  $display → $HOOK_ID"
done

# ── 4. Canales jerárquicos (empresa/sucursal) ──────────────────

echo "[mattermost] Canales jerarquicos:"

# Empresa ACME Corp
ACME_ID=$(get_or_create_channel "$TEAM" "acme-corp" "🏭 ACME Corp" "Eventos de la empresa ACME Corp y sus sucursales" "P")
ACME_HOOK=$(get_or_create_webhook "$ACME_ID" "bnotify-acme-corp" "Webhook ACME Corp")
HOOKS["acme-corp"]="$ACME_HOOK"
echo "  🏭 ACME Corp → $ACME_HOOK"

# Sucursal Norte
NORTE_ID=$(get_or_create_channel "$TEAM" "acme-norte" "🏬 ACME - Norte" "Eventos de la sucursal ACME Norte" "P")
NORTE_HOOK=$(get_or_create_webhook "$NORTE_ID" "bnotify-acme-norte" "Webhook ACME Norte")
HOOKS["acme-norte"]="$NORTE_HOOK"
echo "  🏬 ACME Norte → $NORTE_HOOK"

# Sucursal Sur
SUR_ID=$(get_or_create_channel "$TEAM" "acme-sur" "🏬 ACME - Sur" "Eventos de la sucursal ACME Sur" "P")
SUR_HOOK=$(get_or_create_webhook "$SUR_ID" "bnotify-acme-sur" "Webhook ACME Sur")
HOOKS["acme-sur"]="$SUR_HOOK"
echo "  🏬 ACME Sur → $SUR_HOOK"

# ── 5. Exportar webhooks ──────────────────────────────────────

python3 -c "
import json
hooks = {
    'tenant_seguridad': '${HOOKS[seguridad]:-}',
    'tenant_monitoreo': '${HOOKS[monitoreo]:-}',
    'tenant_infraestructura': '${HOOKS[infraestructura]:-}',
    'tenant_general': '${HOOKS[general]:-}',
    'empresa_acme': '${HOOKS[acme-corp]:-}',
    'sucursal_acme_norte': '${HOOKS[acme-norte]:-}',
    'sucursal_acme_sur': '${HOOKS[acme-sur]:-}',
}
with open('$WEBHOOK_OUTPUT', 'w') as f:
    json.dump(hooks, f, indent=2, ensure_ascii=False)
print(f'Webhooks exportados a $WEBHOOK_OUTPUT')
"

# Guardar config para bAuth
cat > "$MM_CONFIG_DIR/notify.conf" <<EOF
# bAuth → Mattermost notification config
# Auto-generated by init_channels.sh — $(date -u +%Y-%m-%dT%H:%M:%SZ)
MM_URL=$MATTERMOST_URL
MM_TOKEN=$TOKEN
TENANT_HOOK=${HOOKS[seguridad]:-}
ACME_HOOK=${HOOKS[acme-corp]:-}
NORTE_HOOK=${HOOKS[acme-norte]:-}
SUR_HOOK=${HOOKS[acme-sur]:-}
EOF

echo ""
echo "[mattermost] Configuracion completada (idempotente)."
echo "[mattermost] Config guardada en $MM_CONFIG_DIR/notify.conf"
echo "[mattermost] $(date +%H:%M:%S) — $(echo ${!HOOKS[@]} | wc -w) canales configurados."
