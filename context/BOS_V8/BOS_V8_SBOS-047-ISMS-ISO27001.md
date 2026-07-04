# SBOS-047-ISMS-ISO27001
## SGSI: Sistema de Gestion de Seguridad de la Informacion — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. Proposito

Este documento establece el SGSI (Sistema de Gestion de Seguridad de la Informacion) de SKULL para el producto SBOS, alineado a ISO 27001:2022. El SGSI no es un documento estatico — es un sistema vivo cuya columna vertebral es el Ciclo PHVA (Planear-Hacer-Verificar-Actuar), compartido con ISO 9001:2015 (calidad) y toda la familia de normas ISO de sistemas de gestion.

### Alcance

El SGSI cubre SBOS como producto en dos dimensiones: (1) SKULL Systems como desarrollador — procesos de desarrollo, testing, firma Ed25519, distribucion. (2) Operacion en instalaciones de clientes — software SBOS procesando datos del cliente. SKULL es procesador de datos (GDPR/normativa iberoamericana). Clientes son controladores de datos.

## 2. El Ciclo PHVA como Columna Vertebral

El Ciclo PHVA (PDCA en ingles) no es un evento de una sola vez — es una retroalimentacion constante que aplica a TODAS las dimensiones del SBOS. Segun ISO 9001:2015 e ISO 27001:2022, las clausulas 4-10 mapean directamente al PHVA:

### Mapeo PHVA → ISO 27001:2022 → SBOS

| Fase PHVA | Clausulas ISO | Que significa | Implementacion SBOS |
|---|---|---|---|
| **PLANEAR** | 4 (Contexto), 5 (Liderazgo), 6 (Planificacion) | Establecer objetivos, identificar riesgos, definir controles | Registro de riesgos (§5), SoA con 20 controles (§4), politica firmada por direccion |
| **HACER** | 7 (Soporte), 8 (Operacion) | Implementar procesos, controles, capacitacion | Zero Trust (SBOS-031), 5 SPIs KC, IAM Installer con drift detection, Ed25519 supply chain |
| **VERIFICAR** | 9 (Evaluacion del desempeño) | Auditorias internas, monitoreo SLOs, medicion | kube-bench CIS semanal, Wazuh SIEM, SLOs seguridad (SBOS-031 §5), simulacro DR semestral (SBOS-033) |
| **ACTUAR** | 10 (Mejora) | Acciones correctivas, mejora continua | Post-mortems 48h post-P0, actualizacion runbooks, revision anual SGSI, cargo-audit en CI |

### El PHVA es continuo — no lineal

```
    PLANEAR ──────────► HACER
       ▲                    │
       │                    ▼
    ACTUAR ◄──────────── VERIFICAR
       │                    │
       └──── retroalimentacion constante ────┘

Cada incidente de seguridad, cada auditoria interna, cada simulacro DR
alimenta el ciclo → mejora los controles → reduce riesgos residuales
```

### PHVA aplicado a los procesos especificos del SBOS

| Proceso SBOS | PLANEAR | HACER | VERIFICAR | ACTUAR |
|---|---|---|---|---|
| **Desarrollo** | Definir estandares codigo (SBOS-018) | clippy, golangci-lint, cargo-audit en CI | SonarQube, Trivy scan | Corregir vulnerabilidades, actualizar deps |
| **Despliegue** | Criterios halt canary (SBOS-032) | Rollout 10%→50%→100% | Health checks, SLOs post-deploy | Rollback <30s si metricas degradan |
| **Identidad** | Definir H-RBAC, RolTemplates | bAuth sync KC↔Tryton | Drift detection automatico | Correccion drift, actualizar templates |
| **Infraestructura** | Definir SLOs (SBOS-032) | Prometheus, Grafana, Alertmanager | Alertas activas, error budgets | Escalar infra, optimizar VPA |
| **Backup/DR** | Definir RTO/RPO (SBOS-033) | pgBackRest, Velero, Bareos | Simulacro semestral | Ajustar SLAs si RTO real difiere |
| **Supply chain** | Firma Ed25519 obligatoria | Release Plane con firma | Verificacion en IAM Installer | Rotar claves si compromiso detectado |

### Enriquecimiento Smart*: PHVA en subproyectos Smart

| Proceso SBOS | PLANEAR | HACER | VERIFICAR | ACTUAR |
|---|---|---|---|---|
| **Fiscal (Smart Tax)** | Configurar certificados, definir jurisdicciones | biedata ejecuta cajas fiscales SIAT/AFIP/SAT | Circuit breaker, verificacion CUF, invariantes | Rotar certificados, ajustar formulas por sector |
| **Pagos (Smart Pay)** | Definir limites transaccionales, fuentes de fondos | bpay procesa transacciones via cola | Conciliacion automatica vs extractos | Reintentar fallos, alertar anomalias |
| **Tasas (Smart Rates)** | Definir fuentes de tasa, pares de conversion | Motor de cross rate actualiza cotizaciones | Verificacion contra fuentes oficiales | Ajustar fuentes si divergencia detectada |

## 3. Politica de Seguridad de la Informacion (para firma Direccion)

SKULL Systems reconoce que la informacion es un activo critico. La direccion se compromete a:

1. **Confidencialidad:** proteger informacion de clientes y negocio contra accesos no autorizados
2. **Integridad:** garantizar que la informacion no sea modificada sin autorizacion
3. **Disponibilidad:** asegurar acceso conforme a SLAs contractuales (SBOS-032)
4. **Cumplimiento legal:** regulaciones aplicables por pais de operacion
5. **Mejora continua:** revisar y mejorar el SGSI anualmente (ciclo PHVA)

Firma: _______ | Cargo: CTO | Fecha: _______

## 4. Declaracion de Aplicabilidad (SoA) — 20 Controles Criticos

| # | Control ISO 27001:2022 | Anexo A | Estado | Implementacion SBOS |
|---|---|---|---|---|
| 1 | Politicas seguridad | A.5.1 | ✅ | Esta politica + SBOS-031 Zero Trust |
| 2 | Gestion activos | A.5.9 | 🔄 | BCs como activos (SBOS-030) — falta registro formal |
| 3 | Control acceso | A.5.15 | ✅ | H-RBAC (bAuth) + KC OIDC |
| 4 | Gestion identidad | A.5.16 | ✅ | KC unico IdP + 5 SPIs custom |
| 5 | Autenticacion | A.5.17 | ✅ | JWT 5min + MFA + BehavioralScore SPI |
| 6 | Derechos privilegiado | A.5.18 | ✅ | Segregacion funciones + Vault secretos |
| 7 | Transferencia info | A.5.14 | ✅ | TLS todos endpoints, sin transmision terceros |
| 8 | Gestion vulnerabilidades | A.8.8 | 🔄 | cargo-audit — falta proceso formal parches |
| 9 | Gestion cambios | A.8.32 | ✅ | IAM Installer drift + Ed25519 + ARB |
| 10 | Proteccion malware | A.8.7 | ✅ | Wazuh SIEM + firma Ed25519 artefactos |
| 11 | Gestion logs | A.8.15 | ✅ | LGTM stack + Loki + audit_events bKernel |
| 12 | Sincronizacion relojes | A.8.17 | ✅ | NTP todos nodos (JWT depende tiempo sync) |
| 13 | Cifrado | A.8.24 | ✅ | TLS 1.3, Ed25519, Vault, LUKS |
| 14 | Seguridad redes | A.8.20 | ✅ | Zero Trust + Kong WAF + NetworkPolicies |
| 15 | Segregacion redes | A.8.22 | ✅ | Namespaces K8s + Calico deny-all |
| 16 | Backup/recuperacion | A.8.13 | ✅ | pgBackRest PITR + Velero + Bareos |
| 17 | Gestion incidentes | A.5.24 | 🔄 | Runbooks RK-001 a RK-014 — falta clasificacion formal |
| 18 | Notificacion brechas | A.5.26 | ✅ | Proceso por jurisdiccion |
| 19 | Continuidad negocio | A.5.30 | ✅ | DR SBOS-033 + simulacros semestrales |
| 20 | Cumplimiento legal | A.5.31 | 🔄 | GDPR parcial — falta mapeo completo por jurisdiccion |

**Resumen: 15 implementados, 5 parciales, 0 sin implementar.**

## 5. Registro de Riesgos (ISO 27005)

| # | Activo | Amenaza | P×I | Control | Residual |
|---|---|---|---|---|---|
| R-01 | Clave privada Ed25519 | Robo/compromiso | 2×5=10 | HSM/Vault, nunca en web server | 4 |
| R-02 | BDs clientes (PG) | Acceso no autorizado | 2×5=10 | PgBouncer + WAF + NetworkPolicies | 4 |
| R-03 | JWT Keycloak | Interceptacion/reuso | 1×4=4 | JWT 5min expiracion | 2 |
| R-04 | Slots WAL bKernel | Eliminacion accidental | 3×4=12 | Rol replicacion especifico + Vault | 6 |
| R-05 | Flota instalaciones | Fichas maliciosas | 1×5=5 | Ed25519 obligatorio + verificacion | 2 |
| R-06 | Logs auditoria | Manipulacion evidencia | 2×4=8 | Wazuh SIEM + MFA acceso S14 | 4 |
| R-07 | Datos personales KC | Brecha datos | 2×4=8 | KC patches auto + Wazuh | 4 |
| R-08 | bKernel daemon | Escalamiento privilegios | 1×5=5 | cargo-audit + sin puerto + NoNewPrivileges | 2 |

### Enriquecimiento V8: Nuevos riesgos Smart*

| # | Activo | Amenaza | P×I | Control | Residual |
|---|---|---|---|---|---|
| R-09 | Certificados fiscales SmartTax | Expiracion sin renovacion | 2×4=8 | Alerta 30 dias antes, renovacion automatica | 3 |
| R-10 | Transacciones SmartPay | Doble procesamiento | 1×5=5 | Idempotencia por idempotency_key, conciliacion diaria | 2 |
| R-11 | Tasas SmartRates | Manipulacion de fuente de tasa | 2×3=6 | Verificacion multi-fuente, alerta por divergencia >2% | 3 |

Escala: Bajo 1-4, Medio 5-9, Alto 10-14, Critico 15-25. Atencion inmediata (≥8): R-01, R-02, R-04, R-06, R-07, R-09.

## 6. Plan de Certificacion ISO 27001:2022

| Fase | Periodo | PHVA | Entregable |
|---|---|---|---|
| 1 Gap Analysis | Abr-May 2026 | PLANEAR | Inventario activos, evidencia controles, identificar gaps en 🔄 |
| 2 Remediacion | Jun-Sep 2026 | HACER | Gestion vulnerabilidades formal, incidentes formal, mapeo regulatorio BO/AR/MX, SoA firmada |
| 3 Auditoria interna | Oct-Nov 2026 | VERIFICAR | Informe auditoria, cierre no-conformidades |
| 4 Certificacion | Dic 2026-Mar 2027 | ACTUAR | Stage 1 (documental) + Stage 2 (en sitio) → Certificado 3 años |

### Post-certificacion: el ciclo no termina

```
Año 1: Certificacion obtenida → primer ciclo PHVA completo
Año 2: Auditoria de vigilancia (Stage 1 reducida) → VERIFICAR + ACTUAR
Año 3: Auditoria de vigilancia → VERIFICAR + ACTUAR
Año 4: Re-certificacion completa → nuevo ciclo PLANEAR desde contexto actualizado
```

## 7. Relacion ISO 9001:2015 (Calidad) con el SBOS

ISO 9001 y ISO 27001 comparten la misma estructura de alto nivel (Annex SL) y el mismo ciclo PHVA. El SBOS implementa principios de calidad ISO 9001 de forma nativa:

| Principio ISO 9001 | Implementacion SBOS |
|---|---|
| Enfoque al cliente | Seed file con identidad del cliente (SBOS-037), productos seleccionables por sector |
| Liderazgo | CTO firma politica, ARB mensual (SBOS-048) |
| Compromiso personas | Onboarding (SBOS-046), Anti Bus Factor (SBOS-021-ABF) |
| Enfoque a procesos | Fichas como procesos atomicos, DAG de dependencias |
| Mejora continua | PHVA en todo: canary rollout → SLOs → post-mortem → correccion |
| Toma decisiones basada en evidencia | SLIs medibles (SBOS-032), Prometheus+Grafana, error budgets |
| Gestion de relaciones | Bounded Contexts DDD (SBOS-030), contratos inter-daemon (SBOS-008) |

### La retroalimentacion del PHVA en el ciclo de vida del SBOS

```
PLANEAR: ADR-001 decide WAL como bus → define SLOs de lag <500ms
HACER: bKernel implementa CDC con Thread Pool Adaptativo
VERIFICAR: Prometheus mide lag real → Alertmanager alerta si >30s
ACTUAR: Si SLO se viola → post-mortem → ajustar batch_size o escalar CPU
  → Nuevo ciclo PLANEAR con umbrales actualizados
```

## 8. Revision Anual del SGSI

Enero de cada año. Incluye: resultados auditorias (internas/externas), estado riesgos (P×I actualizados), incidentes del año con lecciones aprendidas, cambios en negocio/tecnologia que requieran actualizar controles, objetivos SGSI para el proximo año, efectividad de las acciones correctivas implementadas.

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 Proposito | SBOS-030 v1.0 + investigacion | §1 alcance + PHVA como columna vertebral |
| §2 PHVA | Investigacion web | ISO 9001:2015 PDCA, ISO 27001:2022 clausulas 4-10, PECB guide |
| §3 Politica | SBOS-030 v1.0 | §2 (5 compromisos direccion) |
| §4 SoA | SBOS-030 v1.0 | §3 (20 controles con estado) |
| §5 Riesgos | SBOS-030 v1.0 | §4 (8 riesgos ISO 27005) |
| §6 Plan cert | SBOS-030 v1.0 + PHVA | §5 (4 fases) + mapeo a PHVA + post-certificacion |
| §7 ISO 9001 | Investigacion web + conocimiento SBOS | 7 principios ISO 9001 con implementacion SBOS |
| §8 Revision | SBOS-030 v1.0 | §6 (proceso anual) |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-030-ISMS-ISO27001-v1_0.md | Base ISMS V5 |
| Correlacion Smart* | Vulnerabilidades de subproyectos Smart* | Nuevos riesgos R-09 (certificados fiscales), R-10 (pagos), R-11 (tasas); PHVA extendido a procesos fiscales, pagos y tasas |

---

_SKULL · SBOS · SBOS-047-ISMS-ISO27001 · V8 Enriquecido · Mayo 2026 · CONFIDENCIAL_
