# SBOS-039-BUSINESS-FLOWS
## Flujos de Negocio End-to-End — El SBOS como Sistema Operativo en Acción

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026

---

**Código:** SBOS-039
**Estado:** NUEVO
**Clasificación:** Especificación Funcional — Experiencia del Sistema Operativo
**Propósito:** Documentar cómo el SBOS funciona como un SO desde la perspectiva de quien lo usa. Cada flujo cruza múltiples aplicaciones y demuestra que los daemons son invisibles pero esenciales — exactamente como el kernel de Linux es invisible para quien usa Firefox.

---

## 1. Por Qué Este Documento Existe

Los documentos SBOS-001 a SBOS-038 especifican cada pieza del sistema operativo: cómo funciona el bKernel, qué hace el IAM Installer, cómo se estructura una ficha. Pero ningún documento muestra cómo se ve el SBOS desde los ojos de quien lo usa.

Un vendedor que abre su caja registradora no sabe que un banexus interceptó su QR, que bhnexus consultó a bauth, y que una BitMask de 64 bits desbloqueó su shell y su cajón de dinero en 15ms. Solo sabe que presentó su QR y pudo trabajar.

Este documento captura esa experiencia. Cada flujo describe qué ve el usuario, qué aplicaciones participan, y qué daemons actúan de forma invisible.

---

## 2. Flujo 1 — Alta de Empleado Nuevo

**Perspectiva del usuario:** El responsable de RRHH registra un nuevo empleado en OrangeHRM. En menos de 5 minutos, el empleado tiene correo corporativo, acceso al ERP con los permisos de su cargo, aparece en el directorio de la empresa, y su jefe directo recibe una notificación en Rocket.Chat.

**Paso a paso:**

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
  │     Crear buzón de correo empleado@empresa.com
  │     Configurar firma corporativa con datos del seed file
  │
  ├── bKernel → Rocket.Chat (via regla CROSS-002):
  │     Agregar a canales de su departamento
  │     Notificar al jefe directo: "Nuevo empleado: María García"
  │
  └── bKernel → bSearch (via Redis queue):
       Indexar nuevo empleado para búsqueda federada

RESULTADO: En 5 minutos, el empleado tiene:
  ✓ Registro en el ERP (Tryton)
  ✓ Cuenta de correo (Postfix + Roundcube)
  ✓ Acceso SSO a todas las apps de su rol (Keycloak)
  ✓ Canales de mensajería de su departamento (Rocket.Chat)
  ✓ Aparición en búsqueda federada ("María García" → bSearch)
  ✓ Su jefe fue notificado

RRHH NO hizo nada más que llenar UN formulario en UNA app.
Eso es un Sistema Operativo de Negocios.
```

**Apps involucradas:** OrangeHRM, Tryton, Keycloak, Postfix, Roundcube, Rocket.Chat
**Daemons que actuaron:** bKernel (6 reglas), bAuth (sincronización BitMask), bSearch (indexación)

---

## 3. Flujo 2 — Emisión de Factura Electrónica (Bolivia SIAT)

**Perspectiva del usuario:** El contador emite una factura en Tryton. El sistema la envía automáticamente al Servicio de Impuestos Nacionales (SIN) de Bolivia, recibe el Código Único de Facturación (CUF), y lo registra en el comprobante. El contador no toca ningún otro sistema.

```
Contador abre Tryton → Facturación → Nueva Factura
  │  Selecciona cliente, agrega líneas, confirma.
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
  │     Genera XML según esquema XSD del SIN
  │     Valida NIT, montos, impuestos
  │
  ├── biedata → FASE LOAD:
  │     POST a https://siat.impuestos.gob.bo/api/v2/facturas/envio
  │     Recibe CUF (Código Único de Facturación)
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
  ✓ PDF con código QR del CUF para el cliente

El contador NO abrió ningún portal del SIN.
El SBOS lo hizo por él, cumpliendo la normativa boliviana.
```

**Apps involucradas:** Tryton, SIAT (externo)
**Daemons que actuaron:** biedata (Box Engine: 6 fases), bKernel (detección WAL del CUF para propagar)

---

## 4. Flujo 3 — Apertura de Punto de Venta con QR

**Perspectiva del usuario:** El vendedor llega a su estación Fedora, presenta su QR al lector. En menos de 1 segundo, el escritorio se desbloquea, la app de ventas se abre, y el cajón de dinero se activa.

```
Vendedor presenta QR al lector USB de la terminal Fedora
  │
  ▼  [INVISIBLE] banexus intercepta datos del bus USB ANTES de que Fedora los procese
  ▼  [INVISIBLE] banexus firma el payload y lo envía a bhnexus via WebSocket mTLS
  ▼  [INVISIBLE] bhnexus identifica nodo "Ventas-01", consulta bauth
  ▼  [INVISIBLE] bauth evalúa:
  │     Dominio lógico: dispositivo registrado ✓, red interna ✓
  │     Dominio físico: Zona Ventas ✓, horario 08:00-18:00 ✓
  │     Dominio financiero: límite diario $50,000 ✓
  │
  ▼  [INVISIBLE] bhnexus envía BitMask al banexus:
  │     Bit 0: SESSION_VALID = 1
  │     Bit 1: SHELL_UNLOCK = 1
  │     Bit 2: APP_TRYTON = 1
  │     Bit 4: APP_SALEOR = 1
  │     Bit 5: DRAWER_OPEN = 1
  │     Bit 6: DOOR_ZONE_A = 1
  │
  ▼  banexus ejecuta en paralelo:
       1. Libera shell de Fedora → escritorio KDE aparece
       2. Activa relé del cajón de dinero → cajón se abre
       3. SBOS VDI aplica políticas del RolTemplate "Vendedor":
          → Solo apps permitidas en el dock
          → USB storage deshabilitado
          → Impresora habilitada
          → Internet restringido a sitios autorizados

RESULTADO: El vendedor ve:
  ✓ Escritorio Fedora con su nombre y foto
  ✓ Dock con: Saleor (ventas), Tryton (consulta inventario), Roundcube (correo)
  ✓ Cajón de dinero abierto y listo
  ✓ Todo en menos de 1 segundo

LATENCIA TOTAL: ~15ms (objetivo < 50ms)
```

**Apps involucradas:** Fedora KDE (SBOS VDI), Saleor, Tryton, Roundcube
**Daemons que actuaron:** banexus (input hooking), bhnexus (routing + BitMask), bAuth (3 dominios), SBOS VDI policies

---

## 5. Flujo 4 — Baja de Empleado (Offboarding)

**Perspectiva del usuario:** RRHH marca al empleado como "desvinculado" en OrangeHRM. En menos de 5 minutos, pierde acceso a TODO: correo, ERP, escritorio, puertas físicas. Sus archivos se transfieren a su jefe.

```
RRHH abre OrangeHRM → Empleados → María García → Estado: "Terminated"
  │
  ▼  [INVISIBLE] bKernel detecta: regla CORE-002 "employee_offboarding"
  │
  ├── bKernel → Keycloak: deshabilitar usuario
  │     Todos los JWT activos expiran en 5 minutos
  │     bAuth revoca BitMask inmediatamente → banexus invalida cache
  │
  ├── bKernel → Tryton: marcar party como inactivo
  │     Bloquear creación de transacciones a nombre de este empleado
  │
  ├── bKernel → Postfix: archivar buzón
  │     Redirigir correo entrante al jefe directo
  │
  ├── bKernel → Rocket.Chat: desactivar usuario
  │     Notificar al jefe: "María García ha sido desvinculada"
  │
  ├── bKernel → Nextcloud: transferir archivos al jefe
  │
  └── bAuth → Nexus: revocar acceso físico
       BitMask → todos los bits a 0
       Las puertas, cajones, y escritorios quedan bloqueados

RESULTADO: En 5 minutos, el ex-empleado:
  ✗ No puede iniciar sesión en ninguna app (Keycloak disabled)
  ✗ No puede entrar al edificio (BitMask revocada)
  ✗ No puede abrir su escritorio Fedora (shell bloqueado)
  ✗ Su correo se redirige a su jefe
  ✗ Sus archivos están con su jefe en Nextcloud
  ✓ Registro de auditoría completo en Wazuh

RRHH solo cambió UN campo en UNA app.
```

---

## 6. Flujo 5 — Consulta Gerencial con IA

**Perspectiva del usuario:** El gerente escribe en el Core UI: "¿Cuáles son los productos con margen menor al 15% en el último trimestre?" Recibe un reporte con datos reales de Tryton y Saleor, con links directos a cada producto.

```
Gerente → Core UI → SBOS AI Tools → "Productos con margen < 15%"
  │
  ▼  [INVISIBLE] bCompass recibe solicitud
  ▼  Route Engine selecciona ruta INVENTORY-ALERT-001
  │
  ├── FASE CONTEXT: bCompass consulta:
  │     → Tryton (SQL): precios de catálogo por producto
  │     → Saleor (SQL): precios reales de venta último trimestre
  │     → bSearch (RAG): documentos relacionados con márgenes
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
       → Tabla de 12 productos con margen, precio catálogo, precio venta
       → Link a cada producto: "Ver en Tryton" (smart routing via bSearch)
       → Propuesta: "Generar orden de ajuste de precios" (requiere aprobación humana)

RESULTADO: El gerente tiene un reporte accionable en 30 segundos.
  ✓ Datos reales, no inventados (anti-alucinación)
  ✓ Links directos a cada producto en Tryton
  ✓ Propuesta de acción que requiere su aprobación
  ✓ Todo trazado en Langfuse (quién preguntó, qué respondió, cuándo)
```

---

## 7. Flujo 6 — Búsqueda Federada "345"

**Perspectiva del usuario:** El contador escribe "345" en la barra de búsqueda del Core UI. Encuentra la factura #345 en contabilidad, un pago de Bs. 345 en tesorería, y el pedido #345 en ventas — cada uno con link directo a su formulario.

```
Contador → Barra de búsqueda → "345"
  │
  ▼  bSearch recibe query
  │
  ├── CAPA 1: Normalización → "345" (numérico, sin corrección)
  ├── CAPA 2: No aplica Levenshtein (búsqueda exacta numérica)
  ├── CAPA 3: Expansión → buscar en campos: number, amount, reference
  │
  ├── CAPA 5: Búsqueda federada simultánea:
  │     Typesense → full-text en todos los índices
  │     Qdrant → semantic search
  │
  └── Resultados:

  ┌─────────────────────────────────────────────────────┐
  │  Factura #345                                 95%   │
  │  Cliente: ACME Corp · Bs. 15,000 · 2026-03-10      │
  │  [Ver en Facturación →]                             │
  ├─────────────────────────────────────────────────────┤
  │  Pago por Bs. 345.00                          72%   │
  │  Recibo #8910 · Distribuidora Norte · 2026-03-08   │
  │  [Ver en Tesorería →]                               │
  ├─────────────────────────────────────────────────────┤
  │  Pedido #345                                  68%   │
  │  Saleor · Cliente: María López · Bs. 890            │
  │  [Ver en Ventas →]                                  │
  └─────────────────────────────────────────────────────┘

  Cada link verificado contra bAuth:
    ✓ Contador tiene APP_TRYTON → links de Facturación y Tesorería activos
    ✗ Contador NO tiene APP_SALEOR → link de Ventas deshabilitado
```

---

## 8. Flujo 7 — Instalación de una App Nueva por el Admin

**Perspectiva del usuario:** El administrador TI del cliente quiere agregar gestión documental. Ejecuta un comando y en 10 minutos tiene Paperless-NGX con OCR, firma digital, y acceso SSO integrado.

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
    [✓] paperless-ngx → OCR (español + inglés)
    [✓] tesseract-ocr
    [✓] tabula
    [✓] kimios → flujos de aprobación
    [✓] docuseal → firma digital

  [bos] Verificando...
    [✓] Upload documento PDF: OK
    [✓] OCR extrae texto: OK
    [✓] Firma digital funcional: OK

  ═══ Producto documents instalado en 9m 45s ═══

RESULTADO: El administrador ahora tiene:
  ✓ Gestión documental en https://empresa.com/docs
  ✓ Firma digital en https://empresa.com/sign
  ✓ Acceso SSO — los usuarios entran con su cuenta de siempre
  ✓ OCR automático de documentos escaneados
  ✓ bKernel ya indexa documentos nuevos para bSearch
  ✓ Todo sin tocar configuraciones de Keycloak, Kong, o PostgreSQL manualmente
```

---

## 9. Lo que Estos Flujos Demuestran

| Principio del SBOS | Evidencia en los flujos |
|---------------------|----------------------|
| **Es un SO, no un instalador** | Un formulario en una app dispara acciones en 6 apps simultáneamente. Eso no lo hace un instalador — lo hace un sistema operativo |
| **Los daemons son invisibles** | El usuario nunca sabe que existen bKernel, bAuth, biedata. Solo ve que "todo funciona junto" |
| **Cero invasión (P2)** | OrangeHRM no sabe que Tryton existe. Tryton no sabe que SIAT existe. El bKernel lo conecta todo sin modificar ninguna app |
| **Soberanía total (P1)** | La factura se emite al SIN sin que ningún dato salga a una nube de terceros. La IA analiza datos localmente |
| **Un solo login (P5)** | El vendedor presenta su QR y accede a todo. El contador inicia sesión una vez y tiene ERP, correo, BI |
| **Extensible por fichas (P7)** | Agregar gestión documental = un comando. Sin modificar el Core |
| **Seguridad Zero Trust** | El acceso físico y lógico se evalúa en cada solicitud. Un ex-empleado pierde TODO en 5 minutos |

---

## 10. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. 7 flujos de negocio end-to-end que demuestran el SBOS como Sistema Operativo de Negocios: alta de empleado (6 apps, 3 daemons), factura electrónica SIAT, apertura de punto de venta con QR (15ms), offboarding completo, consulta gerencial con IA, búsqueda federada, e instalación de producto.

---

*SKULL · SBOS · SBOS-039-BUSINESS-FLOWS · v1.0 · Marzo 2026*
*Clasificación: Especificación Funcional — La experiencia del Sistema Operativo*
