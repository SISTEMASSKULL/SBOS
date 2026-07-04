# SBOS-018-API — Política de Versionado de API REST y Ciclo de Vida de Endpoints
## Sección para insertar en SBOS-007 (Core UI) y SBOS-022 (Bounded Contexts)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-018-API (sección nueva compartida entre SBOS-007 y SBOS-022)
**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Estándar de Ingeniería — Contratos de API
**Complementa:** SBOS-007-COREUI-v4_0.md (§A Versionado API REST) y SBOS-022-BoundedContexts-v1_0.md (§nueva Contratos API)
**Insertar en:** SBOS-007 como §nueva sección API Versioning + SBOS-022 como §nueva sección Contratos API

---

## Sección para SBOS-007 — Política de Versionado API REST

### A.1 Convención de versionado en Kong

Todas las APIs externas accesibles por los clientes y sus integraciones pasan por Kong. El formato de URL es uniforme en todo el stack:

```
/api/v{MAJOR}/{bounded-context}/{recurso}
```

**Ejemplos:**

| Endpoint | Bounded Context | Recurso | Versión |
|----------|----------------|---------|---------|
| `/api/v1/identity/users` | identity | users | v1 |
| `/api/v1/erp/invoices` | erp | invoices | v1 |
| `/api/v1/hrm/employees` | hrm | employees | v1 |
| `/api/v1/ecommerce/orders` | ecommerce | orders | v1 |
| `/api/v2/erp/invoices` | erp | invoices | v2 (cuando exista breaking change) |

**Regla de incremento de versión MAJOR:** cualquier cambio que requiera modificar el código del cliente consumidor es un cambio breaking. Específicamente:

- Eliminar un campo de la respuesta JSON.
- Cambiar el tipo de dato de un campo existente.
- Cambiar la semántica de un campo (mismo nombre, diferente significado).
- Cambiar la URL de un endpoint.
- Cambiar el método HTTP de un endpoint.
- Hacer obligatorio un campo que antes era opcional.

**Lo que NO requiere incremento de versión MAJOR:**
- Agregar nuevos campos opcionales a la respuesta (backward compatible).
- Agregar nuevos endpoints.
- Mejorar la performance sin cambiar el contrato.

**Quién define la versión:** el equipo del bounded context propietario del recurso. El cambio de versión MAJOR requiere un RFC en SBOS-025 (proceso ARB).

### A.2 Versionado de la API interna IAM Installer ↔ Core UI

Esta API **no pasa por Kong** — es interna al host. El IAM Installer (SP-04 FastAPI) y el Core UI (SP-06 Flutter) se comunican directamente.

**Header de versión:** `X-IAM-API-Version: {semver}`

```
# Ejemplo de request del Core UI al IAM Installer
GET /internal/fichas/status
X-IAM-API-Version: 1.3.0
Authorization: Bearer <token interno>
```

**Reglas de compatibilidad interna:**

1. El IAM Installer declara su versión de API en el endpoint `GET /internal/version`.
2. El Core UI verifica la compatibilidad al iniciar la sesión.
3. Si la versión del IAM Installer es incompatible con el Core UI, el Core UI muestra un banner de advertencia al administrador.
4. El IAM Installer y el Core UI se despliegan coordinadamente en el mismo release — no se puede desplegar uno sin que el otro sea compatible. Esta restricción está codificada en el proceso de release de SP-04 y SP-06.

**Política de compatibilidad backward:** el IAM Installer soporta la versión de API del Core UI actual y la versión anterior (N y N-1). Esto permite que el Core UI se actualice en un deploy separado si es necesario.

### A.3 Política de sunset para APIs externas en Kong

Cuando un endpoint es deprecado (reemplazado por una versión mayor):

1. **Header Sunset en todas las respuestas del endpoint deprecado:**
   ```
   Sunset: Sat, 31 Dec 2026 23:59:59 GMT
   Deprecation: true
   Link: <https://bos.cliente.com/api/v2/erp/invoices>; rel="successor-version"
   ```

2. **Período mínimo de soporte tras deprecación:** 6 meses. Durante este período, el endpoint v{anterior} sigue funcionando.

3. **Notificación al administrador:** el Core UI muestra un banner amarillo cuando el administrador usa una funcionalidad que depende de un endpoint en período de sunset. El banner incluye la fecha límite y el enlace a la documentación de migración.

4. **Eliminación del endpoint:** después del período de sunset, el endpoint retorna `HTTP 410 Gone` con mensaje explicativo.

### A.4 Contrato de API por bounded context (OpenAPI 3.1)

Ubicación en el repositorio: `servers/{server}/api/openapi.yaml`

```yaml
# Ejemplo: servers/s04-erpserver/api/openapi.yaml
openapi: "3.1.0"
info:
  title: SBOS ERP API
  version: "1.0.0"
  description: |
    API del bounded context ERP (Tryton).
    Esta API es gestionada por el IAM Installer y expuesta via Kong.
  contact:
    name: SKULL Systems
    url: https://skull.bo

servers:
  - url: https://bos.{tenant}.com/api/v1/erp
    description: Producción (tenant específico)
    variables:
      tenant:
        description: Realm/tenant del cliente
        default: example

paths:
  /invoices:
    get:
      operationId: listInvoices
      summary: Listar facturas
      security:
        - keycloakOAuth: [erp:read]
      parameters:
        - name: state
          in: query
          schema:
            type: string
            enum: [draft, confirmed, posted, paid, cancelled]
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
      responses:
        "200":
          description: Lista de facturas
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/InvoiceList'
        "401":
          description: Token JWT inválido o expirado
        "403":
          description: Sin permiso erp:read en el realm

components:
  securitySchemes:
    keycloakOAuth:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://bos.{tenant}.com/realms/{tenant}/protocol/openid-connect/auth
          tokenUrl: https://bos.{tenant}.com/realms/{tenant}/protocol/openid-connect/token
          scopes:
            erp:read: Lectura de datos ERP
            erp:write: Escritura de datos ERP
```

**Generación automática:** FastAPI genera el archivo `openapi.json` automáticamente desde las anotaciones del código. Para Tryton y otras apps del stack (que no son FastAPI), el contrato es declarativo manual — el equipo de fichas lo mantiene actualizado.

**Proceso de cambio breaking:** cualquier cambio al contrato OpenAPI que sea breaking requiere un RFC en SBOS-025 antes de ser implementado.

---

## Sección para SBOS-022 — Contratos de API entre Bounded Contexts

### B.1 APIs entre bounded contexts: WAL, no REST

Una distinción fundamental del SBOS: los bounded contexts **no se llaman entre sí via API REST**. La comunicación entre bounded contexts es via el WAL de PostgreSQL (bKernel como propagador). Las APIs REST son para consultas del Core UI y para integraciones externas via Kong.

```
BC-02 RRHH (OrangeHRM)
  ↓ INSERT en orangehrm.employee (WAL event)
  ↓ bKernel detecta el evento
  ↓ bKernel aplica regla YAML
  ↓ bKernel escribe en BC-04 Identity (crea usuario en Keycloak via API KC)
  ↓ bKernel escribe en BC-01 ERP (crea party en Tryton)
```

No hay una llamada HTTP directa de OrangeHRM hacia Tryton. El bKernel es el único propagador.

### B.2 Tabla de contratos de API externos por bounded context

| Bounded Context | API externa expuesta | Versión actual | Consumers externos permitidos |
|----------------|---------------------|---------------|------------------------------|
| BC-01 ERP | `/api/v1/erp/` | v1 | Integraciones de clientes via Kong |
| BC-02 RRHH | `/api/v1/hrm/` | v1 | Portal self-service de empleados |
| BC-03 Ecommerce | `/api/v1/ecommerce/` | v1 | Tienda web externa del cliente |
| BC-04 Identity | `/api/v1/identity/` | v1 | Solo admin — no exponer a usuarios finales |
| BC-05 Tributario | `/api/v1/tax/` | v1 | Sistemas contables externos del cliente |

### B.3 Eventos WAL como contratos internos

Aunque los BCs no se llaman via API, los **eventos WAL son contratos implícitos**. Si BC-02 (RRHH) cambia la estructura de la tabla `orangehrm.employee`, el bKernel puede dejar de detectar correctamente los eventos de empleados.

Los cambios de esquema en tablas monitoreadas por el bKernel requieren:
1. RFC en SBOS-025 (como cambio breaking).
2. Actualización de las reglas YAML del bKernel para el nuevo esquema.
3. Prueba en staging antes de aplicar en producción.

---

*SKULL · SBOS · SBOS-018-API · v1.0 · Marzo 2026*
*Insertar: Sección A en SBOS-007-CoreUI, Sección B en SBOS-022-BoundedContexts*
