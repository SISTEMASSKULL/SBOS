# Anexo A.70 — bAuth: Recursos Kubernetes (B02 Reconcile + NetworkPolicies)
## Manifests idempotentes para reconstrucción sin fricción

**Versión:** 1.0.0 · **Fecha:** 2026-07-25 · **Autor:** bauth-developer — SBOS  
**Implementa:** B02 `§lifecycle` — reconcile loop de expiración de roles  
**Referencia:** [A.13 BosAgent — Arquitectura K8s VPS de prueba](../../../../BosAgent/context/Documentacion/Anexos/A.13_ANEXO-VPS-PRUEBA-KUBERNETES-ARQUITECTURA.md)

---

## 1. Contexto

bAuth correrá como pod en el namespace `sbos-security` del cluster K8s de SBOS.
Hasta que BOS gestione el despliegue automáticamente, los recursos K8s de bAuth
se aplican con los manifests de este anexo.

**Namespace de bAuth:** `sbos-security`  
**Acceso a PostgreSQL:** `postgresql.sbos-data.svc.cluster.local:5432`  
**Secret de credenciales:** `bauth-pg-credentials` (en `sbos-security`)

---

## 2. Recursos K8s de bAuth (estado 2026-07-25)

| Recurso | Tipo | Namespace | Propósito |
|---|---|---|---|
| `bauth-pg-credentials` | Secret | `sbos-security` | Credenciales PostgreSQL para pods bAuth |
| `allow-bauth-egress-postgresql` | NetworkPolicy | `sbos-security` | Permite a pods `app=bauth` conectar a sbos-data:5432 |
| `bauth-b02-reconcile` | CronJob | `sbos-security` | Reconcile loop B02: depreca roles expirados cada 5 min |

---

## 3. Manifests completos

### 3.1 Secret — credenciales PostgreSQL

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bauth-pg-credentials
  namespace: sbos-security
  labels:
    app: bauth
    sbos.local/daemon: bauth
    sbos.local/block: B02
type: Opaque
stringData:
  PGPASSWORD: sbos_bootstrap_pass
  PGHOST: postgresql.sbos-data.svc.cluster.local
  PGPORT: "5432"
  PGDATABASE: SBOSDB
  PGUSER: postgres
```

> La clave `POSTGRES_PASSWORD` en el secret `postgresql-credentials` de `sbos-data`
> contiene la contraseña autoritativa. Si cambia, actualizar este secret.

### 3.2 NetworkPolicy — egress de bAuth hacia PostgreSQL

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-bauth-egress-postgresql
  namespace: sbos-security
  labels:
    sbos.local/daemon: bauth
spec:
  podSelector:
    matchLabels:
      app: bauth
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 5432
      protocol: TCP
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

> El ingress en `sbos-data` (`allow-postgresql-access`) ya autoriza `sbos-security`.
> Solo se necesita esta política de egress en el lado de bAuth.

### 3.3 CronJob — B02 Reconcile Loop

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: bauth-b02-reconcile
  namespace: sbos-security
  labels:
    app: bauth
    component: b02-reconcile
    sbos.local/block: B02
    sbos.local/daemon: bauth
spec:
  schedule: "*/5 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 5
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        metadata:
          labels:
            app: bauth
            component: b02-reconcile
        spec:
          restartPolicy: Never
          containers:
          - name: reconcile
            image: postgres:18.4-alpine
            imagePullPolicy: IfNotPresent
            command:
            - psql
            - -h
            - postgresql.sbos-data.svc.cluster.local
            - -p
            - "5432"
            - -U
            - postgres
            - -d
            - SBOSDB
            - -t
            - -c
            - >-
              SELECT rol_id, estado_previo, fecha_expiracion, procesado_en
              FROM bauth.fn_b02_reconcile_expiry('system.b02.reconcile.cronjob');
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: bauth-pg-credentials
                  key: PGPASSWORD
            resources:
              requests:
                cpu: 10m
                memory: 32Mi
              limits:
                cpu: 100m
                memory: 64Mi
```

**Comportamiento:**
- `concurrencyPolicy: Forbid` — si el ciclo anterior no terminó, el nuevo se salta
- `backoffLimit: 2` — máximo 2 reintentos por fallo de conexión
- `imagePullPolicy: IfNotPresent` — usa la imagen local (ya en caché en el nodo)
- Retorna una fila por cada rol deprecado; sin filas = sin roles expirados (normal)

---

## 4. Aplicación idempotente

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf

# Aplicar todos los recursos de una vez (kubectl apply es idempotente)
kubectl apply -f manifests/bauth/bauth-pg-credentials.yaml
kubectl apply -f manifests/bauth/allow-bauth-egress-postgresql.yaml
kubectl apply -f manifests/bauth/bauth-b02-reconcile-cronjob.yaml
```

O en un solo comando si se organizan en un directorio:

```bash
kubectl apply -f manifests/bauth/
```

---

## 5. Verificación post-aplicación

```bash
export KUBECONFIG=/etc/kubernetes/admin.conf

# 1. Verificar secret
kubectl get secret bauth-pg-credentials -n sbos-security

# 2. Verificar NetworkPolicy
kubectl get networkpolicy allow-bauth-egress-postgresql -n sbos-security

# 3. Verificar CronJob activo
kubectl get cronjob bauth-b02-reconcile -n sbos-security

# 4. Ejecutar manualmente y verificar Succeeded
kubectl create job bauth-b02-test \
  --from=cronjob/bauth-b02-reconcile \
  -n sbos-security

sleep 30

kubectl get job bauth-b02-test -n sbos-security
# → STATUS: Complete

kubectl delete job bauth-b02-test -n sbos-security
```

**Salida esperada del job:**
- Sin filas en stdout: no hay roles expirados pendientes (estado normal)
- Con filas: cada fila muestra un rol deprecado por expiración

---

## 6. Función SQL asociada

El CronJob llama a `bauth.fn_b02_reconcile_expiry()` que vive en la BD.
Está definida en el DDL (`SBOS_db_V2_DDL.sql`) y se aplica en el bootstrap de la BD.

```sql
-- Firma de la función
SELECT rol_id, estado_previo, fecha_expiracion, procesado_en
FROM bauth.fn_b02_reconcile_expiry(
    p_ctx_id TEXT DEFAULT 'system.b02.reconcile'
);
```

**Garantías:**
- Idempotente: re-ejecución no duplica eventos
- `FOR UPDATE SKIP LOCKED`: no colisiona con el trigger `trg_irrh_b02_validity`
- Registra cada expiración en `bauth.idn_roles_rol_lifecycle_event` con `trigger_type='RECONCILE'`

---

## 7. Evolución futura

Cuando el daemon bAuth esté desplegado como pod en K8s:

1. **El CronJob desaparece** — el reconcile loop se implementa como un tokio background
   task dentro del daemon Rust (`src/domain/versioning/reconcile.rs`)
2. **La NetworkPolicy se mantiene** — el pod del daemon también tiene `app=bauth`
3. **El Secret evoluciona** — incluirá más claves (DSN completo, certs TLS, etc.)
4. **BOS gestiona el despliegue** — estos manifests pasan a ser parte de la ficha de bAuth
   en `servers/fichas/bauth/`

---

## 8. Dependencias

| Componente | Depende de | Estado |
|---|---|---|
| CronJob `bauth-b02-reconcile` | Secret `bauth-pg-credentials` | ✅ |
| CronJob `bauth-b02-reconcile` | NetworkPolicy `allow-bauth-egress-postgresql` | ✅ |
| CronJob `bauth-b02-reconcile` | Función `bauth.fn_b02_reconcile_expiry()` en BD | ✅ |
| Función SQL | Tabla `bauth.idn_roles_rol_hierarchical` (T-041) con columnas B02 | ✅ |
| Función SQL | Tabla `bauth.idn_roles_rol_lifecycle_event` (T-B02L) con trigger WORM | ✅ |

---

*SKULL · SBOS · BauthAgent · 2026-07-25*
