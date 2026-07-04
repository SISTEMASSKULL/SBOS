# SBOS-051 — Especificación de Tenant: Modelo Empresarial y Modelo de Dominio Técnico

**Sovereign Business Operating System (SBOS)**
**Organización:** SKULL
**Clasificación del documento:** Ficha de Arquitectura (ADR-suplementaria) / Especificación de Datos
**Estado:** Borrador para revisión técnica
**Autor:** Ivan (Arquitecto y Lead Developer, SBOS)
**Versión:** 2.0.0
**Fecha de emisión:** 2026-06-17
**Ámbito jurisdiccional de referencia:** Estado Plurinacional de Bolivia, con extensión a Comunidad Andina (CAN) y Mercado Común del Sur (Mercosur) como bloques de referencia regional

---

## Control de Versiones

| Versión | Fecha | Cambios | Autor |
|---|---|---|---|
| 1.0.0 | 2026-06-17 | Emisión inicial: Modelo A (Tenant Empresarial) y Modelo B (Tenant Técnico/Dominio) con respaldo en normativa internacional (ISO, NIST, NSA/CISA) | Ivan |
| 2.0.0 | 2026-06-17 | Incorporación de columna de análogo normativo boliviano/regional (CAN, Mercosur) en todas las tablas de respaldo; adición de Sección 13 (Riesgos y Limitaciones del Modelo), Sección 14 (Anexo de Esquemas de Datos); tratamiento explícito de Empresa Unipersonal; ampliación de la sección de identidad federada; control de versiones formal | Ivan |

---

## Tabla de Contenidos

1. [Propósito y Alcance](#1-propósito-y-alcance)
2. [Resumen Ejecutivo](#2-resumen-ejecutivo)
3. [Marco Normativo de Referencia](#3-marco-normativo-de-referencia)
4. [Modelo A — Tenant Empresarial (Capa Legal/Negocio)](#4-modelo-a--tenant-empresarial-capa-legalnegocio)
5. [Modelo B — Tenant Técnico / Dominio (Capa de Plataforma)](#5-modelo-b--tenant-técnico--dominio-capa-de-plataforma)
6. [Mapeo entre Tenant Empresarial y Dominio Técnico](#6-mapeo-entre-tenant-empresarial-y-dominio-técnico)
7. [Modelo de Aislamiento y Fronteras de Seguridad](#7-modelo-de-aislamiento-y-fronteras-de-seguridad)
8. [Ciclo de Vida del Tenant](#8-ciclo-de-vida-del-tenant)
9. [Componentes SBOS Involucrados](#9-componentes-sbos-involucrados)
10. [Cumplimiento y Trazabilidad Normativa](#10-cumplimiento-y-trazabilidad-normativa)
11. [Marco Regulatorio Boliviano y Regional — Detalle Ampliado](#11-marco-regulatorio-boliviano-y-regional--detalle-ampliado)
12. [Glosario](#12-glosario)
13. [Riesgos y Limitaciones del Modelo](#13-riesgos-y-limitaciones-del-modelo)
14. [Anexo — Esquemas de Datos de Referencia](#14-anexo--esquemas-de-datos-de-referencia)
15. [Referencias Normativas](#15-referencias-normativas)

---

## 1. Propósito y Alcance

Este documento define, con respaldo en estándares internacionales y su análogo normativo en el entorno boliviano y regional (Comunidad Andina, Mercosur), los atributos de datos que constituyen a un **tenant** dentro de SBOS desde dos perspectivas complementarias y no intercambiables:

- **Modelo A — Tenant Empresarial:** el tenant como entidad de negocio/legal (una organización cliente, proveedora o socia que contrata o consume SBOS).
- **Modelo B — Tenant Técnico / Dominio:** el tenant como unidad de aislamiento dentro de la plataforma (namespace, RBAC bindings, políticas de red, cuotas de recursos, almacenamiento dedicado).

El objetivo es que toda ficha, daemon o ADR de SBOS que haga referencia a "tenant" use una terminología y un conjunto de atributos consistente, trazable simultáneamente a normas internacionales y a la normativa vigente o aplicable en la jurisdicción primaria de operación de SKULL (Bolivia), evitando una definición ad-hoc o importada acríticamente desde marcos regulatorios que no rigen en la región. Este documento no sustituye al ADR-003 (RBAC) ni a la SBOS-052-VDI-SPEC; los complementa, definiendo el sustrato de datos sobre el cual ambos operan.

**Fuera de alcance:** procedimientos operativos detallados de onboarding/offboarding (se referencian, no se detallan), implementación de código de `bauth` (se referencia a nivel de contrato de datos), redacción de cláusulas contractuales de SLA (se referencia el marco, no el contenido del contrato), y asesoría legal vinculante (este documento no constituye dictamen jurídico; toda implementación debe ser validada por asesoría legal local antes de su puesta en producción).

---

## 2. Resumen Ejecutivo

Un tenant en SBOS **no es un único objeto de datos**, sino la composición de dos entidades relacionadas que viven en capas distintas del sistema:

| | Modelo A: Tenant Empresarial | Modelo B: Tenant Técnico/Dominio |
|---|---|---|
| **Qué responde** | "¿Quién es, legalmente, esta organización?" | "¿Cómo se aísla esta organización dentro de la plataforma?" |
| **Dónde vive el dato** | **bos (Control Plane soberano)** — `bkernel_db.enterprise_tenants` (PostgreSQL 18.4, tenant_id en DDL). Expuesto vía JSON-RPC 2.0 (`bos.tenant.get`) | Kubernetes (namespace, RBAC, NetworkPolicy, ResourceQuota) + Keycloak (realm/org) + Vault (path/namespace) |
| **Normas internacionales** | ISO 17442 (LEI), ISO 20275 (formas jurídicas), ISO 5009 (roles oficiales), marco KYB/AML (FATF, FinCEN CDD Rule) | ISO/IEC 17788, ISO/IEC 19086 (1–4), NIST SP 800-145, NSA/CISA Kubernetes Hardening Guide, CIS Kubernetes Benchmark v8 |
| **Análogo boliviano/regional** | NIT (SIN), Matrícula de Comercio (FUNDEMPRESA), Certificado Digital de Persona Jurídica (AGETIC/ADSIB), Decisión 486 CAN (secreto empresarial) | Sin análogo normativo boliviano propio; se aplican íntegramente los estándares técnicos internacionales (no existe norma nacional de hardening Kubernetes) |
| **Cardinalidad típica** | 1 entidad legal | 1\:N dominios técnicos (una empresa puede tener múltiples tenencias: producción, staging, por unidad de negocio, etc.) |
| **Cambia con qué frecuencia** | Baja (cambia con eventos corporativos: fusión, cambio de razón social, disolución) | Media/alta (se crean, escalan o destruyen dominios según ciclo de vida de producto) |

La razón de separar ambos modelos explícitamente es que **un identificador técnico (namespace, tenant_id de base de datos) no es una prueba de identidad legal**, y un identificador legal (LEI, NIT) no es, por sí mismo, un límite de aislamiento computacional. Tratarlos como una sola cosa es la causa raíz de errores de diseño frecuentes en sistemas multi-tenant: o bien se sobre-confía en el aislamiento de namespace como si fuera una garantía legal de confidencialidad, o bien se asume que verificar la identidad legal de una empresa es suficiente para garantizar que sus datos están aislados de otros tenants.

Una segunda razón, específica del contexto boliviano, es que **gran parte del andamiaje normativo internacional aquí referenciado (LEI/ISO 17442, GDPR, FATF CDD) no tiene un equivalente nacional vigente, vinculante y exigible de igual fuerza**. Bolivia carece, a la fecha de este documento, de una ley general de protección de datos personales en vigor (existe únicamente un anteproyecto ante la Asamblea Legislativa Plurinacional desde 2018, sin ley promulgada) y de un registro de identificación de entidades legales con alcance global equivalente al LEI. SBOS debe, por tanto, operar bajo un **modelo de cumplimiento en capas**: cumplir la normativa boliviana vigente como mínimo legal exigible, y adoptar voluntariamente los estándares internacionales (ISO, NIST) como buena práctica de interoperabilidad y como preparación ante una eventual ley de datos personales boliviana o ante clientes/socios que operen bajo jurisdicciones con normativa más estricta (UE, Brasil, México).

---

## 3. Marco Normativo de Referencia

SBOS ya opera bajo un conjunto de estándares declarados (NIST SP 800-53/207/123, CIS Benchmarks, NSA/CISA Kubernetes Hardening Guide, ISO/IEC 27001:2022). Este documento añade el subconjunto específico para la definición de tenant, organizado por capa, con su análogo local cuando existe.

### 3.1 Normas para la capa empresarial/legal

| Estándar internacional | Organismo | Qué aporta a la definición de tenant | Análogo boliviano / regional (CAN, Mercosur) |
|---|---|---|---|
| **ISO 17442** (Legal Entity Identifier — LEI) | ISO / GLEIF | Identificador único de 20 caracteres para la entidad legal, con datos de referencia de Nivel 1 (identidad: nombre, dirección, jurisdicción, forma jurídica) y Nivel 2 (relaciones de propiedad: matriz directa, matriz última) | **Sin equivalente directo.** El identificador funcionalmente más cercano en Bolivia es el **NIT** (Número de Identificación Tributaria, emitido por el Servicio de Impuestos Nacionales — SIN), complementado por el **número de Matrícula de Comercio** emitido por FUNDEMPRESA. Ninguno de los dos tiene alcance global ni estructura de datos de Nivel 2 (propiedad/matriz) normalizada. No existe un registro LEI-equivalente a nivel CAN ni Mercosur |
| **ISO 20275** (Entity Legal Forms — ELF Code List) | ISO / GLEIF (Maintenance Agency) | Catálogo normalizado de formas jurídicas (S.A., S.R.L., LLC, GmbH, etc.) interoperable entre jurisdicciones | Las formas jurídicas bolivianas (Empresa Unipersonal, S.R.L., S.A., Sociedad Colectiva, Sociedad en Comandita Simple/por Acciones, Sociedad de Economía Mixta, Sucursal de Sociedad Extranjera) están definidas en el **Código de Comercio boliviano** y catalogadas operativamente por FUNDEMPRESA, pero sin codificación normalizada equivalente a ISO 20275 ni mapeo público a dicho catálogo |
| **ISO 5009** (Official Organizational Roles — OOR Code List) | ISO/TC 68 / GLEIF | Catálogo normalizado de roles oficiales de quienes representan a la entidad (CEO, representante legal, apoderado), usado en credenciales vLEI y certificados X.509 con LEI embebido | **Análogo funcional parcial:** el **Certificado Digital de Persona Jurídica** emitido por AGETIC/ADSIB bajo la Ley N.º 164 y su reglamento (D.S. N.º 1793, art. 27) exige acreditar, en los supuestos de representación, las facultades del signatario para actuar en nombre de la persona jurídica representada — cumpliendo el mismo propósito que ISO 5009, aunque sin catálogo de roles normalizado ni interoperabilidad internacional |
| **Marco KYB (Know Your Business)**, derivado de AML/CDD | FATF Recommendations, FinCEN CDD Rule, regulación equivalente regional | Conjunto mínimo de datos para dar de alta una empresa como cliente: razón social, número de registro, jurisdicción, dirección, identificador fiscal, beneficiarios finales (UBO) | Bolivia es miembro de **GAFILAT** (Grupo de Acción Financiera de Latinoamérica, brazo regional del GAFI/FATF) y aplica normativa de debida diligencia a través de la **Unidad de Investigaciones Financieras (UIF)** y la **ASFI** (Autoridad de Supervisión del Sistema Financiero) para entidades reguladas. La exigencia de identificación de beneficiario final existe en el sector financiero regulado, pero no como obligación horizontal para toda transacción B2B fuera del sistema financiero |
| **GDPR / leyes de protección de datos equivalentes** | UE / regional | Régimen de protección de datos personales de personas físicas asociadas al tenant (representantes, administradores) | **No existe ley general vigente en Bolivia.** El **Anteproyecto de Ley de Protección de Datos Personales** (AGETIC, presentado desde 2018, sin aprobación a la fecha) contemplaría una futura Agencia de Protección de Datos Personales (APP), pero hoy el único marco vigente y aplicable es el **Reglamento de Desarrollo de TIC de la ATT** bajo la Ley N.º 164, de alcance más limitado que el GDPR. En la región, sí existen leyes nacionales vigentes equiparables al GDPR en distinto grado: Ley 1581 de 2012 (Colombia), Ley 25.326 (Argentina), Ley 18.331/2008 (Uruguay) y la LGPD (Brasil, Ley 13.709/2018) — ninguna de ellas vinculante para Bolivia ni armonizada a nivel CAN o Mercosur |

### 3.2 Normas para la capa técnica/dominio

| Estándar internacional | Organismo | Qué aporta a la definición de dominio técnico | Análogo boliviano / regional (CAN, Mercosur) |
|---|---|---|---|
| **ISO/IEC 17788** (Cloud Computing — Overview and vocabulary) | ISO/IEC JTC 1/SC 38 | Define formalmente *multi-tenancy* y aclara que una misma organización cliente puede tener múltiples tenencias distintas con un mismo proveedor | Sin análogo normativo boliviano o regional propio. Bolivia no cuenta con un organismo de normalización técnica en cómputo en la nube equivalente a ISO/IEC JTC 1; el **IBNORCA** (Instituto Boliviano de Normalización y Calidad) no ha emitido normas específicas de cloud computing o multi-tenancy a la fecha |
| **ISO/IEC 17789** (Cloud Computing — Reference architecture) | ISO/IEC JTC 1/SC 38 | Arquitectura de referencia: roles, actividades y componentes del cómputo en nube | Sin análogo nacional o regional. Se adopta el estándar internacional sin sustituto local |
| **ISO/IEC 19086-1 a -4** (Cloud SLA framework) | ISO/IEC JTC 1/SC 38 / SC 27 | Terminología común de SLA entre proveedor y cliente; la Parte 4 cubre protección de PII en SLA cloud | Sin marco normativo boliviano de SLA cloud. La protección de PII en SLA quedaría, en el futuro, bajo competencia de la eventual Agencia de Protección de Datos Personales boliviana (hoy inexistente) |
| **NIST SP 800-145** (The NIST Definition of Cloud Computing) | NIST (EE. UU.) | Define *resource pooling* como modelo multi-tenant con asignación dinámica de recursos | Sin análogo gubernamental boliviano; es, de facto, el estándar de referencia adoptado globalmente incluso fuera de EE. UU., y SBOS lo adopta como tal sin necesidad de sustituto regional |
| **NSA/CISA Kubernetes Hardening Guide** | NSA / CISA (EE. UU.) | Guía de hardening para clústeres Kubernetes multi-tenant | Sin análogo gubernamental boliviano o de la CAN/Mercosur. El **CGII** (Centro de Gestión de Incidentes Informáticos de Bolivia, dependiente de AGETIC) emite alertas y lineamientos generales de ciberseguridad, pero no una guía de hardening específica para Kubernetes |
| **CIS Kubernetes Benchmark v8** | Center for Internet Security (EE. UU.) | Controles técnicos verificables para configuración segura del clúster | Sin análogo local. Adoptado íntegramente como estándar de facto |
| **ISO/IEC 27001:2022** | ISO/IEC JTC 1/SC 27 | Sistema de gestión de seguridad de la información (SGSI) | IBNORCA reconoce y permite certificación bajo ISO/IEC 27001 en Bolivia a través de organismos certificadores acreditados, pero no existe una norma técnica boliviana sustitutiva o equivalente propia; la certificación, cuando se persigue, es directamente bajo la norma ISO internacional |

### 3.3 Posición de SBOS respecto al estándar

SBOS ya delega autorización en PAM/sudoers + Kubernetes RBAC con User Impersonation (ADR-003), usa Vault para secretos, Kong como gateway, y Keycloak para identidad. Este documento no introduce nuevos componentes; **define qué atributos de datos debe transportar cada uno de esos componentes para que el concepto de "tenant" sea consistente y auditable** a través de `bauth`, `bkernel` y `biedata`, satisfaciendo simultáneamente el mínimo legal boliviano vigente y el estándar internacional de buena práctica.

---

## 4. Modelo A — Tenant Empresarial (Capa Legal/Negocio)

### 4.1 Definición

El **Tenant Empresarial** es el registro maestro que identifica, ante la ley y ante terceros, a la organización que contrata, opera o es propietaria de uno o más dominios técnicos en SBOS. Es un registro de baja frecuencia de cambio, gobernado por eventos corporativos (alta, fusión, cambio de razón social, disolución), y es la fuente de verdad para todo lo que requiera valor legal: contratos, facturación, cumplimiento KYB, y atribución de responsabilidad.

**Nota sobre Empresa Unipersonal:** en el entorno boliviano y latinoamericano en general, una proporción significativa de los tenants empresariales reales no serán sociedades de capital sino **personas naturales con actividad económica registrada (Empresa Unipersonal)**. El Código de Comercio boliviano y el régimen del SIN reconocen esta figura como sujeto de NIT y, opcionalmente, de Matrícula de Comercio. El modelo de datos de este documento debe admitir `entity_legal_form_code` con un valor específico para Empresa Unipersonal, y debe tratar a la persona física titular simultáneamente como `legal_name` (titular) y como `official_role_holder` único, dado que en esta figura no existe separación entre propietario y representante.

### 4.2 Atributos obligatorios (Nivel 1 — Identidad)

| Atributo | Descripción | Norma internacional de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `legal_name` | Razón social registrada, tal como figura en el registro mercantil de la jurisdicción de constitución | ISO 17442 (Nivel 1) / KYB | Razón social o nombre del titular tal como consta en la **Matrícula de Comercio (FUNDEMPRESA)** y en el **Padrón Nacional de Contribuyentes (SIN)** |
| `trading_name` | Nombre comercial, si difiere de la razón social | KYB | Nombre comercial registrado ante FUNDEMPRESA (sujeto a verificación de homonimia) |
| `legal_entity_identifier` | Código LEI de 20 caracteres, si la organización lo posee | ISO 17442 | No exigido en Bolivia; campo opcional, relevante solo si el tenant participa en transacciones financieras internacionales reguladas que lo exijan |
| `entity_legal_form_code` | Código normalizado de forma jurídica | ISO 20275 | Forma jurídica según el **Código de Comercio boliviano**: Empresa Unipersonal, S.R.L., S.A., Sociedad Colectiva, Sociedad en Comandita Simple, Sociedad en Comandita por Acciones, Sociedad de Economía Mixta, Sucursal de Sociedad Extranjera |
| `jurisdiction_of_registration` | País/estado de constitución legal | ISO 17442 (Nivel 1) | Departamento de registro en Bolivia (la Matrícula de Comercio se gestiona por oficina regional de FUNDEMPRESA, p. ej. La Paz, Santa Cruz, Cochabamba) |
| `registration_number` | Número de registro mercantil oficial | KYB | **Número de Matrícula de Comercio** emitido por FUNDEMPRESA |
| `tax_identifier` | Identificador fiscal (NIT, RFC, EIN, TIN según jurisdicción) | KYB / regulación fiscal local | **NIT (Número de Identificación Tributaria)**, emitido por el Servicio de Impuestos Nacionales (SIN), obligatorio para toda actividad económica formal en Bolivia |
| `registered_address` | Dirección registrada legalmente | ISO 17442 (Nivel 1) / KYB | Domicilio fiscal declarado ante el SIN y domicilio social declarado ante FUNDEMPRESA |
| `operating_address` | Dirección física operativa, si difiere de la registrada | KYB | Domicilio donde se ejerce la actividad económica, acreditado típicamente mediante factura de consumo de energía eléctrica (requisito habitual del SIN) |
| `entity_status` | Estado de la entidad: activa, en disolución, fusionada, inactiva | ISO 17442 (campo `EntityStatus`) | Estado de la Matrícula de Comercio (vigente, cancelada) y estado del NIT ante el SIN (activo, inactivo, baja) |
| `registration_date` | Fecha de constitución legal | KYB | Fecha de la Escritura de Constitución y/o fecha de inscripción en FUNDEMPRESA |
| `municipal_operating_license` | Licencia de funcionamiento para operar en el municipio | — (no cubierto por ISO 17442) | **Licencia de Funcionamiento Municipal**, emitida por el Gobierno Autónomo Municipal correspondiente; requisito boliviano sin equivalente directo en el estándar ISO, incluido aquí porque condiciona la legalidad operativa del tenant |

### 4.3 Atributos obligatorios (Nivel 2 — Relaciones)

| Atributo | Descripción | Norma internacional de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `direct_parent_entity` | Referencia a la entidad matriz directa, si aplica | ISO 17442 (Nivel 2) | No existe registro público boliviano de relaciones matriz-subsidiaria equivalente; se documenta internamente a partir de la Escritura de Constitución o estatutos de la subsidiaria |
| `ultimate_parent_entity` | Referencia a la matriz última del grupo corporativo, si aplica | ISO 17442 (Nivel 2) | Idem; sin registro público boliviano. Para sucursales de sociedades extranjeras, FUNDEMPRESA exige acreditar la sociedad matriz en el trámite de inscripción |
| `ultimate_beneficial_owners` | Personas físicas que poseen o controlan ≥25% de la entidad | FATF / FinCEN CDD Rule | Exigido formalmente solo dentro del sistema financiero regulado boliviano (supervisión ASFI / UIF, en el marco de GAFILAT); no existe obligación general de declarar UBO para toda empresa fuera del sector financiero |
| `relationship_type` | Naturaleza de la relación con SBOS/SKULL: cliente directo, subsidiaria de cliente, partner, proveedor | KYB | Sin regulación específica; categorización interna de SBOS |

### 4.4 Atributos de representación (Roles Oficiales)

| Atributo | Descripción | Norma internacional de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `official_role_holder` | Persona física vinculada a un rol oficial reconocido | ISO 5009 | Persona acreditada como **Representante Legal** o **Máxima Autoridad Ejecutiva (MAE)** ante el SIN/FUNDEMPRESA, o titular del **Certificado Digital de Persona Jurídica** emitido por AGETIC/ADSIB |
| `official_role_code` | Código normalizado del rol (representante legal, CEO, apoderado, director) | ISO 5009 (OOR Code List) | Sin catálogo normalizado boliviano equivalente; se usa la terminología del Código de Comercio (Representante Legal, Gerente General, Director, Apoderado) sin codificación estándar interoperable |
| `role_evidence_reference` | Referencia al documento que acredita el rol | ISO 5009 / KYB | Acta de Directorio, Testimonio de Poder Notarial, Estatutos, o el propio **Certificado Digital de Persona Jurídica** (D.S. N.º 1793, art. 27, exige acreditar las facultades del signatario) |
| `role_valid_from` / `role_valid_until` | Vigencia temporal del rol | ISO 5009 | Vigencia del Poder Notarial o del Certificado Digital (los certificados de AGETIC/ADSIB tienen período de validez explícito) |

### 4.5 Atributos de cumplimiento y ciclo de vida documental

| Atributo | Descripción | Norma internacional de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `incorporation_documents` | Referencias a actas constitutivas, estatutos | KYB | Escritura de Constitución de Sociedad (o Testimonio equivalente), Estatutos, según exigencia de FUNDEMPRESA |
| `kyb_verification_status` | Estado de verificación: pendiente, verificado, rechazado, en revisión | FATF / KYB | Sin obligación legal horizontal boliviana fuera del sector financiero regulado; se adopta como buena práctica interna de SBOS independientemente de la exigencia legal |
| `kyb_last_reviewed_at` | Fecha de la última revisión/re-verificación | FATF / KYB | Idem; práctica voluntaria de SBOS, alineada con el principio de monitoreo continuo de GAFILAT para el sector regulado, extendida aquí por buena práctica a todo tenant |
| `sanctions_screening_status` | Resultado del cribado contra listas de sanciones | FATF | Bolivia participa en GAFILAT; el cribado de sanciones es exigible legalmente solo a sujetos obligados del sistema financiero (bancos, entidades de intermediación financiera bajo ASFI). SBOS lo adopta como buena práctica general |
| `risk_rating` | Calificación de riesgo asignada (bajo/medio/alto) | KYB | Sin marco normativo boliviano horizontal; práctica interna de SBOS |
| `contact_data_processing_basis` | Base legal de tratamiento de datos de contacto de personas físicas asociadas | GDPR o equivalente regional | **No hay ley boliviana vigente que exija una "base legal de tratamiento" en sentido GDPR.** El régimen vigente (ATT, Ley 164) es significativamente más limitado. SBOS adopta este campo de forma preventiva ante la eventual promulgación del Anteproyecto de Ley de Protección de Datos Personales y para alinear su postura con clientes/socios sujetos a GDPR, LGPD (Brasil) o leyes equivalentes de Colombia, Argentina o Uruguay |

### 4.6 Notas de implementación para SBOS

Este modelo corresponde, en términos de SBOS, al registro del Tenant Empresarial gestionado por el **bos (Control Plane soberano)** como parte de su estado interno. El bos almacena estos atributos en `bkernel_db.enterprise_tenants` (PostgreSQL 18.4, tenant_id en todo DDL) y los expone vía JSON-RPC 2.0 (`bos.tenant.get`, `bos.tenant.list`). No debe vivir en Kubernetes ni en Keycloak directamente: estos solo deben **referenciar** el identificador del Tenant Empresarial (p. ej. mediante el NIT, la Matrícula de Comercio, o un `org_id` interno estable), nunca duplicar ni inferir estos atributos desde la capa técnica. Patrón de industria: AWS Control Plane (Tenant Management Service), Stakater MTO (CRD + Operator), Apicurio Registry (namespace-per-tenant + operator reconciliation).


### 4.7 Campos esenciales para implementación BOS (mínimo viable)

De los atributos definidos en §4.2-4.5, el bos requiere solo este subconjunto para cumplir
con los estándares internacionales aplicables y la normativa boliviana:

| Campo | Estándar | Obligatorio | Implementación BOS |
|-------|---------|------------|-------------------|
| `legal_name` | ISO 17442 / KYB | ✅ | `enterprise_tenant.legal_name` en seed.yml |
| `tax_identifier` | KYB / SIN | ✅ (Bolivia) | `enterprise_tenant.tax_identifier` — NIT |
| `registration_number` | KYB / FUNDEMPRESA | ✅ (Bolivia) | `enterprise_tenant.registration_number` — Matrícula de Comercio |
| `entity_legal_form_code` | ISO 20275 | ✅ | `enterprise_tenant.entity_legal_form_code` |
| `entity_status` | ISO 17442 | ✅ | `enterprise_tenant.entity_status` — ACTIVA/INACTIVA |
| `jurisdiction_of_registration` | ISO 17442 | ✅ | `enterprise_tenant.jurisdiction_of_registration` |
| `trading_name` | KYB | Opcional | Display name en UI |
| `legal_entity_identifier` | ISO 17442 (LEI) | Opcional | Solo si el tenant participa en finanzas internacionales |
| `ultimate_beneficial_owners` | FATF / GAFILAT | Opcional | Solo para sector financiero regulado |
| `official_role_holder` | ISO 5009 | Opcional | Solo si se usa Certificado Digital AGETIC/ADSIB |

Los campos opcionales existen en el schema YAML (§14) pero el bos no los exige para el alta.
El resto de atributos de §4.2-4.5 son documentados como referencia normativa pero no se
implementan en esta fase del BOS.


---

## 5. Modelo B — Tenant Técnico / Dominio (Capa de Plataforma)

### 5.1 Definición

El **Tenant Técnico / Dominio** es la unidad de aislamiento computacional dentro de SBOS: el conjunto de namespace(s) de Kubernetes, vínculos RBAC, políticas de red, cuotas de recursos, rutas de Vault y realm/organización de Keycloak que delimitan qué puede ver, tocar o consumir un conjunto de cargas de trabajo y usuarios. Citando la definición formal de **ISO/IEC 17788**, multi-tenancy es la característica donde los recursos físicos o virtuales se asignan de forma que múltiples tenants y sus cómputos/datos están aislados e inaccesibles entre sí, y dentro de ese marco, una misma organización cliente puede tener múltiples tenencias distintas representando diferentes grupos dentro de ella misma — lo cual es la base formal de la cardinalidad 1\:N descrita en la Sección 6.

Como se detalla en la Sección 3.2, esta capa **no tiene análogo normativo boliviano o regional propio**: no existe en Bolivia, la CAN ni el Mercosur un organismo de normalización técnica que regule multi-tenancy, hardening de Kubernetes o arquitectura de cómputo en la nube. SBOS adopta, por tanto, los estándares internacionales (ISO/IEC, NIST, NSA/CISA, CIS) de forma íntegra y sin sustituto local, lo cual es, en sí mismo, una decisión de cumplimiento que debe quedar documentada.

### 5.2 Atributos de identificación del dominio

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `domain_id` | Identificador técnico único e inmutable del dominio (UUID o slug estable) | Convención interna SBOS | No aplica (campo puramente técnico) |
| `domain_name` | Nombre legible del dominio | — | No aplica |
| `domain_type` | Producción, staging, desarrollo, sandbox, DR | Convención interna SBOS | No aplica |
| `linked_enterprise_tenant_id` | Referencia obligatoria al Tenant Empresarial (Modelo A) | Sección 6 | Equivalente funcional: vínculo al NIT o Matrícula de Comercio del tenant propietario |
| `created_at` / `decommissioned_at` | Fechas de creación y baja del dominio | ISO/IEC 27001 (gestión de activos) | No aplica |

### 5.3 Atributos de aislamiento — Control Plane / API (Kubernetes)

Conforme a la primera de las tres fronteras de aislamiento descritas por la guía NSA/CISA y el CIS Kubernetes Benchmark:

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `namespace(s)` | Uno o más namespaces de Kubernetes asignados exclusivamente a este dominio | NSA/CISA Hardening Guide | Sin análogo local |
| `rbac_role_bindings` | RoleBindings/ClusterRoleBindings (vía Keycloak + impersonation, ADR-003) | NSA/CISA Hardening Guide / ADR-003 SBOS | Sin análogo local |
| `resource_quota` | `ResourceQuota` de CPU, memoria y conteo de pods | NSA/CISA Hardening Guide | Sin análogo local |
| `limit_range` | `LimitRange` por contenedor/pod dentro del namespace | NSA/CISA Hardening Guide | Sin análogo local |
| `pod_security_admission_level` | Nivel de Pod Security Admission: `restricted`, `baseline` o `privileged` | NSA/CISA Hardening Guide / CIS Benchmark | Sin análogo local |

### 5.4 Atributos de aislamiento — Red

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `network_policy_default` | Política de red por defecto: deny-all de ingreso y egreso salvo lo explícitamente permitido | NSA/CISA Hardening Guide | Sin análogo local |
| `network_policy_rules` | Reglas explícitas de ingreso/egreso permitidas para el dominio | NSA/CISA Hardening Guide | Sin análogo local |
| `service_mesh_identity` | Identidad del dominio dentro del service mesh (Linkerd) para mTLS y políticas de tráfico | NSA/CISA Hardening Guide / arquitectura SBOS | Sin análogo local |
| `api_gateway_route_scope` | Alcance de las rutas en Kong asociadas exclusivamente a este dominio | Arquitectura SBOS (ADR-010) | Sin análogo local |

### 5.5 Atributos de aislamiento — Datos y Secretos

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `database_isolation_mode` | Modo de aislamiento de base de datos: instancia dedicada, esquema dedicado, o fila con `tenant_id` | ISO/IEC 19086-4 | Sin marco normativo boliviano específico de aislamiento técnico de datos. Si en el futuro entra en vigor la Ley de Protección de Datos Personales boliviana, este campo sería relevante para demostrar medidas técnicas de seguridad ante la futura Agencia de Protección de Datos Personales |
| `vault_namespace_or_path` | Namespace o path dedicado en Vault para los secretos del dominio | Arquitectura SBOS (Vault) | Sin análogo local |
| `pv_reclaim_policy` | Política de retención de volúmenes persistentes (`Retain` por estándar SBOS) | Arquitectura SBOS (Bootstrap Manual) | Relevante de cara a obligaciones bolivianas de **conservación de documentación contable y tributaria**, que exigen retención por plazos determinados (ver normativa del SIN sobre conservación de respaldos) |
| `data_residency_constraint` | Restricción de ubicación geográfica de almacenamiento, si aplica | ISO/IEC 19086-4 / regulación de residencia de datos | Bolivia no impone, a la fecha, un requisito legal general de residencia de datos dentro del territorio nacional para el sector privado no financiero. El sector financiero regulado por ASFI sí puede estar sujeto a lineamientos de localización según normativa sectorial específica |

### 5.6 Atributos de aislamiento — Identidad

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `keycloak_realm_or_org` | Realm dedicado u organización dentro de Keycloak para el dominio | Arquitectura SBOS | Sin análogo local |
| `identity_federation_protocol` | Protocolo de federación de identidad utilizado (OIDC/SAML 2.0) si el dominio federa con un IdP externo del Tenant Empresarial | NIST SP 800-63C (Federation and Assertions) | Sin estándar técnico boliviano de federación de identidad gubernamental aplicable al sector privado; el **SEGIP** (Servicio General de Identificación Personal) gestiona la identidad civil de personas naturales pero no opera como IdP federado para sistemas corporativos privados |
| `identity_federation_scope` | Alcance de la federación de identidad | NIST SP 800-63 (serie) | Idem |

### 5.7 Atributos de nivel de servicio (SLA) y observabilidad

Conforme a la terminología de ISO/IEC 19086:

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `sla_tier` | Nivel de servicio contratado (referenciado, no definido aquí) | ISO/IEC 19086-1 | Sin marco normativo boliviano de SLA cloud; se rige por derecho contractual general del Código de Comercio y Código Civil boliviano |
| `slo_availability_target` | Objetivo de disponibilidad del dominio | ISO/IEC 19086-1/-2 | Idem |
| `pii_protection_components` | Componentes de protección de PII aplicables (cifrado en reposo, en tránsito, minimización) | ISO/IEC 19086-4 | Adoptado preventivamente; sin exigencia legal boliviana vigente equivalente, pero alineado con el contenido del Anteproyecto de Ley de Protección de Datos Personales (principios de licitud, proporcionalidad y seguridad) |
| `monitoring_endpoint` | Referencia al endpoint/daemon de monitoreo asociado (ej. `sbos-netwatch`, `bnotify`) | Arquitectura SBOS | No aplica |

### 5.8 Modelo de confianza del dominio

| Atributo | Descripción | Norma de respaldo | Análogo boliviano / regional |
|---|---|---|---|
| `tenancy_trust_model` | `soft` (tenants cooperativos) o `hard` (tenants mutuamente no confiables) | Práctica de la industria derivada de NSA/CISA Hardening Guide y CIS Benchmark | Sin análogo local |
| `isolation_mechanism` | Mecanismo de aislamiento efectivo: namespace+RBAC (soft), runtime en sandbox (gVisor/Kata), o cluster virtual/dedicado (hard) | NSA/CISA Hardening Guide | Sin análogo local |

> **Nota crítica de seguridad:** la comunidad de seguridad de Kubernetes y la propia guía NSA/CISA son explícitas en que **el namespace no constituye, por sí solo, una frontera de seguridad**. Únicamente la combinación de namespace + RBAC correctamente configurado + NetworkPolicy + Pod Security Admission + (cuando el modelo de confianza es `hard`) sandboxing a nivel de runtime o separación de control plane constituye una frontera de aislamiento defendible. SBOS debe declarar explícitamente, por cada dominio, cuál es su `tenancy_trust_model` y verificar que el `isolation_mechanism` correspondiente esté efectivamente desplegado, no asumido.

---

## 6. Mapeo entre Tenant Empresarial y Dominio Técnico

### 6.1 Cardinalidad

```
Tenant Empresarial (1) ──────< Dominio Técnico (N)
```

Esta cardinalidad 1\:N es la consecuencia directa de la definición de ISO/IEC 17788: una misma organización cliente puede tener múltiples tenencias distintas con un mismo proveedor, representando diferentes grupos o necesidades dentro de ella misma (por ejemplo: un dominio de producción, uno de staging, uno por unidad de negocio, o uno por región para cumplir residencia de datos).

### 6.2 Tabla de mapeo de referencia

| Tenant Empresarial (`legal_name` / `tax_identifier`) | Dominio Técnico (`domain_id`) | `domain_type` | `tenancy_trust_model` |
|---|---|---|---|
| Empresa Cliente S.A. (NIT: 1234567890) | `dom-prod-001` | Producción | hard |
| Empresa Cliente S.A. (NIT: 1234567890) | `dom-staging-001` | Staging | soft (interno) |
| Empresa Cliente S.A. — Subsidiaria Santa Cruz | `dom-prod-002` | Producción (residencia regional) | hard |
| Consultor Individual (Empresa Unipersonal, NIT: 9876543210) | `dom-prod-003` | Producción | hard |

### 6.3 Regla de integridad referencial

Todo `domain_id` **debe** llevar un `linked_enterprise_tenant_id` no nulo. No se permite la existencia de un dominio técnico "huérfano" sin Tenant Empresarial asociado, salvo dominios internos de SKULL marcados explícitamente como `domain_type: internal-skull`, que se rigen por una ficha separada.

### 6.4 Quién gobierna cada lado del mapeo

- El **Tenant Empresarial** (Modelo A) es gobernado por el **bos (Control Plane soberano)**. El bos almacena el registro maestro en `bkernel_db.enterprise_tenants`, ejecuta el proceso de onboarding KYB (Sección 8), y expone los datos vía JSON-RPC 2.0. Este es el patrón de la industria: AWS Tenant Management Service, Stakater MTO CRD Operator — el Control Plane es el dueño del tenant, no un daemon auxiliar.
- El **Dominio Técnico** (Modelo B) es gobernado por el bos en su creación (`bosctl deploy` → namespace + RBAC + NetworkPolicy + Quota + realm KC + paths Vault), y por `bauth` en cuanto a los bindings RBAC y federación de identidad en runtime.
- `biedata`, como único daemon autorizado para llamadas HTTP externas, es responsable de cualquier verificación externa de KYB/sanciones que requiera el Tenant Empresarial (ej. consulta a un proveedor de verificación, o consulta al portal de verificación de NIT del SIN), nunca el dominio técnico directamente.

---

## 7. Modelo de Aislamiento y Fronteras de Seguridad

Conforme a las tres fronteras de aislamiento multi-tenant identificadas por la práctica de seguridad de Kubernetes (consistente con NSA/CISA Hardening Guide y CIS Benchmark), todo Dominio Técnico de SBOS debe declarar su postura en cada una:

| Frontera | Mecanismo en SBOS | Verificación | Análogo boliviano / regional |
|---|---|---|---|
| **1. Control Plane / API** | Namespace + RBAC (con User Impersonation, ADR-003) | Auditoría de RoleBindings; ningún ClusterRoleBinding amplio sin justificación documentada | Sin análogo local |
| **2. Nodo / Host** | Contenedores (Podman, nunca Docker) + Linux namespaces + cgroups; sandboxing adicional (gVisor/Kata) si `tenancy_trust_model = hard` | Verificación de runtime class asignada por dominio | Sin análogo local |
| **3. Red** | NetworkPolicy deny-all por defecto + reglas explícitas + Linkerd mTLS | Auditoría de NetworkPolicy por namespace; verificación de cifrado en tránsito | Sin análogo local |

Para dominios con `tenancy_trust_model: hard` (la mayoría de los dominios de producción que sirven a organizaciones cliente externas), SBOS debe evaluar si el aislamiento namespace+RBAC es suficiente o si se requiere migrar a separación de control plane (cluster virtual o nodos dedicados), conforme al principio de que las fronteras de hardening genérico (CIS, NSA/CISA) son necesarias pero no garantizan por sí solas el aislamiento entre tenants mutuamente no confiables.

---

## 8. Ciclo de Vida del Tenant

### 8.1 Alta (Onboarding)

1. **Verificación KYB del Tenant Empresarial:** recolección de atributos de la Sección 4.2–4.5; en el contexto boliviano, esto incluye verificación de vigencia del NIT (consultable en el portal del SIN) y de la Matrícula de Comercio (consultable en el directorio empresarial virtual de FUNDEMPRESA), cribado de sanciones donde aplique, y asignación de `risk_rating`.
2. **Aprobación y registro:** alta del Tenant Empresarial en `bkernel_db.enterprise_tenants` (gestionado por el bos) con `kyb_verification_status: verificado`. El bos expone estos datos vía JSON-RPC 2.0 (`bos.tenant.get`).
3. **Provisión del primer Dominio Técnico:** `bosctl` crea namespace(s), RBAC, NetworkPolicy, ResourceQuota, Vault path, y realm/org en Keycloak conforme a la Sección 5, con `linked_enterprise_tenant_id` apuntando al registro creado en el paso 2.
4. **Notificación:** `bnotify` emite evento de alta de dominio a los canales de observabilidad correspondientes.

### 8.2 Operación y monitoreo continuo

- Re-verificación periódica de KYB (`kyb_last_reviewed_at`), conforme a la obligación de monitoreo continuo de los marcos AML/GAFILAT aplicables al sector regulado, extendida por SBOS como buena práctica a todo tenant.
- Auditoría periódica de las fronteras de aislamiento de cada dominio técnico (Sección 7), independiente de la auditoría empresarial.
- Verificación de vigencia del Certificado Digital de Persona Jurídica (AGETIC/ADSIB) del `official_role_holder`, si se usa como mecanismo de acreditación de representación.

### 8.3 Expansión

Creación de nuevos dominios técnicos bajo el mismo Tenant Empresarial (ej. nueva región, nueva unidad de negocio), reutilizando el registro del Modelo A sin re-ejecutar el KYB completo, salvo cambio material en la entidad legal (cambio de razón social, cambio de representante legal, fusión).

### 8.4 Baja (Offboarding)

1. Marca de `entity_status` o `domain_type` según corresponda.
2. Aplicación de la política de retención de datos (`pv_reclaim_policy: Retain` como estándar SBOS), con proceso explícito de purga posterior según el plazo de retención contractual y, donde aplique, los plazos de conservación documental tributaria exigidos por el SIN.
3. Revocación de RBAC bindings, rotación/revocación de secretos en Vault, desactivación de realm en Keycloak.
4. Conservación de registros de auditoría conforme a ISO/IEC 27001 y a las obligaciones de conservación documental aplicables en Bolivia.

---

## 9. Componentes SBOS Involucrados

| Componente | Rol respecto al Tenant |
|---|---|
| **bos (IAM Installer)** | **Control Plane soberano — dueño del ciclo de vida del tenant.** Orquesta alta/baja/expansión de dominios técnicos. Gestiona el registro del Tenant Empresarial (Modelo A) como parte de su estado interno (.sbos_state.json + bkernel_db). Ejecuta `bosctl deploy` para provisionar dominios completos. Patrón: CRD + Operator (K8s Tenant Operator pattern, AWS Control Plane pattern) — el seed.yml es el CRD, el bos es el Operator que reconcilia |
| `bauth` | Gestión de RBAC, bindings, e identidad federada del Dominio Técnico (Modelo B). Evalúa BitMask en cada request |
| `bkernel` | CDC listener + fanout Redis Streams. Propaga eventos de tenant (alta, baja, cambio de estado) a los daemons interesados |
| `bosctl` | CLI de administración. Comandos: `deploy`, `tenant suspend/remove/list`. Interfaz humana al Control Plane |
| `biedata` | JSON-RPC 2.0 gateway. Ejecuta verificaciones externas de KYB/sanciones contra portales públicos (SIN, FUNDEMPRESA) cuando se requieren. Único autorizado para HTTP externo |
| `bnotify` | Notificación de eventos del ciclo de vida del tenant (alta, baja, cambios de estado) vía push/email/MFA |
| `bsearch` | Indexación y búsqueda de registros de tenant para operaciones administrativas (PostgreSQL 18+ nativo) |
| `kong` + Keycloak | API Gateway + Identity Provider. Kong valida ctx_id vía Context API :9443. Keycloak emite JWT con claims del tenant |

---

## 10. Cumplimiento y Trazabilidad Normativa

Esta tabla resume, por marco regulatorio o de control, qué parte de este documento lo satisface, distinguiendo entre marcos de cumplimiento obligatorio en Bolivia y marcos adoptados voluntariamente por buena práctica:

| Marco | Carácter en Bolivia | Control relevante | Sección de este documento |
|---|---|---|---|
| Código de Comercio boliviano / FUNDEMPRESA | Obligatorio | Identificación legal de la entidad (Matrícula de Comercio, forma jurídica) | Sección 4.2 |
| Régimen del SIN (NIT, Padrón de Contribuyentes) | Obligatorio | Identificación fiscal del tenant | Sección 4.2 |
| Ley N.º 164 / D.S. N.º 1793 (AGETIC/ADSIB, Certificado Digital) | Obligatorio (cuando se usa firma/certificado digital) | Acreditación de representación legal | Sección 4.4, 8.2 |
| Reglamento TIC de la ATT (Ley 164) | Obligatorio (alcance limitado) | Tratamiento de datos en telecomunicaciones | Sección 5.7 (referencia preventiva) |
| Anteproyecto de Ley de Protección de Datos Personales (AGETIC) | **No vigente — sin fuerza legal**, adoptado preventivamente | Principios de licitud, proporcionalidad, seguridad de datos personales | Sección 4.5, 5.5, 5.7 |
| GAFILAT / normativa AML del sector financiero (ASFI, UIF) | Obligatorio solo para sujetos obligados del sistema financiero; voluntario para SBOS fuera de ese sector | Debida diligencia de cliente, UBO, monitoreo continuo | Sección 4.3, 4.5, 8.1–8.2 |
| NIST SP 800-30 | Voluntario (buena práctica internacional) | Identificación de activos y fronteras del sistema | Secciones 5, 7 |
| ISO/IEC 27001:2022 | Voluntario (certificable en Bolivia vía organismos acreditados, sin norma nacional sustitutiva) | Inventario de activos (A.5.9), gestión de identidad (A.5.16) | Secciones 4, 5, 6 |
| CIS Controls v8 | Voluntario | Control 3 (Protección de datos), Control 6 (Gestión de control de acceso) | Sección 5.3–5.6 |
| NSA/CISA Kubernetes Hardening Guide | Voluntario (sin sustituto nacional) | Namespace hardening, network hardening | Secciones 5.3–5.4, 7 |
| ISO/IEC 19086-4 | Voluntario | Protección de PII en SLA cloud | Secciones 5.5, 5.7 |

---

## 11. Marco Regulatorio Boliviano y Regional — Detalle Ampliado

Esta sección documenta, de forma independiente y ampliada, las entidades y normas bolivianas y regionales referenciadas a lo largo del documento, para que sirvan como ficha de consulta autónoma.

### 11.1 Entidades bolivianas relevantes para el Tenant Empresarial

| Entidad | Naturaleza | Función relevante para SBOS |
|---|---|---|
| **FUNDEMPRESA** | Fundación sin fines de lucro, opera el Registro de Comercio de Bolivia por delegación del Estado | Otorga personalidad jurídica y Matrícula de Comercio; certifica la legalidad y unicidad del nombre de la empresa |
| **Servicio de Impuestos Nacionales (SIN)** | Entidad estatal | Emite y administra el NIT; gestiona el Padrón Nacional de Contribuyentes |
| **AGETIC** (Agencia de Gobierno Electrónico y Tecnologías de Información y Comunicación) | Entidad estatal, dependiente del Ministerio de la Presidencia | Emite Certificados Digitales de Persona Natural y Jurídica para firma digital y facturación electrónica; impulsa el Anteproyecto de Ley de Protección de Datos Personales |
| **ADSIB** (Agencia para el Desarrollo de la Sociedad de la Información en Bolivia) | Entidad estatal | Entidad Certificadora Pública bajo la Ley N.º 164 |
| **ATT** (Autoridad de Regulación y Fiscalización de Telecomunicaciones y Transportes) | Entidad estatal regulatoria | Entidad Certificadora Raíz para certificación digital; regula el tratamiento de datos en telecomunicaciones bajo su Reglamento TIC |
| **ASFI** (Autoridad de Supervisión del Sistema Financiero) | Entidad estatal regulatoria | Supervisión de debida diligencia y AML en el sector financiero regulado |
| **UIF** (Unidad de Investigaciones Financieras) | Entidad estatal | Análisis financiero y cumplimiento AML, vínculo con GAFILAT |
| **SEGIP** (Servicio General de Identificación Personal) | Entidad estatal | Identificación civil de personas naturales; no opera como proveedor de identidad federada para sistemas corporativos privados |

### 11.2 Bloques regionales y su alcance real

| Bloque | Membresía boliviana | Alcance normativo relevante para este documento |
|---|---|---|
| **Comunidad Andina (CAN)** | Bolivia es País Miembro | La **Decisión 486** (Régimen Común sobre Propiedad Industrial) regula el secreto empresarial y aspectos de protección de información no divulgada de las empresas, relevante para la confidencialidad competitiva del Tenant Empresarial, aunque no define identidad empresarial ni protección de datos personales de forma armonizada. La CAN no cuenta, a la fecha, con una decisión vinculante de protección de datos personales equivalente al GDPR ni con un identificador empresarial regional equivalente al LEI |
| **Mercosur** | Bolivia es Estado en proceso de adhesión / Estado Asociado según el periodo; no es miembro pleno con voto en todas las decisiones | No existe, a la fecha, un marco normativo vinculante de Mercosur sobre protección de datos personales o identificación empresarial de aplicación directa y armonizada en los Estados Parte; los esfuerzos de armonización (p. ej. en datos biométricos fronterizos) son sectoriales y no constituyen un GDPR regional |
| **GAFILAT** | Bolivia es miembro | Brazo regional del GAFI/FATF; relevante para el marco KYB/AML del sector financiero regulado (Sección 4.3, 4.5) |

### 11.3 Conclusión operativa para SBOS

No existe, ni a nivel boliviano ni a nivel de la CAN o Mercosur, un marco normativo horizontal y vinculante equivalente al conjunto ISO 17442 + GDPR + NSA/CISA Hardening Guide adoptado en este documento. La estrategia de SBOS es, por tanto, de **cumplimiento mínimo obligatorio boliviano + adopción voluntaria de estándar internacional como techo de buena práctica**, documentada explícitamente en cada tabla de este documento para que la ausencia de exigencia legal local no se confunda nunca con ausencia de control.

---

## 12. Glosario

- **Tenant Empresarial:** entidad legal (sociedad o Empresa Unipersonal) que es propietaria de uno o más dominios técnicos en SBOS.
- **Dominio Técnico:** unidad de aislamiento computacional (namespace + RBAC + red + datos + identidad) en SBOS.
- **LEI (Legal Entity Identifier):** código de 20 caracteres bajo ISO 17442 que identifica unívocamente a una entidad legal a nivel global.
- **NIT (Número de Identificación Tributaria):** identificador fiscal boliviano emitido por el SIN; análogo funcional local del identificador fiscal exigido en marcos KYB internacionales.
- **Matrícula de Comercio:** identificador de registro mercantil emitido por FUNDEMPRESA en Bolivia.
- **UBO (Ultimate Beneficial Owner):** persona física que posee o controla, directa o indirectamente, una participación igual o superior al umbral regulatorio (típicamente 25%) de una entidad legal.
- **OOR (Official Organizational Role):** rol oficial normalizado bajo ISO 5009 que habilita a una persona física a actuar en representación de una entidad legal.
- **MAE (Máxima Autoridad Ejecutiva):** denominación boliviana habitual para la máxima autoridad de representación de una entidad ante organismos del Estado.
- **Soft multi-tenancy:** modelo de aislamiento basado en namespace+RBAC, adecuado para tenants cooperativos.
- **Hard multi-tenancy:** modelo de aislamiento reforzado (sandboxing de runtime o separación de control plane) requerido cuando los tenants son mutuamente no confiables.
- **PV Reclaim Policy:** política de Kubernetes que determina qué ocurre con un volumen persistente cuando su reclamo (`PersistentVolumeClaim`) es eliminado; SBOS estandariza `Retain`.
- **GAFILAT:** Grupo de Acción Financiera de Latinoamérica, brazo regional del GAFI/FATF, del cual Bolivia es miembro.

---

## 13. Riesgos y Limitaciones del Modelo

Esta sección documenta explícitamente las limitaciones conocidas de este documento, para evitar que se interprete como una garantía de cumplimiento absoluto.

| Riesgo / limitación | Descripción | Mitigación recomendada |
|---|---|---|
| **Cambio regulatorio pendiente en Bolivia** | El Anteproyecto de Ley de Protección de Datos Personales podría aprobarse y crear una Agencia de Protección de Datos Personales con obligaciones nuevas no contempladas en detalle aquí | Revisar este documento ante cualquier avance legislativo confirmado; los campos de la Sección 4.5 y 5.7 ya están diseñados para absorber dicho cambio sin rediseño estructural |
| **Ausencia de LEI en la mayoría de los tenants bolivianos** | La mayoría de las empresas bolivianas, incluso medianas, no poseen ni necesitan un LEI; el campo `legal_entity_identifier` quedará vacío en la mayoría de los registros | Tratar el campo como opcional, nunca como bloqueante del alta del Tenant Empresarial; usar NIT + Matrícula de Comercio como identificador primario en el contexto boliviano |
| **Namespace no es una garantía legal de confidencialidad** | Confundir el aislamiento técnico (Modelo B) con una garantía de confidencialidad legal (Modelo A) es un error de diseño frecuente | Mantener la separación estricta entre ambos modelos descrita en la Sección 2; toda cláusula contractual de confidencialidad debe respaldarse en controles verificados de la Sección 7, no asumidos |
| **Dependencia de fuentes públicas externas para verificación KYB** | La verificación de NIT y Matrícula de Comercio depende de la disponibilidad de los portales del SIN y FUNDEMPRESA, fuera del control de SBOS | `biedata` debe implementar manejo de fallos y reintentos; el estado `kyb_verification_status: pendiente` debe ser un estado válido y no bloqueante de operaciones internas no críticas |
| **No constituye asesoría legal** | Este documento es una ficha de arquitectura técnica, no un dictamen jurídico | Toda implementación de los campos de la Sección 4 relativos a cumplimiento legal debe validarse con asesoría legal boliviana antes de su uso en producción, particularmente en materia tributaria y societaria |
| **Asimetría entre estándares internacionales y exigibilidad local** | Adoptar ISO/NIST/NSA-CISA no genera, por sí solo, cumplimiento legal boliviano si no existe norma local que lo exija; tampoco exime de cumplir la norma boliviana vigente aunque sea menos exigente | Mantener siempre la distinción de la Sección 10 entre "obligatorio en Bolivia" y "voluntario/buena práctica" en cualquier comunicación con stakeholders o auditores |

---

## 14. Anexo — Esquemas de Datos de Referencia

Esquemas ilustrativos en formato YAML para uso como punto de partida de implementación en el bos — `bkernel_db.enterprise_tenants` (Modelo A) y `bkernel`/`bauth` (Modelo B). No son un contrato de API definitivo; deben validarse contra la implementación real de cada daemon.

### 14.1 Esquema de referencia — Tenant Empresarial (Modelo A)

```yaml
enterprise_tenant:
  legal_name: "string"                       # Razón social / nombre del titular (Empresa Unipersonal)
  trading_name: "string | null"
  legal_entity_identifier: "string(20) | null"   # LEI, opcional
  entity_legal_form_code: "enum"              # EMPRESA_UNIPERSONAL | SRL | SA | SOC_COLECTIVA | ...
  jurisdiction_of_registration: "string"      # Departamento / país
  registration_number: "string"               # Matrícula de Comercio (FUNDEMPRESA)
  tax_identifier: "string"                    # NIT (SIN)
  registered_address: "string"
  operating_address: "string | null"
  entity_status: "enum"                       # ACTIVA | INACTIVA | EN_DISOLUCION | FUSIONADA
  registration_date: "date"
  municipal_operating_license:
    number: "string | null"
    issuing_municipality: "string | null"
  relations:
    direct_parent_entity: "ref(enterprise_tenant) | null"
    ultimate_parent_entity: "ref(enterprise_tenant) | null"
    ultimate_beneficial_owners:
      - full_name: "string"
        ownership_percentage: "decimal"
        identification_document: "string"
    relationship_type: "enum"                 # CLIENTE_DIRECTO | SUBSIDIARIA | PARTNER | PROVEEDOR
  official_roles:
    - role_holder_full_name: "string"
      official_role_code: "enum"              # REPRESENTANTE_LEGAL | MAE | APODERADO | DIRECTOR
      role_evidence_reference: "string"        # Referencia documental
      role_valid_from: "date"
      role_valid_until: "date | null"
  compliance:
    incorporation_documents:
      - "ref(document)"
    kyb_verification_status: "enum"           # PENDIENTE | VERIFICADO | RECHAZADO | EN_REVISION
    kyb_last_reviewed_at: "datetime | null"
    sanctions_screening_status: "enum | null"  # NO_APLICA | LIMPIO | ALERTA
    risk_rating: "enum"                        # BAJO | MEDIO | ALTO
    contact_data_processing_basis: "string | null"
```

### 14.2 Esquema de referencia — Dominio Técnico (Modelo B)

```yaml
technical_domain:
  domain_id: "uuid"
  domain_name: "string"
  domain_type: "enum"                          # PRODUCCION | STAGING | DESARROLLO | SANDBOX | DR
  linked_enterprise_tenant_id: "ref(enterprise_tenant)"   # Obligatorio, sin excepción
  created_at: "datetime"
  decommissioned_at: "datetime | null"
  control_plane:
    namespaces: ["string"]
    rbac_role_bindings: ["ref(rbac_binding)"]
    resource_quota:
      cpu_limit: "string"
      memory_limit: "string"
      max_pods: "integer"
    limit_range: "ref(limit_range_policy)"
    pod_security_admission_level: "enum"        # restricted | baseline | privileged
  network:
    network_policy_default: "enum"              # deny_all_default
    network_policy_rules: ["ref(network_policy)"]
    service_mesh_identity: "string"
    api_gateway_route_scope: "string"
  data_and_secrets:
    database_isolation_mode: "enum"             # INSTANCIA_DEDICADA | ESQUEMA_DEDICADO | ROW_LEVEL
    vault_namespace_or_path: "string"
    pv_reclaim_policy: "enum"                    # Retain (estándar SBOS)
    data_residency_constraint: "string | null"
  identity:
    keycloak_realm_or_org: "string"
    identity_federation_protocol: "enum | null"  # OIDC | SAML2 | null
    identity_federation_scope: "string | null"
  sla:
    sla_tier: "string"
    slo_availability_target: "decimal"
    pii_protection_components: ["string"]
    monitoring_endpoint: "string"
  trust_model:
    tenancy_trust_model: "enum"                  # soft | hard
    isolation_mechanism: "enum"                  # namespace_rbac | runtime_sandbox | virtual_cluster | dedicated_cluster
```

---

## 15. Referencias Normativas

### 15.1 Estándares internacionales

1. **ISO 17442** — Financial services — Legal entity identifier (LEI). International Organization for Standardization / Global Legal Entity Identifier Foundation (GLEIF).
2. **ISO 20275** — Financial services — Entity legal forms (ELF) — Code list. ISO / GLEIF (Maintenance Agency).
3. **ISO 5009** — Official Organizational Roles (OOR) Code List. ISO/TC 68 / GLEIF (Maintenance Agency).
4. **ISO/IEC 17788:2014** — Information technology — Cloud computing — Overview and vocabulary. ISO/IEC JTC 1/SC 38.
5. **ISO/IEC 17789:2014** — Information technology — Cloud computing — Reference architecture. ISO/IEC JTC 1/SC 38.
6. **ISO/IEC 19086-1:2016** — Cloud computing — Service level agreement (SLA) framework — Part 1: Overview and concepts.
7. **ISO/IEC 19086-2:2018** — Cloud computing — Service level agreement (SLA) framework — Part 2: Metric model.
8. **ISO/IEC 19086-3:2017** — Cloud computing — Service level agreement (SLA) framework — Part 3: Core conformance requirements.
9. **ISO/IEC 19086-4:2019** — Cloud computing — Service level agreement (SLA) framework — Part 4: Components of security and of protection of PII.
10. **ISO/IEC 27001:2022** — Information security, cybersecurity and privacy protection — Information security management systems — Requirements.
11. **NIST Special Publication 800-145** — The NIST Definition of Cloud Computing. National Institute of Standards and Technology.
12. **NIST Special Publication 800-30** — Guide for Conducting Risk Assessments. National Institute of Standards and Technology.
13. **NIST Special Publication 800-63** (serie, incluyendo 800-63C Federation and Assertions) — Digital Identity Guidelines. National Institute of Standards and Technology.
14. **NSA/CISA Kubernetes Hardening Guidance** — National Security Agency / Cybersecurity and Infrastructure Security Agency.
15. **CIS Kubernetes Benchmark v8** — Center for Internet Security.
16. **FATF Recommendations** — Financial Action Task Force, particularmente las relativas a debida diligencia del cliente (Customer Due Diligence) y beneficiarios finales.
17. **FinCEN Customer Due Diligence (CDD) Rule** — Financial Crimes Enforcement Network (referencia de marco KYB).

### 15.2 Normativa boliviana

18. **Código de Comercio del Estado Plurinacional de Bolivia** — Marco legal de formas jurídicas societarias y registro de comercio.
19. **Ley N.º 164**, de 8 de agosto de 2011 — Ley General de Telecomunicaciones, Tecnologías de Información y Comunicación. Establece validez jurídica de la firma y certificación digital, y las competencias de la ATT como Entidad Certificadora Raíz.
20. **Decreto Supremo N.º 1793**, de 13 de noviembre de 2013 — Reglamento a la Ley N.º 164 para el Desarrollo de Tecnologías de Información y Comunicación. Regula las características y requisitos del certificado digital, incluida la acreditación de representación (art. 27).
21. **Anteproyecto de Ley de Protección de Datos Personales** — AGETIC, presentado ante la Asamblea Legislativa Plurinacional desde el 30 de noviembre de 2018. **Sin aprobación a la fecha de este documento**; referenciado únicamente como indicador de dirección regulatoria futura.
22. **Reglamento de Desarrollo de Tecnologías de Información y Comunicación de la ATT** — Marco vigente y aplicable de tratamiento de datos en telecomunicaciones, bajo la Ley N.º 164.
23. Normativa operativa de **FUNDEMPRESA** — Registro de Comercio de Bolivia (Matrícula de Comercio, homonimia, directorio empresarial).
24. Normativa operativa del **Servicio de Impuestos Nacionales (SIN)** — Padrón Nacional de Contribuyentes y Número de Identificación Tributaria (NIT).

### 15.3 Normativa e instrumentos regionales (CAN / Mercosur / GAFILAT)

25. **Decisión 486** de la Comisión de la Comunidad Andina — Régimen Común sobre Propiedad Industrial (incluye disposiciones sobre secreto empresarial e información no divulgada).
26. **Recomendaciones del GAFILAT** (Grupo de Acción Financiera de Latinoamérica) — Adaptación regional de las Recomendaciones del GAFI/FATF, de aplicación al sector financiero regulado boliviano.
27. **Acuerdo Marco de Servicios de Mercosur (1997) y anexos sectoriales** — Referenciado únicamente para constatar la ausencia de un marco horizontal vinculante de protección de datos personales o identificación empresarial a nivel de bloque.

### 15.4 Normativa de referencia de otros países de la región (comparativa, no vinculante para Bolivia)

28. **Ley 1581 de 2012** (Colombia) — Régimen General de Protección de Datos Personales.
29. **Ley 25.326** (Argentina) — Ley de Protección de los Datos Personales.
30. **Ley N.º 18.331/2008** (Uruguay) — Protección de Datos Personales y Acción de "Habeas Data".
31. **Ley N.º 13.709/2018 — LGPD** (Brasil) — Lei Geral de Proteção de Dados Pessoais.

---

*Fin del documento SBOS-0XX-TENANT-SPEC.md*
