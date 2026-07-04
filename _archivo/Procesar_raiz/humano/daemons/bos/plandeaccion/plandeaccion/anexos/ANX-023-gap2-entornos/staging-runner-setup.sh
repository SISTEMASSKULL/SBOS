#!/usr/bin/env bash
# Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
# Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
# ============================================================
# docs/staging-runner-setup.sh
#
# Instala el GitHub Actions self-hosted runner en la VPS staging.
# Ejecutar UNA SOLA VEZ en 13.140.128.230 como root.
#
# Desde tu máquina Windows/WSL:
#   ssh root@13.140.128.230
#   export RUNNER_TOKEN="AXXXXXXXXX"   # de GitHub UI (ver abajo)
#   export GITHUB_REPO_URL="https://github.com/skull/SBOS"
#   bash docs/staging-runner-setup.sh
#
# Dónde obtener RUNNER_TOKEN:
#   github.com/skull/SBOS → Settings → Actions → Runners
#   → New self-hosted runner → Linux → copiar el token del paso ./config.sh
#   El token expira en 1 hora, usarlo inmediatamente.
# ============================================================

set -euo pipefail

RUNNER_VERSION="2.322.0"
RUNNER_DIR="/opt/bos-runner"
RUNNER_USER="bos-runner"
STAGING_HOST="13.140.128.230"

# ── Validaciones ───────────────────────────────────────────
[ "$EUID" -ne 0 ] && { echo "Ejecutar como root"; exit 1; }
[ -z "${GITHUB_REPO_URL:-}" ] && { echo "GITHUB_REPO_URL no definida"; exit 1; }
[ -z "${RUNNER_TOKEN:-}" ] && { echo "RUNNER_TOKEN no definida"; exit 1; }

echo "=== SBOS Staging Runner — $STAGING_HOST ==="
echo "Repo: $GITHUB_REPO_URL"
echo ""

# ── 1. Usuario dedicado ────────────────────────────────────
if ! id "$RUNNER_USER" &>/dev/null; then
  useradd --system --shell /usr/sbin/nologin \
    --create-home --home-dir "/home/$RUNNER_USER" "$RUNNER_USER"
  echo "✅ Usuario $RUNNER_USER creado"
fi

# Sudoers mínimo — solo lo que necesita el CI para deploy
cat > /etc/sudoers.d/bos-runner << SUDOEOF
# CI runner — permisos mínimos para deploy de bos-staging
$RUNNER_USER ALL=(root) NOPASSWD: /bin/systemctl stop bos-staging.service
$RUNNER_USER ALL=(root) NOPASSWD: /bin/systemctl start bos-staging.service
$RUNNER_USER ALL=(root) NOPASSWD: /bin/systemctl is-active bos-staging.service
$RUNNER_USER ALL=(root) NOPASSWD: /bin/cp /tmp/bos-staging /usr/local/bin/bos-staging
$RUNNER_USER ALL=(root) NOPASSWD: /bin/chown root\:root /usr/local/bin/bos-staging
$RUNNER_USER ALL=(root) NOPASSWD: /bin/chmod 755 /usr/local/bin/bos-staging
SUDOEOF
chmod 440 /etc/sudoers.d/bos-runner
echo "✅ Sudoers configurado"

# ── 2. Descargar runner ────────────────────────────────────
mkdir -p "$RUNNER_DIR"
chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
cd "$RUNNER_DIR"

RUNNER_TAR="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
if [ ! -f "$RUNNER_TAR" ]; then
  sudo -u "$RUNNER_USER" curl -fsSL -o "$RUNNER_TAR" \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TAR}"
fi
sudo -u "$RUNNER_USER" tar xzf "$RUNNER_TAR"
echo "✅ Runner extraído en $RUNNER_DIR"

# ── 3. Configurar runner ───────────────────────────────────
# Label "staging" → el workflow usa runs-on: [self-hosted, linux, staging]
sudo -u "$RUNNER_USER" ./config.sh \
  --url "$GITHUB_REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --name "staging-$(hostname)" \
  --labels "self-hosted,linux,staging,ubuntu-24" \
  --work "$RUNNER_DIR/_work" \
  --unattended \
  --replace
echo "✅ Runner configurado — label: staging"

# ── 4. Instalar como servicio systemd ─────────────────────
chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
./svc.sh install "$RUNNER_USER"
./svc.sh start
echo "✅ Servicio systemd activo"

# ── 5. Resource limits (runner no mata al daemon) ──────────
RUNNER_SVC=$(ls /etc/systemd/system/actions.runner.*.service 2>/dev/null | head -1)
if [ -n "$RUNNER_SVC" ]; then
  SVC_NAME=$(basename "$RUNNER_SVC")
  mkdir -p "/etc/systemd/system/${SVC_NAME}.d"
  cat > "/etc/systemd/system/${SVC_NAME}.d/resources.conf" << SVCEOF
[Service]
# Runner limitado a 1.5 cores y 2GB — bos-staging tiene prioridad
CPUQuota=150%
MemoryMax=2G
Nice=10
SVCEOF
  systemctl daemon-reload
  systemctl restart "$SVC_NAME"
  echo "✅ Resource limits aplicados"
fi

# ── 6. Dependencias de build ───────────────────────────────
apt-get install -y bc golang-go 2>/dev/null || true
echo "✅ Dependencias OK"

# ── 7. Resumen ─────────────────────────────────────────────
echo ""
echo "=== Estado ==="
./svc.sh status

echo ""
echo "=== Verificar en GitHub ==="
echo "   $GITHUB_REPO_URL/settings/actions/runners"
echo ""
echo "=== Logs ==="
echo "   journalctl -u 'actions.runner.*' -f"
echo ""
echo "=== PRÓXIMO PASO: configurar Environments en GitHub ==="
echo "   Settings → Environments → New environment → 'staging'"
echo "   Variables: BOS_ENV=staging, BOS_OBSERVER_V2=true"
echo "   Secrets:   BOS_STAGING_BOOTSTRAP_TOKEN"
echo ""
echo "✅ Instalación completa en $STAGING_HOST"
