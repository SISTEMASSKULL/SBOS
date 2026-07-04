# SBOS-001-OKR — OKRs Estratégicos de SBOS para 12 Meses
## Sección para insertar en SBOS-001 (Visión) y SBOS-017 (Roadmap)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-001-OKR
**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Gobierno Estratégico — OKRs
**Complementa:** SBOS-001-VISION-v4_0.md (sección §nueva OKRs Estratégicos) y SBOS-017-Roadmap-v2_0.md
**Insertar en:** SBOS-001 como sección §nueva y referenciado en SBOS-017

---

## OKRs Estratégicos de SBOS — Marzo 2026 a Marzo 2027

### Proceso de revisión

Los OKRs se revisan mensualmente en la reunión de liderazgo (CTO + CEO + Arquitecto Lead). Se usa la escala de Google: 0.0-1.0, donde 0.7 es el objetivo esperado (0.0 = fallido, 1.0 = superado expectativas).

Al final de cada trimestre se hace una revisión formal con ajuste de fechas si es necesario. Los OKRs no se modifican durante el trimestre en curso — solo se ajustan al inicio del siguiente.

---

## OBJ-1 — Adopción validada del producto

**Propósito:** demostrar que SBOS puede instalarse y ser operado productivamente por clientes reales, no solo en staging de SKULL.

### KR-1.1 — Clientes activos en producción

| Ítem | Detalle |
|------|---------|
| **Definición de "cliente activo"** | Instalación de SBOS en producción con el cliente usando activamente al menos 3 aplicaciones del stack (ej: Tryton + OrangeHRM + bKernel procesando WAL) |
| **Valor actual** | 0 (ningún cliente en producción) |
| **Meta Q2 2026** | 1 cliente activo (cliente piloto v0.9) |
| **Meta Q4 2026** | 3 clientes activos en producción |
| **Método de medición** | Registro en CRM de SKULL + confirmación del cliente de uso activo |
| **Frecuencia de revisión** | Mensual |
| **Responsable** | CEO |

### KR-1.2 — Tiempo de instalación completa (Fases 0-8)

| Ítem | Detalle |
|------|---------|
| **Definición** | Tiempo desde el inicio del bootstrap hasta que las Fases 0-8 completan sin errores y el sistema es declarado operativo |
| **Valor actual** | Sin medición formal (instalación manual actualmente) |
| **Meta Q3 2026** | ≤ 8 horas en el 80% de los casos de instalación |
| **Método de medición** | Log de timestamps del IAM Installer: `installation_started_at` → `phase_8_completed_at` |
| **Frecuencia de revisión** | Por cada nueva instalación |
| **Responsable** | DevOps Lead |

### KR-1.3 — Tiempo de onboarding del administrador del cliente

| Ítem | Detalle |
|------|---------|
| **Definición** | Tiempo desde la entrega del sistema hasta que el administrador TI del cliente puede realizar operaciones diarias sin asistencia de SKULL (crear/desactivar usuarios, revisar estado del stack, interpretar alertas básicas) |
| **Valor actual** | Sin medición formal |
| **Meta Q3 2026** | ≤ 5 días laborales |
| **Método de medición** | Encuesta post-onboarding al administrador del cliente (escala 1-5 + fecha de primera operación autónoma) |
| **Frecuencia de revisión** | Por cada nuevo cliente |
| **Responsable** | CTO + Arquitecto Lead |

---

## OBJ-2 — Excelencia operacional verificada por evidencia

**Propósito:** pasar de SLOs declarados a SLOs demostrados con evidencia medida en producción.

### KR-2.1 — Disponibilidad del sistema en producción

| Ítem | Detalle |
|------|---------|
| **Métrica** | Disponibilidad mensual del sistema completo |
| **SLO de referencia** | ≥ 99.9% mensual (SBOS-024 §3) |
| **Meta** | SLO alcanzado en Q3-Q4 2026 (meses de octubre, noviembre, diciembre 2026) |
| **Valor actual** | Sin medición en producción (solo staging) |
| **Método de medición** | `(1 - uptime_probe_success_sum / uptime_probe_total) * 100` en Prometheus. Panel dedicado en Grafana. |
| **Frecuencia de revisión** | Mensual — comparar % real vs SLO 99.9% |
| **Responsable** | SRE Lead |

### KR-2.2 — Throughput medido del bKernel en producción

| Ítem | Detalle |
|------|---------|
| **Métrica** | `rate(bkernel_events_processed_total[1m]) * 60` en Prometheus del cliente |
| **SLO de referencia** | ≥ 1000 eventos/minuto (SBOS-024 §2) |
| **Meta** | SLO medido y documentado en al menos 1 instalación de producción durante Q3 2026 |
| **Valor actual** | Sin evidencia de producción — solo pruebas de carga en staging (SBOS-024 §11) |
| **Método de medición** | Reporte mensual de Prometheus exportado del cliente y registrado en SBOS-024 §11 |
| **Frecuencia de revisión** | Mensual |
| **Responsable** | SRE Lead |

### KR-2.3 — MTTR para incidentes P0

| Ítem | Detalle |
|------|---------|
| **Definición de P0** | Sistema completo inoperativo (PostgreSQL, Keycloak o Kong caídos) para el cliente |
| **Meta** | MTTR ≤ 60 minutos (alineado con RTO contractual de SBOS-024 §3) |
| **Valor actual** | Sin historial de incidentes P0 (no hay clientes en producción aún) |
| **Método de medición** | Registro de incidentes en GitLab Issues con labels `P0` + `incident`. MTTR = tiempo entre detección y resolución. |
| **Frecuencia de revisión** | Por cada incidente P0 + revisión trimestral del promedio |
| **Responsable** | SRE Lead + CTO |

---

## OBJ-3 — Madurez técnica y certificación

**Propósito:** elevar la calificación del Framework Enterprise de 101/150 a ≥ 137/150.

### KR-3.1 — Calificación Framework Enterprise 2026

| Ítem | Detalle |
|------|---------|
| **Valor actual** | 101/150 (67.3%) — Nivel 3 Gestionado |
| **Meta Q4 2026** | ≥ 137/150 (91.3%) — Nivel 4 Optimizado |
| **Método de medición** | Re-evaluación formal con el mismo auditor/metodología del Framework Enterprise 2026 (prompt VAL-02) |
| **Frecuencia de revisión** | Evaluación formal al cierre del año |
| **Responsable** | Arquitecto Lead |

### KR-3.2 — Cobertura de tests

| Ítem | Detalle |
|------|---------|
| **Umbrales meta** | Módulos Dominio IAM Installer ≥ 85% · bKernel Rule Engine ≥ 80% · FICHA_LINTER ≥ 90% |
| **Valor actual** | Sin medición formal (no hay pipeline de cobertura activo) |
| **Meta Q3 2026** | Todos los umbrales de SBOS-018-TEST §5 activos y en verde en el pipeline CI/CD |
| **Método de medición** | Dashboard SonarQube en S14 opsserver — panel de cobertura por proyecto |
| **Frecuencia de revisión** | Semanal (automático via pipeline CI/CD) |
| **Responsable** | Dev Lead |

### KR-3.3 — Proceso ISO 27001 iniciado

| Ítem | Detalle |
|------|---------|
| **Hito** | Declaración de Aplicabilidad (SoA) firmada por dirección con los 20 controles críticos identificados (SBOS-030) |
| **Valor actual** | Sin proceso ISMS iniciado |
| **Meta Q3 2026** | SoA firmada por CTO + CEO antes del 30 de septiembre 2026 |
| **Método de medición** | Existencia del documento SBOS-030 con SoA firmada + evidencia de gap analysis completado |
| **Frecuencia de revisión** | Hito puntual — verificar en revisión Q3 |
| **Responsable** | CTO + Dir. Legal |

---

## OBJ-4 — Cobertura tributaria y bus factor

**Propósito:** eliminar los dos riesgos operacionales más urgentes: dependencia de biedata Bolivia y Bus Factor = 1 en daemons soberanos.

### KR-4.1 — biedata Bolivia SIAT en producción

| Ítem | Detalle |
|------|---------|
| **Definición** | biedata procesando facturas reales a través de la API del SIN/SIAT en modo producción — no sandbox |
| **Evidencia requerida** | Al menos 10 facturas autorizadas con código de autorización real del SIN |
| **Valor actual** | biedata Bolivia en desarrollo / sandbox |
| **Meta Q2 2026** | biedata Bolivia operativo en producción con al menos 1 cliente |
| **Método de medición** | Evidencia de autorizaciones reales en `biedata_db.authorizations` + confirmación del cliente |
| **Frecuencia de revisión** | Hito puntual — verificar en revisión Q2 |
| **Responsable** | biedata Team |

### KR-4.2 — Bus Factor ≥ 2 en todos los daemons soberanos

| Ítem | Detalle |
|------|---------|
| **Definición** | Cada daemon soberano (bKernel, biedata, bCompass) tiene un propietario principal + al menos un co-propietario que pasó el ejercicio de validación de SBOS-021 §10.4 |
| **Valor actual** | Bus Factor = 1 en todos los daemons |
| **Meta Q3 2026** | Bus Factor ≥ 2 con co-propietarios que aprobaron los ejercicios de validación en SBOS-021 §10.5 |
| **Método de medición** | Tabla de propiedad de SBOS-021 §10.3 completa con propietario + co-propietario + fecha de aprobación del ejercicio |
| **Frecuencia de revisión** | Trimestral |
| **Responsable** | CTO |

### KR-4.3 — ADR catalog con ≥ 12 decisiones formalizadas

| Ítem | Detalle |
|------|---------|
| **Valor actual** | 8 ADRs (SBOS-025 v1.0) |
| **Meta Q2 2026** | ≥ 12 ADRs formalizadas en SBOS-025 |
| **Método de medición** | Count de ADRs con estado "Aceptada" en SBOS-025 |
| **Frecuencia de revisión** | Mensual en reunión ARB |
| **Responsable** | Arquitecto Lead |

---

## Resumen de OKRs

| Objetivo | KR | Meta | Fecha | Responsable |
|----------|-----|------|-------|-------------|
| OBJ-1 Adopción | KR-1.1 | 3 clientes activos | Q4 2026 | CEO |
| OBJ-1 Adopción | KR-1.2 | Instalación ≤ 8h en 80% casos | Q3 2026 | DevOps Lead |
| OBJ-1 Adopción | KR-1.3 | Onboarding admin ≤ 5 días | Q3 2026 | CTO |
| OBJ-2 Operacional | KR-2.1 | Disponibilidad ≥ 99.9% | Q3-Q4 2026 | SRE Lead |
| OBJ-2 Operacional | KR-2.2 | bKernel ≥ 1000 ev/min medido | Q3 2026 | SRE Lead |
| OBJ-2 Operacional | KR-2.3 | MTTR P0 ≤ 60 min | Q4 2026 | SRE Lead |
| OBJ-3 Madurez | KR-3.1 | Framework ≥ 137/150 | Q4 2026 | Arquitecto Lead |
| OBJ-3 Madurez | KR-3.2 | Cobertura tests activa | Q3 2026 | Dev Lead |
| OBJ-3 Madurez | KR-3.3 | ISO 27001 SoA firmada | Q3 2026 | CTO |
| OBJ-4 Tributario | KR-4.1 | biedata Bolivia SIAT prod | Q2 2026 | biedata Team |
| OBJ-4 Tributario | KR-4.2 | Bus Factor ≥ 2 daemons | Q3 2026 | CTO |
| OBJ-4 Tributario | KR-4.3 | ≥ 12 ADRs formalizadas | Q2 2026 | Arquitecto Lead |

---

*SKULL · SBOS · SBOS-001-OKR · v1.0 · Marzo 2026*
*Insertar como sección §OKRs en SBOS-001-VISION y referenciar desde SBOS-017-ROADMAP §nueva*
