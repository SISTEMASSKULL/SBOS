# A.05 — Cierre de Gaps de bi18n: Manual de Desarrollo

**Tipo:** G — guía de implementación, para ejecutar ahora, no para planificar
**Versión del anexo:** 1.2.0
**Fecha:** 2026-07-17
**Respalda a:** [1.01 (bi18n Arquitectura)](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [A.04 (Técnica y guía de ligadura)](A.04_ANEXO-BI18N-TECNICA-LIGADURA-FRONTEND-v2.1.md)

Los 7 gaps identificados en la revisión anterior, con la técnica concreta para cerrar cada uno.
Sin roadmap a futuro — cada sección es ejecutable directamente sobre lo que ya existe.

---

## §1 RTL (texto de derecha a izquierda)

**Qué falta:** ningún campo del contrato indica dirección de texto. `icu_locale_core` ya sabe
qué locales son RTL (es un dato de CLDR, no hay que calcularlo).

**Técnica:** agregar `text_direction: "ltr" | "rtl"` a la respuesta de `bi18n.locale.resolve`
(§8 de 1.01) y a `attr.config_batch`. Se resuelve una vez por sesión, no por campo.

**Adapter por plataforma — dónde se aplica el flag:**

| Plataforma | Mecanismo nativo |
|---|---|
| Web | `document.documentElement.dir = text_direction` |
| Flutter | Envolver la app en `Directionality(textDirection: config.textDirection == 'rtl' ? TextDirection.rtl : TextDirection.ltr, child: ...)` |
| Vue | `document.documentElement.setAttribute('dir', textDirection)` (mismo mecanismo que web) |
| SwiftUI | `.environment(\.layoutDirection, direction)` en la vista raíz |
| Jetpack Compose | `CompositionLocalProvider(LocalLayoutDirection provides direction)` |
| WinUI/WPF | `FlowDirection` en el elemento raíz |

**Orden de ejecución:**
1. Agregar el campo al backend (trivial — `icu_locale_core::DataLocale` ya expone esta info).
2. Aplicarlo en la raíz de cada app cliente (una vez, no por widget individual).

---

## §2 Gobernanza de `country-rules/*.toml` y archivos de traducción

**Qué falta:** cualquiera con acceso al repo puede cambiar el regex de validación de un NIT
sin revisión obligatoria.

**Técnica — no requiere código nuevo, es configuración de repositorio:**

1. Archivo `CODEOWNERS` en la raíz del repo:
   ```
   /Bi18nAgent/country-rules/  @equipo-legal-fiscal @arquitecto-sbos
   /Bi18nAgent/translations/   @equipo-i18n
   ```
2. Regla de protección de rama en GitHub: `country-rules/**` y `translations/**` requieren
   al menos 1 aprobación de un `CODEOWNER` antes de mergear a `main`.
3. Campo `version` obligatorio dentro de cada TOML de país (`[meta] version = "1.3.0"`),
   incrementado en cada PR que modifique reglas — esto da trazabilidad semántica además
   del historial de Git.

**Definición de hecho:** un PR que toque `country-rules/bo.toml` sin aprobación del equipo
fiscal no puede mergearse — verificarlo intentando mergear uno de prueba.

---

## §3 Detección de claves de traducción faltantes (CI)

**Qué falta:** si `pt-BR` no tiene una clave que sí existe en `es-BO`, nadie se entera hasta
que un usuario ve el fallback en producción.

**Técnica:** paso de CI que compara el set de claves de cada locale contra el locale de
referencia (`es-BO`, o el que definas como fuente) y falla el build si falta alguna.

```yaml
# .github/workflows/ci.yml — job nuevo, mismo patrón que Race Detection (hard gate)
- name: i18n-key-parity
  run: |
    cargo run --bin i18nctl -- translations check-parity \
      --reference es-BO --fail-on-missing
```

Esto requiere agregar el subcomando `translations check-parity` a `i18nctl` (ya definido
en A.02 §4) — compara claves entre archivos TOML/Fluent y devuelve exit code 1 si hay faltantes.

**Orden de ejecución:**
1. Implementar `i18nctl translations check-parity` (comparación de sets de claves, sin lógica compleja).
2. Agregarlo como job obligatorio en `.github/workflows/ci.yml`, mismo nivel que Race Detection.

---

## §4 Alta disponibilidad de `bi18nd`

**Qué falta:** no hay definición de qué pasa si la única instancia del daemon se cae.

**Técnica:**

1. **`country-rules/*.toml` empaquetado dentro del artefacto de despliegue (inmutable).**
   Cambia poco, es de alto riesgo (§2), y cualquier cambio ya pasa por aprobación y redeploy
   normal — no necesita ni debe tener hot-reload. Esto mantiene cualquier réplica nueva
   idéntica a las demás sin sincronización adicional para este dato.

2. **`translations/*.ftl`/`.toml` en un path mutable compartido, con hot-reload — no
   empaquetado en el artefacto.** Esto es una excepción intencional a la regla de "sin estado
   mutable" del punto anterior, justificada porque el objetivo explícito de A.06 es actualizar
   traducciones sin redeploy. La condición para que esto no rompa HA: el mecanismo de
   sincronización y el RPC de recarga (`bi18n.admin.reload_translations`, A.06 §4) deben
   **alcanzar a todas las réplicas**, no solo a la que responda primero detrás de Kong — si
   el pipeline de CI llama al RPC a través de la ruta balanceada, una sola réplica se entera
   y las demás sirven texto desdesactualizado hasta su próximo reinicio. El pipeline debe
   dirigirse a cada instancia individualmente (o vía un mecanismo pub/sub interno si el número
   de réplicas crece), y el mismo storage/volumen de `translations/` debe ser accesible por
   todas las réplicas por igual (volumen compartido o sincronización idéntica a cada una).

3. **N réplicas de `bi18nd` detrás de Kong**, balanceadas por Kong con *health check* activo
   sobre `bi18n.health.check` (A.02 §4.3).
4. **Comportamiento del cliente ante corte total:** ya definido en A.04 §5 (fallback offline
   por campo). No hay que rediseñar nada del lado cliente.

**Orden de ejecución:**
1. Verificar que el build empaqueta `country-rules/` dentro del artefacto (inmutable).
2. Definir un volumen/storage compartido para `translations/`, accesible por igual desde
   todas las réplicas (no un disco local por instancia).
3. Definir 2+ réplicas en el despliegue de `bi18nd`, con Kong apuntando a las dos vía
   `bi18n.health.check`.
4. Confirmar que el pipeline de A.06 §6 llama a `reload_translations` en cada réplica
   individualmente, no solo a la que responde detrás del balanceador.

---

## §5 Accesibilidad (a11y) en los adapters de cliente

**Qué falta:** ningún adapter de A.04 §9 anuncia errores a lectores de pantalla.

**Técnica — un ajuste por adapter, no un componente nuevo:**

| Plataforma | Qué agregar |
|---|---|
| Web | El contenedor del mensaje de error debe tener `aria-live="polite"` y `role="alert"` cuando `overall !== "ok"` |
| Flutter | Envolver el texto de error en `Semantics(liveRegion: true, label: errorMessage)` |
| Vue | Igual que web — `aria-live="polite"` en el `<small class="p-error">` |
| SwiftUI | `.accessibilityAnnouncement()` al cambiar `error` |
| Jetpack Compose | `LiveRegion` de Compose Accessibility al actualizar el estado de error |

**Orden de ejecución:** aplicar directamente sobre los 4 ejemplos ya escritos en A.04 §9 —
es un atributo/modificador agregado a un elemento que ya existe, no una reestructura.

---

## §6 Especificación del protocolo WebSocket (contract-first, agnóstico de plataforma)

**bi18n es agnóstico de plataforma.** No es responsabilidad del daemon crear ni mantener
SDKs en lenguajes o frameworks de frontend. Cada equipo cliente implementa su propio adapter
en el lenguaje que le corresponda, siguiendo el contrato del protocolo.

**Lo que sí es responsabilidad del daemon bi18n:**

Publicar una **especificación formal del protocolo** (A.07) que permita a cualquier equipo
implementar un cliente sin leer el código fuente del daemon:
- URL del endpoint WebSocket expuesto por Kong.
- Mecanismo de autenticación (header JWT, qué claim).
- Framing exacto: JSON-RPC 2.0 newline-delimited (un objeto JSON por línea, `\n` como delimitador).
- Todos los métodos disponibles, sus parámetros y las respuestas posibles.
- Códigos de error específicos del transporte WebSocket.
- Pseudocódigo neutro de una conexión mínima (sin lenguaje concreto).

**Lo que corresponde a cada equipo cliente:**

| Responsabilidad | Quién la tiene |
|---|---|
| Adapter de máscara (`mask_pattern` → mecanismo nativo) | Equipo de la app cliente |
| Máquina de estados + debounce | Equipo de la app cliente |
| SDK/paquete/librería en su lenguaje | Equipo de la app cliente |
| Versionado del adapter en sincronía con el contrato | Equipo de la app cliente |

Los ejemplos de A.04 §9 son referencias de implementación que ilustran el protocolo en cuatro
lenguajes distintos — no son artefactos mantenidos por bi18n. Los equipos los usan como punto
de partida o los ignoran; el daemon no cambia.

**Orden de ejecución (responsabilidad del daemon):**
1. Crear `A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md` con la especificación formal.
2. Mantenerlo actualizado cuando cambie el contrato (versión del contrato, no del binario).

---

## §7 Checklist de cierre — los 6 puntos

- [ ] `text_direction` presente en `locale.resolve` y `attr.config_batch`.
- [ ] `CODEOWNERS` con reglas sobre `country-rules/` y `translations/`, branch protection activa.
- [ ] `i18nctl translations check-parity` corriendo como job obligatorio en CI.
- [ ] `bi18nd` corriendo en 2+ réplicas detrás de Kong con health check activo.
- [ ] Los ejemplos de A.04 §9 incluyen los atributos de accesibilidad (`aria-live`, `Semantics`, etc.) como referencia para los equipos cliente.
- [ ] `A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md` publicado — especificación formal del protocolo agnóstico de plataforma.

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-16 | Anexo inicial. Técnica de cierre para los 7 gaps identificados en la revisión de completitud: RTL, gobernanza de country-rules, CI de paridad de traducciones, alta disponibilidad, accesibilidad, y empaquetado de SDKs versionados. Ejecutable directamente, sin fases a futuro. |
| 1.1.0 | 2026-07-16 | Corregida contradicción con A.06: §4 (HA) exigía traducciones empaquetadas de forma inmutable, lo cual es incompatible con el hot-reload de A.06. Separado explícitamente `country-rules/` (inmutable, empaquetado) de `translations/` (mutable, volumen compartido entre réplicas, hot-reload). Agregado requisito de que el RPC de recarga alcance a todas las réplicas, no solo a la que responde detrás de Kong. |
| 1.2.0 | 2026-07-17 | §6 reescrito: eliminado el objetivo de crear SDKs por plataforma dentro del repo del daemon (contraviene el principio agnóstico de bi18n). Reemplazado por la responsabilidad correcta: publicar A.07 (especificación formal del protocolo WebSocket). Checklist actualizado de 7 a 6 puntos. |
