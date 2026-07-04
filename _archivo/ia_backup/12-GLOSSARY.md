# Glosario del Proyecto

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth), SBOS-000-INDEX (v6), SBOS-002-ARCH (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## Terminos propios del proyecto

| Termino | Definicion operacional | Contexto de uso |
|---|---|---|
| SBOS | Sovereign Business Operating System | Sistema operativo empresarial soberano |
| bAuth | Sistema de identidad del SBOS | Coordinador KC-Tryton, PrivilegeEngine, 6 responsabilidades |
| RolTemplate | Contrato unico de identidad. Define permisos, herencia, metodos auth | Fuente de verdad del sistema de identidad |
| UserTemplate | Contrato de usuario concreto. Hereda del RolTemplate | Registro de persona |
| BitmaskBundle | 3x uint64: PhysicalDomainMask + LogicalDomainMask + FinancialDomainMask | Vector de autorizacion O(1) |
| SAM-128 | Sovereign Authority Matrix | Matriz de autoridad soberana (3 dominios) |
| PrivilegeEngine | Motor algebraico H-RBAC de bAuth | Calculo de BitmaskBundle desde RolTemplate |
| AND NOT | Operacion A &^ B en Go | Herencia jerarquica, revocacion de emergencia |
| bos_bitmask (legacy) | Reemplazado por BitmaskBundle v5.0 | No usar -- migrar a BitmaskBundle |
| deploy.yml | Configuracion de despliegue regional | Unico lugar donde vive la jurisdiccion |
| Drift | Estado donde KC o Tryton divergen del RolTemplate | Reconcile loop detecta y corrige |
| NEXUS | Unidad compuesta bhnexus + banexus | Conectividad soberana y centinela edge |
| bhnexus | Sovereign Connectivity Broker | Router central de credenciales fisicas, auth cache |
| banexus | Edge Sentinel | Interceptor USB/shell, cache efimero |
| Ficha | Unidad atomica de despliegue SBOS | manifest.yml + yaml_engine.yml + resources/ |
| bKernel | Daemon de consolidacion via WAL | Plano de datos, sincronizacion de apps |
| biedata | Daemon de integracion exterior | Conector SIN/AFIP/SAT, Box Engine |
| bCompass | Daemon de inteligencia | Rutas IA, Route Engine, Langfuse |
| bSearch | Daemon de busqueda | Indexacion federada Typesense |
| Core UI | Interfaz de administracion | Dart/Flutter, PAP de bAuth |
| SBOS VDI | Escritorio corporativo soberano | Fedora KDE Plasma |
| LoA | Level of Assurance 1-4 | Nivel de autenticacion (bauth) |
| ACR | Authentication Context Reference | Claim JWT del LoA actual |
| AMR | Authentication Method Reference | Array de metodos usados (RFC 8176) |
| H-RBAC | Hierarchical RBAC | ANSI/INCITS 359-2004 con AND NOT |
| PAP/PIP/PDP/PEP | Puntos del control de acceso | Policy Administration/Information/Decision/Enforcement |
| Passkey | Credencial FIDO2/WebAuthn sincronizable | AAL2 valido, nativo KC 26.6.1 |
| SoD | Separation of Duties | Conflict Matrix, nadie ejecuta punta a punta |
| Step-Up | RFC 9470 | LoA superior sin interrumpir sesion |
| SPI | Service Provider Interface de KC | Extension via JARs en /opt/keycloak/providers/ |

## Acronimos

| Acronimo | Expansion |
|---|---|
| SBOS | Sovereign Business Operating System |
| bAuth | Sistema de autenticacion SBOS |
| H-RBAC | Hierarchical Role-Based Access Control |
| SAM | Sovereign Authority Matrix |
| SoD | Separation of Duties |
| LoA | Level of Assurance |
| ACR | Authentication Context Reference |
| AMR | Authentication Method Reference |
| SPI | Service Provider Interface |
| WAL | Write-Ahead Log |
| LSN | Log Sequence Number |
| DPoP | Demonstrating Proof of Possession (RFC 9449) |
| FAPI | Financial-grade API |
| PQC | Post-Quantum Cryptography |
| ML-KEM | Module-Lattice Key Encapsulation Mechanism (FIPS 203) |
| ML-DSA | Module-Lattice Digital Signature Algorithm (FIPS 204) |
| SLH-DSA | Stateless Hash-based Digital Signature (FIPS 205) |
