# A.04 — Ligadura de bi18n a Componentes de UI: Técnica y Guía de Implementación

**Tipo:** R/G — fundamento técnico breve + guía de implementación
**Versión del anexo:** 2.2.0
**Fecha:** 2026-07-17
**Respalda a:** [1.01 (bi18n Arquitectura)](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [A.02 (Interfaces de consumo)](A.02_ANEXO-BI18N-INTERFACES-CONSUMO-v1.1.md)

---

## Principio: bi18n es completamente agnóstico de plataforma

**bi18n no conoce ni depende de ningún framework, lenguaje o entorno de frontend.**

El daemon expone un protocolo neutro: **WebSocket + JSON-RPC 2.0 newline-delimited** (un objeto
JSON por línea, `\n` como delimitador). Cualquier cliente capaz de abrir una conexión WebSocket
y serializar/deserializar JSON puede consumir bi18n — sin importar si está escrito en Dart,
TypeScript, Kotlin, Swift, Python, Go, C#, Ruby, PHP, o cualquier otro lenguaje.

**Qué pertenece al daemon (bi18nd):**
- El listener WebSocket y el listener Unix socket.
- El protocolo JSON-RPC 2.0 y los métodos disponibles.
- La lógica de validación, formateo y resolución de locale.
- La documentación del contrato (este documento + A.07).

**Qué pertenece a cada equipo cliente:**
- La implementación del adapter en su lenguaje/framework nativo.
- La máscara, la máquina de estados, el debounce — aplicados a su mecanismo de UI.
- Cualquier paquete, SDK o librería que empaquete su adapter.

Los ejemplos de §9 son **referencias de implementación** — no son entregables del daemon.
Su propósito es demostrar que el contrato funciona en cualquier contexto, no prescribir
tecnología. Un equipo puede usar el ejemplo como punto de partida o escribir su adapter
desde cero; bi18n sigue siendo el mismo en ambos casos.

---

## §1 Contexto — qué técnica es esta y qué experiencia de la industria cubre

**Nombre de la técnica:** *Metadata-driven attribute binding con adapters de renderizado por plataforma* — una variante **minimal** de **Server-Driven UI (SDUI)**, aplicada a nivel de campo individual (no de pantalla completa).

**Por qué esta y no otra cosa:** es la combinación de dos patrones ya probados en producción a gran escala, aplicados al problema puntual de bi18n:

- **SDUI / Schema-Driven Forms** (Airbnb "Ghost Platform", Lyft, Form.io): el servidor describe reglas de un campo (máscara, formato, validación) y el cliente las interpreta, en vez de que cada plataforma reimplemente la regla de negocio. Lección clave que tomamos de Lyft: construir solo la flexibilidad que el negocio necesita, no un motor genérico — por eso bi18n se queda en "nivel de campo" y **no** crece hacia layout de pantalla completa (eso sí sería sobre-ingeniería, y es justo lo que Netflix evitó al no aplicar SDUI en su pantalla principal).
- **Adapter Pattern** (catálogo GoF): cada plataforma cliente traduce el contrato neutral a su mecanismo nativo, una implementación por plataforma, sin que el daemon sepa cuántas ni cuáles existen. Esto es lo que garantiza, en la práctica, que la ligadura sea independiente de lenguaje — no el JSON por sí solo.

Con esto ya fundamentado, el resto de este documento es la guía de implementación real: qué construir, en qué orden, con qué técnica.

---

## §2 Transporte — la decisión que condiciona todo lo demás

| Cliente | Transporte | Por qué |
|---|---|---|
| Procesos en el mismo VPS (`i18nctl`, otros daemons Rust) | Unix socket `/run/bos/bi18n.sock` | Cero overhead de red, ya definido en 1.01 |
| Frontends remotos (web, Flutter, iOS, Android, Windows, macOS, Linux) | **WebSocket** sobre TLS, expuesto vía Kong | Es lo único de los dos que atraviesa la red pública — el socket Unix no sirve para esto |

**Por qué WebSocket y no HTTP request/response:** vas a mandar varias validaciones seguidas (una por campo, con debounce) sobre la misma sesión sin pagar handshake TLS cada vez, y más adelante sirve para push (ej. si cambian reglas de un país con el formulario abierto). HTTP POST JSON-RPC también funcionaría para un MVP, pero terminarías migrando a WebSocket apenas tengas validación en vivo — mejor empezar ahí.

**Qué monta esto en tu infraestructura:** una ruta en Kong que haga *transcoding* de WebSocket público al listener interno del daemon (mismo patrón que ya usas para JSON-RPC→gRPC). El daemon no necesita saber que Kong existe — solo expone un listener WebSocket además del Unix socket.

---

## §3 El contrato — lo único que el cliente necesita memorizar

**Al abrir un formulario (una vez, batch):**
```
→ bi18n.attr.config_batch { fields: [...], locale, country, tenant_id }
← { CI: {mask_pattern, display_format, validator_profile}, phone: {...}, ... }
```

**Al perder foco o enviar (una por campo):**
```
→ bi18n.attr.pipeline { field_id, value, validator_profile, locale }
← { valid, display, masked, validation_errors: [...] }
```

Todo lo demás (`format.date`, `validate.email`, etc.) son atajos del mismo patrón para casos puntuales fuera de un formulario completo.

---

## §4 Técnicas del lado servidor (bi18nd)

| Técnica | Qué resuelve |
|---|---|
| **Method dispatch table** (mapa `string → handler`) | Enrutar `"bi18n.attr.pipeline"` sin un `match` gigante que crezca sin control |
| **Connection actor por socket** (un task de Tokio por conexión WebSocket) | Que una conexión lenta/rota no bloquee a las demás |
| **Cache de `country-rules/*.toml` en memoria, con recarga por señal (`SIGHUP`) o *watcher* de archivo** | Evitar leer disco en cada validación; actualizar reglas de país sin reiniciar el daemon |
| **Resolución de locale/tenant como paso previo, no repetido por campo** | Si el batch trae 20 campos, resolver el locale efectivo una sola vez, no 20 |
| **Rate limiting por conexión en `attr.pipeline`** | Evitar que un cliente mal implementado (sin debounce) sature el daemon |
| **Timeout explícito por request** | Que una regla remota lenta (ej. denylist) no cuelgue la conexión completa |

**Orden de construcción recomendado:**
1. `attr.pipeline` para un solo `display_format` (ej. `DATE_ISO`) funcionando de punta a punta sobre socket Unix.
2. Agregar `attr.config` / `attr.config_batch`.
3. Agregar el listener WebSocket en paralelo al Unix socket (mismo core, dos transportes).
4. Rate limiting y timeout — recién cuando ya tengas tráfico real, no antes.

---

## §5 Técnicas del lado cliente (cualquier plataforma)

Se implementa **una vez por plataforma**, no por campo ni por formulario.

| Técnica | Qué resuelve |
|---|---|
| **Cliente singleton con conexión persistente** | Una sola conexión WebSocket viva por sesión de app, no una por campo ni por formulario |
| **Cache en memoria de `FieldConfig` por `field_id`** | `attr.config_batch` se pide una vez al abrir la pantalla; si el usuario vuelve en la misma sesión, no se repite |
| **Debounce en la capa de validación, no en la de máscara** | La máscara se aplica sincrónicamente y local; solo la validación remota necesita debounce (250–300ms) |
| **Adapter Pattern (uno por plataforma)** | Traduce `mask_pattern` al mecanismo nativo del widget — la única pieza que cambia por plataforma |
| **Máquina de estados por campo:** `idle → validating → valid / warning / error` | Evita condiciones de carrera si el usuario escribe más rápido de lo que responde el daemon — quedarse solo con la última respuesta, descartando las obsoletas |
| **Fallback offline explícito** | Si se corta la conexión, el campo sigue mostrando la máscara cacheada, pero la validación pasa a `pending`/`sin conexión` — nunca a `válido` por default |

**Orden de construcción recomendado (aplica a cualquier plataforma):**
1. Conexión al WebSocket del daemon, verificar que `bi18n.health.check` responde.
2. Llamar `attr.config_batch` para un formulario de prueba — verificar que llegan los configs.
3. Implementar el adapter de máscara (`mask_pattern` → mecanismo nativo de la plataforma).
4. Máquina de estados de validación con debounce (la misma lógica, diferente mecanismo de UI).
5. El widget/componente de alto nivel que el equipo usa en sus formularios reales.

---

## §6 Flujo completo, paso a paso

```
1. App abre pantalla "Alta de factura"
2. Cliente pide bi18n.attr.config_batch (todos los campos, una llamada)
3. Cliente cachea la respuesta; aplica mask_pattern a cada input vía su Adapter
4. Usuario escribe en "monto" → máscara se aplica local, sin red
5. Usuario pierde foco de "monto" → cliente llama bi18n.attr.pipeline (solo ese campo)
6. Mientras espera → estado del campo pasa a "validating"
7. Respuesta llega → estado pasa a valid/warning/error, se pinta el mensaje si aplica
8. Usuario presiona "Guardar" → cliente vuelve a llamar attr.pipeline para TODOS los campos
   (revalidación final, autoridad del daemon, sin excepción)
9. Solo si todo vuelve "valid" (o "warning" sin error), se envía al endpoint de negocio
   correspondiente — bi18n no persiste datos de negocio
```

---

## §7 Qué NO hacer

- **No** abrir una conexión WebSocket nueva por campo o por formulario — una por sesión de app.
- **No** validar en `on_input` sin debounce.
- **No** tratar `overall: "warning"` como bloqueante — solo `"error"` bloquea envío.
- **No** confiar en la última validación mostrada al momento del submit — siempre revalidar todo en `on_submit`.
- **No** mezclar la lógica del Adapter con lógica de negocio — el Adapter no debe saber qué es un CPF, solo aplicar un `mask_pattern` string.
- **No** implementar reglas de validación en el cliente "para que sea más rápido" — eso es la duplicación de fuente de verdad que este diseño evita.

---

## §8 Definición de "hecho" para el primer entregable

- [ ] Un campo `DATE_ISO` en Flutter muestra la máscara correcta apenas se abre el formulario, sin que el desarrollador la haya escrito a mano.
- [ ] Al perder foco con una fecha inválida, aparece el error que vino del daemon (no uno hardcodeado en el cliente).
- [ ] Al cortar la red a mitad de escritura, el campo sigue mostrando la máscara y no deja pasar el submit como válido.
- [ ] El mismo `field_id`/`display_format` funciona igual en Flutter y en un segundo cliente de prueba, sin tocar el daemon.

---

## §9 Ejemplos de referencia por plataforma

Los cuatro siguen exactamente el mismo contrato de §3 — máscara aplicada local con `9`=dígito,
validación remota en `blur`. Son **referencias de implementación** para equipos clientes, no
entregables del daemon. Demuestran que el mismo protocolo funciona independientemente de la
plataforma. Cualquier equipo puede implementar su propio adapter en cualquier otro lenguaje
siguiendo el mismo contrato — bi18n no cambia.

### 9.1 Servidor (Rust) — dispatch de `attr.pipeline`

```rust
async fn handle_message(msg: Value) -> Value {
    match msg["method"].as_str().unwrap_or("") {
        "bi18n.attr.config_batch" => attr_config_batch(&msg["params"]).await,
        "bi18n.attr.pipeline" => attr_pipeline(&msg["params"]).await,
        _ => json!({"error": {"code": -32601, "message": "Method not found"}}),
    }
}

async fn attr_pipeline(params: &Value) -> Value {
    let value = params["value"].as_str().unwrap_or("");
    let profile = params["validator_profile"].as_str().unwrap_or("");
    let rule = country_rules_cache::get(profile); // TOML cacheado en memoria, §4

    let valid = rule.regex.is_match(value);
    json!({
        "valid": valid,
        "display": format_value(value, &rule),
        "masked": mask_value(value, &rule.mask_strategy),
        "validation_errors": if valid { vec![] } else { vec![rule.error_message.clone()] }
    })
}
```

### 9.2 Web (vanilla JS, sin framework)

```js
const ws = new WebSocket("wss://bi18n.tuservidor.com/ws");
let config = {};

ws.onopen = () => ws.send(JSON.stringify({
  jsonrpc: "2.0", id: 1, method: "bi18n.attr.config_batch",
  params: { fields: [{ key: "CI", display_format: "ID_BO" }], locale: "es-BO", country: "bo" }
}));

ws.onmessage = (evt) => {
  const msg = JSON.parse(evt.data);
  if (msg.id === 1) { config = msg.result; applyMask(document.getElementById("ci"), config.CI.mask_pattern); }
};

function applyMask(input, pattern) {
  input.addEventListener("input", () => {
    const digits = input.value.replace(/\D/g, "");
    let out = "", di = 0;
    for (const ch of pattern) { if (di >= digits.length) break; out += ch === "9" ? digits[di++] : ch; }
    input.value = out;
  });
}

document.getElementById("ci").addEventListener("blur", (e) => ws.send(JSON.stringify({
  jsonrpc: "2.0", id: 2, method: "bi18n.attr.pipeline",
  params: { field_id: "CI", value: e.target.value, validator_profile: config.CI.validator_profile, locale: "es-BO" }
})));
```

### 9.3 Flutter (desktop — mismo código sirve para móvil, el Adapter no cambia)

```dart
class Bi18nMaskFormatter extends TextInputFormatter {
  final String pattern;
  Bi18nMaskFormatter(this.pattern);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    var di = 0;
    for (final ch in pattern.split('')) {
      if (di >= digits.length) break;
      buf.write(ch == '9' ? digits[di++] : ch);
    }
    return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
  }
}

// Uso en el formulario:
final config = await bi18n.getFieldConfig('CI');
TextField(
  inputFormatters: [Bi18nMaskFormatter(config.maskPattern)],
  onEditingComplete: () async {
    final result = await bi18n.validateField('CI', controller.text, config.validatorProfile);
    setState(() => fieldError = result.valid ? null : result.errors.first);
  },
);
```

### 9.4 Vue 3 + PrimeVue

```vue
<template>
  <InputText v-model="ci" @input="applyMask" @blur="validate" :class="{ 'p-invalid': error }" />
  <small class="p-error">{{ error }}</small>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { bi18nClient } from '@/lib/bi18n';

const ci = ref('');
const error = ref(null);
let config = null;

onMounted(async () => { config = await bi18nClient.getFieldConfig('CI'); });

function applyMask() {
  const digits = ci.value.replace(/\D/g, '');
  let out = '', di = 0;
  for (const ch of config.mask_pattern) { if (di >= digits.length) break; out += ch === '9' ? digits[di++] : ch; }
  ci.value = out;
}

async function validate() {
  const result = await bi18nClient.validateField('CI', ci.value, config.validator_profile);
  error.value = result.valid ? null : result.validation_errors[0];
}
</script>
```

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-16 | Versión inicial — investigación extensa de precedentes de industria. |
| 2.0.0 | 2026-07-16 | Reescrito: contexto reducido a §1 (breve), agregada la guía práctica completa (§2–§8: transporte, contrato, técnicas servidor/cliente, flujo, errores a evitar, definición de hecho). Reemplaza la versión 1.0.0 y absorbe el contenido del documento de guía suelto. |
| 2.1.0 | 2026-07-16 | Agregado §9: ejemplos de referencia de implementación en Rust (servidor), web vanilla, Flutter desktop y Vue 3 + PrimeVue — los cuatro siguiendo el mismo contrato y la misma convención de máscara (`9`=dígito) definidos en §3. |
| 2.2.0 | 2026-07-17 | Principio agnóstico de plataforma documentado explícitamente al inicio del documento. §5 orden de construcción desacoplado de Flutter (aplica a cualquier plataforma). §9 reenmarcado como "referencias de implementación" (no entregables del daemon). bi18n no conoce ni depende de ningún framework, lenguaje o entorno de frontend. |
