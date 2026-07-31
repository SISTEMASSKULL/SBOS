# Anexo A.16 — Implementación Zero Trust Architecture en SBOS
## Guía de implementación NIST SP 800-207 aplicada al ecosistema BOS

**Versión:** 1.0.0 · **Fecha:** 2026-07-31 · **Autor:** bos-developer — SBOS
**Motor:** ① IAM Installer · **Fortalece:** 1.04 (Seguridad de Red)
**Norma base:** NIST SP 800-207 · NSA/CISA K8s Hardening Guide 2024 · ISO 27001:2022

---

## 1. Zero Trust en SBOS — Principios y roles

### 1.1 Los 7 Tenets de NIST SP 800-207 en SBOS

| Tenet | Descripción canónica | Componente SBOS | Estado |
|:-----:|---------------------|-----------------|:------:|
| 1 | Todos los recursos son Enterprise Resources | Fichas = recursos · gestionados por BOS como único instalador | ✅ |
| 2 | Toda comunicación asegurada independientemente de red | TLS 1.3 en :9443 · mTLS daemons · SPIFFE/SPIRE en K8s | 🟡 mTLS pendiente |
| 3 | Acceso per-session/per-resource, no per-network | ctx_id verificado en cada request (no solo al login) | ✅ |
| 4 | Política de acceso dinámica (identidad + estado del dispositivo) | bAuth 12 dominios: D05 (dispositivo) + D09 (riesgo) + D03 (temporal) | 🟡 bAuth pendiente |
| 5 | Monitoreo e integridad continua de todos los assets | Wazuh SIEM · Prometheus · audit log WORM | 🟡 Wazuh pendiente |
| 6 | Autenticación y autorización estricta y dinámica | FAPI 2.0 · DPoP · PAR · LoA 1-4 | 🔴 Fase III |
| 7 | Telemetría completa para mejorar postura de seguridad | Alertmanager + Grafana + Loki + audit log | 🟡 Fase V |

### 1.2 Los 3 componentes ZTA en SBOS

```
┌────────────────────────────────────────────────────────┐
│               Zero Trust Architecture SBOS              │
│                                                          │
│   ┌─────────┐    decide    ┌────────────────┐           │
│   │  bAuth  │◄────────────▶│  BOS daemon    │           │
│   │  (PE)   │              │  (PA)          │           │
│   │ 12 dom. │              │ ctx_id manager │           │
│   └─────────┘              └───────┬────────┘           │
│                                    │ allow/deny          │
│   ┌─────────┐                      ▼                    │
│   │  Kong   │◄──────────────┐ PEP decision              │
│   │  (PEP)  │               │                           │
│   │ reverse │ intercepts    │                           │
│   │  proxy  │──────────────▶│                           │
│   └─────────┘  every req    └───────────────────────────│
└────────────────────────────────────────────────────────┘

PE = Policy Engine (evalúa) · PA = Policy Administrator (decide + gestiona)
PEP = Policy Enforcement Point (aplica)
```

---

## 2. Microsegmentación de red

### 2.1 Las 6 zonas de seguridad SBOS

```
Zona            Namespaces         Puede hablar con
─────────────────────────────────────────────────────
sbos-edge       (Kong)             → identity, apps
sbos-identity   sbos-security      → data (solo lectura)
                                   ← edge, apps
sbos-data       sbos-data          Solo recibe, no inicia
sbos-apps       sbos-erp, sbos-*   → data, identity
                                   ← edge
sbos-ia         sbos-ai            Aislada de internet
                                   ← apps únicamente
sbos-infra      sbos-monitoring    → TODAS las zonas
                sbos-backup        (Vault, cert-manager, SPIRE, Prometheus)
```

### 2.2 Patrón de NetworkPolicy (Calico)

Cada namespace SBOS recibe 2 NetworkPolicies base automáticas:

```yaml
# 1. Denegar todo por defecto
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: <ns>
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  # sin reglas = todo denegado

---

# 2. Permitir DNS (requerido para service discovery)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: <ns>
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
```

Las NetworkPolicies específicas por ficha son **generadas automáticamente** por el
`bos.fwman` (Motor FWMAN de 3.08) cuando `portman.Assign()` registra un puerto.

### 2.3 Estado actual en VPS

La VPS de desarrollo ya tiene el patrón correcto en `sbos-data`:
```bash
kubectl get networkpolicy -n sbos-data
# default-deny-all         sbos-data
# allow-dns-egress         sbos-data
# allow-postgresql-access  sbos-data  # incluye sbos-security
```

**Pendiente:** replicar en sbos-security, sbos-gateway, sbos-web, sbos-monitoring,
sbos-erp, sbos-ai (Fase II del plan).

---

## 3. mTLS entre daemons del host

### 3.1 Por qué mTLS y no solo TLS

TLS autentica el servidor. mTLS autentica **ambas partes**. En un entorno Zero Trust,
un proceso malicioso con acceso al socket Unix podría suplantar a Kong para hacer
requests al BOS sin mTLS. Con mTLS, necesita el cert emitido por la CA interna.

### 3.2 Jerarquía de CAs (A.07)

```
SBOS Root CA (offline, air-gapped, ECDSA P-384, 10 años)
    │
    ├── CA Intermedia — Daemons host (3 años)
    │     Vault PKI Engine → emite certs para: bos, bauth, bkernel, biedata, bsearch, bnexus, bi18n
    │     TTL: 90 días · Renovación automática: Vault Agent · Hot-reload: SIGHUP
    │
    └── CA Intermedia — Workloads K8s (3 años)
          ├── cert-manager ClusterIssuer → certs TLS para fichas K8s (90 días)
          └── SPIRE Server → SVIDs mTLS entre pods (24h, auto-renovados)
```

### 3.3 Configuración en BOS (Fase II)

```go
// internal/server/api.go — activar tras Vault PKI operativo
caCert := loadFile(paths.VaultCABundle)    // /etc/bos/tls/ca-bundle.pem
caPool := x509.NewCertPool()
caPool.AppendCertsFromPEM(caCert)

tlsConfig := &tls.Config{
    MinVersion:   tls.VersionTLS13,
    CipherSuites: []uint16{
        tls.TLS_AES_256_GCM_SHA384,
        tls.TLS_CHACHA20_POLY1305_SHA256,
    },
    ClientAuth:  tls.RequireAndVerifyClientCert,
    ClientCAs:   caPool,
    Certificates: []tls.Certificate{loadBOSCert()},
}
```

### 3.4 Verificar mTLS operativo

```bash
# Debe fallar sin cert cliente
curl -k https://localhost:9443/health
# → tls: certificate required (o similar)

# Debe funcionar con cert cliente
curl --cert /etc/bos/tls/bos.crt --key /etc/bos/tls/bos.key \
     --cacert /etc/bos/tls/ca-bundle.pem https://localhost:9443/health
# → {"status":"ok"}
```

---

## 4. WireGuard — Acceso administrativo seguro

El servidor SBOS de producción solo tiene 3 puertos visibles desde internet:
- `:80` TCP — HTTP redirect a HTTPS (Kong)
- `:443` TCP — HTTPS (Kong)
- `:51820` UDP — WireGuard VPN

**Todo acceso administrativo** (SSH, kube-apiserver :6443, Kong Admin :8444,
Vault UI :8200, Grafana :3000) ocurre SOLO desde la interfaz WireGuard `wg0`.

```
# Solo accesible desde wg0 (10.8.0.0/24)
UFW: 22/TCP ALLOW from 10.8.0.0/24
UFW: 6443/TCP ALLOW from 10.8.0.0/24
UFW: 8444/TCP ALLOW from 10.8.0.0/24
UFW: DEFAULT DENY
```

**Generación de config cliente:**
```bash
bosctl admin vpn add-peer --name laptop-admin --pubkey <wg-public-key>
# → retorna config WireGuard lista para importar en el cliente
```

---

## 5. SPIFFE/SPIRE — Identidad de workload en K8s

SPIRE asigna identidades criptográficas (SVIDs) a cada pod sin configuración manual.
Linkerd usa SPIRE como CA, activando mTLS automático entre todos los pods SBOS.

```
Pod bAuth (sbos-security) ←──mTLS automático──→ Pod PostgreSQL (sbos-data)
  SVID: spiffe://sbos.cluster/ns/sbos-security/sa/bauth
  SVID: spiffe://sbos.cluster/ns/sbos-data/sa/postgresql
  Certificados X.509, renovados cada 12h por SPIRE Agent
```

**Sin SPIRE:** Linkerd usa su propia CA (menos seguro, sin identidad de workload formal).
**Con SPIRE (Fase II):** identidad criptográfica formal, auditada, rotada automáticamente.

---

## 6. Checklist de cumplimiento ZTA

Checklist ejecutable para verificar Zero Trust en la VPS:

```bash
#!/bin/bash
echo "=== Zero Trust Compliance Check SBOS ==="

# Tenet 1: recursos gestionados
bosctl ficha list | grep -c INSTALLED
echo "T1: ${?} fichas instaladas via BOS (0=falla)"

# Tenet 2: comunicaciones aseguradas
curl -s -o /dev/null -w "%{http_code}" http://localhost:9443/health
echo "T2: HTTP sin TLS debe retornar 400 o error"

# Tenet 3: acceso per-request
bos_rpc '{"jsonrpc":"2.0","method":"bos.ctx.validate","params":{"ctx_id":"invalid"},"id":1}'
echo "T3: ctx_id inválido debe retornar -32001"

# Tenet 5: monitoreo
curl -s http://localhost:9090/api/v1/query?query=bos_ctx_validate_fail_total | jq '.status'
echo "T5: Prometheus scrapeando métricas de seguridad"

# NRS-01: TLS 1.3
openssl s_client -connect localhost:9443 -tls1_2 2>&1 | grep "no protocols available"
echo "NRS-01: TLS 1.2 debe ser rechazado"

# CIS K8s 5.1.6: no wildcard RBAC
kubectl get clusterrolebindings -o json | jq '[.items[].rules[]?.verbs[]? | select(. == "*")] | length'
echo "CIS 5.1.6: debe ser 0"

# NetworkPolicies
kubectl get networkpolicy -A | grep -c default-deny
echo "NetworkPolicies deny-all activas"
```

---

*SKULL · SBOS · BosAgent · Julio 2026*
