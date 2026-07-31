# Anexo A.15 — Network Security Manager (NetMan)
## Firewall · Certificados · Puertos · IPS · Zero Trust — Motor Unificado de Seguridad de Red

**Versión:** 1.0.0  
**Fecha:** 2026-07-31  
**Autor:** bos-developer — SBOS  
**Fortalece al motor:** ③ Server FICHAS + ① IAM Installer  
**Normas:** NIST SP 800-207 (ZTA) · NIST SP 800-41 · ISO 27001:2022 A.8.20/A.8.21/A.8.24 · CIS K8s Benchmark v1.10 · RFC 6335 · RFC 8555 (ACME)  
**Precede a:** [A.12 — Port Manager Kardex](A.12_ANEXO-PORT-MANAGER-KARDEX.md) (subsistema incluido)

---

## 0. Por qué un motor unificado

Un sistema operativo empresarial soberano que no controla su red no es soberano.

La industria aprendió — con incidentes como SolarWinds (2020), Log4Shell (2021), y MOVEit (2023) — que la seguridad perimetral por sí sola no basta. El modelo moderno es **Zero Trust + Defense in Depth**: verificar todo, confiar en nada, segmentar agresivamente, renovar credenciales automáticamente.

SBOS aplica estos principios sin fricciones. El operador no configura reglas de firewall, no emite certificados, no mantiene listas de puertos. **El Network Security Manager lo hace automáticamente**, derivando toda la configuración de seguridad de las fichas declarativas.

### 0.1 Los cuatro motores del NetMan

```
┌─────────────────────────────────────────────────────────────────┐
│           NETWORK SECURITY MANAGER — bos.netman.*               │
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────┐ │
│  │  PORTMAN     │  │  CERTMAN     │  │  FWMAN       │  │  IPS │ │
│  │  bos.portman │  │  bos.certman │  │  bos.fwman   │  │      │ │
│  │              │  │              │  │              │  │      │ │
│  │ • RFC 6335   │  │ • Vault PKI  │  │ • nftables   │  │ CWD  │ │
│  │ • Algoritmo A│  │ • cert-mgr   │  │ • NetPolicy  │  │ F2B  │ │
│  │ • Algoritmo B│  │ • SPIFFE/    │  │ • WireGuard  │  │ psad │ │
│  │ • Kardex T408│  │   SPIRE      │  │ • DDoS rules │  │      │ │
│  │ • 7 métodos  │  │ • Kardex T413│  │ • SYNPROXY   │  │      │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────┘ │
│                                                                   │
│  Fuente de verdad: fichas declarativas (manifest.yml)            │
│  Principio: seguridad derivada, nunca configurada manualmente    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. PORTMAN — Motor de Puertos (ya implementado)

El portman está implementado en `internal/portman/` (commit `380cd69`).  
Ver diseño completo en [A.12 — Port Manager Kardex](A.12_ANEXO-PORT-MANAGER-KARDEX.md).

**Resumen de lo implementado:**
- Algoritmo A: `BASE_SERVIDOR + (FICHA_INDEX × 10) + TIPO_T`
- Algoritmo B: SHA-256 hash fallback, rango 32000-49151
- Resolución N1→N2→N3→HITL
- Verificación 3 capas: blacklist IANA/K8s → SBOS-050 → Kardex T-408
- 7 métodos JSON-RPC: `bos.portman.assign/lookup/release/check/list/validate/export`
- CLI: `bosctl port lookup/list/check/assign/release/validate/export`

**Integración pendiente:**
- Wire en `bos.ficha.install` → `portman.Assign()`
- Wire en `bos.ficha.remove` → `portman.Release()`
- Wire en `reconcile/scheduler.go` → `portman.ValidateKardex()` cada 300s

---

## 2. CERTMAN — Motor de Certificados TLS

### 2.1 El problema de los certificados en SBOS

Un entorno SBOS completo tiene **80+ certificados activos simultáneamente**:

| Ámbito | Cantidad | Tipo | Renovación |
|--------|----------|------|-----------|
| Daemons SBOS en host (bos, bauth, bkernel...) | 7 | X.509 ECDSA P-256 | Automática (Vault agent) |
| Servicios K8s por ficha (1-3 por ficha) | ~50 | X.509 TLS | cert-manager |
| mTLS entre pods (SPIFFE SVIDs) | ~120 | SVID X.509 (24h) | SPIRE automático |
| Wildcard externo (*.empresa.sbos.app) | 1 | X.509 DV | Let's Encrypt / ACME |
| Certificado Kong (TLS termination) | 1 | X.509 | ACME / Vault |
| CA interna SBOS | 3 | CA Root + 2 Intermediate | Manual/HITL (5 años) |

Sin automatización, la caducidad de un solo certificado puede provocar una interrupción total del servicio. Con automatización, el operador nunca ve un certificado.

### 2.2 Jerarquía de CAs en SBOS

```
SBOS Root CA (offline, 10 años, ECDSA P-384)
   │
   ├── SBOS Intermediate CA — Daemons (3 años, ECDSA P-256)
   │     └── Vault PKI Engine (emite certs de daemons SBOS, 90 días)
   │           ├── bos.service      /etc/bos/tls/bos.{crt,key}
   │           ├── bauth.service    /etc/bauth/tls/bauth.{crt,key}
   │           ├── bkernel.service  /etc/bkernel/tls/...
   │           └── ... (7 daemons SBOS)
   │
   └── SBOS Intermediate CA — Workloads (3 años, ECDSA P-256)
         └── cert-manager ClusterIssuer (emite certs de fichas, 90 días)
               ├── Certificate: keycloak.sbos-identity.svc
               ├── Certificate: postgresql.sbos-data.svc
               └── ... (1 cert por ficha que expone TLS)
         
         └── SPIRE Server (emite SVIDs para mTLS entre pods, 24h)
               ├── SVID: spiffe://sbos.cluster/ns/sbos-identity/sa/keycloak
               ├── SVID: spiffe://sbos.cluster/ns/sbos-data/sa/postgresql
               └── ... (1 SVID por ServiceAccount)
```

### 2.3 Herramientas del stack (estándar industria 2025-2026)

| Herramienta | Rol | Por qué |
|-------------|-----|---------|
| **Vault PKI** | CA interna + emisión de certs para daemons host | Ya está en el stack SBOS (Vault 2.0.1). PKI engine nativo, renovación automática vía Vault Agent |
| **cert-manager** | Gestión de certs en K8s (CNCF Graduated) | Estándar de facto para K8s. Integra con Vault como Issuer. Auto-renueva al 60% del lifetime |
| **SPIFFE/SPIRE** | Identidad de workload para mTLS automático | Identidad criptográfica por ServiceAccount. Linkerd y Cilium pueden usar SPIRE como CA |
| **acme.sh** | Certificados externos (Let's Encrypt / ACME) | Cliente ACME liviano. Integrable con Vault para almacenamiento centralizado |
| **Vault Agent** | Renovación automática en el host | Sidecar/daemon que monitorea TTL de certs y los renueva antes de expirar |

### 2.4 Certificados de daemons en el host

Los 7 daemons SBOS corren en el host (no en pods). Sus certificados siguen un patrón uniforme:

```
/etc/bos/
├── tls/
│   ├── bos.crt          # cert TLS del daemon bos (9443)
│   ├── bos.key          # clave privada
│   └── ca-bundle.crt    # CA interna SBOS (para verificar otros daemons)
└── ...

/etc/bauth/tls/bauth.{crt,key}
/etc/bkernel/tls/bkernel.{crt,key}
# ... (mismo patrón para cada daemon)
```

**Flujo de emisión (Vault PKI + Vault Agent):**

```
1. Vault PKI engine configurado con CA SBOS Intermediate — Daemons
2. Vault Agent en el host monitorea TTL de cada cert (/etc/<daemon>/tls/)
3. Cuando TTL < 30% → Vault Agent solicita renovación a Vault PKI
4. Vault emite nuevo cert (ECDSA P-256, 90 días, SAN = daemon.sbos.local)
5. Vault Agent escribe el cert en /etc/<daemon>/tls/ y envía SIGHUP al daemon
6. El daemon recarga TLS sin restart (hot-reload)
7. Evento registrado en Kardex de Certificados (T-413)
```

### 2.5 Certificados de fichas en K8s (cert-manager)

**Patrón por ficha:**

```yaml
# Generado automáticamente por portman.Assign() durante bos.ficha.install
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: sbos-keycloak-tls
  namespace: sbos-identity
spec:
  secretName: keycloak-tls-secret
  duration: 2160h    # 90 días
  renewBefore: 720h  # renovar 30 días antes
  issuerRef:
    name: sbos-vault-issuer
    kind: ClusterIssuer
  dnsNames:
  - keycloak.sbos-identity.svc.cluster.local
  - keycloak.sbos-identity.svc
  - keycloak
  - auth.empresa.sbos.app   # si está expuesto externamente
  privateKey:
    algorithm: ECDSA
    size: 256
```

**cert-manager ClusterIssuer con Vault:**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: sbos-vault-issuer
spec:
  vault:
    path: pki_workloads/sign/sbos-fichas
    server: https://vault.sbos-infra.svc.cluster.local:8200
    caBundle: <base64 CA SBOS>  # CA bundle para verificar Vault
    auth:
      kubernetes:
        role: cert-manager
        mountPath: /v1/auth/kubernetes
```

### 2.6 mTLS con SPIFFE/SPIRE (identidad de workload)

Para comunicación pod-a-pod con mTLS automático (Zero Trust):

```
SPIRE Server (DaemonSet en K8s)
   │
   ├── Emite SVID a cada workload basándose en ServiceAccount + namespace
   │   SVID = X.509 cert de 24 horas (auto-renovado cada 12h)
   │   Subject: spiffe://sbos.cluster/ns/sbos-identity/sa/keycloak
   │
   └── Linkerd/Cilium usan SPIRE como fuente de certificados
       → mTLS automático sin configuración por pod
```

### 2.7 Kardex de Certificados (T-413)

```sql
-- DDL propuesto para bos.cert_inventory (T-413)
CREATE TABLE IF NOT EXISTS bos.cert_inventory (
    cert_id         UUID PRIMARY KEY DEFAULT uuidv7(),
    
    -- Identidad del certificado
    subject_cn      TEXT NOT NULL,          -- "keycloak.sbos-identity.svc"
    subject_san     TEXT[],                 -- ["keycloak", "auth.empresa.sbos.app"]
    issuer          TEXT NOT NULL,          -- "SBOS Intermediate CA — Workloads"
    serial_number   TEXT,                   -- número de serie del cert
    fingerprint_sha256 TEXT,               -- SHA-256 del cert (audit trail)
    
    -- Lifecycle
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    days_remaining  INTEGER GENERATED ALWAYS AS
                    (EXTRACT(DAY FROM valid_until - NOW())::INTEGER) STORED,
    
    -- Tipo y uso
    cert_type       TEXT NOT NULL CHECK (cert_type IN (
                        'daemon_host',      -- bos, bauth, bkernel...
                        'ficha_k8s',        -- cert de ficha en K8s
                        'spiffe_svid',      -- identidad de workload mTLS
                        'external_wildcard',-- *.empresa.sbos.app
                        'kong_tls',         -- TLS Kong Gateway
                        'ca_internal'       -- CA raíz o intermedia SBOS
                    )),
    key_algorithm   TEXT DEFAULT 'ECDSA-P256',
    key_size        INTEGER DEFAULT 256,
    
    -- Vínculo con el activo
    service_name    TEXT,                   -- nombre del servicio/ficha/daemon
    namespace       TEXT,                   -- namespace K8s (NULL para host)
    ficha_id        TEXT,                   -- ficha responsable si aplica
    secret_name     TEXT,                   -- Secret K8s que contiene el cert
    host_path       TEXT,                   -- /etc/bos/tls/bos.crt si es host
    
    -- Gestión
    issuer_engine   TEXT NOT NULL CHECK (issuer_engine IN (
                        'vault_pki',        -- Vault PKI secrets engine
                        'cert_manager',     -- cert-manager ClusterIssuer
                        'spire',            -- SPIFFE/SPIRE
                        'acme_le',          -- Let's Encrypt vía ACME
                        'manual'            -- Manual (solo CA raíz)
                    )),
    auto_renew      BOOLEAN DEFAULT TRUE,
    renew_before_days INTEGER DEFAULT 30,
    
    -- Estado
    status          TEXT DEFAULT 'active' CHECK (status IN (
                        'active',           -- en uso
                        'expiring_soon',    -- días_restantes < renew_before_days
                        'expired',          -- caducado
                        'revoked',          -- revocado por Vault/OCSP
                        'superseded'        -- reemplazado por renovación
                    )),
    
    -- Audit
    issued_at       TIMESTAMPTZ DEFAULT NOW(),
    revoked_at      TIMESTAMPTZ,
    last_renewed_at TIMESTAMPTZ,
    ctx_id          TEXT NOT NULL DEFAULT 'system',
    
    CONSTRAINT uq_cert_service_ns UNIQUE (subject_cn, namespace, cert_type)
);

CREATE INDEX idx_cert_expiry    ON bos.cert_inventory(valid_until) WHERE status = 'active';
CREATE INDEX idx_cert_ficha     ON bos.cert_inventory(ficha_id);
CREATE INDEX idx_cert_type      ON bos.cert_inventory(cert_type);
CREATE INDEX idx_cert_expiring  ON bos.cert_inventory(days_remaining) WHERE status = 'active';
```

### 2.8 API JSON-RPC — `bos.certman.*`

| Método | Quién lo llama | Qué hace |
|--------|---------------|----------|
| `bos.certman.issue` | `bos.ficha.install` | Emite cert para una ficha vía cert-manager/Vault. Registra en T-413 |
| `bos.certman.revoke` | `bos.ficha.remove` | Revoca cert en Vault. Transiciona T-413 a 'revoked' |
| `bos.certman.renew` | `bos.certman.watch` | Renueva cert próximo a expirar. Idempotente |
| `bos.certman.status` | `bosctl cert status` | Estado de cert de una ficha/daemon |
| `bos.certman.list` | `bosctl cert list` | Kardex de Certificados con filtros |
| `bos.certman.watch` | `reconcile/scheduler.go` | Detecta certs próximos a expirar (< renew_before_days) y dispara renovación |
| `bos.certman.rotate_ca` | HITL only | Rotación de CA interna (operación de alto impacto) |
| `bos.certman.export` | `bosctl cert export` | Exporta inventario en Markdown (ISO 27001 A.8.24) |

### 2.9 CLI — `bosctl cert`

```bash
bosctl cert list                              # Listar todos los certificados con estado
bosctl cert list --expiring-in 30             # Certs que expiran en 30 días
bosctl cert list --ficha keycloak             # Certs de una ficha específica
bosctl cert status --ficha keycloak           # Estado detallado
bosctl cert renew --ficha keycloak            # Forzar renovación anticipada
bosctl cert export                            # Kardex en Markdown (ISO 27001 A.8.24)
```

---

## 3. FWMAN — Motor de Firewall y Políticas de Red

### 3.1 Dos capas de firewall en SBOS

SBOS implementa defensa en profundidad con dos capas complementarias:

```
┌─────────────────────────────────────────────────────────────────┐
│  CAPA 1 — HOST FIREWALL (nftables)                              │
│  Controla: tráfico que entra/sale del servidor físico           │
│  Motor: nftables (Linux kernel, GA en K8s 1.33+)               │
│  Gestión: bos.fwman.host.*                                      │
│                                                                   │
│  REGLAS BASE (deny-all, allows explícitos):                      │
│  • ACCEPT: 51820/UDP (WireGuard admin)                          │
│  • ACCEPT: 443/TCP (Kong HTTPS)                                  │
│  • ACCEPT: 80/TCP (Kong HTTP → redirect 443)                     │
│  • ACCEPT: established, related (stateful)                       │
│  • DROP: todo lo demás (incluyendo 22/SSH desde internet)        │
│                                                                   │
│  PROTECCIÓN ACTIVA:                                              │
│  • SYNPROXY (SYN flood)                                          │
│  • Rate limiting por IP (100 conn/s)                             │
│  • TCP flags inválidos → DROP inmediato                          │
│  • Bogon filter (IPs privadas como fuente)                       │
│  • CrowdSec bouncer (blocklist comunitaria dinámica)             │
└──────────────────────┬──────────────────────────────────────────┘
                       │ tráfico pasa al cluster K8s
┌──────────────────────▼──────────────────────────────────────────┐
│  CAPA 2 — POD FIREWALL (K8s NetworkPolicy + Calico/Cilium)      │
│  Controla: tráfico entre pods, entre namespaces                  │
│  Motor: Calico nftables dataplane o Cilium eBPF                  │
│  Gestión: bos.fwman.policy.*                                     │
│                                                                   │
│  MICROSEGMENTACIÓN POR ZONA DE SEGURIDAD SBOS:                  │
│  • sbos-identity  (bauth, Keycloak)                              │
│  • sbos-data      (PostgreSQL, Redis, bkernel)                   │
│  • sbos-apps      (ERP, CRM, fichas de negocio)                  │
│  • sbos-edge      (Kong Gateway, Ingress)                        │
│  • sbos-ia        (modelos IA locales)                           │
│  • sbos-infra     (Vault, monitoring)                            │
│                                                                   │
│  REGLA BASE: deny-all en cada namespace                          │
│  + allows explícitos derivados del Kardex de Puertos            │
└─────────────────────────────────────────────────────────────────┘
```

### 3.2 Ruleset nftables base de SBOS

El Motor de Firewall genera y aplica el siguiente ruleset. No se edita manualmente.

```
# Tabla principal: inet (IPv4 + IPv6 unificados)
table inet sbos_firewall {

    # ── Conjuntos dinámicos (CrowdSec bouncer los actualiza) ────────────
    set crowdsec_blacklist {
        type ipv4_addr
        flags dynamic, timeout
        timeout 4h
    }

    set admin_whitelist {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }
        # Actualizado por bos.fwman.admin_whitelist
    }

    # ── Rate-limiting maps ───────────────────────────────────────────────
    map syn_rate {
        type ipv4_addr : verdict
        flags dynamic
        timeout 10s
        gc-interval 10s
    }

    map conn_count {
        type ipv4_addr : integer
        flags dynamic
        size 65535
    }

    # ── Chain PREROUTING (raw — antes de conntrack, para SYNPROXY) ──────
    chain prerouting_raw {
        type filter hook prerouting priority raw; policy accept;
        
        # SYNPROXY: interceptar SYN en puertos públicos antes del conntrack
        tcp dport { 80, 443 } tcp flags syn notrack
    }

    # ── Chain INPUT ──────────────────────────────────────────────────────
    chain input {
        type filter hook input priority 0; policy drop;
        
        # 1. CrowdSec blacklist — DROP inmediato
        ip saddr @crowdsec_blacklist drop
        
        # 2. Loopback
        iif lo accept
        
        # 3. Stateful (connexiones established/related)
        ct state established,related accept
        ct state invalid drop
        
        # 4. SYNPROXY: completar handshake
        tcp dport { 80, 443 } tcp flags syn ct state untracked \
            synproxy mss 1460 wscale 9 timestamp sack-perm
        tcp dport { 80, 443 } ct state invalid drop
        
        # 5. TCP flags inválidos (NULL, XMAS, SYN+FIN scans)
        tcp flags & (fin|syn|rst|psh|ack|urg) == fin|syn|rst|psh|ack|urg drop
        tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 drop
        tcp flags & (syn|fin) == syn|fin drop
        tcp flags & (syn|rst) == syn|rst drop
        
        # 6. Bogon filter
        ip saddr {
            0.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8,
            169.254.0.0/16, 198.18.0.0/15, 198.51.100.0/24,
            203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4
        } drop
        
        # 7. ICMP (rate limited)
        icmp type echo-request limit rate 5/second burst 10 packets accept
        icmp type echo-request drop
        
        # 8. WireGuard (acceso admin — solo IP whitelist si se configura)
        udp dport 51820 accept
        
        # 9. Kong público (HTTP/HTTPS)
        tcp dport { 80, 443 } accept
        
        # 10. Rate limiting conexiones TCP por IP (100/s)
        tcp dport { 80, 443 } \
            meter tcp_rate { ip saddr limit rate over 100/second } \
            drop
        
        # 11. Connection count por IP (max 200 conn simultáneas)
        tcp dport { 80, 443 } \
            meter tcp_conncount { ip saddr ct count over 200 } \
            drop
        
        # 12. UDP flood
        ip protocol udp \
            meter udp_flood { ip saddr limit rate over 1000/second burst 1500 } \
            drop
        
        # [Todos los demás → DROP por policy]
    }

    # ── Chain FORWARD (tráfico K8s inter-pod) ───────────────────────────
    chain forward {
        type filter hook forward priority 0; policy accept;
        # Calico/Cilium gestionan el forward — no tocar
        # Solo añadir reglas globales aquí (ej: bloquear Inter-VPC no deseado)
    }

    # ── Chain OUTPUT ─────────────────────────────────────────────────────
    chain output {
        type filter hook output priority 0; policy accept;
        # Permitir todo el tráfico de salida (servidores PULL-only)
        # Si se requiere egress filtering, agregarlo aquí
    }
}
```

### 3.3 NetworkPolicy K8s generadas automáticamente

El Fwman genera las NetworkPolicies de K8s derivándolas del Kardex de Puertos (T-408).  
Cada vez que `bos.portman.assign` registra un puerto, `bos.fwman.policy.sync` genera la NetworkPolicy correspondiente.

**Patrón por namespace (base):**

```yaml
# Generado por bos.fwman.policy.sync — NO editar manualmente
# Fuente de verdad: Kardex T-408 + manifest.yml de la ficha

# 1. Deny-all base (siempre presente en todo namespace SBOS)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sbos-default-deny
  namespace: sbos-identity  # se repite en cada namespace
  labels:
    sbos.io/managed-by: fwman
    sbos.io/version: "1"
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# 2. Permitir DNS (requerido siempre)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sbos-allow-dns
  namespace: sbos-identity
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
---
# 3. Permit ingress para keycloak (generado del Kardex T-408 ficha=keycloak)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sbos-ingress-keycloak
  namespace: sbos-identity
  labels:
    sbos.io/managed-by: fwman
    sbos.io/ficha: keycloak
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: keycloak
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          sbos.io/zone: edge         # solo desde Kong (sbos-edge)
    ports:
    - port: 8080  # containerPort del Kardex (port_role=container)
      protocol: TCP
  - from:
    - namespaceSelector:
        matchLabels:
          sbos.io/zone: identity     # desde otros pods de identity (admin)
    ports:
    - port: 9000  # admin port (tipo_t=4)
      protocol: TCP
```

### 3.4 Microsegmentación por zona de seguridad

```
SBOS define 6 zonas de seguridad (namespaces K8s + labels):

sbos-edge (zona: edge)
  └─ Kong Gateway — único punto de entrada externo
  └─ Puede enviar a: sbos-identity, sbos-apps
  └─ No puede recibir de: nada (solo recibe de internet)

sbos-identity (zona: identity)
  └─ bauth, Keycloak
  └─ Puede enviar a: sbos-data (leer credenciales)
  └─ Puede recibir de: sbos-edge, sbos-apps (autenticación)

sbos-data (zona: data)
  └─ PostgreSQL, Redis, bkernel
  └─ No puede iniciar conexiones salientes (recibe solo)
  └─ Puede recibir de: sbos-identity, sbos-apps

sbos-apps (zona: apps)
  └─ ERP, CRM, fichas de negocio
  └─ Puede enviar a: sbos-data, sbos-identity
  └─ Puede recibir de: sbos-edge

sbos-ia (zona: ai)
  └─ Modelos IA locales
  └─ Completamente aislada de internet (air-gapped)
  └─ Solo recibe de sbos-apps (inference requests)

sbos-infra (zona: infra)
  └─ Vault, monitoring, cert-manager, SPIRE
  └─ Puede recibir de: todos los namespaces (métricas, audit, certs)
  └─ Puede enviar a: todos (PKI, secrets)

REGLA: Tráfico no especificado entre zonas → DENIED por NetworkPolicy
```

### 3.5 WireGuard para acceso administrativo

El acceso SSH y al panel admin de Kong nunca se expone directamente a internet.  
Todo acceso administrativo pasa por WireGuard:

```
nftables del host:
  ACCEPT: 51820/UDP (WireGuard VPN)
  ACCEPT: 80/443 TCP (Kong público)
  DROP: 22/TCP (SSH — solo desde interfaz WireGuard wg0)
  DROP: 8444/TCP (Kong admin — solo desde wg0)
  DROP: todo lo demás

Dentro de la VPN WireGuard (red 10.7.0.0/24):
  SSH: 10.7.0.1:22
  kubectl: 10.7.0.1:6443 (kube-apiserver)
  Kong admin: 10.7.0.1:8444
  Grafana/monitoring: 10.7.0.1:3000
```

**Patrón de WireGuard en nftables:**

```
# Solo SSH desde wg0
chain input {
    iif "wg0" tcp dport 22 accept
    iif "wg0" tcp dport 8444 accept
    iif "wg0" tcp dport 6443 accept
    tcp dport 22 drop    # desde cualquier otra interfaz → DROP
}
```

### 3.6 API JSON-RPC — `bos.fwman.*`

| Método | Quién lo llama | Qué hace |
|--------|---------------|----------|
| `bos.fwman.policy.sync` | `bos.ficha.install` automático | Genera/actualiza NetworkPolicy K8s desde Kardex T-408 |
| `bos.fwman.policy.status` | `bosctl fw policy list` | Lista NetworkPolicies activas por namespace |
| `bos.fwman.host.status` | `bosctl fw host status` | Estado del ruleset nftables del host |
| `bos.fwman.host.validate` | `reconcile/scheduler.go` | Verifica que el ruleset nftables coincide con la config canónica |
| `bos.fwman.host.reload` | HITL / operador | Recarga el ruleset nftables desde la config canónica |
| `bos.fwman.whitelist.add` | `bosctl fw whitelist add <ip>` | Agrega IP a admin_whitelist (WireGuard bypass temporal) |
| `bos.fwman.whitelist.remove` | `bosctl fw whitelist remove <ip>` | Remueve IP de admin_whitelist |
| `bos.fwman.audit` | `bosctl fw audit` | Compara ruleset actual vs canónico — detecta modificaciones manuales |

### 3.7 CLI — `bosctl fw`

```bash
bosctl fw policy list                    # NetworkPolicies activas
bosctl fw policy list --ns sbos-identity # Por namespace
bosctl fw host status                    # Estado ruleset nftables
bosctl fw host validate                  # Detectar drift en nftables
bosctl fw host reload                    # Recargar ruleset canónico
bosctl fw whitelist add 203.0.113.5      # Whitelist temporal
bosctl fw whitelist list                 # Ver whitelist activa
bosctl fw audit                          # Auditoría completa
```

---

## 4. IPS — Motor de Prevención de Intrusiones

### 4.1 Stack IPS/IDS en SBOS

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1 — nftables (preventivo, nanosegundos)                  │
│  • TCP flags inválidos (NULL, XMAS, SYN+FIN)                    │
│  • Rate limiting (100 conn/s por IP)                             │
│  • Bogon filter                                                  │
│  • SYNPROXY (anti-SYN-flood)                                     │
│  → Sin overhead: reglas en el kernel, antes del proceso de paquete│
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│  LAYER 2 — CrowdSec (behavioral, segundos)                       │
│  • Agent en el host: analiza logs nftables + Kong + SSH          │
│  • Detecta: brute force, port scan, credential stuffing,         │
│    web scraping, DDoS lento (slowloris)                          │
│  • Bouncer nftables: actualiza @crowdsec_blacklist dinámicamente │
│  • Blocklist comunitaria: ~2M IPs maliciosas conocidas           │
│  • Decision TTL: 4 horas (configurable)                          │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│  LAYER 3 — fail2ban + nftables (reactivo, segundos-minutos)      │
│  • Complementa CrowdSec para patrones de log específicos de SBOS │
│  • Protege: SSH (en wg0), Kong admin (8444)                      │
│  • banaction: nftables-multiport (no iptables)                   │
│  • maxretry: 3 intentos en 10 minutos → ban 1 hora               │
└──────────────────────┬──────────────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────────────┐
│  LAYER 4 — psad (detección de port scan, minutos)                │
│  • Analiza logs nftables de paquetes DROP                         │
│  • Detecta: nmap, masscan, ZGrab, patterns de scan               │
│  • Auto-bloquea IPs escaneando vía nftables                      │
│  • Registra en audit log con nivel de severidad                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 CrowdSec en Kubernetes

```yaml
# DaemonSet CrowdSec — lee logs del host y de pods
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: crowdsec-agent
  namespace: sbos-infra
spec:
  selector:
    matchLabels:
      app: crowdsec
  template:
    spec:
      hostPID: true          # Necesario para acceder a logs del host
      hostNetwork: true      # Necesario para leer logs de red
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: nftables-log
        hostPath:
          path: /var/log/nftables/
      containers:
      - name: crowdsec-agent
        image: crowdsecurity/crowdsec:v1.6
        env:
        - name: COLLECTIONS
          value: "crowdsecurity/linux crowdsecurity/nginx crowdsecurity/ssh"
```

**Bouncers activos:**
- `crowdsec-nftables-bouncer` — actualiza `@crowdsec_blacklist` en nftables del host
- `crowdsec-kong-plugin` — bloquea en Kong antes de que llegue al cluster

### 4.3 fail2ban con nftables (configuración SBOS)

```ini
# /etc/fail2ban/jail.d/sbos.conf
[DEFAULT]
banaction = nftables-multiport
banaction_allports = nftables-allports
backend = systemd

# SSH vía WireGuard (solo en interfaz wg0)
[sshd-wireguard]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600

# Kong Admin API (8444)
[kong-admin]
enabled = true
port = 8444
filter = kong-admin
logpath = /var/log/kong/admin.log
maxretry = 5
findtime = 300
bantime = 7200
```

### 4.4 Logging de red (audit trail)

Todo evento de red relevante se registra en un formato estructurado centralizable con Loki:

```
# /var/log/nftables/sbos-firewall.log (via nftables LOG action)
{"ts":"2026-07-31T10:23:44Z","event":"DROP","src":"198.51.100.45","dst":"10.0.0.1","dport":22,"proto":"TCP","reason":"port_not_allowed","chain":"input"}
{"ts":"2026-07-31T10:23:45Z","event":"DROP","src":"203.0.113.7","dst":"10.0.0.1","reason":"crowdsec_blacklist","chain":"input"}
{"ts":"2026-07-31T10:23:50Z","event":"DROP","src":"192.0.2.99","reason":"tcp_flags_invalid","flags":"FIN|SYN","chain":"input"}

# Eventos mandatorios para ISO 27001 A.8.21 / NIST SP 800-41:
# - Toda conexión rechazada por firewall
# - Cambios en ruleset nftables
# - Cambios en NetworkPolicy K8s
# - Eventos CrowdSec (nueva IP baneada, desbaneo)
# - fail2ban bans/unbans
# - Port scan detections (psad)
```

### 4.5 API JSON-RPC — `bos.ips.*`

| Método | Quién lo llama | Qué hace |
|--------|---------------|----------|
| `bos.ips.status` | `bosctl ips status` | Estado de CrowdSec, fail2ban, psad |
| `bos.ips.blacklist.list` | `bosctl ips blocked` | IPs bloqueadas actualmente con TTL restante |
| `bos.ips.blacklist.unblock` | HITL operador | Desbloquear una IP específica |
| `bos.ips.alerts` | `bosctl ips alerts` | Últimas alertas IPS con severidad |

### 4.6 CLI — `bosctl ips`

```bash
bosctl ips status                            # Estado del stack IPS
bosctl ips blocked                           # IPs bloqueadas en este momento
bosctl ips blocked --source crowdsec         # Solo bloqueos de CrowdSec
bosctl ips blocked --source fail2ban         # Solo bloqueos de fail2ban
bosctl ips unblock 203.0.113.5               # Desbloquear IP (HITL)
bosctl ips alerts --last 24h                 # Alertas últimas 24h
bosctl ips alerts --severity high            # Solo alertas críticas
```

---

## 5. Flujo integrado: instalar una ficha = seguridad automática

```
bosctl ficha install postgresql

  bos.ficha.install (daemon)
    │
    ├─[1] DEPENDENCY_RESOLVER: verificar dependencias OK
    │
    ├─[2] PORT MANAGER: bos.portman.assign
    │       • Derivar puerto S00 + index 0 + tipo_t 0 = 20000
    │       • Verificar 3 capas → LIBRE
    │       • Registrar T-408: postgresql:K8S_CLUSTER_IP:20000
    │       • Retornar: port=20000, service_name="sbos-postgresql-data"
    │
    ├─[3] CERT MANAGER: bos.certman.issue
    │       • Emitir cert via cert-manager + Vault PKI
    │       • SAN: postgresql.sbos-data.svc.cluster.local
    │       • Guardar en Secret: postgresql-tls-secret
    │       • Registrar T-413: cert válido 90 días, auto-renew ON
    │
    ├─[4] FIREWALL MANAGER: bos.fwman.policy.sync
    │       • Leer Kardex T-408 para ficha postgresql
    │       • Generar NetworkPolicy: deny-all base en sbos-data
    │       • Generar NetworkPolicy: allow ingress port 20000 from sbos-apps
    │       • kubectl apply NetworkPolicies
    │
    ├─[5] K8S CORE: kubectl apply -f
    │       • Service YAML (ClusterIP:20000)
    │       • Deployment YAML
    │       • Secret postgresql-tls-secret
    │
    └─[6] HEALTH CHECK: TCP probe 20000 → OK ✅

RESULTADO: postgresql instalada, puerto asignado, certificado emitido,
           NetworkPolicy activa. El operador no configuró nada.
```

---

## 6. DDL propuesto — Nuevas tablas

```sql
-- T-413: Kardex de Certificados (ver §2.7 para DDL completo)
-- T-414: Log de eventos de seguridad de red
CREATE TABLE IF NOT EXISTS bos.net_security_events (
    event_id     UUID PRIMARY KEY DEFAULT uuidv7(),
    event_time   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    event_type   TEXT NOT NULL CHECK (event_type IN (
                     'port_assigned', 'port_released', 'port_conflict',
                     'cert_issued', 'cert_renewed', 'cert_expiring', 'cert_revoked',
                     'fw_rule_added', 'fw_rule_removed', 'netpol_synced',
                     'ips_block', 'ips_unblock', 'port_scan_detected',
                     'crowdsec_ban', 'fail2ban_ban', 'ddos_detected'
                 )),
    severity     TEXT DEFAULT 'info' CHECK (severity IN ('info', 'warn', 'high', 'critical')),
    source       TEXT,        -- 'portman' | 'certman' | 'fwman' | 'ips' | 'crowdsec'
    ficha_id     TEXT,
    src_ip       TEXT,        -- IP origen (para eventos IPS)
    details      JSONB,       -- detalles del evento
    ctx_id       TEXT NOT NULL DEFAULT 'system'
);

CREATE INDEX idx_net_events_time     ON bos.net_security_events(event_time DESC);
CREATE INDEX idx_net_events_type     ON bos.net_security_events(event_type);
CREATE INDEX idx_net_events_severity ON bos.net_security_events(severity) WHERE severity IN ('high','critical');
CREATE INDEX idx_net_events_src_ip   ON bos.net_security_events(src_ip) WHERE src_ip IS NOT NULL;
```

---

## 7. Validación con normas internacionales

| Norma | Requerimiento | Motor que lo cumple |
|-------|-------------|---------------------|
| **NIST SP 800-207 (ZTA)** | mTLS en toda comunicación, mínimo privilegio, verificación continua | CERTMAN (SPIFFE/SPIRE mTLS) + FWMAN (deny-all + allows mínimos) |
| **NIST SP 800-41** | Documentación de cada regla, stateful inspection, logging de rechazos | FWMAN (nftables stateful) + IPS (logging estructurado) |
| **NIST SP 800-53 CM-8(3)** | Detección de componentes no autorizados | PORTMAN validate (puertos sin Kardex) + FWMAN audit (reglas no canónicas) |
| **ISO 27001:2022 A.8.20** | Inventario actualizado de activos de red | Kardex T-408 (puertos) + T-413 (certs) |
| **ISO 27001:2022 A.8.21** | Seguridad de servicios de red, identificación de mecanismos | FWMAN (NetworkPolicy por ficha) + CERTMAN (TLS por servicio) |
| **ISO 27001:2022 A.8.24** | Criptografía: inventario de claves y certificados | Kardex T-413 (tipo, algoritmo, expiración, responsable) |
| **CIS K8s Benchmark v1.10 §5.3** | NetworkPolicy en todos los namespaces, deny-all base | FWMAN policy.sync genera deny-all automáticamente |
| **RFC 6335 (BCP 165)** | Registro formal de puertos con 8 campos obligatorios | PORTMAN (implementa RFC 6335 para el cluster SBOS) |
| **RFC 8555 (ACME)** | Emisión automática de certificados | CERTMAN (acme.sh + cert-manager integrado) |

---

## 8. Estructura de código — roadmap de implementación

```
BosAgent/src/internal/
├── portman/           ← ✅ IMPLEMENTADO (commit 380cd69)
│   ├── portman.go     ← doc del paquete
│   ├── blacklist.go   ← capas 1 y 2
│   ├── engine.go      ← algoritmos A y B
│   ├── kardex.go      ← CRUD T-408
│   ├── manager.go     ← punto de entrada público
│   └── portman_test.go← 6 tests OK
│
├── certman/           ← 🔴 POR IMPLEMENTAR — Fase 2
│   ├── certman.go     ← doc + Manager
│   ├── vault.go       ← emisión/revocación via Vault PKI
│   ├── certmanager.go ← integración cert-manager K8s CRDs
│   ├── spire.go       ← consulta de SVIDs SPIFFE
│   ├── acme.go        ← certs externos vía ACME
│   ├── kardex.go      ← CRUD T-413
│   ├── watcher.go     ← goroutine que detecta certs próximos a expirar
│   └── certman_test.go
│
├── fwman/             ← 🔴 POR IMPLEMENTAR — Fase 3
│   ├── fwman.go       ← doc + Manager
│   ├── nftables.go    ← gestión de ruleset nftables (via exec nft)
│   ├── netpol.go      ← generador de NetworkPolicy K8s desde Kardex T-408
│   ├── zones.go       ← definición de zonas de seguridad SBOS
│   ├── whitelist.go   ← admin_whitelist dinámica
│   ├── audit.go       ← comparar ruleset actual vs canónico
│   └── fwman_test.go
│
└── ips/               ← 🔴 POR IMPLEMENTAR — Fase 4
    ├── ips.go         ← doc + Manager
    ├── crowdsec.go    ← integración CrowdSec LAPI
    ├── fail2ban.go    ← control de fail2ban via systemd/CLI
    ├── psad.go        ← lectura de alertas psad
    └── ips_test.go
```

**Fases de implementación:**

| Fase | Motor | Prioridad | Esfuerzo |
|------|-------|-----------|---------|
| **Fase 1** | portman | ✅ DONE | — |
| **Fase 2** | certman | Alta — sin certs válidos los servicios fallan | 3-4 días |
| **Fase 3** | fwman (NetworkPolicy) | Alta — microsegmentación es obligatoria | 2-3 días |
| **Fase 3b** | fwman (nftables host) | Media — el host ya tiene nftables del SO | 1-2 días |
| **Fase 4** | ips | Media — CrowdSec/fail2ban se instalan como fichas | 1 día |

---

## 9. Métodos JSON-RPC completos del NetMan

```
bos.portman.assign   bos.portman.lookup   bos.portman.release
bos.portman.check    bos.portman.list     bos.portman.validate  bos.portman.export

bos.certman.issue    bos.certman.revoke   bos.certman.renew
bos.certman.status   bos.certman.list     bos.certman.watch
bos.certman.rotate_ca bos.certman.export

bos.fwman.policy.sync    bos.fwman.policy.status
bos.fwman.host.status    bos.fwman.host.validate   bos.fwman.host.reload
bos.fwman.whitelist.add  bos.fwman.whitelist.remove bos.fwman.audit

bos.ips.status  bos.ips.blacklist.list  bos.ips.blacklist.unblock  bos.ips.alerts
```

---

## 10. Experiencias de industria que validan este diseño

| Organización / Herramienta | Patrón adoptado por SBOS |
|---------------------------|--------------------------|
| **cert-manager** (CNCF Graduated, >85% K8s deployments) | Emisor de certs para fichas K8s con Vault como backend |
| **HashiCorp Vault PKI** (estándar empresarial de PKI en K8s) | CA interna + renovación automática para daemons host |
| **SPIFFE/SPIRE** (CNCF Graduated, Google, Netflix, Uber) | Identidad de workload para mTLS sin configuración por pod |
| **CrowdSec** (IPS comunitario moderno, >10K despliegues 2025) | IPS behavioural + blocklist global + bouncer nftables |
| **Calico nftables dataplane** (GA v3.31, Microsoft AKS, IBM) | CNI + NetworkPolicy + firewall K8s unificados |
| **WireGuard** (Linux kernel 5.6+, estándar VPN 2025) | Acceso administrativo soberano sin VPN propietaria |
| **NetBox** (estándar de inventario de red Fortune 500) | Kardex T-408+T-413 como fuente de verdad de activos de red |
| **Kong Gateway** (implementa K8s Gateway API, sucesor de ingress-nginx deprecado 2026) | Único punto de entrada externo con TLS termination y plugins |

---

*SKULL · SBOS · BosAgent · Julio 2026*
