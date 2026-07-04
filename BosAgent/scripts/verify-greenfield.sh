#!/bin/bash
# VERIFICACIÓN GREENFIELD — BOS Bootstrap desde cero
# Ejecutar desde terminal externa mientras el agente trabaja
# Uso: bash /opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/scripts/verify-greenfield.sh
TARGET="${1:-sbos-greenfield}"

echo "============================================"
echo "  VERIFICACIÓN GREENFIELD — $TARGET"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"

# 1. CONTENEDOR
echo ""
echo "=== 1. CONTENEDOR ==="
podman ps --filter name="$TARGET" --format "Nombre: {{.Names}} | Status: {{.Status}}"

# 2. SYSTEMD
echo ""
echo "=== 2. SYSTEMD ==="
podman exec "$TARGET" systemctl is-system-running 2>&1

# 3. BOS COMPONENTS
echo ""
echo "=== 3. BOS COMPONENTS ==="
podman exec "$TARGET" bash -c '
echo "Core scripts:"
ls -la /tmp/00_*.sh 2>/dev/null || echo "  MISSING"
echo "Bos binary:"
ls -la /opt/bos/bin/bos 2>/dev/null || echo "  MISSING"
echo "Fichas dirs:"
ls /var/lib/bos-servers/servers/ 2>/dev/null | wc -l
'

# 4. .sbos_state.json
echo ""
echo "=== 4. ESTADO BOS ==="
for sp in /etc/bos/.sbos_state.json /tmp/.sbos_state.json; do
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

# 5. K8S (si está instalado)
echo ""
echo "=== 5. K8S STATUS ==="
podman exec "$TARGET" bash -c '
if command -v kubectl &>/dev/null && [ -f /etc/kubernetes/admin.conf ]; then
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "Nodes:"
    kubectl get nodes 2>&1
    echo "Pods:"
    kubectl get pods -A 2>&1 | head -20
else
    echo "K8s not installed yet"
fi
' 2>&1

echo ""
echo "============================================"
echo "  Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
