# FICHAS-ADMIN-MATRIX — Matriz de Administración de Fichas

**Versión:** 1.0 · **Fecha:** 2026-06-19 · **F11.F.4**
**Propósito:** Mapa completo de operaciones × 24 fichas. Cada celda indica el estado de soporte de una operación sobre una ficha.

---

## Leyenda

| Símbolo | Significado |
|---------|------------|
| ✅ | Soportado y probado |
| 🟡 | Implementado, pendiente de prueba en staging |
| ⚠️ | No aplica (la operación no tiene sentido para esta ficha) |
| ❌ | No implementado aún |

---

## Matriz de operaciones

| Ficha | Servidor | install | update | repair | remove | scale | pause | logs | diff |
|-------|----------|---------|--------|--------|--------|-------|-------|------|------|
| **bos-preflight** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-bootstrap-os** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-bootstrap-k8s** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-bootstrap-cni** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-bootstrap-storage** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-bootstrap-hard** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-bootstrap-monitoring** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-namespace** | S-HOST | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **postgresql** | S01 | ✅ | 🟡 | ✅ | ✅ | 🟡 | ✅ | ✅ | ✅ |
| **redis** | S01 | ✅ | 🟡 | ✅ | ✅ | 🟡 | ✅ | ✅ | ✅ |
| **minio** | S01 | ✅ | 🟡 | ✅ | ✅ | 🟡 | ✅ | ✅ | ✅ |
| **vault** | S02 | ✅ | 🟡 | ✅ | ✅ | 🟡 | ✅ | ✅ | ✅ |
| **kong** | S02 | ✅ | 🟡 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **nginx** | S02 | ✅ | 🟡 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **oauth2-proxy** | S02 | ✅ | 🟡 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **certbot** | S02 | ✅ | 🟡 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| **keycloak** | S03 | ✅ | 🟡 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **kyverno** | S03 | ✅ | 🟡 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| **linkerd** | S03 | ✅ | 🟡 | ✅ | ⚠️ | ⚠️ | ⚠️ | ✅ | ✅ |
| **sbos-notifier** | S06 | 🟡 | 🟡 | 🟡 | 🟡 | ✅ | ✅ | 🟡 | 🟡 |
| **prometheus** | S12 | ✅ | 🟡 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| **grafana** | S12 | ✅ | 🟡 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| **alertmanager** | S12 | ✅ | 🟡 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |
| **alloy** | S12 | ✅ | 🟡 | ✅ | ✅ | ⚠️ | ✅ | ✅ | ✅ |

---

## Notas por ficha

### S-HOST (bootstrap)
- **install/repair:** Ejecutan vía `00_MASTER_INSTALL_SBOS.sh`, probados en VPS staging
- **update:** Lógica implementada en Lifecycle, pendiente prueba en vivo
- **remove/scale/pause:** ⚠️ No aplica — son fichas de infraestructura crítica del host
- **logs/diff:** Soportados por el LogReader y DriftDetector

### S01 (datos)
- **postgresql/redis/minio:** StatefulSets, críticos, requieren governance dual-control para remove
- **scale:** Implementado en lógica, requiere integración K8s (F9) para ejecución real

### S02 (gateway/seguridad)
- **vault:** Crítico, remove requiere governance dual-control
- **kong/nginx:** Deployments con soporte completo de scale
- **certbot:** Scale ⚠️ no aplica (singleton)

### S03 (identidad)
- **keycloak:** Deployment crítico, remove requiere dual-control
- **kyverno:** Cluster-wide, scale ⚠️ no aplica
- **linkerd:** CNI, remove ⚠️ no aplica (rompería mTLS de todo el cluster)

### S06 (notificaciones)
- **sbos-notifier:** 🟡 Mayormente pendiente — ficha en desarrollo

### S12 (observabilidad)
- **prometheus/grafana/alertmanager/alloy:** Deployments estándar
- **scale:** ⚠️ Monitoreo típicamente es singleton en clusters pequeños

---

## Resumen de cobertura

| Operación | ✅ | 🟡 | ⚠️ | ❌ |
|-----------|----|----|----|-----|
| install | 23 | 1 | 0 | 0 |
| update | 0 | 24 | 0 | 0 |
| repair | 23 | 1 | 0 | 0 |
| remove | 14 | 1 | 9 | 0 |
| scale | 5 | 3 | 16 | 0 |
| pause | 8 | 0 | 16 | 0 |
| logs | 23 | 1 | 0 | 0 |
| diff | 23 | 1 | 0 | 0 |

**Total de celdas:** 192 (24 fichas × 8 operaciones)
**Cobertura de operaciones core (install/repair/logs/diff):** 95% ✅
**Gap principal:** update pendiente de prueba en staging para todas las fichas

---

## Gobernanza

| Operación | Categoría | Requiere |
|-----------|-----------|----------|
| install, repair, logs, diff, status, describe | Cat 1 (read) | Sin auth especial |
| update, scale (>0), pause | Cat 2 (write) | 1 admin |
| remove, scale a 0 | Cat 3 (destructive) | ⛔ 2 admins + ventana 60min + texto exacto |

---

*FICHAS-ADMIN-MATRIX.md v1.0 · BOS-REPAIR · SKULL · SBOS · Junio 2026*
*Actualizar con cada ficha nueva agregada a servers/.*
