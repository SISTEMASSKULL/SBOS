# SBOS-016-NOTES
## Notas — Estándar HUMAN-DOC
### SKULL · SBOS · V8 · Mayo 2026

---

## 1. Deuda Técnica — Estado Post-Sesión Mayo 2026

### Items resueltos

| Item | Prioridad | Estado | Dónde vive |
|---|---|---|---|
| Estrategia de ramas Git | Alta | ✅ Resuelto | SBOS-009-REPOS §3 |
| HITL personas no asignadas | Alta | ✅ Resuelto | SBOS-010-GOVERNANCE §1 |
| ADR-010 Kong 3.10 sin resolver | Alta | ✅ Resuelto | SBOS-048-ADR-CATALOG §12 — Kong OSS 3.9.x LTS |
| Ciclo de vida multitenant no absorbido | Media | ✅ Resuelto | SBOS-018-DAEMON-BOS §18.1 |
| 046-ONBOARDING incompleto | Alta | ✅ Resuelto | SBOS-046-ONBOARDING v1.3 |
| Tabla BitMask unificada | Alta | ✅ Resuelto | SBOS-021-DAEMON-BAUTH §8 |
| Catálogo troubleshooting bAuth | Media | ✅ Resuelto | SBOS-021-DAEMON-BAUTH §16 |
| Flujo onboarding magic link | Media | ✅ Resuelto | SBOS-022-IDENTITY-CONTRACTS §4 |
| SonarQube Quality Gate sin formalizar | Media | ✅ Resuelto | SBOS-013-TESTING §4 |
| Política PR multi-integrante | Baja | ✅ Resuelto | SBOS-009-REPOS §3 |
| Estándares Go no documentados | Media | ✅ Resuelto | SBOS-004-RULES §6 |
| Definición técnica SBOS como OS empresarial | Alta | ✅ Resuelto | SBOS-001-VISION v2.0 §2 — Mayo 2026 |
| Plano de Contexto Distribuido sin documentar | Alta | ✅ Resuelto | SBOS-049-CONTEXT-PLANE v3.0 — Mayo 2026 |
| ADR sobre responsabilidad del Context Plane | Alta | ✅ Resuelto | SBOS-048-ADR-CATALOG ADR-011 — Mayo 2026 |
| Política de puertos sin formalizar | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG v3.1 — Mayo 2026 |
| HTTP entre daemons sin política formal | Alta | ✅ Resuelto | SBOS-048-ADR-CATALOG ADR-012 + SBOS-050 §3 P9/P10 + §17 R10-R12 |
| Rangos puertos SKULL Custom (Smart*) sin definir | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG §13 — rango 28100-28999 |
| Puertos bhnexus incorrectos en documentación | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG §7.2 — bhnexus :9444 (WSS/mTLS) :9445 (métricas) |
| Colisión ClusterIP Zabbix Server / Traccar BASE | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG §12.4 CONFLICT-001 — Zabbix ajustado 8850→8848 |
| Colisión ClusterIP Portainer CE / Fleetbase | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG §12.4 CONFLICT-002 — Portainer ajustado 8860→8864 |
| Subdominios sksistemas.com sin catálogo formal | Media | ✅ Resuelto | SBOS-050-PORT-CATALOG §14-§16 — 9 activos + catálogo completo |
| biedata descrito incorrectamente como facturación | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG §7.2 — flujos EXPORT/IMPORT correctos documentados |
| S05-S15 nombres incorrectos en PORT-CATALOG | Alta | ✅ Resuelto | SBOS-050-PORT-CATALOG §12.2 — sincronizado con SBOS-005-STACK §3 |

### Items pendientes (no bloqueantes)

| Item | Prioridad | Estado | Condición de desbloqueo |
|---|---|---|---|
| Sesiones de transferencia por equipo (SBOS-046 §3.2) | Baja | ⏳ Pendiente | Incorporación de Juan Pérez |
| Co-propietario validado en tabla BF (SBOS-046 §2.3) | Baja | ⏳ Pendiente | Juan Pérez completa ejercicio de validación |
| Corpus 2 — HUMAN-DOC-CONCEPTUAL | Baja | ⏳ Pendiente | Puede iniciarse ahora |
| RFC-002 estrategia API Gateway post-LTS Kong | Baja | 📅 Programado Q1 2027 | Fecha fija |
| RFC-003 implementación Context Plane | Media | 📅 Programado Sprint B | Requiere SP-04 al 100% primero |
| RFC-004 evaluación ampliación rango ClusterIP | Media | 🔄 Abierto — pendiente ARB | Pre-requisito bloqueante: reubicar daemons soberanos de 9400-9499 a 9500-9599 antes de ampliar. Ver SBOS-050 §12.5 y SBOS-048 RFC-004 |

---

## 2. Decisiones de Sesión

| Decisión | Fecha | Detalle |
|---|---|---|
| HUMAN-DOC es fuente de verdad técnica | Abr 2026 | Sobre todos los documentos conceptuales |
| Dos corpus: técnico primero, narrativo después | Abr 2026 | Corpus 1 al 99.9% — puede iniciarse Corpus 2 |
| Trazabilidad obligatoria en cada archivo | Abr 2026 | Sección ## Trazabilidad al final de cada archivo |
| Documentos originales como archivo histórico | Abr 2026 | No son fuente de verdad — referencia histórica |
| ADR-010 Kong 3.10 — Opción A aceptada | Abr 2026 | Kong OSS 3.9.x LTS. RFC-002 en Q1 2027 |
| Modelo de desarrollo: Ingeniería Aumentada | Abr 2026 | 2 humanos + Agentes de Dominio |
| BF se mide por equipo, no por daemon | Abr 2026 | 6 equipos: BOS, AUTH, KERNEL, INTELLIGENCE, FRONTEND, INTEGRATIONS |
| Agentes de Dominio formalizados | Abr 2026 | 6 Agentes con corpus HUMAN-DOC. No toman decisiones arquitectónicas |
| Juan Pérez incorpora equipos en secuencia | Abr 2026 | BOS→AUTH→KERNEL→INTELLIGENCE→FRONTEND→INTEGRATIONS |
| **SBOS es un Sistema Operativo Empresarial** | **May 2026** | **Definición técnica verificable en v1.0 GA. Plano de control unificado sobre dominios lógico/físico/financiero. Alineado con ISA-95/IEC 62264. Ver SBOS-001-VISION §2** |
| **Context Plane formalizado como SBOS-049** | **May 2026** | **ctx_id, dctx_id, context.promoted, pre-auth → auth → operación. OTel Baggage + W3C. NIST 800-207 + ISO 27001 A.8.15** |
| **ADR-011: bos como dueño del Context Plane** | **May 2026** | **bos es el Policy Administrator (NIST 800-207). Inicializa y destruye Context Registry por tenant. Context API en :9443** |
| **SBOS-050-PORT-CATALOG creado** | **May 2026** | **Política completa de puertos, subdominios y segmentación de red. 1.844 líneas, 7 Partes, 21 secciones. Cubre 110+ apps, 8 daemons, 16 servidores lógicos, subdominios DNS verificados (9 activos en 144.91.76.130), 8 plantillas NetworkPolicy. Fuente de verdad prevalente para puertos en todo el corpus HUMAN-DOC** |
| **ADR-012: HTTP vetado entre daemons** | **May 2026** | **Solo WebSocket y Unix socket entre los 8 daemons soberanos y entre daemons y Smart*. Tres excepciones exhaustivas: métricas Prometheus (scrape unidireccional), healthcheck K8s, API bos→Core UI con mTLS. biedata es el único daemon con salida HTTP al exterior (APIs tributarias)** |
| **ADR-013: Política de Puertos SBOS** | **May 2026** | **Formaliza esquema ClusterIP (8100-8999, fórmula BASE+FICHA×10+TIPO), daemons soberanos (9400-9499), SKULL Custom Apps (28100-28999, bloques 10 por app), NodePort mantenimiento (31000-31999, esquema 310+SS). Alineado con IANA RFC 6335, CIS, NSA/CISA, ISO 27001** |
| **RFC-004 abierto** | **May 2026** | **Rango ClusterIP 8100-8999 insuficiente para 110+ apps en bloques fijos. Solución provisional: bloques variables. Pre-requisito bloqueante para ampliar: reubicar daemons de 9400-9499 a 9500-9599. Ver SBOS-048 RFC-004 y SBOS-050 §12.5** |
| **BOS-Agent corpus incluye SBOS-049 y SBOS-050** | **May 2026** | **SBOS-050 lectura obligatoria Semana 1 Equipo BOS: §7.2 (puertos daemons), §3 (principios P9/P10), §12 (ClusterIP), §18 (proceso asignación puertos)** |
| **Par Nexus Soberano formalizado** | **May 2026** | **bhnexus y banexus son una unidad compuesta (no daemons separados). bhnexus: :9444 WSS/mTLS + :9445 métricas. banexus: sin puertos TCP entrantes, solo cliente saliente WSS/mTLS hacia :9444** |

---

## 3. Contexto para Próxima Sesión

**El corpus técnico está completo al ~99.9%.** Las próximas sesiones deben enfocarse en:

1. **Desarrollo del producto** — implementación de fichas, SP-01 a SP-04
2. **RFC-004** — decisión ARB sobre rango ClusterIP (requiere reunión; pre-requisito identificado)
3. **RFC-003** — implementación Context Plane (bloquea en SP-04 al 100%)
4. **Inicio Corpus 2** — HUMAN-DOC-CONCEPTUAL puede iniciarse en paralelo

---

## Trazabilidad

| Sección | Extraída de | Notas |
|---|---|---|
| §1 Deuda técnica items resueltos | Sesiones Abr–May 2026 | 21 items resueltos en total |
| §1 Items pendientes | Sesiones Abr–May 2026 | RFC-004 nuevo item de Mayo 2026 |
| §2 Decisiones | Sesiones Abr–May 2026 | 8 nuevas decisiones de Mayo 2026 |
| §3 Contexto próxima sesión | Estado actual del proyecto | Actualizado post-PORT-CATALOG |

---

## Fuentes de Enriquecimiento V8

| Fuente | Ruta | Tipo | Detalle |
|---|---|---|---|
| BOS_V6_SBOS-016-NOTES.md | Procesar/ | V6 Base | Contenido completo preservado |

---

_SKULL · SBOS · SBOS-016-NOTES · V8 · Mayo 2026_
_Reemplaza: v1.4 (Mayo 2026)_
