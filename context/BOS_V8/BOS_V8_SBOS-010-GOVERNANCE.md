# SBOS-010-GOVERNANCE
## Gobernanza — Estandar HUMAN-DOC (Enriquecido V8)
### SKULL · SBOS v1.3-V8 · Mayo 2026

---

## 1. HITL (Human-In-The-Loop)

**Modelo de desarrollo:** Ingenieria Aumentada con dos humanos reales + Agentes de Dominio. Ver SBOS-046-ONBOARDING §0 para la descripcion completa del modelo.

| Rol | Persona | Alias | Delegado | Alcance |
|---|---|---|---|---|
| CTO | **Ivan Villanueva** | Super Usuario | — | Decisiones arquitectonicas finales + ADRs |
| CEO | **Ivan Villanueva** | Super Usuario | — | Decisiones de negocio y mercado |
| Arquitecto Lead | **Ivan Villanueva** | Super Usuario | — | ADRs, estandares tecnicos, ARB |
| sbos-admin (Core UI) | **Ivan Villanueva** | Super Usuario | — | Operaciones cat.3, desinstalaciones, governance dual-control |
| sbos-operator (Core UI) | **Ivan Villanueva** | Super Usuario | — | Instalaciones, repairs, updates |
| ARB (Architecture Review Board) | **Ivan Villanueva** | Super Usuario | — | RFC + aprobacion ADRs |
| **Administrador de Dominios** | **Juan Perez** | — | Ivan Villanueva | Operacion del sistema cuando Ivan no esta disponible. Supervision y validacion de Agentes de Dominio. Acceso: sbos-operator (todos los dominios) → sbos-admin tras validacion por equipo (ver SBOS-046-ONBOARDING §2.4) |

### Responsabilidades de Juan Perez como Administrador de Dominios

Juan Perez puede ejecutar, con apoyo de los Agentes de Dominio del sistema:
- Diagnostico de incidentes P2 y P3 en cualquier equipo
- Operaciones de mantenimiento de fichas (install, repair, update) cat. 1 y cat. 2
- Validacion de PRs de mediana complejidad en los equipos donde ha completado el ejercicio de validacion
- Escalacion informada a Ivan en incidentes P0 y P1

Juan Perez NO puede, sin aprobacion explicita de Ivan:
- Aprobar ADRs ni RFCs arquitectonicos
- Ejecutar operaciones cat.3 (desinstalar datos criticos, eliminar tenants)
- Modificar principios inquebrantables (SBOS-004-RULES §1)
- Acceder a claves Ed25519 del Release Plane ni a unseal keys de Vault

### Politica de escalacion

Cuando una decision implica conflicto entre roles, Ivan Villanueva aplica el siguiente orden de precedencia:

1. **Principios Inquebrantables** (SBOS-004-RULES §1) — maxima prioridad, nunca se negocian
2. **Seguridad y soberania de datos** (SBOS-001-VISION §6, restricciones R1–R15)
3. **Viabilidad tecnica a largo plazo**
4. **Velocidad de entrega**

### Condicion de transicion de Juan Perez

Juan Perez adquiere acceso sbos-admin en un equipo cuando completa el ejercicio de validacion del equipo (SBOS-046-ONBOARDING §2.4). El acceso es por equipo, no global — un co-propietario validado en Equipo BOS no tiene automaticamente sbos-admin en Equipo KERNEL.

---

## 2. Architecture Review Board (ARB)

- Reunion mensual
- Quorum: CTO + Arquitecto Lead + 1 representante de dominio
- Proceso: RFC (GitHub Issue con label `architecture-decision`) → 5 dias habiles revision → ARB decide → ADR formalizado en 48h
- ADR requerido cuando: afecta principios inquebrantables (KC, PG, licencias), modifica WAL/slots, introduce dependencias en daemons soberanos, cambia canal Ed25519, impacta S01/S03, **o cambia modelo de licenciamiento/distribucion de un componente del stack**

---

## 3. Normas y Estandares Aplicables

| Norma | Ambito | Estado |
|---|---|---|
| ISO 27001:2022 | SGSI completo | En proceso — SoA en SBOS-047 (15 implementados, 5 parciales) |
| ISO 9001:2015 | Calidad (PHVA) | Principios implementados — ver SBOS-047 §7 |
| NIST SP 800-207 | Zero Trust | Implementado — 7 principios cumplidos (ver SBOS-031 §1) |
| CIS Kubernetes Benchmark | Hardening K8s | Level 1 PASS — verificacion semanal (kube-bench) |
| OWASP Top 10 | Seguridad web | ModSecurity en Kong (ver SBOS-031 §2 V1) |
| SLSA | Supply chain | Ed25519 en Release Plane (ver SBOS-041) |
| NIST SP 800-63B | Autenticacion | Implementado en Keycloak SPIs (ver SBOS-029) |

---

## 4. Ciclos PDCA

### En construccion (desarrollo)
- Sprint review: quincenal
- ARB: mensual
- Re-evaluacion Framework Enterprise: anual

### En produccion
- Health check fichas: cada 30 segundos (IAM Installer HEALTH_CHECKER)
- Reconciliacion drift: cada 300 segundos (IAM Installer RECONCILE_SCHEDULER)
- Backup verificacion: diario (pgBackRest + Velero)
- Simulacro DR: semestral (SBOS-033-BACKUP-DR §5)
- Rotacion secrets: cada 90 dias (Vault)
- kube-bench CIS: semanal
- Auditoria de drift bAuth: cada 60 segundos (sync_status PENDING/SYNCED/DRIFT/ERROR)

---

## 5. Metricas de Salud

| Metrica | Frecuencia | Umbral alerta | Runbook |
|---|---|---|---|
| Disponibilidad sistema | Continua | < 99.9% mensual | RK-001 a RK-006 |
| Disponibilidad KC | Continua | < 99.99% mensual | RK-002 |
| bKernel throughput | Continua | < 1000 ev/min | RK-003 |
| WAL lag | Continua | > 500ms P99 | RK-004 |
| DLQ pending | Continua | > 10 eventos | RK-003 |
| Backup success | Diario | Cualquier fallo | RK-011 |
| CIS compliance | Semanal | Cualquier FAIL Level 1 | sbos-compliance-check |
| bAuth sync_status | Cada 60s | DRIFT o ERROR | bAuth drift detection |
| Disco por nodo | Continua | > 85% | RK-005 |
| TLS expiry | Continua | < 7 dias | RK-006 |

---

## 6. OKRs (Gobierno Estrategico)

Revision mensual (CTO + CEO + Arquitecto Lead). Escala Google 0.0-1.0. Ajuste trimestral.
Ver detalle completo en SBOS-001-VISION §10.

---

## 7. Politica de Aprobaciones

Define que nivel de aprobacion requiere cada tipo de cambio en el sistema.

### Operaciones en Fichas (Core UI + bosctl)

| Tipo de operacion | Governance cat. | Aprobadores requeridos | Proceso |
|---|---|---|---|
| Instalar/actualizar ficha estandar | 1 | sbos-operator (1 persona) | Accion directa en Core UI |
| Probe (dry-run) antes de instalar | 1 | sbos-operator | Accion directa |
| Repair no invasivo (restart pod) | 1 | sbos-operator | Accion directa |
| Repair invasivo (criticality: true) | 2 | sbos-admin (1 persona) | Pantalla de diagnostico + confirmacion explicita |
| Escalar deployment a cero | 2 | sbos-admin (1 persona) | Diagnostico + confirmacion |
| Desinstalar ficha cat. 1-2 | 2 | sbos-admin (1 persona) | Diagnostico + backup verificado + string confirmacion |
| Desinstalar ficha cat. 3 (critica) | 3 | 2 sbos-admin distintos | Diagnostico + backup + doble aprobacion (ventana 60 min) |
| Drenar nodo (kubeadm) | 3 | 2 sbos-admin distintos | Doble aprobacion + ventana mantenimiento |
| Eliminar namespace | 3 | 2 sbos-admin distintos | Solo ARB puede autorizar en produccion |

> **Nota sobre Juan Perez:** Juan Perez puede ejecutar operaciones cat. 1 y cat. 2 en los equipos donde ha completado el ejercicio de validacion. Las operaciones cat. 3 siempre requieren Ivan Villanueva como uno de los dos sbos-admin.

### Operaciones Arquitectonicas

| Tipo de cambio | Aprobadores | Proceso | Documentacion |
|---|---|---|---|
| ADR nuevo | CTO + Arquitecto Lead + 1 dominio | RFC 5 dias → ARB mensual → formalizar 48h | ADR en SBOS-006 + SBOS-048 |
| Cambio en Release Plane | CTO | Pipeline CI/CD firmado + Ed25519 | Actualizar SBOS-041 |
| Cambio de licencia de componente | ARB completo | RFC urgente si licencia vetada | ADR obligatorio |
| Nuevo servidor logico (S16+) | ARB | RFC estandar | Actualizar SBOS-005, SBOS-007 |

### Operaciones de Identidad

| Tipo de cambio | Aprobadores | Proceso |
|---|---|---|
| Crear/editar RolTemplate | sbos-admin | Core UI — PAP del RolFramework |
| Asignar RolTemplate a usuario | sbos-admin | Core UI con confirmacion |
| Delegacion temporal de rol | sbos-admin + propietario delegante | Core UI + limite 21 dias max |
| Suspension de tenant (realm) | CTO o delegado | PUT realm enabled: false via bAuth |
| Baja definitiva de tenant | CTO + aprobacion cliente | Proceso formal semana -2 / dia 0 / dia 1 |

### Categorias de Governance en Fichas

| Categoria | Definicion | Ejemplos |
|---|---|---|
| Cat. 1 | Impacto bajo — reversible facilmente | redis, minio, grafana, bSearch |
| Cat. 2 | Impacto medio — reversible con trabajo | kong, nginx, linkerd, apps negocio |
| Cat. 3 | Impacto alto — datos o acceso critico | postgresql, keycloak, vault, tryton |

---

## 8. Smart* Enriquecimiento — Gobernanza Visual del Ecosistema (SBOS IAM Style)

El subproyecto SBOS IAM Style define una gobernanza visual que complementa la gobernanza arquitectonica:

### Jerarquia de gobernanza visual

| Nivel | Autoridad | Responsabilidad |
|---|---|---|
| ForUI (Flutter/Dart) | Fuente de verdad unica (SSOT) | Define colores, tipografia, iconos, radios, bordes, tokens |
| Sakai/PrimeVue (Vue 3.5) | Contraparte web primaria | Deriva valores desde ForUI |
| Apps del stack (PHP, Tryton, terceros) | Receptores | Se adecuan a los valores de ForUI sin redefinir |

### Principio de gobernanza visual

Lo que ForUI define se adopta en todo el ecosistema sin excepcion. Ninguna aplicacion puede redefinir colores, tipografia o espaciado por iniciativa propia. Los cambios visuales siguen el flujo:

```
Propuesta de cambio → Design Lead evalua → Implementacion en ForUI (SSOT) → 
Derivacion automatica a Sakai/PrimeVue → Propagacion a apps del stack
```

### Gobernanza de acentos

El sistema de acentos permite a cada tenant personalizar su identidad visual sin romper la coherencia del ecosistema. Los acentos estan limitados a: color primario (matiz H ±15), color secundario (derivado), y logo. El resto de tokens son fijos y gestionados por ForUI.

---

## 9. Smart* Enriquecimiento — Gobernanza de Subproyectos

Cada subproyecto Smart* opera bajo la misma estructura de gobernanza del SBOS central, con las siguientes adaptaciones:

| Subproyecto | Governance cat. fichas | Aprobador tecnico | ARB aplicable |
|---|---|---|---|
| SmartTax | Cat. 2 (datos fiscales) | Arquitecto Lead + biedata owner | Si (cambios en cajas SIAT) |
| SmartORC | Cat. 1 (correspondencia) | Arquitecto Lead | Si (cambios en rutas WAL) |
| SmartVaultFlow | Cat. 2 (custodia documental) | Arquitecto Lead | Si (cambios en politica de firmas) |
| SmartPay | Cat. 2 (transacciones) | Arquitecto Lead + bKernel owner | Si (cambios en eventos de pago) |
| SmartRates | Cat. 1 (pricing) | Arquitecto Lead | No (solo notificacion) |
| SmartReport | Cat. 1 (reportes) | Arquitecto Lead | No |
| SmartPortfolio | Cat. 1 (catalogo) | Arquitecto Lead | No |

### Reglas de gobernanza para subproyectos

1. Todo subproyecto Smart* debe cumplir las reglas de acoplamiento SBOS (Manual de Acoplamiento)
2. Los datos nunca salen de la infraestructura del cliente — ni siquiera entre subproyectos
3. Cada subproyecto tiene su propia BD dentro del mismo PostgreSQL del tenant
4. La autenticacion se delega a Keycloak — ningun subproyecto tiene login propio
5. Los subproyectos se comunican via bKernel (WAL), no via llamadas directas
6. Todo cambio en la interfaz visual debe pasar por ForUI (SSOT visual)

---

## ENRIQUECIMIENTO SBOS (Primera Versión)

### SBOS-025-010-1: Estructura del ARB (desde SBOS-025-ARB-Proceso.md)

**Miembros permanentes:**

| Rol | Responsabilidad | Autoridad |
|---|---|---|
| CTO (Presidente) | Preside reuniones. Veto absoluto. | Sin su voto, ningun RFC es aprobado |
| Arquitecto Lead | Revisa impacto tecnico. Convierte RFC aprobados a ADR | Voto 2x en decisiones tecnicas |
| Rust Team Lead | Representa daemons soberanos (bKernel, biedata, bCompass) | Veto en decisiones que afecten daemons |
| IAM Installer Lead | Representa instalador, fichas y K8s | Veto en decisiones que afecten IAM Installer |
| Security Lead | Evalua impacto de seguridad | Veto en decisiones que degraden Zero Trust |

**Rotacion:** los 3 lideres tecnicos rotan trimestralmente. **Quorum:** 3 miembros incluyendo CTO o Arquitecto Lead. **Aprobacion simple:** mayoria de votos presentes. **Cambios a Principios Inquebrantables:** unanimidad o voto CTO. **Rechazo expedito:** CTO puede rechazar RFC sin sesion si viola un Principio.

**Cadencia:** Sesion ordinaria primer lunes de cada mes (90 min). Extraordinaria a demanda (45 min). Review async para RFCs simples (5 dias habiles).

### SBOS-025-010-2: Categorias de RFC Obligatorio (desde SBOS-025-ARB-Proceso.md)

**Categoria A** (Principios Inquebrantables -- veto automatico sin RFC): autenticacion diferente a Keycloak, BD diferente a PostgreSQL, dependencia con licencia no libre (SSPL, BSL, Sustainable Use).

**Categoria B** (Alto impacto arquitectonico): cambios en protocolo WAL/slots, nuevas dependencias Rust en daemons, cambios en canal Ed25519/Release Plane, migracion mayor PG, nuevas fichas en S01/S03, cambios en manifest.yml/yaml_engine.yml, cambios en protocolo IAM Installer <-> Core UI.

**Categoria C** (Nuevos componentes): nuevo daemon soberano, nuevo servidor logico (S16+), nueva integracion tributaria en biedata.

**Cuando NO es necesario RFC:** nuevas fichas de app sin afectar S01/S03, cambios minor/patch en dependencias, nuevas reglas YAML bKernel, nuevas rutas bCompass sin modificar protocolo, bugfixes sin impacto arquitectonico, cambios en documentacion.

**Regla de zona gris:** si el cambio es dificil de revertir, necesita RFC.

### SBOS-025-010-3: Proceso RFC -> ADR (desde SBOS-025-ARB-Proceso.md)

**Flujo completo:**
```
Autor abre RFC en GitHub (issue con label architecture-decision)
  -> 5 dias habiles comentarios abiertos
  -> Consenso claro? SI: review async | NO: sesion ARB mensual
  -> Sesion ARB debate y votacion
  -> APROBADO: Arquitecto Lead convierte a ADR en 48h
  -> RECHAZADO: RFC cerrado con motivo documentado
  -> MAS INFO: RFC en espera, autor provee info adicional
```

**Tiempos:** Comentarios 5 dias habiles. Sesion ARB proxima mensual. Conversion RFC->ADR post-aprobacion 48h. RFC urgente: sesion extraordinaria en 48h.

**Template RFC** (12 secciones via GitHub Issue): Problema, Propuesta tecnica, Alternativas evaluadas (min 2), Impacto en componentes criticos, Impacto en 3 Principios Inquebrantables, Trade-offs, Criterios de exito, Plan de rollback, Evidencia/prototipos, Checklist completitud.

**Formato ADR resultante:** Contexto, Decision (presente activo), Alternativas rechazadas (tabla), Consecuencias positivas, Consecuencias negativas/trade-offs, Documentos relacionados. CTO firma como comentario en PR.

### SBOS-025-010-4: Indice de ADRs y Casos Especiales (desde SBOS-025-ARB-Proceso.md)

**ADRs formalizados:**

| ADR | Titulo | Estado |
|-----|--------|--------|
| ADR-001 | WAL de PostgreSQL como EventBus del sistema | Aceptada |
| ADR-002 | Daemons soberanos como systemd fuera de K8s | Aceptada |
| ADR-003 | IAM Installer como daemon residente | Aceptada |
| ADR-004 | Keycloak como unico proveedor de identidad | Aceptada |
| ADR-005 | PostgreSQL como unica BD relacional | Aceptada |
| ADR-006 | Veto de n8n, bCompass como reemplazo soberano | Aceptada |
| ADR-007 | Firma Ed25519 de artefactos Release Plane | Aceptada |
| ADR-008 | Arquitectura de fichas como unidad de despliegue | Aceptada |

**RFCs rechazados** se mantienen como registro historico. No pueden reabrirse sin nueva evidencia tecnica sustancial.

**Casos especiales:**

| Caso | Procedimiento |
|------|--------------|
| RFC urgente por vulnerabilidad | Security Lead convoca sesion extraordinaria en 24h. Quorum minimo: CTO + Security Lead |
| Excepcion temporal a Principios | RFC Cat A. Unanimidad ARB + firma CEO. Alcance limitado a cliente especifico con fecha de expiracion. ADR con estado "Excepcion Temporal" |
| Implementar sin RFC (Cat A/B/C) | PR bloqueado con label requires-rfc. RFC retroactivo obligatorio. Si ARB rechaza, cambio revertido. Dos incidentes = suspension de merge |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §1 HITL — Ivan Villanueva | SBOS-COMPLETITUD-v2 §2 B2.2 | Super Usuario alias + politica escalacion + condicion transicion |
| §1 HITL — Juan Perez | SBOS-COMPLETITUD-v4 §2 "Juan Perez — Administrador de Dominios" | Rol formal, alcance, responsabilidades, condicion de transicion por equipo |
| §2 ARB | SBOS-025-ARB, SBOS-048-ADR-CATALOG | §proceso completo |
| §3 Normas | SBOS-023 v1.0, SBOS-030 v1.0, SBOS-004 v4.0 | §Zero Trust, §SGSI, §CIS |
| §4 PDCA | SBOS-024 v1.0, SBOS-018 v1.0, SBOS-021 v1.0 | §SLOs, §runbooks, §RECONCILE_SCHEDULER |
| §5 Metricas | SBOS-024 v1.0, SBOS-001-OKR v1.0 | §SLOs, §KRs |
| §7 Aprobaciones | SBOS-018 v1.0 §19 + SBOS-020-COREUI v1.0 §9 | §governance dual-control + §RBAC + nota Juan Perez |
| §8 Smart* Visual | 05_brand-system_theming-governance.md (SBOS IAM Style) | Gobernanza visual ForUI SSOT, jerarquia, acentos |
| §9 Smart* Subproyectos | Observado en subproyectos Smart* | Tabla de governance por subproyecto, reglas de acoplamiento |
| §10 SBOS-025-010-1 a SBOS-025-010-4 | SBOS-025-ARB-Proceso.md | Estructura ARB (5 miembros, quorum, rotacion), categorias RFC (A/B/C), proceso RFC->ADR con tiempos y template, indice ADRs (ADR-001 a ADR-008), casos especiales (urgencia, excepciones temporales, implementacion sin RFC) |

---

## Fuentas de Enriquecimiento V8

| Fuente | Tipo | Contenido aportado |
|---|---|---|
| BOS_V6_SBOS-010-GOVERNANCE.md | V6 (canonico) | Contenido base completo preservado |
| 05_brand-system_theming-governance.md (SBOS IAM Style) | Smart* | Gobernanza visual, ForUI como SSOT, jerarquia visual, sistema de acentos |
| Estructura observada en subproyectos/ | Smart* | Tabla de governance, reglas de acoplamiento para subproyectos |
| SBOS-025-ARB-Proceso.md | SBOS (V8) | Estructura ARB (5 miembros, quorum, rotacion), categorias RFC (A/B/C), proceso RFC->ADR con template de 12 secciones, formato ADR, indice ADR-001 a ADR-008, casos especiales (urgencia seguridad, excepciones temporales, implementacion sin RFC) |

---

_SKULL · SBOS · SBOS-010-GOVERNANCE · HUMAN-DOC v1.3-V8 · Mayo 2026_
_Enriquecimiento V8: Smart* gobernanza visual del ecosistema (ForUI SSOT) + tabla de governance de subproyectos_
