# Documentación Técnica — bAuth Identity Control Plane

**Versión:** 1.0.0  
**Mantenido por:** bauth-developer  
**Última actualización:** 2026-08-02  
**Estado:** Activo — se amplía a medida que se cierran los gaps de reparación

---

## ⭐ Documento rector

| Documento | Archivo | Rol |
|-----------|---------|-----|
| **Directrices de Categoría IAM Enterprise** | [0.00_MANUAL-DIRECTRICES-IAM-ENTERPRISE.md](0.00_MANUAL-DIRECTRICES-IAM-ENTERPRISE.md) | **Carta rectora** — define la categoría IAM Enterprise que bAuth persigue, los 7 pilares, los diferenciadores irrenunciables, el modelo de madurez L0-L4, la matriz de alineación de TODOS los manuales, y las 10 directrices editoriales que cada manual acata. **Todo manual se lee bajo esta carta.** |

---

## ⭐ Vista por Motor (ADR-013)

bAuth se estructura por **motores**: una capacidad (verbo) = un motor = un punto único de cambio. La
**[vista por motor](MOTORES/MOTORES-INDEX.md)** agrupa estos manuales bajo el motor al que sirven —
**sin renumerarlos**. Para reparar o completar una capacidad, abre la **portada** de su motor: reúne
su propósito, los archivos de código a consolidar, y las referencias a manuales/anexos/contratos.

| Motor (verbo) | Portada | Estado |
|---------------|---------|:------:|
| BitMask (privilegios) | [motor-bitmask](MOTORES/motor-bitmask.md) | ✅ |
| Métodos (autenticar) | [motor-metodos](MOTORES/motor-metodos.md) | 🔄 9/18 |
| Políticas/PDP (autorizar) | [motor-politicas](MOTORES/motor-politicas.md) | 🔄 partido + fail-open |
| Canales (transportar) | [motor-canales](MOTORES/motor-canales.md) | ⬜ |
| Criptográfico (cifrar) | [motor-criptografico](MOTORES/motor-criptografico.md) | ⬜ |
| Firma (documentos) | [motor-firma](MOTORES/motor-firma.md) | 🔄 |
| Auditoría (WORM) | [motor-auditoria](MOTORES/motor-auditoria.md) | 🔄 |

> Índice completo, especialización (familias/dominios/PIP) y orden de convergencia: **[MOTORES/MOTORES-INDEX.md](MOTORES/MOTORES-INDEX.md)**.

---

## Manuales disponibles

> **Alineación IAM Enterprise:** cada manual documenta uno o más de los 7 pilares de la carta
> rectora (AM · IGA · PAM · ITDR · Directory · Standards · Enterprise Platform), declara su nivel
> de madurez real (L0-L4) y persigue la categoría plena. Ver la matriz de alineación en las
> Directrices §7.

### Esquema de catálogo — ciclo cerrado + dependencia

Los manuales se numeran `N.M` donde **N = fase del ciclo cerrado de seguridad de identidad**
(la frontera de madurez L4 de la carta rectora) y **M = orden por dependencia** dentro de la
fase (un manual con número menor es prerequisito de los mayores). El ciclo:

```
1 Identificación → 2 Protección → 3 Detección → 4 Respuesta → 5 Causa raíz → 6 Recuperación → 7 Remediación
   (+ 9 Producto, transversal)
```

No se puede proteger lo que no se ha identificado, ni detectar sin protección, ni remediar sin
causa raíz — el número refleja esa cadena. **El número `N.MM` prefija el nombre del archivo**
(ej.: `1.04_MANUAL-BITMASK-v1.0.md`) para que el orden de lectura se identifique de inmediato al
listar la carpeta; los archivos ordenan solos por fase y dependencia. La carta rectora es
`0.00_` (se lee primero); este índice (`INDICE.md`) es el mapa de entrada.

### Fase 1 — IDENTIFICACIÓN · el modelo y el almacén de identidad (¿quién/qué existe?)

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 1.1 | [Dominios (D00–D13 + funcionales)](1.01_MANUAL-DOMINIOS-v1.0.md) | — (mapa de los 13 planos) | ✅ 1.0.0 |
| 1.2 | [Verbos](1.02_MANUAL-VERBOS-v1.0.md) | 1.1 | ✅ 1.0.0 |
| 1.3 | [Átomos](1.03_MANUAL-ATOMOS-v1.0.md) | 1.1, 1.2 | ✅ 1.2.0 |
| 1.4 | [BitMask y Dominios](1.04_MANUAL-BITMASK-v1.0.md) | 1.3 | ✅ 1.1.0 |
| 1.5 | [DDL y Seeds](1.05_MANUAL-DDL-SEEDS-v1.0.md) | 1.3 (schema del catálogo) | ✅ 1.0.0 |
| 1.6 | [D00 — Identidad Organizacional v2.1.0](1.06_MANUAL-D00-IDENTIDAD-v2.0.md) | 1.4, 1.7 | ✅ 2.1.0 (37 dominios · N-to-N · multi-tenant · visibilidad) |
| 1.7 | [Atributos v2.0](1.07_MANUAL-ATRIBUTOS-v2.0.md) | 1.6 | ✅ 2.0.0 |
| 1.8 | [User y UserTemplate](1.08_MANUAL-USER-TEMPLATE-v1.0.md) | 1.6, 1.9 | ✅ 1.1.0 |
| 1.9 | [Roles](1.09_MANUAL-ROLES-v1.0.md) | 1.4, 1.6 | ✅ 1.3.0 |
| 1.10 | [Aplicaciones (catálogo e integración)](1.10_MANUAL-APLICACIONES-v1.0.md) | 1.3, 1.9 | ✅ 1.2.0 |
| 1.11 | [Context Plane (ctx_id)](1.11_MANUAL-CONTEXT-PLANE-v1.0.md) | 1.6 (árbol D00) | ✅ 1.0.0 |
| 1.12 | [Multi-tenancy e IDaaS (`bauth.tenant.*` + `bauth.idp.*`)](1.12_MANUAL-MULTITENANCY-IDAAS-v1.0.md) | 1.6, 1.8 | ✅ 1.0.0 ➕ |
| 1.13 | [Motor de Versionado Universal (MVU)](1.13_MANUAL-MOTOR-VERSIONADO-v1.0.md) | 1.5, 1.8, 1.9, 2.10, 5.01, 7.3 | ✅ 2.1.0 ➕ (motor: L1) |

### Fase 2 — PROTECCIÓN · control de acceso, autenticación, salvaguardas

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 2.1 | [Autenticación](2.01_MANUAL-AUTENTICACION-v1.0.md) | 1.11, 2.3 | ✅ 1.1.0 |
| 2.2 | [Métodos — Estado del Arte 2026](2.02_MANUAL-METODOS-ESTADO-INDUSTRIA-v1.0.md) | 2.1 | ✅ 1.0.1 |
| 2.3 | [Tokens](2.03_MANUAL-TOKENS-v1.0.md) | 1.4, 2.4 | ✅ 1.0.0 |
| 2.4 | [Firma Digital](2.04_MANUAL-FIRMA-DIGITAL-v1.0.md) | 2.3, 5.2 | ✅ 1.0.0 |
| 2.5 | [Políticas (+ Rules)](2.05_MANUAL-POLITICAS-v1.0.md) | 1.3, 1.1 | ✅ 1.1.1 |
| 2.6 | [D99 — Administrativo Global](2.06_MANUAL-D99-DOMINIO-ADMINISTRATIVO-GLOBAL-v1.0.md) | 2.5 (biblioteca) · garante de 1.6 | ✅ 1.0.0 |
| 2.7 | [Calendario (D4 ↔ bcalendar)](2.07_MANUAL-CALENDARIO-D4-v1.0.md) | 1.1 (D4) | ✅ 1.0.0 |
| 2.8 | [bAuth ↔ bGlobal (menú contextual)](2.08_MANUAL-MENU-CONTEXTUAL-v1.0.md) | 1.9, 1.10 | ✅ 1.2.0 |
| 2.9 | [Seguridad (cibernética + red)](2.09_MANUAL-SEGURIDAD-v1.0.md) | 1.11, 2.3 | ✅ 1.0.0 |
| 2.10 | [Seguridad de Datos](2.10_MANUAL-SEGURIDAD-DATOS-v1.0.md) | 1.7, 2.4 | ✅ 1.0.0 |
| 2.11 | [Frontend (Dashboard)](2.11_MANUAL-FRONTEND-v1.0.md) | 2.5, 1.10 | ✅ 1.0.0 |
| 2.12 | [Canales Protegidos (Gestor de canales)](2.12_MANUAL-CANALES-PROTEGIDOS-v1.0.md) | 2.9, 1.11, 2.3, 2.4 | ✅ 1.0.0 ➕ (gestor: L0) |
| 2.13 | [AtomLang — Lenguaje de configuración del árbol de políticas v2.0](2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md) | 1.01, 1.02, 1.03, 1.04, 2.05, 7.03 | ✅ 2.0.0 (lenguaje L2 · compilador L0) |
| 2.14 | [Composición del Árbol — dominios, zonas, aplicaciones y posición de cada átomo](2.14_MANUAL-COMPOSICION-ARBOL-v1.0.md) | 2.13, 1.01, 1.03, 1.10, 2.05 | ✅ 1.0.0 (árbol conceptual L2 · árbol técnico L0) |
| 2.15 | [Motor de Identidad — validación de datos con políticas AtomLang](2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) | 1.06 v2.0, 1.07 v2.0, 2.13 v2.0 | ✅ 1.1.0 (N-to-N · multi-tenant · visibilidad) |
| 2.16 | [Uso del Motor de Identidad — guía práctica](2.16_MANUAL-USO-MOTOR-IDENTIDAD-v1.0.md) | 1.06 v2.0, 1.07 v2.0, 2.15 | ✅ 1.1.0 (guía de uso · ejemplos · API) |
| 2.17 | [Motor de Roles — gestión de roles, átomos y asignaciones vía JSON-RPC y CLI](2.17_MANUAL-MOTOR-ROLES-v1.0.md) | 1.03, 1.04, 1.08, 1.09, 2.05, 2.13, 2.15 | ✅ 1.1.0 (CRUD + CLI + RPC · diseño completo) |

### Fase 3 — DETECCIÓN · monitoreo y riesgo

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 3.1 | [Riesgo Adaptativo (Risk Engine / ITDR)](3.01_MANUAL-RIESGO-ADAPTATIVO-v1.0.md) | 1.11, 2.1, 2.3 | ✅ 1.0.0 |

### Fase 4 — RESPUESTA · reacción (alerta, step-up, revocación)

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 4.1 | [bAuth ↔ bNotify (OIDC · CAEP · entrega)](4.01_MANUAL-BAUTH-BNOTIFY-v1.0.md) | 3.1, 2.9 | ✅ 1.0.0 |

### Fase 5 — CAUSA RAÍZ · forense y evidencia

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 5.1 | [Auditoría y Trazabilidad](5.01_MANUAL-AUDITORIA-TRAZABILIDAD-v1.0.md) | 1.11, 2.3 | ✅ 1.1.0 |
| 5.2 | [Blockchain D12 (Forma A y B)](5.02_MANUAL-BLOCKCHAIN-D12-v1.0.md) | 5.1 | ✅ 1.0.0 |

### Fase 6 — RECUPERACIÓN · restauración, bootstrap, break-glass

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 6.1 | [Operación (runbook del daemon)](6.01_MANUAL-OPERACION-v1.0.md) | 1.5, 5.1 | ✅ 1.0.0 |

### Fase 7 — REMEDIACIÓN · gobernanza, corrección, certificación

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 7.1 | [Gobernanza y Auditoría de Identidades (IGA)](7.01_MANUAL-GOBERNANZA-IGA-v1.0.md) | 1.9, 1.8, 5.1 | ✅ 1.0.0 |
| 7.2 | [Calidad de Autenticación (QA)](7.02_MANUAL-CALIDAD-AUTENTICACION-v1.0.md) | 2.2, 7.3 | ✅ 1.0.0 |
| 7.3 | [Normas y Estándares Internacionales](7.03_MANUAL-NORMAS-v1.0.md) | todos (cataloga sus normas) | ✅ 1.0.0 |
| 7.4 | [CLI y Pruebas Externas (delegación de verificación)](7.04_MANUAL-CLI-PRUEBAS-EXTERNAS-v1.0.md) | 6.1, 9.1 | ✅ 1.0.0 ➕ |
| 7.5 | [Pipeline de Seguridad CI — SA-10 / ISO 27001 A.8.25 (Podman + cargo-audit + cargo-deny + clippy + timer systemd)](7.05_MANUAL-PIPELINE-SEGURIDAD-CI-v1.0.md) | 6.1, 5.1, 7.3 | ✅ 1.0.0 |

### Serie 9 — PRODUCTO (transversal)

| N° | Manual | Depende de | Estado / Ver. |
|:--:|--------|------------|:-------------:|
| 9.1 | [Producto (entregables)](9.01_MANUAL-PRODUCTO-v1.0.md) | todos | ✅ 1.0.0 |
| 9.2 | [Referencia de API (~141 métodos `bauth.*` por plano)](9.02_MANUAL-REFERENCIA-API-v1.0.md) | 9.1 | ✅ 1.0.0 ➕ |

---

### Anexos — la capa de respaldo documental (`anexos/`)

Los manuales afirman; los **anexos respaldan**: documentos nuevos, organizados y
referenciables (`A.NN §X`) que estructuran el conocimiento de los SSOT de diseño + la
verificación contra normas y estándares internacionales. **No son copias** — son la lectura
curada para consulta sin fricción. Índice, patrón canónico y plan: [anexos/INDICE-ANEXOS.md](anexos/INDICE-ANEXOS.md).

| Anexo | Respalda a | Estado |
|:--:|--------|:-------------:|
| [A.01 — El Contrato RolTemplate v6.0 + átomos D00 + idn_identity_attribute roles (§22)](anexos/A.01_ANEXO-ROLTEMPLATE-v1.0.md) — FUENTE AUTOSUFICIENTE | 1.06, 1.09, 1.13, 1.04, 2.05, 2.15 | ✅ 2.2.0 |
| [A.02 — El Contrato UserTemplate v6.0 + idn_identity_entity + idn_identity_attribute usuarios (§23)](anexos/A.02_ANEXO-USERTEMPLATE-v1.0.md) — FUENTE AUTOSUFICIENTE | 1.06, 1.08, 1.13, 2.01, 2.10, 2.15 | ✅ 1.2.0 |
| A.03 Catálogo de Roles (+BitMask Dual) · A.04 Cadenas DAG · A.05 Átomos de Dominio · A.06/A.07 Frameworks (+recursos) · A.08 Firma · A.09 Credenciales/IAL · A.10 Revocación · A.11 Red · A.12 Blockchain D12 · A.13 ADRs (vigencia real) · A.14 Context Plane | ver [INDICE-ANEXOS](anexos/INDICE-ANEXOS.md) §2 | ✅ (14 publicados) |
| [A.15 — Stack Rust de Autenticación](anexos/A.15_ANEXO-STACK-RUST-AUTENTICACION-v1.0.md) — el patrón de SUSTENTACIÓN (verificación de código: cubierto/parcial/brechas específicas) | 2.1, 2.2, 2.3 | ✅ 1.0.0 ➕ |
| **Sustentación A.16–A.40 (25 anexos)** — verificación de código real de todos los manuales: protocolos, BitMask, frontend, superficie, OIDC, dominios, RLS, validadores, sqlx, calidad, riesgo, auditoría, DPoP, operación, IGA, atributos, aplicaciones, motor, D99, calendario, menú, datos, CAEP, CLI, producto | [INDICE-ANEXOS §2-§3.1](anexos/INDICE-ANEXOS.md) | ✅ **COBERTURA TOTAL** (36/36 manuales) |
| **AtomLang A.45–A.51 (7 anexos)** — respaldo normativo y técnico de los manuales 2.13 y 2.14. | [INDICE-ANEXOS §2](anexos/INDICE-ANEXOS.md) | ✅ |
| **Identidad + Motor de Roles A.52–A.63 (10 anexos)** — A.52 Tipos y Dominios · A.53 Capas Acumulativas · A.54 Catálogo Autopartes · A.55 Catálogo Automotriz · A.56 Diseño BD Identidad · A.57 Rendimiento Identidad · A.59 Tipos de Átomos (6,000, BitMask) · A.60 Ciclo Vida Átomos (DAG, merge) · A.61 Diseño BD Roles · A.62 Rendimiento Roles · A.63 Objetos Compuestos (Composite GoF, 3 árboles) | [INDICE-ANEXOS §2](anexos/INDICE-ANEXOS.md) | ✅ 2.1.0 |
| **A.64 Maquetas Desktop** · **[A.65 — Inventario Tablas DDL](anexos/A.65_ANEXO-INVENTARIO-TABLAS-DDL-v1.0.md)** · **[A.65.01 — Guía Desarrollo Tablas](anexos/A.65.01_ANEXO-GUIA-DESARROLLO-TABLAS-DDL-v1.0.md)** · **[A.65.02 — Nueva DDL · 32 tablas base (GLOBAL/TENANT/ROLES/VERSIONADO/IDENTIDAD)](anexos/A.65.02_ANEXO-NUEVA-DDL-v1.0.md)** — inventario limpio de partida para el diseño DDL desde cero | 5.01 · 1.13 · A.65 · A.61 · A.56 | ✅ 1.0.0 |
| **[A.65.03 — Completitud 18 dominios bAuth](anexos/A.65.03.01.18_COMPLETITUD-TODOS-DOMINIOS.md)** · **[A.65.04 — Inventario Menús Contextuales MC-0001..MC-0319](anexos/A.65.04_INVENTARIO-MENUS-CONTEXTUALES.md)** — análogo del A.65.02 para `bglobal.menu_context`: 58 ENUMs + 261 CHECKs, MC-XXXX + T-XXX, índice inverso columna→MC | DDL · Seeds · UI | ✅ 1.0.0 |
| **[A.66 — Gaps nombres tablas DDL](anexos/A.66_ANEXO-GAPS-NOMBRES-TABLAS-DDL-v1.0.md)** · **[A.67 — Zonas de Negocio RolTemplate](anexos/A.67_ANEXO-BLOQUE-ZONAS-NEGOCIO-ROL-TEMPLATE-v1.0.md)** · **[A.68 — Catálogo propiedades átomos](anexos/A.68_CATALOGO-PROPIEDADES-ATOMOS-v1.0.md)** · **[A.69 — Revisión DDL V2 bugs](anexos/A.69_ANEXO-REVISION-DDL-V2-BUGS-v1.0.md)** | DDL · Árbol · Átomos | ✅ |
| **[A.70 — Recursos Kubernetes de bAuth (B02 Reconcile + NetworkPolicies)](anexos/A.70_ANEXO-BAUTH-KUBERNETES-RESOURCES-v1.0.md)** — Secret, CronJob y NetworkPolicy; manifests idempotentes para reconstrucción sin fricción | B02 · K8s | ✅ 1.0.0 |
| **[A.71 — Informe de Cumplimiento ISO 27001:2022](anexos/A.71_INFORME-CUMPLIMIENTO-ISO27001-2022-v1.0.md)** — Análisis de los 93 controles Anexo A contra SBOS_db: 74 % cumplimiento global · 18 controles CUMPLIDOS · 5 brechas priorizadas P1-P3 · plan de remediación a 88-92 % | ISO 27001 · DDL | ✅ 1.0.0 |

---

## Decisiones de alcance de la hoja de ruta (2026-07-10 — ratificadas con el humano)

**Fusiones (un solo manual, no dos):**
- *Interfaz de Usuario* + *Frontend* → **MANUAL-FRONTEND** (Dashboard Flutter, prototipos HTML de pruebas, widget universal de atributos, patrones de UX como el gate «Modificar — AAL3»).
- *Auditoría* + *Trazabilidad* → **MANUAL-AUDITORIA-TRAZABILIDAD** (auditoría = qué se registra WORM; trazabilidad = cómo se reconstruye extremo a extremo: ctx_id + W3C trace + hash-chain + Merkle).
- *Cortafuegos* → capítulo de red del **MANUAL-SEGURIDAD** (puertos SBOS-050, deny-all, Kong PEP, D7 — la infraestructura de firewall pertenece al proyecto/bos; bAuth documenta su superficie).
- ~~*Dominio 99* → capítulo del MANUAL-DOMINIOS~~ **RECTIFICADO por el humano (2026-07-10): D99 tiene manual propio** — [2.06_MANUAL-D99-DOMINIO-ADMINISTRATIVO-GLOBAL-v1.0.md](2.06_MANUAL-D99-DOMINIO-ADMINISTRATIVO-GLOBAL-v1.0.md). Razón: D99 es parte de las soluciones a los gaps en curso y es el **garante normativo de D00 Identidad** (validación bglobal, criptografía de atributos, trazabilidad, versionado de normas — ver su §5). MANUAL-DOMINIOS queda con alcance D00–D13.

**Rectificaciones de alcance:**
- *«Control Plane»* → se documenta el **Context Plane (ctx_id, SBOS-049)** — el Control Plane (despliegue/gobierno) es producto de **bos**, no de bAuth.
- *«Herramientas y Aplicaciones (Fichas)»* → **MANUAL-APLICACIONES** (catálogo `privilege_application`, cómo una app se registra y aporta átomos). Las **fichas de despliegue** (S00–S15) son recurso compartido del proyecto (`servers/` — skill `sbos-fichas`) y producto de bos: NO se duplican aquí.
- *«Productos entregados»* → **MANUAL-PRODUCTO**: artefactos que bAuth entrega (daemon MUSL, `bauthctl`, `verify_policies`, `bos_verify`, servicio systemd, socket, API JSON-RPC, SDK) con su versionado. ~~SPIs Java~~ eliminadas (ADR-010 — bAuth cubre nativo; ver 9.01 §10).

**Añadidos por brecha detectada (➕):**
- **MANUAL-OPERACION** — runbook: systemd Type=notify + watchdog, arranque (`startup.rs`), reconcile loop, health checks, bootstrap/reconstrucción, break-glass operativo, troubleshooting. Ningún manual cubría la operación diaria.
- **MANUAL-RIESGO-ADAPTATIVO** — el Risk Engine (`risk.rs`), las señales, el `risk_score` dinámico y CAE: es la brecha P1 transversal de Métodos/Autenticación/Políticas y merece su especificación propia.

**Mejora aplicada:** el concepto de **Rules** se incorporó al MANUAL-POLITICAS §7.3 (v1.1.0) — no requiere manual aparte: la Rule es la unidad interna de la política.

---

## Principio de esta documentación

Cada manual documenta el **estado real y verificado** del sistema en la VPS de producción. No es documentación especulativa ni de diseño futuro — es la descripción del sistema que existe.

Cuando un componente aún está en desarrollo, se indica con la marca `⚙ En implementación` dentro del documento correspondiente.

## Visión editorial — norma de todos los manuales

Todo manual de bAuth documenta **lo que hay y lo que no hay** con la misma honestidad. Además de
describir el funcionamiento del sistema, cada manual DEBE incluir una sección de **Estado del arte**
con estos cinco bloques:

1. **Inventario verificado** — tabla de capacidades con estado (✅ implementado · ⚠️ parcial ·
   ❌ no existe · 🚫 deprecado/prohibido) y **evidencia** (archivo de código, seed o documento SSOT).
   Ningún ✅ sin evidencia; ningún ❌ sin haberlo buscado en el código.
2. **Panorama de la industria** — qué hacen las plataformas líderes del dominio en el año en curso,
   con datos y tendencias citables.
3. **Comparativa honesta** — tabla bAuth vs competidores relevantes del dominio. Se declaran tanto
   los diferenciadores únicos de bAuth como las áreas donde la industria está por delante.
4. **Brechas priorizadas P1/P2/P3** — cada brecha con la norma que la exige (si aplica), el riesgo
   que mitiga y el enfoque de implementación propuesto.
5. **Cumplimiento normativo** — cuadro de estándares aplicables al dominio con estado y gaps.

Esta visión se aplicó por primera vez en `2.02_MANUAL-METODOS-ESTADO-INDUSTRIA-v1.0.md` y es
retroactiva: los manuales existentes la incorporaron en sus secciones finales (Roles §14,
Autenticación §16, BitMask §14). Todo manual futuro nace con ella.

## Norma editorial: categoría IAM Enterprise (2026-07-10)

Sobre la visión anterior, todo manual acata las **10 directrices editoriales** de la carta rectora
([MANUAL-DIRECTRICES-IAM-ENTERPRISE §9](0.00_MANUAL-DIRECTRICES-IAM-ENTERPRISE.md)). En síntesis:

1. **bAuth se documenta como IAM Enterprise soberano**, nunca como "servicio de login".
2. Cada manual **declara su pilar** (AM/IGA/PAM/ITDR/Directory/Standards/Platform), su **número
   de catálogo `N.M`** y su **fase del ciclo cerrado** (identificación→…→remediación) — según el
   esquema de catálogo de arriba.
3. **Madurez honesta L0-L4**: distinguir *tabla/motor existe* (L2) de *integrado/operativo* (L3+) —
   nunca ✅ sin verificar en código.
4. Los **diferenciadores irrenunciables** (BitMask O(1) · plano unificado · soberanía · SoD en el
   momento · todo firmado/WORM · físico+digital+blockchain · compliance como dato) **no se diluyen**.
5. **Consistencia del corpus**: ninguna capacidad se documenta dos veces con estados divergentes.

**Regla de revisión:** al desarrollar o tocar un manual, verificar que no contradiga la carta
rectora ni el estado real del código; si una investigación revela que una "brecha" es en realidad
un sustrato existente (tabla/motor), corregir el manual afectado y anotar la corrección en su
historial. El corpus es una herramienta de reparación — su valor está en la exactitud.

---

## Relación con otros documentos

| Documento | Ubicación | Propósito |
|-----------|-----------|-----------|
| Gaps de reparación | `context/plandeaccion/REPARACIONBAUTH/` | Registro de gaps detectados y su solución |
| Contratos entre daemons | `../context/contracts/` | Interfaz entre bAuth y otros daemons |
| Contexto de diseño | `context/` | Decisiones arquitectónicas y análisis |
| DDL y seeds | `../DDLs/` | Esquema de base de datos y datos iniciales |
