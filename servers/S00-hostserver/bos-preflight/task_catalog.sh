#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha bos-preflight
#
# Instala las dependencias del SO que BOS necesita antes del wizard.
# Las dependencias se leen de manifest.yml (sección system_packages).
# Agregar un paquete nuevo = editar manifest.yml, no recompilar BOS.
#
# Señales obligatorias: __SBOS__STEP_START__ / __SBOS__STEP_OK__ / __SBOS__STEP_FAIL__
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/bos-preflight.log}"
FICHA_DIR="$(dirname "${BASH_SOURCE[0]}")"
MANIFEST="${FICHA_DIR}/manifest.yml"

# Modo de instalación: dev (advertencias no bloquean) | prod (requisitos estrictos)
# Establecido por bosctl system-install --mode dev|prod → env BOS_INSTALL_MODE
readonly BOS_INSTALL_MODE="${BOS_INSTALL_MODE:-prod}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [bos-preflight] $*" | tee -a "$FICHA_LOG"; }

# _warn_or_fail <nombre_step> <mensaje>
# dev:  emite STEP_SKIP + advertencia — no bloquea la instalación
# prod: emite STEP_FAIL + error — bloquea la instalación
_warn_or_fail() {
    local step="$1" msg="$2"
    if [[ "$BOS_INSTALL_MODE" == "dev" ]]; then
        _log "ADVERTENCIA [dev]: $msg"
        echo "${__STEP_SKIP__} ${step}: [DEV] $msg"
        return 0
    else
        _log "FALLO [prod]: $msg"
        echo "${__STEP_FAIL__} ${step}: $msg"
        return 1
    fi
}

# Mínimos reales del stack SBOS completo.
# Cálculo por componente en INVESTIGACION-LOG.md INV-001.
# Modificar solo si cambia el stack — no ajustar para que pase en hardware débil.
readonly _RAM_MIN_MB=16384
readonly _DISK_MIN_GB=165
readonly _CPU_MIN=8
readonly _PORTS_REQUIRED=(9440 9441 9442 9443 5432 6379 8080 8200 8000 8443 6443)

_check_resources() {
    local ram_mb cpu_cores disk_gb ok=0
    ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
    cpu_cores=$(nproc 2>/dev/null || echo 0)
    disk_gb=$(df -BG / 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4); print $4}' || echo 0)

    echo "${__STEP_START__} check_ram"
    if (( ram_mb < _RAM_MIN_MB )); then
        _warn_or_fail "check_ram" "RAM ${ram_mb}MB < ${_RAM_MIN_MB}MB requeridos para el stack SBOS" || ok=1
    else
        echo "${__STEP_OK__} check_ram: ${ram_mb}MB disponibles (mín ${_RAM_MIN_MB}MB)"
    fi

    echo "${__STEP_START__} check_cpu"
    if (( cpu_cores < _CPU_MIN )); then
        _warn_or_fail "check_cpu" "${cpu_cores} cores < ${_CPU_MIN} requeridos (K8s+PG+KC+Kong+daemons)" || ok=1
    else
        echo "${__STEP_OK__} check_cpu: ${cpu_cores} cores (mín ${_CPU_MIN})"
    fi

    echo "${__STEP_START__} check_disk"
    if (( disk_gb < _DISK_MIN_GB )); then
        _warn_or_fail "check_disk" "${disk_gb}GB libres en / < ${_DISK_MIN_GB}GB requeridos" || ok=1
    else
        echo "${__STEP_OK__} check_disk: ${disk_gb}GB libres (mín ${_DISK_MIN_GB}GB)"
    fi

    return $ok
}

_check_ports() {
    echo "${__STEP_START__} check_ports"
    local occupied=()
    for port in "${_PORTS_REQUIRED[@]}"; do
        ss -tlnp 2>/dev/null | grep -q ":${port}\b" && occupied+=("$port")
    done
    if (( ${#occupied[@]} > 0 )); then
        _warn_or_fail "check_ports" "puertos ya ocupados: ${occupied[*]}" || return 1
    else
        echo "${__STEP_OK__} check_ports: todos los puertos requeridos disponibles"
    fi
    return 0
}

_check_os_strict() {
    echo "${__STEP_START__} check_os_strict"
    local version
    version=$(grep '^VERSION_ID' /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "unknown")
    if [[ "$version" != "26.04" ]]; then
        _warn_or_fail "check_os_strict" "Ubuntu 26.04 LTS requerido — detectado: Ubuntu $version" || return 1
    else
        echo "${__STEP_OK__} check_os_strict: Ubuntu 26.04 LTS"
    fi
    return 0
}

# Lee la lista de paquetes de manifest.yml (sección system_packages).
# No requiere un parser YAML completo — el formato es fijo: "  - paquete"
_read_packages() {
    awk '/^system_packages:/,/^[^ ]/' "$MANIFEST" 2>/dev/null \
        | grep '^\s*-\s' \
        | sed 's/^\s*-\s*//'
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    _log "Modo de instalación: $BOS_INSTALL_MODE"
    echo "${__STEP_START__} verificar_root"
    if [[ $EUID -ne 0 ]]; then
        echo "${__STEP_FAIL__} verificar_root: se requiere ejecutar como root"
        return 1
    fi
    echo "${__STEP_OK__} verificar_root"

    # OS estricto + recursos + puertos — dev: advertencias, prod: bloquea
    _check_os_strict || return 1
    _check_resources || return 1
    _check_ports     || return 1
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Paquetes del sistema — leídos desde manifest.yml
    echo "${__STEP_START__} instalar_paquetes_sistema"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq 2>/dev/null || _log "ADVERTENCIA: apt-get update falló"

    local to_install=()
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            to_install+=("$pkg")
        fi
    done < <(_read_packages)

    if (( ${#to_install[@]} > 0 )); then
        _log "Instalando: ${to_install[*]}"
        apt-get install -y -qq "${to_install[@]}" 2>/dev/null \
            || _log "ADVERTENCIA: algunos paquetes no se pudieron instalar"
    else
        _log "Todos los paquetes del SO ya están instalados"
    fi
    echo "${__STEP_OK__} instalar_paquetes_sistema"

    # Usuario y grupo bosagent
    echo "${__STEP_START__} crear_usuario_bosagent"
    if ! getent group bosagent > /dev/null 2>&1; then
        groupadd --system bosagent
        _log "Grupo bosagent creado"
    fi
    if ! id bosagent > /dev/null 2>&1; then
        useradd --system --gid bosagent --no-create-home \
                --shell /bin/false --comment "BOS daemon user" bosagent
        _log "Usuario bosagent creado"
    fi
    echo "${__STEP_OK__} crear_usuario_bosagent"

    # Directorios necesarios
    echo "${__STEP_START__} crear_directorios"
    local dirs=(
        "/etc/bos:0750:root:bosagent"
        "/etc/bos/blibs:0750:root:bosagent"
        "/etc/bos/.kube:0750:bosagent:bosagent"
        "/etc/sbos:0750:bosagent:bosagent"
        "/run/bos:0750:bosagent:bosagent"
        "/var/log/bos:0750:bosagent:bosagent"
        "/var/log/bos/fichas:0750:bosagent:bosagent"
        "/opt/bos:0755:root:root"
        "/opt/bos/bin:0755:root:root"
        "/opt/bos/core:0750:bosagent:bosagent"
        "/data:0755:root:root"
    )
    for entry in "${dirs[@]}"; do
        IFS=':' read -r dir mode user group <<< "$entry"
        mkdir -p "$dir"
        chmod "$mode" "$dir"
        chown "${user}:${group}" "$dir" 2>/dev/null || true
    done
    echo "${__STEP_OK__} crear_directorios"

    # kubectl symlink (ficha 00)
    echo "${__STEP_START__} configurar_kubectl"
    kubectl_path=$(which kubectl 2>/dev/null || echo "")
    [ -z "$kubectl_path" ] && [ -f /usr/bin/kubectl ] && kubectl_path=/usr/bin/kubectl
    [ -n "$kubectl_path" ] && [ ! -f /usr/local/bin/kubectl ] && ln -sf "$kubectl_path" /usr/local/bin/kubectl
    echo "${__STEP_OK__} configurar_kubectl"

    # RPC token desarrollo (ficha 00)
    echo "${__STEP_START__} configurar_rpc_token"
    [ ! -f /etc/bos/rpc-token ] && echo "dev-token-2026" > /etc/bos/rpc-token && chmod 644 /etc/bos/rpc-token
    grep -q BOS_RPC_TOKEN /etc/bos/.env 2>/dev/null || echo "BOS_RPC_TOKEN=c2Jvc19hZG1pbjpkZXY6ZGV2LXRva2VuLTIwMjY=" >> /etc/bos/.env
    echo "${__STEP_OK__} configurar_rpc_token"

    # Certificado TLS autofirmado para Context API :9443 (M1.4, SBOS-054 §7.5)
    # Kong→BOS requiere TLS 1.3. En producción se reemplaza por Vault PKI (M2.2).
    echo "${__STEP_START__} generar_cert_tls"
    local cert_dir="/etc/bos/certs"
    mkdir -p "$cert_dir"
    if [ -f "$cert_dir/bos.crt" ] && [ -f "$cert_dir/bos.key" ]; then
        _log "Certificado TLS ya existe en $cert_dir — omitiendo generación"
    else
        openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
            -keyout "$cert_dir/bos.key" \
            -out "$cert_dir/bos.crt" \
            -subj "/CN=bos.sbos-system.svc.cluster.local" \
            -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,DNS:bos.sbos-system.svc.cluster.local" 2>/dev/null
        chmod 600 "$cert_dir/bos.key"
        chmod 644 "$cert_dir/bos.crt"
        chown bosagent:bosagent "$cert_dir/bos.crt" "$cert_dir/bos.key" 2>/dev/null || true
        _log "Certificado TLS autofirmado generado en $cert_dir (CN=bos.sbos-system.svc.cluster.local)"
    fi
    echo "${__STEP_OK__} generar_cert_tls"

    # Cgroup v2 delegation para bosagent
    echo "${__STEP_START__} configurar_cgroup_v2"
    local cg_conf="/etc/systemd/system/user@.service.d/delegate.conf"
    mkdir -p "$(dirname "$cg_conf")"
    cat > "$cg_conf" <<'EOF'
[Service]
Delegate=cpuset cpu io memory hugetlb pids rdma misc dmem
EOF
    systemctl daemon-reload 2>/dev/null || true
    echo "${__STEP_OK__} configurar_cgroup_v2"

    # Sudoers para bosagent (solo lo que realmente necesita)
    echo "${__STEP_START__} configurar_sudoers"
    cat > /etc/sudoers.d/bosagent <<'EOF'
# BOS daemon — generado por ficha bos-preflight
# No editar manualmente. Actualizar la ficha y ejecutar: bos ficha repair bos-preflight
bosagent ALL=(ALL) NOPASSWD: /bin/systemctl, /usr/bin/apt-get, \
    /usr/bin/kubectl, /usr/bin/kubeadm, /usr/bin/podman, \
    /usr/bin/apt, /sbin/reboot, /sbin/poweroff, /sbin/shutdown
EOF
    chmod 440 /etc/sudoers.d/bosagent
    visudo -c 2>/dev/null && _log "sudoers validado" || _log "ADVERTENCIA: visudo -c falló"
    echo "${__STEP_OK__} configurar_sudoers"

    _log "bos-preflight completado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Verificando estado post-install"
    id bosagent > /dev/null 2>&1 || { _log "FALLO: bosagent no existe"; return 1; }
    test -d /etc/bos  || { _log "FALLO: /etc/bos no existe"; return 1; }
    test -d /etc/sbos || { _log "FALLO: /etc/sbos no existe"; return 1; }
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    _log "Reparando bos-preflight..."
    ficha_install
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_usuario"
    id bosagent > /dev/null 2>&1 \
        && echo "${__STEP_OK__} test_usuario" \
        || { echo "${__STEP_FAIL__} test_usuario: bosagent no existe"; ok=1; }

    echo "${__STEP_START__} test_directorios"
    for d in /etc/bos /etc/sbos /run/bos /var/log/bos /opt/bos/bin; do
        if [[ ! -d "$d" ]]; then
            echo "${__STEP_FAIL__} test_directorios: $d no existe"
            ok=1
        fi
    done
    [[ $ok -eq 0 ]] && echo "${__STEP_OK__} test_directorios"

    echo "${__STEP_START__} test_paquetes"
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" \
            || { _log "FALLO: paquete $pkg no instalado"; ok=1; }
    done < <(_read_packages)
    [[ $ok -eq 0 ]] && echo "${__STEP_OK__} test_paquetes"

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== bos-preflight STATUS ==="
    echo "bosagent:  $(id bosagent 2>/dev/null && echo OK || echo FALTANTE)"
    echo "Directorios:"
    for d in /etc/bos /etc/sbos /run/bos /var/log/bos /opt/bos/bin; do
        printf "  %-25s %s\n" "$d" "$([ -d "$d" ] && echo OK || echo FALTANTE)"
    done
    echo "Paquetes instalados:"
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        local st; st=$(dpkg -l "$pkg" 2>/dev/null | grep "^ii" | awk '{print $3}' || echo "NO")
        printf "  %-25s %s\n" "$pkg" "${st:-NO INSTALADO}"
    done < <(_read_packages)
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "Desinstalando bos-preflight (no remueve binarios ni datos)"
    userdel bosagent 2>/dev/null || true
    rm -f /etc/sudoers.d/bosagent
    _log "bos-preflight desinstalado"
}
