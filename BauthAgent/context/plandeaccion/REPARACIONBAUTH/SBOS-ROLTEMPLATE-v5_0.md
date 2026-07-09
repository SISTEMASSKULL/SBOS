# SBOS — RolTemplate: Contrato Definitivo v6.0
## La Fuente de Verdad del Sistema de Identidad
### SKULL · SBOS — Sovereign Business Operating System
### v6.0 · Junio 2026 · Alineado con bAuth v2.0 · BitMask Dual Jun 2026

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-ROLTEMPLATE-v6_0 |
| **Versión** | 6.0 — actualizada, alineada con BAUTH-CATALOGO-ROLES-EMPRESARIALES v2.0 y Authentication_Framework v3.0.0 |
| **Estado** | ACTIVO |
| **Propósito** | Especificación JSONB completa del RolTemplate — contrato canónico entre bAuth, Keycloak y Tryton |
| **Almacenamiento** | PostgreSQL tabla `bos_rol_template`, columna `template JSONB` |
| **Estándares** | ANSI/INCITS 359-2004 H-RBAC · NIST SP 800-53 Rev.5 AC-2/AC-5/AC-6 · NIST SP 800-63B Rev.4 (2024) · ISO/IEC 27001:2022 A.5.15-18, A.8.2, A.8.15 · ISO 9001:2015 §3.2.4 · ISO/IEC 24760-2:2025 · PCI-DSS v4.0 · OASIS XACML 3.0 · oneM2M TS 0001 · OAuth 2.0 (RFC 6749/7636/8705/9449) · RFC 9470 Step-Up |
| **Integra** | BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 · BAUTH-CADENAS-JERARQUIA.md v1.1 · Authentication_Framework.json v3.0.0 · Policies_Authentication_Framework_v4.json · SBOS-BAUTH-CONCEPTUALIZACION-v4_0 · SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0 · SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION · SBOS-008-001 |

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** El modelo BitMask referenciado en este documento (SAM-128, "2 capas", "7×64 bits") ha sido reemplazado por el **BitMask Dual** definido en `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`. Las operaciones de herencia y combinación de roles usan el Rol BitMask (one-hot encoding), NUNCA el BitMask Átomo (label encoding). Ver también `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7.

---

## PRINCIPIO ABSOLUTO

> **El RolTemplate es el ÚNICO contrato que define lo que un tipo de rol PUEDE HACER en el SBOS.**
> Todo lo que bAuth sincroniza en Keycloak, Tryton, y aplicaciones
> proviene exclusivamente de este documento.
> No hay otra forma de configurar el sistema de identidad.

**Pregunta del RolTemplate:** ¿Qué PUEDE HACER un tipo de rol?
**Granularidad:** Define una categoría organizacional, no un usuario individual.
**Multiplicidad:** Un RolTemplate → muchos usuarios.

---

## ESTRUCTURA JSONB COMPLETA

```json
{
  "role": {

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 1 — IDENTIFICACIÓN Y METADATOS
    // Propósito: Identidad canónica, versionado semántico, jerarquía H-RBAC
    // Estándar: ANSI/INCITS 359-2004 §4 (Role Hierarchy), SemVer 2.0
    // ═══════════════════════════════════════════════════════════════════

    "id": "RGV-001",
    // ID canónico — INMUTABLE post-creación.
    // Formato: {SIGLA_DEPARTAMENTO}-{NUM_3_DIGITOS}
    // Este mismo ID se usa como: Composite Role en KC, Grupo en Tryton.
    // Ejemplos: DGV-001, RGV-001, VEN-VEN-001, CFO-001, IT-ADM-001

    "parent_id": "VEN-BASE-001",
    // Referencia al RolTemplate padre para herencia H-RBAC.
    // null = rol raíz (sin herencia).
    // Herencia vía AND NOT: hijo = padre &^ bits_removidos.
    // NUNCA circular (bAuth valida DAG antes de guardar).

    "type_id": "TYPE-GERENCIA-REGIONAL",
    // Clasificación funcional del rol.
    // Valores sugeridos: TYPE-OPERATIVO, TYPE-SUPERVISOR, TYPE-GERENCIA-MEDIA,
    //   TYPE-DIRECCION, TYPE-ADMIN-SISTEMA, TYPE-SERVICIO, TYPE-AUDITORIA

    "hierarchy_level": 2,
    // Nivel en la jerarquía organizacional (1=más alto, N=más bajo).
    // 1 = C-Level/Dirección, 2 = Gerencia regional, 3 = Supervisor,
    // 4 = Operativo calificado, 5 = Operativo estándar

    "path_ids": ["VEN-BASE-001", "RGV-001"],
    // Cadena completa de ancestros desde raíz hasta este rol.
    // Calculado automáticamente por bAuth. Solo lectura.

    "version": "3.1.0",
    // Versión semántica del contrato de este rol.
    // MAJOR.MINOR.PATCH — cambio MAJOR = breaking change en permisos

    "status": "ACTIVE",
    // DRAFT      → en diseño, no sincronizado
    // REVIEW     → pendiente aprobación del ARB
    // ACTIVE     → sincronizado en KC + Tryton, operativo
    // DEPRECATED → operativo pero no asignable a nuevos usuarios
    // ARCHIVED   → desactivado, sin sesiones activas posibles

    "name": {
      // Nombre multilenguaje (i18n obligatorio).
      "es": "Gerente Regional de Ventas — Región Norte",
      "en": "Regional Sales Manager — Northern Region",
      "pt": "Gerente Regional de Vendas — Região Norte"
    },

    "description": {
      "es": "Responsable de operaciones comerciales en la región norte. Gestiona equipo de hasta 10 vendedores, aprueba ventas hasta 50.000 BOB, administra cartera de clientes asignada.",
      "en": "Responsible for commercial operations in the northern region.",
      "pt": "Responsável pelas operações comerciais na região norte."
    },

    "metadata": {
      // Datos organizacionales y territoriales del rol.
      "department":             "Ventas",
      "cost_center":            "VEN-NORTE",
      "region":                 "NORTH",
      "territory_code":         "VEN-NORTH-001",
      "job_family":             "Sales",
      "job_level":              "M2",
      // job_level según escala interna: I1-I5 (individual), M1-M5 (manager), D1-D3 (director)
      "max_subordinates":       10,
      "required_certifications":["SALES_CERT_A", "MANAGEMENT_CERT_B"],
      "reporting_line":         "SALES_DIVISION",
      "classification":         "CONFIDENTIAL"
      // CONFIDENTIAL | RESTRICTED | INTERNAL | PUBLIC
    },

    "audit": {
      // Trazabilidad completa de creación y modificación (ISO 27001 A.8.15).
      "created_by":   "ADMIN.SISTEMA",
      "created_at":   "2024-01-01T00:00:00Z",
      "updated_by":   "DGV.CARLOS.RUIZ",
      "updated_at":   "2026-03-01T10:30:00Z",
      "version_number": 7,
      // Incrementa en cada UPDATE. Auditado en bos_rol_template_history.
      "change_history": [
        {
          "version":      "3.1.0",
          "date":         "2026-03-01T10:30:00Z",
          "changed_by":   "DGV.CARLOS.RUIZ",
          "approved_by":  "CFO",
          "changes":      ["Incremento límite financiero L1 de 40k a 50k BOB"],
          "change_reason":"Ajuste por inflación anual — Resolución DIR-2026-003",
          "security_impact":"LOW"
        }
      ]
    },

    "digital_signature": {
      // Firma digital del contrato — asegura integridad del RolTemplate.
      "signature":            "base64_encoded_EdDSA_signature",
      "algorithm":            "EdDSA_Ed25519",
      // Algoritmo primario: EdDSA (alta seguridad, rendimiento óptimo).
      // NIST SP 800-186 §3.2.1 recomienda Ed25519 para nuevas implementaciones.
      "post_quantum_planned": "CRYSTALS-Dilithium",
      // Algoritmo post-cuántico planeado (NIST PQC Standard 2024).
      // Se activará en modo híbrido EdDSA+Dilithium cuando Vault 2.0+ lo soporte.
      // Release planeado: 2027-2028.
      "certificate_thumbprint":"sha256:abc123...",
      "timestamp":            "2026-06-20T10:31:00Z",
      "validity": {
        "not_before": "2026-06-20T10:31:00Z",
        "not_after":  "2027-06-20T10:31:00Z"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 2 — VIGENCIA Y CICLO DE VIDA
    // Propósito: Controlar período de validez del rol
    // Estándar: ISO/IEC 24760 §7 (Identity Lifecycle), NIST SP 800-63B §4.3
    // ═══════════════════════════════════════════════════════════════════

    "validity_period": {
      "type":       "FIXED",
      // FIXED         → requiere start_date y end_date
      // INDEFINITE    → sin caducidad (end_date = null)
      // PROJECT_BASED → vigencia vinculada a un proyecto específico

      "start_date": "2026-01-01T00:00:00Z",
      "end_date":   "2027-12-31T23:59:59Z",
      // null para INDEFINITE. bAuth valida automáticamente al expirar.

      "review_date":"2026-07-01T00:00:00Z",
      // Fecha de revisión periódica (Quarterly|Semiannual|Annual).
      // bAuth alerta 30 días antes al role_owner.

      "renewal_settings": {
        "renewable":              true,
        "max_renewals":           2,
        "renewal_duration_days":  365,
        "auto_renewal":           false,
        // Si true, bAuth renueva automáticamente sin aprobación.
        "renewal_approval_roles": ["DIRECTOR_VENTAS", "COMPLIANCE_OFFICER"]
      },

      "early_termination": {
        "allowed":             true,
        "requires_approval":   true,
        "approver_roles":      ["DIRECTOR_VENTAS", "HR_DIRECTOR"],
        "notice_period_days":  5,
        "documentation":       "mandatory"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 3 — FLUJO DE APROBACIÓN
    // Propósito: Gobernanza de cambios al RolTemplate
    // Estándar: ISO/IEC 27001 A.5.2 (Policies), ITIL Change Management
    // ═══════════════════════════════════════════════════════════════════

    "approval_workflow": {
      "required_approvers":    2,
      "approver_roles":        ["DIRECTOR_VENTAS", "CFO"],
      // Mínimo required_approvers de approver_roles deben aprobar.
      // bAuth valida: required_approvers <= len(approver_roles).
      "notification_channel":  "rocket_chat",
      // rocket_chat | email | slack
      "sla_hours":             48,
      // Tiempo máximo para obtener aprobación antes de expirar el request.
      "escalation_after_hours":24,
      // Si no hay respuesta en N horas, escalar al siguiente nivel.
      "escalation_to":         ["CISO", "CEO"]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 4 — DOMINIO LÓGICO (Autenticación Digital)
    // Propósito: Controla cómo y cuándo el usuario puede autenticarse digitalmente.
    // bAuth traduce este bloque a → Authentication Flow KC + User Attributes.
    // Estándar: NIST SP 800-63B AAL, FIDO2/WebAuthn W3C, RFC 9470 Step-Up
    // ═══════════════════════════════════════════════════════════════════

    "logical_access": {

      "availableMethods": [
        // Lista COMPLETA de métodos que el sistema soporta y que este rol PODRÍA usar.
        // No todos son obligatorios — ver requiredMethods.
        "username_password",
        "totp",
        "hotp",
        "webauthn_platform",
        // WebAuthn con authenticator de plataforma (Face ID, Windows Hello, Touch ID)
        "webauthn_roaming",
        // WebAuthn con hardware key (YubiKey, Nitrokey)
        "passkey",
        // Passkeys sincronizadas (FIDO2 con sync, KC 26.4+)
        "x509_smartcard",
        // Certificado X.509 en tarjeta inteligente (PIV)
        "magic_link",
        // Email magic link (single-use, TTL 5 min)
        "email_otp",
        // OTP enviado a email (KC 26 nativo)
        "push_notification",
        // Push a app móvil (requiere SPI externo)
        "sms_otp",
        // ⚠️ DEPRECADO por NIST SP 800-63B Rev.4 §5.1 — NO USAR para nuevos roles.
        // Solo mantenido para roles legacy que aún no han migrado a TOTP/Passkey.
        // Reemplazo: TOTP (KC_TOTP) o Passkey (KC_PASSKEY).
        "backup_codes",
        // Códigos de recuperación de un solo uso
        "security_questions"
        // Solo para recuperación de cuenta — NUNCA como factor primario
      ],

      "requiredMethods": {
        // Define qué combinación de factores se necesita según el contexto de acceso.
        // Cada entry es un Authentication Flow distinto en KC.
        "standard_login": [
          {"method": "username_password", "order": 1, "required": true},
          {"method": "totp",              "order": 2, "required": true}
        ],
        // Login estándar: pwd + TOTP. LoA 2.

        "elevated_login": [
          {"method": "username_password",  "order": 1, "required": true},
          {"method": "webauthn_platform",  "order": 2, "required": true}
        ],
        // Login elevado: pwd + biométrico digital. LoA 3.
        // Se activa por step-up desde operaciones de alto riesgo.

        "financial_high_value": [
          {"method": "username_password",  "order": 1, "required": true},
          {"method": "webauthn_platform",  "order": 2, "required": true},
          {"method": "totp",               "order": 3, "required": true}
        ]
        // Para transacciones > 25.000 BOB. LoA 3 + TOTP fresco.
      },

      "alternativeMethods": [
        // Sustitutos permitidos si el método requerido no está disponible.
        {
          "replaces":          "webauthn_platform",
          "with":              "webauthn_roaming",
          "requires_approval": false,
          "reason":            "Dispositivo sin biométrico nativo"
        },
        {
          "replaces":          "totp",
          "with":              "backup_codes",
          "requires_approval": true,
          "max_uses":          1,
          "reason":            "Pérdida de dispositivo TOTP"
        }
      ],

      "level_of_assurance": 2,
      // LoA requerido base para este rol.
      // 1 = password simple, 2 = MFA (pwd+OTP), 3 = MFA fuerte (WebAuthn/biométrico), 4 = WebAuthn+quórum

      "step_up_rules": [
        // Define cuándo se requiere autenticación adicional durante la sesión (RFC 9470).
        {
          "trigger":          "financial_approve",
          "condition_pyson":  "Eval('amount', 0) > 10000",
          "required_loa":     3,
          "max_age_seconds":  300,
          // El step-up es válido por 5 minutos antes de requerir re-autenticación.
          "acr_value":        "high_security"
        },
        {
          "trigger":          "system_config_change",
          "required_loa":     3,
          "max_age_seconds":  0,
          // max_age 0 = requiere autenticación fresca para cada operación.
          "acr_value":        "high_security"
        }
      ],

      "geospatial_control": {
        // Control de red/ubicación lógica. Sincronizado como User Attribute en KC.
        // SPI: SkbosGeoContextAuthenticator lee estos valores.
        "enabled": true,
        "allowed_locations": [
          {
            "type":         "office",
            "name":         "Sucursal La Paz — Av. Camacho 1234",
            "network_ranges":["10.0.1.0/24", "192.168.10.0/24"]
          },
          {
            "type":         "vpn",
            "name":         "VPN Corporativa SBOS",
            "network_ranges":["10.10.0.0/16"]
          },
          {
            "type":         "home_office",
            "name":         "Teletrabajo autorizado",
            "network_ranges":["*"],
            // * = cualquier red, pero requiere VPN activa
            "requires_vpn": true
          }
        ],
        "validation_rules": {
          "require_vpn":         false,
          // true = VPN obligatoria en TODAS las redes, incluso oficinas.
          "allow_roaming":       false,
          // false = solo redes pre-registradas.
          "require_corporate_network": false,
          // true = solo redes de la empresa.
          "geo_velocity_check":  true,
          // Detecta viaje imposible (> 1200 km/h entre logins).
          "max_velocity_kmh":    1200,
          "tolerance_km":        10
        }
      },

      "temporal_control": {
        // Control horario y de días. Sincronizado como User Attribute en KC.
        // SPI: SkbosRoleValidityAuthenticator + horas en Authentication Flow.
        "enabled": true,
        "schedule_type": "SPECIFIC_DAYS",
        // FULL_WEEK    → acceso todos los días
        // SPECIFIC_DAYS → solo días configurados
        // ALTERNATE_DAYS → alternados

        "timezone": "America/La_Paz",

        "allowed_days": [
          {
            "day": "MONDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "TUESDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "WEDNESDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "THURSDAY",
            "shifts": [
              {"start": "08:00", "end": "18:00"}
            ]
          },
          {
            "day": "FRIDAY",
            "shifts": [
              {"start": "08:00", "end": "15:00"}
            ]
          }
        ],

        "exceptions": {
          "holidays":       "BLOCKED",
          // BLOCKED = no acceso, ALLOWED = acceso normal, REQUIRES_APPROVAL = con justificación
          "special_dates": [
            {
              "date":   "2026-02-01",
              "status": "BLOCKED",
              "reason": "Inventario Anual"
            }
          ],
          "emergency_override": {
            "allowed":         true,
            "requires_approval":true,
            "approver_roles":  ["DIRECTOR_VENTAS", "CISO"],
            "max_duration_hours": 4,
            "audit_logging":   "comprehensive"
          }
        },

        "session_management": {
          "max_session_duration_s":     28800,
          // 8 horas. Traducido a client.session.max.lifespan en KC.
          "inactivity_timeout_s":       900,
          // 15 minutos. Traducido a client.offline.session.idle.timeout en KC.
          "force_logout_at_end_shift":  true,
          // bAuth calcula fin de turno y KC expira la sesión.
          "concurrent_sessions_allowed":false,
          // false = máximo 1 sesión activa. maxSessionCount=1 en KC.
          "reauthentication_interval_s":14400
          // Re-autenticar cada 4 horas aunque la sesión esté activa.
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 5 — DOMINIO FÍSICO (Acceso Presencial)
    // Propósito: Controla acceso a espacios físicos, actuadores, hardware.
    // bAuth materializa en SAM-128 Q2 + device fichas banexus/bhnexus.
    // Estándar: ISO/IEC 27001 A.7, NIST SP 800-116, SIA OSDP v2.2.2
    // ═══════════════════════════════════════════════════════════════════

    "physical_access": {
      "enabled": true,

      "availableMethods": [
        "qr_dynamic",
        // QR HMAC-SHA256 generado por bAuth, TTL 30s
        "nfc_mifare_desfire",
        // NFC DESFire con AES-128, LoA 2
        "nfc_mifare_classic",
        // NFC Classic — solo legacy, LoA 1
        "rfid_125khz",
        // RFID Wiegand — baja seguridad, solo donde no hay alternativa
        "fingerprint_hash",
        // Hash PBKDF2-SHA256 del template, nunca raw biometric, LoA 3
        "face_hash",
        // Hash facial, LoA 3
        "smartcard_x509",
        // PKI en tarjeta, LoA 3-4
        "pin_pad"
        // PIN solo — nunca único factor, solo combinado
      ],

      "requiredMethods": {
        "standard_areas": [
          {"method": "nfc_mifare_desfire", "order": 1, "loa": 2}
        ],
        "restricted_areas": [
          {"method": "nfc_mifare_desfire", "order": 1, "loa": 2},
          {"method": "fingerprint_hash",   "order": 2, "loa": 3}
        ],
        "critical_areas": [
          {"method": "smartcard_x509",     "order": 1, "loa": 4},
          {"method": "fingerprint_hash",   "order": 2, "loa": 3}
        ]
      },

      "zones": [
        // Lista de zonas físicas accesibles para este rol.
        // Referencia al árbol jerárquico de 11 niveles en bhnexus.
        {
          "zone_id":        "PHY_ZONE_VENTAS",
          "name":           "Piso de Ventas — Planta Baja",
          "security_level": 2,
          // 1=público, 2=empleados, 3=restringido, 4=crítico
          "access_level":   "FULL",
          // FULL | READ_ONLY | TIMED | ESCORTED
          "schedule":       "business_hours",
          // business_hours | 24x7 | custom:{schedule_id}
          "access_points":  ["AP-PUERTA-01", "AP-PUERTA-02"]
        },
        {
          "zone_id":        "PHY_ZONE_ALMACEN",
          "name":           "Almacén General",
          "security_level": 2,
          "access_level":   "TIMED",
          "schedule":       "business_hours",
          "max_duration_minutes": 30
          // Para accesos TIMED: tiempo máximo por visita.
        },
        {
          "zone_id":        "PHY_ROOM_SERVIDOR",
          "name":           "Sala de Servidores",
          "security_level": 4,
          "access_level":   "DENIED"
          // DENIED explícito — este rol NO tiene acceso aunque esté en la misma zona padre.
        }
      ],

      "biometric_enrollment_policy": {
        // Define cómo se registran los datos biométricos de los usuarios con este rol.
        "mode":              "hybrid",
        // admin_only = solo admin registra
        // self_service = usuario registra sin supervisión
        // hybrid = usuario registra pero admin aprueba
        "risk_level":        "high",
        "liveness_required": true,
        "liveness_method":   "passive",
        // passive | active (desafío aleatorio) | combined
        "fallback_method":   "qr_dynamic",
        // Alternativa si el biométrico falla N veces consecutivas.
        "max_failed_attempts":3,
        "hash_algorithm":    "Argon2id",
        // Argon2id — ganador de PHC 2015, recomendado por OWASP ASVS 2.4.3 y NIST SP 800-63B Rev.4.
        // Parámetros: t=3 (time cost), m=64MB (memory), p=2 (parallelism) para LoA 2-3.
        // Reemplaza PBKDF2-SHA256. SHA1, MD5, bcrypt están deprecados para nuevos roles.
        "argon2_params": {
          "time_cost": 3,
          "memory_mb": 64,
          "parallelism": 2,
          "salt_length": 16,
          "hash_length": 32
        },
        "iterations":        "N/A_para_Argon2id",
        // OWASP 2023: mínimo 310.000 iteraciones para PBKDF2-SHA256 (solo referencia legacy)
        "fmr_threshold":     "1:10000"
        // False Match Rate aceptable (NIST SP 800-76-2).
        // 1:10.000 para LoA 2, 1:100.000 para LoA 3.
      },

      "physical_security_controls": {
        "two_person_rule":   false,
        // true = requiere dos personas simultáneamente (bóvedas, data centers)
        "mantrap_required":  false,
        // true = cámara esclusa entre dos puertas
        "anti_passback": {
          "enabled": true,
          "mode":    "hard",
          // hard = bloquea tailgating estrictamente
          // soft = permite pero alerta
          "reset_hours": 24
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 6 — ZONAS DE NEGOCIO (Dominio Lógico Abstracto)
    // Propósito: Define en qué zonas organizacionales puede operar este rol
    //            y con qué verbos. Las zonas se mapean a aplicaciones en
    //            zone_application_map.yaml — no al revés.
    // bAuth materializa en SAM-128 Q1 (LogicalDomainMask).
    // Estándar: OASIS XACML 3.0, NIST SP 800-162 (ABAC)
    // ═══════════════════════════════════════════════════════════════════

    "zones": {
      // Clave = nombre de zona de negocio (abstracto, no la app).
      // Verbos universales: READ | WRITE | DELETE | APPROVE | EXECUTE | CONFIGURE | AUDIT | EMIT
      // Las aplicaciones que implementan cada zona se resuelven en zone_application_map.yaml.

      "zone_logical/ventas": {
        "verbs":            ["READ", "WRITE", "APPROVE", "EXECUTE"],
        "scope":            "REGIONAL",
        // GLOBAL | REGIONAL | LOCAL | PERSONAL
        // REGIONAL = solo datos de su territorio (Record Rule automática en Tryton)
        "restrictions": {
          "max_record_limit": 1000,
          // Número máximo de registros retornados por consulta
          "data_classification": ["PUBLIC", "INTERNAL", "CONFIDENTIAL"]
          // Niveles de clasificación de datos accesibles en esta zona
        },
        "applications": [
          // Hint de qué apps implementan esta zona.
          // El evaluador lógico resuelve via zone_application_map.yaml.
          {"app": "tryton",   "modules": ["sale", "sale.opportunity", "party"]},
          {"app": "saleor"},
          {"app": "espocrm"}
        ]
      },

      "zone_logical/facturacion": {
        "verbs":            ["READ", "WRITE", "EMIT"],
        "scope":            "REGIONAL",
        "restrictions": {
          "data_classification": ["INTERNAL", "CONFIDENTIAL"]
        },
        "applications": [
          {"app": "tryton",   "modules": ["account_invoice", "account"]},
          {"app": "superset", "dashboards": ["facturacion_regional"]},
          {"app": "paperless","tags": ["factura", "nota_credito"]}
        ]
      },

      "zone_logical/reportes": {
        "verbs":            ["READ", "EXECUTE"],
        "scope":            "REGIONAL",
        "applications": [
          {"app": "superset"},
          {"app": "tryton",   "modules": ["account_statement"]}
        ]
      },

      "zone_logical/clientes": {
        "verbs":            ["READ", "WRITE"],
        "scope":            "REGIONAL",
        "restrictions": {
          "pii_access":          true,
          // Este rol accede a PII — logging extra + enmascaramiento parcial
          "masking_policy":      "lastFourVisible",
          "data_classification": ["CONFIDENTIAL"]
        },
        "applications": [
          {"app": "espocrm"},
          {"app": "tryton",   "modules": ["party"]}
        ]
      },

      "zone_financial/ventas": {
        "verbs":            ["CREATE", "APPROVE"],
        "scope":            "REGIONAL",
        "limit_tier":       2,
        // Tier 0=sin ops, 1=hasta 1k, 2=hasta 10k, 3=hasta 50k, 4=hasta 200k, 5=sin límite
        "sod_cannot_also":  "zone_financial/ventas:AUDIT",
        // SoD: quien crea/aprueba ventas no puede auditarlas
        "requires_dual_approval_above": 10000,
        // Monto en moneda local (currency del tenant) que requiere 2 aprobadores
        "currency":         "BOB"
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 7 — PRIVILEGIOS TRYTON (5 Capas Nativas)
    // Propósito: Definición explícita de cada capa de enforcement en Tryton.
    // bAuth genera estos objetos automáticamente en Tryton al sincronizar.
    // Estándar: Tryton ir.model.access, ir.rule, ir.model.button, ir.action.groups
    // ═══════════════════════════════════════════════════════════════════

    "tryton_privileges": {

      "model_access": [
        // CAPA 1 — Permisos CRUD por modelo de datos.
        // Si read=false → el usuario no ve NINGÚN dato de ese modelo.
        {"model":"sale.order",         "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"sale.opportunity",   "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"sale.line",          "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"party.party",        "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"party.address",      "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"account.invoice",    "read":true,  "write":false, "create":false, "delete":false},
        {"model":"account.invoice.line","read":true, "write":false, "create":false, "delete":false},
        {"model":"account.payment",    "read":true,  "write":true,  "create":true,  "delete":false},
        {"model":"product.product",    "read":true,  "write":false, "create":false, "delete":false},
        {"model":"product.category",   "read":true,  "write":false, "create":false, "delete":false},
        {"model":"stock.shipment.out", "read":true,  "write":false, "create":false, "delete":false},
        {"model":"res.user",           "read":false, "write":false, "create":false, "delete":false},
        // Ningún rol puede leer la tabla de usuarios — aislamiento de privacidad
        {"model":"ir.model",           "read":false, "write":false, "create":false, "delete":false}
      ],

      "visible_actions": [
        // CAPA 2 — Menús y acciones visibles en la UI de Tryton.
        // Menús no listados aquí son INVISIBLES para el usuario.
        "menu_sale_orders",
        "menu_sale_opportunities",
        "menu_sale_products",
        "menu_sale_reports_regional",
        "menu_party_customers",
        "menu_party_addresses",
        "menu_account_invoice_view",
        "menu_account_payment_view",
        "menu_dashboard_ventas",
        "menu_stock_shipment_out_view"
      ],

      "field_restrictions": [
        // CAPA 3 — Acceso a campos individuales.
        // Campos con read:false son eliminados de las vistas automáticamente.
        {"model":"account.invoice",    "field":"margin",       "read":false, "write":false},
        {"model":"account.invoice",    "field":"cost_price",   "read":false, "write":false},
        {"model":"sale.order",         "field":"cost_price",   "read":false, "write":false},
        {"model":"sale.line",          "field":"margin",       "read":false, "write":false},
        {"model":"party.party",        "field":"credit_limit", "read":true,  "write":false},
        // Solo puede ver el límite de crédito, no modificarlo
        {"model":"product.product",    "field":"cost_price",   "read":false, "write":false}
      ],

      "button_rules": [
        // CAPA 4 — Control de botones y aprobaciones con PYSON.
        // El campo sod_cannot_also define restricciones de SoD.
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  1,
          "condition_pyson": "Eval('amount_total', 0) <= 10000",
          "sod_cannot_also": null,
          "step_up_loa":     null,
          "description":     "Confirmar venta hasta 10.000 BOB — sin restricción adicional"
        },
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  2,
          "condition_pyson": "And(Eval('amount_total', 0) > 10000, Eval('amount_total', 0) <= 50000)",
          "sod_cannot_also": null,
          "step_up_loa":     3,
          "description":     "Confirmar venta 10.001–50.000 BOB — requiere 2 aprobadores + WebAuthn"
        },
        {
          "model":           "sale.order",
          "button":          "cancel",
          "users_required":  1,
          "condition_pyson": "Eval('state', '') == 'draft'",
          "sod_cannot_also": null,
          "step_up_loa":     null
        },
        {
          "model":           "account.payment",
          "button":          "approve",
          "users_required":  2,
          "condition_pyson": "Eval('amount', 0) > 5000",
          "sod_cannot_also": "account.payment:create",
          // SoD: quien creó el pago no puede aprobarlo
          "step_up_loa":     3,
          "description":     "Aprobar pago > 5.000 BOB — SoD activo + WebAuthn"
        }
      ],

      "record_rules": [
        // CAPA 5 — Reglas de registros (filtros SQL automáticos).
        // Tryton agrega estos filtros a CADA consulta SQL del usuario.
        {
          "model":       "sale.order",
          "domain_pyson":"[('shop.region', '=', Eval('context', {}).get('user_region', ''))]",
          "description": "Solo pedidos de la región norte asignada al usuario"
        },
        {
          "model":       "sale.opportunity",
          "domain_pyson":"[('responsible.id', '=', Eval('user.id', 0))]",
          "perm_write_exception": true,
          // write_exception = puede escribir en oportunidades ajenas si es manager
          "description": "Solo oportunidades propias o asignadas al equipo regional"
        },
        {
          "model":       "party.party",
          "domain_pyson":"[('category', 'in', ['CUSTOMER', 'PROSPECT', 'SUPPLIER'])]",
          "description": "Solo clientes, prospectos y proveedores — nunca internos ni empleados"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 8 — DOMINIO FINANCIERO (Transacciones y SoD)
    // Propósito: Regula operaciones económicas, límites y aprobaciones.
    // bAuth materializa en SAM-128 Q3 (FinancialDomainMask).
    // Estándar: PCI-DSS v4.0, ISO 27001 A.5.3, NIST SP 800-53 AC-5, ISACA COBIT 2019
    // ═══════════════════════════════════════════════════════════════════

    "financial_transactions": {
      "enabled": true,

      "availableMethods": [
        // Métodos de autenticación adicionales requeridos para operaciones financieras.
        "smart_card_pin",
        "mobile_token",
        "biometric_validation",
        "digital_signature",
        "hardware_security_token"
      ],

      "requiredMethods": {
        "standard_transactions": [
          {"method": "smart_card_pin", "order": 1},
          {"method": "mobile_token",   "order": 2}
        ],
        // Transacciones estándar (hasta single_transaction_limit).

        "high_value_transactions": [
          {"method": "smart_card_pin",      "order": 1},
          {"method": "mobile_token",         "order": 2},
          {"method": "biometric_validation", "order": 3}
        ]
        // Transacciones de alto valor (> requires_dual_approval_above).
      },

      "transaction_schedule": {
        // Ventanas de tiempo durante las cuales se permiten transacciones financieras.
        "type": "SCHEDULED",
        // CONTINUOUS = sin restricción horaria
        // SCHEDULED  = solo en períodos definidos
        "schedules": [
          {
            "name": "Pagos a Proveedores — Quincenal",
            "periods": [
              {
                "days_of_month": [13, 14, 15],
                "hours": {"start": "09:00", "end": "16:00"},
                "timezone": "America/La_Paz"
              },
              {
                "days_of_month": [28, 29, 30, 31],
                "hours": {"start": "09:00", "end": "16:00"},
                "timezone": "America/La_Paz"
              }
            ]
          }
        ],
        "emergency_override": {
          "allowed":         true,
          "requires_approval":true,
          "approver_roles":  ["FINANCE_DIRECTOR", "CEO"],
          "max_duration_hours": 2,
          "audit_logging":   "critical"
        }
      },

      "transaction_limits": {
        "currency":               "BOB",
        "single_transaction_limit": 10000,
        // Una sola transacción. Si > límite: requiere aprobación adicional.
        "daily_limit":            50000,
        // Suma de todas las transacciones del día.
        "monthly_limit":          200000,
        // Suma mensual.
        "per_period_limit":       100000,
        // Por período de nómina/quincenal.
        "requires_dual_approval_above": 10000
        // > N BOB requiere 2 aprobadores distintos.
      },

      "sod_rules": [
        // Segregación de Funciones — evaluada por Conflict Matrix en bAuth.
        // Estas reglas se aplican ANTES de guardar asignaciones de rol.
        {
          "action":        "zone_financial/ventas:CREATE",
          "cannot_also":   "zone_financial/ventas:APPROVE",
          "description":   "Quien crea ventas no puede aprobar sus propias ventas",
          "severity":      "critical"
        },
        {
          "action":        "zone_financial/pagos:CREATE",
          "cannot_also":   "zone_financial/pagos:APPROVE",
          "description":   "Separación creador/aprobador de pagos",
          "severity":      "critical"
        }
      ],

      "geospatial_control": {
        // Restricción geográfica específica para operaciones financieras.
        "allowed_locations": [
          {
            "type":          "office",
            "name":          "Oficina Central Finanzas — La Paz",
            "network_ranges":["10.0.1.0/24"]
          }
        ],
        "validation_rules": {
          "require_secure_network":       true,
          "allow_remote":                 false,
          "require_location_verification":true,
          "require_vpn":                  false
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 9 — SAM-128 + BITMASK 64-bit (Sovereign Authority Matrix)
    // Propósito: Representación binaria calculada por PrivilegeEngine.
    // Solo lectura — bAuth lo calcula automáticamente desde los bloques anteriores.
    //
    // ARQUITECTURA DE DOBLE CAPA (bAuth v2.0):
    // - BitMask 64-bit (catálogo de roles): capa 1 [31:0] sistema, capa 2 [63:32] negocio.
    //   Usada para herencia de privilegios via DAG (OR bitwise).
    //   Documentada en: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 §6.
    // - SAM-128 (éste bloque): matriz de autoridad soberana de 128 bits.
    //   Extiende el BitMask con dominios físico, financiero, y de gobernanza.
    //
    // Estándar: SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO v1.0
    // ═══════════════════════════════════════════════════════════════════

    "sam128": {
      "_readonly": true,
      "_description": "Calculado por PrivilegeEngine. No editar manualmente.",
      "bitmask_64_ref": {
        "_description": "El BitMask 64-bit del catálogo alimenta los primeros 64 bits del SAM-128.",
        "layer1_system_mask": "bits_0_31_privilegios_sistema",
        "layer2_business_mask": "bits_32_63_privilegios_negocio",
        "effective_mask": "mask_own_OR_mask_efectiva_de_todos_los_junior",
        "inheritance": "DAG_NIST_RBAC_§4.2"
      },
      "physical_domain_mask_hex": "0x000000000003E627",
      // SAM-128 Q1+Q2 (bits 0-63): dominio físico + lógico básico
      "logical_domain_mask_hex":  "0x0000010900030052",
      // SAM-128 Q1 extendido: zonas de negocio × verbos
      "financial_domain_mask_hex":"0x0000020900010000",
      // SAM-128 Q3 (bits 64-95): dominio financiero
      "governance_mask_hex":      "0x0000021200010052",
      // SAM-128 Q4 (bits 96-127): soberanía, LoA, auditoría
      "computed_at":              "2026-06-20T10:35:00Z",
      "computed_by":              "bAuth.PrivilegeEngine.v2.0"
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 10 — DELEGACIÓN
    // Propósito: Controla cómo este rol puede delegar permisos temporalmente.
    // Implementa DSD (Dynamic Separation of Duties) según ANSI/INCITS 359-2004 §4.2.
    // ═══════════════════════════════════════════════════════════════════

    "delegation_config": {
      "can_delegate":        true,
      "max_duration_days":   21,
      // Una delegación no puede durar más de 21 días.
      "delegable_to_roles":  ["SUP-NORTE-001", "GER-VENTAS-SUR"],
      // Solo puede delegar a estos roles específicos.
      "non_delegable_permissions": [
        // Permisos que NUNCA pueden ser delegados, independientemente.
        "zone_logical/reportes:CONFIGURE",
        "zone_financial/ventas:APPROVE",
        "GOV_ADMIN_USERS"
      ],
      "requires_approval":   true,
      "approver_roles":      ["DIRECTOR_VENTAS"],
      "max_concurrent_delegations": 1,
      // Solo una delegación activa a la vez.
      "auto_revoke_on_expiry": true,
      // bAuth revoca automáticamente al vencer valid_until.
      "notification_channels":["email", "rocket_chat"]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 11 — GESTIÓN DE GRUPOS Y JERARQUÍAS
    // Propósito: Define herencia, grupos funcionales y reglas de composición.
    // ═══════════════════════════════════════════════════════════════════

    "group_management": {
      "role_hierarchy": {
        "level":        2,
        "parent_role":  "VEN-BASE-001",
        "child_roles":  ["SUP-NORTE-001", "VEN-VEN-NORTE-001"],
        "inheritance_rules": {
          "inherit_permissions": true,
          "bits_removed_from_parent": [
            "PERM_CONFIG",
            // Este rol hereda de VEN-BASE-001 pero NO puede configurar el sistema
            "GOV_ADMIN_USERS"
          ],
          // Implementación: SAM = parent_mask &^ bits_removed (AND NOT)
          "permission_modifications": {
            "FIN_LIMIT_TIER": {
              "parent_value": 3,
              // Tier 3 en el padre (hasta 50k)
              "inherited_value": 2
              // Este rol solo tiene Tier 2 (hasta 10k)
            }
          }
        }
      },

      "role_groups": [
        {
          "group_id":         "VENTAS_TEAM",
          "group_type":       "FUNCTIONAL",
          "members":          ["RGV-001", "SUP-NORTE-001", "VEN-VEN-NORTE-001"],
          "shared_permissions":["zone_logical/ventas:READ", "zone_logical/clientes:READ"],
          "group_policies": {
            "minimum_active_members": 1,
            "quorum_requirements": {
              "high_value_sales":  2,
              // Para ventas > 10k BOB se necesitan 2 miembros del grupo activos
              "policy_changes":    3
            }
          }
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 12 — GESTIÓN DE CONFLICTOS (SoD y Conflicto de Intereses)
    // Propósito: Prevent fraud mediante separación formal de funciones.
    // Estándar: ISACA COBIT 2019, ISO 27001 A.5.3, NIST SP 800-53 AC-5
    // ═══════════════════════════════════════════════════════════════════

    "conflict_management": {
      "segregation_of_duties": {
        "incompatible_roles": [
          // Roles que NO pueden coexistir en el mismo usuario con este rol.
          {
            "incompatible_with": "FIN-AUDIT-001",
            "description":       "Gerente de ventas no puede ser auditor financiero",
            "severity":          "critical",
            "mitigation":        "DENY"
            // DENY = bloquea la asignación
            // APPROVE = requiere aprobación especial
          }
        ],
        "incompatible_functions": [
          {
            "function_a": "zone_financial/ventas:CREATE",
            "function_b": "zone_financial/ventas:AUDIT",
            "description":"Quien crea transacciones no puede auditarlas",
            "severity":   "critical",
            "mitigation": "DENY"
          }
        ],
        "conflict_validation": {
          "check_frequency": "REAL_TIME",
          // bAuth valida en cada solicitud de acceso y en cada cambio de rol
          "validation_scope":["DIRECT_CONFLICTS", "INHERITED_CONFLICTS", "DELEGATION_CONFLICTS"]
        }
      },

      "interest_conflicts": {
        "restricted_entities": [
          {
            "type": "VENDORS",
            "validation_rules": {
              "check_ownership":      true,
              "check_relationship":   true,
              "relationship_degrees": 2
              // Familiares hasta 2do grado no pueden ser proveedores auditados por este rol
            }
          }
        ],
        "declaration_requirements": {
          "frequency":                "ANNUAL",
          "requires_update_on_change":true,
          "verification_method":      "COMPLIANCE_REVIEW",
          "documentation":            "mandatory"
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 13 — CUMPLIMIENTO Y AUDITORÍA
    // Propósito: Garantizar trazabilidad y cumplimiento normativo.
    // Estándar: ISO 27001 A.8.15, RGPD Art.30, SOX §404, PCI-DSS Req.10
    // ═══════════════════════════════════════════════════════════════════

    "compliance_audit": {
      "review_frequency":  "QUARTERLY",
      // MONTHLY | QUARTERLY | SEMIANNUAL | ANNUAL
      "last_review_date":  "2026-01-01T00:00:00Z",
      "next_review_date":  "2026-07-01T00:00:00Z",
      "review_scope": [
        "ACCESS_PATTERNS",
        "PERMISSION_USAGE",
        "DELEGATION_HISTORY",
        "CONFLICT_VIOLATIONS",
        "FINANCIAL_TRANSACTIONS"
      ],
      "reviewers":         ["DIRECTOR_VENTAS", "COMPLIANCE_OFFICER", "INTERNAL_AUDIT"],

      "regulatory_frameworks": {
        "pci_dss": {
          "applicable":    true,
          "requirements":  ["Req.7", "Req.8", "Req.10"],
          "review_evidence":["access_logs", "sod_matrix", "mfa_enforcement"]
        },
        "gdpr": {
          "applicable":    true,
          "pii_access":    true,
          "legal_basis":   "legitimate_interest",
          "data_minimization": true,
          "retention_days":365
        }
      },

      "access_review_policy": {
        "auto_revoke_on_review_failure": false,
        // Si el revisado no responde a la revisión en SLA → auto-revocar
        "sla_days":       14,
        "escalation":     ["CISO", "HR_DIRECTOR"]
      },

      "change_tracking": {
        "tracked_elements": [
          "PERMISSIONS", "AUTHENTICATION_METHODS", "TEMPORAL_ACCESS",
          "DELEGATIONS", "FINANCIAL_LIMITS", "SOD_RULES"
        ],
        "retention_years": 7
        // ISO 27001 + SOX: mínimo 7 años para registros financieros
      }
    },

    // ═══════════════════════════════════════════════════════════════════
    // BLOQUE 14 — ESTADO DE SINCRONIZACIÓN
    // Propósito: Rastrear sincronización con KC y Tryton.
    // Gestionado por bAuth — solo lectura para administradores.
    // ═══════════════════════════════════════════════════════════════════

    "sync_state": {
      "_readonly":     true,
      "_description":  "Gestionado exclusivamente por bAuth.PrivilegeEngine. No editar.",
      "sync_status":   "SYNCED",
      // PENDING | SYNCING | SYNCED | ERROR | ERROR_TRYTON_PENDING | DRIFT
      "last_sync_at":  "2026-03-01T10:35:00Z",
      "sync_targets": {
        "keycloak": {
          "status":          "SYNCED",
          "composite_role":  "RGV_001",
          "group_path":      "/Empresa-ACME/Ventas/Norte",
          "auth_flow":       "RGV_001_browser_flow",
          "realm_roles":     ["SALES_VIEW", "SALES_WRITE", "SALES_APPROVE_10K", "REPORTS_REGIONAL"],
          "last_synced_at":  "2026-03-01T10:35:00Z"
        },
        "tryton": {
          "status":          "SYNCED",
          "group_id":        847,
          "group_name":      "RGV_001",
          "last_synced_at":  "2026-03-01T10:35:00Z"
        }
      },
      "drift_detected":  false,
      "drift_details":   null
    }

  }
}
```

---

## REGLAS DE VALIDACIÓN (bAuth PrivilegeEngine)

### Validaciones de Schema (JSON Schema 2020-12)

| Campo | Regla | Error |
|---|---|---|
| `id` | Patrón `^[A-Z]+-[0-9]{3}$` | `INVALID_ID_FORMAT` |
| `parent_id` | Debe existir en `bos_rol_template` | `PARENT_NOT_FOUND` |
| `validity_period.end_date` | Si type=FIXED → obligatorio y > start_date | `INVALID_VALIDITY` |
| `zones.*.limit_tier` | Entero 0–5 | `INVALID_LIMIT_TIER` |
| `approval_workflow.required_approvers` | ≤ len(approver_roles) | `INVALID_APPROVERS` |
| `tryton_privileges.button_rules.*.sod_cannot_also` | Formato `model.button:action` o `zone_*:VERB` | `INVALID_SOD_FORMAT` |

### Validaciones Semánticas (Runtime)

| Regla | Descripción |
|---|---|
| **DAG check** | No permite ciclos en la jerarquía de herencia |
| **Conflict Matrix** | SoD evaluada antes de guardar — `conflict_management.segregation_of_duties` |
| **LoA coherence** | `level_of_assurance` debe ser ≥ al LoA del parent_id |
| **Zone verb consistency** | Verbos en `zones` deben ser subconjunto de verbos universales |
| **SAM-128 bounds** | Ningún bit en posición > 127 |
| **Delegation depth** | Max 2 niveles de delegación encadenada |

---

## TABLA DE MAPPING: ROLTEMPLATE → KEYCLOAK

| Campo RolTemplate | Objeto KC creado | Tipo de sync |
|---|---|---|
| `logical_access.requiredMethods` | Authentication Flow `{id}_browser_flow` | CREATE + UPDATE |
| `logical_access.geospatial_control.allowed_locations` | User Attribute `allowed_networks` | UPDATE user |
| `logical_access.temporal_control.allowed_days` | User Attributes `allowed_days`, `shift_start`, `shift_end` | UPDATE user |
| `validity_period.end_date` | User Attribute `role_valid_until` | UPDATE user |
| `logical_access.session_management.max_session_duration_s` | `client.session.max.lifespan` | UPDATE client |
| `logical_access.session_management.concurrent_sessions_allowed` | `maxSessionCount: 1/N` | UPDATE realm |
| `id` | Composite Role name = `{id}` | CREATE |
| `zones.*.verbs` | Realm Roles atómicos | CREATE/DELETE |
| `sam128.governance_mask_hex` | User Attribute `bos_sam128_governance` | UPDATE user |

---

## TABLA DE MAPPING: ROLTEMPLATE → TRYTON

| Campo RolTemplate | Objeto Tryton creado | Capa |
|---|---|---|
| `id` | `res.group` con name = `{id}` | Base |
| `tryton_privileges.model_access` | `ir.model.access` por modelo | Capa 1 |
| `tryton_privileges.visible_actions` | `ir.action.groups` | Capa 2 |
| `tryton_privileges.field_restrictions` | `ir.model.field.access` | Capa 3 |
| `tryton_privileges.button_rules` | `ir.model.button` + Button Rule | Capa 4 |
| `tryton_privileges.record_rules` | `ir.rule.group` | Capa 5 |

---

## CICLO DE VIDA DEL ROLTEMPLATE

```
DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED
          ↑
     Requiere N aprobaciones del approval_workflow
          ↓
     bAuth sincroniza KC + Tryton en < 5 segundos
```

**Transiciones automáticas:**
- `ACTIVE` → `DEPRECATED` cuando `validity_period.end_date` expira
- `DEPRECATED` → `ARCHIVED` cuando no queda ningún usuario asignado
- `ACTIVE` → `DRAFT` solo si no hay usuarios asignados activos

---

## STÁNDAR DE NOMENCLATURA

| Tipo | Formato | Ejemplo |
|---|---|---|
| Rol operativo | `{DEPT}-{NN}` | `VEN-VEN-001`, `CAJ-001` |
| Rol supervisor | `{DEPT}-SUP-{NN}` | `VEN-SUP-001` |
| Rol gerencia regional | `{DEPT}RGV-{NN}` | `RGV-001` |
| Rol director | `{DEPT}DGV-{NN}` | `DGV-001` |
| Rol C-Level | `{SIGLA}-{NN}` | `CFO-001`, `CEO-001`, `CISO-001` |
| Rol de sistema/servicio | `SVC-{APP}-{NN}` | `SVC-TRYTON-001`, `SVC-SALEOR-001` |
| Rol de auditoría | `AUD-{SCOPE}-{NN}` | `AUD-FIN-001`, `AUD-SYS-001` |

---

---

# PLAN DE REPARACIÓN — Cobertura D0–D12 en el RolTemplate
## Agregado en sesión 2026-07-08 · No modifica el contrato v6.0 existente

---

## PR-1. MATRIZ DE COBERTURA ACTUAL (14 bloques vs 13 dominios D0–D12)

| Dominio | Nombre | ¿Tiene bloque dedicado? | ¿Dónde está actualmente? | Estado |
|---------|--------|------------------------|--------------------------|--------|
| **D0** | Organizacional / Identidad del Rol | Parcial | B1 `metadata` (department, region, job_family, classification) | ⚠️ IMPLÍCITO — no declarado como dominio |
| **D1** | Lógico (Autenticación Digital) | ✅ Sí | **B4 `logical_access`** — métodos, LoA, step-up, session | ✅ COMPLETO |
| **D2** | Físico (Acceso Presencial) | ✅ Sí | **B5 `physical_access`** — zonas, métodos físicos, anti-passback | ✅ COMPLETO |
| **D3** | Financiero (Transacciones) | ✅ Sí | **B8 `financial_transactions`** — límites, SoD, schedule | ✅ COMPLETO |
| **D4** | Temporal (Ciclo de Vida / Sesiones) | ❌ No dedicado | Embebido en **B2** (`validity_period`) + **B4** (`temporal_control`) + **B8** (`transaction_schedule`) | ⚠️ DISPERSO — 3 bloques |
| **D5** | Biométrico (Enrollamiento y Verificación) | ❌ No dedicado | Embebido en **B5** (`biometric_enrollment_policy`) | ⚠️ EMBEBIDO en D2 |
| **D6** | Geoespacial (Ubicación y Red de Origen) | ❌ No dedicado | Embebido en **B4** y **B8** (`geospatial_control`) | ⚠️ DUPLICADO en 2 bloques |
| **D7** | Red (Network Access Control) | ❌ AUSENTE | Solo `network_ranges` dentro de `geospatial_control.allowed_locations` | ❌ FALTA BLOQUE |
| **D8** | Contexto Adaptativo (Risk Engine) | ❌ No dedicado | Parcial en **B4** (`step_up_rules`) — sin risk engine ni device posture | ⚠️ INCOMPLETO |
| **D9** | Credenciales (Lifecycle Management) | ❌ No dedicado | Solo `availableMethods` en B4 — sin enrollment, rotación, revocación | ⚠️ INCOMPLETO |
| **D10** | Delegación (DSD / SoD Dinámico) | ✅ Sí | **B10 `delegation_config`** + **B11** + **B12** | ✅ COMPLETO |
| **D11** | Auditoría (Cumplimiento y Trazabilidad) | ✅ Sí | **B13 `compliance_audit`** + `audit` en B1 | ✅ COMPLETO |
| **D12** | Blockchain (Firma Digital / DLT) | ❌ No dedicado | Solo `digital_signature` en **B1** — sin contratos, wallet, cadena | ⚠️ INCOMPLETO |

**Resumen:** 6 de 13 dominios completamente cubiertos · 4 parcialmente cubiertos · 3 ausentes o implícitos.

---

## PR-2. ANÁLISIS PROFUNDO POR DOMINIO FALTANTE

### D0 — Organizacional (implícito en B1)

**Qué existe hoy:** `metadata.department`, `metadata.region`, `metadata.job_family`, `metadata.classification`.

**Qué falta formalizarse como D0:**
El dominio organizacional es la **identidad del rol dentro de la estructura de la empresa** — va más allá de metadata de contacto. Según ISO/IEC 24760-2:2025 (Identity Management Architecture), la identidad organizacional requiere:
- `org_unit_id`: unidad organizativa canónica (no solo nombre)
- `cost_center`: código de centro de costos (ya existe ✅)
- `tenant_id`: identificador del tenant SBOS al que pertenece
- `sector_code`: código CAEB SIN (catálogo de 21 sectores definido en bAuth)
- `accountability_chain`: cadena de responsabilidad hasta el CEO
- `data_owner_roles`: quiénes son custodios de los datos que este rol maneja

**Decisión de diseño:** D0 puede mantenerse en B1 si se enriquece el `metadata` con los campos anteriores. No requiere bloque separado.

---

### D4 — Temporal (disperso en B2, B4, B8)

**Qué existe hoy:**
- `validity_period` (B2): vigencia del RolTemplate como contrato
- `temporal_control` (B4): horarios de acceso lógico, timezone, sesiones
- `transaction_schedule` (B8): ventanas de tiempo para transacciones financieras

**El problema:** Son tres conceptos temporales distintos que responden a preguntas diferentes:
- B2 → ¿Hasta cuándo existe ESTE ROL como entidad?
- B4 → ¿En qué horario puede el USUARIO AUTENTICARSE?
- B8 → ¿En qué ventana puede el USUARIO EJECUTAR TRANSACCIONES?

**Propuesta:** No crear B15 separado. En cambio, añadir en cada bloque existente una referencia cruzada explícita a D4 para que el administrador entienda que los tres son partes del control temporal. El campo `d4_temporal_ref` en B4 y B8 enlaza a B2.

---

### D5 — Biométrico (embebido en B5)

**Qué existe hoy:** `physical_access.biometric_enrollment_policy` con campos robustos (Argon2id, liveness, FMR threshold, fmr_threshold).

**Qué falta:**
- `biometric_types_enrolled`: qué modalidades tiene registradas este rol (huella, iris, rostro, voz)
- `cross_modality_policy`: si puede usar modalidad alternativa si falla la primaria
- `biometric_consent`: requisitos de consentimiento RGPD Art.9 (dato biométrico es dato sensible)
- `template_storage`: dónde se almacena el template (on-device, server-side encrypted, federated)
- `iso_30107_pad_level`: nivel de detección de ataques de presentación (PAD Level 1/2/3)

**Estándar de referencia:** ISO/IEC 30107-3:2023 Presentation Attack Detection · NIST SP 800-76-2 · FIDO UAF 2.0 §4.

**Propuesta:** Enriquecer `physical_access.biometric_enrollment_policy` con estos campos. D5 permanece embebido en B5 pero completo.

---

### D6 — Geoespacial (duplicado en B4 y B8)

**Qué existe hoy:**
- `logical_access.geospatial_control` (B4): allowed_locations con network_ranges, geo_velocity_check
- `financial_transactions.geospatial_control` (B8): allowed_locations para operaciones financieras

**El problema:** La duplicación crea riesgo de inconsistencia — si se actualiza la lista de ubicaciones en B4 pero no en B8, el sistema tiene dos fuentes de verdad para el mismo concepto.

**Propuesta:**
Extraer la lógica geoespacial a un **B15 `geospatial_policy`** canónico con:
```json
"geospatial_policy": {
  "allowed_locations": [...],          // ÚNICA fuente de verdad
  "validation_rules": {...},
  "financial_override": {              // si null → usa las mismas reglas base
    "require_secure_network": true,
    "allow_remote": false
  },
  "gps_attestation": {                 // para métodos con GPS (am22, am4, am6)
    "required": false,
    "max_accuracy_meters": 100,
    "provider": "FIDO2_GPS_ATTESTATION"
  }
}
```
En B4 y B8 quedan referencias: `"geospatial_ref": "geospatial_policy"`.

**Estándar:** USPTO US 12375929 (Geolocation Auth) · WinMagic MagicEndpoint · LBAC (Location-Based AC).

---

### D7 — Red (AUSENTE — requiere bloque nuevo B16)

**Qué existe hoy:** Solo `network_ranges: ["10.0.1.0/24"]` dentro de `geospatial_control.allowed_locations`. No hay control de red como disciplina propia.

**Qué necesita un bloque D7 completo:**
Según NIST SP 800-207 (Zero Trust Architecture) §2.2 y Microsoft Entra Conditional Access:

```json
"network_access": {
  "enabled": true,
  "zero_trust_mode": true,            // NIST SP 800-207: never trust always verify
  "device_compliance": {
    "required": true,
    "check_provider": "kong_opa",     // Kong + OPA como PEP
    "posture_requirements": ["managed", "patched", "encrypted"]
  },
  "allowed_ranges": [                 // extrae de geospatial_control actual
    {"type": "office",   "cidr": "10.0.1.0/24"},
    {"type": "vpn",      "cidr": "10.10.0.0/16"},
    {"type": "any",      "requires_vpn": true}
  ],
  "mtls_required": false,             // si true → client cert en cada request
  "api_gateway_rules": {
    "rate_limit_rpm": 1000,
    "allowed_origins": ["*"],
    "kong_plugins": ["rate-limiting", "ip-restriction", "bot-detection"]
  },
  "network_segmentation": {
    "vlan_id": null,
    "micro_segmentation": false
  }
}
```

**Fuente:** NIST SP 800-207 §2.2 · Okta Adaptive MFA (device posture signals) · Microsoft Entra Conditional Access (device compliance, named locations) · Google BeyondCorp (device-based access).

---

### D8 — Contexto Adaptativo (incompleto en B4 step_up_rules)

**Qué existe hoy:** `step_up_rules` en B4 con trigger, condition_pyson, required_loa, max_age_seconds.

**Qué falta:** El motor de riesgo contextual completo. Okta Adaptive MFA, Microsoft Entra ID Protection y Google BeyondCorp definen el contexto como señales **continuas**, no solo triggers puntuales:

```json
"adaptive_context": {
  "risk_engine": {
    "provider": "bauth_internal",
    "evaluation_mode": "continuous",   // no solo al login
    "revoke_on_anomaly": true,         // revoca token si riesgo aumenta
    "assessment_interval_s": 300
  },
  "context_signals": {
    "device_posture": true,            // ¿dispositivo gestionado y actualizado?
    "user_behavior": true,             // baseline de horarios, IPs, velocidad de tecleo
    "threat_intel": false,             // feed externo de IPs maliciosas
    "impossible_travel": true,         // ya en geospatial_control (cross-ref D6)
    "new_device": true,                // primer acceso desde este dispositivo
    "time_of_day": true                // cross-ref con D4 temporal_control
  },
  "adaptive_policies": [
    {
      "condition": "risk_score > 0.7",
      "action":    "step_up",
      "required_loa": 3
    },
    {
      "condition": "risk_score > 0.9",
      "action":    "block",
      "notify_channels": ["email", "rocket_chat"]
    }
  ],
  "emergency_access": {
    "allowed": true,
    "bypass_conditions": ["verified_emergency", "dual_approval"],
    "max_duration_hours": 4,
    "audit": "critical"
  }
}
```

**Estándar:** NIST SP 800-207 §2.1 Policy Engine · RFC 9470 §4 (step-up) · OpenID CAEP (Continuous Access Evaluation Protocol) · Okta ThreatInsight · Microsoft Entra ID Protection Risk Signals.

---

### D9 — Credenciales (ciclo de vida ausente)

**Qué existe hoy:** `logical_access.availableMethods` lista los métodos que el rol PUEDE usar. Pero no define el ciclo de vida de las credenciales que lo sustentan.

**Qué falta:** El ciclo de vida completo (NIST SP 800-63B-4 §2.2 — Authenticator Lifecycle):

```json
"credential_lifecycle": {
  "enrollment_policy": {
    "verification_level": "IAL2",      // IAL1=self-asserted, IAL2=verificado, IAL3=presencial
    "requires_supervisor_approval": true,
    "enrollment_channels": ["admin_portal", "self_service"],
    "binding_type": "post_enrollment"  // NIST 800-63B-4 §6.1.2
  },
  "rotation_policy": {
    "password": {
      "mandatory_rotation": false,     // NIST 800-63B-4 eliminó rotación forzada
      "trigger_on_breach": true,       // sí rotar si aparece en lista de brechas
      "min_age_days": 1
    },
    "totp_seed": { "rotation_on_device_change": true },
    "x509_cert": { "max_age_days": 365, "auto_renew": true }
  },
  "revocation_policy": {
    "immediate_on_termination": true,  // al salir del rol → revocar en < 30s
    "suspension_before_revoke": true,  // suspender antes de revocar (permite reintegro)
    "suspension_grace_days": 7,
    "channels": ["keycloak", "vault", "kong"]
  },
  "privilege_creep_detection": {
    "enabled": true,
    "review_interval_days": 90,
    "auto_flag_threshold": 0.3         // si 30% de permisos no usados → alert
  },
  "recovery_policy": {
    "channels": ["email_recuperacion", "supervisor_approval"],
    "identity_verification_required": "IAL1",
    "max_recovery_attempts": 3
  }
}
```

**Estándar:** NIST SP 800-63B-4 §6 (Authenticator Lifecycle) · NIST SP 800-63B-4 §5.1.1 (Memorized Secrets) · ISO/IEC 24760-2:2025 §7 · OWASP ASVS v5.0 §2.1-2.5.

---

### D12 — Blockchain / Firma Digital (incompleto en B1)

**Qué existe hoy:** `digital_signature` en B1 cubre la firma del CONTRATO del RolTemplate (EdDSA Ed25519 con Vault, CRYSTALS-Dilithium planeado). Esto es la integridad del documento, NO las operaciones blockchain del rol.

**Qué falta:** Los permisos del rol para OPERAR en Besu QBFT (la cadena blockchain de SBOS):

```json
"blockchain_access": {
  "enabled": false,                    // mayoría de roles no necesita
  "network": {
    "chain": "besu_qbft",
    "chain_id": 1337,
    "node_endpoint": "internal"        // via bnexa, nunca directo
  },
  "signing_config": {
    "algorithm": "ECDSA_secp256k1",    // para Besu EVM
    "key_managed_by": "vault",         // Vault PKI Engine
    "key_path": "besu/keys/{role_id}"
  },
  "ley164_compliance": {
    "required": false,                 // true = firma con validez jurídica Bolivia
    "adsib_cert_required": false,      // certificado ADSIB/SIN
    "rnd_102100000011": false          // SIN facturación electrónica
  },
  "smart_contract_permissions": [
    {
      "contract": "AuditLog",
      "functions": ["appendEntry"],    // append-only para este rol
      "read_only": false
    }
  ],
  "on_chain_audit": {
    "enabled": false,
    "event_types": ["high_value_approval", "role_change"]
  },
  "wallet_policy": {
    "rotation_on_compromise": true,
    "max_transaction_value_wei": null  // null = sin límite de token value
  }
}
```

**Estándar:** Besu QBFT docs · ANSI X9.62 (ECDSA) · RFC 8032 (EdDSA) · Bolivia Ley 164 Art.13 · ADSIB-FD-POLT-015 v2.3 · SIN RND 102100000011.

---

## PR-3. PROPUESTA DE NUEVOS BLOQUES (B15–B21)

| Nro | Nuevo Bloque | Dominio | Acción | Prioridad |
|-----|-------------|---------|--------|-----------|
| **B15** | `geospatial_policy` | D6 | Extraer de B4+B8 y unificar — elimina duplicidad | 🔴 ALTA |
| **B16** | `network_access` | D7 | Crear nuevo — no existe actualmente | 🔴 ALTA |
| **B17** | `adaptive_context` | D8 | Crear nuevo — step_up_rules es insuficiente | 🟠 MEDIA |
| **B18** | `credential_lifecycle` | D9 | Crear nuevo — ciclo de vida no existe | 🟠 MEDIA |
| **B19** | `blockchain_access` | D12 | Crear nuevo — separar de `digital_signature` B1 | 🟡 BAJA (mayoría de roles: enabled=false) |
| D5 enrich | Enriquecer B5 | D5 | Agregar campos ISO 30107-3 a `biometric_enrollment_policy` | 🟡 BAJA |
| D4 refactor | Unificar referencias | D4 | Agregar `d4_temporal_ref` cross-links entre B2, B4, B8 | 🟡 BAJA |

---

## PR-4. ESTRUCTURA ÁRBOL COMPLETA (D0–D12 con bloques existentes + propuestos)

```
role: {
  ├── B1  IDENTIFICACIÓN          → D0 (org identity, firma del contrato)
  ├── B2  VIGENCIA                → D4 (ciclo de vida del contrato)
  ├── B3  APROBACIÓN              → gobernanza
  ├── B4  D1 LÓGICO               → D1 + [D4 temporal] + [D6 geo] + [D8 step-up]
  ├── B5  D2 FÍSICO               → D2 + [D5 biométrico]
  ├── B6  ZONAS DE NEGOCIO        → D1 (abstracto) + D3 (financiero)
  ├── B7  PRIVILEGIOS TRYTON      → D1 (operaciones ERP — 5 capas)
  ├── B8  D3 FINANCIERO           → D3 + [D4 schedule] + [D6 geo]
  ├── B9  SAM-128 [READONLY]      → todos los dominios (representación binaria)
  ├── B10 D10 DELEGACIÓN          → D10
  ├── B11 GRUPOS Y JERARQUÍAS     → D10 (gobernanza de grupos)
  ├── B12 SOD — CONFLICTOS        → D10 (SoD estático + dinámico)
  ├── B13 D11 AUDITORÍA           → D11
  ├── B14 SYNC STATE [READONLY]   → D1 + D2 (estado KC + Tryton)
  │
  │   ══════ BLOQUES PENDIENTES (propuestos) ══════
  │
  ├── B15 D6 GEOESPACIAL          → D6 [PROPUESTO — unifica B4+B8 geospatial_control]
  ├── B16 D7 RED                  → D7 [NUEVO — network_access + device_posture]
  ├── B17 D8 CONTEXTO ADAPTATIVO  → D8 [NUEVO — risk_engine + continuous_assessment]
  ├── B18 D9 CREDENCIALES         → D9 [NUEVO — enrollment + rotation + revocation]
  └── B19 D12 BLOCKCHAIN          → D12 [NUEVO — besu_qbft + ley164 + wallet]
}
```

---

## PR-5. SECUENCIA DE REPARACIÓN

| Fase | Tarea | Dependencia | Entregable |
|------|-------|-------------|-----------|
| **F1** | Enriquecer B1 `metadata` con campos D0 | — | D0 completo |
| **F2** | Enriquecer B5 `biometric_enrollment_policy` con campos ISO 30107-3 | — | D5 completo |
| **F3** | Crear B15 `geospatial_policy` y referenciar desde B4+B8 | B4, B8 | D6 unificado |
| **F4** | Crear B16 `network_access` | B15 (locations) | D7 completo |
| **F5** | Crear B17 `adaptive_context` | B4 step_up_rules, B16 device_posture | D8 completo |
| **F6** | Crear B18 `credential_lifecycle` | B4 availableMethods | D9 completo |
| **F7** | Crear B19 `blockchain_access` | B1 digital_signature | D12 completo |
| **F8** | Añadir cross-refs D4 en B2+B4+B8 | F3 | D4 explícito |
| **F9** | Actualizar SAM-128 B9 para incluir los nuevos dominios en governance_mask | F1-F8 | B9 completo |
| **F10** | Actualizar B14 `sync_state.sync_targets` para incluir bHnexus (D2/D7) y Vault (D9/D12) | F4, F6, F7 | B14 completo |

**Todo cambio al contrato v6.0 requiere aprobación HITL antes de commitear.**

---

## PR-6. FUENTES DE INVESTIGACIÓN

- [NIST SP 800-63B-4 — Authenticator Lifecycle §6](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-63B-4.pdf)
- [NIST SP 800-207 — Zero Trust Architecture §2.2 Policy Engine](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207.pdf)
- [NIST SP 800-207A — ZTA Multi-Cloud](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-207A.pdf)
- [ISO/IEC 30107-3:2023 — Biometric Presentation Attack Detection](https://www.iso.org/standard/79520.html)
- [Microsoft Entra Conditional Access — Device Compliance + Named Locations](https://learn.microsoft.com/en-us/entra/identity/conditional-access/)
- [OpenID CAEP — Continuous Access Evaluation Protocol](https://openid.net/specs/openid-caep-1_0.html)
- [Okta Adaptive MFA — Risk Signals and Context](https://www.okta.com/products/adaptive-multi-factor-authentication/)

---

*SKULL · SBOS · SBOS-ROLTEMPLATE-v6_0 · Junio 2026 · Alineado con bAuth v2.0*
*Reemplaza: SBOS-ROLTEMPLATE-v5_0 (Abril 2026)*
*Todos los campos validados con bAuth PrivilegeEngine v2.0*
*Documentos compañeros: BAUTH-CATALOGO-ROLES-EMPRESARIALES.md v2.0 (368 roles, 66 plantillas) · BAUTH-CADENAS-JERARQUIA.md v1.1 (186 aristas) · Authentication_Framework.json v3.0.0 · Policies_Authentication_Framework_v4.json*
*Estándares: ANSI/INCITS 359-2004 · NIST SP 800-63B Rev.4 (2024) · NIST SP 800-53 Rev.5 · ISO/IEC 27001:2022 · ISO 9001:2015 · ISO/IEC 24760-2:2025 · PCI-DSS v4.0 · OASIS XACML 3.0 · FIDO2/WebAuthn W3C · RFC 9470 Step-Up*
