# Identidad del Proyecto

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS -- Sovereign Business Operating System
**Fuentes:** SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth), SBOS-001-VISION (v6), SBOS-002-ARCH (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Nombre del proyecto
SBOS -- Sovereign Business Operating System

## Empresa / organizacion
SKULL (SISTEMASSKULL) -- Fabrica de Software ORQUESTA

## Declaracion de proposito
SBOS es un sistema operativo empresarial soberano que instala en el servidor del cliente toda la infraestructura digital que una organizacion necesita para operar -- ERP, RRHH, CRM, correo, comunicaciones, identidad, escritorio corporativo e inteligencia artificial -- sin que ningun dato salga de ese servidor y sin licencias de proveedores externos. Instalable en 45 minutos, reemplaza 8-15 herramientas SaaS, elimina USD 5,850-15,000/mes en licencias.

## Arquitecto Lider
Ivan Villanueva -- CTO/Arquitecto Lead SKULL. Decisiones arquitectonicas finales, ADRs.

## Mercado objetivo
PYME iberoamericana (20-500 empleados) con datos sensibles y cumplimiento tributario local (SIN Bolivia, AFIP Argentina, SAT Mexico). Secundario: contadores multicliente. Terciario: instituciones educativas y de salud.

## Restricciones no negociables
| # | Restriccion | Tipo |
|---|---|---|
| R1 | Datos del cliente NUNCA salen de su infraestructura | Soberania |
| R2 | bKernel consolida datos SIN modificar apps ni sus BDs | Cero invasion |
| R3 | 100% open source, licencias OSI-approved | Legal |
| R4 | Toda app del stack DEBE soportar PostgreSQL | Arquitectonica |
| R5 | Toda app DEBE ser gobernada por Keycloak (OIDC nativo u OAuth2-Proxy) | Arquitectonica |
| R6 | K8s desde el dia 1 | Operacional |
| R7 | Extensibilidad por fichas -- agregar app nueva NO modifica el Core | Arquitectonica |
| R8 | IAM Installer construye su propia plataforma (instala K8s) | Operacional |
| R9 | Secrets via Vault -- cero passwords en texto claro | Seguridad |
| R10 | Daemons soberanos en el host (systemd, NO pods K8s) | Arquitectonica |
| R11 | Idempotencia obligatoria en toda operacion | Operacional |
| R12 | Diagnostico antes de reparar (diagnosis_first: true) | Operacional |
| R13 | Pull-only para actualizaciones -- SKULL nunca empuja codigo sin consentimiento | Soberania |
| R14 | bAuth es el sistema de identidad -- el SBOS no consulta KC directamente | Arquitectonica (bauth) |
| R15 | Keycloak version canonica: 26.6.1 (CVE-2026-4366 + CVE-2026-4633 corregidos) | Seguridad (bauth) |

## Estado actual del proyecto
Fase C.2b (Construccion). 24 sesiones registradas (S-10 a S-23 en SKDATA). 7 nodos de agentes: BosAgent (en-construccion, 22 Go + 45 Rust + 376 YAML), BauthAgent (en-construccion, 27 Go), BintelligenceAgent (en-construccion, 8 Go), BnexusAgent (en-construccion, 10 Go), InfraAgent (en-concepcion), BkernelAgent (en-concepcion), BstyleAgent (en-concepcion). BOS installer certificado (S-23, 18/18 fichas HEALTHY en sbos-k8s).
