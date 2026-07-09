# BAUTH-USERTEMPLATE-SECCIONES.md — UserTemplate Definitivo v6.0

**Versión:** 6.0 · **Fecha:** 2026-06-25 · **Autor:** sbos-coordinador
**Fuentes:** `SBOS-USERTEMPLATE-v5_0.md` · SCIM 2.0 RFC 7643/7644 · Okta Universal Directory (31 attrs)
  · Keycloak 26.x User Profile · NIST SP 800-63B-4 Final (2025) · ISO/IEC 24760-2:2025
  · FIDO2/WebAuthn Level 3 · OIDC Core 1.0 · GDPR Art.9/Art.7
**Evaluado contra:** Okta (31 base + custom types) · Keycloak (declarative profile + managed/unmanaged)
  · SCIM 2.0 Enterprise Extension · Auth0 FGA · Entra ID · SailPoint IIQ
**DDL:** 177 tablas, 0 errores · Cada sección mapea a tablas específicas

---

## PRINCIPIO ABSOLUTO

> **El UserTemplate es el contrato que define QUIÉN ES y QUÉ TIENE este usuario concreto.**
> Los permisos NO viven aquí — viven en el RolTemplate asignado.
> bAuth → RolTemplate → UserTemplate. El Rol define autoridad. El User define identidad.

| Dimensión | UserTemplate | RolTemplate |
|-----------|-------------|-------------|
| **Pregunta** | ¿QUIÉN es este usuario? | ¿QUÉ puede hacer este tipo de rol? |
| **Permisos** | Hereda del RolTemplate asignado | Define los permisos |
| **Autenticación** | Registra qué métodos TIENE disponibles | Define qué métodos son REQUERIDOS |
| **Horario** | Puede tener excepciones individuales | Define el horario base del rol |
| **Biometría** | Almacena el hash biométrico del individuo | Define la política de enrollment |
| **Sincroniza en KC** | User record, credenciales, atributos | Auth Flows, Session Settings, atributos del rol |
| **Sincroniza en Tryton** | `res.user`, `company.employee`, empresa activa | Grupos, `ir.model.access`, Button Rules |

---

## SECCIÓN 0 — `identity` — IDENTIDAD Y METADATOS

**Dominio:** USER · **Estándar:** SCIM 2.0 RFC 7643 §4.1 · ISO/IEC 24760-1 §5 · OIDC Core 1.0 · NIST SP 800-63B §4
**DDL:** `idn_user_template` (17 columnas) · `idn_tenant` · `org_empresa` · `org_sucursal`

```json
{
  "identity": {
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "external_id": "EMP789456",
    "username": "maria.garcia",
    "display_name": "María García López",
    "nickname": "Mari",
    "honorific_prefix": "Lic.",
    "honorific_suffix": "MBA",
    "profile_url": "https://sbos.app/users/maria.garcia",
    "locale": "es-BO",
    "zoneinfo": "America/La_Paz",
    "preferred_language": "es",

    "tenant_id": "empresa-acme",
    "empresa_id": "NIT-1234567890",
    "sucursal_id": "skull-central",
    "pos_logico": "POS-23",
    "realm_kc": "empresa-acme",
    "namespace_k8s": "tenant-acme",

    "version": "1.1.0",
    "status": "ACTIVE",
    "account_type": "HUMAN",
    "user_type": "EMPLOYEE",

    "lifecycle": {
      "created_at": "2026-01-15T08:00:00Z",
      "activated_at": "2026-01-15T08:30:00Z",
      "status_changed_at": "2026-01-15T08:30:00Z",
      "termination_date": null,
      "termination_reason": null,
      "offboarding_status": null,
      "purge_after": null
    },

    "federation": {
      "federated_idp": null,
      "federated_user_id": null,
      "federated_username": null,
      "identity_provider": "keycloak",
      "brokering_enabled": false
    },

    "digital_signature": {
      "signature": "base64_EdDSA",
      "algorithm": "EdDSA_Ed25519",
      "post_quantum_planned": "CRYSTALS-Dilithium",
      "certificate_thumbprint": "sha256:abc123...",
      "timestamp": "2026-01-15T08:00:00Z",
      "validity": {
        "not_before": "2026-01-15T00:00:00Z",
        "not_after": "2027-01-15T23:59:59Z"
      }
    },

    "audit_trail": {
      "created_by": "ADMIN.SISTEMA",
      "updated_by": "HR.LAURA.MENDOZA",
      "updated_at": "2026-06-20T14:00:00Z",
      "change_history": [
        {
          "version": "1.1.0",
          "date": "2026-06-20T14:00:00Z",
          "changed_by": "HR.LAURA.MENDOZA",
          "changes": ["Actualización de dirección", "Nuevo teléfono móvil"],
          "security_impact": "LOW"
        }
      ]
    }
  }
}
```

---

## SECCIÓN 1 — `personal_info` — INFORMACIÓN PERSONAL (PII · CONFIDENTIAL)

**Dominio:** USER · **Estándar:** SCIM 2.0 RFC 7643 §4.1.2 · OIDC Core claims · ISO/IEC 5218 (gender)
  · GDPR Art.9 (sensitive data) · ICAO Doc 9303 (travel documents)
**DDL:** `idn_user_template.template` (JSONB) · `menu_context` (gender, marital_status, id_document_type, nationality)

```json
{
  "personal_info": {
    "_classification": "CONFIDENTIAL",
    "_access_control": {
      "full_access_roles": ["ROL-ORG-CHRO", "ROL-SYS-ADMIN-SEGURIDAD"],
      "masked_access_roles": ["ROL-ORG-GER-RRHH"],
      "restricted_fields": ["national_id", "birth_date", "bank_account"],
      "gdpr_sensitive_fields": ["gender", "nationality", "biometric_data", "health_info"]
    },

    "name": {
      "given_name": "María",
      "middle_name": "Elena",
      "family_name": "García",
      "second_family_name": "López",
      "full_name": "María Elena García López",
      "formatted_name": "Lic. María García López, MBA",
      "initials": "MEGL",
      "previous_names": ["María Elena López García"]
    },

    "demographics": {
      "birth_date": "1985-06-15",
      "gender": "F",
      "nationality": "BOL",
      "nationality_secondary": null,
      "ethnicity": null,
      "religion": null,
      "marital_status": "MARRIED",
      "dependents_count": 2,
      "military_status": null
    },

    "identification": {
      "primary_document": {
        "type": "DNI",
        "number": "****5678Z",
        "issue_date": "2015-03-10",
        "expiry_date": "2025-03-10",
        "issuing_country": "BO",
        "issuing_authority": "SEGIP",
        "verified": true,
        "verified_at": "2026-01-15T09:00:00Z",
        "verified_by": "HR.VERIFICATION",
        "hashed_number": "sha256:abc..."
      },
      "secondary_documents": [
        {
          "type": "PASSPORT",
          "number": "****8901B",
          "issue_date": "2023-06-01",
          "expiry_date": "2033-06-01",
          "issuing_country": "BO",
          "verified": true
        }
      ],
      "tax_identifiers": [
        {
          "type": "NIT",
          "value": "1234567890",
          "issuing_country": "BO"
        }
      ],
      "social_identifiers": [
        {
          "type": "SSN",
          "value": "***-**-1234",
          "issuing_country": "US"
        }
      ]
    },

    "contact": {
      "emails": [
        {
          "address": "maria.garcia@empresa.com",
          "display": "María García (Trabajo)",
          "type": "work",
          "is_primary": true,
          "verified": true,
          "verified_at": "2026-01-15T08:30:00Z",
          "verification_method": "email_link",
          "purpose": ["notifications", "account_recovery", "security_alerts"]
        },
        {
          "address": "maria.garcia@gmail.com",
          "display": "María (Personal)",
          "type": "personal",
          "is_primary": false,
          "verified": true,
          "verified_at": "2026-01-15T09:00:00Z",
          "verification_method": "email_link",
          "purpose": ["account_recovery"]
        }
      ],
      "phones": [
        {
          "number": "+591 70012345",
          "display": "iPhone 15 (Principal)",
          "type": "mobile",
          "carrier": "Entel",
          "is_primary": true,
          "verified": true,
          "verified_at": "2026-01-15T09:30:00Z",
          "verification_method": "sms_code",
          "country_code": "BO",
          "purpose": ["sms_otp", "2fa", "emergency", "whatsapp"],
          "capabilities": ["voice", "sms", "data", "whatsapp", "telegram"]
        },
        {
          "number": "+591 22345678",
          "display": "Oficina Piso 4",
          "type": "office",
          "is_primary": false,
          "verified": true,
          "country_code": "BO",
          "purpose": ["voice"]
        }
      ],
      "ims": [
        {
          "type": "whatsapp",
          "value": "+591 70012345",
          "is_primary": true,
          "verified": true
        },
        {
          "type": "telegram",
          "value": "@maria_garcia",
          "is_primary": false,
          "verified": false
        }
      ],
      "websites": [
        {
          "url": "https://linkedin.com/in/mariagarcia",
          "type": "linkedin",
          "verified": true
        }
      ]
    },

    "addresses": [
      {
        "type": "work",
        "street": "Av. Camacho 1234, Piso 4",
        "city": "La Paz",
        "state": "La Paz",
        "country": "BO",
        "postal_code": "0000",
        "coordinates": {"latitude": -16.5000, "longitude": -68.1193, "accuracy_meters": 100},
        "geo_fence_id": "uuid-fence-central",
        "is_primary": true,
        "verified": true,
        "verified_at": "2026-01-15T09:00:00Z"
      },
      {
        "type": "home",
        "street": "Calle 15, No 234, Zona Sur",
        "city": "La Paz",
        "state": "La Paz",
        "country": "BO",
        "postal_code": "0000",
        "coordinates": {"latitude": -16.5300, "longitude": -68.1000, "accuracy_meters": 50},
        "is_primary": false,
        "verified": false
      }
    ],

    "emergency_contacts": [
      {
        "name": "Juan García López",
        "relationship": "spouse",
        "phone": "+591 70098765",
        "phone_alt": "+591 22345679",
        "email": "juan.garcia@email.com",
        "address": "Calle 15, No 234, Zona Sur, La Paz",
        "notification_channels": ["phone", "whatsapp"],
        "priority": 1,
        "can_pickup_children": true,
        "verified": true
      },
      {
        "name": "Elena López de García",
        "relationship": "mother",
        "phone": "+591 70011223",
        "priority": 2,
        "can_pickup_children": true,
        "verified": false
      }
    ],

    "health_info": {
      "blood_type": "O+",
      "allergies": ["Penicilina"],
      "medical_conditions": [],
      "disability_status": null,
      "disability_accommodations": [],
      "physician_name": "Dr. Carlos Mendoza",
      "physician_phone": "+591 22456789",
      "_classification": "RESTRICTED",
      "_access_roles": ["ROL-ORG-CHRO"]
    },

    "biometric_data": {
      "face_photo_url": "https://storage.sbos.app/photos/maria_garcia.jpg",
      "face_photo_hash": "sha256:def...",
      "face_photo_updated_at": "2026-01-15T08:00:00Z",
      "_classification": "RESTRICTED",
      "_gdpr_basis": "explicit_consent",
      "_consent_id": "uuid-consent-biometric"
    }
  }
}
```

---

## SECCIÓN 2 — `professional_info` — INFORMACIÓN PROFESIONAL

**Dominio:** USER/ORG · **Estándar:** SCIM 2.0 Enterprise User Extension RFC 7643 §4.3 · ISO 9001 §3.2.4
**DDL:** `org_empresa` · `org_sucursal` · `org_pos_logico` · `fis_location` · `menu_context`

```json
{
  "professional_info": {
    "employee_code": "EMP789456",
    "employee_type": "FULL_TIME",
    "employment_status": "ACTIVE",

    "job": {
      "title": "Gerente Regional de Ventas Norte",
      "title_en": "Regional Sales Manager North",
      "job_family": "Sales",
      "job_level": "M2",
      "job_code": "SALES-MGR-REG",
      "job_description": "Responsable de operaciones comerciales en la región norte con equipo de 10 vendedores.",
      "fte_ratio": 1.0,
      "flsa_status": "EXEMPT"
    },

    "organization": {
      "department": "Ventas",
      "division": "Comercial",
      "cost_center": "VEN-NORTE",
      "business_unit": "LATAM-BOL",
      "legal_entity": "ACME Bolivia SRL",
      "profit_center": "PC-NORTE-001",
      "location_code": "LPZ-HQ"
    },

    "reporting_line": {
      "manager_uuid": "uuid-carlos-ruiz",
      "manager_username": "carlos.ruiz",
      "manager_display_name": "Carlos Ruiz, Director Comercial",
      "manager_email": "carlos.ruiz@empresa.com",
      "reports_to_chain": [
        {"uuid": "uuid-carlos-ruiz", "role": "DIRECTOR_COMERCIAL", "level": 1},
        {"uuid": "uuid-ana-flores", "role": "CEO", "level": 2}
      ],
      "direct_reports_count": 10,
      "direct_reports": [
        {"uuid": "uuid-rep-001", "username": "pedro.mendoza", "display_name": "Pedro Mendoza"},
        {"uuid": "uuid-rep-002", "username": "lucia.torres", "display_name": "Lucía Torres"}
      ],
      "dotted_line_manager": null
    },

    "employment_details": {
      "hire_date": "2024-01-15",
      "original_hire_date": "2024-01-15",
      "seniority_date": "2024-01-15",
      "probation_end_date": "2024-04-15",
      "termination_date": null,
      "termination_reason": null,
      "last_working_day": null,
      "notice_period_days": 30,
      "contract_type": "INDEFINITE",
      "contract_end_date": null
    },

    "compensation": {
      "salary_currency": "BOB",
      "salary_amount": 15000,
      "salary_frequency": "MONTHLY",
      "overtime_eligible": false,
      "bonus_eligible": true,
      "bonus_target_pct": 20,
      "_classification": "RESTRICTED",
      "_access_roles": ["ROL-ORG-CHRO", "ROL-ORG-CFO"]
    },

    "office_location": {
      "building": "HQ",
      "building_code": "LPZ-HQ-001",
      "floor": 4,
      "wing": "NORTE",
      "desk": "4F-123",
      "desk_phone": "+591 22345678",
      "zone_id": "PHY_ZONE_VENTAS",
      "fis_location_id": "uuid-fis-ventas-p4"
    },

    "schedule": {
      "assigned_schedule_id": "uuid-oficina",
      "schedule_name": "Horario Oficina",
      "timezone": "America/La_Paz",
      "work_days": ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"],
      "standard_hours_per_week": 40,
      "flexible_hours": true,
      "remote_work_allowed": true,
      "remote_work_days_per_week": 1
    },

    "union_membership": {
      "union_name": null,
      "union_id": null,
      "collective_bargaining_applies": false
    },

    "certifications": [
      {
        "id": "SALES_CERT_A",
        "name": "Certificación de Ventas Nivel A",
        "issued_by": "Instituto Nacional de Ventas",
        "issued_at": "2023-06-01",
        "expires_at": "2025-06-01",
        "verified": true,
        "credential_url": "https://institutoventas.org/cert/SALES_CERT_A/EMP789456",
        "required_for_role": true
      },
      {
        "id": "MANAGEMENT_CERT_B",
        "name": "Certificación en Gestión de Equipos Nivel B",
        "issued_by": "Escuela de Negocios La Paz",
        "issued_at": "2024-09-01",
        "expires_at": "2027-09-01",
        "verified": true,
        "required_for_role": true
      }
    ],

    "education": [
      {
        "degree": "Licenciatura en Administración de Empresas",
        "institution": "Universidad Mayor de San Andrés",
        "graduation_year": 2008,
        "verified": true
      },
      {
        "degree": "MBA — Maestría en Dirección Comercial",
        "institution": "Escuela de Negocios La Paz",
        "graduation_year": 2015,
        "verified": true
      }
    ],

    "skills": [
      {"name": "Gestión de equipos comerciales", "level": "EXPERT", "years_experience": 8},
      {"name": "CRM Salesforce", "level": "ADVANCED", "years_experience": 5},
      {"name": "Análisis de datos de ventas", "level": "ADVANCED", "years_experience": 6},
      {"name": "Inglés de negocios", "level": "ADVANCED", "certification": "TOEFL 95"},
      {"name": "Negociación", "level": "EXPERT", "years_experience": 10}
    ]
  }
}
```

---

## SECCIÓN 3 — `roles_assignments` — ROLES ASIGNADOS

**Dominio:** D1 · **Estándar:** ANSI/INCITS 359-2004 §4.2 · NIST SP 800-53 AC-2 · COBIT BAI09
**DDL:** `idn_user_role` · `idn_role_template` · `idn_role_closure` · `dlg_delegation` · `emergency_override_policy`

```json
{
  "roles_assignments": {
    "active_roles": [
      {
        "assignment_id": "uuid-assign-001",
        "role_id": "RGV-001",
        "role_name": "Gerente Regional de Ventas",
        "role_type": "TYPE-GERENCIA-MEDIA",
        "hierarchy_level": 2,
        "tier": "BIZ_N3",
        "assigned_at": "2026-01-15T08:00:00Z",
        "assigned_by": "ADMIN.SISTEMA",
        "approved_by": "DIRECTOR_VENTAS",
        "valid_from": "2026-01-15T00:00:00Z",
        "valid_until": null,
        "status": "ACTIVE",
        "assignment_reason": "Promoción a Gerente Regional Norte — Resolución DIR-2026-001",
        "bitmask_effective": "0x0000010900030052",
        "is_primary_role": true,
        "can_be_delegated": true,
        "context_overrides": {
          "temporal_exceptions": [
            {
              "exception_id": "uuid-temp-001",
              "date": "2026-06-20",
              "allowed_until": "22:00",
              "approved_by": "DIRECTOR_VENTAS",
              "approved_at": "2026-06-19T15:00:00Z",
              "reason": "Cierre trimestral — procesamiento de facturación pendiente",
              "audit_trail": true
            }
          ],
          "network_exceptions": [
            {
              "exception_id": "uuid-net-001",
              "cidr": "192.168.50.0/24",
              "reason": "Acceso desde oficina temporal proyecto Norte",
              "valid_from": "2026-06-01T00:00:00Z",
              "valid_until": "2026-07-01T00:00:00Z"
            }
          ],
          "geo_exceptions": [],
          "financial_overrides": [
            {
              "limit_type": "single_transaction",
              "new_limit": 15000,
              "reason": "Aprobación de compras urgentes durante ausencia del Director",
              "valid_from": "2026-06-20T00:00:00Z",
              "valid_until": "2026-06-25T00:00:00Z",
              "approved_by": "CFO",
              "step_up_required": true
            }
          ]
        }
      }
    ],

    "role_history": [
      {
        "assignment_id": "uuid-assign-000",
        "role_id": "VEN-VEN-NORTE-001",
        "role_name": "Vendedor Senior — Región Norte",
        "assigned_at": "2024-01-15T00:00:00Z",
        "removed_at": "2026-01-14T23:59:59Z",
        "assigned_by": "ADMIN.SISTEMA",
        "removed_by": "ADMIN.SISTEMA",
        "reason": "PROMOTION",
        "documentation": "Carta de Promoción EMP789456-2026",
        "was_effective": true
      }
    ],

    "delegations_received": [
      {
        "delegation_id": "DLG-2026-001",
        "delegated_from_uuid": "uuid-carlos-ruiz",
        "delegated_from_username": "carlos.ruiz",
        "from_role_id": "DGV-001",
        "from_role_name": "Director General de Ventas",
        "valid_from": "2026-03-15T00:00:00Z",
        "valid_until": "2026-03-30T23:59:59Z",
        "delegated_permissions": [
          "zone_logical/ventas:APPROVE",
          "zone_financial/ventas:APPROVE"
        ],
        "restricted_permissions": [
          "GOV_ADMIN_USERS",
          "zone_logical/reportes:CONFIGURE"
        ],
        "reason": "Vacaciones del Director General de Ventas",
        "approved_by": "DIRECTOR_VENTAS",
        "auto_revoke": true,
        "status": "EXPIRED",
        "used_count": 12,
        "last_used_at": "2026-03-29T16:30:00Z"
      }
    ],

    "delegations_given": [
      {
        "delegation_id": "DLG-2026-005",
        "delegated_to_uuid": "uuid-pedro-mendoza",
        "delegated_to_username": "pedro.mendoza",
        "role_id": "RGV-001",
        "valid_from": "2026-06-24T00:00:00Z",
        "valid_until": "2026-07-01T00:00:00Z",
        "reason": "Vacaciones de María García",
        "status": "ACTIVE"
      }
    ],

    "role_compliance": {
      "sod_conflicts_detected": [],
      "sod_conflicts_overridden": [],
      "last_sod_check_at": "2026-06-24T08:00:00Z",
      "compliant": true,
      "excessive_permissions_risk": "LOW",
      "unused_permissions_count": 3,
      "last_activity_review_at": "2026-06-01T10:00:00Z"
    }
  }
}
```

---

## SECCIÓN 4 — `keycloak_credentials` — CREDENCIALES DIGITALES

**Dominio:** D9 · **Estándar:** FIDO2/WebAuthn Level 3 · RFC 6238 (TOTP) · NIST SP 800-63B §5
  · OWASP ASVS V2 · RFC 9470 (Step-Up)
**DDL:** 46 tablas `ath_*`

```json
{
  "keycloak_credentials": {
    "_readonly": true,
    "_description": "Estado de credenciales sincronizado desde Keycloak vía Admin API. bAuth actualiza cada 60s.",

    "password": {
      "has_password": true,
      "password_last_changed": "2026-01-15T09:00:00Z",
      "password_expires_at": null,
      "password_strength_score": 87,
      "password_strength_feedback": ["Suficientemente larga", "Sin palabras comunes"],
      "hibp_screened": true,
      "hibp_screened_at": "2026-01-15T09:00:00Z",
      "hibp_compromised": false,
      "password_history_count": 5,
      "password_age_days": 161
    },

    "totp": {
      "has_totp": true,
      "devices": [
        {
          "credential_id": "kc-cred-totp-001",
          "device_name": "Google Authenticator — iPhone 15",
          "registered_at": "2026-01-15T09:30:00Z",
          "last_used_at": "2026-06-24T08:00:00Z",
          "algorithm": "SHA256",
          "digits": 6,
          "period_seconds": 30,
          "is_primary": true,
          "backup_codes_generated": true
        }
      ]
    },

    "webauthn": {
      "has_webauthn": true,
      "credentials": [
        {
          "credential_id": "kc-cred-wn-001",
          "device_name": "YubiKey 5 NFC",
          "type": "security_key",
          "transport": ["usb", "nfc"],
          "aaguid": "2fc0579f-8113-47ea-b116-bb5a8db9202a",
          "registered_at": "2026-01-15T10:00:00Z",
          "last_used_at": "2026-06-24T08:00:00Z",
          "attestation_verified": true,
          "attestation_type": "packed",
          "user_verification": "required",
          "resident_key": false,
          "backup_eligible": false,
          "backup_state": false,
          "is_primary": false,
          "is_device_bound": true
        },
        {
          "credential_id": "kc-cred-wn-002",
          "device_name": "MacBook Pro — Touch ID",
          "type": "platform_biometric",
          "transport": ["internal"],
          "aaguid": "adce0002-35bc-c60a-648b-0b25f1f05503",
          "registered_at": "2026-02-01T14:00:00Z",
          "last_used_at": "2026-06-24T08:00:00Z",
          "attestation_verified": true,
          "attestation_type": "none",
          "user_verification": "required",
          "resident_key": true,
          "backup_eligible": true,
          "backup_state": true,
          "is_primary": true,
          "is_device_bound": false,
          "synced_via": "icloud"
        }
      ]
    },

    "passkeys": {
      "has_passkey": false,
      "credentials": []
    },

    "smartcard_x509": {
      "has_x509_smartcard": false,
      "credentials": []
    },

    "federated": {
      "has_federated": false,
      "providers": []
    },

    "backup_codes": {
      "generated": true,
      "generated_at": "2026-01-15T09:00:00Z",
      "total_codes": 10,
      "remaining_codes": 8,
      "codes_used": 2,
      "exhausted_at": null,
      "hash_algorithm": "SHA-256"
    },

    "recovery": {
      "methods": [
        {
          "method_id": "uuid-rec-001",
          "type": "email",
          "value_hash": "sha256:ghi...",
          "verified": true,
          "verified_at": "2026-01-15T09:00:00Z",
          "is_primary": true
        },
        {
          "method_id": "uuid-rec-002",
          "type": "sms",
          "value_hash": "sha256:jkl...",
          "verified": true,
          "verified_at": "2026-01-15T09:30:00Z",
          "is_primary": false
        }
      ],
      "challenges": [
        {
          "challenge_id": "uuid-ch-001",
          "question_hash": "argon2id:...",
          "created_at": "2026-01-15T09:00:00Z"
        }
      ]
    },

    "credentials_compliance": {
      "covers_required_methods": true,
      "missing_methods": [],
      "compliance_checked_at": "2026-06-24T08:00:00Z",
      "compliant": true,
      "required_by_role": ["PASSWORD", "TOTP", "WEBAUTHN_PWDLESS"],
      "available_to_user": ["PASSWORD", "TOTP", "WEBAUTHN_PWDLESS", "BACKUP_CODES", "EMAIL_RECOVERY"],
      "gap_analysis": {
        "role_requires": ["PASSWORD", "TOTP", "WEBAUTHN_PWDLESS"],
        "user_has": ["PASSWORD", "TOTP", "WEBAUTHN_PWDLESS"],
        "gap": []
      }
    },

    "login_activity": {
      "last_successful_login_at": "2026-06-24T08:00:00Z",
      "last_successful_login_ip": "10.0.1.45",
      "last_successful_login_device": "uuid-iphone-15",
      "last_failed_login_at": null,
      "failed_login_attempts_24h": 0,
      "total_logins": 1245,
      "account_locked": false,
      "locked_until": null
    },

    "kc_integration": {
      "kc_user_id": "kc-user-uuid-maria-garcia",
      "kc_realm": "empresa-acme",
      "kc_groups": ["/Empresa-ACME/Ventas/Norte", "/Empresa-ACME/Gerentes"],
      "kc_composite_roles": ["RGV_001"],
      "kc_realm_roles": ["SALES_VIEW", "SALES_WRITE", "SALES_APPROVE_10K", "REPORTS_REGIONAL"],
      "kc_client_roles": {},
      "kc_required_actions": [],
      "kc_email_verified": true,
      "kc_created_at": "2026-01-15T08:00:00Z"
    }
  }
}
```

---

## SECCIÓN 5 — `physical_credentials` — CREDENCIALES FÍSICAS

**Dominio:** D2 · **Estándar:** SIA OSDP v2.2.3 · ISO/IEC 14443 · ISO/IEC 30107-3 · NIST SP 800-116
**DDL:** `fis_device` · `fis_access_zone` · `fis_zone_member` · `fis_zone_method_requirement` · `ath_consent`

```json
{
  "physical_credentials": {
    "smart_cards": [
      {
        "id": "SC-LPZ-001",
        "type": "NFC_MIFARE_DESFIRE",
        "standard": "ISO 14443-A AES-128",
        "chip_type": "DESFire_EV3",
        "card_number": "****4567",
        "facility_code": "LPZ-001",
        "issue_level": 2,
        "encryption_key_version": 3,
        "status": "ACTIVE",
        "issued_at": "2026-01-15T08:00:00Z",
        "expires_at": "2027-01-15T00:00:00Z",
        "last_used_at": "2026-06-24T08:10:00Z",
        "last_used_zone": "PHY_ZONE_VENTAS",
        "last_used_reader": "AP-VENTAS-01",
        "usage_count_today": 2,
        "anti_passback_status": "IN",
        "lost_reported": false
      }
    ],

    "mobile_credentials": [
      {
        "id": "MOB-LPZ-001",
        "type": "QR_DYNAMIC",
        "device_id": "uuid-iphone-15",
        "device_name": "iPhone 15 Pro",
        "registered_at": "2026-01-15T08:00:00Z",
        "last_used_at": "2026-06-24T08:10:00Z",
        "last_used_zone": "PHY_ZONE_VENTAS",
        "ttl_seconds": 30,
        "algorithm": "HMAC-SHA256",
        "status": "ACTIVE",
        "can_unlock_doors": true,
        "can_activate_devices": false
      }
    ],

    "biometric_enrollments": [
      {
        "id": "BIO-LPZ-001",
        "type": "FINGERPRINT",
        "standard": "ISO/IEC 19794-2",
        "finger": 2,
        "hand": "RIGHT",
        "template_hash": "argon2id:abc...",
        "argon2_params": {"time_cost": 3, "memory_mb": 64, "parallelism": 2},
        "enrolled_at": "2026-01-15T10:00:00Z",
        "enrolled_by": "SEC.ADMIN",
        "enrollment_station": "PHY_ZONE_CAJA",
        "liveness_verified": true,
        "liveness_method": "PASSIVE",
        "fmr_threshold": "1:10000",
        "consent_given": true,
        "consent_id": "uuid-consent-biometric",
        "status": "ACTIVE",
        "revoked_at": null
      }
    ],

    "access_history": [
      {
        "timestamp": "2026-06-24T08:10:00Z",
        "zone_id": "PHY_ZONE_VENTAS",
        "access_point": "AP-VENTAS-01",
        "method_used": "NFC_MIFARE_DESFIRE",
        "result": "ALLOW",
        "ctx_id": "active-ctx-uuid"
      }
    ],

    "physical_restrictions": {
      "max_security_zone": 3,
      "requires_escort_in": ["PHY_ROOM_SERVIDOR"],
      "restricted_zones": ["PHY_ROOM_SERVIDOR", "PHY_ZONE_BOVEDA"],
      "allowed_schedules": ["business_hours"],
      "allowed_access_methods": ["NFC_MIFARE_DESFIRE", "QR_DYNAMIC", "FINGERPRINT"]
    }
  }
}
```

---

## SECCIÓN 6 — `device_registry` — DISPOSITIVOS VINCULADOS

**Dominio:** D5/D7 · **Estándar:** FIDO2 CTAP 2.2 · Play Integrity · App Attest · WebAuthn Level 3
**DDL:** `user_client_device` · `net_device` · `device_attestation_log` · `mobile_heartbeat_log` · `push_token_registry` · `certificate_pin_config`

```json
{
  "device_registry": {
    "primary_device": {
      "device_id": "uuid-iphone-15",
      "device_name": "iPhone 15 Pro",
      "device_category": "MOBILE",
      "platform": "ios",
      "os_version": "18.3",
      "app_version": "1.2.3",
      "platform_authenticator": "FACE_ID",
      "passkey_type": "synced_icloud",
      "secure_enclave": true,
      "tpm_version": null,
      "aaguid": "adce0002-35bc-c60a-648b-0b25f1f05503",
      "trust_score": 98,
      "attestation_provider": "app_attest",
      "last_attestation_at": "2026-06-24T08:00:00Z",
      "last_attestation_score": 98,
      "last_seen_at": "2026-06-24T14:30:00Z",
      "heartbeat_interval_seconds": 30,
      "push_token_registered": true,
      "push_provider": "APNS",
      "is_primary": true,
      "status": "ACTIVE",
      "battery_pct": 72,
      "network_type": "WIFI",
      "last_known_location": {"lat": -16.5000, "lon": -68.1193}
    },
    "secondary_devices": [
      {
        "device_id": "uuid-macbook",
        "device_name": "MacBook Pro 16 M3",
        "device_category": "DESKTOP",
        "platform": "macos",
        "os_version": "15.2",
        "app_version": "1.2.3",
        "platform_authenticator": "TOUCH_ID",
        "passkey_type": "device_bound",
        "secure_enclave": true,
        "tpm_version": null,
        "trust_score": 95,
        "attestation_provider": "app_attest",
        "last_attestation_at": "2026-06-24T08:05:00Z",
        "last_seen_at": "2026-06-24T14:30:00Z",
        "is_primary": false,
        "status": "ACTIVE",
        "battery_pct": 85,
        "network_type": "WIFI"
      }
    ],

    "device_trust_summary": {
      "active_devices_count": 2,
      "compromised_devices_count": 0,
      "lost_devices_count": 0,
      "average_trust_score": 96.5,
      "lowest_trust_device": "uuid-macbook (95)",
      "any_jailbreak_detected": false,
      "any_root_detected": false
    }
  }
}
```

---

## SECCIÓN 7 — `session_state` — ESTADO DE SESIÓN

**Dominio:** D8 · **Estándar:** SBOS-049 · W3C Trace Context · NIST SP 800-63B-4 §7 · OpenID CAEP 1.0
**DDL:** `ses_context` · `ses_context_switch` · `ses_superuser_context` · `ses_risk_policy` · `ses_caep_config`
  · `ctx_transfer_log` · `qr_challenge_registry`

```json
{
  "session_state": {
    "current_ctx_id": "active-ctx-uuid",
    "dctx_id": "device-ctx-uuid",
    "context_actual": "skull/acme/lapaz/pos23",
    "bos_contexts": ["skull/acme/lapaz", "skull/acme/central", "skull/acme/norte"],
    "ruta_canonica": "/dist/skull/emp/acme/suc/lapaz/user/maria.garcia/pos/pos23",

    "active_sessions": [
      {
        "ctx_id": "active-ctx-uuid",
        "session_type": "WORK",
        "device_id": "uuid-iphone-15",
        "started_at": "2026-06-24T08:00:00Z",
        "expires_at": "2026-06-24T16:00:00Z",
        "remaining_seconds": 5400,
        "loa_current": 2,
        "loa_min_required": 2,
        "bitmask_hex": "0x0000010900030052",
        "traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
        "tracestate": "sbos=tenant:acme;empresa:nit-1234567890;sucursal:lapaz",
        "network_ip": "10.0.1.45",
        "network_type": "WIFI",
        "device_mac": "aa:bb:cc:dd:ee:ff",
        "risk_score_current": 12,
        "risk_level": "LOW",
        "caep_events_subscribed": ["session-revoked", "assurance-level-change", "credential-change"]
      }
    ],

    "session_history": [
      {
        "ctx_id": "prev-ctx-uuid-001",
        "started_at": "2026-06-23T08:00:00Z",
        "ended_at": "2026-06-23T18:00:00Z",
        "end_reason": "END_SHIFT",
        "duration_seconds": 36000,
        "transfers": [
          {
            "transfer_id": "uuid-xfer-001",
            "from_device": "uuid-iphone-15",
            "to_device": "CPU-045",
            "method": "QR",
            "timestamp": "2026-06-23T08:05:00Z",
            "result": "ALLOW"
          }
        ]
      }
    ],

    "context_switches": [
      {
        "switch_id": "uuid-sw-001",
        "from_ctx_id": "prev-ctx-uuid-001",
        "to_ctx_id": "active-ctx-uuid",
        "from_context": "skull/acme/central",
        "to_context": "skull/acme/lapaz",
        "motivo": "cambio_sucursal",
        "emitido_por": "usuario",
        "timestamp": "2026-06-24T08:00:00Z"
      }
    ],

    "emergency_overrides": [
      {
        "override_id": "uuid-ovr-001",
        "authorized_by": "carlos.ruiz",
        "reason": "Cierre trimestral urgente — procesamiento de facturación pendiente",
        "valid_from": "2026-06-20T18:00:00Z",
        "valid_until": "2026-06-20T22:00:00Z",
        "overrides_applied": ["temporal", "geo"],
        "status": "EXPIRED",
        "audit_completed": true
      }
    ],

    "session_compliance": {
      "max_sessions_allowed": 1,
      "concurrent_sessions": 1,
      "within_limit": true,
      "force_logout_on_end_shift": true,
      "reauth_required_at": "2026-06-24T12:00:00Z"
    }
  }
}
```

---

## SECCIÓN 8 — `location_profile` — PERFIL DE UBICACIÓN

**Dominio:** D6 · **Estándar:** NIST SP 800-53 PE-3 · Google BeyondCorp · OGC GeoFence
**DDL:** `geo_trust_tier` · `geo_fence` · `geo_location_log` · `geo_velocity_policy` · `geo_evaluation_log`

```json
{
  "location_profile": {
    "home_location": {
      "city": "La Paz",
      "state": "La Paz",
      "country": "BO",
      "coordinates": {"latitude": -16.5300, "longitude": -68.1000},
      "trust_tier": "LOW"
    },

    "work_location": {
      "city": "La Paz",
      "state": "La Paz",
      "country": "BO",
      "coordinates": {"latitude": -16.5000, "longitude": -68.1193},
      "trust_tier": "HIGH",
      "geo_fence_id": "uuid-fence-central",
      "geo_fence_status": "INSIDE"
    },

    "assigned_branches": [
      {"sucursal_id": "skull-central", "geo_fence_id": "uuid-fence-central", "is_primary": true},
      {"sucursal_id": "skull-norte", "geo_fence_id": "uuid-fence-norte", "is_primary": false}
    ],

    "allowed_countries": ["BO"],
    "blocked_countries": [],

    "current_location": {
      "point": {"latitude": -16.5000, "longitude": -68.1193},
      "accuracy_meters": 10,
      "source": "GPS",
      "recorded_at": "2026-06-24T14:30:00Z",
      "country": "BO",
      "city": "La Paz",
      "geo_fence_check": "INSIDE",
      "trust_tier_effective": "HIGH"
    },

    "location_history": [
      {
        "log_id": "uuid-loc-001",
        "point": {"latitude": -16.5300, "longitude": -68.1000},
        "source": "GPS",
        "accuracy_meters": 50,
        "country": "BO",
        "city": "La Paz",
        "recorded_at": "2026-06-24T07:45:00Z"
      },
      {
        "log_id": "uuid-loc-002",
        "point": {"latitude": -16.5000, "longitude": -68.1193},
        "source": "GPS",
        "accuracy_meters": 10,
        "country": "BO",
        "city": "La Paz",
        "recorded_at": "2026-06-24T08:00:00Z"
      }
    ],

    "velocity_checks": [
      {
        "evaluation_id": "uuid-vel-001",
        "from_point": {"latitude": -16.5300, "longitude": -68.1000},
        "to_point": {"latitude": -16.5000, "longitude": -68.1193},
        "distance_km": 3.8,
        "time_minutes": 15,
        "velocity_kmh": 15.2,
        "max_allowed_kmh": 900,
        "result": "ALLOW",
        "evaluated_at": "2026-06-24T08:00:00Z"
      }
    ],

    "velocity_violations": [],

    "location_compliance": {
      "geo_fence_compliant": true,
      "country_allowed": true,
      "trust_tier_sufficient": true,
      "last_evaluation_at": "2026-06-24T08:00:00Z",
      "compliant": true
    }
  }
}
```

---

## SECCIÓN 9 — `temporal_profile` — PERFIL TEMPORAL

**Dominio:** D4 · **Estándar:** RFC 5545 iCalendar · GTRBAC · ISO 8601 · Ley General del Trabajo Bolivia
**DDL:** `cal_schedule` · `cal_calendar` · `cal_holiday` · `cal_overtime_policy` · `cal_break_policy` · `cal_event` · `cal_fiscal_year`

```json
{
  "temporal_profile": {
    "assigned_schedule_id": "uuid-oficina",
    "schedule_name": "Horario Oficina",
    "timezone": "America/La_Paz",

    "work_schedule": {
      "days": [
        {"day": "MONDAY",    "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "TUESDAY",   "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "WEDNESDAY", "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "THURSDAY",  "shifts": [{"start": "08:00", "end": "12:00"}, {"start": "14:00", "end": "18:00"}]},
        {"day": "FRIDAY",    "shifts": [{"start": "08:00", "end": "15:00"}]}
      ],
      "total_hours_per_week": 40
    },

    "breaks": {
      "lunch": {"required": true, "duration_minutes": 60, "window_start": "12:00", "window_end": "14:00"},
      "short_breaks": {"count": 2, "duration_minutes": 15, "auto_logout": false, "session_pause": true}
    },

    "overtime": {
      "authorized": false,
      "max_daily_hours": 4,
      "max_weekly_hours": 20,
      "rate_multiplier": 1.5,
      "night_shift_rate": 2.0,
      "holiday_rate": 2.5,
      "requires_approval": true,
      "approver_roles": ["ROL-ORG-GER-RRHH"],
      "overtime_hours_today": 0,
      "overtime_hours_this_week": 0
    },

    "holidays": {
      "calendar_id": "uuid-bolivia-holidays",
      "behavior": "BLOCKED",
      "upcoming_holidays": [
        {"date": "2026-08-06", "name": "Día de la Independencia", "country": "BO"}
      ]
    },

    "temporal_exceptions": [
      {
        "exception_id": "uuid-temp-001",
        "date": "2026-06-20",
        "allowed_until": "22:00",
        "approved_by": "DIRECTOR_VENTAS",
        "reason": "Cierre trimestral — procesamiento de facturación pendiente",
        "override_type": "EXTENDED_HOURS",
        "status": "EXPIRED"
      }
    ],

    "attendance_today": {
      "clock_in": "2026-06-24T08:00:00Z",
      "expected_clock_out": "2026-06-24T18:00:00Z",
      "lunch_start": "2026-06-24T12:30:00Z",
      "lunch_end": "2026-06-24T13:30:00Z",
      "break_1_start": "2026-06-24T10:30:00Z",
      "break_1_end": "2026-06-24T10:45:00Z",
      "hours_worked_so_far": 5.5,
      "status": "PRESENT"
    },

    "attendance_history": [
      {"date": "2026-06-23", "status": "PRESENT", "hours_worked": 9.0, "overtime": 0, "late_minutes": 0},
      {"date": "2026-06-22", "status": "PRESENT", "hours_worked": 8.5, "overtime": 0, "late_minutes": 5}
    ],

    "fiscal_calendar": {
      "current_fiscal_year": 2026,
      "fiscal_period": "JUNIO",
      "tax_deadlines": []
    }
  }
}
```

---

## SECCIÓN 10 — `network_profile` — PERFIL DE RED

**Dominio:** D7 · **Estándar:** NIST SP 800-207 ZTA · CISA ZTMM v2 · IEEE 802.1X
**DDL:** `idn_tenant_network` · `net_device` · `net_ztna_policy` · `certificate_pin_config`

```json
{
  "network_profile": {
    "allowed_cidrs": ["10.0.1.0/24", "10.0.2.0/24"],
    "vpn_required": false,
    "mtls_required": false,
    "device_trust_min_score": 70,

    "current_network": {
      "ip_address": "10.0.1.45",
      "mac_address": "aa:bb:cc:dd:ee:ff",
      "network_type": "WIFI",
      "ssid": "CORP-SBOS",
      "vlan": 10,
      "network_zone": "CORPORATE",
      "trust_tier": "HIGH",
      "verified_at": "2026-06-24T08:00:00Z"
    },

    "network_history": [
      {"ip_address": "192.168.1.100", "type": "WIFI", "ssid": "HomeNetwork", "zone": "HOME", "date": "2026-06-23T18:30:00Z"},
      {"ip_address": "10.0.1.45", "type": "WIFI", "ssid": "CORP-SBOS", "zone": "CORPORATE", "date": "2026-06-24T08:00:00Z"}
    ],

    "vpn": {
      "configured": false,
      "provider": "WIREGUARD",
      "last_connected_at": null,
      "required_for_remote": true
    },

    "ztna": {
      "default_action": "DENY",
      "allowed_services": ["tryton", "keycloak", "superset", "espocrm", "mattermost"],
      "just_in_time_access": false,
      "microsegmentation_enabled": false
    },

    "certificate_pinning": {
      "enabled": true,
      "pinned_hosts": ["api.sbos.app", "auth.sbos.app"],
      "last_pin_rotation": "2026-06-01T00:00:00Z"
    }
  }
}
```

---

## SECCIÓN 11 — `audit_profile` — PERFIL DE AUDITORÍA

**Dominio:** D11 · **Estándar:** ISO 27001 A.8.15 · PCI DSS 10.3.2 · NIST SP 800-53 AU-2/AU-3 · SOX §404
**DDL:** `aud_event` · `aud_review` · `aud_ghost_account` · `aud_policy_change` · `aud_policy_version` · `aud_compliance_map`

```json
{
  "audit_profile": {
    "audit_level": "basic",
    "retention_days": 2555,
    "hash_chain_required": false,

    "review_schedule": {
      "frequency": "QUARTERLY",
      "last_review_date": "2026-06-01",
      "next_review_date": "2026-09-01",
      "reviewer": "ROL-ORG-GER-VENT",
      "sla_days": 14,
      "escalation_role": "ROL-ORG-CCO"
    },

    "significant_events": [
      {"event_type": "ROLE_CHANGE", "date": "2026-01-15", "description": "Promoción a Gerente Regional Norte"},
      {"event_type": "DELEGATION_RECEIVED", "date": "2026-03-15", "description": "Delegación temporal de DGV durante vacaciones"},
      {"event_type": "TEMPORAL_OVERRIDE", "date": "2026-06-20", "description": "Acceso extendido hasta 22:00 por cierre trimestral"},
      {"event_type": "DELEGATION_GIVEN", "date": "2026-06-24", "description": "Delegación a Pedro Mendoza por vacaciones"}
    ],

    "event_summary": {
      "total_events_90d": 1245,
      "access_granted_90d": 1230,
      "access_denied_90d": 2,
      "auth_failures_90d": 0,
      "config_changes_90d": 3,
      "delegations_90d": 2,
      "privileged_operations_90d": 10
    },

    "compliance_status": {
      "iso_27001": {"applicable": true, "compliant": true, "last_audit": "2026-05-01"},
      "sox": {"applicable": false, "compliant": null},
      "pci_dss": {"applicable": false, "compliant": null},
      "gdpr": {"applicable": true, "pii_access": true, "legal_basis": "legitimate_interest", "compliant": true, "last_dpia": "2026-04-01"},
      "nist_800_53": {"applicable": true, "controls_applicable": ["AC-2","AC-3","AC-5","AU-2","AU-3","IA-2","IA-5"], "compliant": true}
    },

    "ghost_account_check": {
      "last_checked_at": "2026-06-24T02:00:00Z",
      "is_ghost": false,
      "days_since_last_login": 0,
      "kc_active_and_hr_active": true,
      "tryton_synced": true,
      "risk_score": 0
    }
  }
}
```

---

## SECCIÓN 12 — `external_services` — SERVICIOS EXTERNOS

**Dominio:** D5/D9 · **Estándar:** OIDC Core 1.0 · OAuth 2.1 BCP · SAML 2.0 · GDPR Art.7 (consent)
**DDL:** `idp_client` · `idp_client_policy` · `idp_token_config` · `ath_consent` · `external_session_registry`

```json
{
  "external_services": {
    "consented_apps": [
      {
        "client_id": "uuid-portal-facturas",
        "client_name": "Portal de Facturas ACME",
        "client_type": "oidc",
        "scopes_granted": ["openid", "profile", "email"],
        "consent_given_at": "2026-02-01T10:00:00Z",
        "consent_status": "granted",
        "consent_expires_at": null,
        "ip_address_at_consent": "10.0.1.45",
        "user_agent_at_consent": "Mozilla/5.0...",
        "can_withdraw": true,
        "data_shared": ["name", "email", "department", "job_title"],
        "purpose": "Autenticación para acceso al portal de facturas"
      },
      {
        "client_id": "uuid-app-delivery",
        "client_name": "App de Delivery Corporativa",
        "client_type": "oidc",
        "scopes_granted": ["openid", "profile"],
        "consent_given_at": "2026-03-15T14:00:00Z",
        "consent_status": "granted",
        "data_shared": ["name", "email"],
        "purpose": "Autenticación para app de pedidos de almuerzo"
      }
    ],

    "consent_withdrawn": [
      {
        "client_id": "uuid-old-app",
        "client_name": "App Legacy de RRHH",
        "withdrawn_at": "2026-05-01T09:00:00Z",
        "reason": "App descontinuada"
      }
    ],

    "active_external_sessions": [
      {
        "session_id": "uuid-ext-session-001",
        "client_id": "uuid-portal-facturas",
        "started_at": "2026-06-24T09:00:00Z",
        "expires_at": "2026-06-24T10:00:00Z",
        "scopes_active": ["openid", "profile", "email"],
        "id_token_jti": "jti-id-001",
        "access_token_jti": "jti-ac-001",
        "refresh_token_rotated": false
      }
    ],

    "token_activity": {
      "total_tokens_issued_30d": 45,
      "tokens_refreshed_30d": 30,
      "tokens_revoked_30d": 0,
      "average_session_duration_minutes": 45
    },

    "consent_audit": {
      "total_consents_active": 2,
      "total_consents_withdrawn": 1,
      "last_consent_change_at": "2026-05-01T09:00:00Z",
      "gdpr_consent_compliant": true
    }
  }
}
```

---

## SECCIÓN 13 — `compliance_profile` — PERFIL DE COMPLIANCE

**Dominio:** D11/D14 · **Estándar:** SOX §404 · COSO 2013 · ISO 27001 A.5.3 · NIST SP 800-53 AC-5
**DDL:** `fin_sod_rule` · `sod_validation_config` · `conflict_interest_policy` · `aud_compliance_map`

```json
{
  "compliance_profile": {
    "segregation_of_duties": {
      "active_conflicts": [],
      "conflicts_overridden": [],
      "last_sod_check_at": "2026-06-24T08:00:00Z",
      "compliant": true
    },

    "conflict_of_interest": {
      "declarations": [
        {
          "declaration_id": "uuid-decl-001",
          "type": "ANNUAL",
          "declared_at": "2026-01-01T00:00:00Z",
          "has_conflicts": false,
          "restricted_entities": [],
          "verification_method": "COMPLIANCE_REVIEW",
          "verified_by": "COMPLIANCE.OFFICER",
          "verified_at": "2026-01-15T00:00:00Z",
          "status": "VERIFIED",
          "next_declaration_due": "2027-01-01"
        }
      ],
      "family_relationships_in_company": [
        {
          "related_user_uuid": "uuid-juan-garcia",
          "related_username": "juan.garcia",
          "relationship": "spouse",
          "department": "TI",
          "has_financial_oversight": false,
          "has_approval_authority_over": false,
          "conflict_assessed": true,
          "conflict_mitigation": "NO_DIRECT_REPORTING"
        }
      ],
      "outside_interests": [],
      "compliant": true
    },

    "required_certifications": [
      {"cert_id": "SALES_CERT_A", "status": "EXPIRED", "expired_at": "2025-06-01", "critical_for_role": true},
      {"cert_id": "MANAGEMENT_CERT_B", "status": "ACTIVE", "expires_at": "2027-09-01", "critical_for_role": true}
    ],

    "policy_acknowledgments": [
      {"policy_name": "Política de Uso Aceptable", "version": "3.2", "acknowledged_at": "2026-01-15T08:30:00Z"},
      {"policy_name": "Política de Protección de Datos", "version": "2.1", "acknowledged_at": "2026-01-15T08:30:00Z"},
      {"policy_name": "Código de Conducta", "version": "5.0", "acknowledged_at": "2026-01-15T08:30:00Z"},
      {"policy_name": "Política de Seguridad de la Información", "version": "4.0", "acknowledged_at": "2026-01-15T08:30:00Z"}
    ],

    "risk_assessment": {
      "inherent_risk_score": 45,
      "residual_risk_score": 15,
      "risk_trend": "STABLE",
      "last_assessment_at": "2026-06-01T00:00:00Z",
      "assessed_by": "COMPLIANCE.OFFICER"
    }
  }
}
```

---

## SECCIÓN 14 — `lifecycle_automation` — AUTOMATIZACIÓN DEL CICLO DE VIDA

**Dominio:** USER/D1/D9 · **Estándar:** SCIM 2.0 RFC 7644 · ISO/IEC 24760-2:2025 · NIST SP 800-53 AC-2
**DDL:** `idn_user_template` · `idn_user_role` · `ath_binding` · `ses_context` · `sync_log`

```json
{
  "lifecycle_automation": {
    "provisioning": {
      "provisioning_source": "HR_ORANGEHRM",
      "provisioning_method": "SCIM_2_0",
      "provisioned_at": "2026-01-15T08:00:00Z",
      "provisioning_status": "COMPLETED",
      "auto_provisioned_resources": [
        {"resource": "keycloak_user", "status": "CREATED"},
        {"resource": "tryton_res_user", "status": "CREATED"},
        {"resource": "tryton_employee", "status": "CREATED"},
        {"resource": "email_mailbox", "status": "CREATED"},
        {"resource": "vpn_account", "status": "NOT_NEEDED"}
      ]
    },

    "deprovisioning": {
      "deprovisioning_method": "AUTOMATIC",
      "grace_period_days": 30,
      "steps": [
        {"step": "REVOKE_SESSIONS", "order": 1, "delay_after_termination": "IMMEDIATE"},
        {"step": "REVOKE_CREDENTIALS", "order": 2, "delay_after_termination": "IMMEDIATE"},
        {"step": "DISABLE_KC_ACCOUNT", "order": 3, "delay_after_termination": "IMMEDIATE"},
        {"step": "ARCHIVE_TRyTON_EMPLOYEE", "order": 4, "delay_after_termination": "1_DAY"},
        {"step": "BACKUP_DATA", "order": 5, "delay_after_termination": "7_DAYS"},
        {"step": "PURGE_PII", "order": 6, "delay_after_termination": "30_DAYS"}
      ]
    },

    "sync_state": {
      "kc_sync_status": "SYNCED",
      "kc_last_sync_at": "2026-06-24T08:00:00Z",
      "tryton_sync_status": "SYNCED",
      "tryton_last_sync_at": "2026-06-24T08:00:00Z",
      "drift_detected": false,
      "drift_details": null
    },

    "notifications": {
      "on_role_change": true,
      "on_password_change": true,
      "on_new_device": true,
      "on_suspicious_activity": true,
      "channels": ["email", "push", "whatsapp"],
      "preferred_channel": "push"
    }
  }
}
```

---

## RESUMEN — 15 SECCIONES

| # | Sección | Dominio | Campos | DDL Tables |
|---|---------|---------|:---:|------|
| 0 | `identity` | USER | 25 | `idn_user_template`, `idn_tenant` |
| 1 | `personal_info` | USER | 65+ | `idn_user_template.template`, `menu_context` |
| 2 | `professional_info` | USER/ORG | 55+ | `org_empresa`, `org_sucursal`, `org_pos_logico`, `fis_location`, `cal_schedule` |
| 3 | `roles_assignments` | D1 | 30+ | `idn_user_role`, `idn_role_template`, `dlg_delegation`, `emergency_override_policy` |
| 4 | `keycloak_credentials` | D9 | 50+ | 46 tablas `ath_*` |
| 5 | `physical_credentials` | D2 | 25+ | `fis_device`, `fis_access_zone`, `user_client_device` |
| 6 | `device_registry` | D5/D7 | 25+ | `user_client_device`, `net_device`, `device_attestation_log`, `mobile_heartbeat_log` |
| 7 | `session_state` | D8 | 30+ | `ses_*`, `ctx_transfer_log`, `qr_challenge_registry`, `ses_risk_policy` |
| 8 | `location_profile` | D6 | 25+ | `geo_*`, `geo_fence`, `geo_location_log`, `geo_velocity_policy` |
| 9 | `temporal_profile` | D4 | 30+ | `cal_*`, `cal_overtime_policy`, `cal_break_policy`, `cal_holiday` |
| 10 | `network_profile` | D7 | 20+ | `net_*`, `idn_tenant_network`, `certificate_pin_config` |
| 11 | `audit_profile` | D11 | 20+ | `aud_*`, `aud_compliance_map` |
| 12 | `external_services` | D5/D9 | 20+ | `idp_*`, `ath_consent`, `external_session_registry` |
| 13 | `compliance_profile` | D11/D14 | 20+ | `fin_sod_rule`, `sod_validation_config`, `conflict_interest_policy` |
| 14 | `lifecycle_automation` | USER/D1/D9 | 20+ | `idn_user_template`, `sync_log`, `ath_revocation` |

**~460 atributos totales. 15 secciones. 177 tablas DDL referenciadas.**
**Investigado contra: Okta Universal Directory (31 base + custom), Keycloak 26.x User Profile,**
**SCIM 2.0 RFC 7643/7644, Auth0 FGA, Entra ID, SailPoint IIQ.**

---

*Documento generado 2026-06-25. 15 secciones con ~460 atributos. Explota el potencial completo de la DDL.*
