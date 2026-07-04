# Modelo de Dominio

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth), SBOS-003-DOMAIN (v6), SBOS-002-ARCH (v6)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## 8 Bounded Contexts

| # | Bounded Context | Servidor logico | Fuente de Verdad | Entidad central |
|---|---|---|---|---|
| BC-01 | Financiero-Contable | erpserver | Tryton ERP | party.party |
| BC-02 | RRHH | appsserver | OrangeHRM | hs_hr_employee |
| BC-03 | Ventas y CRM | appsserver | Saleor + EspoCRM | contacts, orders |
| BC-04 | Identidad | identityserver | Keycloak + bAuth | user, realm, role, RolTemplate |
| BC-05 | Comunicaciones | commsserver | Postfix + Mattermost + Centrifugo | mailbox, channel |
| BC-06 | Reportes e Inteligencia | reportserver | Superset + Airflow | dashboard, pipeline |
| BC-07 | IA Soberana | aiserver | Qdrant + bCompass | embedding, query |
| BC-08 | Integracion Exterior | daemon biedata | biedata | caja, mensaje externo |
| BC-09 | Plataforma | host + K8s | IAM Installer + K8s + bKernel | ficha, cluster state |

## Entidades clave -- BC-04 Identidad (PRECEDENCIA BAUTH)

bAuth es el **sistema de identidad del SBOS**. Keycloak y Tryton son sus brazos de ejecucion. El SBOS no consulta KC directamente -- consulta bAuth.

| Entidad | Descripcion | Fuente |
|---|---|---|
| RolTemplate | Contrato unico de identidad. Define permisos, herencia H-RBAC, metodos auth, SoD. Almacenado en JSONB en bos_rol_template. | bAuth v5.0 |
| UserTemplate | Contrato de usuario concreto. Hereda permisos del RolTemplate. | bAuth v5.0 |
| BitmaskBundle | 3x uint64: PhysicalDomainMask + LogicalDomainMask + FinancialDomainMask | bAuth v5.0 |
| SAM-128 | Sovereign Authority Matrix -- vector de autorizacion O(1) en 3 dominios | bAuth v5.0 |
| PrivilegeEngine | Motor algebraico H-RBAC con AND NOT, Conflict Matrix, herencia jerarquica | bAuth v5.0 |
| SAM Physical | 64 bits: sesion, shell, apps escritorio, puertas, zonas fisicas, caja | bAuth v5.0 |
| SAM Logical | 64 bits: zonas de negocio x verbos (READ, WRITE, APPROVE, AUDIT) | bAuth v5.0 |
| SAM Financial | 64 bits: limites transaccionales, SoD, aprobaciones, nómina | bAuth v5.0 |
| GovernanceMask | 64 bits: LoA, role tier, auditoria forzada, superusuario, emergencia | bAuth v5.0 |

## Los 8 Daemons Soberanos (systemd, NO pods K8s)

| Daemon | Servicio | Lenguaje | Responsabilidad |
|---|---|---|---|
| IAM Installer | bos.service | Go | Plano de control: instala, vigila, repara |
| bKernel | bkernel.service | Rust | Plano de datos: sincroniza apps via WAL |
| biedata | biedata.service | Rust | Plano de integracion: conecta con sistemas externos |
| bCompass | bcompass.service | Go | Plano de inteligencia: rutas de IA y analisis |
| bSearch | bsearch.service | Go | Plano de busqueda: indexacion federada soberana |
| bAuth | bauth.service | Go | Plano de identidad: BitMask 3 dominios, 15 metodos auth |
| bhnexus | bhnexus.service | Go | Plano de conectividad: broker hardware, WebSocket mTLS |
| banexus | banexus.service (--user) | Go | Plano edge: interceptor USB/shell, centinela Fedora |

## WAL como Event Bus Nativo

El SBOS NO usa Kafka, RabbitMQ ni middleware externo. El Write-Ahead Log (WAL) de PostgreSQL es el bus de eventos nativo. 3 slots de replicacion: bkernel_slot, biedata_slot, bcompass_slot. Orden causal garantizado por LSN.

## Relaciones entre BCs

| Origen | Destino | Relacion | Mecanismo |
|---|---|---|---|
| BC-02 (RRHH) | BC-01 (Financiero) | Customer-Supplier | WAL > bKernel > party.party |
| BC-03 (Ventas) | BC-01 (Financiero) | Customer-Supplier | WAL > bKernel > invoices |
| BC-04 (Identidad) | Todos | Shared Kernel (JWT) | JWT a todas las apps |
| BC-08 (Integracion) | BC-01, BC-02, BC-03 | ACL (biedata) | Traduce modelos externos |
