# SBOS-056 — Flujo de Instalación de Kubernetes (sbos-bootstrap-k8s)

**Evaluación del documento de instalación idempotente de K8s + estado de correcciones.**
**Versión:** 1.2 · **Fecha:** 2026-06-18 · **Actualizado con ADR-044**

**Referencia normativa:** ADR-044 — Repositorio de Instalación Autocontenido.
El flujo completo de instalación está documentado en `BOS_V8_SBOS-007-DEPLOY.md` §5
y se ejecuta con UN solo comando desde `github.com/SISTEMASSKULL/bos-install`.

---

## 1. Evaluación del Documento del Usuario

El documento propuesto por el operador define un flujo de 5 capas progresivas
para instalar Kubernetes de forma idempotente. Es **correcto y completo**.

La ficha `sbos-bootstrap-k8s` en `servers/S-HOST/sbos-bootstrap-k8s/task_catalog.sh`
(590 líneas) implementa todas las 5 capas + pasos adicionales de verificación.

### Matriz de Comparación (ACTUALIZADA — post-correcciones)

| Capa | Documento | Ficha actual | Estado |
|------|-----------|-------------|--------|
| **0 — OS** | swapoff, modprobe, sysctl ip_forward | ✅ Líneas 54-77: `verificar_swap_off` + `verificar_recursos` + módulos | ✅ CUBIERTO |
| **1 — Runtime** | containerd + SystemdCgroup=true | ✅ Líneas 97-167: `instalar_containerd` + `configurar_containerd` con `SystemdCgroup=true` forzado | ✅ CUBIERTO |
| **2 — Binarios** | kubelet+kubeadm+kubectl vía apt | ✅ Líneas 170-201: `instalar_kubeadm_kubectl_kubelet` vía `pkgs.k8s.io` + `apt-mark hold` | ✅ CUBIERTO |
| **3 — Init** | kubeadm init | ✅ Líneas 209-279: `kubeadm_init` con kubeadm-config.yaml + preflight ignore | ✅ CUBIERTO |
| **4 — kubeconfig** | cp admin.conf → kubeconfig | ✅ Líneas 282-293: `configurar_kubeconfig` copia a `/etc/bos/.kube/config` | ✅ CUBIERTO |
| **5 — CNI** | Calico apply + wait pods Ready | ✅ Líneas 296-355: `instalar_calico` + `esperar_nodo_ready` (timeout 600s) | ✅ CUBIERTO |
| **Post-install** | Taint + Namespaces + StorageClass | ✅ Líneas 357-389: `quitar_taint_master` + `crear_namespaces` + `crear_storageclass` | ✅ CUBIERTO |
| **Idempotencia** | `_cluster_exists()` verifica kubeconfig antes de kubectl | ✅ Línea 34: `[[ -f "$KUBECONFIG_DEST" ]] &&` — short-circuit, nunca ejecuta kubectl sin kubeconfig | ✅ CUBIERTO |
| **Repair** | Reparación de containerd/kubelet/calico/namespaces | ✅ Líneas 402-437: `ficha_repair` | ✅ CUBIERTO |
| **Test** | 7 verificaciones (containerd, apiserver, nodo, calico, ns, sc, taint) | ✅ Líneas 440-522: `ficha_test` | ✅ CUBIERTO |
| **Diagnosis** | Diagnóstico completo con journalctl | ✅ Líneas 566-589: `ficha_diagnosis` | ✅ CUBIERTO |
| **Uninstall** | kubeadm reset + limpiar configs | ✅ Líneas 547-563: `ficha_uninstall` | ✅ CUBIERTO |
| **State file** | `/var/lib/k8s-installer.state` | ❌ No tiene | 🟡 PENDIENTE |
| **Lock file** | `/var/run/k8s-installer.lock` | ❌ No tiene | 🟡 PENDIENTE |
| **Systemd oneshot** | Servicio de instalación automática al boot | ❌ No tiene | 🔵 FUTURO |

---

## 2. Gaps Abiertos (post-correcciones)

Solo quedan 2 gaps, ninguno bloqueante:

| # | Prioridad | Gap | Impacto | Acción |
|---|----------|-----|---------|--------|
| 🟡 1 | Media | **State file** (`/var/lib/bos/k8s-installer.state`) | Sin trazabilidad explícita de "instalación completada". `_cluster_exists()` hace health check pero no registra versión, timestamp, ni CIDRs usados | Agregar `update_state()` que escriba JSON con k8s_version, calico_version, pod_cidr, service_cidr, timestamp |
| 🔵 2 | Baja | **Servicio systemd** (`k8s-installer.service`) | Sin auto-recuperación tras reinicio. BOS ya ejecuta bajo demanda con `bosctl setup`, así que no es crítico | Crear oneshot service con `ConditionPathExists=!/var/lib/bos/k8s-installer.state` |

---

## 3. Verificación de Correcciones Clave

### Gap #1 (kubectl antes de kubeconfig) — CORREGIDO

```bash
# Línea 33-36 de task_catalog.sh
_cluster_exists() {
    [[ -f "$KUBECONFIG_DEST" ]] && \
        KUBECONFIG="$KUBECONFIG_DEST" kubectl cluster-info --request-timeout=5s > /dev/null 2>&1
}
```

El `&&` de bash hace short-circuit: si `$KUBECONFIG_DEST` no existe, la primera
condición es falsa y NUNCA se ejecuta kubectl. Esto es correcto.

### Gap #2 (SystemdCgroup) — CORREGIDO

```bash
# Línea 142 de task_catalog.sh
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

### Gap #3 (repo Google) — CORREGIDO

```bash
# Línea 179 de task_catalog.sh
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key"
```

### Gap #5 (ficha_uninstall) — CORREGIDO

```bash
# Líneas 547-563 de task_catalog.sh
ficha_uninstall() {
    kubeadm reset --force
    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    rm -f "$KUBECONFIG_DEST"
    rm -f /etc/crictl.yaml
}
```

---

## 4. Estado Actual del Deploy (VPS Staging)

La última ejecución en la VPS (13.140.128.230) confirmó:
- ✅ kubeadm instalado y corriendo
- ✅ Calico aplicado
- ✅ Nodo Ready
- ✅ Taint removido
- ✅ Namespaces creados: sbos-system, sbos-data, sbos-security, sbos-gateway, sbos-monitoring
- ⏭️ Próximo: PostgreSQL → Redis → Vault → Keycloak → Kong

---

## 5. Próximos Pasos

1. **Ahora:** Ejecutar `bosctl setup` — con kubeadm ya instalado, PASO 0 será idempotente y continuará con PASO 1 (namespace) → 1.5 (storage) → 2 (postgresql) → ...
2. **Próximo:** Agregar state file (gap 🟡 #1) para trazabilidad completa
3. **Futuro:** Servicio systemd oneshot (gap 🔵 #2)

---

*SBOS-056 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
