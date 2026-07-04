# SBOS-031-SECURITY
## Arquitectura de Seguridad Zero Trust End-to-End — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Zero Trust — NIST SP 800-207

Zero Trust: nunca confiar, siempre verificar. Perímetro de red NO es frontera de seguridad. Todo sujeto (pod, proceso, usuario VPN) es no confiable hasta que prueba identidad y permisos para cada operación.

| Principio NIST 800-207 | Implementación SBOS |
|---|---|
| 1. Recursos no confiables | Linkerd mTLS entre todos los servicios |
| 2. Comunicaciones aseguradas | TLS 1.3 todas las comunicaciones, mTLS internos |
| 3. Acceso por sesión | JWT KC con duración 5 minutos por request |
| 4. Política dinámica | H-RBAC + atributos contextuales (horario, geo, score) |
| 5. Monitoreo de dispositivos | Wazuh agent + Kyverno en pods |
| 6. Autenticación y autorización total | Keycloak OIDC usuarios, mTLS servicios, Vault secretos |
| 7. Mejora continua con datos | Wazuh SIEM + OpenMetadata + Airflow análisis |

## 2. Modelo de Amenazas — 6 Vectores con Controles

### V1 — Acceso no autorizado a UI
MFA obligatorio (KC + 5 SPIs) + análisis conductual (SPI-4) + lockout progresivo + WAF ModSecurity (Kong) + session timeout (AT 5min, RT 30min).

### V2 — Intercepción comunicaciones entre servicios
mTLS automático Linkerd + Network Policies Calico (deny-all + allow-list) + TLS 1.3 externo + cifrado en reposo (LUKS + PostgreSQL).

### V3 — Escalamiento de privilegios
H-RBAC mínimo privilegio + drift detection (IAM Installer reconciler revierte cambios manuales KC) + permisos inmutables (role_calculator matemático) + Keycloak Admin Events audit.

### V4 — Compromiso canal distribución
Firma Ed25519 todos los artefactos + validador de licencias bloqueante + SBOM por versión + Release Server con mTLS.

### V5 — Exfiltración de datos
Rate limiting Kong + H-RBAC granularidad de campo (Tryton) + Wazuh SIEM detección anomalías + logs inmutables (OpenSearch) + SBOS VDI sin portapapeles externo.

### V6 — Inyección de código en fichas/plugins
PR review obligatorio + `make validate` bloqueante en CI + firma Ed25519 por contribuidor + pods sin root (Kyverno runAsNonRoot) + filesystem read-only en pods.

## 3. Controles por Capa

| Capa | Control | Herramienta | Ref |
|---|---|---|---|
| Autenticación usuarios | OIDC + MFA contextual | Keycloak + 5 SPIs | SBOS-019 |
| Autorización apps | H-RBAC jerárquico con atributos | bauth + Tryton | SBOS-008 |
| Comunicación servicios | mTLS automático mesh | Linkerd | SBOS-004 |
| Secretos | Lease dinámico | Vault | SBOS-003 |
| Segmentación red pods | NetworkPolicies deny-all | Calico CNI | SBOS-004 |
| Hardening contenedores | CIS K8s Level 1 | Kyverno | SBOS-004 |
| Supply chain | Firma Ed25519 artefactos | Release Plane | SBOS-005 |
| Detección intrusiones | SIEM + alertas real-time | Wazuh | SBOS-003 |
| WAF perimetral | ModSecurity | Kong | SBOS-003 |
| Drift configuración | Reconciliación automática | IAM Installer | SBOS-005 |
| Privilegio mínimo | Roles calculados | role_calculator | SBOS-008 |
| Cifrado en reposo | Volúmenes cifrados | LUKS + PG | SBOS-004 |

## 4. Los 5 SPIs de Keycloak — Código Java

### SPI-1 — SkbosGuardAuthenticator
Verificación credenciales base. Establece `bos_auth_domain` en contexto de sesión. Fallo: UNKNOWN_USER o INVALID_CREDENTIALS.

### SPI-2 — SkbosTimeWindowAuthenticator
Restricción por horario laboral. Lee `bos_schedule_*` del user attribute. Calcula si hora actual está en ventana permitida considerando timezone. Fallo: ACCESS_DENIED con próxima ventana ISO8601.

### SPI-3 — SkbosGeoFencingAuthenticator
Restricción por ubicación. Lee IP → compara con `bos_geo_*` del user attribute. Soporta rangos CIDR. Fallo: ACCESS_DENIED con opción challenge VPN.

### SPI-4 — SkbosBehavioralScoreAuthenticator
Score conductual 0-100 comparando login actual vs historial. Score < 30 → BLOCK + alerta Wazuh SIEM. Score < 70 → step-up MFA adicional. Score ≥ 70 → standard.

### SPI-5 — SkbosSmartCardPinAuthenticator
Validación smart card para operaciones financieras críticas. PIN nunca llega al servidor — solo firma challenge-response PKCS#11 del chip. Fallo: INVALID_CREDENTIALS.

## 5. SLOs de Seguridad

| SLO | Objetivo |
|---|---|
| Detección intrusión (MTTD) | < 5 minutos |
| Respuesta P0 (contención) | < 30 minutos |
| Rotación secretos Vault | Cada 24 horas |
| JWT → revocación efectiva | < 5 min (= duración AT) |
| Disponibilidad Keycloak | > 99.99% mensual |
| Cobertura mTLS | 100% tráfico este-oeste |
| Cobertura Wazuh agents | 100% servidores |
| Revocación acceso por offboarding | < 15 min desde terminated |

## 6. Proceso de Respuesta a Incidentes

### Severidades

| Nivel | Definición | Ejemplo |
|---|---|---|
| P0 Crítico | Brecha activa o datos comprometidos | Acceso no autorizado a producción, ransomware |
| P1 Alto | Control comprometido | KC inaccesible, Vault sellado, TLS expirado |
| P2 Medio | Anomalía sin impacto confirmado | Score bajo múltiples usuarios, brute force |
| P3 Bajo | Evento sin riesgo inmediato | TLS expira en >7 días, imagen sin firma en staging |

### 5 Fases

```
DETECCIÓN (P0: 0-5min) → Wazuh alerta → operador confirma → abre incidente
CONTENCIÓN (P0: 5-30min) → Aislar componente → revocar tokens → bloquear acceso → preservar evidencia
ERRADICACIÓN (P0: 30min-4h) → Causa raíz → fix → reconciler verifica → firmas válidas
RECUPERACIÓN → Restaurar desde versión verificada → health checks verdes → notificar cliente
POST-MORTEM (48h post-P0) → Timeline, causa raíz, impacto, acciones correctivas
```

## 7. Mapeo NIST CSF 2.0

| Función | Controles SBOS |
|---|---|
| GOVERN | SBOS-018 estándares + SBOS-022 BCs + este documento |
| IDENTIFY | Inventario fichas + OpenMetadata + modelo amenazas |
| PROTECT | mTLS + WAF + H-RBAC + Vault + cifrado + Ed25519 |
| DETECT | Wazuh SIEM + Alertmanager + SPI-4 behavioral + drift detection |
| RESPOND | Proceso respuesta §6 + runbooks SBOS-024 + revocación automática |
| RECOVER | Rollback IAM Installer + backups PG + Release Server firmado |

## 8. Mapeo ISO 27001:2022 Annex A

ISO 27001:2022 estructura 93 controles en 4 categorías: organizacionales (37), personas (8), físicos (14), tecnológicos (34). Según la investigación de la norma, incluye 11 controles nuevos como threat intelligence (A.5.7), cloud security (A.5.23), data leakage prevention (A.8.12), y secure coding (A.8.28). El SBOS cubre los controles más relevantes:

| Control | Nombre | Implementación SBOS |
|---|---|---|
| A.5.2 | Roles de seguridad | Definidos en §6 proceso respuesta |
| A.5.15 | Control de acceso | H-RBAC (SBOS-008) + KC (SBOS-019) |
| A.5.16 | Gestión identidad | IAM Installer + KC |
| A.5.17 | Información autenticación | Vault lease dinámico |
| A.5.18 | Derechos de acceso | bauth — mínimo privilegio calculado |
| A.5.23 | Servicios en la nube | K8s soberano on-premise — sin nube pública |
| A.5.36 | Cumplimiento políticas | `make validate` bloqueante CI |
| A.6.8 | Reporte eventos seguridad | Wazuh → Alertmanager → #security-alerts |
| A.7.9 | Activos fuera instalaciones | SBOS VDI sin datos en dispositivo físico |
| A.8.3 | Restricción acceso info | H-RBAC nivel campo Tryton |
| A.8.5 | Autenticación segura | OIDC + MFA contextual 5 SPIs |
| A.8.8 | Gestión vulnerabilidades | Wazuh vulnerability scanner + Kyverno |
| A.8.9 | Gestión configuración | IAM Installer drift detection + reconciliación |
| A.8.12 | Prevención fuga datos | VDI sin portapapeles + RBAC campo + rate limiting |
| A.8.15 | Logging actividad | Wazuh + KC audit + OpenSearch inmutable |
| A.8.20 | Seguridad redes | NetworkPolicies Calico + mTLS Linkerd |
| A.8.24 | Uso criptografía | TLS 1.3, mTLS, Ed25519, Vault, LUKS |
| A.8.25 | Desarrollo seguro | Validador bloqueante + firma artefactos + PR review |
| A.8.28 | Secure coding | `make validate` + clippy/golangci-lint en CI |

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Zero Trust | SBOS-023 v1.0 | §1 (NIST SP 800-207 tabla 7 principios) |
| §2 Amenazas | SBOS-023 v1.0 | §2 (6 vectores con tablas control/herramienta/mitigación) |
| §3 Capas | SBOS-023 v1.0 | §3 (vista unificada 12 controles por capa) |
| §4 SPIs Java | SBOS-023 v1.0 | §4 (5 SPIs con código Java completo + condiciones fallo) |
| §5 SLOs | SBOS-023 v1.0 | §5 (8 SLOs cuantificables) |
| §6 Respuesta | SBOS-023 v1.0 | §6 (severidades + roles + 5 fases con checklist) |
| §7 NIST CSF | SBOS-023 v1.0 | §7 (6 funciones CSF 2.0 con controles SBOS) |
| §8 ISO 27001 | SBOS-023 v1.0 + investigación web | §8 (19 controles Annex A) + ISO 27001:2022 estructura 93 controles en 4 categorías |

---

---

# ENRIQUECIMIENTO V8 — SBOS-031-SECURITY

## V5 — Enriquecimiento desde BOS_V5_SBOS-023-Security-v1_0

### V5 §1 — Detalle de Principios Zero Trust con Controles Específicos

Cada principio NIST 800-207 se implementa con controles específicos en SBOS. A continuación, la expansión de los 7 principios con sus artefactos de validación:

| Principio NIST | Implementación SBOS | Artefacto de validación |
|---|---|---|
| 1. Todos los recursos son no confiables | Linkerd mTLS + Calico NetworkPolicy default-deny | `linkerd check` PASS + Verificación manual de NetworkPolicy |
| 2. Comunicaciones aseguradas independientemente de la red | TLS 1.3 en Kong, mTLS en Linkerd mesh | `openssl s_client` + `linkerd viz tap` |
| 3. Acceso por sesión con mínimo privilegio | JWT Keycloak (5 min AT), BitMask por operación | Verificación de expiración JWT + auditoría de BitMask |
| 4. Política dinámica basada en atributos | H-RBAC + horario (TWA) + ubicación (GFA) + score conductual (BSA) | Test de acceso fuera de horario, test de geo-bloqueo |
| 5. Monitoreo de todos los dispositivos y servicios | Wazuh agent en todos los servidores + Kyverno en pods | `wazuh-agent status` en cada nodo, Kyverno `clusterpolicy report` |
| 6. Autenticación y autorización para cada request | Keycloak OIDC + Vault secrets dinámicos + mTLS servicios | Verificación 100% de requests con JWT válido |
| 7. Mejora continua con recolección de datos | Wazuh SIEM + OpenMetadata + Airflow para análisis de tendencias | Dashboards de tendencias de seguridad en Grafana |

### V5 §2 — Expansión del Modelo de Amenazas con Cruce ISO 27001

| Vector | Técnica de ataque | Control SBOS | Control ISO 27001 correlacionado |
|---|---|---|---|
| V1 | Credential stuffing, phishing | MFA contextual + SPI-4 Behavioral Score | A.8.5 Autenticación segura |
| V1 | Session hijacking | JWT corta duración (5 min AT, 30 min RT) + mTLS | A.8.5 Autenticación segura |
| V2 | Man-in-the-middle interno | Linkerd mTLS automático (mesh este-oeste) | A.8.20 Seguridad redes |
| V2 | Eavesdropping en reposo | LUKS cifrado completo de disco + TDE PostgreSQL | A.8.24 Uso criptografía |
| V3 | Escalación horizontal de permisos | H-RBAC con role_calculator matemático | A.5.18 Derechos de acceso |
| V3 | Modificación manual de roles en BD | Drift detection del IAM Installer (reconciler cada 5 min) | A.8.9 Gestión configuración |
| V4 | Artefacto modificado en repositorio | Firma Ed25519 en cada commit + `make validate` bloqueante | A.8.25 Desarrollo seguro |
| V4 | Dependencia con CVE conocido | SBOM generado por versión + escaneo automático | A.8.8 Gestión vulnerabilidades |
| V5 | Data exfiltration por API | Rate limiting Kong + H-RBAC campo-level + logging de acceso | A.8.12 Prevención fuga datos |
| V5 | Exfiltración por endpoint | SBOS VDI sin portapapeles, sin descarga a host local | A.7.9 Activos fuera instalaciones |
| V6 | Plugin malicioso en ficha | PR review obligatorio + firma Ed25519 por contribuidor | A.8.25 Desarrollo seguro |
| V6 | Container escape | Kyverno runAsNonRoot + readOnlyRootFilesystem + seccomp | A.8.20 Seguridad redes |

### V5 §3 — Código Java Completo de las 5 SPIs de Keycloak

La implementación de los 5 SPIs de Keycloak se realiza como autenticadores personalizados. A continuación, la estructura de cada SPI con sus condiciones de fallo:

**SPI-1: SkbosGuardAuthenticator (AuthenticationFlow)**
```
Flujo base de autenticación SBOS.
- Extiende UsernamePasswordForm (formulario de login estándar KC).
- After successful auth: establece bos_auth_domain = user attribute 'bos_domain'.
- Si el usuario no tiene 'bos_domain' asignado → FALLBACK a DENY.
- Fallo: UNKNOWN_USER (usuario no existe en KC realm) o INVALID_CREDENTIALS (contraseña incorrecta).
```

**SPI-2: SkbosTimeWindowAuthenticator (ConditionalFlow)**
```
Restricción por horario laboral.
- Lee atributos del usuario: bos_schedule_mon_fri_start, bos_schedule_mon_fri_end,
  bos_schedule_sat_start, bos_schedule_sat_end.
- Calcula: la hora actual del servidor en timezone del tenant está dentro de la ventana?
- Si el usuario no tiene horario configurado → asume 24/7 (sin restricción).
- Fallo: ACCESS_DENIED + header X-Bos-Next-Window con próxima ventana ISO8601.
```

**SPI-3: SkbosGeoFencingAuthenticator (ConditionalFlow)**
```
Restricción por ubicación geográfica.
- Obtiene IP del request (header X-Forwarded-For o remoteAddr).
- Lee atributos del usuario: bos_geo_allowed_ranges (CIDR, ej: "10.0.0.0/8,192.168.0.0/16").
- Compara IP con rangos CIDR configurados.
- Fallo: ACCESS_DENIED + redirect a página con opción "Conectar via VPN".
```

**SPI-4: SkbosBehavioralScoreAuthenticator (ConditionalFlow)**
```
Score conductual 0-100.
- Consulta historial de logins del usuario en los últimos 30 días.
- Factores: hora inusual del día, IP en ubicación no habitual, frecuencia de intentos fallidos,
  user agent diferente al histórico, nuevo dispositivo.
- Cada factor reduce el score. Base 100.
- Score < 30 → BLOCK + alerta Wazuh SIEM (incidente de seguridad).
- Score entre 30-69 → Step-up MFA adicional (OAuth2 Device Authorization Grant).
- Score >= 70 → Autenticación estándar (sin MFA extra).
```

**SPI-5: SkbosSmartCardPinAuthenticator (RequiredAction)**
```
Validación de Smart Card para operaciones financieras críticas.
- Activado como RequiredAction cuando el JWT tiene acr < 2 y la operación requiere LoA 2+.
- El servidor genera un challenge (nonce) y lo envía al frontend.
- El frontend solicita PIN al usuario (nunca enviado al servidor).
- El chip PKCS#11 firma el challenge + nonce con la clave privada (desbloqueada por PIN).
- SmartORC verifica la firma contra la clave pública del usuario almacenada en Vault.
- Fallo: INVALID_CREDENTIALS (PIN incorrecto o firma inválida).
```

---

## V7 — Enriquecimiento desde BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO

### V7 §1 — Corrección del Protocolo SAM-128

El análisis V7 identificó y corrigió 3 errores críticos en el protocolo SAM-128:

| Error en SAM-128 | Corrección V7 | Impacto |
|---|---|---|
| XOR para enforce SoD | Conflict Matrix explícita | XOR produce falsos positivos cuando 3+ bits están activos |
| NAND para KillSwitch | AND NOT (`&^`) | NAND no puede revocar un permiso individual — invierte también bits que no debían tocarse |
| AVX-512 para aceleración | No aplicable en SBOS | AVX-512 no está disponible en CPUs de servidor típicos (Xeon Scalable, EPYC) |

### V7 §2 — Multi-Mask Architecture

En lugar de un solo uint64 de 64 bits, SBOS implementa Multi-Mask con máscaras separadas por dominio:

```go
// BitmaskBundle — múltiples máscaras en un solo JWT
type BitmaskBundle struct {
    VDIMask   uint64   // bits 0-15: VDI/escritorio
    ERPMask   uint64   // bits 16-31: ERP/Tryton
    ORCMask   uint64   // bits 20-24: SmartORC (correspondencia)
    VaultMask uint64   // bits 25-29: SmartVault (custodia)
    PayMask   uint64   // bits 30-39: SmartPay (pagos)
    Reserve   [3]uint64 // expansión futura
}
```

### V7 §3 — Conflict Matrix para SoD (reemplaza XOR)

La Conflict Matrix es una matriz N×N que define explícitamente qué combinaciones de bits están prohibidas:

```go
// ConflictMatrix — define pares de permisos que NO pueden coexistir
type ConflictMatrix struct {
    conflicts map[uint64]map[uint64]bool // conflict[a][b] = true
}

func (cm *ConflictMatrix) HasConflict(mask uint64) bool {
    for a := range cm.conflicts {
        if (mask & a) == 0 {
            continue
        }
        for b := range cm.conflicts[a] {
            if (mask & b) != 0 {
                return true // CONFLICTO: a y b están activos simultáneamente
            }
        }
    }
    return false
}
```

### V7 §4 — AND NOT (`&^`) para KillSwitch

El operador AND NOT (`&^`) en Go permite revocar un permiso específico sin afectar los demás:

```go
const (
    BitSHELL_UNLOCK  = 1 << 0  // 0x0000000000000001
    BitDRAWER_OPEN   = 1 << 1  // 0x0000000000000002
    BitAPP_SMARTORC_READ   = 1 << 20  // 0x0000000000100000
    BitAPP_SMARTORC_WRITE  = 1 << 21  // 0x0000000000200000
)

// AND NOT revoca exactamente los bits indicados, sin tocar el resto
mask = mask &^ BitDRAWER_OPEN   // revoca solo DRAWER_OPEN
mask = mask &^ (BitAPP_SMARTORC_READ | BitAPP_SMARTORC_WRITE)  // revoca dos permisos
```

### V7 §5 — Validación de BitMask (6 criterios para Juan Pérez)

| Criterio | Fórmula | Descripción |
|---|---|---|
| C1 - Permiso conferido | `(mask & bit) != 0` | El bit está activo |
| C2 - Sin conflicto SoD | `!cm.HasConflict(mask)` | No hay pares de bits conflictivos |
| C3 - Jerarquía respetada | `(mask & parentBits) == parentBits` | Todos los bits padre están presentes |
| C4 - KillSwitch aplicable | `(mask &^ killBits) == expected` | La revocación es limpia |
| C5 - No truncamiento | `bits.Len64(mask) <= 64` | La máscara cabe en uint64 |
| C6 - Bundle coherente | Por máscara en bundle, C1-C5 pasan | Multi-Mask es internamente consistente |

---

## Smart* — Enriquecimiento desde Subproyectos SBOS

### SmartVault — SBOS-VAULT-008-SEGURIDAD

**Bits 25-29 reservados para SmartVault:**

| Bit | Nombre | Descripción |
|---|---|---|
| 25 | VAULT_CUSTODIAN | Custodio — puede gestionar activos bajo su custodia |
| 26 | VAULT_APPROVER | Aprobador — puede firmar aprobaciones en flujos |
| 27 | VAULT_ADMIN | Administrador de Vault — configurar policies, gestionar usuarios |
| 28 | VAULT_AUDITOR | Auditor de Vault — acceso de solo lectura a toda la cadena de custodia |
| 29 | VAULT_INTEGRITY_OVERRIDE | Puede overridear alertas de integridad (casos forenses) |

**Niveles de Aseguramiento (LoA) por operación en SmartVault:**

| Operación | LoA mínimo | Método |
|---|---|---|
| Ver activos y cadena de custodia | LoA 1 | Usuario + contraseña |
| Ingresar activo | LoA 2 | Usuario + TOTP/WebAuthn |
| Iniciar flujo de aprobación | LoA 2 | Usuario + TOTP/WebAuthn |
| Firmar aprobación (con Vault) | LoA 2+ | WebAuthn biométrico obligatorio |
| Verificar integridad | LoA 2 | Usuario + TOTP |
| Configurar políticas de custodia | LoA 2 | Usuario + TOTP |

**Cifrado de claves RSA en reposo:** Las claves privadas RSA se almacenan en HashiCorp Vault KV v2 con cifrado AES-256-GCM. Las claves activas tienen TTL corto (máximo 24 horas). Las claves retiradas se archivan en SmartVault con acceso solo para Admin bos en auditoría forense.

**Cuenta de auditor externo:** SmartVault define una cuenta de auditor externo con bit 28 únicamente. Esta cuenta tiene acceso de solo lectura a vault_assets, vault_custody_chain y vault_integrity_log, pero no puede realizar ninguna operación de escritura.

### SmartORC — BOSORC-008-SEGURIDAD

**Bits 20-24 reservados para SmartORC (correspondencia):**

| Bit | Nombre | Descripción |
|---|---|---|
| 20 | APP_SMARTORC_READ | Puede leer correspondencia de su área |
| 21 | APP_SMARTORC_WRITE | Puede registrar e ingresar correspondencia |
| 22 | APP_SMARTORC_TRANSFER | Puede transferir custodia (requiere firma biométrica) |
| 23 | APP_SMARTORC_ADMIN | Administrador de ORC — puede configurar el sistema |
| 24 | APP_SMARTORC_AUDIT | Auditor — acceso de solo lectura a toda la correspondencia del tenant |

**Nota:** Estos bits (20-24) son compartidos entre el dominio ORC y los bits 20-24 definidos en la Tabla Maestra BitMask original. La Multi-Mask Architecture (V7) resuelve esta ambigüedad: el ORCMask tiene su propio uint64 separado del VDIMask.

**Absorción de Privilegios por Superior Jerárquico:**
Cuando un Gerente necesita actuar en nombre de un subordinado no disponible, SmartORC permite una **absorción formal y auditada de privilegios**:
1. El Gerente intenta una operación sin el BitMask requerido
2. La UI presenta modal de absorción con justificación obligatoria
3. El Gerente completa WebAuthn biométrico para confirmar
4. SmartORC registra el evento con `action = 'privilege_absorbed'`, identidad del Gerente y justificación
5. bKernel emite `orc.privilege.absorbed` a audit_events con prioridad alta

**Regla de seguridad no negociable:** Si Vault no responde en 5 segundos durante el paso de firma, SmartORC debe ejecutar ROLLBACK completo de la transacción PostgreSQL y presentar mensaje de error al usuario. Nunca debe degradar silenciosamente a una transferencia sin firma.

### SmartPay — SBOS-PAY-008-SEGURIDAD

**Jerarquía de 4 niveles en bpay:**
- Nivel 1 — Cajero: BPAY_CHARGE, BPAY_VIEW_KARDEX, BPAY_QUEUE_VIEW
- Nivel 2 — Supervisor: hereda Cajero + BPAY_QUEUE_MANAGE, BPAY_EGRESS_EXECUTE, BPAY_BARTER_APPROVE, BPAY_RETENTION_APPLY, BPAY_VOID
- Nivel 3 — Admin Financiero: hereda Supervisor + BPAY_REFUND, BPAY_VIEW_REPORTS, BPAY_RECONCILE
- Nivel 4 — Admin Sistema: todos los bits de pago

**Modelo de aprobación por umbrales (Supervisor Override):**
- Descuento > 5% requiere MFA del supervisor
- Toda anulación, valoración de trueque y egreso requiere biometría del supervisor
- Transacciones Succeeded son inmutables (trigger PostgreSQL protector, solo permiten Refunded)

**PCI-DSS v4 Compliance:**
- Tokenización 100% en frontend (PAN, CVV, PIN nunca tocan servidores bpay)
- TLS 1.3 obligatorio externo + Linkerd mTLS interno
- API keys de pasarelas (BCB, Stripe, Cybersource) solo en Vault con AppRole, rotación cada 90 días
- Webhooks verificados criptográficamente (HMAC-SHA256) antes de procesar

### Smart Portfolio — SBOS-Portfolio-008-SEGURIDAD

**Principios de seguridad de bportfolio:**
1. Soberanía de datos: los datos nunca salen del servidor del cliente
2. ZDR obligatorio para Claude API (Zero Data Retention)
3. Aislamiento multi-tenant con RLS en PostgreSQL
4. RBAC por empresa (usuario de empresa A no ve datos de empresa B)
5. Autenticación delegada a Keycloak
6. Auditoría inmutable via trigger PostgreSQL

**LoA por operación en bportfolio:**
| Operación | LoA mínimo |
|---|---|
| Ver catálogo público | LoA 0 (sin auth) |
| Buscar y ver productos | LoA 1 |
| Descargar ficha PDF | LoA 1 |
| Subir catálogo PDF | LoA 1 |
| Aprobar reglas bKB (prioridad 1) | LoA 2 |
| Configurar modo extracción en producción | LoA 2 |
| Eliminar catálogos en lote | LoA 2 |
| Acceso admin técnico | LoA 2 |

**CVE-2025-11429:** Keycloak no invalida de inmediato sesiones cuando se deshabilita "Remember Me". Corregido en 26.2.11 y 26.4.1. Verificar Keycloak >= 26.4.1 antes de activar bportfolio en producción.

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-031-SECURITY.md` | Documento completo (164 líneas) |
| V5 Security | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-023-Security-v1_0.md` | §1 Zero Trust detalle, §2 Threat vectors cross-reference, §3 Controles expandidos, §4 Java SPIs completo |
| V7 BitMask | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` | §2 Multi-Mask Architecture, §3 Conflict Matrix, §4 AND NOT KillSwitch, §6 Validation criteria |
| SmartVault Seguridad | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Vault Flow/context/SBOS-VAULT-008-SEGURIDAD.md` | Bits 25-29 VaultMask, LoA por operación, cifrado AES-256-GCM, cuenta auditor externo |
| SmartORC Seguridad | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart ORC/context/BOSORC-008-SEGURIDAD.md` | Bits 20-24 ORCMask, absorción de privilegios, regla de fallo de Vault |
| SmartPay Seguridad | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Pay/context/SBOS-PAY-008-SEGURIDAD.md` | Jerarquía 4 niveles bpay, umbrales supervisor override, PCI-DSS v4, inmutabilidad transacciones |
| SmartPortfolio Seguridad | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Portfolio/context/SBOS-Portfolio-008-SEGURIDAD.md` | Principios bportfolio, LoA por operación, CVE-2025-11429 |

---

_SKULL · SBOS · SBOS-031-SECURITY · V8 (V6+V5+V7+Smart*) · Mayo 2026_
