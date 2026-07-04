# SBOS-025-EXT — Proceso Formal del Architecture Review Board (ARB)
## Extensión de SBOS-025 — Catálogo de Decisiones Arquitectónicas

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-025-EXT-ARB
**Versión:** 1.0
**Estado:** ACTIVO
**Extiende:** SBOS-025 — Catálogo de Decisiones Arquitectónicas (ADR)
**Clasificación:** Especificación de Gobernanza — Arquitectura

---

## Índice

1. [Por qué un ARB formal](#1-por-que-arb-formal)
2. [Estructura y composición del ARB](#2-estructura-composicion)
3. [Cuándo es obligatorio un RFC](#3-cuando-obligatorio-rfc)
4. [Template RFC para GitHub Issue](#4-template-rfc)
5. [Proceso RFC → ADR](#5-proceso-rfc-adr)
6. [Índice de RFCs y ADRs](#6-indice-rfcs-adrs)

---

## 1. Por qué un ARB Formal

El veto de n8n (ADR-006 en SBOS-025) fue una decisión correcta tomada informalmente. El Principio 3 (solo licencias libres) fue el fundamento, pero el proceso de evaluación de la Sustainable Use License no está documentado — si alguien propone n8n de nuevo en el futuro, el único registro es "está vetado" sin evidencia del análisis.

El ARB existe para que **ninguna decisión arquitectónica de alto impacto se tome informalmente**. Cada decisión que podría arrepentirse en el futuro debe tener un registro de:
- Qué opciones se evaluaron
- Por qué se eligió lo que se eligió
- Qué trade-offs se aceptaron conscientemente
- Quién tomó la decisión y cuándo

El ARB no ralentiza el desarrollo — solo aplica a decisiones que, si se toman mal, cuestan semanas revertir.

---

## 2. Estructura y Composición del ARB

### 2.1 Miembros permanentes

| Rol | Responsabilidad | Autoridad |
|---|---|---|
| **CTO (Presidente)** | Preside las reuniones. Veto absoluto. | Puede rechazar cualquier RFC unilateralmente. Sin su voto, ningún RFC es aprobado. |
| **Arquitecto Lead** | Revisa el impacto técnico de cada RFC. Convierte los RFC aprobados a ADR. | Voto con peso 2x en decisiones técnicas. |
| **Rust Team Lead** | Representa los intereses de los daemons soberanos (bKernel, SBOS Data Integration, SBOS AI Tools). | Voto estándar. Veto en decisiones que afecten los daemons soberanos. |
| **IAM Installer Lead** | Representa los intereses del instalador, fichas y K8s. | Voto estándar. Veto en decisiones que afecten el IAM Installer o el sistema de fichas. |
| **Security Lead** | Evalúa el impacto de seguridad de cada RFC. | Veto en decisiones que degraden la postura Zero Trust. |

### 2.2 Rotación de miembros técnicos

Los tres líderes técnicos (Rust, IAM Installer, Security) rotan trimestralmente. El objetivo es que diferentes partes del equipo tengan exposición a las decisiones arquitectónicas globales.

### 2.3 Quórum y reglas de votación

- **Quórum mínimo para sesión ordinaria:** 3 miembros, incluyendo el CTO o el Arquitecto Lead
- **Aprobación simple:** mayoría de votos presentes
- **Aprobación con cambios breaking a Principios Inquebrantables:** unanimidad o voto del CTO
- **Rechazo expedito:** el CTO puede rechazar un RFC sin sesión si viola claramente un Principio Inquebrantable

### 2.4 Cadencia de reuniones

| Tipo | Frecuencia | Duración | Formato |
|---|---|---|---|
| Sesión ordinaria | Primer lunes de cada mes | 90 minutos | Síncrono (presencial o videoconferencia) |
| Sesión extraordinaria | A demanda por RFC urgente | 45 minutos | Videoconferencia |
| Review async | Para RFCs simples con consenso previo | Asíncrono | GitHub PR/Issue — 5 días hábiles de revisión |

---

## 3. Cuándo es Obligatorio un RFC

### 3.1 Criterios de RFC obligatorio

Un contribuidor DEBE abrir un RFC antes de implementar si su cambio cae en cualquiera de estas categorías:

**Categoría A — Cambios a Principios Inquebrantables (veto automático si no tiene RFC):**
- Propuesta de usar un sistema de autenticación diferente a Keycloak
- Propuesta de añadir una base de datos relacional diferente a PostgreSQL
- Propuesta de añadir una dependencia con licencia no libre (Sustainable Use, SSPL, BSL, Commons Clause)

**Categoría B — Cambios de alto impacto arquitectónico:**
- Cambios en el protocolo WAL / configuración de slots de replicación lógica
- Nuevas dependencias (crates Rust) en los daemons soberanos
- Cambios al canal de distribución Ed25519 / Release Plane
- Cambios de versión mayor de PostgreSQL (ver SBOS-022-PGMIG)
- Nuevas fichas que modifiquen S01 dataserver o S03 identityserver
- Cambios en el formato del manifest.yml o yaml_engine.yml de las fichas
- Cambios en el protocolo de comunicación entre IAM Installer y Core UI

**Categoría C — Nuevos componentes del sistema:**
- Cualquier nuevo daemon soberano (tipo bKernel / SBOS Data Integration / SBOS AI Tools)
- Cualquier nuevo servidor lógico (tipo S01-S15)
- Cualquier nueva integración tributaria en SBOS Data Integration

### 3.2 Cuándo NO es necesario un RFC

- Nuevas fichas de aplicación que no afectan servidores críticos (S01, S03)
- Cambios de versión menor o patch en dependencias
- Nuevas reglas YAML del bKernel (son configuración, no código)
- Nuevas rutas del SBOS AI Tools que no modifiquen el protocolo
- Correcciones de bugs sin impacto arquitectónico
- Cambios en documentación SBOS

### 3.3 Zona gris — cómo decidir

Ante la duda, la regla es: **si el cambio es difícil de revertir, necesita RFC**. Una nueva dependencia Rust que se propaga a 50 builds es difícil de quitar. Un nuevo archivo YAML de reglas del bKernel se puede eliminar en segundos.

---

## 4. Template RFC para GitHub Issue

Crear el RFC como un GitHub Issue en el repositorio SBOS con el tipo `architecture-decision`:

```markdown
## RFC-NNN: [Título descriptivo de la decisión propuesta]

**Autor:** @username
**Fecha:** YYYY-MM-DD
**Estado:** Draft | En revisión | Aprobado | Rechazado | Más información requerida
**Tipo:** Cambio Breaking | Nuevo Componente | Excepción a Principio | Mejora Arquitectónica
**Principio afectado:** 1-Keycloak | 2-PostgreSQL | 3-Licencias | Ninguno
**Categoría:** A | B | C (según §3.1)
**Urgencia:** Normal (próxima sesión mensual) | Alta (sesión extraordinaria requerida)

---

### Problema que motiva este RFC

_Describir el problema concreto que existe hoy. No la solución — el problema._

¿Qué limitación, deuda técnica o necesidad nueva nos trae aquí?

---

### Propuesta técnica

_Describir con precisión qué se propone implementar. Incluir:_
- ¿Qué cambia respecto al estado actual?
- ¿Qué componentes de SBOS se ven afectados?
- ¿Qué documentos SBOS deberán actualizarse?

---

### Alternativas evaluadas (mínimo 2)

_Para cada alternativa:_

**Alternativa 1: [Nombre]**
- Descripción: ...
- Por qué no se elige: ...

**Alternativa 2: [Nombre]**
- Descripción: ...
- Por qué no se elige: ...

---

### Impacto en componentes críticos

| Componente | ¿Afectado? | Descripción del impacto |
|---|---|---|
| bKernel / WAL / slots de replicación | Sí / No | ... |
| IAM Installer / sistema de fichas | Sí / No | ... |
| SBOS Data Integration / integraciones tributarias | Sí / No | ... |
| SBOS AI Tools / Ollama | Sí / No | ... |
| Keycloak / Vault / Kong | Sí / No | ... |
| PostgreSQL (esquema, slots, versión) | Sí / No | ... |
| Release Plane / firma Ed25519 | Sí / No | ... |

---

### Impacto en los Tres Principios Inquebrantables

- **Principio 1 (Solo Keycloak):** ¿Este cambio introduce o puede introducir otro sistema de autenticación?
- **Principio 2 (Solo PostgreSQL):** ¿Este cambio introduce otra base de datos relacional?
- **Principio 3 (Solo licencias libres):** ¿Las nuevas dependencias tienen licencia MIT, Apache 2.0, GPL o AGPL?

---

### Trade-offs conocidos

_¿Qué se sacrifica o complejiza con esta decisión? Ser honesto — el ARB busca decisiones conscientes, no perfectas._

---

### Criterios de éxito

_¿Cómo sabremos que esta decisión fue correcta? Métricas, comportamientos observables, fechas._

---

### Plan de rollback si falla

_Si la implementación produce problemas, ¿cómo se revierte? ¿Es reversible en < 1 hora?_

---

### Evidencia / prototipos / benchmarks

_Adjuntar cualquier evidencia técnica que apoye la propuesta: benchmarks, POCs, análisis de licencias._

---

### Checklist de completitud (para el autor)

- [ ] He leído los Tres Principios Inquebrantables del SBOS-000 y este RFC no los viola
- [ ] He identificado al menos 2 alternativas reales (no strawmen)
- [ ] He descrito el impacto en todos los componentes críticos afectados
- [ ] He definido criterios de éxito medibles
- [ ] He definido un plan de rollback
- [ ] He asignado la Categoría correcta (A, B o C) según §3.1 de SBOS-025-EXT-ARB

---

### Historial de revisiones del RFC

| Fecha | Autor | Cambio |
|---|---|---|
| YYYY-MM-DD | @username | Versión inicial |
```

---

## 5. Proceso RFC → ADR

### 5.1 Diagrama del proceso completo

```
AUTOR abre RFC en GitHub
          ↓
5 días hábiles de comentarios abiertos en GitHub
(cualquier miembro del equipo puede comentar)
          ↓
¿Consenso claro en los comentarios?
  ├── SÍ → Revisión async (sin sesión presencial necesaria)
  └── NO → Discusión en próxima sesión ARB mensual
          ↓
SESIÓN ARB — debate y votación
          ↓
DECISIÓN:
  ├── APROBADO → Arquitecto Lead convierte a ADR en 48h
  ├── RECHAZADO → RFC cerrado con motivo documentado
  └── MÁS INFO → RFC en espera, autor debe proveer información adicional
          ↓ (si APROBADO)
Arquitecto Lead crea ADR en SBOS-025 (formato estándar)
          ↓
CTO firma el ADR (comentario en el PR de GitHub)
          ↓
ADR publicado — implementación puede comenzar
```

### 5.2 Tiempos del proceso

| Etapa | Duración máxima | Responsable |
|---|---|---|
| Comentarios abiertos en GitHub | 5 días hábiles | Comunidad SBOS |
| Sesión ARB (si necesaria) | Próxima sesión mensual | ARB |
| Conversión RFC → ADR post-aprobación | 48 horas | Arquitecto Lead |
| RFC urgente (Categoría A con riesgo activo) | Sesión extraordinaria en 48h | CTO |

### 5.3 Formato del ADR resultante

Cuando un RFC es aprobado, el Arquitecto Lead crea el ADR en SBOS-025 con el siguiente formato estándar:

```markdown
## ADR-NNN: [Título de la decisión]

**Fecha:** YYYY-MM-DD
**Estado:** Aceptada
**RFC origen:** RFC-NNN (link a GitHub Issue)
**Autores:** @arquitecto-lead (formal), @autor-rfc (propuesta)
**CTO aprobó:** @cto — YYYY-MM-DD (comentario en PR #NNN)

### Contexto

_El problema que motivó esta decisión, extraído del RFC._

### Decisión

_Qué se decidió exactamente. Presente, activo: "Usamos X porque Y"._

### Alternativas rechazadas

| Alternativa | Razón del rechazo |
|---|---|
| Alternativa 1 | ... |
| Alternativa 2 | ... |

### Consecuencias positivas

_Qué habilita esta decisión para el sistema._

### Consecuencias negativas / trade-offs

_Qué se sacrifica o complejiza. Honesto y específico._

### Documentos relacionados

_SBOS-XXX que se actualizaron o deben actualizarse como resultado de esta decisión._
```

---

## 6. Índice de RFCs y ADRs

### 6.1 Índice de ADRs (ver SBOS-025 para contenido completo)

| ADR | Título | Estado | Fecha |
|---|---|---|---|
| ADR-001 | WAL de PostgreSQL como EventBus del sistema | Aceptada | 2024-Q1 |
| ADR-002 | Daemons soberanos como procesos systemd fuera de K8s | Aceptada | 2024-Q1 |
| ADR-003 | IAM Installer como daemon residente (no como script) | Aceptada | 2024-Q2 |
| ADR-004 | Keycloak como único proveedor de identidad | Aceptada | 2024-Q1 |
| ADR-005 | PostgreSQL como única base de datos relacional | Aceptada | 2024-Q1 |
| ADR-006 | Veto de n8n, SBOS AI Tools como reemplazo soberano | Aceptada | 2024-Q3 |
| ADR-007 | Firma Ed25519 de todos los artefactos del Release Plane | Aceptada | 2024-Q4 |
| ADR-008 | Arquitectura de fichas como unidad de despliegue soberana | Aceptada | 2024-Q2 |

### 6.2 RFCs activos (en proceso de revisión)

_(Esta sección se actualiza dinámicamente — ver GitHub Issues con label `architecture-decision`)_

| RFC | Título | Estado | Categoría | Autor | Fecha apertura |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

### 6.3 RFCs rechazados (registro histórico)

Los RFCs rechazados se mantienen como registro histórico. Un RFC rechazado no puede reabrirse sin nueva evidencia técnica sustancial.

| RFC | Título | Motivo rechazo | Fecha |
|---|---|---|---|
| — | — | — | — |

---

## 7. Casos Especiales

### 7.1 RFC urgente por vulnerabilidad de seguridad

Si un RFC es motivado por una vulnerabilidad de seguridad activa:
1. El Security Lead puede convocar una sesión extraordinaria del ARB en 24 horas
2. El quórum mínimo se reduce a CTO + Security Lead
3. La decisión es válida con esos dos votos para casos de emergencia
4. El ADR formal se completa dentro de las 72h post-decisión

### 7.2 Excepciones temporales a los Principios Inquebrantables

Si un cliente requiere en contrato una excepción a los Principios Inquebrantables (por ejemplo, usar MySQL porque ya tiene una inversión existente):
1. El RFC debe ser de Categoría A
2. Requiere unanimidad del ARB + firma del CEO (no solo del CTO)
3. La excepción tiene alcance limitado al cliente específico y fecha de expiración
4. Se documenta como ADR con estado `Excepción Temporal` — nunca como `Aceptada` general

### 7.3 Qué pasa si alguien implementa sin RFC

Si un contribuidor implementa un cambio de Categoría A, B o C sin RFC previo:
1. El PR es bloqueado por el Arquitecto Lead con label `requires-rfc`
2. El contribuidor debe abrir el RFC retroactivo
3. Si el ARB rechaza el RFC, el cambio debe ser revertido
4. El incidente se registra — dos incidentes resultan en suspensión del acceso de merge

---

## 8. Referencias Cruzadas

- **SBOS-025** — Catálogo de ADRs (el output principal del ARB)
- **SBOS-018** — Estándares (el proceso de RFC se integra con el pipeline CI/CD)
- **SBOS-000** — Índice y Glosario (los Tres Principios Inquebrantables)
- **SBOS-021** — Onboarding (los nuevos contribuidores leen este documento en la semana 1)

---

## 9. Registro de Cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | CTO + Arquitecto Lead | Documento inicial — estructura ARB, criterios de RFC obligatorio, template RFC completo, proceso RFC → ADR |

---

*SKULL · SBOS · SBOS-025-EXT-ARB · v1.0 · Marzo 2026*
*Extiende: SBOS-025 — Catálogo de Decisiones Arquitectónicas*
*Clasificación: Especificación de Gobernanza — Arquitectura*
