# Perfiles de Usuario — SBOS SmartRates

---

## Perfil 1 — Operador Financiero

**Quién es:** El responsable financiero o contador de la empresa que gestiona el tipo de cambio del día a día. Conoce el negocio boliviano, sabe qué es el mercado paralelo y cuándo aplicarlo, pero no es técnico. Opera desde su escritorio en la sucursal.

**Frecuencia de uso:** Diario — primera tarea de la mañana (antes de las 09:00)

**Nivel técnico:** Básico-intermedio. Maneja Excel, sistemas contables, pero no sabe de APIs ni configuración de servidores.

**Su tarea principal:** Ver el tipo de cambio del día, confirmar el ajuste del mercado alternativo si aplica, y asegurarse de que la información esté disponible para la empresa antes de que empiece la operación.

**Sus frustraciones actuales:**
- Tiene que buscar el tipo de cambio en el sitio del BCB manualmente cada mañana
- El Excel compartido con los tipos de cambio siempre tiene alguien que lo olvidó actualizar
- No sabe si el sistema de facturación está usando el tipo de cambio correcto o uno de ayer
- Cuando hay feriado o fin de semana largo, no sabe qué valor usar el lunes

**Criterio de éxito:** En menos de 5 minutos desde que llega a su computadora, confirmó el ajuste del día y el sistema ya está propagado. No tiene que hacer nada más durante el día salvo revisar alertas.

**Casos de uso principales:**
1. Ver el tipo de cambio del día con comparación vs ayer (¿subió? ¿bajó? ¿cuánto?)
2. Confirmar el monto del ajuste del mercado alternativo para el día
3. Ver el historial de confirmaciones de ajuste de los últimos 30 días
4. Recibir notificación si el sistema no sincronizó correctamente
5. Consultar el tipo de cambio de fechas pasadas para validar documentos

**Lo que NO puede hacer:**
- No puede modificar cotizaciones históricas
- No puede cambiar la política de empresa (eso es el Administrador)
- No puede forzar una sincronización manual (eso es el Administrador)
- No puede gestionar usuarios

**Rol en el sistema:** `smartrates.operator`

---

## Perfil 2 — Administrador del Sistema

**Quién es:** El responsable de TI o el gerente financiero de la empresa. Tiene acceso total. Configura las políticas cambiarias, gestiona los permisos de otros usuarios, puede forzar sincronizaciones y revisar el estado técnico del sistema.

**Frecuencia de uso:** Semanal para tareas de mantenimiento; diario para revisión de alertas si hay incidencias.

**Nivel técnico:** Intermedio-avanzado. Entiende conceptos de APIs, sabe leer logs, puede interpretar métricas.

**Su tarea principal:** Garantizar que el sistema funcione correctamente, configurar las políticas de la empresa y resolver incidencias.

**Sus frustraciones actuales:**
- Cuando una fuente externa falla, no tiene visibilidad de qué está pasando ni por qué
- No puede auditar quién confirmó qué ajuste y cuándo
- No puede cambiar la política de mercado alternativo sin llamar al proveedor del sistema

**Criterio de éxito:** El panel de estado muestra verde en todas las fuentes. Los logs de sincronización son accesibles y comprensibles. Puede cambiar cualquier configuración sin asistencia técnica externa.

**Casos de uso principales:**
1. Revisar el estado de todas las fuentes externas (¿sincronizaron hoy?)
2. Forzar una sincronización inmediata cuando hay un problema
3. Configurar la política de black rate para la empresa (disabled / reference / national)
4. Gestionar usuarios y asignar roles
5. Revisar el log de auditoría de confirmaciones de ajuste
6. Iniciar o pausar el proceso de backfill histórico
7. Ver el dashboard de métricas del sistema (latencia, errores, volumen)

**Lo que puede hacer exclusivamente:**
- Cambiar la política `use_black_rate` de la empresa
- Forzar `POST /sync/trigger`
- Gestionar el backfill histórico
- Ver el audit log completo de todos los usuarios
- Cambiar la moneda puente (`bridge_currency`)

**Rol en el sistema:** `smartrates.admin`

---

## Perfil 3 — Consultor de Solo Lectura

**Quién es:** Un usuario del ecosistema SBOS (vendedor, gerente de sucursal, analista) que necesita consultar tipos de cambio para su trabajo cotidiano pero no tiene responsabilidades de gestión. Puede acceder desde el móvil.

**Frecuencia de uso:** Varias veces al día — cada vez que necesita convertir un monto o verificar una cotización.

**Nivel técnico:** Básico. Usa la app igual que cualquier app de teléfono.

**Su tarea principal:** Saber cuánto cuesta algo en otra moneda, ahora mismo, con el tipo de cambio correcto de la empresa.

**Sus frustraciones actuales:**
- Abre Google para buscar el tipo de cambio pero el resultado no coincide con lo que usa la empresa
- No sabe si debe usar el tipo de cambio oficial o el del mercado alternativo
- Cuando está fuera de la oficina no tiene acceso al Excel con los tipos de cambio

**Criterio de éxito:** Abre la app, escribe un monto, selecciona dos monedas, y en 3 segundos tiene el resultado correcto con el tipo de cambio que la empresa ha configurado.

**Casos de uso principales:**
1. Convertir un monto de BOB a USD (o cualquier par configurado)
2. Ver cuál es el tipo de cambio del día para BOB/USD
3. Ver el historial de cotizaciones de los últimos 7/30 días
4. Ver los tipos de cambio de los bloques más importantes (G7, Mercosur)

**Lo que NO puede hacer:**
- No puede ver ni confirmar ajustes del mercado alternativo
- No puede acceder al panel de sincronización
- No puede acceder al audit log
- No puede modificar ninguna configuración

**Rol en el sistema:** `smartrates.readonly`

---

## Perfil 4 — Desarrollador Integrador (API Consumer)

**Quién es:** Un desarrollador que integra SmartRates en otra aplicación del ecosistema SBOS (Tryton, SmartTax, Saleor) o en un sistema externo del cliente. Puede ser interno de SKULL o un desarrollador del cliente.

**Frecuencia de uso:** En desarrollo: diario. En producción: el sistema consume la API automáticamente.

**Nivel técnico:** Avanzado. Conoce APIs REST, JWT, PostgreSQL.

**Su tarea principal:** Integrar los tipos de cambio en su aplicación de la forma más eficiente posible.

**Sus frustraciones actuales:**
- La documentación de APIs de terceros está desactualizada o incompleta
- No puede probar la API sin crear una cuenta y esperar aprobación
- No sabe cómo manejar los fines de semana y feriados bolivianos
- Los reportes JasperReports con conversiones de moneda tardan demasiado

**Criterio de éxito:** En menos de 30 minutos tiene el sistema corriendo localmente y está haciendo su primera llamada a la API. La documentación Swagger es tan buena que no necesita pedir ayuda.

**Casos de uso principales:**
1. Leer la documentación Swagger interactiva en `/api/documentation`
2. Usar el Explorador SmartRates (Playground) para entender el comportamiento antes de codificar
3. Instalar `CREATE EXTENSION smartrates_rate` en su BD y usar `catalog.RATE()` en sus queries SQL
4. Integrar el Ticker como Web Component en 2 líneas en su aplicación
5. Suscribirse al WebSocket `rates.updated` para actualizar precios en tiempo real
6. Usar `POST /convert/batch` para conversiones masivas en lote

**Lo que puede hacer con el rol de API:**
- Acceso de solo lectura a todos los endpoints de cotizaciones y conversión
- Sin acceso a endpoints de empresa ni de sincronización
- Rate limit según plan contratado (1.000 / 5.000 / 50.000 req/hora)

**Rol en el sistema:** `smartrates.api`

---

## Perfil 5 — Sistema Consumidor Interno (Machine-to-Machine)

**Quién es:** No es una persona — es otro sistema del ecosistema SBOS (Tryton, SmartTax, Saleor, JasperReports, bCompass) que consume SmartRates de forma automática, sin intervención humana.

**Frecuencia de uso:** Continua — cada vez que hay una conversión de moneda en el sistema consumidor.

**Nivel técnico:** N/A — es una integración técnica.

**Su tarea principal:** Obtener el tipo de cambio correcto para la fecha y las monedas solicitadas, con la latencia más baja posible.

**Mecanismo principal:** En producción SBOS, usa directamente `catalog.RATE()` via SQL — zero latencia de red. En modo standalone, usa el endpoint REST `/api/v1/convert`.

**Casos de uso principales:**
1. **Tryton:** `catalog.RATE(fecha, 'BOB', 'USD', monto, 2)` en queries de contabilidad multicurrency
2. **SmartTax:** obtener el tipo de cambio oficial BCB del día para calcular el monto en BOB de facturas en USD (requerimiento legal boliviano)
3. **Saleor:** convertir precios de catálogo a la moneda del visitante en tiempo real
4. **JasperReports:** `SELECT catalog.RATE(...)` en la query del reporte — 50.000 conversiones en 50ms
5. **bCompass:** analizar tendencias de volatilidad cambiaria via SELECT en `rates.exchange_rates`

**Rol en el sistema:** Service account con `smartrates.api` + acceso directo a BD via extensión

---

## Matriz de acceso por perfil

| Funcionalidad | Operador | Admin | ReadOnly | API | Sistema |
|---|---|---|---|---|---|
| Ver cotizaciones del día | ✅ | ✅ | ✅ | ✅ | ✅ |
| Convertir montos | ✅ | ✅ | ✅ | ✅ | ✅ vía RATE() |
| Ver historial | ✅ | ✅ | ✅ 30 días | ✅ | ✅ |
| Confirmar ajuste diario | ✅ | ✅ | ❌ | ❌ | ❌ |
| Ver panel de ajustes | ✅ | ✅ | ❌ | ❌ | ❌ |
| Configurar política empresa | ❌ | ✅ | ❌ | ❌ | ❌ |
| Forzar sync manual | ❌ | ✅ | ❌ | ❌ | ❌ |
| Ver estado de fuentes | ❌ | ✅ | ❌ | ❌ | ❌ |
| Gestionar backfill | ❌ | ✅ | ❌ | ❌ | ❌ |
| Ver audit log | ❌ | ✅ | ❌ | ❌ | ❌ |
| Gestionar usuarios | ❌ | ✅ | ❌ | ❌ | ❌ |
| Usar catalog.RATE() | ❌ | ❌ | ❌ | ❌ | ✅ |
| WebSocket rates.updated | ✅ | ✅ | ✅ | ✅ | ✅ |
| Ticker embebido | ✅ | ✅ | ✅ | ✅ | ✅ |

---
_SKULL · SBOS · SmartRates · 003-USUARIOS · v1.0 · 2026-05-23_
