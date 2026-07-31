# AUDITORÍA DE GAPS DDL — bAuth Identity Control Plane
## Análisis de completitud: Documentos de dominio · DDL canónico · VPS SBOSDB

**Versión:** 1.0.0  
**Fecha:** 2026-07-31  
**Autor:** bauth-developer (auditoría independiente para BOS)  
**Alcance:** 18 dominios D00-D15, D98, D99 · 161 tablas en VPS · DDL v2.12.0  
**Nota:** Documento suelto — NO indexado a manuales ni anexos. Uso: planificación DDL.  
**Exclusión explícita:** Los átomos en `idn_roles_template` (T-162) NO son gaps de base de datos. Son el resultado de sagas de configuración en el árbol de roles. Este documento no los registra como pendientes.

---

## Metodología de auditoría

La auditoría cruza tres fuentes de verdad independientes:

1. **Documentos de completitud** (`A.65.03.01.01` a `A.65.03.01.18`) — estado declarado por dominio.
2. **DDL canónico** (`DDLs/SBOS_db_V2_DDL.sql` v2.12.0) — tablas formalizadas en el contrato DDL.
3. **VPS SBOSDB** — tablas que realmente existen en producción de pruebas (verificado en tiempo real).

Cuando las tres fuentes no coinciden, se documenta la brecha. La fuente de verdad operacional es la VPS.

Adicionalmente, cada gap fue contrastado con el estado actual de los estándares normativos internacionales mediante investigación en línea (julio 2026).

---

## Estado global verificado

| Dominio | Nombre | Estado doc. | Tablas VPS (verificadas) | Tablas pendientes DDL | Madurez |
|---------|--------|-------------|--------------------------|----------------------|---------|
| **D00** | Identidad Organizacional | ✅ COMPLETO | 25+ tablas | 0 | L4 |
| **D01** | Control de Acceso Lógico | ✅ PARCIAL* | 10+ tablas | 0 (DDL completo) | L3 |
| **D02** | Control de Acceso Físico | ❌ L0 | 0 propias | **8 tablas** | L0 |
| **D03** | Control Financiero | ❌ L0 | 0 | **8 tablas** | L0 |
| **D04** | Control Temporal (GTRBAC) | ❌ L0 | 0 | **6 tablas** | L0 |
| **D05** | Control Biométrico | ❌ L0 | 0 | **6 tablas** | L0 |
| **D06** | Control Geoespacial | ❌ L0 | 0 | **6 tablas** | L0 |
| **D07** | Control de Red / ZTA | ❌ L0 | 0 | **7 tablas** | L0 |
| **D08** | Context Plane / Sesiones | ✅ COMPLETO | ses_* + bos.ctx_* | 0 | L3 |
| **D09** | Credenciales | ⚠️ PARCIAL | 25 tablas auth_* | **2 tablas** | L1-L2 |
| **D10** | Delegación de Identidad | ❌ L0 | 0 propias | **6 tablas** | L0 |
| **D11** | Auditoría y SIEM | ⚠️ PARCIAL | aud_* + bos.ctx_* | **4 tablas** | L2 |
| **D12** | Blockchain / DID | ⚠️ PARCIAL | 5 tablas blk_* | **5 tablas** | L1 |
| **D13** | Firma Digital | ⚠️ PARCIAL | 8 sig_* + 4 wallet_* | **7 tablas** | L2 |
| **D14** | PAM Cuentas Privilegiadas | ✅ COMPLETO | pam_* 6 tablas | **1 tabla** | L3 |
| **D15** | NHI (Identidades No Humanas) | ✅ COMPLETO | idn_roles_nhi_* | **2 tablas** | L3 |
| **D98** | Meta-Registro | ❌ L0 | 0 | **3 tablas** | L0 |
| **D99** | Admin Global Soberano | ❌ L0 | 0 | **6 tablas** | L0 |

*D01 tiene el DDL completo de tablas. El estado PARCIAL refiere a átomos (excluidos de este informe).

**Resumen cuantitativo:**
- Dominios completos (L3-L4): **5** (D00, D01, D08, D14, D15)
- Dominios parciales (L1-L2): **4** (D09, D11, D12, D13)
- Dominios sin implementar (L0): **9** (D02, D03, D04, D05, D06, D07, D10, D98, D99)
- **Total tablas pendientes de implementar:** ~77 tablas
- Tablas en VPS hoy: **161**
- Tablas objetivo tras implementación completa: **~238**

---

## Detalle de gaps por dominio

### D02 — Control de Acceso Físico `❌ L0`

**Estándares:** ISO 27001 A.7.1-A.7.4 · NIST SP 800-116 R2 · IEC 60839-11 · SIA OSDP v2.2.2 · FIPS 201-3 (PIV)

**Perspectiva de industria:** Los sistemas IAM enterprise maduros integran el control de acceso físico con el digital desde el mismo modelo de identidad. La convergencia físico-digital (física badge ↔ identidad IAM) es requisito explícito en NIST SP 800-116 R2 §3 y es la base de los sistemas PACS modernos. Sin esta tabla, el IAM no puede revocar acceso físico cuando se revoca una identidad digital — brecha de seguridad crítica en offboarding.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-220 | `idn_acceso_fisico_instalacion` | B01 facilities | ISO 27001 A.7.1 · IEC 60839-11-5 | 🔴 P1 |
| T-221 | `idn_acceso_fisico_lector` | B02 readers | SIA OSDP v2.2.2 · IEC 60839-11-5 §6 | 🔴 P1 |
| T-222 | `idn_acceso_fisico_presencia` | B03 presence | NIST SP 800-116 R2 §4.2 · IEC 60839-11-3 | 🟠 P2 |
| T-223 | `idn_acceso_fisico_presencia_log` | B04 antipassback | IEC 60839-11-1 §6.4 · ISO 27001 A.7.2 | 🟠 P2 |
| T-224 | `idn_acceso_fisico_visita` | B05 visitors | ISO 27001 A.7.2 · GDPR Art. 5(1)(c) | 🟠 P2 |
| T-225 | `idn_acceso_fisico_emergencia` | B06 emergency | NIST SP 800-116 R2 §5.4 · ISO 27001 A.7.3 | 🟠 P2 |
| T-226 | `idn_acceso_fisico_evacuacion` | B07 mustering | ISO 27001 A.7.4 · NFPA 101:2021 §7.7 | 🟡 P3 |
| T-228 | `idn_acceso_fisico_credencial` | B09 credentials | **NIST SP 800-116 R2 §3** · FIPS 201-3 | 🔴 P1 |

**Gap crítico verificado:** Sin T-228 no existe convergencia física-digital. T-220 y T-221 son el fundamento — sin catálogo de instalaciones y lectores no hay control ninguno.

**Decisión arquitectónica pendiente (GAP-D02-05):** El anti-passback (T-223) es un log de eventos. El enforcement en tiempo real requiere estado actual de presencia — vista materializada sobre T-223 vs. tabla de estado separada. Requiere decisión HITL antes de implementar.

---

### D03 — Control Financiero `❌ L0`

**Estándares:** PCI DSS 4.0 · SOX §302/§404 · COSO 2013 · SIN RND 102100000011 · ISO 20022 · FAPI 2.0 · PSD2 Art. 98

**Perspectiva de industria:** El PDP que controla acceso a operaciones financieras sin límites transaccionales en base de datos es un control de papel. PCI DSS 4.0 Req 8.2 exige límites por rol, y COSO CC6.3 exige segregación de funciones financieras demostrable mediante evidencia de datos, no solo política. La ausencia de T-241 (aprobación dual/quórum) es el riesgo más inmediato: una operación de alto valor puede ejecutarse con un solo actor.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-240 | `idn_financiero_limite` | B01 limits | PCI DSS 4.0 Req 8.2 · NIST AC-2(6) | 🔴 P1 |
| T-241 | `idn_financiero_aprobacion` + `_voto` | B02 approvals | COSO 2013 CC6.3 · SOX §302 | 🔴 P1 |
| T-242 | `idn_financiero_sod_regla` | B03 segregation | NIST AC-5 · SOX §404 · COSO CC6.3 | 🟠 P2 |
| T-243 | `idn_financiero_factura_autorizacion` | B04 billing | SIN RND 102100000011 · Ley 164 Bolivia | 🟠 P2 |
| T-244 | `idn_financiero_reporte` | B05 reporting | SOX §302/§404 · IFRS 7 | 🟠 P2 |
| T-245 | `idn_financiero_alerta_fraude` | B06 fraud | PCI DSS 4.0 Req 10.7 · ISO 37001 §8.6 | 🟠 P2 |
| T-246 | `idn_financiero_conciliacion` | B07 reconciliation | ISO 20022 §5 · COSO 2013 CC6.6 | 🟡 P3 |
| T-247 | `idn_financiero_tpp_consentimiento` | B08 open_banking | FAPI 2.0 · RFC 9449 DPoP · PSD2 Art. 98 | 🟠 P2 |

**Gap crítico verificado:** T-240 + T-241 son bloqueantes para PCI DSS 4.0. Sin límites transaccionales en BD, cualquier actor con el rol correcto puede ejecutar operaciones de valor ilimitado. La aprobación dual (T-241) sin base de datos es un control no demostrable en auditoría SOX.

---

### D04 — Control Temporal (GTRBAC) `❌ L0`

**Estándares:** GTRBAC §3-5 · NIST SP 800-53 R5 AC-3(7) · AC-2(2) · ISO 8601:2019 · RFC 5545 iCalendar · PostgreSQL 18 temporal constraints (WITHOUT OVERLAPS/PERIOD)

**Perspectiva de industria:** El acceso temporal con ventanas horarias y rotación de turnos es un control crítico para cumplimiento laboral y seguridad operacional. NIST AC-3(7) "Role-Based Access Control" exige que los privilegios puedan ser restringidos a ventanas de tiempo específicas. Sin T-260 y T-261, bAuth no puede revocar automáticamente accesos al finalizar un turno — el access creep temporal es inevitable. PostgreSQL 18 tiene soporte nativo de `WITHOUT OVERLAPS` y `PERIOD` para temporal constraints que SBOS debe aprovechar en estas tablas.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-260 | `idn_temporal_ventana` | B01 windows | GTRBAC §3.2 · NIST AC-3(7) | 🔴 P1 |
| T-261 | `idn_temporal_periodo` | B02 periods | GTRBAC §4 · PG18 PERIOD | 🔴 P1 |
| T-262 | `idn_temporal_calendario` | B03 calendar | RFC 5545 §3 · ISO 8601:2019 | 🟠 P2 |
| T-263a | `idn_temporal_turno` | B04 schedules | NIST AC-2(2) · GTRBAC §5 | 🟠 P2 |
| T-263b | `idn_temporal_turno_asignacion` | B04 schedules | NIST AC-2(2) | 🟠 P2 |
| T-264 | `idn_temporal_excepcion` | B05 exceptions | NIST AC-17(1) · ISO 27001 A.5.18 | 🟡 P3 |

**Nota de integración:** T-262 puede solaparse con `bcalendar.cal_calendar` (ya existe en VPS). Antes de crear T-262, evaluar si una FK a `cal_calendar` satisface D04-B03 sin duplicar datos. Requiere análisis antes de implementar.

---

### D05 — Control Biométrico `❌ L0`

**Estándares:** NIST SP 800-76-2 · ISO/IEC 30107-3:2023 (PAD) · ISO/IEC 19794-2:2011 · ISO/IEC 29794-1:2024 · ISO/IEC 24745:2022 · NIST SP 800-63B-4 §5.2.3 (AAL3) · FIDO2 §8.8

**Perspectiva de industria:** La autenticación biométrica como AAL3 requiere: (a) enrolamiento trazable con calidad de muestra verificada, (b) detección de vivacidad (PAD — Presentation Attack Detection) obligatoria según ISO/IEC 30107-3:2023 e impuesta por NIST 800-63B-4 para AAL3, y (c) revocación de plantilla que no exponga los datos biométricos originales (ISO/IEC 24745:2022). Sin estas tablas, bAuth no puede ofrecer AAL3 conforme a estándares. La ausencia de T-282 (PAD policy) es el riesgo más serio: los ataques de presentación (fotos, réplicas) pueden pasar sin ser detectados.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-280 | `idn_biometrico_enrolamiento` | B01 enrollment | NIST SP 800-76-2 §4 · ISO/IEC 30107-1:2023 | 🔴 P1 |
| T-281 | `idn_biometrico_verificacion_log` (particionada) | B02 verification | ISO/IEC 19794-2:2011 §5 · NIST 800-63B-4 §5.2.3 | 🔴 P1 |
| T-282 | `idn_biometrico_pad_policy` | B03 liveness | **ISO/IEC 30107-3:2023 §5** · FIDO2 §8.8 | 🔴 P1 |
| T-283 | `idn_biometrico_identificacion_log` (particionada) | B04 identification | ISO/IEC 19794-2:2011 §6 · NIST SP 800-76-2 §5 | 🟠 P2 |
| T-284 | `idn_biometrico_calidad_policy` | B05 quality | ISO/IEC 29794-1:2024 §5 · NIST SP 800-76-2 §3 | 🟠 P2 |
| T-285 | `idn_biometrico_revocacion` | B06 revocation | **ISO/IEC 24745:2022 §6** · NIST SP 800-76-2 §6 | 🟠 P2 |

**Alerta normativa:** ISO/IEC 30107-3:2023 (Presentation Attack Detection) fue actualizada en 2023 y ahora es la norma vigente para PAD. La versión anterior (2017) ya no se acepta como cumplimiento en licitaciones gubernamentales y sistemas bancarios. bAuth debe implementar T-282 conforme a la versión 2023.

---

### D06 — Control Geoespacial `❌ L0`

**Estándares:** RFC 7946 GeoJSON §3.1 · OGC GeoSPARQL 1.1 · NIST SP 800-53 R5 AC-3(11) · NIST SI-4(13) · GDPR Art. 44-49 (transferencias internacionales) · Ley 1174 Bolivia · ISO 6709:2022

**Perspectiva de industria:** El "viaje imposible" (impossible travel detection) es uno de los controles más efectivos contra el robo de credenciales. Microsoft, Okta y Ping Identity lo implementan como regla de política de riesgo de sesión por defecto. Sin T-302 (velocidad geográfica), bAuth no puede detectar que un usuario autenticó desde La Paz a las 09:00 y desde Madrid a las 09:15. T-303 (soberanía de datos) es crítica para SBOS: si los datos de un tenant boliviano no pueden salir del país, el motor geoespacial debe poder bloquear accesos desde IPs fuera de Bolivia — esto es el diferenciador soberano del producto.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-300 | `idn_geoespacial_geocerca` | B01 geofencing | RFC 7946 §3.1 · OGC GeoSPARQL 1.1 | 🔴 P1 |
| T-301 | `idn_geoespacial_ubicacion_log` (particionada) | B02 location | RFC 7946 §3 · NIST AC-3(11) | 🟠 P2 |
| T-302a | `idn_geoespacial_velocidad_policy` | B03 velocity | NIST SI-4(13) · ISO 27001 A.8.16 | 🟠 P2 |
| T-302b | `idn_geoespacial_velocidad_evento` | B03 velocity | NIST SI-4(13) | 🟠 P2 |
| T-303 | `idn_geoespacial_residencia` | B04 residency | **GDPR Art. 44-49** · Ley 1174 Bolivia | 🔴 P1 |
| T-304 | `idn_geoespacial_dispositivo_flota` | B05 fleet | ISO 6709:2022 · NIST AC-3(11) | 🟡 P3 |

**Gap crítico:** T-303 es el único control que puede garantizar que los datos de un tenant soberano no sean accesibles desde jurisdicciones extranjeras. Sin él, SBOS no puede cumplir su promesa de soberanía geográfica.

---

### D07 — Control de Red / Zero Trust Architecture `❌ L0`

**Estándares:** NIST SP 800-207 (ZTA) · RFC 9449 (DPoP) · RFC 7636 (PKCE) · RFC 8705 (mTLS) · NIST SP 800-52 R2 · OWASP API Security 2023 §6 · W3C Trace Context v2 · OpenTelemetry §5 · SBOS-049 · SBOS-050

**Perspectiva de industria:** DPoP (RFC 9449) es el control más importante de este dominio. Sin T-321 (DPoP binding), los access tokens de bAuth son Bearer tokens que pueden ser robados y reutilizados desde cualquier cliente. FAPI 2.0 (requerido para open banking y PSD2) exige DPoP o mTLS como mecanismo de sender-constraining. La ausencia de esta tabla significa que todos los tokens emitidos por bAuth son vulnerables a replay attacks si son interceptados. T-326 (propagación de contexto) es igualmente crítica para SBOS-049: sin config de propagación, el ctx_id no se propaga correctamente entre servicios.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-320 | `idn_red_conexion_policy` | B01 connection | RFC 8705 §2 · NIST SP 800-52 R2 · SBOS-050 | 🔴 P1 |
| T-321 | `idn_red_dpop_binding` | B02 tokens | **RFC 9449 DPoP §4** · RFC 7636 PKCE §4 | 🔴 P1 |
| T-322 | `idn_red_rate_policy` | B03 rate | OWASP API Security 2023 §6 · RFC 6585 §4 | 🟠 P2 |
| T-323 | `idn_red_postura_policy` | B04 posture | NIST SP 800-207 §3.3 · CIS Controls v8 §13 | 🟠 P2 |
| T-324 | `idn_red_segmento` | B05 segmentation | NIST SP 800-207 §2.1 · ISO 27001 A.8.22 | 🟠 P2 |
| T-325 | `idn_red_dlp_policy` | B06 inspection | NIST SP 800-53 R5 SI-3 · ISO 27001 A.8.12 | 🟡 P3 |
| T-326 | `idn_red_contexto_propagacion` | B07 propagation | W3C Trace Context v2 · **SBOS-049** | 🔴 P1 |

**Alerta DPoP (verificada julio 2026):** RFC 9449 es el RFC final de DPoP (publicado en 2023). FAPI 2.0 lo exige como el mecanismo preferido de sender-constraining sobre mTLS para APIs financieras. Sin T-321, bAuth no puede implementar FAPI 2.0 ni PSD2 compliant. Esto bloquea D03-B08 (open banking).

---

### D09 — Credenciales `⚠️ PARCIAL`

**Estado verificado en VPS:** 25 tablas `auth_*` implementadas. 7/10 bloques satisfechos.

**Estándares:** NIST SP 800-63B-4 §5.1.1.2 (password history) · OAuth 2.0 RFC 6749 · RFC 7519 (JWT) · RFC 9449 (DPoP)

**Perspectiva de industria:** El historial de contraseñas (T-360) es obligatorio bajo NIST SP 800-63B-4 §5.1.1.2 — prohíbe reutilizar las últimas N contraseñas. Sin esta tabla, el motor no puede verificar que una nueva contraseña no fue usada antes. El registro de tokens emitidos (T-363) es la base del registro de sesiones activas y de la introspección OAuth — sin él, `bauth.token.introspect` no tiene datos sobre los que operar.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-360 | `idn_credencial_password_history` | B01 password | **NIST SP 800-63B-4 §5.1.1.2** · OWASP ASVS 5.0 §2.1.7 | 🔴 P1 |
| T-363 | `idn_credencial_token_emitido` | B04 tokens | RFC 7519 JWT §4 · **RFC 9449 DPoP** · OAuth 2.0 | 🔴 P1 |

**Nota sobre B04 (tokens):** `fed_token_issued` (T-367, S16) existe en VPS pero no cubre el ciclo de vida completo del token ni el binding DPoP. T-363 es necesaria como registro canónico del motor de credenciales bAuth.

---

### D10 — Delegación de Identidad `❌ L0`

**Estándares:** RFC 8693 (Token Exchange) · RFC 9396 (RAR - Rich Authorization Requests) · NIST SP 800-53 R5 AC-2(5) · AC-5 (SoD) · ISO 27001 A.5.18 · ANSI INCITS 359-2004 §4.5

**Perspectiva de industria:** El Token Exchange (RFC 8693) es el mecanismo estándar para impersonación controlada — permite que un servicio actúe "en nombre de" un usuario sin conocer sus credenciales. Sin T-380, los flujos de delegación de identidad (ej: un agente que actúa en nombre de un usuario para una operación específica) no están soportados de forma segura. La Autorización Granular de API (RAR, RFC 9396) permite que los access tokens lleven autorizaciones precisas ("puede aprobar facturas hasta 5000 BOB") en lugar de scopes genéricos — es la evolución de OAuth hacia autorización contextual.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-380 | `idn_delegacion_identidad` | B01 delegation | **RFC 8693 §3** · NIST AC-2(5) | 🔴 P1 |
| T-381 | `idn_delegacion_renovacion` | B02 renewal | RFC 8693 §4.2 · ISO 27001 A.5.18 | 🟠 P2 |
| T-382 | `idn_delegacion_restriccion` | B03 restrictions | NIST AC-5 · ISO 27001 A.5.3 | 🟠 P2 |
| T-383 | `idn_delegacion_cadena` | B04 chain | RFC 8693 §2 · ANSI INCITS 359-2004 §4.5 | 🟠 P2 |
| T-384 | `idn_delegacion_uso_log` (particionada) | B05 audit | ISO 27001 A.8.15 · NIST AU-2 | 🟠 P2 |
| T-385 | `idn_delegacion_rar_request` | B06 rich_authorization | **RFC 9396 §3** · OAuth 2.0 | 🟠 P2 |

---

### D11 — Auditoría y SIEM `⚠️ PARCIAL`

**Estado verificado en VPS:** `aud_certification_campaign`, `aud_certification_review`, tablas `bos.ctx_*` WORM. IGA access review: L3. Retención y SIEM: L0.

**Estándares:** ISO 27001 A.8.15 · NIST SP 800-53 R5 AU-2/AU-6/AU-9/AU-11 · GDPR Art. 5(1)(e)(f) · SOX §802 (7 años retención)

**Perspectiva de industria:** La política de retención de logs (T-400) tiene implicaciones legales directas. SOX §802 exige 7 años de retención de registros financieros. GDPR Art. 5(1)(e) exige limitación de almacenamiento — no se puede guardar indefinidamente. Estos dos requisitos son contradictorios y requieren una política de retención diferenciada por tipo de evento y jurisdicción del tenant. Sin T-400, bAuth retiene logs indefinidamente sin política — violación GDPR. Sin T-403, no hay log unificado multi-dominio; los eventos de D02, D03, D05 tienen registros parciales o nulos.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-400 | `idn_auditoria_retencion` + seeds | B02 retention | **SOX §802** · GDPR Art. 5(1)(e) · NIST AU-11 | 🔴 P1 |
| T-401 | `idn_auditoria_regla_alerta` + seeds | B04 monitoring | NIST AU-6 · ISO 27001 A.8.16 | 🟠 P2 |
| T-402 | `idn_auditoria_siem_destino` + seed Wazuh | B05 export | NIST AU-9(2) · ISO 27001 A.8.15 | 🟠 P2 |
| T-403 | `idn_auditoria_evento` (particionada) | B01 events | ISO 27001 A.8.15 · **GDPR Art. 5(1)(f)** · NIST AU-2 | 🔴 P1 |

---

### D12 — Blockchain / DID `⚠️ PARCIAL`

**Estado verificado en VPS:** 5 tablas `blk_*` (anchoring + merkle) implementadas. DID parcial via `idn_did_document`.

**Tablas pendientes** (verificadas contra estándares W3C DID Core 1.0 · RFC 6962 · EIP-712 · Hyperledger Besu):

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-420 | `idn_blockchain_anclaje` | B01 anchoring | RFC 6962 §2.1 · EIP-712 · NIST SP 800-208 | 🟠 P2 |
| T-421 | `idn_blockchain_transaccion` | B02 transactions | Hyperledger Besu §6 · EIP-1559 | 🟠 P2 |
| T-422 | `idn_blockchain_wallet` | B03 wallet | BIP-32/39/44 · EIP-712 | 🟠 P2 |
| T-423 | `idn_blockchain_merkle_proof` | B04 merkle | RFC 6962 §2.1.1 · NIST SP 800-208 §3 | 🟡 P3 |
| T-424 | `idn_blockchain_nodo` | B06 consensus | Hyperledger Besu §4 · EIP-225 (CLIQUE) | 🟡 P3 |

**Nota:** Las 5 tablas `blk_*` existentes cubren parcialmente B01 y B04. Las tablas pendientes son el motor de transacciones completo.

---

### D13 — Firma Digital `⚠️ PARCIAL`

**Estado verificado en VPS:** 8 tablas `sig_*` + 4 `wallet_*` implementadas. Motor de soporte completo. Falta el motor operacional de solicitudes.

**Normas críticas:** Ley 164 Bolivia (Art. 9, Art. 20) · ADSIB-FD-POLT-015 v2.3 · PAdES EN 319 132 · CAdES EN 319 122 · RFC 3161 (TSA) · ETSI EN 319 102-1/2 (LTV) · ETSI EN 319 412 (cadena CA) · FIPS 201-3

**Perspectiva de industria:** La validación a largo plazo (LTV, T-445) es crítica para documentos con validez jurídica. Un documento firmado con un certificado de 2 años sigue siendo válido 10 años después solo si en el momento de la firma se registró evidencia de que la cadena de certificación era válida entonces. Sin T-445, los documentos firmados por bAuth pierden validez jurídica cuando expiran los certificados de la CA — incumplimiento de Ley 164 Bolivia.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-440 | `idn_firma_solicitud` | B01 signing | PAdES EN 319 132 · **Ley 164 Art. 9** | 🔴 P1 |
| T-441 | `idn_firma_cadena_ca` | B02 certification | RFC 5280 §6 · ADSIB-FD-POLT-015 v2.3 | 🔴 P1 |
| T-442 | `idn_firma_timestamp` | B03 timestamping | **RFC 3161 §2** · Ley 164 Art. 20 | 🔴 P1 |
| T-443 | `idn_firma_verificacion_log` | B04 verification | ETSI EN 319 102-1 §5 · RFC 5280 | 🟠 P2 |
| T-444 | `idn_firma_revocacion_cache` | B05 revocation | RFC 6960 OCSP · RFC 5280 §5 CRL | 🟠 P2 |
| T-445 | `idn_firma_ltv_evidencia` | B06 long_term | **ETSI EN 319 102-2 §5.6** · RFC 3161 §3 | 🟠 P2 |
| T-446 | `idn_firma_eudi_wallet` | B07 eudi_wallet | UE 2024/1183 §5a · ARF 1.4 | 🟡 P3 |

**Alerta EU 2024/1183:** El Reglamento Europeo de Identidad Digital (eIDAS 2.0) fue publicado como UE 2024/1183 en mayo 2024. El EUDI Wallet ARF 1.4 define cómo deben integrarse los wallets de identidad digital. T-446 es el conector con este ecosistema.

---

### D14 — PAM (Cuentas Privilegiadas) `✅ COMPLETO` con gap menor

**Estado:** 6 tablas `pam_*` implementadas. Un gap residual:

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-461 | `pam_grabacion_ref` | B06 session_recording | NIST SP 800-53 R5 AU-14 · ISO 27001 A.8.20 | 🟠 P2 |

**Contexto:** La grabación de sesiones privilegiadas existe como proceso (videos/logs en almacenamiento externo), pero sin T-461 no hay referencia trazable a los archivos con hash de integridad. NIST AU-14 exige que las sesiones de cuentas privilegiadas sean auditables — la referencia con hash garantiza que el archivo no fue alterado.

---

### D15 — NHI (Identidades No Humanas) `✅ COMPLETO` con 2 gaps

**Estado:** La NHI más madura del ecosistema (L3). Gaps residuales:

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-480 | `idn_nhi_rotacion_policy` | B05 rotation | NIST SP 800-57 Pt1 R5 §5.3 · CIS Controls v8 §4.4 | 🟠 P2 |
| T-481 | `idn_nhi_svid` | B06 attestation | **SPIFFE Spec v1.0 §8** · NIST SP 800-204A §4 | 🔴 P1 |

**Contexto SPIFFE:** Los SVIDs (SPIFFE Verifiable Identity Documents) son el mecanismo estándar de atestación de identidad para workloads en Zero Trust. Sin T-481, bAuth no puede emitir ni validar SVIDs para los daemons de SBOS — los servicios se autentican entre sí sin identidad verificable. NIST SP 800-204A §4 exige service mesh identity para microservicios seguros.

---

### D98 — Meta-Registro `❌ L0`

**Estándares:** SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1:2019 §5 · ISO/IEC 24760-2:2025 §7 · NIST SP 800-162 §4.2 · ISO 9001:2015 §7.5

**Perspectiva de industria:** El schema registry (T-500) es infraestructura de gobernanza — permite que el sistema EAV de atributos (`idn_identity_attribute`, T-157) sea extensible sin hardcode. Sin T-500, agregar un nuevo tipo de atributo requiere código. Con T-500, es un INSERT. El catálogo de átomos (T-501) habilita la introspección del árbol BitMask: qué átomos existen, cuáles están implementados, cuáles están deprecados. El versionado del árbol (T-502) permite auditoría forense: "¿qué permisos existían el día X?".

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-500 | `idn_registro_atributo_schema` + seeds SCIM | B01 schema | SCIM 2.0 RFC 7643 §4 · ISO/IEC 24760-1 §5 | 🟠 P2 |
| T-501 | `idn_registro_atomo_catalogo` + trigger auto | B02 catalog | NIST SP 800-162 §4.2 · ISO/IEC 24760-2:2025 §7 | 🟠 P2 |
| T-502 | `idn_registro_arbol_version` + job diario | B03 versioning | ISO 9001:2015 §7.5 · ISO/IEC 24760-2:2025 | 🟠 P2 |

---

### D99 — Admin Global Soberano `❌ L0`

**Estándares:** NIST SP 800-53 R5 AC-2 · NIST SP 800-131A R2 (algoritmos criptográficos) · ISO 27001 A.8.24 · NIST AI RMF 1.0 §3.6 · NTIA SBOM 2021 · NIST SA-12 (supply chain)

**Perspectiva de industria:** T-513 (parámetros criptográficos) es la tabla más crítica de D99. Sin ella, diferentes módulos de bAuth pueden usar algoritmos distintos sin control centralizado. NIST SP 800-131A R2 deprecó MD5 y SHA-1 — sin T-513, no hay forma de verificar que ningún módulo los use. T-510 (administradores globales) es el control de acceso al propio sistema de identidad — sin ella, no hay separación formal entre un admin de tenant y un super-admin del sistema. T-515 (SBOM) responde a la Executive Order 14028 de EE.UU. y al Cyber Resilience Act europeo: los sistemas críticos deben poder producir un inventario de sus componentes de software.

| T-Code | Tabla propuesta | Bloque | Norma clave | Prioridad |
|--------|----------------|--------|-------------|-----------|
| T-510 | `idn_global_admin` + seed BAUTH_SYSTEM | B01 users | NIST AC-2 · ISO 27001 A.5.16 | 🔴 P1 |
| T-511 | `idn_global_notificacion` | B02 notifications | NIST SI-12 · ISO 27001 A.5.2 | 🟠 P2 |
| T-512 | `idn_global_hitl_excepcion` | B03 exceptions | NIST AI RMF 1.0 §3.6 · ISO 27001 A.5.29 | 🟠 P2 |
| T-513 | `idn_global_crypto_params` + seeds NIST/prohibidos | B04 cryptography | **NIST SP 800-131A R2** · ISO 27001 A.8.24 | 🔴 P1 |
| T-514 | `idn_global_compliance_control` + seeds ISO/NIST | B05 compliance | ISO 19600:2014 §6 · NIST CA-2 | 🟠 P2 |
| T-515 | `idn_global_sbom` | B06 supply_chain | NTIA SBOM 2021 · **NIST SA-12** · EU Cyber Resilience Act | 🟡 P3 |

---

## Matriz de prioridades consolidada

### 🔴 P1 — Bloqueantes críticos (implementar primero)

Estos gaps bloquean cumplimiento normativo, seguridad fundamental, o son prerequisito de otros dominios.

| Gap | Tabla | Dominio | Norma bloqueada | Impacto si no se implementa |
|-----|-------|---------|-----------------|---------------------------|
| T-321 DPoP binding | `idn_red_dpop_binding` | D07 | RFC 9449 · FAPI 2.0 | Todos los tokens son Bearer — replay attacks posibles |
| T-326 ctx propagation | `idn_red_contexto_propagacion` | D07 | SBOS-049 | ctx_id no se propaga entre servicios — SBOS-049 incumplido |
| T-220+221 físico base | `idn_acceso_fisico_instalacion` + `_lector` | D02 | NIST SP 800-116 R2 | Sin base para ningún control de acceso físico |
| T-228 convergencia física | `idn_acceso_fisico_credencial` | D02 | NIST SP 800-116 R2 §3 | Badge no vinculado a identidad digital — offboarding incompleto |
| T-240+241 financiero | `idn_financiero_limite` + `_aprobacion` | D03 | PCI DSS 4.0 · SOX | Operaciones financieras sin límite ni aprobación dual |
| T-260+261 GTRBAC | `idn_temporal_ventana` + `_periodo` | D04 | NIST AC-3(7) | Accesos no expiran al terminar turno — access creep temporal |
| T-280+282 biométrico | `idn_biometrico_enrolamiento` + `_pad_policy` | D05 | NIST 800-63B-4 AAL3 · ISO/IEC 30107-3:2023 | AAL3 no disponible · ataques de presentación sin detectar |
| T-300+303 geoespacial | `idn_geoespacial_geocerca` + `_residencia` | D06 | GDPR Art. 44-49 · Soberanía SBOS | Sin control geográfico de datos — soberanía incumplida |
| T-360 password history | `idn_credencial_password_history` | D09 | NIST SP 800-63B-4 §5.1.1.2 | Reutilización de contraseñas — violación 800-63B-4 |
| T-363 token registry | `idn_credencial_token_emitido` | D09 | RFC 7519 · RFC 9449 | Introspección de token sin datos — método RPC sin soporte |
| T-380 Token Exchange | `idn_delegacion_identidad` | D10 | RFC 8693 | Impersonación controlada no implementada |
| T-400 retención logs | `idn_auditoria_retencion` | D11 | SOX §802 · GDPR Art. 5(1)(e) | Logs sin política — violación GDPR simultáneamente con SOX |
| T-403 log unificado | `idn_auditoria_evento` | D11 | ISO 27001 A.8.15 | Sin log multi-dominio — auditoría forense incompleta |
| T-440+441+442 firma | `idn_firma_solicitud` + cadena CA + timestamp | D13 | Ley 164 Bolivia | Firma digital sin trazabilidad — sin validez jurídica |
| T-481 SVID SPIFFE | `idn_nhi_svid` | D15 | SPIFFE Spec v1.0 · NIST SP 800-204A | Daemons SBOS sin identidad verificable entre sí |
| T-510 admin global | `idn_global_admin` | D99 | NIST AC-2 | Sin separación admin-tenant vs. super-admin del sistema |
| T-513 crypto params | `idn_global_crypto_params` | D99 | NIST SP 800-131A R2 | Algoritmos prohibidos (MD5/SHA-1) no controlados |

### 🟠 P2 — Alta prioridad (implementar en segunda fase)

33 tablas adicionales en D02-D13, D14-D15, D98, D99. Ver detalles por dominio.

### 🟡 P3 — Completitud avanzada (tercera fase)

14 tablas en D02 (evacuación), D03 (conciliación), D04 (excepciones), D05 (identificación 1:N), D06 (flota), D07 (DLP), D10 (RAR), D13 (EUDI), D98 (versionado), D99 (SBOM).

---

## Hallazgos que no estaban en los documentos de completitud

Estas brechas fueron identificadas durante la auditoría cruzando las tres fuentes y la investigación en línea:

### H-01 — Integración D04 con bcalendar (solapamiento potencial)

`D04-B03` propone `T-262 idn_temporal_calendario`. La tabla `bcalendar.cal_calendar` ya existe en VPS (9 tablas bcalendar). Antes de crear T-262, se debe evaluar si una FK a `cal_calendar` satisface D04-B03 sin duplicar datos. Si bcalendar ya cubre los feriados bolivianos, T-262 podría ser reemplazada por una vista o eliminada. **Requiere análisis arquitectónico antes de crear T-262.**

### H-02 — DPoP bloquea D03-B08 (FAPI 2.0)

D07-B02 (T-321 DPoP binding) es prerequisito de D03-B08 (T-247 open banking FAPI 2.0). No se puede implementar la tabla T-247 de forma útil si T-321 no existe — FAPI 2.0 exige DPoP como sender-constraining. El orden de implementación debe ser: T-321 → T-247.

### H-03 — D11-B01 (T-403) depende de que D02/D03/D05 estén implementados

El log unificado multi-dominio (T-403) solo tiene valor cuando hay eventos de D02, D03, D05 para registrar. Si se implementa T-403 antes que los dominios fuente, quedará vacío. El orden correcto: implementar al menos D02-T-223 (log de presencia) y D03-T-245 (alertas fraude) antes de activar T-403.

### H-04 — Seeds de T-513 (crypto params) deben incluir algoritmos PQC

NIST finalizó los estándares PQC en agosto 2024 (FIPS 203 ML-KEM, FIPS 204 ML-DSA, FIPS 205 SLH-DSA). Los seeds de T-513 deben incluir estos algoritmos como "aprobados para uso futuro" y los algoritmos clásicos como "aprobados con deadline de migración". Sin esto, T-513 nace desactualizada respecto al estado actual de NIST SP 800-131A R2.

### H-05 — D02-B04 (anti-passback) requiere decisión de diseño no resuelta

El log T-223 registra eventos (ENTRADA/SALIDA). El enforcement de anti-passback requiere conocer el estado actual de presencia por actor+instalación. Dos opciones: (a) vista materializada sobre T-223 o (b) tabla de estado separada. Esta decisión no fue resuelta en el documento de completitud (GAP-D02-05). Debe resolverse antes de implementar T-223 para no crear una tabla con propósito incompleto.

### H-06 — D98-T-501 puede auto-poblarse con trigger

Si se crea un trigger `AFTER INSERT ON bauth.idn_roles_template`, puede auto-crear la entrada correspondiente en T-501 (catálogo de átomos) con `implementado = false`. Esto elimina la necesidad de poblar T-501 manualmente. El trigger garantiza que el catálogo esté siempre sincronizado con el árbol. Esta optimización no estaba documentada.

---

## Orden de implementación recomendado

Basado en dependencias técnicas y prioridad normativa:

```
FASE 1 — Fundamentos de seguridad (P1 críticos)
├── T-513 crypto_params + seeds PQC+NIST (D99) — gobierno del stack criptográfico
├── T-510 global_admin + seed BAUTH_SYSTEM (D99) — separación admin
├── T-321 dpop_binding (D07) — tokens seguros antes de cualquier integración
├── T-326 contexto_propagacion + seeds (D07) — SBOS-049 cumplido
├── T-360 password_history (D09) — NIST 800-63B-4 §5.1.1.2
├── T-363 token_emitido (D09) — introspección funcional
├── T-400 auditoria_retencion + seeds (D11) — política GDPR/SOX
└── T-403 auditoria_evento particionada (D11) — log unificado

FASE 2 — Dominios físico + temporal (P1 + P2)
├── T-220, T-221, T-228 (D02) — base acceso físico + convergencia
├── T-222..T-226 (D02) — control físico completo
├── T-260, T-261 (D04) — GTRBAC base
├── T-262..T-264 (D04) — GTRBAC completo [evaluar integración bcalendar antes]
├── T-300, T-303 (D06) — geocercas + soberanía de datos
└── T-301, T-302 (D06) — location logging + viaje imposible

FASE 3 — Dominios financiero + credenciales + delegación
├── T-240, T-241 (D03) — límites + aprobación dual
├── T-242..T-247 (D03) — SoD financiero + FAPI 2.0 [T-321 prerequisito de T-247]
├── T-380 (D10) — Token Exchange base
├── T-381..T-385 (D10) — delegación completa
├── T-401, T-402 (D11) — alertas + SIEM destino
└── T-480, T-481 (D15) — rotación NHI + SVID SPIFFE

FASE 4 — Firma digital + biométrico + blockchain
├── T-440, T-441, T-442 (D13) — motor de firma Ley 164 [BLOQUEANTE LEGAL]
├── T-443..T-446 (D13) — firma completa
├── T-280, T-282 (D05) — enrolamiento + PAD biométrico [BLOQUEANTE AAL3]
├── T-281, T-283..T-285 (D05) — biométrico completo
├── T-420..T-424 (D12) — motor blockchain completo
└── T-461 (D14) — grabación sesiones privilegiadas

FASE 5 — Gobernanza y meta-registro
├── T-500..T-502 (D98) — schema registry + catálogo + versionado
├── T-511..T-515 (D99) — gobernanza completa
└── Triggers y jobs de todos los dominios
```

---

## Apéndice: Verificación contra VPS

```
Fecha verificación: 2026-07-31
Comando: psql -h localhost -p 15432 -U postgres -d SBOSDB
         SELECT table_schema, count(*) FROM information_schema.tables
         WHERE table_schema NOT IN ('pg_catalog','information_schema')
         GROUP BY table_schema ORDER BY table_schema;

Resultado:
  bauth     | 122
  bcalendar |   9
  bglobal   |   8
  bos       |  22
  Total     | 161

Búsqueda de tablas D02 (idn_acceso_fisico_*):
  0 rows — confirmado: D02 sin implementar en VPS.

Búsqueda de tablas D03..D10 (prefijos idn_financiero_, idn_temporal_,
  idn_biometrico_, idn_geoespacial_, idn_red_, idn_delegacion_):
  0 rows en todos los casos.
```

---

*Fin del documento. Próxima revisión: al completar Fase 1.*
