#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bootstrap-storage
# Iteración 1: PersistentVolumes hostPath (Retain) para las 19 fichas.
# Dependencias: sbos-bootstrap-k8s, sbos-bootstrap-cni
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-storage.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-storage] $*" | tee -a "$FICHA_LOG" >&2; }
_kubectl() { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# Tabla canónica: name|capacity|hostPath|namespace
# Debe coincidir exactamente con yaml_engine.yml.
readonly PVS=(
    "sbos-postgres-pv|100Gi|/data/postgres|sbos-data"
    "sbos-redis-pv|10Gi|/data/redis|sbos-data"
    "sbos-minio-pv|100Gi|/data/minio|sbos-data"
    "sbos-vault-pv|5Gi|/data/vault|sbos-security"
    "sbos-keycloak-pv|5Gi|/data/keycloak|sbos-security"
    "sbos-prometheus-pv|20Gi|/data/prometheus|sbos-monitoring"
    "sbos-grafana-pv|5Gi|/data/grafana|sbos-monitoring"
    "sbos-bkernel-pv|10Gi|/data/bkernel|sbos-system"
    "sbos-bauth-pv|5Gi|/data/bauth|sbos-system"
    "sbos-notifier-pv|5Gi|/data/notifier|sbos-system"
)

# _pv_exists: retorna 0 si el PV ya existe en el cluster.
_pv_exists() { _kubectl get pv "$1" > /dev/null 2>&1; }

# _apply_pv: crea un PV hostPath si no existe.
# Retorna 0 si fue creado, 1 si hubo error, skips silenciosamente si ya existe.
# El caller distingue "ya existía" vs "recién creado" verificando antes con _pv_exists.
_apply_pv() {
    local name="$1" capacity="$2" host_path="$3"

    # Asegurar que el directorio host existe (sin cambiar permisos — sbos-bootstrap-os los fijó)
    mkdir -p "$host_path"

    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-storage-XXXXXX.yaml)
    cat > "$tmp" <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ${name}
  labels:
    sbos-managed: "true"
    sbos-storage: "bootstrap"
spec:
  capacity:
    storage: ${capacity}
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: sbos-local
  hostPath:
    path: ${host_path}
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: Exists
EOF
    _kubectl apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    if (( rc == 0 )); then
        _log "PV creado: $name ($capacity → $host_path)"
    fi
    return $rc
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_k8s"
    if ! _kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_k8s: cluster no accesible"
        return 1
    fi
    echo "${__STEP_OK__} verificar_k8s"

    echo "${__STEP_START__} verificar_storageclass"
    if ! _kubectl get storageclass sbos-local > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_storageclass: sbos-local no existe — ejecutar sbos-bootstrap-k8s primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_storageclass"

    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. PersistentVolumes ─────────────────────────────────────
    echo "${__STEP_START__} crear_persistent_volumes"
    local created=0 skipped=0 failed=0

    for entry in "${PVS[@]}"; do
        IFS='|' read -r name capacity host_path _ <<< "$entry"

        if _pv_exists "$name"; then
            _log "PV $name ya existe — omitiendo"
            skipped=$((skipped + 1))
            continue
        fi

        if _apply_pv "$name" "$capacity" "$host_path"; then
            created=$((created + 1))
        else
            failed=$((failed + 1))
            _log "FALLO al crear PV: $name"
        fi
    done

    _log "PVs: $created creados, $skipped ya existían, $failed fallos"

    if (( failed > 0 )); then
        echo "${__STEP_FAIL__} crear_persistent_volumes: $failed fallos de ${#PVS[@]}"
        return 1
    fi
    echo "${__STEP_OK__} crear_persistent_volumes ($created creados, $skipped ya existían)"

    # ── 2. Verificar que los PVs están Available ─────────────────
    echo "${__STEP_START__} verificar_pvs_disponibles"
    local not_ready=0
    # Esperar hasta 30s por PVs recién creados
    local deadline=$(( $(date +%s) + 30 ))
    local pending_pvs=()
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "$entry"
        pending_pvs+=("$name")
    done

    while (( $(date +%s) < deadline )) && (( ${#pending_pvs[@]} > 0 )); do
        local still_pending=()
        for name in "${pending_pvs[@]}"; do
            local phase
            phase=$(_kubectl get pv "$name" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
            # Available = listo para usar. Bound = PVC ya lo reclamó (también válido).
            case "$phase" in
                Available|Bound) ;;
                *) still_pending+=("$name") ;;
            esac
        done
        pending_pvs=("${still_pending[@]+"${still_pending[@]}"}")
        (( ${#pending_pvs[@]} > 0 )) && sleep 2
    done

    if (( ${#pending_pvs[@]} > 0 )); then
        for name in "${pending_pvs[@]}"; do
            _log "PV $name no está Available/Bound tras 30s"
            not_ready=$((not_ready + 1))
        done
        echo "${__STEP_FAIL__} verificar_pvs_disponibles: $not_ready PVs no listos"
        return 1
    fi
    echo "${__STEP_OK__} verificar_pvs_disponibles (${#PVS[@]} PVs listos)"

    _log "sbos-bootstrap-storage instalado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "PersistentVolumes creados:"
    _kubectl get pv -l sbos-managed=true \
        --no-headers 2>/dev/null \
        | awk '{printf "  %-30s %-10s %-12s %s\n", $1, $2, $5, $6}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_pvs"
    local repaired=0
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name capacity host_path _ <<< "$entry"
        if ! _pv_exists "$name"; then
            _log "PV $name faltante — recreando..."
            _apply_pv "$name" "$capacity" "$host_path" && \
                repaired=$((repaired + 1)) || \
                _log "FALLO al recrear PV $name"
        fi
    done
    _log "Reparación: $repaired PVs recreados"
    echo "${__STEP_OK__} reparar_pvs ($repaired recreados)"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_storageclass"
    if _kubectl get storageclass sbos-local > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_storageclass"
    else
        echo "${__STEP_FAIL__} test_storageclass: sbos-local no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_pvs_existen"
    local missing=0
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "$entry"
        if ! _pv_exists "$name"; then
            _log "FALLO: PV $name no existe"
            missing=$((missing + 1))
        fi
    done
    if (( missing == 0 )); then
        echo "${__STEP_OK__} test_pvs_existen (${#PVS[@]}/$(( ${#PVS[@]} )) PVs)"
    else
        echo "${__STEP_FAIL__} test_pvs_existen: $missing/${#PVS[@]} PVs faltantes"
        ok=1
    fi

    echo "${__STEP_START__} test_pvs_phase"
    local bad_phase=0
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "$entry"
        local phase
        phase=$(_kubectl get pv "$name" \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        case "$phase" in
            Available|Bound) ;;
            *)
                _log "PV $name en fase inesperada: $phase"
                bad_phase=$((bad_phase + 1))
                ;;
        esac
    done
    if (( bad_phase == 0 )); then
        echo "${__STEP_OK__} test_pvs_phase (todos Available o Bound)"
    else
        echo "${__STEP_FAIL__} test_pvs_phase: $bad_phase PVs en fase no válida"
        ok=1
    fi

    echo "${__STEP_START__} test_directorios_host"
    local dir_missing=0
    for entry in "${PVS[@]}"; do
        IFS='|' read -r _ _ host_path _ <<< "$entry"
        [[ -d "$host_path" ]] || dir_missing=$((dir_missing + 1))
    done
    if (( dir_missing == 0 )); then
        echo "${__STEP_OK__} test_directorios_host (${#PVS[@]} directorios)"
    else
        echo "${__STEP_FAIL__} test_directorios_host: $dir_missing directorios faltantes en host"
        ok=1
    fi

    echo "${__STEP_START__} test_retain_policy"
    local wrong_policy=0
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "$entry"
        local policy
        policy=$(_kubectl get pv "$name" \
            -o jsonpath='{.spec.persistentVolumeReclaimPolicy}' 2>/dev/null || echo "Unknown")
        [[ "$policy" == "Retain" ]] || {
            _log "PV $name tiene reclaim policy '$policy' (esperado: Retain)"
            wrong_policy=$((wrong_policy + 1))
        }
    done
    if (( wrong_policy == 0 )); then
        echo "${__STEP_OK__} test_retain_policy (todos Retain)"
    else
        echo "${__STEP_FAIL__} test_retain_policy: $wrong_policy PVs sin Retain"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bootstrap-storage STATUS ==="
    echo ""
    echo "StorageClass:"
    _kubectl get storageclass sbos-local 2>/dev/null \
        | awk '{printf "  %s\n", $0}' || echo "  (no existe)"
    echo ""
    echo "PersistentVolumes SBOS:"
    _kubectl get pv -l sbos-managed=true \
        -o custom-columns='NAME:.metadata.name,CAP:.spec.capacity.storage,PHASE:.status.phase,POLICY:.spec.persistentVolumeReclaimPolicy,PATH:.spec.hostPath.path' \
        2>/dev/null || echo "  (ninguno)"
    echo ""
    echo "Directorios host:"
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name _ host_path _ <<< "$entry"
        local size
        size=$(du -sh "$host_path" 2>/dev/null | cut -f1 || echo "---")
        printf "  %-30s %-6s %s\n" "$host_path" \
            "$([[ -d "$host_path" ]] && echo OK || echo MISS)" "$size"
    done
    echo ""
    echo "Espacio total en /data:"
    df -h /data 2>/dev/null | tail -1 || echo "  /data no existe"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: eliminando PVs — política Retain, datos en /data NO se borran"
    echo "${__STEP_START__} eliminar_pvs"
    local deleted=0
    for entry in "${PVS[@]}"; do
        IFS='|' read -r name _ _ _ <<< "$entry"
        if _pv_exists "$name"; then
            _kubectl delete pv "$name" 2>/dev/null && \
                deleted=$((deleted + 1)) && \
                _log "PV $name eliminado" || \
                _log "No se pudo eliminar PV $name"
        fi
    done
    echo "${__STEP_OK__} eliminar_pvs ($deleted eliminados)"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bootstrap-storage ==="
    echo "PVs en el cluster:"
    _kubectl get pv 2>/dev/null \
        | awk '{printf "  %s\n", $0}' || echo "  (cluster no accesible)"
    echo ""
    echo "PVCs pendientes o en error:"
    _kubectl get pvc --all-namespaces 2>/dev/null \
        | grep -E "Pending|Lost" \
        | awk '{printf "  %s/%s %s\n", $1, $2, $3}' || echo "  (ninguna)"
    echo ""
    echo "Espacio en /data:"
    df -h /data 2>/dev/null || echo "  /data no existe"
    echo ""
    echo "Uso por directorio:"
    du -sh /data/*/ 2>/dev/null | awk '{printf "  %s\n", $0}' || echo "  (vacío)"
}
