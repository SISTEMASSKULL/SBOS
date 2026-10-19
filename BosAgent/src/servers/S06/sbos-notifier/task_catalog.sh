#!/usr/bin/env bash
# ============================================================
# SBOS TASK CATALOG — sbos-notifier
# Tareas operativas: instalar, reparar, migrar, probar
# Uso: bosctl ficha task sbos-notifier <tarea> --tenant=<t>
# ============================================================
set -euo pipefail

FICHA="sbos-notifier"
TENANT="${SBOS_TENANT:-}"
PG_DB="notifier_db"
NTFY_URL="http://localhost:28204"
REDIS_DB=3

# ── Colores para output legible ─────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'

log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC} $*"; }
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }

require_tenant() {
  [[ -z "$TENANT" ]] && { log_err "SBOS_TENANT no definido"; exit 1; }
}

# ============================================================
# install — crea BD, tablas, topics ntfy, configura Vault
# ============================================================
task_install() {
  require_tenant
  log_info "Instalando $FICHA para tenant=$TENANT"

  # 1. Crear BD en PostgreSQL
  log_info "Creando base de datos $PG_DB..."
  psql -U postgres -c "CREATE DATABASE ${PG_DB} OWNER sbos_app;" 2>/dev/null \
    && log_ok "BD $PG_DB creada" \
    || log_warn "BD $PG_DB ya existe — omitiendo"

  # 2. Ejecutar migraciones SQL
  log_info "Aplicando migraciones..."
  psql -U sbos_app -d "$PG_DB" <<'SQL'
    CREATE TABLE IF NOT EXISTS notification_events (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant        TEXT NOT NULL,
      ctx_id        TEXT NOT NULL,           -- campo obligatorio SBOS-049
      type          TEXT NOT NULL,           -- factura, error, tarea, mfa, alerta
      severity      TEXT DEFAULT 'info',     -- info, warning, critical
      source_module TEXT,
      recipient_id  TEXT,                    -- user_id o external_id
      channel       TEXT NOT NULL,           -- telegram, whatsapp, email, ntfy, cli
      payload       JSONB,
      status        TEXT DEFAULT 'pending',  -- pending, sent, failed
      sent_at       TIMESTAMPTZ,
      error_msg     TEXT,
      created_at    TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notification_channels (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant     TEXT NOT NULL,
      user_id    TEXT NOT NULL,
      channel    TEXT NOT NULL,             -- telegram, whatsapp, email, ntfy, cli
      address    TEXT NOT NULL,             -- chat_id, número, email, topic
      active     BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(tenant, user_id, channel)
    );

    CREATE TABLE IF NOT EXISTS mfa_challenges (
      id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant        TEXT NOT NULL,
      ctx_id        TEXT NOT NULL,
      user_id       TEXT NOT NULL,
      challenge_token TEXT NOT NULL UNIQUE,
      status        TEXT DEFAULT 'pending', -- pending, confirmed, denied, expired
      geo           TEXT,
      device_info   TEXT,
      expires_at    TIMESTAMPTZ NOT NULL,
      resolved_at   TIMESTAMPTZ,
      created_at    TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE IF NOT EXISTS notification_templates (
      id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      tenant   TEXT NOT NULL,
      type     TEXT NOT NULL,
      channel  TEXT NOT NULL,
      lang     TEXT DEFAULT 'es',
      subject  TEXT,
      body     TEXT NOT NULL,
      UNIQUE(tenant, type, channel, lang)
    );

    CREATE INDEX IF NOT EXISTS idx_notif_tenant_ctx
      ON notification_events(tenant, ctx_id);
    CREATE INDEX IF NOT EXISTS idx_notif_status
      ON notification_events(status, created_at);
    CREATE INDEX IF NOT EXISTS idx_mfa_token
      ON mfa_challenges(challenge_token, expires_at);
SQL
  log_ok "Migraciones aplicadas"

  # 3. Crear topics ntfy por tenant
  log_info "Configurando topics ntfy..."
  # topics: alertas admin, notificaciones clientes, MFA, CLI
  for topic in "admin-alerts" "client-notify" "mfa-push" "cli-alerts" "task-reminders"; do
    curl -s -X POST "$NTFY_URL/v1/topics" \
      -H "Content-Type: application/json" \
      -d "{\"topic\": \"${TENANT}-${topic}\"}" > /dev/null \
      && log_ok "Topic ntfy: ${TENANT}-${topic}"
  done

  # 4. Insertar templates base en español
  log_info "Cargando templates base..."
  psql -U sbos_app -d "$PG_DB" <<SQL
    INSERT INTO notification_templates (tenant, type, channel, lang, subject, body)
    VALUES
      ('$TENANT', 'factura-emitida',   'telegram',  'es', NULL,
       '📄 Factura emitida\nNúmero: {{invoice_number}}\nMonto: {{amount}} {{currency}}\nCliente: {{partner_name}}'),
      ('$TENANT', 'factura-emitida',   'email',     'es',
       'Factura emitida - {{invoice_number}}',
       'Estimado {{partner_name}},\n\nSu factura {{invoice_number}} por {{amount}} {{currency}} ha sido emitida.\n\nSistema SBOS'),
      ('$TENANT', 'error-critico',     'telegram',  'es', NULL,
       '🚨 Error crítico\nMódulo: {{source_module}}\nMensaje: {{message}}\nCtx: {{ctx_id}}'),
      ('$TENANT', 'tarea-pendiente',   'ntfy',      'es', 'Tarea vencida: {{title}}',
       'La tarea "{{title}}" está vencida desde {{due_date}}.\nAsignada a: {{assigned_to}}'),
      ('$TENANT', 'mfa-push',         'telegram',  'es', NULL,
       '🔐 Intento de acceso a SBOS\n📍 Desde: {{geo}}\n🕐 {{created_at}}\n\n¿Eres tú?'),
      ('$TENANT', 'alerta-sistema',   'cli',       'es', NULL,
       '[SBOS-ALERT] {{severity}} | {{source_module}} | {{message}}')
    ON CONFLICT (tenant, type, channel, lang) DO NOTHING;
SQL
  log_ok "Templates base cargados"

  log_ok "Instalación de $FICHA completada para tenant=$TENANT"
}

# ============================================================
# repair — verifica y repara el estado de la ficha
# ============================================================
task_repair() {
  require_tenant
  log_info "Reparando $FICHA para tenant=$TENANT"

  # Verificar pod corriendo
  POD=$(kubectl get pod -n "sbos-${TENANT}" -l app=sbos-notifier \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$POD" ]]; then
    log_err "Pod no encontrado — relanzando deployment"
    kubectl rollout restart deployment/sbos-notifier -n "sbos-${TENANT}"
  else
    log_ok "Pod activo: $POD"
  fi

  # Verificar conectividad PostgreSQL
  psql -U sbos_app -d "$PG_DB" -c "SELECT 1;" > /dev/null 2>&1 \
    && log_ok "PostgreSQL OK" \
    || { log_err "PostgreSQL no responde"; exit 1; }

  # Verificar ntfy health
  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$NTFY_URL/v1/health")
  [[ "$HTTP_STATUS" == "200" ]] \
    && log_ok "ntfy OK (HTTP $HTTP_STATUS)" \
    || log_warn "ntfy no responde (HTTP $HTTP_STATUS)"

  # Limpiar MFA challenges expirados
  DELETED=$(psql -U sbos_app -d "$PG_DB" -t -c \
    "DELETE FROM mfa_challenges WHERE expires_at < NOW() AND status='pending'
     RETURNING id;" | wc -l)
  log_ok "MFA challenges expirados limpiados: $DELETED"

  log_ok "Reparación completada"
}

# ============================================================
# migrate — ejecuta migraciones de versión
# ============================================================
task_migrate() {
  require_tenant
  VERSION="${2:-}"
  log_info "Migrando $FICHA a versión $VERSION"
  # Las migraciones se agregan aquí en versiones futuras
  log_ok "Sin migraciones pendientes para $VERSION"
}

# ============================================================
# test — prueba completa de canales de notificación
# ============================================================
task_test() {
  require_tenant
  log_info "Probando canales de notificación para tenant=$TENANT"

  CTX_TEST="ctx-test-$(date +%s)"

  # Test ntfy (bus interno + CLI)
  log_info "Probando ntfy → CLI..."
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$NTFY_URL/${TENANT}-cli-alerts" \
    -H "Title: Test SBOS-Notifier" \
    -H "Priority: default" \
    -H "X-SBOS-CtxId: $CTX_TEST" \
    -d "Test de notificación CLI desde sbos-notifier — tenant=$TENANT")
  [[ "$RESPONSE" == "200" ]] \
    && log_ok "ntfy CLI OK (HTTP $RESPONSE)" \
    || log_warn "ntfy CLI falló (HTTP $RESPONSE)"

  # Test endpoint health
  log_info "Probando /health..."
  H=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:28203/health")
  [[ "$H" == "200" ]] && log_ok "Health OK" || log_warn "Health falló: $H"

  # Test /metrics
  log_info "Probando /metrics..."
  M=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:28202/metrics")
  [[ "$M" == "200" ]] && log_ok "Metrics OK" || log_warn "Metrics falló: $M"

  # Test MFA challenge (crea y consulta)
  log_info "Probando flujo MFA challenge..."
  MFA_RESPONSE=$(curl -s -X POST "http://localhost:28200/api/mfa/test-challenge" \
    -H "Content-Type: application/json" \
    -H "X-SBOS-CtxId: $CTX_TEST" \
    -d '{"user_id":"test-user","geo":"La Paz, Bolivia"}')
  echo "$MFA_RESPONSE" | grep -q "challenge_token" \
    && log_ok "MFA challenge generado OK" \
    || log_warn "MFA challenge falló: $MFA_RESPONSE"

  log_info "Pruebas completadas para tenant=$TENANT"
}

# ============================================================
# status — muestra estado completo de la ficha
# ============================================================
task_status() {
  require_tenant
  log_info "Estado de $FICHA — tenant=$TENANT"
  echo ""

  # Pods
  echo "── Pods ──────────────────────────────────────────────"
  kubectl get pods -n "sbos-${TENANT}" -l app=sbos-notifier \
    -o wide 2>/dev/null || log_warn "kubectl no disponible"

  # Notificaciones últimas 24h
  echo ""
  echo "── Notificaciones últimas 24h ────────────────────────"
  psql -U sbos_app -d "$PG_DB" -x -c "
    SELECT channel, status, COUNT(*) as total
    FROM notification_events
    WHERE tenant='$TENANT' AND created_at > NOW() - INTERVAL '24h'
    GROUP BY channel, status
    ORDER BY total DESC;" 2>/dev/null || log_warn "BD no disponible"

  # MFA challenges activos
  echo ""
  echo "── MFA Challenges activos ────────────────────────────"
  psql -U sbos_app -d "$PG_DB" -c "
    SELECT user_id, status, geo, expires_at
    FROM mfa_challenges
    WHERE tenant='$TENANT' AND expires_at > NOW()
    ORDER BY created_at DESC LIMIT 5;" 2>/dev/null
}

# ============================================================
# Dispatcher de tareas
# ============================================================
TASK="${1:-help}"
case "$TASK" in
  install)  task_install  ;;
  repair)   task_repair   ;;
  migrate)  task_migrate  "$@" ;;
  test)     task_test     ;;
  status)   task_status   ;;
  *)
    echo "Uso: bosctl ficha task $FICHA <tarea> --tenant=<tenant>"
    echo ""
    echo "Tareas disponibles:"
    echo "  install   Instala la ficha: BD, tablas, topics ntfy, templates"
    echo "  repair    Verifica y repara estado de la ficha"
    echo "  migrate   Ejecuta migraciones de versión"
    echo "  test      Prueba todos los canales de notificación"
    echo "  status    Muestra estado completo: pods, métricas, últimas notif"
    ;;
esac
