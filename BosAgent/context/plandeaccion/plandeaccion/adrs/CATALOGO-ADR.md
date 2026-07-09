# CATÁLOGO COMPLETO DE ADRs — SBOS

**Versión:** 1.0  
**Fecha:** 2026-06-13  
**Estado:** Activo — Fuente de verdad del inventario de decisiones arquitectónicas

Este documento lista TODOS los ADRs del proyecto SBOS: los ya existentes en CLAUDE.md y en los documentos BOS-REPAIR, y los nuevos ADR-023 en adelante formalizados a partir de reglas implícitas en SBOS_Proyecto_Master.md v2.1.

---

## Cómo Leer Este Catálogo

| Campo | Significado |
|-------|-------------|
| **Estado** | Aceptado = activo e irrenunciable. Supersedido = reemplazado por otro ADR. |
| **Fuente** | Dónde está el documento completo del ADR |
| **Impacto** | Qué áreas del código afecta |

---

## ADRs Existentes (ADR-001 a ADR-022)

### Del Plan BOS-REPAIR (BOS-REPAIR-0X documentos)

| ADR | Título | Estado | Fuente |
|-----|--------|--------|--------|
| **ADR-001** | BOS corre como root con hardening systemd | Aceptado | CLAUDE.md BosAgent (sección Servicio) |
| **ADR-002** | Roles y privilegios del sistema | Aceptado | `bos-repair/BOS-REPAIR-06-ADR002-ROLES-PRIVILEGIOS.md` |
| **ADR-003** | Estándares de documentación — 6 secciones Godoc | Aceptado | `bos-repair/BOS-REPAIR-07-ADR003-ESTANDARES-DOCUMENTACION.md` |
| **ADR-004** | Operator Soberano — ciclo de certificación C-01 a C-13 | Aceptado | `bos-repair/BOS-REPAIR-02-ADR004-OPERATOR-SOBERANO.md` |
| **ADR-005** | Abstracción bosctl como capa soberana — el operador no ve K8s | Aceptado | `bos-repair/BOS-REPAIR-03-ADR005-ABSTRACCION-BOSCTL.md` |
| **ADR-006** | RBAC delegado Ubuntu + Kubernetes (política sudoers + ClusterRole) | Aceptado | `bos-repair/BOS-REPAIR-11-ADR006-RBAC-HERENCIA-UBUNTU-K8S.md` |
| **ADR-007** | Daemons hermanos como stubs de contrato para pruebas del bos | Aceptado | `bos-repair/BOS-REPAIR-16-ADR007-DAEMONS-STUB.md` |

> **Nota:** El Master §7.1 cita "ADR-005" para "PostgreSQL única BD relacional". Esto es un error de referencia. ADR-005 es "Abstracción bosctl". La decisión de PostgreSQL como única BD relacional queda formalizada en **ADR-024** (este catálogo).

### Del CLAUDE.md Principal SBOS (normas de fábrica)

| ADR | Título | Estado | Fuente |
|-----|--------|--------|--------|
| **ADR-014** | Límites de agentes — soberanía de dominio por pane | Aceptado | `CLAUDE.md` §LÍMITES DE AGENTES |
| **ADR-015** | Protocolo de desarrollo en dos fases (Fase A/B por certificación BOS) | Aceptado | `CLAUDE.md` §PROTOCOLO DE DESARROLLO |
| **ADR-016** | Política de backups — estructura canónica S-HOST/S01..S15 | Aceptado | `CLAUDE.md` §POLÍTICA DE BACKUPS |
| **ADR-017** | Versiones canónicas obligatorias del stack tecnológico | Aceptado | `CLAUDE.md` §POLÍTICA DE VERSIONES + Master §Stack |
| **ADR-019** | BOS Interface Dual: WebSocket RPC + JSON-RPC 2.0 sobre Unix socket | Aceptado | `CLAUDE.md` §BOS INTERFACE DUAL |
| **ADR-020** | Interface Dual obligatoria para TODOS los daemons y Smarts | Aceptado | `CLAUDE.md` §REGLA GENERAL Interface Dual |
| **ADR-021** | Máquina de 18 estados de ficha | Aceptado | `CLAUDE.md` §MÁQUINA DE 18 ESTADOS |
| **ADR-022** | Sin intervención manual en el servidor — todo vía BOS | Aceptado | `CLAUDE.md` §NORMA IRRENUNCIABLE + BosAgent CLAUDE.md |
| **ADR-030** | Anti-alucinación — directrices basadas en evidencia, no suposiciones | Aceptado | `CLAUDE.md` §Coordinador (referencia inline) |

> **Nota:** ADR-008 a ADR-013 y ADR-018 están RESERVADOS para decisiones futuras o corresponden a normas del ecosistema aún no documentadas como ADRs formales.

---

## ADRs Nuevos — Formalizados desde Reglas Implícitas del Master v2.1

### §18 — Las 12 Reglas Inquebrantables Formalizadas

| ADR | Título | §18 Regla | Archivo |
|-----|--------|-----------|---------|
| **ADR-023** | Keycloak como único proveedor de identidad | Regla 1 | `ADR-023-KEYCLOAK-UNICO-IDP.md` |
| **ADR-024** | PostgreSQL como única BD relacional (corrige ref. errónea a ADR-005 en §7.1) | Regla 2 | `ADR-024-POSTGRESQL-UNICA-BD-RELACIONAL.md` |
| **ADR-025** | Solo licencias OSI-approved (MIT, Apache, GPL, LGPL, MPL, BSD, AGPL, ISC) | Regla 3 | `ADR-025-LICENCIAS-OSI-APPROVED.md` |
| **ADR-026** | biedata como único gateway hacia APIs externas | Reglas 4 y 10 | `ADR-026-BIEDATA-UNICO-GATEWAY-EXTERIOR.md` |
| **ADR-027** | Kubernetes desde el día 1 — sin modo standalone | Regla 5 | `ADR-027-KUBERNETES-DESDE-DIA-1.md` |
| **ADR-028** | Secretos exclusivamente vía Vault — nunca en env vars | Regla 6 | `ADR-028-SECRETOS-EXCLUSIVAMENTE-VAULT.md` |
| **ADR-029** | Docker vetado — solo Podman/OCI con firma Ed25519 | Regla 8 | `ADR-029-DOCKER-VETADO-PODMAN-OCI.md` |
| **ADR-031** | Tenant ID siempre server-side — nunca del cliente | Regla 11 | `ADR-031-TENANT-ID-SIEMPRE-SERVER-SIDE.md` |

> **Nota:** Regla 7 ("Cero invasión") está cubierta por ADR-007 (daemons stubs) y ADR-014 (límites de agentes).  
> Regla 9 ("HTTP entre daemons vetado") está cubierta por ADR-019/020 (Unix socket) y SBOS-050 P9.  
> Regla 12 ("ctx_id inmutable") está cubierta por ADR-033 y §2.1 P3 del Master.

### §12 — Contratos gRPC Formalizados

| ADR | Título | Origen | Archivo |
|-----|--------|--------|---------|
| **ADR-032** | API-First: Protobuf como fuente de verdad — `.proto` antes que el código | §10 P10, §12.1 | `ADR-032-PROTOBUF-FUENTE-DE-VERDAD.md` |
| **ADR-033** | RequestContext campo 1 obligatorio en todos los mensajes gRPC | §12.2 | `ADR-033-REQUEST-CONTEXT-CAMPO-1.md` |
| **ADR-034** | Tipo monetario: int64 centavos + string ISO 4217 — nunca float | §17.1 | `ADR-034-TIPO-MONETARIO-INT64-CENTAVOS.md` |

### §11 / §17 — Estándares de Desarrollo Formalizados

| ADR | Título | Origen | Archivo |
|-----|--------|--------|---------|
| **ADR-035** | Arquitectura hexagonal obligatoria en todos los daemons | §11, §17 | `ADR-035-ARQUITECTURA-HEXAGONAL-OBLIGATORIA.md` |
| **ADR-036** | Cadena de interceptores gRPC: Recovery→Context→Auth→Logging→Tracing→Metrics | §17.3 | `ADR-036-INTERCEPTORES-GRPC-ORDEN-CANONICO.md` |

### §13 / §16 — Observabilidad y Fichas Formalizadas

| ADR | Título | Origen | Archivo |
|-----|--------|--------|---------|
| **ADR-037** | Observabilidad semántica: ctx_id + tenant_id + correlation_id en todo log/traza | §13 | `ADR-037-OBSERVABILIDAD-SEMANTICA.md` |
| **ADR-038** | Ficha SBOS — 4 artefactos mínimos obligatorios: dashboard, netpolicies, /metrics, /health | §16 | `ADR-038-FICHA-ARTEFACTOS-MINIMOS.md` |

---

## Resumen de Cobertura

| Sección del Master | Reglas/Principios | ADRs que cubren |
|-------------------|------------------|-----------------|
| §2.1 Principios P1-P10 | ctx_id inmutable, Context Plane | ADR-033, ADR-031, SBOS-049 |
| §6 Identity Plane | Keycloak único IdP | ADR-023 |
| §7 Data Plane | PostgreSQL única BD, WAL como bus | ADR-024 |
| §8 Web Platform | Nginx→Kong routing | ADR-027 (K8s), fichas nginx/kong |
| §9 Storage | MinIO, pgBackRest | ADR-016 (backups), fichas S09/ |
| §10 Daemons soberanos | 8 daemons en host | ADR-019, ADR-020, ADR-027 |
| §11 Backend Services | Arquitectura hexagonal | ADR-035 |
| §12 Contratos gRPC | Protobuf primero, RequestContext, Money | ADR-032, ADR-033, ADR-034 |
| §13 Observabilidad | OTel, ctx_id en logs | ADR-037 |
| §14 Seguridad | Zero Trust, Vault, Podman | ADR-028, ADR-029, ADR-031 |
| §16 Ficha SBOS | 4 artefactos mínimos | ADR-038 |
| §17 Estándares Go/Rust | Hexagonal, interceptores | ADR-035, ADR-036 |
| §18 Reglas Inquebrantables | 12 reglas → 8 ADRs nuevos | ADR-023 a ADR-031 |

---

## Números Reservados

| Rango | Estado |
|-------|--------|
| ADR-008 a ADR-013 | RESERVADOS — pendiente de formalización |
| ADR-018 | RESERVADO — pendiente de formalización |
| ADR-042 | RESERVADO — pendiente de formalización |
| ADR-043 | kubeadm Real en VPS Staging (No k3s) | ADR-043-KUBEADM-REAL-VPS.md |
| **ADR-044** | **Repositorio de Instalación Autocontenido** | `ADR-044-REPOSITORIO-INSTALACION-AUTOCONTENIDO.md` |
| ADR-045+ | Disponibles para decisiones futuras |

---

## ADR-044 — Repositorio de Instalación Autocontenido

| Campo | Valor |
|-------|-------|
| **Estado** | Aceptado |
| **Fecha** | 2026-06-18 |
| **Origen** | Corrección del proceso de instalación manual con dependencia de GitHub |
| **Impacto** | Proceso de deployment, estructura de archivos, `system-install`, `bosctl setup` |

### Decisión

La instalación de SBOS se distribuye como un **repositorio Git autocontenido**
(`SISTEMASSKULL/bos-install`). Un solo comando instala todo el plano de control
sin intervención manual ni dependencias de internet.

```
git clone https://github.com/SISTEMASSKULL/bos-install.git && cd bos-install
sudo ./bin/bosctl setup --mode=dev --seed ./seed-skull.yml
```

### Principios

- **Autocontenido**: binarios precompilados, core scripts, fichas, manifiestos CNI. Todo en el repo.
- **SBOS no incluye prerrequisitos del SO**: kubeadm/kubectl/containerd son como PHP/Composer para Laravel.
- **Un solo comando**: `bosctl setup` ejecuta system-install, inicia daemon, despliega saga.
- **Sin intervención manual**: cero `kubectl delete`, cero `rm -rf`, cero edición de archivos en la VPS.

---

*Próxima revisión: cuando se apruebe un nuevo ADR o se detecte una regla implícita no cubierta.*
