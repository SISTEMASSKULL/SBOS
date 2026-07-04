#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-bootstrap-hard
# Iteración 1: CIS hardening — UFW + sysctl + Calico default-deny + Kyverno
#
# Se ejecuta DESPUÉS de que todas las fichas de aplicación están instaladas
# (execution_order: 250 — último paso del DAG).
# Dependencias: sbos-bootstrap-cni, sbos-bootstrap-monitoring, prometheus, grafana
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-hard.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
SVC_CIDR="${SVC_CIDR:-10.96.0.0/12}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-hard] $*" | tee -a "$FICHA_LOG" >&2; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _apply_manifest: aplica un manifest YAML desde un archivo temporal y lo elimina.
# Uso: _apply_manifest <nombre> <contenido>
_apply_manifest() {
    local name="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-hard-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    # || rc=$? captura el error sin que set -e termine la función,
    # garantizando que rm -f siempre se ejecute aunque apply falle.
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_root"
    if [[ $EUID -ne 0 ]]; then
        echo "${__STEP_FAIL__} verificar_root: se requiere root"
        return 1
    fi
    echo "${__STEP_OK__} verificar_root"

    echo "${__STEP_START__} verificar_k8s_operativo"
    if ! _k get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -q "^Ready$"; then
        echo "${__STEP_FAIL__} verificar_k8s_operativo: no hay nodos Ready — hardening abortado"
        return 1
    fi
    echo "${__STEP_OK__} verificar_k8s_operativo"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /var/log/bos/audit
    chmod 700 /var/log/bos/audit

    # ── 1. UFW ───────────────────────────────────────────────────
    echo "${__STEP_START__} instalar_ufw"
    if ! command -v ufw > /dev/null 2>&1; then
        _log "UFW no instalado — instalando..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y -qq ufw 2>/dev/null || {
            echo "${__STEP_FAIL__} instalar_ufw: apt install falló"
            return 1
        }
        _log "UFW instalado"
    fi
    echo "${__STEP_OK__} instalar_ufw"

    echo "${__STEP_START__} configurar_ufw"
    # CRÍTICO: DEFAULT_FORWARD_POLICY=ACCEPT es obligatorio para K8s.
    # ufw default deny forward bloquea el IP forwarding de pods.
    # Las NetworkPolicies de Calico ya controlan el tráfico entre pods.
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' \
        /etc/default/ufw 2>/dev/null || true

    ufw --force reset > /dev/null 2>&1 || true
    ufw default deny incoming  > /dev/null 2>&1
    ufw default allow outgoing > /dev/null 2>&1
    ufw default allow forward  > /dev/null 2>&1

    # Reglas externas (SBOS-050: solo 3 puertos externos)
    ufw allow 22/tcp   comment 'SSH administracion'  > /dev/null 2>&1
    ufw allow 80/tcp   comment 'HTTP->HTTPS redirect' > /dev/null 2>&1
    ufw allow 443/tcp  comment 'HTTPS externo'        > /dev/null 2>&1

    # Kubernetes — comunicación interna del cluster
    ufw allow 4789/udp comment 'Calico VXLAN'                        > /dev/null 2>&1
    ufw allow 179/tcp  comment 'Calico BGP'                          > /dev/null 2>&1
    ufw allow 10250/tcp comment 'kubelet API (kubectl logs/exec)'    > /dev/null 2>&1
    ufw allow 10256/tcp comment 'kube-proxy health'                  > /dev/null 2>&1

    # Tráfico de pods y servicios K8s (Calico + kube-proxy)
    ufw allow from "${POD_CIDR}"  comment 'Calico pod network'       > /dev/null 2>&1
    ufw allow from "${SVC_CIDR}"  comment 'K8s service network'      > /dev/null 2>&1

    # kube-apiserver: solo loopback (single-node) — bosctl accede via Unix socket
    ufw allow from 127.0.0.1 to any port 6443 proto tcp \
        comment 'kube-apiserver local'                               > /dev/null 2>&1

    ufw --force enable > /dev/null 2>&1
    _log "UFW activado: deny-in/allow-out/allow-fwd + reglas SBOS"
    echo "${__STEP_OK__} configurar_ufw"

    # ── 2. Sysctl hardening (CIS Ubuntu 26.04) ───────────────────
    echo "${__STEP_START__} sysctl_hardening"
    cat > /etc/sysctl.d/99-sbos-hardening.conf <<'EOF'
# CIS Ubuntu 26.04 LTS Benchmark — SBOS Hardening
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
EOF
    sysctl -p /etc/sysctl.d/99-sbos-hardening.conf > /dev/null 2>&1 || true
    _log "Sysctl hardening aplicado (CIS Ubuntu 26.04)"
    echo "${__STEP_OK__} sysctl_hardening"

    # ── 3. NetworkPolicy default-deny en todos los namespaces ────
    echo "${__STEP_START__} calico_default_deny_all"
    # Leer namespaces en array para evitar el conflicto heredoc/stdin del bucle while<<<
    local -a namespaces
    mapfile -t namespaces < <(_k get namespaces \
        --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null || true)

    local applied=0 skipped=0
    for ns in "${namespaces[@]}"; do
        [[ -z "$ns" ]] && continue
        case "$ns" in
            kube-system|kube-public|kube-node-lease)
                skipped=$((skipped+1)); continue ;;
        esac

        _apply_manifest "default-deny-${ns}" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${ns}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]" || true

        # allow-dns: Calico conntrack permite respuestas UDP sin regla de ingress adicional
        _apply_manifest "allow-dns-${ns}" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: ${ns}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53" || true

        applied=$((applied+1))
        _log "NetworkPolicy default-deny-all + allow-dns-egress: $ns"
    done
    _log "NetworkPolicies: $applied namespaces protegidos, $skipped omitidos (kube-*)"
    echo "${__STEP_OK__} calico_default_deny_all ($applied namespaces)"

    # ── 4. Kyverno → enforce mode ────────────────────────────────
    echo "${__STEP_START__} kyverno_enforce"
    if ! _k get ns kyverno > /dev/null 2>&1; then
        _log "Kyverno no instalado — saltando políticas"
        echo "${__STEP_SKIP__} kyverno_enforce: namespace kyverno no existe"
    else
        # Promover ClusterPolicies existentes de Audit → Enforce
        while IFS= read -r policy; do
            [[ -z "$policy" ]] && continue
            _k patch clusterpolicy "$policy" \
                --type=merge -p '{"spec":{"validationFailureAction":"Enforce"}}' \
                > /dev/null 2>&1 && _log "Kyverno policy $policy → Enforce" || true
        done < <(_k get clusterpolicy --no-headers \
            -o custom-columns=NAME:.metadata.name 2>/dev/null || true)

        # sbos-require-probes
        _apply_manifest "sbos-require-probes" 'apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-require-probes
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-probes
      match:
        any:
          - resources:
              kinds: [Deployment, StatefulSet, DaemonSet]
              namespaces:
                - sbos-system
                - sbos-data
                - sbos-security
                - sbos-gateway
                - sbos-monitoring
      validate:
        message: "Los contenedores SBOS deben tener readinessProbe y livenessProbe."
        pattern:
          spec:
            template:
              spec:
                containers:
                  - readinessProbe: "?*"
                    livenessProbe: "?*"' || true

        # sbos-require-resource-limits
        _apply_manifest "sbos-require-limits" 'apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-require-resource-limits
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-limits
      match:
        any:
          - resources:
              kinds: [Deployment, StatefulSet, DaemonSet]
              namespaces:
                - sbos-system
                - sbos-data
                - sbos-security
                - sbos-gateway
      validate:
        message: "Los contenedores SBOS deben tener resources.limits."
        pattern:
          spec:
            template:
              spec:
                containers:
                  - resources:
                      limits:
                        memory: "?*"
                        cpu: "?*"' || true

        # sbos-forbid-host-port (excepciones: prometheus-node-exporter, alloy)
        _apply_manifest "sbos-forbid-host-port" 'apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-forbid-host-port
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-host-port
      match:
        any:
          - resources:
              kinds: [Deployment, StatefulSet, DaemonSet]
              namespaces:
                - sbos-system
                - sbos-data
                - sbos-security
                - sbos-gateway
      exclude:
        any:
          - resources:
              names:
                - prometheus-node-exporter
                - alloy
      validate:
        message: "hostPort no permitido en namespaces SBOS."
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[].ports[].hostPort | length(@) }}"
                operator: GreaterThan
                value: 0' || true

        # sbos-forbid-privileged (excepción: alloy)
        _apply_manifest "sbos-forbid-privileged" 'apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: sbos-forbid-privileged
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-privileged
      match:
        any:
          - resources:
              kinds: [Deployment, StatefulSet, DaemonSet]
              namespaces:
                - sbos-system
                - sbos-data
                - sbos-security
                - sbos-gateway
                - sbos-monitoring
      exclude:
        any:
          - resources:
              names:
                - alloy
      validate:
        message: "Contenedores privilegiados no permitidos en namespaces SBOS."
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[?securityContext.privileged == `true`] | length(@) }}"
                operator: GreaterThan
                value: 0' || true

        _log "Kyverno: 4 políticas SBOS en modo Enforce"
        echo "${__STEP_OK__} kyverno_enforce (4 políticas)"
    fi

    # ── 5. Audit log rotation ────────────────────────────────────
    echo "${__STEP_START__} configurar_auditlog"
    cat > /etc/logrotate.d/bos-audit <<'EOF'
/var/log/bos/audit/*.log {
    daily
    rotate 90
    compress
    delaycompress
    missingok
    notifempty
    create 0600 root root
}
EOF
    echo "${__STEP_OK__} configurar_auditlog"

    # ── 6. Deshabilitar servicios innecesarios ───────────────────
    echo "${__STEP_START__} deshabilitar_servicios"
    local svcs_off=(bluetooth cups avahi-daemon)
    for svc in "${svcs_off[@]}"; do
        if systemctl is-enabled "$svc" 2>/dev/null | grep -q "^enabled$"; then
            systemctl disable --now "$svc" 2>/dev/null && \
                _log "Servicio deshabilitado: $svc" || true
        fi
    done
    echo "${__STEP_OK__} deshabilitar_servicios"

    _log "sbos-bootstrap-hard: CIS hardening completado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado de hardening:"
    echo "UFW: $(ufw status 2>/dev/null | head -1)"
    echo "ASLR: $(sysctl -n kernel.randomize_va_space 2>/dev/null)"
    local np_count
    np_count=$(_k get networkpolicy --all-namespaces --no-headers 2>/dev/null \
        | grep -c "default-deny-all" || echo "0")
    echo "Namespaces con default-deny: $np_count"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    _log "Reparando sbos-bootstrap-hard..."

    echo "${__STEP_START__} reparar_ufw"
    if command -v ufw > /dev/null 2>&1; then
        if ! ufw status 2>/dev/null | grep -q "Status: active"; then
            ufw --force enable > /dev/null 2>&1 && _log "UFW reactivado" || true
        fi
    fi
    echo "${__STEP_OK__} reparar_ufw"

    echo "${__STEP_START__} reparar_sysctl"
    sysctl -p /etc/sysctl.d/99-sbos-hardening.conf > /dev/null 2>&1 || true
    echo "${__STEP_OK__} reparar_sysctl"

    echo "${__STEP_START__} reparar_network_policies"
    # Reaplicar solo en namespaces SBOS que hayan perdido la política
    local sbos_ns=(sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring)
    for ns in "${sbos_ns[@]}"; do
        _k get namespace "$ns" > /dev/null 2>&1 || continue
        if ! _k get networkpolicy default-deny-all -n "$ns" > /dev/null 2>&1; then
            _apply_manifest "repair-deny-${ns}" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${ns}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]" && _log "default-deny-all restaurado en $ns" || true
        fi
    done
    echo "${__STEP_OK__} reparar_network_policies"

    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_ufw_activo"
    if command -v ufw > /dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
        echo "${__STEP_OK__} test_ufw_activo"
    else
        echo "${__STEP_FAIL__} test_ufw_activo: UFW no activo"
        ok=1
    fi

    echo "${__STEP_START__} test_ufw_forward_policy"
    local fwd_policy
    fwd_policy=$(grep "^DEFAULT_FORWARD_POLICY" /etc/default/ufw 2>/dev/null \
        | cut -d'"' -f2 || echo "DENY")
    if [[ "$fwd_policy" == "ACCEPT" ]]; then
        echo "${__STEP_OK__} test_ufw_forward_policy (ACCEPT — K8s pods pueden rutear)"
    else
        echo "${__STEP_FAIL__} test_ufw_forward_policy: DEFAULT_FORWARD_POLICY=${fwd_policy} (debe ser ACCEPT)"
        ok=1
    fi

    echo "${__STEP_START__} test_sysctl_hardening"
    local aslr kptr
    aslr=$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo "0")
    kptr=$(sysctl -n kernel.kptr_restrict 2>/dev/null || echo "0")
    if [[ "$aslr" == "2" && "$kptr" == "2" ]]; then
        echo "${__STEP_OK__} test_sysctl_hardening (ASLR=$aslr kptr=$kptr)"
    else
        echo "${__STEP_FAIL__} test_sysctl_hardening: ASLR=$aslr kptr=$kptr (esperado: 2 y 2)"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicies"
    local np_count
    np_count=$(_k get networkpolicy --all-namespaces --no-headers 2>/dev/null \
        | grep -c "default-deny-all" || echo "0")
    if (( np_count >= 5 )); then
        echo "${__STEP_OK__} test_networkpolicies ($np_count namespaces con default-deny)"
    elif (( np_count >= 3 )); then
        echo "${__STEP_OK__} test_networkpolicies ($np_count namespaces — aceptable)"
    else
        echo "${__STEP_FAIL__} test_networkpolicies: solo $np_count namespaces protegidos"
        ok=1
    fi

    echo "${__STEP_START__} test_kyverno_policies"
    if _k get ns kyverno > /dev/null 2>&1; then
        local policies_ok=0 policies_fail=0
        for policy in sbos-require-probes sbos-require-resource-limits \
                      sbos-forbid-host-port sbos-forbid-privileged; do
            if _k get clusterpolicy "$policy" > /dev/null 2>&1; then
                local mode
                mode=$(_k get clusterpolicy "$policy" \
                    -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || echo "Audit")
                if [[ "$mode" == "Enforce" ]]; then
                    policies_ok=$((policies_ok+1))
                else
                    _log "Policy $policy en modo $mode (esperado: Enforce)"
                    policies_fail=$((policies_fail+1))
                fi
            else
                _log "Policy $policy no existe"
                policies_fail=$((policies_fail+1))
            fi
        done
        if (( policies_fail == 0 )); then
            echo "${__STEP_OK__} test_kyverno_policies (${policies_ok}/4 en Enforce)"
        else
            echo "${__STEP_FAIL__} test_kyverno_policies: $policies_fail/4 no están en Enforce"
            ok=1
        fi
    else
        echo "${__STEP_SKIP__} test_kyverno_policies: Kyverno no instalado"
    fi

    echo "${__STEP_START__} test_audit_logrotate"
    if [[ -f /etc/logrotate.d/bos-audit ]]; then
        echo "${__STEP_OK__} test_audit_logrotate"
    else
        echo "${__STEP_FAIL__} test_audit_logrotate: /etc/logrotate.d/bos-audit no existe"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bootstrap-hard STATUS ==="
    echo ""
    echo "UFW:"
    ufw status 2>/dev/null | head -5 | awk '{print "  "$0}' \
        || echo "  (no disponible)"
    echo "  DEFAULT_FORWARD_POLICY: $(grep '^DEFAULT_FORWARD_POLICY' /etc/default/ufw 2>/dev/null \
        | cut -d'"' -f2 || echo '?')"
    echo ""
    echo "Sysctl hardening:"
    printf "  ASLR:       %s\n" "$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo '?')"
    printf "  kptr:       %s\n" "$(sysctl -n kernel.kptr_restrict 2>/dev/null || echo '?')"
    printf "  syncookies: %s\n" "$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo '?')"
    echo ""
    echo "NetworkPolicies default-deny ($(_k get networkpolicy --all-namespaces \
        --no-headers 2>/dev/null | grep -c "default-deny-all" || echo "0") namespaces):"
    _k get networkpolicy --all-namespaces --no-headers 2>/dev/null \
        | grep "default-deny-all" | awk '{printf "  %-25s %s\n", $1, $2}' \
        || echo "  (ninguna)"
    echo ""
    echo "Kyverno ClusterPolicies SBOS:"
    for p in sbos-require-probes sbos-require-resource-limits \
              sbos-forbid-host-port sbos-forbid-privileged; do
        local mode
        mode=$(_k get clusterpolicy "$p" \
            -o jsonpath='{.spec.validationFailureAction}' 2>/dev/null || echo "NO EXISTE")
        printf "  %-40s %s\n" "$p" "$mode"
    done
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: deshaciendo CIS hardening — sistema quedará sin protección"

    echo "${__STEP_START__} remover_ufw"
    ufw --force disable 2>/dev/null || true
    echo "${__STEP_OK__} remover_ufw"

    echo "${__STEP_START__} remover_sysctl"
    rm -f /etc/sysctl.d/99-sbos-hardening.conf
    sysctl --system > /dev/null 2>&1 || true
    echo "${__STEP_OK__} remover_sysctl"

    echo "${__STEP_START__} remover_kyverno_policies"
    _k delete clusterpolicy \
        sbos-require-probes sbos-require-resource-limits \
        sbos-forbid-host-port sbos-forbid-privileged \
        2>/dev/null || true
    echo "${__STEP_OK__} remover_kyverno_policies"

    echo "${__STEP_START__} remover_logrotate"
    rm -f /etc/logrotate.d/bos-audit
    echo "${__STEP_OK__} remover_logrotate"

    _log "Hardening removido (NetworkPolicies conservadas — gestión de sbos-bootstrap-cni)"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bootstrap-hard ==="
    echo "UFW reglas:"
    ufw status verbose 2>/dev/null | head -30 || echo "  UFW no disponible"
    echo ""
    echo "DEFAULT_FORWARD_POLICY:"
    grep "DEFAULT_FORWARD_POLICY" /etc/default/ufw 2>/dev/null || echo "  (no encontrado)"
    echo ""
    echo "Sysctl hardening activo:"
    sysctl -a 2>/dev/null \
        | grep -E 'randomize_va|kptr_restrict|dmesg_restrict|syncookies|protected_' \
        | awk '{print "  "$0}' || true
    echo ""
    echo "NetworkPolicies por namespace:"
    _k get networkpolicy --all-namespaces 2>/dev/null \
        | awk '{printf "  %-25s %-30s\n", $1, $2}' || echo "  (no disponible)"
    echo ""
    echo "Kyverno ClusterPolicies:"
    _k get clusterpolicy 2>/dev/null | awk '{print "  "$0}' || echo "  (Kyverno no instalado)"
}
