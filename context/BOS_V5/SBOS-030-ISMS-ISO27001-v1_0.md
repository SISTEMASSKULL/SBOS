# SBOS-030 — SGSI: Sistema de Gestión de Seguridad de la Información
## ISO 27001:2022 — Documento inicial del proceso de certificación

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-030
**Versión:** 1.0
**Estado:** ACTIVO — En proceso de certificación
**Clasificación:** CONFIDENCIAL — Gobierno de Seguridad
**Complementa:** SBOS-023 (Zero Trust), SBOS-022 (Bounded Contexts como activos de información)

---

## 1. Alcance del SGSI

El SGSI cubre **SBOS como producto** en dos dimensiones:

1. **SKULL Systems (desarrollo):** los procesos de desarrollo, testing, firma Ed25519 y distribución del software SBOS desde las instalaciones de SKULL.
2. **Operación en instalaciones de clientes:** el software SBOS operando en los servidores de clientes, incluyendo los datos que procesa.

> **Nota de alcance:** SKULL es el **procesador de datos** (según GDPR/normativa iberoamericana). Los clientes son los **controladores de datos**. El SGSI de SKULL cubre sus obligaciones como procesador. Cada cliente debe implementar su propio SGSI como controlador.

---

## 2. Política de Seguridad de la Información

> **Para firma de Dirección**

---

**POLÍTICA DE SEGURIDAD DE LA INFORMACIÓN**
**SKULL Systems — SBOS**
**Versión 1.0 · Marzo 2026**

SKULL Systems reconoce que la información es un activo crítico del negocio y que su protección es una responsabilidad organizacional fundamental.

**La dirección de SKULL Systems se compromete a:**

1. **Confidencialidad:** proteger la información de clientes y del negocio contra accesos no autorizados.
2. **Integridad:** garantizar que la información no sea modificada de forma no autorizada.
3. **Disponibilidad:** asegurar que la información esté disponible cuando sea necesaria, conforme a los SLAs contractuales.
4. **Cumplimiento legal:** cumplir con las regulaciones aplicables en los países donde operamos.
5. **Mejora continua:** revisar y mejorar el SGSI anualmente.

Esta política aplica a todo el personal de SKULL Systems y a los contratistas que accedan a información del negocio.

Firma: _______________________
Cargo: CTO / Director General
Fecha: _______________

---

## 3. Declaración de Aplicabilidad (SoA) — 20 controles críticos para SBOS

La SoA mapea los controles del Anexo A de ISO 27001:2022 a los controles ya implementados en SBOS.

| # | Control ISO 27001:2022 | Sección Anexo A | Estado en SBOS | Implementación actual |
|---|----------------------|----------------|----------------|----------------------|
| 1 | Políticas de seguridad de la información | A.5.1 | ✅ Implementado | Esta política + SBOS-023 |
| 2 | Gestión de activos | A.5.9 | 🔄 Parcial | SBOS-022 (activos de información por BC) — falta registro formal |
| 3 | Control de acceso | A.5.15 | ✅ Implementado | Keycloak H-RBAC + Principio 1 (ADR-004) |
| 4 | Gestión de identidad | A.5.16 | ✅ Implementado | Keycloak como único IdP, SPIs custom SBOS-019 |
| 5 | Autenticación | A.5.17 | ✅ Implementado | JWT 5 min + MFA via SPIs + SkbosBehavioralScoreAuthenticator |
| 6 | Derechos de acceso privilegiado | A.5.18 | ✅ Implementado | Segregación de funciones SBOS-008 §9, Vault para secretos |
| 7 | Transferencia de información | A.5.14 | ✅ Implementado | TLS en todos los endpoints, no hay transmisión a terceros |
| 8 | Gestión de vulnerabilidades técnicas | A.8.8 | 🔄 Parcial | cargo-audit (SBOS-018-SONAR) — falta proceso formal de parches |
| 9 | Gestión de cambios | A.8.32 | ✅ Implementado | IAM Installer con drift detection + Ed25519 + proceso ARB (SBOS-025) |
| 10 | Protección contra malware | A.8.7 | ✅ Implementado | Wazuh SIEM en S03 identityserver, firma Ed25519 de artefactos |
| 11 | Gestión de logs | A.8.15 | ✅ Implementado | Stack LGTM en S12 + Loki + audit_events del bKernel |
| 12 | Sincronización de relojes | A.8.17 | ✅ Implementado | NTP configurado en todos los nodos (JWT depende de tiempo sincronizado) |
| 13 | Cifrado | A.8.24 | ✅ Implementado | TLS 1.3, Ed25519 para firmas, Vault para claves |
| 14 | Seguridad en redes | A.8.20 | ✅ Implementado | Zero Trust SBOS-023, Kong + WAF ModSecurity, NetworkPolicies K8s |
| 15 | Segregación de redes | A.8.22 | ✅ Implementado | Namespaces K8s + NetworkPolicies + Calico CNI |
| 16 | Backup y recuperación | A.8.13 | ✅ Implementado | pgBackRest + MinIO (SBOS-026), Velero para K8s |
| 17 | Gestión de incidentes | A.5.24 | 🔄 Parcial | Runbooks RK-001 a RK-014 (SBOS-024) — falta proceso formal de clasificación |
| 18 | Notificación de brechas | A.5.26 | ✅ Implementado | SBOS-023 §nueva (MP-03) — proceso por jurisdicción |
| 19 | Continuidad del negocio | A.5.30 | ✅ Implementado | SBOS-026 DR + simulacros semestrales (RK-013) |
| 20 | Cumplimiento legal | A.5.31 | 🔄 Parcial | SBOS-023 §GDPR — falta mapeo completo por jurisdicción |

**Leyenda:** ✅ Implementado · 🔄 Parcial · ❌ No implementado

---

## 4. Registro de Riesgos (ISO 27005)

| # | Activo | Amenaza | Vulnerabilidad | P (1-5) | I (1-5) | Riesgo inherente | Control existente | Riesgo residual |
|---|--------|---------|---------------|---------|---------|-----------------|------------------|----------------|
| R-01 | Clave privada Ed25519 del Release Plane | Robo/compromiso de la clave | Almacenamiento inseguro de la clave privada | 2 | 5 | 10 | Clave en HSM/Vault, nunca en el servidor web de distribución | 4 (2×2) |
| R-02 | Bases de datos de clientes (PostgreSQL) | Acceso no autorizado | SQL injection en apps del stack | 2 | 5 | 10 | PgBouncer + Kong WAF (ModSecurity) + NetworkPolicies K8s | 4 (2×2) |
| R-03 | JWT de Keycloak | Interceptación y reuso | Token de larga duración capturado | 1 | 4 | 4 | JWT duración 5 min (expiración automática) | 2 (1×2) |
| R-04 | Slots de replicación WAL del bKernel | Eliminación accidental | Acceso directo a PostgreSQL sin restricciones | 3 | 4 | 12 | Solo el rol de replicación específico tiene acceso a los slots; Vault gestiona credenciales | 6 (2×3) |
| R-05 | Instalaciones de clientes (flota) | Distribución de fichas maliciosas | Compromiso del Release Server | 1 | 5 | 5 | Firma Ed25519 obligatoria + verificación en el IAM Installer antes de ejecutar cualquier artefacto | 2 (1×2) |
| R-06 | Logs de auditoría en S14 | Manipulación o eliminación de evidencia | Acceso admin sin MFA | 2 | 4 | 8 | Wazuh SIEM detecta cambios en logs + acceso a S14 requiere MFA | 4 (2×2) |
| R-07 | Datos personales en Keycloak | Brecha de datos personales | Vulnerabilidad en la versión de Keycloak | 2 | 4 | 8 | Actualizaciones automáticas de Keycloak patch + Wazuh monitoreo | 4 (2×2) |
| R-08 | bKernel (daemon soberano) | Escalamiento de privilegios | Vulnerabilidad en código Rust del bKernel | 1 | 5 | 5 | cargo-audit en CI/CD + bKernel sin puerto expuesto + systemd con NoNewPrivileges=yes | 2 (1×2) |

**Escala de riesgo:** Bajo (1-4) · Medio (5-9) · Alto (10-14) · Crítico (15-25)

**Riesgos que requieren atención inmediata (≥ 8):** R-01, R-02, R-04, R-06, R-07

---

## 5. Plan de implementación hacia certificación ISO 27001:2022

### Fase 1 — Gap Analysis (Meses 1-2: Abril-Mayo 2026)

| Actividad | Responsable | Entregable |
|-----------|-------------|-----------|
| Completar el inventario formal de activos de información | Arquitecto Lead | Registro de activos en formato ISO 27005 |
| Revisar los controles ✅ para confirmar que están documentados | CTO | Evidencia de implementación por control |
| Remediar controles 🔄 Parciales | CTO + Dev Lead | Controls A.5.9, A.8.8, A.5.24, A.5.31 completos |
| Entrevistas con el equipo para identificar gaps operacionales | Auditor externo (si disponible) | Informe de gaps |

### Fase 2 — Remediación (Meses 3-6: Junio-Septiembre 2026)

| Actividad | Responsable | Entregable |
|-----------|-------------|-----------|
| Implementar proceso formal de gestión de vulnerabilidades | DevOps Lead | Proceso documentado + cargo-audit bloqueante activo |
| Formalizar proceso de gestión de incidentes | SRE Lead | Clasificación P0-P3 + escalación documentada |
| Completar mapeo regulatorio por jurisdicción | Dir. Legal | SBOS-023 §GDPR completo para BO/AR/MX |
| Implementar revisiones periódicas de acceso privilegiado | CTO | Proceso de revisión trimestral de accesos admin |
| Firmar la SoA por dirección | CTO + CEO | SoA firmada (este documento, §2) |

### Fase 3 — Auditoría interna (Meses 7-8: Octubre-Noviembre 2026)

| Actividad | Responsable | Entregable |
|-----------|-------------|-----------|
| Ejecutar auditoría interna del SGSI | Arquitecto Lead (interno) o auditor externo | Informe de auditoría interna |
| Verificar que todos los controles SoA están implementados y evidenciados | CTO | Lista de conformidades y no-conformidades |
| Remediar no-conformidades identificadas | Equipo correspondiente | Cierre de NCs antes de la auditoría externa |

### Fase 4 — Certificación externa (Meses 9-12: Diciembre 2026 - Marzo 2027)

| Actividad | Responsable | Entregable |
|-----------|-------------|-----------|
| Seleccionar organismo certificador | CEO | Contrato con certificador ISO 27001 acreditado |
| Auditoría Stage 1 (revisión documental) | Organismo certificador | Informe Stage 1 |
| Auditoría Stage 2 (auditoría en sitio) | Organismo certificador | Informe Stage 2 |
| Obtención del certificado ISO 27001:2022 | — | Certificado válido por 3 años |

---

## 6. Revisión del SGSI

El SGSI se revisa formalmente una vez al año en el mes de enero. La revisión incluye:
- Resultados de las auditorías internas y externas
- Estado de los riesgos (¿han cambiado la probabilidad o el impacto?)
- Incidentes del año y lecciones aprendidas
- Cambios en el negocio o la tecnología que requieran actualizar controles
- Objetivos del SGSI para el próximo año

---

## Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — alcance, política, SoA 20 controles, registro de riesgos, plan hacia certificación |

---

*SKULL · SBOS · SBOS-030-ISMS · v1.0 · Marzo 2026 · CONFIDENCIAL*
*Complementa: SBOS-023 (Zero Trust), SBOS-022 (activos de información), SBOS-026 (continuidad del negocio)*
