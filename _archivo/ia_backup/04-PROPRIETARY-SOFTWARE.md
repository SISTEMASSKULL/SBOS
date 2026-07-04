# Software Propio a Construir

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth), SBOS-002-ARCH (v6), SBOS-005-STACK (v6), SBOS-018-DAEMON-BOS (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## 8 Daemons Soberanos (systemd, fuera de K8s)

| Daemon | Lenguaje | BD propia | Estado nodo | Codigo real | Funcion |
|---|---|---|---|---|---|
| IAM Installer (bos) | Go | bos_db | en-construccion | 22 Go + 376 YAML | Plano de control: instala, vigila, repara. Certificado S-23 |
| bKernel | Rust | bkernel_db | en-concepcion | 0 lineas | Plano de datos: sincroniza apps via WAL, Rule Engine YAML |
| biedata | Rust | biedata_db | en-concepcion | 0 lineas | Plano de integracion: conecta con SIN/AFIP/SAT, Box Engine |
| bCompass | Go | bcompass_db | en-construccion | 8 Go | Plano de inteligencia: Route Engine + Langfuse + HITL |
| bSearch | Go | -- | en-construccion | 8 Go (en bintelligence) | Plano de busqueda: indexacion federada Typesense |
| bAuth | Go | bauth_db | en-construccion | 27 Go | Plano de identidad: H-RBAC, BitmaskBundle 3x uint64, 15 metodos auth |
| bhnexus | Go | -- | en-construccion | 10 Go (en bnexus) | Plano de conectividad: broker hardware, WebSocket mTLS |
| banexus | Go (--user) | -- | en-construccion | 10 Go (en bnexus) | Plano edge: interceptor USB/shell, centinela Fedora VDI |

## Core SP-01 (IAM Installer)

| Componente | Tipo | Lenguaje |
|---|---|---|
| 00_MASTER_INSTALL_SBOS.sh | Script maestro | Bash |
| 00_TASK_CATALOG_SBOS.sh | Catalogo de tareas | Bash |
| 00_YAML_ENGINE_SBOS.sh | Motor YAML declarativo | Bash |
| 00_ARCHITECTURE_SBOS.yml | Arquitectura declarativa | YAML |
| STATE_MANAGER.py | Gestion de estado (fcntl flock) | Python |
| DEPENDENCY_RESOLVER.py | Resolucion de dependencias (Kahn) | Python |
| HEALTH_CHECKER.py | Verificacion de salud | Python |
| LOGGER.py | Logging estructurado | Python |
| PROCESS_MANAGER.py | Gestion de procesos | Python |
| bos (binario Go) | Daemon residente | Go |
| bosctl | CLI administracion local | Go |

## Detalle bAuth (PRECEDENCIA MAXIMA -- bauth v5.0)

bAuth es el sistema de identidad del SBOS. 6 responsabilidades, 15 metodos de autenticacion canonicos, 5 SPIs para Keycloak.

### SAM-128 -- Sovereign Authority Matrix (Version Corregida v5.0)
Estructura: BitmaskBundle con 3 registros uint64 independientes:
- **PhysicalDomainMask**: sesion, shell, apps escritorio, puertas, zonas fisicas, caja (24 bits operativos)
- **LogicalDomainMask**: zonas de negocio x verbos (CONTABILIDAD, RRHH, VENTAS, FACTURACION, etc.)
- **FinancialDomainMask**: limites transaccionales, SoD, aprobaciones, nómina, auditoria financiera
- **GovernanceMask**: LoA 1-4, role tier, auditoria forzada, superusuario, emergencia

Operadores correctos (corregidos vs v4.0): AND NOT para herencia, OR para merge de roles, Conflict Matrix para SoD.

### 5 SPIs para Keycloak (JARs Java)
| SPI | Clase | Funcion |
|---|---|---|
| BOS-Guard | SkbosGuardAuthenticator | Bloquea metodos auth no autorizados para el rol |
| BOS-GeoContext | SkbosGeoContextAuthenticator | Verifica IP en allowed_networks |
| BOS-FinancialPeriod | SkbosFinancialPeriodAuthenticator | Deniega logins fuera de ventanas financieras |
| BOS-RoleValidity | SkbosRoleValidityAuthenticator | Verifica role_valid_until no expirado |
| BOS-StepUp | SkbosStepUpCondition | RFC 9470 -- step-up de LoA |

Stack tecnologico bAuth: Go 1.22+, pgx/v5, kolo/xmlrpc, coder/websocket, golang-jwt/jwt/v5, BurkntSushi/toml, rs/zerolog.

## Productos SKULL

| Producto | Licencia | Funcion |
|---|---|---|
| SmartTax | MIT | Tax compliance BO/AR/MX -- firma XML, envio SIN/AFIP/SAT |
| SmartReport | MIT | BI avanzado y reporteria |
| SmartRates | MIT | Pricing engine dinamico |
