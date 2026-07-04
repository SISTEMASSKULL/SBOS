# Manual JSON-RPC — Parte 8: Ecosistema y Estrategia de Adopción

> **Parte de:** Manual JSON-RPC (documento estratégico transversal)  
> **Audiencia:** Arquitectos, líderes técnicos y responsables de decisiones tecnológicas que necesitan definir cómo JSON-RPC estructura el ecosistema completo de aplicaciones de una organización.

---

## Tabla de Contenidos

1. [JSON-RPC como filosofía de arquitectura, no solo como protocolo](#1-json-rpc-como-filosofía-de-arquitectura-no-solo-como-protocolo)
2. [Las aplicaciones como motores de procesamiento puros](#2-las-aplicaciones-como-motores-de-procesamiento-puros)
3. [Separación limpia de interfaz y backend](#3-separación-limpia-de-interfaz-y-backend)
4. [Tres categorías de aplicaciones en el ecosistema](#4-tres-categorías-de-aplicaciones-en-el-ecosistema)
5. [Categoría A — Aplicaciones nativas JSON-RPC (Tryton y similares)](#5-categoría-a--aplicaciones-nativas-json-rpc-tryton-y-similares)
6. [Categoría B — Aplicaciones nuevas bajo este manual](#6-categoría-b--aplicaciones-nuevas-bajo-este-manual)
7. [Categoría C — Aplicaciones legadas sin JSON-RPC (OrangeHRM y similares)](#7-categoría-c--aplicaciones-legadas-sin-json-rpc-orangehrm-y-similares)
8. [El Patrón Fachada-RPC para aplicaciones legadas](#8-el-patrón-fachada-rpc-para-aplicaciones-legadas)
9. [Implementación de una Fachada-RPC para OrangeHRM](#9-implementación-de-una-fachada-rpc-para-orangehrm)
10. [El ecosistema completo: mapa de integración](#10-el-ecosistema-completo-mapa-de-integración)
11. [Gobernanza del estándar](#11-gobernanza-del-estándar)

---

## 1. JSON-RPC como filosofía de arquitectura, no solo como protocolo

A lo largo de las partes anteriores de este manual se ha construido el conocimiento técnico de JSON-RPC: cómo se estructura un mensaje, cómo se autentica, cómo se diseñan cadenas de eventos, cómo se construye el servidor. Esta parte responde a la pregunta más importante: **¿qué significa adoptar JSON-RPC a nivel de ecosistema organizacional?**

La respuesta es que JSON-RPC no es solo un formato de comunicación. Es una **declaración de principios de arquitectura**:

> Toda la lógica de negocio vive en motores independientes de cualquier interfaz. Esos motores se comunican a través de un contrato único, predecible y auditable: JSON-RPC. Cualquier cliente, sea una interfaz web, una app móvil, un script de integración nocturna o un agente de IA, accede al motor exactamente de la misma forma.

Este principio, sostenido de forma consistente en toda la organización, produce sistemas donde:

- **No hay lógica duplicada.** Las reglas de negocio existen en un solo lugar.
- **La interfaz no tiene privilegios.** La UI web no puede hacer nada que no pueda hacer una integración programática.
- **Las integraciones son naturales.** Conectar dos sistemas es llamar a sus métodos, no reverse-engineerear su base de datos.
- **Los agentes de IA pueden operar.** Un agente que entiende JSON-RPC puede operar cualquier motor del ecosistema con el mismo patrón.

---

## 2. Las aplicaciones como motores de procesamiento puros

Esta es la consecuencia arquitectónica más importante del modelo JSON-RPC bien aplicado:

**Una aplicación bajo este modelo es exclusivamente un motor de procesamiento. No es una interfaz. No es un portal. No es un frontend.**

```
┌─────────────────────────────────────────────────────────────┐
│              MOTOR DE PROCESAMIENTO                         │
│                                                             │
│  Lo que SÍ hace:                                            │
│  ✓ Ejecutar lógica de negocio                               │
│  ✓ Mantener estado de los registros                         │
│  ✓ Aplicar validaciones y reglas                            │
│  ✓ Persistir datos en base de datos                         │
│  ✓ Exponer operaciones vía JSON-RPC                         │
│  ✓ Comunicarse con otros motores vía adaptadores            │
│                                                             │
│  Lo que NO hace:                                            │
│  ✗ Renderizar HTML                                          │
│  ✗ Mantener estado de sesión de usuario en pantalla         │
│  ✗ Tomar decisiones de presentación                         │
│  ✗ Conocer si quien lo llama es un humano o un script       │
└─────────────────────────────────────────────────────────────┘
```

Este modelo es la materialización del **Principio de Paridad**: la interfaz propia no tiene privilegios especiales sobre cualquier otro cliente. Todos acceden al motor de la misma forma, con las mismas llamadas, con los mismos resultados.

### Implicaciones prácticas

Cuando una organización adopta este modelo de forma consistente:

- Un proceso que hoy hace un operador en la interfaz web puede ser automatizado mañana por un script sin modificar el motor.
- Un agente de IA puede ejecutar flujos de negocio completos simplemente aprendiendo el catálogo de métodos del motor.
- Las integraciones entre sistemas se reducen a "qué métodos llamo" en lugar de "cómo accedo a su base de datos".
- El testing de negocio se hace directamente contra el motor, sin necesidad de simular interacciones de usuario.

---

## 3. Separación limpia de interfaz y backend

La consecuencia más visible del modelo de motores puros es que **la interfaz y el backend quedan completamente desacoplados**. El motor no sabe ni le importa qué tipo de cliente lo está llamando. Eso permite crear múltiples interfaces para el mismo motor sin tocar una línea de su código.

### Las tres formas de operar el mismo motor

Un motor JSON-RPC puede ser operado de forma completamente equivalente desde tres tipos de clientes distintos:

```
┌────────────────────────────────────────────────────────────────┐
│                        MOTOR JSON-RPC                          │
│              (lógica, datos, reglas, estado)                   │
└───────────────────────────┬────────────────────────────────────┘
                            │  mismo contrato POST /rpc/
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
┌──────────────────┐ ┌─────────────┐ ┌──────────────────┐
│  Interfaz web    │ │  Binario    │ │  Línea de        │
│  (React, Vue,   │ │  nativo     │ │  comandos        │
│   HTML clásico) │ │  (desktop,  │ │  (script, cron,  │
│                 │ │   mobile)   │ │   integración)   │
│  El usuario     │ │  El usuario │ │  Un operador,    │
│  hace clic en   │ │  toca un    │ │  script o agente │
│  un botón       │ │  botón      │ │  ejecuta un      │
│                 │ │             │ │  comando         │
└──────────────────┘ └─────────────┘ └──────────────────┘
```

Los tres clientes envían exactamente el mismo JSON al motor. No hay una versión "para web" y otra "para escritorio" del servidor. Hay un servidor y múltiples formas de llamarlo.

### Lo que esto significa para el desarrollo

**Una interfaz web** no contiene lógica de negocio. Sabe qué botones mostrar, qué formularios presentar, y cómo renderizar los resultados. Pero todas las reglas — qué campos son obligatorios, si una venta puede confirmarse, qué sucede al pagar — viven en el motor.

```python
# Todo lo que hace el frontend al presionar "Confirmar venta"
respuesta = cliente.call("model.venta.confirm", [[101]], {"company": 1})
# El motor ya validó, ya actualizó el estado, ya registró el evento.
# El frontend solo muestra el resultado.
```

**Un binario nativo** — una aplicación de escritorio o móvil — usa exactamente el mismo cliente RPC que la web. No hay una API especial para apps. El mismo login, el mismo token, el mismo contexto, los mismos métodos.

**La línea de comandos** es la prueba más directa de que la lógica vive en el servidor. Un operador puede ejecutar cualquier operación del sistema sin abrir ninguna interfaz gráfica:

```bash
# Confirmar la venta 101 directamente desde la terminal
curl -X POST https://api.miapp.com/rpc/ \
  -H "Authorization: Basic YW5h..." \
  -H "Content-Type: application/json" \
  -d '{"id":1,"method":"model.venta.confirm","params":[[101],{}]}'
```

El resultado es idéntico al del botón en la interfaz web. El motor no distingue entre los dos.

### La interfaz es intercambiable; el motor no

Esta separación tiene una consecuencia operativa importante: **se puede reemplazar la interfaz completa sin tocar el motor**. Si la organización decide migrar de una interfaz web a una app nativa, o de un framework frontend a otro, el motor y todos sus datos quedan intactos. Solo cambia la capa que hace las llamadas.

A la inversa, **el motor puede mejorarse sin coordinar con las interfaces**. Mientras un método siga aceptando los mismos parámetros y devolviendo el mismo formato de respuesta (ver Parte 6 §6, versionado), las interfaces existentes siguen funcionando sin cambios.

---

## 4. Tres categorías de aplicaciones en el ecosistema

Al evaluar el ecosistema de aplicaciones de una organización frente a este modelo, toda aplicación cae en una de tres categorías:

```
CATEGORÍA A                CATEGORÍA B               CATEGORÍA C
─────────────────          ──────────────────        ─────────────────────
Nativa JSON-RPC            Nueva bajo el manual      Legada, sin JSON-RPC

Ya cumple el modelo.       Se construye siguiendo     Tiene su propia API
No requiere trabajo        este manual desde cero.    (REST, SOAP, propietaria)
adicional de               Sigue el estándar          o ninguna API pública.
integración.               desde el día 1.            Requiere Fachada-RPC.

Ejemplo: Tryton            Ejemplo: cualquier         Ejemplo: OrangeHRM,
                           sistema nuevo de           sistemas bancarios
                           la organización            legados, ERPs propietarios
```

La estrategia de adopción consiste en:
- **Categoría A:** documentar y aprovechar
- **Categoría B:** construir bajo el estándar desde el inicio
- **Categoría C:** crear una Fachada-RPC que envuelva la aplicación

---

## 5. Categoría A — Aplicaciones nativas JSON-RPC (Tryton y similares)

### Tryton como referencia

Tryton es un ERP de código abierto que implementa JSON-RPC de forma nativa como su único protocolo de comunicación. El servidor `trytond` levanta un endpoint JSON-RPC y todo — el cliente de escritorio, el cliente web, los módulos, las integraciones externas — pasa por ese mismo endpoint.

La estructura de métodos de Tryton sigue exactamente el patrón documentado en este manual:

```
common.server.version    → versión del servidor (sin autenticación)
common.db.login          → login → [user_id, session]
model.<modelo>.create    → crear registros
model.<modelo>.read      → leer campos
model.<modelo>.write     → actualizar
model.<modelo>.delete    → eliminar
model.<modelo>.search    → buscar IDs
wizard.<wizard>.create   → iniciar asistente
wizard.<wizard>.execute  → ejecutar paso del asistente
report.<reporte>.execute → generar documento
```

Esto significa que para una organización que ya usa Tryton, **este manual describe exactamente cómo integrar con Tryton**. No hay trabajo adicional de adaptación. El estándar ya está implementado.

### Configuración del endpoint en Tryton

```ini
# trytond.conf
[options]
jsonrpc = 0.0.0.0:8000
# ssl_jsonrpc = True
# hostname_jsonrpc = erp.miempresa.com
```

### Llamada de referencia a Tryton

```python
# Este es exactamente el código del manual, aplicado a Tryton
import requests
import base64

URL = "https://erp.miempresa.com/nombrebasedatos/"  # Tryton incluye el nombre de la BD en la URL

# Login
resp = requests.post(URL, json={
    "id": 1,
    "method": "common.db.login",
    "params": ["usuario", {"password": "contraseña"}]
}, headers={"Content-Type": "application/json"})
uid, session = resp.json()["result"]

# Llamada autenticada — mismo patrón que el manual
creds = f"usuario:{uid}:{session}"
auth  = "Basic " + base64.b64encode(creds.encode()).decode()

ventas = requests.post(URL, json={
    "id": 2,
    "method": "model.sale.sale.search_read",
    "params": [[["state", "=", "confirmed"]], ["number", "amount_total"], 0, 50, None, {}]
}, headers={"Content-Type": "application/json", "Authorization": auth}).json()["result"]
```

### Lo que se obtiene de gratis con Tryton

Al usar Tryton bajo este modelo, la organización obtiene sin trabajo adicional:

- Todos los módulos de Tryton (contabilidad, ventas, compras, inventario, RRHH) expuestos vía JSON-RPC.
- `system.listMethods` nativo para introspección.
- Gestión de sesiones, permisos por rol, y contexto multi-empresa ya implementados.
- Wizards para procesos complejos (facturación masiva, cierres contables) listos para automatizar.
- Generación de reportes en PDF/ODS/XLSX vía `report.<nombre>.execute`.

---

## 6. Categoría B — Aplicaciones nuevas bajo este manual

Toda aplicación nueva desarrollada en la organización debe seguir este manual desde el día 1. No es opcional ni aspiracional: es el estándar de desarrollo.

### Lista de verificación para aplicaciones nuevas

Antes de arrancar el desarrollo de cualquier sistema nuevo, verificar:

**Arquitectura**
- [ ] El dominio de negocio está separado de la capa de comunicación (Parte 5).
- [ ] Los modelos de dominio no importan nada de HTTP, Flask, ni JSON.
- [ ] Los servicios de aplicación son el único punto de entrada desde la capa RPC.
- [ ] Existe un registro de métodos central (`RegistroRPC`).
- [ ] El dispatcher es el único componente que maneja autenticación y enrutamiento.

**Contrato público**
- [ ] Todo modelo expuesto implementa los seis métodos base: `create`, `read`, `write`, `delete`, `search`, `search_read`.
- [ ] Las transiciones de estado tienen métodos propios con nombres verbales.
- [ ] Existe `common.server.version`, `system.listMethods`, `system.methodHelp`.
- [ ] El contexto de ejecución sigue el esquema estándar (`language`, `company`, `timezone`).
- [ ] Los nombres de métodos siguen la convención `espacio.modelo.accion` en un único idioma.

**Seguridad y calidad**
- [ ] Ningún método de negocio es accesible sin sesión válida.
- [ ] Toda llamada se loguea con método, usuario, duración y resultado.
- [ ] Los errores de negocio siguen la estructura estándar con `code`, `name`, `message`.
- [ ] Existe la jerarquía de errores definida en la Parte 6.

### Decisión de lenguaje y framework

El manual provee implementaciones en Python, Go, Rust y PHP. La elección no afecta el contrato externo. Un cliente Python puede llamar sin cambios a un servidor Go. Lo que importa es que el **contrato JSON-RPC sea idéntico**.

---

## 7. Categoría C — Aplicaciones legadas sin JSON-RPC (OrangeHRM y similares)

### El problema

Muchas organizaciones tienen aplicaciones consolidadas que no pueden o no deben reescribirse, pero que tampoco exponen su lógica de negocio via JSON-RPC. Existen tres subcasos:

**Subcaso C1 — Tienen API REST propia:**
La aplicación ya tiene una API, pero es REST (o SOAP, o GraphQL). No sigue el contrato del manual.

*Ejemplo: OrangeHRM* tiene una API REST v2 con OAuth 2.0 Bearer Token. Los endpoints siguen patrones como `GET /api/v2/leave/employees/{id}/leave-requests`. No tiene `model.X.search_read` ni contexto de ejecución ni `system.listMethods`.

**Subcaso C2 — Tienen API propietaria o limitada:**
La aplicación tiene algún mecanismo de integración (CSV import/export, webhooks, base de datos accesible directamente) pero no una API programática completa.

**Subcaso C3 — No tienen API:**
La aplicación no tiene ningún mecanismo de integración documentado. Solo existe su interfaz web y su base de datos.

### La solución: Fachada-RPC

Para los tres subcasos, la solución es construir una **Fachada-RPC**: una aplicación independiente que:

1. Expone un endpoint JSON-RPC estándar (siguiendo este manual al 100%).
2. Traduce cada método JSON-RPC a las operaciones correspondientes en la aplicación subyacente.
3. Normaliza los errores de la aplicación subyacente al formato estándar.
4. Agrega autenticación, logging y contexto de la misma forma que cualquier otro motor del ecosistema.

```
┌──────────────────────────────────────────────────────────────┐
│                     FACHADA-RPC                              │
│                                                              │
│  Hacia afuera (clientes):                                    │
│  POST /rpc/                                                  │
│  model.empleado.search_read(...)                             │
│  model.ausencia.create(...)                                  │
│  → Contrato JSON-RPC 100% estándar                           │
│                                                              │
│  Hacia adentro (aplicación subyacente):                      │
│  GET /api/v2/employees?...            ← REST de OrangeHRM    │
│  POST /api/v2/leave/employees/5/...   ← REST de OrangeHRM    │
│  SELECT * FROM ohrm_employee WHERE... ← BD directa (C3)      │
└──────────────────────────────────────────────────────────────┘
```

**Lo que la Fachada-RPC NO es:**

- No es un proxy simple. Un proxy solo reenvía peticiones. La fachada *traduce* entre dos modelos conceptuales distintos.
- No reemplaza a la aplicación subyacente. La fachada no tiene lógica de negocio propia; la lógica sigue viviendo en la aplicación original.
- No es permanente necesariamente. En algunos casos, la fachada es un puente temporal mientras se migra hacia un motor nativo.

---

## 8. El Patrón Fachada-RPC para aplicaciones legadas

### Estructura de la Fachada-RPC

```
fachada-orangehrm/
│
├── dominio/                    ← Modelos de datos propios de la fachada
│   ├── empleado.py             ← Estructura interna del empleado
│   └── ausencia.py             ← Estructura interna de ausencias
│
├── adaptadores/                ← Traducción hacia OrangeHRM
│   ├── orangehrm_rest.py       ← Llama a la API REST de OrangeHRM
│   └── orangehrm_mock.py       ← Mock para tests
│
├── rpc/                        ← Capa JSON-RPC estándar (del manual)
│   ├── registro.py
│   ├── dispatcher.py
│   ├── sesion.py
│   └── catalogos/
│       ├── empleados.py        ← model.empleado.*
│       └── ausencias.py        ← model.ausencia.*
│
├── servidor/
│   └── app.py                  ← Flask / FastAPI
│
└── main.py
```

### Mapeo de operaciones: REST de OrangeHRM → JSON-RPC

La Fachada-RPC traduce el modelo REST de OrangeHRM al modelo JSON-RPC estándar:

| Método JSON-RPC (estándar) | Operación OrangeHRM REST equivalente |
|----------------------------|--------------------------------------|
| `model.empleado.search` | `GET /api/v2/employees?nameOrId=...&limit=...` |
| `model.empleado.search_read` | `GET /api/v2/employees?...` + mapeo de campos |
| `model.empleado.read` | `GET /api/v2/employees/{id}` |
| `model.empleado.create` | `POST /api/v2/employees` |
| `model.empleado.write` | `PUT /api/v2/employees/{id}` |
| `model.ausencia.search_read` | `GET /api/v2/leave/employees/{id}/leave-requests` |
| `model.ausencia.create` | `POST /api/v2/leave/employees/{id}/leave-requests` |
| `model.ausencia.aprobar` | `PUT /api/v2/leave/employees/{id}/leave-requests/{lid}` con `{action: "APPROVE"}` |
| `model.ausencia.rechazar` | `PUT /api/v2/leave/employees/{id}/leave-requests/{lid}` con `{action: "REJECT"}` |

### Mapeo de campos: API externa → dominio interno

Las APIs externas usan nombres propios para sus campos. La fachada los normaliza al esquema interno:

```python
# OrangeHRM devuelve esto:
{
    "empNumber": 42,
    "firstName": "Maria",
    "lastName": "García",
    "employeeId": "EMP-042",
    "jobTitle": {"id": 5, "title": "Analista"},
    "subUnit": {"id": 3, "unitId": "IT", "name": "Tecnología"},
    "employmentStatus": {"id": 1, "name": "Full-Time"},
    "terminationDate": null
}

# La fachada expone esto (esquema interno normalizado):
{
    "id": 42,
    "nombre": "Maria",
    "apellido": "García",
    "codigo": "EMP-042",
    "cargo": {"id": 5, "nombre": "Analista"},
    "departamento": {"id": 3, "codigo": "IT", "nombre": "Tecnología"},
    "tipo_contrato": {"id": 1, "nombre": "Full-Time"},
    "activo": true
}
```

---

## 9. Implementación de una Fachada-RPC para OrangeHRM

### Adaptador OrangeHRM (Python)

```python
# adaptadores/orangehrm_rest.py
#
# Responsabilidad: traducir entre el dominio interno y la API REST de OrangeHRM.
# La Fachada-RPC llama a este adaptador; nunca llama a OrangeHRM directamente.

import requests
from dataclasses import dataclass
from typing import Optional, List


@dataclass
class EmpleadoInterno:
    id:            int
    nombre:        str
    apellido:      str
    codigo:        str
    cargo:         Optional[dict]
    departamento:  Optional[dict]
    tipo_contrato: Optional[dict]
    activo:        bool


class AdaptadorOrangeHRM:
    """
    Adaptador para la API REST v2 de OrangeHRM.
    Autenticación: OAuth 2.0 con client_credentials.
    """

    def __init__(self, base_url: str, client_id: str, client_secret: str):
        self.base_url      = base_url.rstrip("/")
        self.client_id     = client_id
        self.client_secret = client_secret
        self._token        = None
        self._session      = requests.Session()

    # ── Autenticación ──────────────────────────────────────────────────────

    def _obtener_token(self) -> str:
        if self._token:
            return self._token
        resp = requests.post(
            f"{self.base_url}/oauth/issueToken",
            data={"client_id": self.client_id,
                  "client_secret": self.client_secret,
                  "grant_type": "client_credentials"},
        )
        resp.raise_for_status()
        self._token = resp.json()["access_token"]
        return self._token

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self._obtener_token()}",
                "Content-Type": "application/json"}

    def _get(self, ruta: str, params: dict = None) -> dict:
        resp = self._session.get(f"{self.base_url}{ruta}",
                                 headers=self._headers(), params=params)
        if resp.status_code == 401:
            self._token = None  # Token expirado, limpiar para renovar
            resp = self._session.get(f"{self.base_url}{ruta}",
                                     headers=self._headers(), params=params)
        resp.raise_for_status()
        return resp.json()

    def _post(self, ruta: str, datos: dict) -> dict:
        resp = self._session.post(f"{self.base_url}{ruta}",
                                  headers=self._headers(), json=datos)
        resp.raise_for_status()
        return resp.json()

    def _put(self, ruta: str, datos: dict) -> dict:
        resp = self._session.put(f"{self.base_url}{ruta}",
                                 headers=self._headers(), json=datos)
        resp.raise_for_status()
        return resp.json()

    # ── Traducción de campos ───────────────────────────────────────────────

    @staticmethod
    def _ext_a_interno(emp: dict) -> EmpleadoInterno:
        """Traduce el formato de OrangeHRM al formato interno normalizado."""
        return EmpleadoInterno(
            id            = emp.get("empNumber") or emp.get("employeeId"),
            nombre        = emp.get("firstName", ""),
            apellido      = emp.get("lastName", ""),
            codigo        = emp.get("employeeId", ""),
            cargo         = ({"id": emp["jobTitle"]["id"],
                              "nombre": emp["jobTitle"]["title"]}
                             if emp.get("jobTitle") else None),
            departamento  = ({"id": emp["subUnit"]["id"],
                              "codigo": emp["subUnit"].get("unitId", ""),
                              "nombre": emp["subUnit"]["name"]}
                             if emp.get("subUnit") else None),
            tipo_contrato = ({"id": emp["employmentStatus"]["id"],
                              "nombre": emp["employmentStatus"]["name"]}
                             if emp.get("employmentStatus") else None),
            activo        = emp.get("terminationDate") is None,
        )

    @staticmethod
    def _interno_a_ext(datos: dict) -> dict:
        """Traduce el formato interno normalizado al formato de OrangeHRM."""
        ext = {}
        if "nombre"   in datos: ext["firstName"]        = datos["nombre"]
        if "apellido" in datos: ext["lastName"]         = datos["apellido"]
        if "cargo"    in datos: ext["jobTitleId"]       = datos["cargo"]["id"]
        if "departamento" in datos: ext["subUnitId"]    = datos["departamento"]["id"]
        if "tipo_contrato" in datos: ext["empStatusId"] = datos["tipo_contrato"]["id"]
        return ext

    # ── Operaciones de empleados ───────────────────────────────────────────

    def buscar_empleados(self, filtros: dict, offset: int = 0,
                         limit: int = 50) -> List[EmpleadoInterno]:
        params = {"limit": limit, "offset": offset}
        if "nombre" in filtros:
            params["nameOrId"] = filtros["nombre"]
        if "departamento_id" in filtros:
            params["subUnitId"] = filtros["departamento_id"]

        data = self._get("/api/v2/employees", params)
        return [self._ext_a_interno(e) for e in data.get("data", [])]

    def obtener_empleado(self, emp_id: int) -> EmpleadoInterno:
        data = self._get(f"/api/v2/employees/{emp_id}")
        return self._ext_a_interno(data.get("data", {}))

    def crear_empleado(self, datos: dict) -> EmpleadoInterno:
        payload = {
            "firstName": datos["nombre"],
            "lastName":  datos["apellido"],
            "employeeId": datos.get("codigo", ""),
        }
        data = self._post("/api/v2/employees", payload)
        return self._ext_a_interno(data.get("data", {}))

    def actualizar_empleado(self, emp_id: int, datos: dict) -> bool:
        payload = self._interno_a_ext(datos)
        self._put(f"/api/v2/employees/{emp_id}", payload)
        return True

    # ── Operaciones de ausencias ───────────────────────────────────────────

    def buscar_ausencias(self, emp_id: int, filtros: dict = None) -> list:
        params = {}
        if filtros:
            if "fecha_desde" in filtros: params["fromDate"] = filtros["fecha_desde"]
            if "fecha_hasta" in filtros: params["toDate"]   = filtros["fecha_hasta"]
            if "estado"      in filtros: params["statuses"] = filtros["estado"]

        data = self._get(f"/api/v2/leave/employees/{emp_id}/leave-requests", params)
        return [self._normalizar_ausencia(a) for a in data.get("data", [])]

    def aprobar_ausencia(self, emp_id: int, leave_id: int) -> bool:
        self._put(f"/api/v2/leave/employees/{emp_id}/leave-requests/{leave_id}",
                  {"action": "APPROVE"})
        return True

    def rechazar_ausencia(self, emp_id: int, leave_id: int,
                           motivo: str = "") -> bool:
        self._put(f"/api/v2/leave/employees/{emp_id}/leave-requests/{leave_id}",
                  {"action": "REJECT", "comment": motivo})
        return True

    @staticmethod
    def _normalizar_ausencia(aus: dict) -> dict:
        return {
            "id":           aus.get("id"),
            "empleado_id":  aus.get("employee", {}).get("empNumber"),
            "tipo":         aus.get("leaveType", {}).get("name"),
            "fecha_desde":  aus.get("startDate"),
            "fecha_hasta":  aus.get("endDate"),
            "dias":         aus.get("noOfDays"),
            "estado":       aus.get("status", {}).get("label"),
            "comentario":   aus.get("comment"),
        }
```

### Catálogo RPC de la Fachada (Python)

```python
# rpc/catalogos/empleados.py

from rpc.registro import registro, DescriptorRPC
from adaptadores.orangehrm_rest import AdaptadorOrangeHRM


class CatalogoEmpleados:
    """
    Expone operaciones de empleados vía JSON-RPC estándar.
    Los clientes no saben que por debajo hay una API REST de OrangeHRM.
    """

    def __init__(self, adaptador: AdaptadorOrangeHRM):
        self.adaptador = adaptador
        self._registrar()

    def _registrar(self):
        metodos = [
            ("model.empleado.search",      self.search,      True,  ["rrhh", "admin"]),
            ("model.empleado.search_read", self.search_read, True,  ["rrhh", "admin", "gerencia"]),
            ("model.empleado.read",        self.read,        True,  ["rrhh", "admin", "gerencia"]),
            ("model.empleado.create",      self.create,      False, ["rrhh", "admin"]),
            ("model.empleado.write",       self.write,       False, ["rrhh", "admin"]),
        ]
        for nombre, func, solo_lectura, perms in metodos:
            registro.registrar(nombre, DescriptorRPC(
                funcion=func, solo_lectura=solo_lectura, permisos=perms
            ))

    def search(self, params, ctx):
        """model.empleado.search(dominio, offset, limit, order, ctx) → [ids]"""
        dominio = params[0] if params else []
        offset  = params[1] if len(params) > 1 else 0
        limit   = params[2] if len(params) > 2 else 50
        filtros = self._dominio_a_filtros(dominio)
        empleados = self.adaptador.buscar_empleados(filtros, offset, limit)
        return [e.id for e in empleados]

    def search_read(self, params, ctx):
        """model.empleado.search_read(dominio, [campos], offset, limit, order, ctx) → [{...}]"""
        dominio = params[0] if params else []
        campos  = params[1] if len(params) > 1 else None
        offset  = params[2] if len(params) > 2 else 0
        limit   = params[3] if len(params) > 3 else 50
        filtros   = self._dominio_a_filtros(dominio)
        empleados = self.adaptador.buscar_empleados(filtros, offset, limit)
        return [self._empleado_a_dict(e, campos) for e in empleados]

    def read(self, params, ctx):
        """model.empleado.read([ids], [campos], ctx) → [{...}]"""
        ids    = params[0]
        campos = params[1] if len(params) > 1 else None
        return [self._empleado_a_dict(self.adaptador.obtener_empleado(eid), campos)
                for eid in ids]

    def create(self, params, ctx):
        """model.empleado.create([valores], ctx) → [ids]"""
        return [self.adaptador.crear_empleado(v).id for v in params[0]]

    def write(self, params, ctx):
        """model.empleado.write([ids], {valores}, ctx) → true"""
        ids    = params[0]
        valores = params[1]
        for eid in ids:
            self.adaptador.actualizar_empleado(eid, valores)
        return True

    # ── Helpers ────────────────────────────────────────────────────────────

    @staticmethod
    def _dominio_a_filtros(dominio: list) -> dict:
        """Convierte el dominio JSON-RPC estándar a los filtros de OrangeHRM."""
        filtros = {}
        for condicion in dominio:
            if not isinstance(condicion, list) or len(condicion) != 3:
                continue
            campo, operador, valor = condicion
            if campo == "nombre"          and operador in ("=", "ilike"):
                filtros["nombre"] = valor.strip("%")
            elif campo == "departamento_id" and operador == "=":
                filtros["departamento_id"] = valor
            elif campo == "activo"        and operador == "=":
                filtros["activo"] = valor
        return filtros

    @staticmethod
    def _empleado_a_dict(emp, campos: list = None) -> dict:
        """Convierte EmpleadoInterno a dict, filtrando campos si se especifican."""
        d = {
            "id":           emp.id,
            "nombre":       emp.nombre,
            "apellido":     emp.apellido,
            "codigo":       emp.codigo,
            "cargo":        emp.cargo,
            "departamento": emp.departamento,
            "tipo_contrato": emp.tipo_contrato,
            "activo":       emp.activo,
        }
        if campos:
            return {k: v for k, v in d.items() if k in campos or k == "id"}
        return d
```

### Catálogo de ausencias

```python
# rpc/catalogos/ausencias.py

class CatalogoAusencias:
    def __init__(self, adaptador: AdaptadorOrangeHRM):
        self.adaptador = adaptador
        self._registrar()

    def _registrar(self):
        metodos = [
            ("model.ausencia.search_read", self.search_read, True,  ["rrhh", "admin", "gerencia"]),
            ("model.ausencia.create",      self.create,      False, ["rrhh", "empleados"]),
            ("model.ausencia.aprobar",     self.aprobar,     False, ["rrhh", "admin"]),
            ("model.ausencia.rechazar",    self.rechazar,    False, ["rrhh", "admin"]),
        ]
        for nombre, func, solo_lectura, perms in metodos:
            registro.registrar(nombre, DescriptorRPC(
                funcion=func, solo_lectura=solo_lectura, permisos=perms
            ))

    def search_read(self, params, ctx):
        dominio = params[0] if params else []
        # Extraer empleado_id del dominio
        emp_id  = next((c[2] for c in dominio
                        if isinstance(c, list) and c[0] == "empleado_id"), None)
        if not emp_id:
            raise ValueError("Se requiere filtrar por empleado_id.")
        filtros = {c[0]: c[2] for c in dominio
                   if isinstance(c, list) and c[0] != "empleado_id"}
        return self.adaptador.buscar_ausencias(emp_id, filtros)

    def create(self, params, ctx):
        datos  = params[0][0]
        emp_id = datos.pop("empleado_id")
        result = self.adaptador._post(
            f"/api/v2/leave/employees/{emp_id}/leave-requests", {
                "leaveTypeId": datos["tipo_id"],
                "startDate":   datos["fecha_desde"],
                "endDate":     datos["fecha_hasta"],
                "comment":     datos.get("comentario", ""),
            })
        return [result.get("data", {}).get("id")]

    def aprobar(self, params, ctx):
        ids = params[0]
        # Requiere empleado_id en el contexto o en params extendidos
        emp_id = ctx.get("_empleado_id") or params[1].get("empleado_id")
        for lid in ids:
            self.adaptador.aprobar_ausencia(emp_id, lid)
        return True

    def rechazar(self, params, ctx):
        ids    = params[0]
        emp_id = ctx.get("_empleado_id") or params[1].get("empleado_id")
        motivo = params[1].get("motivo", "") if len(params) > 1 else ""
        for lid in ids:
            self.adaptador.rechazar_ausencia(emp_id, lid, motivo)
        return True
```

### Servidor completo de la Fachada-RPC

```python
# main.py — Fachada-RPC para OrangeHRM

import os
from flask import Flask, request
from rpc.registro import registro, DescriptorRPC
from rpc.dispatcher import DispatcherRPC
from rpc.sesion import GestorSesiones
from adaptadores.orangehrm_rest import AdaptadorOrangeHRM
from rpc.catalogos.empleados import CatalogoEmpleados
from rpc.catalogos.ausencias import CatalogoAusencias

# Configuración desde variables de entorno
ORANGEHRM_URL    = os.environ["ORANGEHRM_URL"]     # https://rrhh.miempresa.com
ORANGEHRM_CLIENT = os.environ["ORANGEHRM_CLIENT"]  # OAuth client_id
ORANGEHRM_SECRET = os.environ["ORANGEHRM_SECRET"]  # OAuth client_secret

# Ensamblar adaptador
adaptador = AdaptadorOrangeHRM(ORANGEHRM_URL, ORANGEHRM_CLIENT, ORANGEHRM_SECRET)

# Registrar catálogos
CatalogoEmpleados(adaptador)
CatalogoAusencias(adaptador)

# Métodos del sistema
registro.registrar("common.server.version", DescriptorRPC(
    funcion=lambda p, c: "1.0.0-orangehrm", solo_lectura=True))
registro.registrar("system.listMethods", DescriptorRPC(
    funcion=lambda p, c: registro.listar(), solo_lectura=True))

# Dispatcher con autenticación propia de la fachada
# (la fachada tiene sus propios usuarios, independientes de OrangeHRM)
gestor     = GestorSesiones(...)
dispatcher = DispatcherRPC(registro, gestor)

app = Flask(__name__)

@app.route("/rpc/", methods=["POST", "OPTIONS"])
def rpc():
    if request.method == "OPTIONS":
        return ("", 200, {
            "Access-Control-Allow-Origin":  "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type, Authorization",
        })
    resultado = dispatcher.despachar(request.get_data(as_text=True), dict(request.headers))
    return app.response_class(resultado, mimetype="application/json")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8001)  # Puerto distinto al ERP principal
```

### Uso desde cualquier cliente — idéntico al resto del ecosistema

```python
# Un cliente que usa Tryton (Categoría A) Y OrangeHRM vía Fachada (Categoría C)
# El código de llamada es IDÉNTICO. El cliente no sabe la diferencia.

import base64, requests

def rpc(url, method, params, uid, session, username, call_id=1, ctx=None):
    if ctx: params = params + [ctx]
    creds = f"{username}:{uid}:{session}"
    auth  = "Basic " + base64.b64encode(creds.encode()).decode()
    resp  = requests.post(url, json={"id": call_id, "method": method, "params": params},
                          headers={"Content-Type": "application/json",
                                   "Authorization": auth})
    data  = resp.json()
    if data.get("error"): raise Exception(data["error"]["message"])
    return data["result"]

# Llamar a Tryton (ERP nativo)
ventas = rpc("https://erp.miempresa.com/prod/", "model.sale.sale.search_read",
             [[["state", "=", "confirmed"]], ["number", "amount_total"], 0, 10, None],
             uid_tryton, session_tryton, "usuario", ctx={"company": 1})

# Llamar a la Fachada de OrangeHRM (mismo patrón exacto)
empleados = rpc("https://fachada-rrhh.miempresa.com/rpc/", "model.empleado.search_read",
                [[["activo", "=", True]], ["nombre", "apellido", "departamento"], 0, 50, None],
                uid_fachada, session_fachada, "usuario", ctx={"company": 1})
```

---

## 10. El ecosistema completo: mapa de integración

Con las tres categorías resueltas, el ecosistema se ve así:

```
                    CLIENTES (todos usan el mismo patrón JSON-RPC)
        ┌──────────────┬──────────────┬──────────────┬──────────────┐
        │  Web App     │  App Móvil   │  Reportes    │  Agente IA   │
        │  (React/Vue) │  (Flutter)   │  automáticos │  (Claude)    │
        └──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────┘
               │              │              │              │
               │      POST /rpc/ + Authorization: Basic     │
               │              │              │              │
        ┌──────▼──────┬───────▼──────┬───────▼──────┬───────▼───────┐
        │             │              │              │               │
        │  TRYTON     │  SISTEMA     │  SISTEMA     │  FACHADA-RPC  │
        │  (ERP)      │  NUEVO A     │  NUEVO B     │  OrangeHRM    │
        │             │              │              │               │
        │ Categoría A │ Categoría B  │ Categoría B  │ Categoría C   │
        │ Nativo      │ Manual       │ Manual       │ Adaptador     │
        │ JSON-RPC    │ JSON-RPC     │ JSON-RPC     │ JSON-RPC      │
        │             │              │              │               │
        │ Puerto 8000 │ Puerto 8001  │ Puerto 8002  │ Puerto 8003   │
        └─────────────┴──────────────┴──────────────┴───────┬───────┘
                                                             │
                                                   Llama via REST
                                                             │
                                                     ┌───────▼───────┐
                                                     │  OrangeHRM    │
                                                     │  (legado)     │
                                                     │  REST API v2  │
                                                     └───────────────┘
```

### El contrato único que hace posible el ecosistema

Independientemente de si la aplicación es nativa, nueva o legada con fachada, **el contrato hacia los clientes es siempre el mismo**:

```
POST /<url_del_motor>/rpc/
Authorization: Basic base64(usuario:uid:token)
Content-Type: application/json

{
  "id": <número>,
  "method": "<espacio>.<modelo>.<accion>",
  "params": [<argumentos...>, <contexto>]
}
```

Un agente de IA, un desarrollador, o un script de integración que aprende a usar un motor del ecosistema, puede usar todos los demás sin aprender nada nuevo sobre el protocolo.

---

## 11. Gobernanza del estándar

Para que el ecosistema funcione de forma sostenida, se necesitan reglas de gobernanza claras:

### Reglas no negociables

**1. Un motor, un endpoint.** Cada aplicación del ecosistema tiene exactamente un endpoint JSON-RPC (`POST /rpc/`). No se crean endpoints adicionales para casos especiales.

**2. El contrato es inmutable en versiones lanzadas.** Un método publicado no se elimina ni cambia su firma. Se depreca, se documenta la alternativa, y se mantiene hasta el siguiente ciclo de vida mayor. (Ver Parte 6, sección 6.)

**3. Los nombres son consistentes en todo el ecosistema.** Si el ERP usa `model.venta.confirm`, el sistema de RRHH no puede usar `model.empleado.approveLeave`. El verbo de transición es siempre en español (o siempre en inglés, según la decisión del equipo), en toda la organización.

**4. Toda aplicación tiene `common.server.version` y `system.listMethods`.** Sin excepciones, incluyendo las fachadas. Esto permite que agentes automatizados descubran las capacidades de cualquier motor en tiempo de ejecución.

**5. Las fachadas no tienen lógica de negocio propia.** Una fachada traduce y delega. Si se necesita lógica nueva (validaciones, orquestación entre sistemas), esa lógica va en un motor nuevo (Categoría B), no en la fachada.

### Proceso para agregar un nuevo motor al ecosistema

```
1. Clasificar la aplicación (A, B o C)
2. Si A: documentar el endpoint y credenciales en el registro del ecosistema
3. Si B: seguir el checklist de la Sección 5 de este documento
4. Si C:
   a. Analizar la API disponible de la aplicación
   b. Diseñar el mapeo de métodos JSON-RPC ↔ operaciones externas
   c. Implementar el adaptador con sus mocks
   d. Implementar los catálogos RPC siguiendo el patrón de este documento
   e. Levantar la fachada en su propio puerto/subdominio
   f. Registrar en el ecosistema
5. Publicar en el registro: URL, catálogo de métodos, permisos requeridos
```

### Registro del ecosistema (ejemplo)

```json
{
  "motores": [
    {
      "nombre":      "ERP Principal",
      "tipo":        "A",
      "aplicacion":  "Tryton 7.0",
      "url_rpc":     "https://erp.miempresa.com/produccion/",
      "version":     "7.0.1",
      "modulos":     ["sale", "account", "stock", "purchase"],
      "contacto":    "equipo-erp@miempresa.com"
    },
    {
      "nombre":      "Sistema de Proyectos",
      "tipo":        "B",
      "aplicacion":  "Desarrollo interno (manual JSON-RPC)",
      "url_rpc":     "https://proyectos.miempresa.com/rpc/",
      "version":     "1.2.0",
      "modulos":     ["proyecto", "tarea", "recurso"],
      "contacto":    "equipo-proyectos@miempresa.com"
    },
    {
      "nombre":      "Fachada RRHH",
      "tipo":        "C",
      "aplicacion":  "OrangeHRM 5.x (vía Fachada-RPC)",
      "url_rpc":     "https://fachada-rrhh.miempresa.com/rpc/",
      "version":     "1.0.0-orangehrm",
      "modulos":     ["empleado", "ausencia", "vacacion"],
      "contacto":    "equipo-rrhh@miempresa.com"
    }
  ]
}
```

---

## Resumen ejecutivo para toma de decisiones

| Pregunta | Respuesta |
|----------|-----------|
| ¿Puede una app ser 100% JSON-RPC? | Sí. Para la lógica interna, es el modelo ideal. |
| ¿Las apps son solo motores de procesamiento? | Exactamente. La interfaz es un cliente más, sin privilegios especiales. |
| ¿Qué hacemos con Tryton? | Nada adicional. Ya cumple el estándar de este manual. |
| ¿Cómo construimos apps nuevas? | Siguiendo el manual desde el día 1. El estándar es el checklist de la Sección 5. |
| ¿Qué hacemos con OrangeHRM? | Creamos una Fachada-RPC que lo envuelve y lo expone con el contrato estándar. |
| ¿El cliente nota la diferencia entre Tryton y la Fachada? | No. El código de llamada es idéntico. |
| ¿Puede un agente de IA operar el ecosistema? | Sí. Un agente que entiende JSON-RPC puede operar cualquier motor usando `system.listMethods`. |

---

## Índice de todos los documentos del manual

| Documento | Contenido |
|-----------|-----------|
| `JSON-RPC-01-fundamentos.md` | Qué es JSON-RPC, estructura del mensaje, convenciones, transporte HTTP |
| `JSON-RPC-02-autenticacion.md` | Login, tokens, headers de autorización, logout, implementaciones en 4 lenguajes |
| `JSON-RPC-03-crud-contexto.md` | Contexto de ejecución, create/read/write/delete/search, relaciones, ejemplos en 4 lenguajes |
| `JSON-RPC-04-cadena-eventos.md` | Eslabones, máquinas de estado, flujo completo de venta, wizards, reportes |
| `JSON-RPC-05-arquitectura-servidor.md` | Motor de dominio, capas, dispatcher, registro de métodos, servidores en 4 lenguajes |
| `JSON-RPC-06-errores-produccion.md` | Tipos de error, manejo por lenguaje, reintentos, seguridad, logging, checklist |
| `JSON-RPC-07-arquitectura-hibrida-integraciones.md` | Arquitectura híbrida, patrón adaptador, archivos binarios, integración SIAT Bolivia |
| `JSON-RPC-08-ecosistema-y-estrategia-de-adopcion.md` | Filosofía de ecosistema, motores puros, Tryton nativo, apps nuevas, Fachada-RPC para legados |
| `JSON-RPC-09-orquestacion-multi-motor.md` | Motor de orquestación, flujos multi-motor, saga con compensación, contexto distribuido, 4 lenguajes |

---

*Manual JSON-RPC — Diseño, Implementación e Integración*  
*Versión 2.0 — Aplicable a cualquier sistema que adopte JSON-RPC como protocolo de comunicación*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
