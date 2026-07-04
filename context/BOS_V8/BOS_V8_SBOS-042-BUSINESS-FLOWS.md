# SBOS-042-BUSINESS-FLOWS
## Flujos de Negocio End-to-End — Estandar HUMAN-DOC
### SKULL · SBOS · V8 Enriquecido · Mayo 2026

---

## 1. Proposito

Documentar como funciona el SBOS desde la perspectiva del usuario. Los daemons son invisibles pero esenciales — como el kernel de Linux es invisible para quien usa Firefox. Un formulario en UNA app dispara acciones en 6 apps simultaneamente.

## 2. Flujo 1 — Alta de Empleado (Onboarding)

RRHH llena UN formulario en OrangeHRM. En <5 minutos el empleado tiene: registro ERP (Tryton), cuenta correo (Postfix+Roundcube), SSO todas las apps de su rol (KC), canales departamento (Rocket.Chat), aparece en busqueda federada (bSearch), jefe notificado.

```
OrangeHRM → PG (WAL) → bKernel detecta regla OHRM-001 →
  ├── Tryton: UPSERT party.party (estructura costos)
  ├── KC: crear usuario + grupo RolTemplate → bAuth sync BitMask <5s
  ├── Postfix: crear buzon + firma corporativa del seed file
  ├── Rocket.Chat: agregar canales departamento + notificar jefe
  └── bSearch: indexar para busqueda federada
```
Apps: OrangeHRM, Tryton, KC, Postfix, Roundcube, Rocket.Chat. Daemons: bKernel (6 reglas), bAuth, bSearch.

### Enriquecimiento V5: Detalle extendido del flujo

```
RRHH abre OrangeHRM → Empleados → Nuevo
  │  Llena: nombre, cargo, departamento, email, fecha de ingreso
  │  Guarda.
  │
  ▼  [INVISIBLE] OrangeHRM escribe en PostgreSQL (hs_hr_employee)
  ▼  [INVISIBLE] PostgreSQL genera evento WAL
  ▼  [INVISIBLE] bKernel detecta: regla OHRM-001 "employee_to_tryton"
  │
  ├── bKernel → Tryton: UPSERT en party.party
  │     El empleado ahora existe en el ERP con su estructura de costos
  │
  ├── bKernel → Keycloak (via regla CORE-001):
  │     Crear usuario con email como username
  │     Asignar al grupo del RolTemplate de su cargo
  │     bAuth sincroniza BitMask en <5 segundos
  │
  ├── bKernel → Postfix (via regla derivada):
  │     Crear buzon de correo empleado@empresa.com
  │     Configurar firma corporativa con datos del seed file
  │
  ├── bKernel → Rocket.Chat (via regla CROSS-002):
  │     Agregar a canales de su departamento
  │     Notificar al jefe directo: "Nuevo empleado: Maria Garcia"
  │
  └── bKernel → bSearch (via Redis queue):
       Indexar nuevo empleado para busqueda federada

RESULTADO: En 5 minutos, el empleado tiene:
  ✓ Registro en el ERP (Tryton)
  ✓ Cuenta de correo (Postfix + Roundcube)
  ✓ Acceso SSO a todas las apps de su rol (Keycloak)
  ✓ Canales de mensajeria de su departamento (Rocket.Chat)
  ✓ Aparicion en busqueda federada
  ✓ Su jefe fue notificado
```

## 3. Flujo 2 — Factura Electronica Bolivia (SIAT)

Contador emite factura en Tryton. Sistema envia al SIN automaticamente, recibe CUF, lo registra. Contador no toca portal del SIN.

```
Tryton → PG (WAL) → biedata detecta Caja SIAT-EXPORT-001 →
  AUTHENTICATE: certificado digital de Vault → SIAT API
  EXTRACT: factura + datos cliente de PG
  TRANSFORM: XML segun XSD del SIN + validacion NIT/montos
  LOAD: POST siat.impuestos.gob.bo → recibe CUF
  UPDATE: account_invoice.siat_cuf = CUF
  AUDIT: log en biedata_audit_log
```
Resultado: factura con CUF + estado "Enviada a SIAT" + PDF con QR. Daemons: biedata (6 fases Box Engine), bKernel.

### Enriquecimiento V5: Detalle extendido del flujo SIAT

```
Contador abre Tryton → Facturacion → Nueva Factura
  │  Selecciona cliente, agrega lineas, confirma.
  │  Tryton registra factura con estado "Emitida"
  │
  ▼  [INVISIBLE] Tryton escribe en PostgreSQL (account_invoice)
  ▼  [INVISIBLE] PostgreSQL genera evento WAL
  ▼  [INVISIBLE] biedata detecta: Caja SIAT-EXPORT-001
  │
  ├── biedata → FASE AUTHENTICATE:
  │     Obtiene certificado digital de Vault
  │     Autentica contra SIAT API
  │
  ├── biedata → FASE EXTRACT:
  │     Lee factura de PostgreSQL con datos del cliente
  │
  ├── biedata → FASE TRANSFORM:
  │     Genera XML segun esquema XSD del SIN
  │     Valida NIT, montos, impuestos
  │
  ├── biedata → FASE LOAD:
  │     POST a https://siat.impuestos.gob.bo/api/v2/facturas/envio
  │     Recibe CUF (Codigo Unico de Facturacion)
  │
  ├── biedata → Actualiza account_invoice:
  │     siat_submitted = true
  │     siat_cuf = "CUF recibido"
  │
  └── biedata → FASE AUDIT:
       Log en biedata_audit_log: factura #X enviada exitosamente

RESULTADO: El contador ve en Tryton:
  ✓ Factura con CUF del SIN asignado
  ✓ Estado: "Enviada a SIAT"
  ✓ PDF con codigo QR del CUF para el cliente
```

### Enriquecimiento Smart CMS: Flujo de checkout y custodia 3PL

Smart CMS define flujos de checkout que se integran con el flujo de facturacion. BOSCMS-C-04-CHECKOUT-5-FLUJOS describe el proceso completo desde la seleccion de productos hasta la emision de factura electronica, incluyendo:

1. **Seleccion de productos** desde catalogo con precios y stock en tiempo real
2. **Validacion de disponibilidad** contra inventario (BOSCMS-011-INVENTARIO-INVERSO)
3. **Calculo de impuestos** por jurisdiccion (BOSCMS-A-02-IMPUESTOS-BO)
4. **Confirmacion de pago** via Smart Pay o metodos tradicionales
5. **Emision de factura** electronica a traves del flujo SIAT descrito arriba

El flujo de custodia 3PL (BOSCMS-C-10-CUSTODIA-3PL) gestiona la logistica posterior a la facturacion: picking, packing, shipping con tracking actualizado via WebSocket al cliente.

## 4. Flujo 3 — Apertura Punto de Venta con QR (~15ms)

Vendedor presenta QR → escritorio se desbloquea + app ventas se abre + cajon dinero se activa. Todo en <1 segundo.

```
QR → banexus intercepta USB → firma HMAC → bhnexus (WebSocket mTLS) →
  bauth evalua 3 dominios:
    Logico: dispositivo ✓, red ✓
    Fisico: zona Ventas ✓, horario 08-18 ✓
    Financiero: limite $50,000 ✓
  → BitMask 0x000000000003E627 →
  banexus ejecuta en paralelo:
    Bit 1: SHELL_UNLOCK → escritorio KDE
    Bit 5: DRAWER_OPEN → cajon dinero
    Bit 2+4: APP_TRYTON + APP_SALEOR en dock
    VDI policies: USB disabled, impresora OK, internet restringido
```
Latencia total: ~15ms (objetivo <50ms). Daemons: banexus, bhnexus, bAuth, SBOS VDI.

### Enriquecimiento V5: Detalle extendido del flujo QR

```
Vendedor presenta QR al lector USB de la terminal Fedora
  │
  ▼  [INVISIBLE] banexus intercepta datos del bus USB ANTES de que Fedora los procese
  ▼  [INVISIBLE] banexus firma el payload y lo envia a bhnexus via WebSocket mTLS
  ▼  [INVISIBLE] bhnexus identifica nodo "Ventas-01", consulta bauth
  ▼  [INVISIBLE] bauth evalua:
  │     Dominio logico: dispositivo registrado ✓, red interna ✓
  │     Dominio fisico: Zona Ventas ✓, horario 08:00-18:00 ✓
  │     Dominio financiero: limite diario $50,000 ✓
  │
  ▼  [INVISIBLE] bhnexus envia BitMask al banexus:
  │     Bit 0: SESSION_VALID = 1
  │     Bit 1: SHELL_UNLOCK = 1
  │     Bit 2: APP_TRYTON = 1
  │     Bit 4: APP_SALEOR = 1
  │     Bit 5: DRAWER_OPEN = 1
  │     Bit 6: DOOR_ZONE_A = 1
  │
  ▼  banexus ejecuta en paralelo:
       1. Libera shell de Fedora → escritorio KDE aparece
       2. Activa rele del cajon de dinero → cajon se abre
       3. SBOS VDI aplica politicas del RolTemplate "Vendedor":
          → Solo apps permitidas en el dock
          → USB storage deshabilitado
          → Impresora habilitada
          → Internet restringido a sitios autorizados
```

## 5. Flujo 4 — Baja de Empleado (Offboarding)

RRHH cambia UN campo → en <5 minutos pierde TODO: correo, ERP, escritorio, puertas fisicas.

```
OrangeHRM "Terminated" → bKernel regla CORE-002 →
  ├── KC: deshabilitar usuario (JWTs expiran 5 min)
  │   bAuth revoca BitMask → banexus invalida cache
  ├── Tryton: party inactivo (bloquear transacciones)
  ├── Postfix: archivar buzon + redirigir al jefe
  ├── Rocket.Chat: desactivar + notificar jefe
  ├── Nextcloud: transferir archivos al jefe
  └── Nexus: BitMask → todos bits a 0 (puertas, cajones, escritorios bloqueados)
```
SLO seguridad: revocacion acceso <15 min desde terminated (SBOS-031 §5).

### Enriquecimiento V5: Detalle extendido del flujo offboarding

```
RRHH abre OrangeHRM → Empleados → Maria Garcia → Estado: "Terminated"
  │
  ▼  [INVISIBLE] bKernel detecta: regla CORE-002 "employee_offboarding"
  │
  ├── bKernel → Keycloak: deshabilitar usuario
  │     Todos los JWT activos expiran en 5 minutos
  │     bAuth revoca BitMask inmediatamente → banexus invalida cache
  │
  ├── bKernel → Tryton: marcar party como inactivo
  │     Bloquear creacion de transacciones a nombre de este empleado
  │
  ├── bKernel → Postfix: archivar buzon
  │     Redirigir correo entrante al jefe directo
  │
  ├── bKernel → Rocket.Chat: desactivar usuario
  │     Notificar al jefe: "Maria Garcia ha sido desvinculada"
  │
  ├── bKernel → Nextcloud: transferir archivos al jefe
  │
  └── bAuth → Nexus: revocar acceso fisico
       BitMask → todos los bits a 0
       Las puertas, cajones, y escritorios quedan bloqueados
```

## 6. Flujo 5 — Consulta Gerencial con IA

Gerente pregunta "¿Productos con margen <15%?" → reporte accionable en 30 segundos con datos reales.

```
Core UI → bCompass → Route INVENTORY-ALERT-001 →
  CONTEXT: SQL Tryton (precios catalogo) + SQL Saleor (ventas real) + bSearch (RAG)
  PROMPT: template Langfuse con datos reales
  INFERENCE: Ollama qwen3:8b → "12 productos con margen <15%"
  VALIDATION: cross-check producto existe en Tryton ✓ + precios coinciden ✓
  DELIVERY: tabla 12 productos + links "Ver en Tryton" + propuesta ajuste (HITL)
```
Anti-alucinacion: cada dato citado validado contra BD. Trazabilidad: Langfuse.

### Enriquecimiento V5: Detalle extendido del flujo IA

```
Gerente → Core UI → SBOS AI Tools → "Productos con margen < 15%"
  │
  ▼  [INVISIBLE] bCompass recibe solicitud
  ▼  Route Engine selecciona ruta INVENTORY-ALERT-001
  │
  ├── FASE CONTEXT: bCompass consulta:
  │     → Tryton (SQL): precios de catalogo por producto
  │     → Saleor (SQL): precios reales de venta ultimo trimestre
  │     → bSearch (RAG): documentos relacionados con margenes
  │
  ├── FASE PROMPT: Arma prompt con datos reales + template Langfuse
  │
  ├── FASE INFERENCE: Ollama (qwen3:8b) analiza datos
  │     "Hay 12 productos con margen inferior al 15%..."
  │
  ├── FASE VALIDATION: Cross-check respuesta contra datos del contexto
  │     ¿Cada producto mencionado existe en Tryton? ✓
  │     ¿Los precios citados coinciden con la BD? ✓
  │
  └── FASE DELIVERY: Respuesta en Core UI con:
       → Tabla de 12 productos con margen, precio catalogo, precio venta
       → Link a cada producto: "Ver en Tryton"
       → Propuesta: "Generar orden de ajuste de precios" (HITL)
```

## 7. Flujo 6 — Busqueda Federada "345"

Contador escribe "345" → factura #345 en contabilidad, pago Bs.345 en tesoreria, pedido #345 en ventas. Links verificados contra bAuth.

```
bSearch: normalizacion → expansion (number, amount, reference) →
  Typesense full-text + Qdrant semantic →
  Factura #345 (95%) [Ver Facturacion →] ✓ tiene APP_TRYTON
  Pago Bs.345 (72%) [Ver Tesoreria →] ✓ tiene APP_TRYTON
  Pedido #345 (68%) [Ver Ventas →] ✗ NO tiene APP_SALEOR → link deshabilitado
```

### Enriquecimiento V5: Detalle extendido de busqueda federada

```
Contador → Barra de busqueda → "345"
  │
  ▼  bSearch recibe query
  │
  ├── CAPA 1: Normalizacion → "345" (numerico, sin correccion)
  ├── CAPA 2: No aplica Levenshtein (busqueda exacta numerica)
  ├── CAPA 3: Expansion → buscar en campos: number, amount, reference
  │
  ├── CAPA 5: Busqueda federada simultanea:
  │     Typesense → full-text en todos los indices
  │     Qdrant → semantic search
  │
  └── Resultados con verificacion bAuth:
      Cada link verificado contra bAuth:
        ✓ Contador tiene APP_TRYTON → links de Facturacion y Tesoreria activos
        ✗ Contador NO tiene APP_SALEOR → link de Ventas deshabilitado
```

## 8. Flujo 7 — Instalacion App Nueva

Admin ejecuta `bosctl product install documents` → 10 min → Paperless-NGX con OCR, firma digital, SSO integrado. Sin tocar KC, Kong, PG manualmente.

```
bosctl product install documents →
  PG: crear paperless_db, docuseal_db ✓
  KC: crear clients paperless, docuseal ✓
  Kong: rutas /docs, /sign ✓
  MinIO: bucket documents ✓
  Fichas: paperless-ngx, tesseract-ocr, tabula, kimios, docuseal ✓
  Verify: upload PDF ✓, OCR ✓, firma digital ✓
```

### Enriquecimiento V5: Detalle extendido de instalacion

```
Admin → Terminal:
  $ bosctl product install documents

  [bos] ━━━ Producto: documents ━━━
  [bos] Evaluando requirements...
    postgresql → paperless_db NO EXISTE → crear ✓
    postgresql → docuseal_db NO EXISTE → crear ✓
    keycloak → client "paperless" NO EXISTE → crear ✓
    keycloak → client "docuseal" NO EXISTE → crear ✓
    kong → ruta /docs NO EXISTE → crear ✓
    kong → ruta /sign NO EXISTE → crear ✓
    minio → bucket "documents" NO EXISTE → crear ✓

  [bos] Instalando fichas...
    [✓] paperless-ngx → OCR (espanol + ingles)
    [✓] tesseract-ocr
    [✓] tabula
    [✓] kimios → flujos de aprobacion
    [✓] docuseal → firma digital

  [bos] Verificando...
    [✓] Upload documento PDF: OK
    [✓] OCR extrae texto: OK
    [✓] Firma digital funcional: OK

  ═══ Producto documents instalado en 9m 45s ═══
```

### Enriquecimiento Smart CMS: Flujo de negocio BOSCMS

Smart CMS (BOSCMS-B-04-BKERNEL-FLUJOS-3-4-5) define flujos de negocio adicionales que se integran con el ecosistema SBOS:

**Flujo CMS-3 — Gestion de contenido multi-tenant:**
- Creacion de contenido desde SBOS CMS
- Publicacion con aprobacion via flujo HITL de bCompass
- Sincronizacion a traves de bKernel WAL a todas las apps del stack
- Indexacion en bSearch para busqueda federada

**Flujo CMS-4 — Checkout con pagos:**
- Integracion con Smart Pay para procesamiento de pagos
- Verificacion de stock via inventario inverso (BOSCMS-011)
- Emision de factura electronica al completar el pago
- Notificacion al cliente via WebSocket (Centrifugo)

**Flujo CMS-5 — Gestion de inventario multi-almacen:**
- Actualizacion de inventario en tiempo real
- Replicacion via bKernel WAL a todos los puntos de venta
- Conciliacion nocturna con generacion de reportes via Smart Report

## 9. Lo que Demuestran

| Principio SBOS | Evidencia |
|---|---|
| Es un SO, no un instalador | 1 formulario → 6 apps simultaneas |
| Daemons invisibles | Usuario nunca sabe de bKernel/bAuth/biedata |
| Cero invasion (P2) | OrangeHRM no sabe que Tryton existe |
| Soberania total (P1) | Datos nunca salen a nube de terceros |
| Un solo login (P5) | QR → acceso a todo |
| Extensible por fichas (P7) | `bosctl product install` → sin modificar core |
| Zero Trust | Acceso evaluado cada solicitud, offboarding <5 min |

### Enriquecimiento V5: Tabla extendida de principios

| Principio del SBOS | Evidencia en los flujos |
|---|---|
| **Es un SO, no un instalador** | Un formulario en una app dispara acciones en 6 apps simultaneamente. Eso no lo hace un instalador — lo hace un sistema operativo |
| **Los daemons son invisibles** | El usuario nunca sabe que existen bKernel, bAuth, biedata. Solo ve que "todo funciona junto" |
| **Cero invasion (P2)** | OrangeHRM no sabe que Tryton existe. Tryton no sabe que SIAT existe. El bKernel lo conecta todo sin modificar ninguna app |
| **Soberania total (P1)** | La factura se emite al SIN sin que ningun dato salga a una nube de terceros. La IA analiza datos localmente |
| **Un solo login (P5)** | El vendedor presenta su QR y accede a todo. El contador inicia sesion una vez y tiene ERP, correo, BI |
| **Extensible por fichas (P7)** | Agregar gestion documental = un comando. Sin modificar el Core |
| **Seguridad Zero Trust** | El acceso fisico y logico se evalua en cada solicitud. Un ex-empleado pierde TODO en 5 minutos |

---

## Trazabilidad

| Seccion | Extraida de | Secciones originales |
|---|---|---|
| §2 Alta | SBOS-039 v1.0 | §2 (flujo completo 6 apps + 3 daemons) |
| §3 Factura | SBOS-039 v1.0 | §3 (SIAT 6 fases Box Engine) |
| §4 QR | SBOS-039 v1.0 | §4 (15ms, 3 dominios, BitMask, VDI policies) |
| §5 Baja | SBOS-039 v1.0 | §5 (offboarding 6 sistemas + Nexus) |
| §6 IA | SBOS-039 v1.0 | §6 (5 fases bCompass, anti-alucinacion) |
| §7 Busqueda | SBOS-039 v1.0 | §7 (federada, links verificados bAuth) |
| §8 Install | SBOS-039 v1.0 | §8 (bosctl product install documents) |
| §9 Principios | SBOS-039 v1.0 | §9 (tabla 7 principios con evidencia) |

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Aportacion |
|---|---|---|
| V5 | /opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-039-BUSINESS-FLOWS-v1_0.md | Detalle extendido de cada flujo con diagramas paso a paso, tabla extendida de principios, nomenclatura completa de bits |
| Smart CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-B-04-BKERNEL-FLUJOS-3-4-5.md | Flujos CMS multi-tenant (contenido, checkout, inventario) |
| Smart CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-C-04-CHECKOUT-5-FLUJOS.md | Flujo de checkout completo con integracion de pagos y facturacion |
| Smart CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-C-10-CUSTODIA-3PL.md | Flujo de custodia 3PL (picking, packing, shipping) |
| Smart CMS | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS CMS/context/BOSCMS-011-INVENTARIO-INVERSO.md | Inventario inverso y gestion multi-almacen |
| Smart Pay | /opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Pay/context/ | Flujos de pago integrados en el checkout |
| Correlacion V8 | Integracion de flujos Smart* en el ecosistema SBOS | Flujos CMS-3/4/5 como extension de los flujos core SBOS |

---

_SKULL · SBOS · SBOS-042-BUSINESS-FLOWS · V8 Enriquecido · Mayo 2026_
