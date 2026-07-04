# SBOS-MP01 — Secciones Completadas: Ciclo de Vida de Realm, Catálogo de Roles y Onboarding Funcional
## Complemento para SBOS-008, SBOS-009 y SBOS-021

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-MP01
**Versión:** 1.0
**Estado:** ACTIVO
**Complementa:** SBOS-008-ROLFRAMEWORK-v1_0.md (PARTE A — Ciclo de Vida del Realm), SBOS-009-IDENTITY-CONTRACTS-v1_0.md (PARTE B — Catálogo de Roles), SBOS-021-Onboarding-v1_0.md (PARTE C — Onboarding Funcional)
**Clasificación:** Especificación — Identidad y Onboarding
**Distribuir en:** SBOS-008 (§nueva sección ciclo de vida), SBOS-009 (§nueva sección catálogo de roles), SBOS-021 (§nueva sección onboarding funcional)

---

## PARTE A — Para insertar en SBOS-008: Ciclo de Vida Completo del Realm

### A.1 Alta de empresa cliente (nuevo realm)

El alta de una empresa cliente en SBOS es la creación de un nuevo **realm de Keycloak** + el despliegue de las fichas que esa empresa ha contratado.

**Proceso completo:**

```
1. El administrador de SKULL crea la empresa en el Core UI:
   - Nombre del realm (ej: "acme-corp")
   - Plan contratado (qué fichas/módulos están habilitados)
   - Datos del administrador principal del cliente

2. El IAM Installer recibe la instrucción via API REST y ejecuta la Saga "onboard-tenant":
   Paso 1: Crear realm en Keycloak via Admin API
           → POST /admin/realms con la configuración base del realm SBOS
   Paso 2: Configurar los 5 SPIs custom en el realm nuevo
           → SkbosBehavioralScoreAuthenticator, SkbosRolFrameworkProvider, etc.
   Paso 3: Crear usuarios iniciales (admin del cliente + service accounts)
   Paso 4: Desplegar las fichas contratadas en el namespace K8s del tenant
           → kubectl create namespace acme-corp
           → Desplegar fichas según el plan
   Paso 5: Crear la base de datos del tenant en PostgreSQL
           → CREATE DATABASE acme_corp_tryton OWNER tryton
   Paso 6: Actualizar .sbos_state.json con el nuevo tenant
   Paso 7: Emitir evento WAL "tenant.onboarded" → bKernel lo propaga

3. Evento WAL emitido:
   Tabla: bos_tenants, operación: INSERT
   Campos: tenant_id, realm_name, plan, created_at
   bKernel detecta este evento y activa las reglas de configuración inicial del tenant
```

**Tiempo estimado de alta:** 15-30 minutos.

**Compensación de la Saga si falla:**
- Si falla en Paso 3: eliminar realm creado en Keycloak (rollback Paso 1-2)
- Si falla en Paso 4: eliminar namespace K8s + eliminar realm (rollback completo)
- Si falla en Paso 5: eliminar BD + namespace + realm

### A.2 Modificación del tenant

| Tipo de modificación | Proceso | Impacto |
|---------------------|---------|---------|
| **Cambio de plan** (más módulos) | Desplegar nuevas fichas + actualizar atributos del realm en Keycloak | Sin downtime — las apps nuevas se añaden al namespace existente |
| **Cambio de dominio** | Actualizar issuer URL en realm + regenerar certificados | Requiere ventana de mantenimiento de 5 minutos |
| **Activar SPI adicional** | Modificar Authentication Flow del realm | Sin downtime si se usa la Admin API |
| **Cambiar configuración de feature flag** | Actualizar atributo del realm via Core UI | Inmediato — el IAM Installer lo propaga en el próximo ciclo |

### A.3 Suspensión temporal del tenant

**Caso de uso:** el cliente no paga o solicita pausar el servicio temporalmente. Los datos se conservan.

```bash
# Via Keycloak Admin API: deshabilitar el realm
curl -X PUT \
  https://bos.skull.bo/admin/realms/acme-corp \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'

# Efecto inmediato: ningún usuario del realm puede autenticarse
# Los JWTs activos expiran en 5 minutos (duración JWT SBOS)
```

**Qué pasa con el bKernel durante la suspensión:**
- Los slots de replicación del tenant siguen activos
- Si hay actividad de base de datos (procesos internos), el bKernel la procesa
- La suspensión es a nivel de identidad (login bloqueado), no de datos

**Para suspender también el procesamiento del bKernel** (suspensión completa de datos):

```bash
# Detener el slot de replicación del tenant
sudo -u postgres psql -c \
  "SELECT pg_drop_replication_slot('bkernel_acme_corp');"
# ⚠️ Esto causa pérdida de eventos WAL del tenant durante la suspensión
# Solo hacer si la suspensión es > 1 día para evitar acumulación de WAL
```

### A.4 Baja definitiva del tenant

La baja definitiva elimina todos los datos del tenant. Es irreversible.

**Proceso formal de offboarding:**

```
SEMANA -2 (notificación al cliente):
□ Enviar aviso formal de cierre de cuenta
□ Generar y entregar export de datos al cliente:
  - pg_dump de todas las bases de datos del tenant
  - Export de usuarios y roles de Keycloak (realm export)
  - Archivos de MinIO del tenant
□ El cliente firma el recibo del export

DÍA 0 (baja efectiva):
□ Deshabilitar realm en Keycloak (acceso bloqueado)
□ Esperar 24 horas (ventana de gracia)

DÍA 1:
□ Eliminar fichas del namespace del tenant:
  kubectl delete namespace acme-corp
□ Eliminar realm de Keycloak:
  curl -X DELETE https://bos.skull.bo/admin/realms/acme-corp
□ Eliminar bases de datos del tenant en PostgreSQL:
  DROP DATABASE acme_corp_tryton;
  DROP DATABASE acme_corp_keycloak; -- ya fue eliminada con el realm
□ Eliminar slots de replicación del tenant (si quedan):
  SELECT pg_drop_replication_slot('bkernel_acme_corp_tryton');
□ Eliminar datos de MinIO del tenant
□ Actualizar .sbos_state.json removiendo el tenant

RETENCIÓN LEGAL:
□ Retener logs de auditoría en S14 (GitLab) durante el período requerido por la jurisdicción del cliente
  Bolivia: 10 años (Ley 843 en materia contable)
  Argentina: 10 años (Código Comercial)
  México: 5 años (SAT)
□ Estos logs son de solo lectura y no contienen datos de negocio — solo eventos de acceso y cambios de configuración
```

---

## PARTE B — Para insertar en SBOS-009: Catálogo de Roles por Sector Industrial

### B.1 Sector Manufactura

| Rol | Descripción | Módulos con acceso | Nivel de acceso | SPI relevante |
|-----|-------------|-------------------|----------------|---------------|
| **Gerente de Producción** | Supervisa toda la cadena de producción | Tryton (Manufacturing), OrangeHRM (Read), SBOS AI Tools (analyst) | Full en manufactura, Read en RRHH | SkbosRolFrameworkProvider |
| **Operario de Planta** | Ejecuta órdenes de producción | Tryton (Manufacturing — solo su área), OrangeHRM (portal empleado) | Restricted — solo órdenes asignadas | SkbosBehavioralScoreAuthenticator |
| **Jefe de Almacén** | Gestiona inventario y logística | Tryton (Inventory, Purchase), OrangeHRM (Read) | Full en inventario | SkbosRolFrameworkProvider |
| **Contador** | Contabilidad y reportes financieros | Tryton (Accounting, Invoicing), SBOS Data Integration (View) | Full en contabilidad | SkbosRolFrameworkProvider |
| **Responsable RRHH** | Gestión de empleados | OrangeHRM (Full), Tryton (Party — Read) | Full en RRHH, Read en ERP | SkbosRolFrameworkProvider |
| **Auditor Interno** | Solo lectura de todo el sistema | Tryton (Read All), OrangeHRM (Read), SBOS AI Tools (report) | Read-only global | SkbosTimeWindowAuthenticator |

### B.2 Sector Servicios

| Rol | Descripción | Módulos con acceso | Nivel de acceso | SPI relevante |
|-----|-------------|-------------------|----------------|---------------|
| **Director de Operaciones** | Supervisa servicios y contratos | Tryton (All), OrangeHRM (Read), SBOS AI Tools (analyst/report) | Full en operaciones | SkbosRolFrameworkProvider |
| **Gestor de Clientes** | Gestión de relaciones y contratos | Tryton (Party, Sale, Contract), EspoCRM (Full) | Full en CRM y ventas | SkbosBehavioralScoreAuthenticator |
| **Técnico de Campo** | Ejecuta órdenes de servicio | Tryton (Service Orders — asignadas), SBOS VDI (móvil) | Restricted por asignación | SkbosGeoFencingAuthenticator |
| **Facturador** | Emite y envía facturas | Tryton (Invoicing, SBOS Data Integration — Submit), SBOS Data Integration (Bolivia/AR/MX) | Full en facturación | SkbosRolFrameworkProvider |
| **Administrador TI** | Gestión del propio tenant SBOS | Core UI (Full), Grafana (Read), Keycloak (Realm Admin) | Admin del tenant | Keycloak Admin |

### B.3 Sector Comercial / Retail

| Rol | Descripción | Módulos con acceso | Nivel de acceso | SPI relevante |
|-----|-------------|-------------------|----------------|---------------|
| **Gerente de Tienda** | Supervisa operaciones de venta | Saleor (Full), Tryton (Inventory, Accounting — Read), OrangeHRM (Read) | Full en retail | SkbosRolFrameworkProvider |
| **Vendedor** | Atención al cliente y ventas | Saleor (Orders, Customers), Tryton (Inventory — Read) | Restricted a su área/turno | SkbosTimeWindowAuthenticator + SkbosBehavioralScoreAuthenticator |
| **Cajero** | Procesa pagos y cierres de caja | Saleor (Checkout, Payments) | Muy restringido — solo flujo de caja | SkbosTimeWindowAuthenticator (horario de turno) |
| **Jefe de Inventario** | Gestiona stock y compras | Tryton (Inventory, Purchase), Saleor (Products — Read) | Full en inventario | SkbosRolFrameworkProvider |
| **E-Commerce Manager** | Gestiona tienda online | Saleor (Full), SBOS AI Tools (analyst) | Full en Saleor | SkbosRolFrameworkProvider |
| **Customer Service** | Atención post-venta y devoluciones | Saleor (Orders — Read, Returns), EspoCRM (Full) | Restricted — no puede ver precios de costo | SkbosRolFrameworkProvider |

---

## PARTE C — Para insertar en SBOS-021: Onboarding para Roles No Técnicos

### C.1 Perfil del administrador funcional del cliente

El administrador funcional es la persona responsable de operar SBOS en la empresa cliente. No es necesariamente un técnico de TI. Puede ser el contador, el jefe de operaciones, o una persona designada específicamente para la gestión del sistema.

**Lo que puede hacer sin soporte técnico:**
- Crear, modificar y desactivar usuarios del realm de su empresa
- Asignar y quitar roles a usuarios (usando el catálogo de roles de SBOS-009)
- Revisar el estado del stack (qué fichas están activas) en el Core UI
- Interpretar los paneles básicos de Grafana (disponibilidad del sistema, estado del bKernel)
- Solicitar actualizaciones de fichas desde el Core UI
- Exportar reportes del SBOS AI Tools

**Lo que requiere asistencia de SKULL:**
- Cambiar el plan (agregar/quitar módulos)
- Modificar configuraciones de autenticación (flujos MFA, SPIs)
- Actualizar versiones del IAM Installer o daemons soberanos
- Resolver incidentes de nivel 2 o superior

### C.2 Plan de 5 sesiones de onboarding para el administrador funcional

| Sesión | Duración | Temas | Ejercicio práctico |
|--------|---------|-------|-------------------|
| **Sesión 1 — El sistema** | 2 h | Qué es SBOS, los tres planos (Release/IAM/K8s), cómo acceder al Core UI, el concepto de ficha | Acceder al Core UI y navegar a "Estado del Stack" — identificar qué fichas están activas |
| **Sesión 2 — Identidad** | 2 h | Qué es un realm, qué es un usuario, qué es un rol, cómo funciona Keycloak, los 3 niveles de admin | Crear un usuario de prueba, asignarle el rol "Vendedor" del sector retail, verificar que puede iniciar sesión |
| **Sesión 3 — Operación diaria** | 2 h | Cómo interpretar el panel de disponibilidad en Grafana, qué es el bKernel y por qué importa, las alertas que puede recibir | Simular una alerta de prueba y documentar los pasos para reportarla a SKULL |
| **Sesión 4 — Backup y continuidad** | 2 h | Qué es el backup, cuándo se ejecuta, cómo verificar que es exitoso, qué es un RTO y por qué le importa al cliente | Verificar el estado del último backup desde el Core UI + revisar el panel FinOps de Grafana |
| **Sesión 5 — Casos de uso reales** | 2 h | Alta de empleado nuevo (proceso cross-sistema: OrangeHRM → Keycloak → Tryton), baja de empleado, cambio de rol | Ejecutar el alta completa de un empleado de prueba y verificar que aparece en Tryton y tiene acceso correcto |

### C.3 Operaciones diarias del administrador funcional

**Lunes (inicio de semana):**
- Verificar en Core UI que todas las fichas están activas (semáforo verde)
- Revisar las alertas de la semana pasada en el canal Slack de alertas
- Procesar solicitudes de nuevos usuarios pendientes

**Mensual:**
- Revisar el panel FinOps: ¿el uso de recursos está dentro de lo esperado?
- Revisar usuarios inactivos (más de 30 días sin login): desactivar si corresponde
- Confirmar que el backup del último domingo completó exitosamente

### C.4 Cuándo escalar a SKULL

El administrador funcional debe contactar a SKULL cuando:

| Señal | Urgencia | Canal |
|-------|---------|-------|
| El Core UI muestra una ficha en rojo ("error") que no se recupera sola en 15 minutos | Alta | Email + teléfono |
| Un usuario no puede autenticarse y el problema no es la contraseña | Media | Email |
| El panel de Grafana muestra "bKernel DOWN" por más de 5 minutos | Crítica | Teléfono directo |
| Una factura no recibió autorización del ente tributario | Alta | Email |
| La empresa quiere agregar un nuevo módulo o cambiar de plan | Normal | Email con asunto "Cambio de plan" |

---

*SKULL · SBOS · SBOS-MP01 · v1.0 · Marzo 2026*
*Distribuir: Parte A → SBOS-008, Parte B → SBOS-009, Parte C → SBOS-021*
