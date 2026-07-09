# SBOS — Decisiones de Diseño: RolTemplate v5.0 y UserTemplate v5.0
## Por qué los templates anteriores fueron reemplazados
### SKULL · SBOS · Abril 2026

---

## RESUMEN EJECUTIVO

Los templates v5.0 reemplazan a `EsrtructuraRolFinal.txt`, `EstructuraUserFinal.txt`
y los fragmentos §4 de `SBOS-BAUTH-CONCEPTUALIZACION-v4_0.md`.

**Lo que los anteriores hacían mal:**
1. Mezclaban permisos de usuario con permisos de rol
2. No cubrían los 3 dominios de soberanía (lógico, físico, financiero)
3. Carecían de los métodos de autenticación completos del Authentication_Framework.json
4. No tenían política biométrica conforme RGPD + NIST SP 800-63B
5. No incluían el SAM-128 como campo calculado
6. La estructura de zonas de negocio abstractas no existía

---

## DECISIONES DE DISEÑO POR BLOQUE

### D1 — Separación estricta RolTemplate/UserTemplate

**Problema anterior:** `EstructuraUserFinal.txt` incluía campos de permisos y
métodos requeridos en el usuario. Esto viola el principio H-RBAC.

**Decisión v5.0:** El UserTemplate NUNCA define permisos propios.
Solo registra qué métodos de autenticación TIENE disponibles (credenciales registradas).
El RolTemplate define qué métodos son REQUERIDOS.

### D2 — Los 15 Métodos de Autenticación completos

**Problema anterior:** Los templates anteriores listaban solo 4-5 métodos.
`Authentication_Framework.json` define 15 métodos en 5 categorías.
`Policies_Authentication_Framework.json §modern_authentication_policies` exige WebAuthn/FIDO2.

**Decisión v5.0:** `availableMethods` lista los 15 métodos canónicos.
`requiredMethods` define flujos específicos por nivel de riesgo.
`alternativeMethods` define sustitutos aprobados con condiciones.

### D3 — Zonas de Negocio Abstractas (no aplicaciones)

**Problema anterior:** `EsrtructuraRolFinal.txt` no tenía el concepto de zonas.
`Authentication_Framework.json §webSocketAccessControl.accessRules` define endpoints
pero no zonas de negocio transversales.

**Decisión v5.0 (de SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION):**
El bit lógico NO significa "puede usar Tryton" sino "puede operar en la zona Contabilidad".
Las zonas se resuelven a aplicaciones vía `zone_application_map.yaml`.

### D4 — SAM-128 como campo calculado (solo lectura)

**Problema anterior:** El BitMask 64 bits no estaba en el RolTemplate — vivía solo
en código. No había trazabilidad de qué bits estaban activos para un rol.

**Decisión v5.0:** El bloque `sam128` vive en el RolTemplate como campo `_readonly`.
bAuth lo calcula y lo persiste. Los administradores pueden ver qué bits tienen activos.
Facilita auditoría y debugging.

### D5 — Biometría: Política en RolTemplate, Hash en UserTemplate

**Problema anterior:** No había separación entre política biométrica y datos biométricos.
`Policies_Authentication_Framework.json §physical_logical_authentication.physical_access.allowed_methods.biometric`
define los tipos pero no dónde almacenar qué.

**Decisión v5.0 (RGPD Art.9 + NIST SP 800-63B §5.2.3):**
- `RolTemplate.physical_access.biometric_enrollment_policy` → POLÍTICA (qué se acepta)
- `UserTemplate.physical_credentials.biometric_templates` → HASH del usuario (solo hash PBKDF2-SHA256)
- Raw biometric NUNCA sale del chip del lector ni llega al servidor

### D6 — Dominio Financiero con máscara propia

**Problema anterior:** Los límites de transacción vivían en `EsrtructuraRolFinal.txt`
pero sin vinculación con el SAM-128. El `Authentication_Framework.json §authenticationCore`
define transaction_periods pero no los integra con el modelo de bits.

**Decisión v5.0:** `financial_transactions` es un bloque de primer nivel en el RolTemplate.
Genera el `FinancialDomainMask` (SAM-128 Q3).
Los SoD financieros se declaran explícitamente y se evalúan en la Conflict Matrix.

### D7 — Context Overrides individuales en UserTemplate

**Problema anterior:** No había forma de aprobar excepciones individuales al RolTemplate
sin modificar el template base (afectando a todos).

**Decisión v5.0:** `UserTemplate.roles_assignments.active_roles[].context_overrides`
permite excepciones individuales aprobadas y documentadas.
La excepción requiere: approved_by + reason + valid_until.
bAuth registra en audit_events toda excepción aplicada.

### D8 — Compliance y Certificaciones como bloqueantes

**Problema anterior:** `EstructuraUserFinal.txt` tenía `compliance_control.certifications`
pero sin mecanismo de bloqueo. Un usuario sin cert podía ser ACTIVE.

**Decisión v5.0:** `certifications_status[blocking=true]` son prerequisito para status=ACTIVE.
bAuth bloquea la activación si hay certificaciones faltantes con `blocking: true`.
Implementa PCI-DSS Req.12.6 (security awareness training).

---

## MAPPING CON LOS DOCUMENTOS DE REFERENCIA

| Fuente | Campo en Template | Implementación |
|---|---|---|
| `Authentication_Framework.json §authenticationCore.sanctumEnhanced.tokenManagement.security.keyRotation` | `logical_access.session_management.reauthentication_interval_s` | KC token rotation policy |
| `Authentication_Framework.json §advancedBiometrics.multimodalAuthentication.fusionEngine.modalities.facialRecognition.neuralEngine.minimumAccuracy` | `physical_access.biometric_enrollment_policy.fmr_threshold` | Threshold de calidad biométrica |
| `Authentication_Framework.json §contextualAuthentication.riskEvaluationEngine.environmentalContext.locationAnalysis.spatialValidation.impossibleTravel` | `logical_access.geospatial_control.validation_rules.geo_velocity_check` | SPI SkbosGeoContextAuthenticator |
| `Authentication_Framework.json §quantumResistantSecurity.postQuantumCrypto.keyExchange.primaryAlgorithm.name` | `digital_signature.algorithm = "CRYSTALS-Dilithium"` | Firma post-cuántica del template |
| `Policies_Authentication_Framework.json §modern_authentication_policies.webauthn_fido2` | `availableMethods: ["webauthn_platform", "webauthn_roaming", "passkey"]` | Auth Flow KC |
| `Policies_Authentication_Framework.json §physical_logical_authentication.physical_access.entry_points.high_security_areas.required_factors` | `physical_access.requiredMethods.critical_areas` | 3 factores para zonas críticas |
| `Policies_Authentication_Framework.json §quantum_resistant_authentication.post_quantum_cryptography.key_exchange.primary_algorithm` | `digital_signature.algorithm = "CRYSTALS-Dilithium"` | Integrado |
| `Policies_Authentication_Framework.json §compliance_regulation.regulatory_framework.compliance_requirements.data_protection.gdpr_compliance` | `UserTemplate.territorial_compliance.privacy` | RGPD Art.6/9 |
| `SBOS-008-001 §2.1 Mapa de Bits` | `sam128.physical_domain_mask_hex` | SAM-128 Q1+Q2 |
| `SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION §3.3` | `zones.zone_logical/*` | Zonas × Verbos abstractos |
| `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO §2.4` | `conflict_management.segregation_of_duties` | Conflict Matrix con AND NOT |
| `SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0 §A3` | `tryton_privileges.button_rules[].sod_cannot_also` | Doble formato SOD |

---

## LO QUE FALTA IMPLEMENTAR (roadmap)

| Componente | Template que lo necesita | Versión estimada |
|---|---|---|
| `LogicalDomainEvaluator` | `zones` → evaluador unificado | v1.0 |
| `FinancialDomainEvaluator` | `financial_transactions` → evaluador | v1.0 |
| `zone_application_map.yaml` | Resolución zona → apps | v0.9 GA |
| Passkeys (KC 26.4+) | `availableMethods: ["passkey"]` | v0.9 |
| `bos_normative_ar/mx` en SAM-128 Q4 | `territorial_compliance.applicable_regulations` | v1.5 |
| SCIM 2.0 bidireccional completo | `system_bindings.*` | v1.1 |

---

*SKULL · SBOS · SBOS-TEMPLATES-DECISIONES · Abril 2026*
