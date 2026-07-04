# SBOS — Plan de Certificación Formal
## FAPI 2.0 (OpenID Foundation) e ISO/IEC 27001:2022

**Documento:** SBOS-CERT-001  
**Versión:** 1.0  
**Estado:** Normativo Activo  
**Fecha:** 2026-06-12  
**Clasificación:** Interno · Dirección + Ingeniería  

---

## 1. Naturaleza de esta Brecha

Las certificaciones FAPI 2.0 e ISO 27001:2022 no son brechas de ingeniería.
Son procesos formales con terceros independientes que tienen sus propios
criterios, timelines y costos. El código puede cumplir el 100% de los
requisitos técnicos y la certificación puede aún demorar meses por razones
de proceso externo.

Este documento distingue con precisión qué está bajo control del equipo de
ingeniería de SBOS y qué está bajo control del tercero certificador.

---

## 2. Certificación ISO/IEC 27001:2022

### 2.1 Qué es

ISO/IEC 27001:2022 es el estándar internacional de gestión de seguridad de la
información (ISMS — Information Security Management System). Certifica que la
organización tiene un sistema formal de gestión de riesgos, controles
implementados y un ciclo de mejora continua.

La certificación la otorga un organismo de certificación acreditado (p. ej.
Bureau Veritas, SGS, TÜV, BSI, AENOR). El auditor es externo e independiente.

### 2.2 Lo que SBOS controla — Evidencia técnica producida

Cada control del Anexo A de ISO 27001:2022 tiene un artefacto técnico
concreto ya definido en la arquitectura SBOS:

| Control ISO 27001:2022 | Artefacto técnico SBOS | Responsable |
|---|---|---|
| **A.5.2** Políticas de seguridad | `SBOS-004-RULES` — 15 principios inquebrantables | Arquitectura |
| **A.5.15** Control de acceso | bAuth + BitMask 64-bit + RBAC jerárquico | bAuth |
| **A.5.16** Gestión de identidad | Keycloak 26.x + 5 SPIs custom | Identity Plane |
| **A.5.17** Información de autenticación | Vault AppRole por ficha. Secrets dinámicos con TTL | bos + Vault |
| **A.8.2** Derechos de acceso privilegiado | BitMask Bit 23 (ADMIN_PANEL). MFA obligatorio roles admin | bAuth |
| **A.8.3** Restricción de acceso a información | tenant_id obligatorio en toda query. NetworkPolicy default-deny | Data Plane + Calico |
| **A.8.5** Autenticación segura | FAPI 2.0 + DPoP + MFA + Passkeys (KC 26.4+) | Keycloak |
| **A.8.7** Protección contra malware | Wazuh DaemonSet en todos los nodos | Wazuh |
| **A.8.8** Gestión de vulnerabilidades técnicas | Kyverno admission control. Trivy en CI/CD. Imágenes firmadas Ed25519 | CI/CD + K8s |
| **A.8.12** Prevención de fuga de datos | biedata: único daemon con salida exterior. NetworkPolicy default-deny | biedata + Calico |
| **A.8.15** Registro de actividad (logging) | audit_events en bkernel_db. ctx_id inmutable. Nunca se elimina | bKernel |
| **A.8.16** Actividades de monitoreo | Prometheus + Grafana + Wazuh SIEM. Alertas definidas en §13.5 | Observabilidad |
| **A.8.20** Seguridad de redes | mTLS Linkerd (pod↔pod). TLS 1.3 Kong. mTLS bhnexus↔banexus | Linkerd + Kong |
| **A.8.24** Uso de criptografía | pgcrypto (PG). SSE-S3 MinIO. Vault KMS. TLS 1.3 en tránsito | Múltiples capas |
| **A.8.28** Codificación segura | Checklist pre-commit §17.4. buf lint + buf breaking en CI | Ingeniería |

### 2.3 Lo que el equipo debe producir (artefactos de gestión)

Además de los artefactos técnicos, el auditor ISO 27001 exige artefactos de
gestión. Estos son documentos de proceso, no de código:

| Artefacto de gestión | Descripción | Responsable |
|---|---|---|
| **Declaración de Aplicabilidad (SoA)** | Lista de los 93 controles del Anexo A con justificación de inclusión/exclusión | CISO / Dirección |
| **Política de Seguridad de la Información** | Documento firmado por la dirección. Alcance, objetivos, compromisos | Dirección |
| **Análisis y evaluación de riesgos (ISMS-RA)** | Inventario de activos, amenazas, vulnerabilidades, impacto, probabilidad | CISO + Ingeniería |
| **Plan de tratamiento de riesgos (RTP)** | Para cada riesgo identificado: control aplicado, responsable, fecha | CISO |
| **Procedimiento de gestión de incidentes** | Cómo se detecta, clasifica, responde y post-mortem de un incidente | Operaciones |
| **Procedimiento de continuidad del negocio (BCP)** | Failover PG, Redis, MinIO. RPO/RTO definidos. DR drill documentado | Ingeniería + Ops |
| **Procedimiento de control de accesos** | Alta/baja de usuarios, revisión periódica de privilegios, revocación | CISO + bos |
| **Registros de auditoría interna** | Evidencia de que se realizaron auditorías internas antes del auditor externo | CISO |
| **Revisión por la dirección** | Actas de reunión donde la dirección revisa el estado del ISMS | Dirección |
| **Programa de concienciación en seguridad** | Formación del personal. Registro de asistencia | RRHH / CISO |

### 2.4 Proceso externo — Lo que no controla ingeniería

| Etapa | Duración estimada | Controlado por |
|---|---|---|
| Selección del organismo certificador | 2-4 semanas | Dirección (decisión comercial) |
| Auditoría de diagnóstico (gap analysis) | 1-3 días in situ | Organismo certificador |
| Remediación de no-conformidades detectadas | 4-16 semanas | Ingeniería + CISO |
| Auditoría de etapa 1 (revisión documental) | 1-2 días | Organismo certificador |
| Auditoría de etapa 2 (revisión in situ) | 2-5 días | Organismo certificador |
| Emisión del certificado | 2-6 semanas post-auditoría | Organismo certificador |
| Auditorías de seguimiento anuales | 1-2 días/año | Organismo certificador |

**Costo estimado referencial** (varía por organismo, región y tamaño de la organización):

| Concepto | Rango estimado |
|---|---|
| Auditoría inicial (etapas 1+2) | USD 8.000 — 25.000 |
| Auditorías de seguimiento anuales | USD 3.000 — 8.000 |
| Consultoría de preparación (opcional) | USD 5.000 — 20.000 |

*Estos valores son referenciales. El costo real lo determina el organismo certificador seleccionado.*

### 2.5 Timeline propuesto

```
2026 Q3 (Jul-Sep)
    ├── Completar artefactos de gestión (SoA, RA, RTP, políticas)
    ├── Auditoría interna formal
    └── Contratar organismo certificador

2026 Q4 (Oct-Dic)
    ├── Gap analysis por el organismo
    ├── Remediación de no-conformidades
    └── Auditoría etapa 1 (documental)

2027 Q1 (Ene-Mar)
    ├── Auditoría etapa 2 (in situ)
    └── Emisión del certificado ISO 27001:2022

2027 en adelante
    └── Auditorías de seguimiento anuales (ciclo de mejora continua)
```

---

## 3. Certificación FAPI 2.0 (OpenID Foundation)

### 3.1 Qué es

FAPI 2.0 (Financial-grade API Security Profile) es el perfil de seguridad de
OpenID Foundation para APIs que manejan datos financieros o de alta sensibilidad.
Requiere OAuth 2.0 + PKCE, DPoP (Demonstration of Proof of Possession),
PAR (Pushed Authorization Requests) y restricciones estrictas sobre los
grant types y algoritmos de firma.

La conformidad se verifica con el **FAPI Conformance Test Suite** de OpenID
Foundation, ejecutado sobre una instancia real del sistema con endpoints
públicamente accesibles.

### 3.2 Lo que SBOS controla — Requisitos técnicos

| Requisito FAPI 2.0 | Implementación SBOS | Estado |
|---|---|---|
| **OAuth 2.0 + Authorization Code Flow** | Keycloak 26.x con OIDC nativo | Keycloak lo provee |
| **PKCE obligatorio** (RFC 7636) | Habilitado en todos los clients KC `pkce-required: true` | Configuración KC |
| **DPoP** (RFC 9449) | Keycloak 26.x soporta DPoP nativo desde KC 23 | Keycloak lo provee |
| **PAR** — Pushed Authorization Requests (RFC 9126) | Habilitado en realm KC con `par.required: true` | Configuración KC |
| **Algoritmos de firma: RS256/PS256/ES256** | Configurado en KC. Vetados HS256 y RS512 | Configuración KC |
| **TLS 1.2+ obligatorio** | TLS 1.3 en Kong. mTLS en Linkerd | Kong + Linkerd |
| **Scopes mínimos de privilegio** | Definidos en RolTemplates de bAuth | bAuth |
| **Tiempo de vida del token acotado** | access_token: 5min. refresh_token: 24h | Configuración KC |
| **Revocación de tokens** (RFC 7009) | Endpoint `/protocol/openid-connect/revoke` en KC | Keycloak |
| **Introspection endpoint** (RFC 7662) | Habilitado en Kong plugin OIDC | Kong |
| **No `response_type=token`** (Implicit Flow vetado) | Grant types permitidos: `authorization_code`, `client_credentials` | Configuración KC |

**Evaluación:** Keycloak 26.x con la configuración correcta cumple el 100% de
los requisitos técnicos de FAPI 2.0. No se requiere código adicional.

### 3.3 Lo que no controla ingeniería — El proceso de conformidad

El FAPI Conformance Test Suite de OpenID Foundation funciona así:

1. Se registra la organización en el portal de OpenID Foundation.
2. Se configura el test suite apuntando a los endpoints de Keycloak.
3. Se ejecutan los test plans (FAPI2-SP-ID1 y FAPI2-MS-ID1).
4. Se corrigen las no-conformidades y se re-ejecutan los tests.
5. Se envía el reporte al equipo de OpenID Foundation para revisión.
6. OpenID Foundation emite el certificado de conformidad.

| Etapa | Duración estimada | Controlado por |
|---|---|---|
| Configuración del entorno de test | 1-2 semanas | Ingeniería |
| Ejecución del test suite y correcciones | 2-8 semanas | Ingeniería |
| Revisión por OpenID Foundation | 4-8 semanas | OpenID Foundation |
| Emisión del certificado | Tras aprobación de OIF | OpenID Foundation |
| Re-certificación por cambios de versión | Según criterio de OIF | OpenID Foundation |

**Costo:** La ejecución del test suite es gratuita (open source). El registro
para la certificación formal tiene un costo de organismo que varía según el
tipo de entidad (startup, empresa, proveedor financiero).

### 3.4 Entorno requerido para el test suite

El test suite de OpenID Foundation requiere que los endpoints sean públicamente
accesibles durante las pruebas. Esto implica:

- Un entorno de staging con dominio público (no localhost)
- Certificado TLS válido (no self-signed) en el dominio de pruebas
- Keycloak en el entorno de staging configurado con FAPI 2.0
- El equipo disponible para ejecutar los test plans de forma iterativa

### 3.5 Timeline propuesto

```
2026 Q3 (Jul-Sep)
    ├── Configurar entorno staging con dominio público
    ├── Habilitar FAPI 2.0 en KC staging (PAR, DPoP, PKCE)
    └── Primera ejecución del test suite FAPI2-SP-ID1

2026 Q4 (Oct-Dic)
    ├── Iteración sobre no-conformidades detectadas
    ├── Segunda ejecución del test suite (FAPI2-MS-ID1)
    └── Envío del reporte a OpenID Foundation

2027 Q1 (Ene-Mar)
    ├── Revisión por OpenID Foundation
    └── Emisión del certificado de conformidad FAPI 2.0
```

---

## 4. Matriz de Responsabilidades

| Actividad | Ingeniería | CISO / Dirección | Tercero externo |
|---|---|---|---|
| Implementar controles técnicos ISO 27001 | **HACE** | Revisa | — |
| Producir artefactos de gestión (SoA, RA, RTP) | Aporta datos | **HACE** | — |
| Auditoría interna ISO 27001 | Participa | **HACE** | — |
| Auditoría externa ISO 27001 | Aporta evidencia | Coordina | **DECIDE** |
| Configurar FAPI 2.0 en Keycloak | **HACE** | — | — |
| Ejecutar test suite OpenID Foundation | **HACE** | — | — |
| Revisar y certificar conformidad FAPI 2.0 | — | — | **DECIDE** (OIF) |
| Presupuesto para certificaciones | — | **DECIDE** | Fija precio |

---

## 5. Dependencias Críticas

Estas condiciones deben cumplirse antes de iniciar el proceso formal de
certificación. Son precondiciones bajo control del equipo:

- [ ] Keycloak configurado con FAPI 2.0 (PAR, DPoP, PKCE, TLS 1.3, algoritmos aprobados)
- [ ] audit_events operativo y demostrable — no-conformidad crítica ISO 27001 si falta
- [ ] context_sessions preservada con retention >= 1 año — evidencia forense ISO 27001 A.8.15
- [ ] DR drill documentado con evidencia — RPO/RTO medidos realmente
- [ ] Artefactos de gestión completos: SoA, RA, RTP, políticas firmadas
- [ ] Entorno staging con dominio público y certificado TLS válido
- [ ] Primera auditoría interna completada con actas

---

*SBOS-CERT-001 v1.0 · Junio 2026 · SKULL*
