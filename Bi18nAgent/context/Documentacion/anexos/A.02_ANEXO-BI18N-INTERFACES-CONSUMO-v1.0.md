# A.02 — Interfaces de Consumo de bi18n: UI Remota (JSON-RPC) y CLI Interno (i18nctl)

**Tipo:** Anexo de arquitectura — cómo consumen bi18n los dos mundos de cliente
**Versión del anexo:** 1.0.0
**Fecha:** 2026-07-16
**Respalda a:** [1.01 (bi18n Arquitectura)](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [A.01 (Cobertura de librerías)](A.01_ANEXO-BI18N-COBERTURA-LIBRERIAS-v1.0.md)
**Reemplaza a:** ORQUESTA-048 v1 (documento de trabajo previo, no versionado en el repo) — este anexo lo sustituye, alineado al contrato real de bi18n

---

## §0 Corrección de alcance respecto a la versión de trabajo previa

La primera versión de este análisis (fuera de repo) cometió tres errores que este anexo corrige:

1. **Inventaba una convención de máscara propia** (`0`/`9`/`A`/`*`) en vez de usar el mecanismo real ya documentado en 1.01 §7.2: la máscara se **deriva del patrón CLDR** vía ICU4X, traducido carácter por carácter (`d`,`M`,`y`→`9`, separadores literales se preservan). Este anexo usa exclusivamente ese mecanismo.
2. **Incluía `PASSWORD` como tipo cubierto por bi18n**, con un modo de validación por composición (checklist en vivo tipo fortaleza de contraseña). Esto queda **fuera de alcance**: bi18n es un servicio de internacionalización — formatea, valida regionalmente y enmascara atributos de identidad y de negocio — y **no se entromete en autenticación**. La validación de contraseñas es responsabilidad del componente de autenticación (bAuth u otro), no de bi18n.
3. **Proponía un contrato de dos llamadas separadas** (`getFieldConfig` / `validateField`) en vez de reconocer el pipeline real ya implementado (`bi18n.attr.pipeline` / `AttrBuilder`, 1.01 §7.3). Este anexo reconcilia ambos mundos: mantiene una llamada liviana de solo-configuración para UX en vivo (necesaria y no cubierta por el manual 1.01), pero la monta explícitamente sobre el pipeline real, no sobre una fantasía paralela.

---

## §1 Principio de alcance de bi18n (reafirmado)

bi18n es **horizontal**: cualquier componente de SBOS que defina atributos (bAuth, bpay, btax, bcms, bhnexus, etc.) delega en bi18n la resolución de máscara, formato, validación regional y enmascarado PII de esos atributos. bAuth es un consumidor más — no el dueño del servicio.

bi18n **nunca**:
- Autentica ni autoriza.
- Valida fortaleza de contraseñas ni políticas de credenciales.
- Decide reglas de negocio no relacionadas con presentación/validación regional de un valor.

bi18n **siempre**:
- Resuelve máscara y formato de un atributo según su `display_format` (catálogo de 18 códigos, 1.01 §7.1) y el locale/país efectivo del tenant.
- Ejecuta el pipeline `validate → transform → format → mask` (AttrBuilder, 1.01 §7.3) cuando se le pide.
- Es la única fuente de verdad — ningún cliente (UI ni código interno) reimplementa una regla que bi18n ya resuelve.

---

## §2 Los dos mundos de consumo

```
                         ┌───────────────────────┐
                         │      bi18nd (Rust)     │
                         │  core: i18n-orchestrator│
                         └───────────┬────────────┘
                     ┌───────────────┼────────────────┐
                     │                                 │
        Unix socket / JSON-RPC 2.0            invocación local (mismo host)
        /run/bos/bi18n.sock                    binario i18nctl (clap)
                     │                                 │
         ┌───────────▼────────────┐         ┌─────────▼──────────┐
         │   Mundo 1: UI remota    │         │  Mundo 2: CLI interno│
         │  (web, Flutter, iOS,    │         │  (scripts, jobs,     │
         │   Android, Windows,     │         │   otros daemons,     │
         │   macOS, Linux)         │         │   CI/CD, migraciones)│
         └─────────────────────────┘         └──────────────────────┘
```

Ambos mundos consumen **el mismo core** (`i18n-orchestrator`). La diferencia es solo el transporte: socket JSON-RPC para clientes remotos, invocación de proceso (o dependencia de crate en proceso) para código interno del propio VPS.

---

## §3 Mundo 1 — UI remota (sin cambios de fondo respecto al mecanismo real de bi18n)

### 3.1 Métodos JSON-RPC relevantes (ya definidos en 1.01 §8, reconfirmados aquí)

| Método | Uso desde UI | Fase |
|---|---|---|
| `bi18n.attr.pipeline` | Validación + formato + máscara completos, en `on_blur`/`on_submit` | 7 |
| `bi18n.format.date` / `bi18n.format.number` / `bi18n.format.money` | Formateo puntual sin validar | 1 |
| `bi18n.validate.national_id` / `bi18n.validate.phone` / `bi18n.validate.email` | Validaciones puntuales | 1/4 |
| `bi18n.mask.value` / `bi18n.mask.pii` | Enmascarado puntual | 1 |
| `bi18n.locale.resolve` | Resolver locale/país/tz efectivo del tenant al abrir un formulario | 1 |
| `bi18n.enum.display` | Traducción de enums de negocio | 2 |

### 3.2 Método adicional propuesto: `bi18n.attr.config` (config liviana sin ejecutar validate)

**Justificación:** `bi18n.attr.pipeline` ejecuta las 4 etapas completas (validate→transform→format→mask). Para UX en vivo (mostrar la máscara de entrada apenas se abre el formulario, antes de que el usuario escriba nada) no tiene sentido pagar el costo de validar un valor vacío. Se propone un método liviano que devuelva solo lo necesario para configurar el widget cliente:

```json
→ {"jsonrpc":"2.0","id":1,"method":"bi18n.attr.config","params":{
    "display_format":"ID_BO","locale":"es-BO","country":"bo"}}

← {"jsonrpc":"2.0","result":{
    "mask_pattern":"9999999-AA",
    "display_format":"ID_BO",
    "masks_pii":true
    },"id":1}
```

Esto se pide **una vez** al abrir el formulario (o en batch para todos los campos, ver 3.3), no por tecla. El `mask_pattern` es el resultado exacto del mecanismo CLDR→máscara de 1.01 §7.2 — no una convención distinta.

**Este método debe agregarse al roadmap de bi18n (Fase 1 o 7, a decidir) si no existe ya como parte interna de `AttrBuilder` expuesta de forma independiente.**

### 3.3 Método batch: `bi18n.attr.config_batch` (opcional, recomendado)

Para minimizar round-trips al abrir un formulario con múltiples campos:

```json
→ {"method":"bi18n.attr.config_batch","params":{
    "fields":[
      {"key":"CI","display_format":"ID_BO"},
      {"key":"phone","display_format":"E164"},
      {"key":"birth_date","display_format":"DATE_ISO"}
    ],
    "locale":"es-BO","country":"bo"}}

← {"result":{"CI":{"mask_pattern":"9999999-AA",...},
             "phone":{"mask_pattern":"+999 99 9999999",...},
             "birth_date":{"mask_pattern":"99/99/9999",...}}}
```

### 3.4 Trigger de validación desde el cliente (UX)

| Trigger | Método a invocar | Cuándo |
|---|---|---|
| Apertura de formulario | `bi18n.attr.config_batch` | Una vez, cachear localmente |
| `on_blur` de un campo | `bi18n.attr.pipeline` | Al perder foco, valor completo |
| `on_submit` | `bi18n.attr.pipeline` (siempre, sin excepción) | Revalidación final — autoridad definitiva |

**No existe modo `on_input`/composición en bi18n.** Cualquier campo que requiera feedback carácter-por-carácter fuera de este modelo (ej. fortaleza de contraseña) pertenece a otro componente (bAuth), fuera del alcance de este anexo.

### 3.5 Patrón adapter por plataforma cliente (aporte de este anexo, no cubierto en 1.01)

El manual 1.01 documenta cómo bi18n *genera* la máscara (CLDR→patrón). No documenta cómo cada plataforma la *consume*. Esa es la pieza que este anexo cubre — un adapter delgado, una vez por plataforma, sin lógica de negocio:

| Plataforma / framework | Mecanismo de máscara (consume `mask_pattern`, convención `9`=dígito, literal=resto) | Mecanismo de invocación async |
|---|---|---|
| Flutter — `shadcn_flutter` | `TextInputFormatter` custom que interpreta `9` como placeholder de dígito | `Validator<String>` con `FutureOr<String?> validate()` llamando `attr.pipeline` |
| Flutter — Material estándar | Mismo `TextInputFormatter` (reutilizable) | Validación manual vía `onChanged`/`FormFieldState` (Material no soporta validator async nativo) |
| Vue — PrimeVue | Directiva custom sobre `InputText` | Watcher con debounce + resolver async (VeeValidate/Zod custom resolver) |
| iOS / macOS — SwiftUI | `ViewModifier` custom o librería `InputMask` parametrizada | `Task` async en `onSubmit`/`onChange` |
| Android — Jetpack Compose | `VisualTransformation` custom | `LaunchedEffect` + `snapshotFlow` |
| Windows — WinUI/WPF | `MaskedTextBox.Mask` (soporte nativo de patrón similar) | `Task` async en `LostFocus` |
| Linux — GTK | `GtkEntry` + validación manual | Callback async sobre `notify::text` |

**Nota de corrección respecto a A.01 §2.6:** `rat-input` es un widget de **terminal** (ratatui/TUI) — no aplica a ninguna de las plataformas de la tabla anterior. Se recomienda reclasificar esa entrada en A.01 como "máscara de entrada para **TUI/CLI interactivo únicamente**" (útil si algún día bi18n o alguna herramienta interna tiene una interfaz de terminal interactiva), y dejar constancia explícita de que **no cubre** el requisito de máscaras para los frontends de UI real (web/Flutter/nativos). Esa cobertura la resuelve el adapter por plataforma de esta tabla, no una librería Rust adicional.

---

## §4 Mundo 2 — CLI interno (`i18nctl`)

### 4.1 Propósito

`i18nctl` ya está declarado en el manual 1.01 (Fase 5, `src/bin/i18nctl.rs` — "mismo core, sin socket"). Este anexo especifica su superficie de comandos para cubrir el caso de **validaciones por código**: scripts de shell, jobs de migración de datos, hooks de CI/CD, validación ad-hoc en operaciones, y llamadas desde otros daemons SBOS que corren en el mismo host y prefieren invocación de proceso (o dependencia directa del crate) en vez de round-trip por socket.

### 4.2 Dos formas de consumo interno

| Forma | Cuándo usarla | Costo |
|---|---|---|
| **Binario `i18nctl`** (subprocess) | Scripts bash, jobs cron, hooks de CI/CD, operaciones manuales, herramientas que no están escritas en Rust | Overhead de fork/exec — aceptable para uso no interactivo/no masivo |
| **Dependencia directa del crate `i18n-orchestrator`** | Otro daemon Rust de SBOS (ej. `btax` validando un NIT antes de guardar una factura) que corre en el mismo binario/proceso o como librería local | Cero overhead de IPC — llamada de función en proceso |

**Recomendación:** para *otros daemons Rust* de SBOS que necesiten validar/formatear con alta frecuencia (ej. `btax` en cada factura), preferir la dependencia directa del crate sobre invocar el binario `i18nctl` como subproceso. El binario `i18nctl` se reserva para scripts, operaciones y herramientas no-Rust. Esta decisión debe confirmarse explícitamente por componente y documentarse en el manual de cada daemon consumidor.

### 4.3 Superficie de comandos propuesta (mapeo 1:1 con los métodos JSON-RPC de 1.01 §8)

```
i18nctl attr pipeline \
  --key CI \
  --value "7654321-lp" \
  --validate ID_BO \
  --transform uppercase,strip_hyphen \
  --format ID_BO \
  --mask partial:4 \
  --country bo \
  [--json]

i18nctl attr config \
  --display-format ID_BO \
  --locale es-BO \
  --country bo \
  [--json]

i18nctl format date    --value "2026-07-16T05:00:00Z" --locale es-BO --granularity date
i18nctl format number  --value 1500.5 --locale es-BO
i18nctl format money   --value 1500.50 --currency BOB --locale es-BO

i18nctl validate national-id --country bo --kind ci  --value "7654321-LP"
i18nctl validate phone       --value "+59171234567"
i18nctl validate email       --value "usuario@dominio.com"

i18nctl mask value --value "7654321-LP" --strategy partial:4
i18nctl mask pii   --value "usuario@dominio.com" --kind email

i18nctl locale resolve --tenant acme-sa [--branch la-paz] [--user u123]
i18nctl enum display    --domain gender --key M --locale es-BO

i18nctl health check
```

### 4.4 Formatos de salida

| Flag | Salida | Uso previsto |
|---|---|---|
| (default) | Tabla legible en terminal (formato humano) | Uso interactivo/operación manual |
| `--json` | JSON de una línea, mismo shape que el `result` de JSON-RPC | Scripts, parsing programático, integración con otros lenguajes |
| `--quiet` | Solo exit code, sin stdout | Gating en CI/CD (`if i18nctl validate national-id ... --quiet; then`) |

### 4.5 Convención de exit codes (para scripting y CI/CD)

| Código | Significado |
|---|---|
| `0` | Válido / operación exitosa |
| `1` | Valor inválido (falla de validación, no error de sistema) |
| `2` | Error de argumentos (uso incorrecto del CLI) |
| `3` | Error de sistema (país sin `country-rules/*.toml`, fallo de I/O, etc.) |

Esta convención permite usar `i18nctl` directamente como gate en pipelines de CI/CD o scripts de migración de datos:

```bash
if ! i18nctl validate national-id --country bo --kind nit --value "$NIT" --quiet; then
  echo "NIT inválido en fila $LINE" >&2
  exit 1
fi
```

### 4.6 Modo batch/pipe (recomendado para migraciones masivas)

Para validar grandes volúmenes de datos (ej. migración de una base legada) sin overhead de fork/exec por fila:

```bash
cat nits_a_validar.csv | i18nctl attr pipeline --stdin --format-code TAX_BO --json > resultados.jsonl
```

Cada línea de entrada produce una línea de salida JSON (`AttrResult`), permitiendo procesamiento en streaming con herramientas estándar de Unix (`jq`, `awk`, etc.).

**Este modo no está en el roadmap actual (1.01 §9) y debe agregarse explícitamente a la Fase 5 si se confirma la necesidad de migraciones masivas.**

---

## §5 Resumen de responsabilidades por interfaz

| Responsabilidad | JSON-RPC (UI remota) | CLI (`i18nctl`, código interno) |
|---|---|---|
| Transporte | Unix socket, JSON-RPC 2.0 | Subprocess / crate directo |
| Consumidor típico | Widgets de formulario en cualquier frontend | Scripts, jobs, otros daemons SBOS, CI/CD |
| Frecuencia esperada | Por interacción de usuario (blur/submit) | Batch / puntual / en proceso |
| Config liviana sin validar | `bi18n.attr.config[_batch]` | `i18nctl attr config` |
| Pipeline completo | `bi18n.attr.pipeline` | `i18nctl attr pipeline` (o dependencia directa del crate desde otro daemon Rust) |
| Autoridad final del dato | Siempre el daemon, nunca el cliente | Siempre el daemon/core, nunca el script llamador |

---

## §6 Pendientes derivados de este anexo

- [ ] Confirmar si `bi18n.attr.config` / `attr.config_batch` se agrega como método nuevo o si ya existe como capacidad interna de `AttrBuilder` sin exponer — de no existir, entra al roadmap (1.01 §9).
- [ ] Confirmar convención de exit codes de `i18nctl` con el resto de CLIs de SBOS (¿existe ya un estándar en otros daemons, ej. `bctl`, `bpayctl`?) para no introducir una convención distinta por componente.
- [ ] Decidir, por cada daemon Rust consumidor (btax, bpay, bcms, etc.), si usa el crate `i18n-orchestrator` en proceso o invoca `i18nctl`/socket — documentar la decisión en el manual de cada uno.
- [ ] Evaluar si el modo batch/pipe (§4.6) es necesario para el roadmap actual o se pospone a post-MVP.
- [ ] Corregir A.01 §2.6: reclasificar `rat-input` como cobertura exclusiva de TUI/CLI interactivo, no de UI de frontend.

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-16 | Anexo inicial. Corrige y reemplaza el documento de trabajo previo (ORQUESTA-048 v1). Alinea el mundo UI al contrato real de bi18n (CLDR→máscara, attr.pipeline, sin PASSWORD). Documenta el mundo CLI interno (i18nctl) con superficie de comandos, formatos de salida, exit codes y modo batch. |
