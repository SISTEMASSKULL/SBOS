#!/bin/bash
# VERIFICACIÓN INDEPENDIENTE — ejecutar desde terminal externa
# No depende del agente — valida el estado real del entorno
# Uso: bash /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/scripts/verify-independiente.sh [TARGET]
#   TARGET: nombre del contenedor (default: sbos-k8s)

TARGET="${1:-sbos-k8s}"

echo "============================================"
echo "  VERIFICACIÓN INDEPENDIENTE — $TARGET"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 1. CONTENEDOR ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
podman ps --filter name="$TARGET" --format "Nombre: {{.Names}} | Status: {{.Status}} | Imagen: {{.Image}}"
echo ""
podman inspect "$TARGET" --format 'Hostname: {{.Config.Hostname}} | IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>&1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 2. K8S NODES ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
podman exec "$TARGET" kubectl get nodes -o wide 2>&1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 3. K8S PODS (ALL NAMESPACES) ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
podman exec "$TARGET" kubectl get pods -A -o wide 2>&1

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 4. FICHAS INSTALADAS — .sbos_state.json ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Try multiple paths
for sp in /etc/bos/.sbos_state.json /var/lib/bos/.sbos_state.json /tmp/.sbos_state.json; do
    if podman exec "$TARGET" test -f "$sp" 2>/dev/null; then
        echo "  [path: $sp]"
        podman exec "$TARGET" python3 -c "
import json
with open('$sp') as f:
    d = json.load(f)
print(f'  Version: {d.get(\"version\",\"?\")}  Hostname: {d.get(\"hostname\",\"?\")}')
fichas = d.get('fichas',{})
print(f'  Total fichas: {len(fichas)}')
for name, f in sorted(fichas.items()):
    print(f'    {name:35s} state={f.get(\"state\",\"?\"):25s} health={f.get(\"health_status\",\"?\")}')
" 2>&1
        break
    fi
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 5. PODS POR NAMESPACE ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for ns in sbos-system sbos-data sbos-identity sbos-gateway sbos-monitor kube-system; do
    pods=$(podman exec "$TARGET" kubectl get pods -n "$ns" --no-headers 2>&1)
    if echo "$pods" | grep -q "No resources"; then
        echo "  --- $ns: (vacío) ---"
    elif echo "$pods" | grep -q "error\|Error\|connection refused"; then
        echo "  --- $ns: ERROR ---"
        echo "  $pods"
    else
        echo "  --- $ns ---"
        echo "$pods"
    fi
    echo ""
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 6. DAEMON BOS CORRIENDO ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
podman exec "$TARGET" ps aux 2>&1 | grep -E "bosmin|bos |bosctl" | grep -v grep || echo "  (ningún daemon BOS detectado)"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 7. LOGS DEL DAEMON (últimas 30 líneas) ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for logf in /var/log/bosmin.log /var/log/bos.log /tmp/bosmin.log; do
    if podman exec "$TARGET" test -f "$logf" 2>/dev/null; then
        echo "  [$logf]"
        podman exec "$TARGET" tail -30 "$logf" 2>&1
        break
    fi
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
echo "=== 8. HEALTH CHECK COMMANDS ==="
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
podman exec "$TARGET" bash -c '
# Check K8s API
echo -n "  k8s API: "
if kubectl get --raw /healthz 2>/dev/null | grep -q ok; then echo "HEALTHY"; else echo "DOWN"; fi

# Check key services by port
for svc in "9443:bos-api" "5432:postgres" "9000:keycloak" "8000:tryton" "11434:ollama"; do
    port="${svc%%:*}"
    name="${svc##*:}"
    echo -n "  $name ($port): "
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        echo "LISTENING"
    else
        echo "NOT LISTENING"
    fi
done
' 2>&1

echo ""
echo "============================================"
echo "  FIN VERIFICACIÓN"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
