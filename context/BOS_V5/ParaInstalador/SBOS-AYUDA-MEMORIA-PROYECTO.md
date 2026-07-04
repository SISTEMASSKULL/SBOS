# SBOS — Ayuda Memoria del Proyecto
## Documento Portátil de Contexto para Continuidad en Cualquier Cuenta
### Última actualización: Marzo 2026

---

**INSTRUCCIÓN PARA CLAUDE:** Este documento contiene el contexto completo del proyecto SBOS. Fue creado para permitir continuidad si se migra a una cuenta nueva. Léelo completo antes de responder cualquier pregunta sobre el proyecto. Los documentos SBOS-000 a SBOS-040 + MP01 a MP05 son la especificación formal. Este archivo es el contexto humano que los conecta.

---

## 1. Qué es SBOS

SBOS = **Sovereign Business Operating System** de la empresa **SKULL**. Es un sistema operativo de negocios completo: 110+ aplicaciones en 15 servidores lógicos corriendo en UN servidor físico. Cubre ERP, RRHH, CRM, correo, VoIP, VDI, IA, documentos, e-commerce, helpdesk, BI y backup.

La analogía con un SO es **literal**, no metafórica:

```
Linux analogy              SBOS analogy
──────────────────         ──────────────────────────────────────────
Linux kernel          →    bkernel  (kernel de datos — WAL CDC)
Ubuntu/Debian (el SO) →    bos      (el SO empresarial — instala,
                                     vigila y repara todo el stack)
apt/dpkg              →    sistema de fichas (unidades de despliegue)
systemd               →    bos.service (daemon residente en el host)
/usr/bin/apt          →    bosctl (CLI del SO empresarial)
Desktop environment   →    Core UI (Flutter)
Repositorio de paquetes →  SKULL Release Plane
```

**DISTINCIÓN CRÍTICA — NO CONFUNDIR:**
- `bos` = el sistema operativo empresarial completo que corre sobre Ubuntu Server.
  Instala, vigila, repara y actualiza TODO el stack SBOS. Sin bos, nada existe.
- `bkernel` = el kernel de datos del SBOS. Corre DENTRO del SO bos.
  Se encarga de la sincronización de datos via WAL de PostgreSQL.
- `bos` NO es systemd ni el kernel — es el SO COMPLETO que usa Ubuntu como base.

El proyecto tiene 68 documentos y ~43,000 líneas de especificación. Está en fase de transición de documentación a desarrollo.

---

## 2. Los 8 Daemons Soberanos (nombres canónicos — NO cambiar)

| # | Daemon | Nombre real | Servicio | Lenguaje |
|:-:|--------|------------|---------|---------|
| 1 | **bos** | Infrastructure Provisioning & Lifecycle Orchestrator | bos.service | Go |
| 2 | **bkernel** | Reactive Data Orchestration Engine | bkernel.service | **Rust** (no C++) |
| 3 | **biedata** | Federated Batch & Compliance Exchange | biedata.service | **Rust** |
| 4 | **bcompass** | Collaborative & Federated Intelligence | bcompass.service | — |
| 5 | **bsearch** | Sovereign Federated Intelligent Search (RAG) | bsearch.service | — |
| 6 | **bauth** | Unified Identity & Permissions Orchestrator | bauth.service | — |
| 7 | **bhnexus** | Sovereign Connectivity Broker & Multiprotocol Gateway | bhnexus.service | — |
| 8 | **banexus** | Edge Sentinel & Multi-Input Interceptor | banexus.service | — |

**ERRORES DE NOMENCLATURA CORREGIDOS (no reintroducir):**
- ~~InExData~~ → **biedata** (corregido en 35 documentos)
- ~~apiBitMask~~ → **bauth** (corregido en 88 ocurrencias)
- ~~tríada de 3 daemons~~ → **8 Daemons Soberanos**

---

## 3. Estado del Desarrollo (Marzo 2026)

### Daemons
- 6 de 8 en nivel N5 (listos para código): bos, bkernel, biedata, bsearch, bauth, bcompass
- 2 en nivel N4 (faltan specs Go): bhnexus, banexus

### Fichas
- 38 fichas identificadas para poner en marcha el SBOS
- 10 fichas con código Docker validado del TODOIAM legacy (4,495 líneas)
- Promedio global de avance: ~35%
- Correo es lo más avanzado (79%), bootstrap lo más crítico (35%)

### Testbench (SBOS-MP05)
- Herramienta universal con 3 roles: VALIDADOR, CONSTRUCTOR, CERTIFICADOR
- Stack decidido: **Podman 4.9.3** (repos oficiales Ubuntu 24.04) + Buildah + crun + PostgreSQL embebido
- Migración a Podman 5.x cuando se actualice a Ubuntu 26.04 LTS (abril 2026) — migración trivial, mismos YAML K8s
- Fichas usan YAML de K8s desde día 1 (podman play kube — disponible en 4.9)
- Motor: algoritmo de Kahn para resolución recursiva de dependencias
- Knowledge Base en PostgreSQL aprende patrones de cada instalación exitosa
- 5 niveles de certificación antes de publicar en Release Plane
- Este motor es el prototipo del daemon bos
- **SIGUIENTE PASO:** Crear estructura del repositorio + montar testbench + primera ficha (postgresql)

---

## 4. Decisiones Arquitectónicas Tomadas (NO revertir)

| Decisión | Detalle | Documento |
|----------|---------|-----------|
| Rust para bkernel y biedata | C++/Qt eliminado definitivamente | SBOS-010 §7 |
| Podman en vez de Docker | Para el testbench. Más cercano a K8s | SBOS-MP05 |
| Podman 4.9 ahora, 5.x con Ubuntu 26.04 | No actualizar Ubuntu 24.04 a 25.04 (sin soporte). Esperar 26.04 LTS | Sesión Mar 2026 |
| NO actualizar Ubuntu a 25.04 | 25.04 es interim sin soporte. Quedarse en 24.04 LTS. 26.04 LTS sale abril 2026 | Sesión Mar 2026 |
| YAML K8s desde día 1 | Las fichas NO usan docker-compose | SBOS-MP05 §1.3 |
| PostgreSQL embebido en testbench | Para estado + colas + knowledge base | SBOS-MP05 §8 |
| Kahn para dependencias | Algoritmo estándar de la industria (apt, npm) | SBOS-MP05 §4 |
| Fichas con relaciones | No solo depends_on sino tipo de relación | SBOS-MP05 §5 |
| task_catalog.sh permanece en Bash | Las fichas son Bash, el daemon bos es Go | SBOS-005 header |
| Ed25519 para firma de fichas | SLSA framework para Release Plane | SBOS-038 |

---

## 5. Correcciones Aplicadas al Corpus (no revertir)

- "tríada" → "8 Daemons Soberanos" en SBOS-001, 002, 007, 016
- "apiBitMask" → "bAuth" en SBOS-012 (88 ocurrencias)
- "InExData" → "biedata" en 35 documentos
- SBOS-006 referencia corregida de SBOS-027 → SBOS-031
- 7 anexos (-001) integrados en documentos base
- INDEX actualizado a v6.0 con 52 documentos y 24 rutas de lectura
- SBOS-040 creado (catálogo de bases de datos con DDL completo)
- SBOS-039 creado (7 flujos de negocio end-to-end)

---

## 6. Documentos Clave del Proyecto

### Especificación del sistema
| Doc | Contenido |
|-----|-----------|
| SBOS-000 | Índice maestro (v6.0, 52 docs, 24 rutas) |
| SBOS-001 | Visión + OKRs estratégicos |
| SBOS-002 | Arquitectura general |
| SBOS-003 | Stack tecnológico (119 apps) |
| SBOS-005 | **IAM Installer** (3,450 líneas — spec del daemon bos) |
| SBOS-006 | **Sistema de Fichas** (manifest.yml, yaml_engine.yml, task_catalog.sh) |
| SBOS-007 | Core UI (19 endpoints REST + WebSocket) |
| SBOS-010 | bKernel (WAL, CDC, Rust, reglas YAML) |
| SBOS-017 | Roadmap con fases A-D y fechas |
| SBOS-031 | Rutina de instalación (16 fichas desde Ubuntu virgen) |
| SBOS-032 | Productos (agrupaciones de fichas con YAML) |
| SBOS-033 | Deploy manifest (seed file del cliente) |
| SBOS-038 | Release Plane (Ed25519, canary/early/stable) |
| SBOS-040 | Catálogo de bases de datos (DDL de 5 daemons + 30 apps) |

### Planes maestros
| Doc | Contenido |
|-----|-----------|
| SBOS-MP01 | Completar documentación (ya ejecutado) |
| SBOS-MP02 | Pendientes del instalador (ya ejecutado) |
| SBOS-MP03 | Plan de conceptualización (8 etapas) |
| SBOS-MP04 | **Plan Maestro**: estado daemons + 38 fichas + sprints |
| SBOS-MP05 | **Testbench**: Podman + Kahn + KB + certificación |

---

## 7. El TODOIAM Legacy (código reutilizable)

Archivo de 4,495 líneas con 10 servicios Docker validados y funcionales:
- PostgreSQL 18/17/16-alpine, MySQL 8.0, Redis 7-alpine, PgAdmin 4
- docker-mailserver, PostfixAdmin, Roundcube, Cypht (php:8.3-apache)
- Motor: YAML Engine + Task Catalog (~70 funciones Bash) + Docker Core
- 4 workflows: full_install, repair, diagnostic, backup
- Todo validado y funcional — se reutiliza al 80%

---

## 8. Convenciones de Trabajo

- **Nombres de archivos:** SBOS-XXX-NOMBRE-vN_M.md (no cambiar versión sin instrucción)
- **Nombres de daemons:** siempre minúscula: bos, bkernel, biedata, etc.
- **Nombres de fichas:** siempre minúscula con guion: postgresql, roundcube, sbos-bootstrap-os
- **Contenedores testbench:** prefijo sbos-: sbos-postgresql, sbos-keycloak
- **No mezclar:** documentación SBOS general con desarrollo del IAM Installer
- **Preservar investigación:** al corregir documentos, integrar contenido, nunca eliminar
- **Compendio del usuario:** la definición de los 8 daemons del usuario es la fuente autoritativa

---

## 9. Pendientes (lo siguiente a hacer)

### PLAN MAESTRO — 10 Etapas hacia SBOS v0.9
Ver SBOS-MP06-PlanMaestroDesarrollo-v1_0.md para el plan completo.

**ETAPA ACTUAL: 1 — Motor Core + 4 archivos maestros**

### ETAPA 0 COMPLETADA (Marzo 2026)
- Corregida analogia bos/bkernel: bos=SO empresarial, bkernel=kernel de datos
- Corregida version Podman 5.x a 4.9.3 en Ayuda Memoria y Prompt Maestro
- Eliminada oracion task_catalog.so de SBOS-018 seccion 11.1
- SBOS-MP06 creado con plan maestro completo de 10 etapas

### PROXIMA SESION — ETAPA 1: Motor Core + 4 archivos maestros
Objetivo: crear /opt/sbos-dev/core/ con los 4 archivos maestros Bash.
Criterio: validate_sp01.py pasa con exit 0. Ciclo A-E-L probado.

Prompt para continuar:
Continuamos con el proyecto SBOS. Lee la Ayuda Memoria.
Etapa actual: 1. Objetivo: /opt/sbos-dev/core/ con los 4 archivos maestros
y validate_sp01.py pasando con exit 0.

### Documentacion SBOS pendiente (prioridad baja)
1. Agregar Nexus a SBOS-017 Roadmap
2. Agregar Nexus bounded context a SBOS-022
3. Agregar flujo QR soberano a SBOS-023
4. Agregar runbooks Nexus a SBOS-024
5. Eliminar 46 archivos SKBOS-* legacy
6. Renombrar SBOS-011-INEXDATA a SBOS-011-BIEDATA

---

## 10. Reglas para Claude (leer siempre)

**REGLA 1 — ACTUALIZACIÓN AUTOMÁTICA DE AYUDA MEMORIA:**
Antes de que se agote el contexto o al final de cada sesión larga, Claude DEBE actualizar automáticamente este archivo (SBOS-AYUDA-MEMORIA-PROYECTO.md) con:
- Decisiones tomadas durante la sesión
- Pendientes actualizados (§9)
- Estado del proyecto actualizado (§3)
- Cualquier nueva convención o corrección establecida

También debe actualizar cualquier documento MP que haya cambiado durante la sesión. Esto es CRÍTICO para la continuidad del proyecto. No esperar a que el usuario lo pida — hacerlo proactivamente.

**REGLA 2 — NOMENCLATURA:**
Nunca reintroducir nombres eliminados: ~~InExData~~, ~~apiBitMask~~, ~~tríada~~. Los nombres canónicos de los 8 daemons están en §2.

**REGLA 3 — DOCUMENTOS SOBRE CONVERSACIÓN:**
Si algo importante se decide en la conversación, cristalizarlo en un documento. Las conversaciones se pierden, los documentos del proyecto persisten.

---

## 11. Prompt Maestro del Proyecto

Este prompt se pega como **instrucciones personalizadas del proyecto** o como primer mensaje en un chat nuevo. Define cómo debe actuar Claude como profesional de infraestructura para este proyecto.

```
IDENTIDAD Y ROL:
Eres un arquitecto senior de infraestructura soberana y sistemas 
distribuidos, trabajando como co-arquitecto del proyecto SBOS 
(Sovereign Business Operating System) de SKULL junto a Ivan, 
el arquitecto lead. Tu especialización es: aprovisionamiento de 
infraestructura bare-metal, orquestación de contenedores (Podman/K8s), 
resolución de dependencias en DAGs, diseño de instaladores declarativos, 
y desarrollo de sistemas tipo package manager.

CONTEXTO DEL PROYECTO:
Busca y lee siempre estos archivos del proyecto antes de responder:
- SBOS-AYUDA-MEMORIA-PROYECTO.md (contexto completo y reglas)
- SBOS-MP04 (estado del proyecto + plan de desarrollo)
- SBOS-MP05 (testbench + motor de dependencias)
- SBOS-005 (especificación del IAM Installer)
- SBOS-006 (especificación del sistema de fichas)

CÓMO DEBES TRABAJAR:
1. INVESTIGAR ANTES DE OPINAR: Cuando hay una decisión técnica,
   busca en internet cómo lo hacen los proyectos referentes 
   (k0s, K3s, Talos, RKE2, Helm, apt). No inventes — fundamenta.

2. CICLO DUAL: Documentación y código van juntos. Nunca generes 
   documentación teórica sin que tenga un camino directo a ejecución. 
   Nunca generes código sin que quede documentado en la ficha.

3. CRISTALIZAR DESCUBRIMIENTOS: Si durante el trabajo se descubre 
   algo nuevo (un puerto, un timing, una dependencia), debe quedar 
   registrado en el archivo correspondiente de la ficha 
   (manifest.yml, yaml_engine.yml, task_catalog.sh, resources/).

4. NO DISPERSAR: Un concepto = un documento. Si algo ya está 
   documentado en un archivo, referenciarlo, no duplicarlo. 
   Antes de crear un documento nuevo, verificar que no exista ya.

5. PROPONER ALTERNATIVAS: Ante decisiones importantes, presentar 
   2-3 opciones con pros/contras antes de implementar. 
   Dejar que Ivan decida.

6. CÓDIGO EJECUTABLE: Cuando generes código (Bash, YAML, SQL), 
   debe ser código que se pueda copiar y ejecutar directamente 
   en un servidor Ubuntu 24.04 con Podman 4.9.3. 
   Nada de pseudocódigo ni placeholders genéricos.

7. INVESTIGAR EN INTERNET: Cuando no estés seguro de una versión, 
   una configuración, o un comportamiento de un servicio Docker, 
   búscalo en internet antes de responder. 
   Las imágenes Docker cambian, las APIs cambian.

8. NOMENCLATURA ESTRICTA: Los 8 daemons tienen nombres canónicos 
   (bos, bkernel, biedata, bcompass, bsearch, bauth, bhnexus, banexus). 
   Los contenedores del testbench usan prefijo sbos-. 
   Las fichas usan minúscula con guion. Nunca violar esto.

9. ACTUALIZAR AYUDA MEMORIA: Al final de cada sesión o cuando 
   detectes que el contexto se agota, actualizar automáticamente
   SBOS-AYUDA-MEMORIA-PROYECTO.md con decisiones y pendientes.

STACK TECNOLÓGICO DEL PROYECTO:
- Host: Ubuntu 24.04 LTS
- Contenedores: Podman 4.9.3 (rootless, repos oficiales Ubuntu 24.04) + Buildah + crun
  NOTA: migrar a Podman 5.x cuando Ubuntu 26.04 LTS esté disponible (abril 2026)
- Motor de estado: PostgreSQL 18-alpine (embebido en el testbench)
- Daemon bos: Go (binario soberano)
- bkernel + biedata: Rust
- Fichas: Bash (task_catalog.sh) + YAML (manifest.yml, yaml_engine.yml)
- Manifiestos: YAML de Kubernetes (podman play kube)
- Seguridad: Ed25519 (firma), Vault (secrets), mTLS
- Orquestación destino: Kubernetes (kubeadm + Calico + MetalLB)

FORMATO DE RESPUESTAS:
- Directo y sin relleno. Si la respuesta es corta, que sea corta.
- Código en bloques con lenguaje especificado.
- Tablas para comparaciones.
- Cuando generes archivos, usar create_file con la ruta correcta.
- Cuando investigues, citar las fuentes relevantes.
- Español como idioma principal. Inglés para código y nombres técnicos.
```

### 11.1 Prompt Rápido para Continuar Trabajo

```
Continuamos con el proyecto SBOS. Lee la Ayuda Memoria y SBOS-MP04/MP05.
Hoy necesito: [LO QUE NECESITAS]
```

---

*SKULL · SBOS · Ayuda Memoria · Marzo 2026*
