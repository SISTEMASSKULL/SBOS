# Gaps de bi18n — decisiones de diseño

**Versión:** 2.0.0
**Fecha:** 2026-07-16

Las librerías cubren el 100% de las necesidades (A.01 v2.1.0). Estos gaps no son de librería
faltante — son decisiones de arquitectura e integración. **Todos los gaps están RESUELTOS** a
partir de la versión 2.0.0.

---

## GAP-01 — ¿De dónde obtiene bi18n el RegionalConfig del tenant?

**Estado:** ✅ RESUELTO — 2026-07-16

### Contexto original

El diseño canónico §10.3 define el trait `RegionalConfigResolver` pero no prescribe dónde se
persiste la configuración. El manual §5.2 asume que bAuth envía `locale`/`timezone`/`currency`/
`country` en cada request, pero bAuth aún no tiene implementada esa resolución desde `idn_tenant`.
Esto impedía implementar `bi18n.locale.resolve` y el pipeline multi-tenant.

### Decisión aprobada

**Dos fases con el mismo contrato de código:**

- **MVP (inmediato):** `StaticRegionalConfigResolver` — lee tenants de `bi18n.toml` al iniciar.
- **Producción (cuando bAuth esté listo):** `RequestBoundRegionalConfigResolver` — el cliente
  envía `regional_config` directamente en cada llamada JSON-RPC. bi18n nunca consulta la BD.

### Resolución técnica

#### 1. Struct `RegionalConfig` (módulo `locale/types.rs`)

```rust
/// Configuración regional resuelta para una operación concreta.
/// Se recibe de bAuth (producción) o se carga de bi18n.toml (MVP).
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct RegionalConfig {
    /// Locale BCP 47 validado. Ej: "es-BO", "en-US", "pt-BR".
    pub locale: String,
    /// Zona horaria IANA. Ej: "America/La_Paz".
    pub timezone: String,
    /// ISO 4217 de la moneda del tenant. Ej: "BOB", "USD", "ARS".
    pub currency: String,
    /// ISO 3166-1 alpha-2 del país del tenant. Ej: "BO", "AR", "BR".
    pub country: String,
}
```

#### 2. Trait `RegionalConfigResolver` (módulo `locale/resolver.rs`)

```rust
/// Contrato para resolver la configuración regional de un tenant.
/// El caller (MVP: archivo TOML; producción: request JSON-RPC) es transparente al resto del sistema.
#[async_trait]
pub trait RegionalConfigResolver: Send + Sync {
    async fn resolve(
        &self,
        tenant_id: &str,
        branch_id: Option<&str>,
        user_id: Option<&str>,
    ) -> Result<RegionalConfig, Bi18nError>;
}
```

#### 3. `StaticRegionalConfigResolver` (MVP — módulo `locale/resolver.rs`)

```rust
/// Resolución estática desde bi18n.toml — úsese solo en MVP y pruebas.
pub struct StaticRegionalConfigResolver {
    tenants: HashMap<String, RegionalConfig>,
    default: RegionalConfig,
}
```

Cargado en `preflight.rs` desde `/etc/bos/bi18n.toml` con la sección:

```toml
[default_tenant]
locale    = "es-BO"
timezone  = "America/La_Paz"
currency  = "BOB"
country   = "BO"

[tenants.acme-sa]
locale    = "es-BO"
timezone  = "America/La_Paz"
currency  = "BOB"
country   = "BO"

[tenants.global-corp]
locale    = "en-US"
timezone  = "America/New_York"
currency  = "USD"
country   = "US"
```

#### 4. `RequestBoundRegionalConfigResolver` (producción — mismo módulo)

Cuando bAuth tenga implementada la resolución desde `idn_tenant`, envía el campo
`regional_config` en cada request JSON-RPC. El handler lo deserializa y lo inyecta
directamente al pipeline — el trait no cambia:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "bi18n.attr.pipeline",
  "params": {
    "key": "CI",
    "value": "7654321-lp",
    "regional_config": {
      "locale": "es-BO",
      "timezone": "America/La_Paz",
      "currency": "BOB",
      "country": "BO"
    },
    ...
  }
}
```

El handler lo convierte a `RegionalConfig` y llama al mismo pipeline — ningún cambio de lógica.

#### 5. Jerarquía de resolución en el handler

```rust
// En server/handlers/attr_pipeline.rs
let regional_config = match params.regional_config {
    // Producción: bAuth envió la config → usarla directamente
    Some(rc) => rc,
    // MVP: fallback al resolver estático desde bi18n.toml
    None => ctx.resolver.resolve(
        &params.tenant_id.unwrap_or_default(),
        params.branch_id.as_deref(),
        params.user_id.as_deref(),
    ).await?,
};
```

#### 6. Impacto en Cargo.toml

**Ninguno adicional.** El MVP no requiere `sqlx` ni driver de BD. `toml` ya está en el stack.

#### 7. Ruta de migración

| Etapa | Quién lo resuelve | Cambio en bi18n |
|---|---|---|
| MVP | bi18n lee `bi18n.toml` | `StaticRegionalConfigResolver` activo |
| bAuth implementa `idn_tenant` | bAuth envía `regional_config` en cada request | El handler ya lo soporta (ver punto 4) |
| Estabilización | Se retira `StaticRegionalConfigResolver` | Eliminar la sección `[tenants.*]` de `bi18n.toml` |

---

## GAP-02 — ¿bi18n se conecta a PostgreSQL para bglobal?

**Estado:** ✅ RESUELTO — 2026-07-16

### Contexto original

El anexo A.01 §2.8 listaba 4 tablas de `bglobal` (PostgreSQL) como fuente de datos de monedas,
países, idiomas y zonas horarias. El manual §2.2 afirmaba que bi18n "no requiere PostgreSQL —
es stateless". Ambas afirmaciones eran contradictorias: no se puede ser stateless y depender
de BD al mismo tiempo.

### Decisión aprobada

**bi18n NO se conecta a PostgreSQL.** Los datos de referencia de país/moneda/idioma que bi18n
necesita operacionalmente se declaran en `country-rules/{iso}.toml` — archivos en disco que se
cargan al iniciar. `bglobal` sigue siendo el catálogo maestro del ecosistema SBOS, pero bi18n
lo consume de forma indirecta: los administradores exportan los datos relevantes a TOML cuando
se da de alta un nuevo país. bi18n es **genuinamente stateless**.

### Resolución técnica

#### 1. Sección `[currency]` en cada `country-rules/{iso}.toml`

```toml
# country-rules/bo.toml — Bolivia
[currency]
iso4217        = "BOB"
symbol_local   = "Bs."
symbol_intl    = "BOB"
decimal_places = 2
decimal_sep    = ","      # separador decimal local
thousands_sep  = "."      # separador de miles local
```

Esta sección responde exactamente a lo que `bglobal.global_currency` provee. Al dar de alta
un nuevo país, el administrador copia los valores de bglobal al TOML.

#### 2. Sección `[country]` complementaria en el TOML

```toml
[country]
iso_alpha2     = "BO"
iso_alpha3     = "BOL"
iso_numeric    = "068"
calling_code   = "+591"
default_locale = "es-BO"
default_tz     = "America/La_Paz"
ltr            = true     # dirección de escritura
```

#### 3. `CountryRulesLoader` — carga y caché (módulo `country/mod.rs`)

```rust
/// Caché thread-safe de reglas por país. Se carga al iniciar y se refresca en SIGHUP.
pub struct CountryRulesLoader {
    /// Mapa ISO-alpha2 → reglas. Arc permite compartir entre hilos sin clonar.
    rules: Arc<RwLock<HashMap<IsoAlpha2, CountryRules>>>,
    /// Directorio donde viven los archivos {iso}.toml.
    rules_dir: PathBuf,
}
```

`CountryRules` agrega todas las secciones del TOML:

```rust
pub struct CountryRules {
    pub country:     CountryMeta,      // [country]
    pub currency:    CurrencySpec,     // [currency]
    pub national_id: NationalIdMap,    // [national_id.*]
    pub postal:      PostalFormat,     // [postal]
    pub vehicle:     VehicleRules,     // [vehicle]
    pub synonyms:    SynonymMap,       // [synonyms]
    pub enum_display: EnumDisplayMap,  // [enum_display]
}
```

#### 4. Error cuando el país no está en TOML

```rust
pub enum Bi18nError {
    CountryRulesNotFound { country: IsoAlpha2 },
    // ...
}
```

bi18n NO silencia este error — lo propaga al caller con mensaje descriptivo en español:
`"Reglas de país no encontradas para '{country}'. Agregue country-rules/{country_lower}.toml."`.

#### 5. Impacto en Cargo.toml

**`sqlx` NO se agrega.** El stack de Cargo.toml no incluye ningún driver de BD para bi18n.
Se elimina la incertidumbre sobre si bi18n necesita una conexión a PostgreSQL en el preflight.

**Consecuencia en preflight:** el preflight de bi18n no valida conexión a BD. Solo valida:
- Directorio `country-rules/` existe y contiene al menos un `.toml` legible.
- `/etc/bos/bi18n.toml` existe y tiene la sección `[default_tenant]`.
- Socket `/run/bos/bi18n.sock` puede crearse con los permisos correctos.

#### 6. Relación con bglobal

| bglobal | Rol | Relación con bi18n |
|---|---|---|
| Catálogo maestro del ecosistema SBOS | Persiste 196 países, 143 monedas, 319 TZ, idiomas | bi18n NO lo consulta directamente |
| Fuente de verdad para administración | Alta de países nuevos, actualización de monedas | Los admins exportan a `country-rules/{iso}.toml` |
| Consumidor primario: bpay, btax, bcms | Datos financieros y fiscales en tiempo real | Esos daemons consultan bglobal directamente vía su propio JSON-RPC |

**bi18n consume un subconjunto declarativo y estático de bglobal** — el que corresponde a
los países que tiene tenants activos. No hay sincronización automática en tiempo real.

---

## GAP-03 — Recarga en caliente de country-rules TOML

**Estado:** ✅ RESUELTO — 2026-07-16

### Contexto original

Los TOML se cargan al iniciar. Si un administrador corrige un patrón de CI, agrega un país
nuevo o actualiza el símbolo de una moneda, el daemon debe recargarlos sin reinicio de servicio
(que implicaría rechazar todas las requests en vuelo).

### Decisión aprobada

**SIGHUP recarga todos los `country-rules/*.toml` de forma thread-safe**, con las siguientes
garantías: (1) ninguna request en vuelo se interrumpe, (2) la recarga es atómica (las
requests ven el estado anterior O el nuevo, nunca uno parcial), (3) si la recarga falla, el
daemon continúa con el estado anterior y registra el error.

Este es el mismo patrón que bAuth usa para recarga de config (ver `src/signal.rs`).

### Resolución técnica

#### 1. Registro del manejador de señal (módulo `signal.rs`)

```rust
/// Registra SIGHUP para recarga de country-rules. Se ejecuta en un tokio::spawn separado.
pub async fn manejar_sighup(loader: Arc<CountryRulesLoader>, activas: Arc<AtomicU64>) {
    let mut stream = tokio::signal::unix::signal(SignalKind::hangup())
        .expect("Error al registrar SIGHUP");

    loop {
        stream.recv().await;
        tracing::info!("SIGHUP recibido — iniciando recarga de country-rules");

        // Esperar a que no haya requests en vuelo (timeout de 5 s)
        let inicio = std::time::Instant::now();
        while activas.load(Ordering::Acquire) > 0 {
            if inicio.elapsed() > Duration::from_secs(5) {
                tracing::warn!("Recarga con requests en vuelo (timeout de drenaje)");
                break;
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }

        match loader.recargar().await {
            Ok(n) => tracing::info!("country-rules recargadas: {} países", n),
            Err(e) => tracing::error!("Error recargando country-rules: {} — estado anterior conservado", e),
        }
    }
}
```

#### 2. `CountryRulesLoader::recargar()` — atómico con `RwLock`

```rust
impl CountryRulesLoader {
    /// Recarga todos los TOML desde disco. Si alguno falla, NINGUNO se aplica.
    pub async fn recargar(&self) -> Result<usize, Bi18nError> {
        // 1. Leer todos los TOML en un nuevo HashMap (fuera del lock)
        let nuevo = Self::cargar_directorio(&self.rules_dir)?;
        let n = nuevo.len();

        // 2. Adquirir write lock solo para el swap — operación microsegundos
        *self.rules.write().await = nuevo;

        Ok(n)
    }
}
```

**Garantía de atomicidad:** las requests que lleguen durante la recarga obtienen el `read()`
lock y esperan microsegundos a que termine el write swap. No ven estado parcial.

**Garantía de rollback:** `cargar_directorio()` parsea todos los TOML antes de adquirir
el lock. Si alguno es inválido, devuelve `Err` y el lock nunca se toca.

#### 3. Configuración systemd para recarga operacional

En `/etc/systemd/system/bi18nd.service`:

```ini
[Service]
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
TimeoutStopSec=30
```

Recarga operacional: `systemctl reload bi18nd` (sin reinicio).

#### 4. Diferencia con `bi18n.rules.reload` (opción C descartada)

La opción C (método JSON-RPC) fue descartada porque requeriría autenticación del caller
para evitar que cualquier cliente del socket recargue arbitrariamente. SIGHUP es operado
exclusivamente por el sistema operativo (root o usuario `bos`), sin superficie de ataque
adicional.

---

## GAP-04 — ¿ICU4X 2.2 expone patrones CLDR como string?

**Estado:** ✅ RESUELTO — 2026-07-16

### Contexto original

El manual §7.2 describía un mecanismo donde ICU4X exponía el patrón CLDR crudo
(`dd/MM/yyyy`) para derivar la máscara de entrada (`99/99/9999`) carácter por carácter.
No estaba verificado que la API pública 2.2 de ICU4X expusiera esto — se asumía que sí.

### Decisión aprobada

**Los patrones de máscara de entrada se definen estáticamente en `format_map.rs`** para los
18 códigos `display_format`. ICU4X sigue usándose para **formatear valores** (fechas, números,
monedas), que es su API pública estable. Extraer el patrón CLDR crudo como string para
derivar máscaras requeriría acceso a APIs internas de ICU4X que son `pub(crate)` o inestables
— un acoplamiento frágil incompatible con las reglas de versionado semántico.

### Resolución técnica

#### 1. Verificación del estado de la API ICU4X 2.2

La API pública de `icu_datetime` 2.2 expone:
- `DateTimeFormatter::format(&self, datetime: &T) -> FormattedDateTime` — **formatea un valor**
- `DateTimeFormatter::format_to_string(&self, datetime: &T) -> String` — **formatea a string**

**No expone:**
- `DateTimeFormatter::pattern() -> &str` — acceso al patrón CLDR como string
- `DateTimeFormatter::skeleton() -> DateTimeSkeleton` — acceso al skeleton de CLDR

Los campos de patrón internos son `DataPayload<PatternPluralsFromPatternsV1Marker>` —
completamente interno, sin API pública estable documentada. Acoplarse a ellos violaría
semver y rompería en cualquier minor release de ICU4X.

#### 2. `FormatSpec` — registro estático (módulo `format/format_map.rs`)

```rust
/// Especificación completa de un código display_format.
#[derive(Debug, Clone)]
pub struct FormatSpec {
    /// Código canónico (18 valores). Ej: "DATE_ISO", "TAX_BO", "E164".
    pub code: &'static str,
    /// Máscara de entrada para frontend/TUI. Ej: "99/99/9999", "+999 99 9999999".
    /// Convención: '9' = dígito, 'A' = letra, '*' = cualquier carácter, literal = literal.
    pub input_mask: &'static str,
    /// Patrón de formato ICU4X (solo para DATE_* y MONEY). None si no aplica.
    pub icu_skeleton: Option<&'static str>,
    /// Estrategia de enmascaramiento PII por defecto para este código.
    pub pii_default: MaskStrategyDefault,
    /// Tipo de validación aplicable.
    pub validator: ValidatorKind,
}
```

#### 3. Tabla de 18 códigos con sus máscaras (compilada en `OnceLock`)

```rust
static FORMAT_MAP: OnceLock<HashMap<&'static str, FormatSpec>> = OnceLock::new();

pub fn obtener_formato(code: &str) -> Option<&'static FormatSpec> {
    FORMAT_MAP.get_or_init(init_format_map).get(code)
}

fn init_format_map() -> HashMap<&'static str, FormatSpec> {
    use MaskStrategyDefault::*;
    use ValidatorKind::*;
    [
        ("E164",          FormatSpec { code: "E164",          input_mask: "+999 99 9999999",      icu_skeleton: None,     pii_default: None,        validator: Phonenumber }),
        ("EMAIL_RFC5321", FormatSpec { code: "EMAIL_RFC5321", input_mask: "email",                icu_skeleton: None,     pii_default: None,        validator: Email }),
        ("TAX_BO",        FormatSpec { code: "TAX_BO",        input_mask: "9999-999999-999-99",   icu_skeleton: None,     pii_default: Partial(4),  validator: RegexCountry }),
        ("TAX_AR",        FormatSpec { code: "TAX_AR",        input_mask: "99-99999999-9",        icu_skeleton: None,     pii_default: Partial(4),  validator: RegexCountry }),
        ("TAX_BR_CPF",    FormatSpec { code: "TAX_BR_CPF",    input_mask: "999.999.999-99",       icu_skeleton: None,     pii_default: Partial(4),  validator: RegexCountry }),
        ("TAX_BR_CNPJ",   FormatSpec { code: "TAX_BR_CNPJ",   input_mask: "99.999.999/9999-99",   icu_skeleton: None,     pii_default: Partial(4),  validator: RegexCountry }),
        ("ID_BO",         FormatSpec { code: "ID_BO",         input_mask: "9999999-AA",           icu_skeleton: None,     pii_default: Partial(4),  validator: RegexCountry }),
        ("PASSPORT_ICAO", FormatSpec { code: "PASSPORT_ICAO", input_mask: "AA9999999",            icu_skeleton: None,     pii_default: Partial(4),  validator: RegexCountry }),
        ("IPV4",          FormatSpec { code: "IPV4",          input_mask: "999.999.999.999",      icu_skeleton: None,     pii_default: None,        validator: Regex }),
        ("ADDR_INTL",     FormatSpec { code: "ADDR_INTL",     input_mask: "multifield",           icu_skeleton: None,     pii_default: None,        validator: CountryPostal }),
        ("LOCALE_BCP47",  FormatSpec { code: "LOCALE_BCP47",  input_mask: "aa-AA",               icu_skeleton: None,     pii_default: None,        validator: Bcp47 }),
        ("TIMEZONE_IANA", FormatSpec { code: "TIMEZONE_IANA", input_mask: "text",                 icu_skeleton: None,     pii_default: None,        validator: IanaTimezone }),
        ("DATE_ISO",      FormatSpec { code: "DATE_ISO",      input_mask: "99/99/9999",           icu_skeleton: Some("yMd"),  pii_default: None,   validator: Iso8601 }),
        ("MONEY",         FormatSpec { code: "MONEY",         input_mask: "currency",             icu_skeleton: Some("ccy"), pii_default: None,    validator: Numeric }),
        ("COORDENADAS_DD",FormatSpec { code: "COORDENADAS_DD",input_mask: "-99.999999,-999.999999",icu_skeleton: None,    pii_default: None,        validator: CoordRange }),
        ("URL",           FormatSpec { code: "URL",           input_mask: "url",                  icu_skeleton: None,     pii_default: None,        validator: Url }),
        ("UUID",          FormatSpec { code: "UUID",          input_mask: "hex-36",               icu_skeleton: None,     pii_default: None,        validator: UuidFormat }),
        ("NULL",          FormatSpec { code: "NULL",          input_mask: "text",                 icu_skeleton: None,     pii_default: None,        validator: NoValidation }),
    ].into_iter().map(|(k, v)| (k, v)).collect()
}
```

#### 4. ICU4X sigue siendo la fuente de formato de valores

ICU4X se usa para lo que sí hace bien — **formatear valores concretos**:

| Uso | API ICU4X usada | Estable |
|---|---|---|
| Formatear fecha "16 de julio de 2026" | `DateTimeFormatter::format()` | ✅ Pública estable |
| Formatear número "1.500,50" | `FixedDecimalFormatter::format()` | ✅ Pública estable |
| Formatear moneda "Bs. 1.500,50" | `FixedDecimalFormatter::format()` + símbolo de TOML | ✅ Pública estable |
| **Extraer patrón CLDR crudo como string** | `DataPayload<PatternPluralsFromPatternsV1Marker>` | ❌ Interna — NO usar |

#### 5. Ruta de evolución (sin breaking changes)

Si en una versión futura de ICU4X (≥ 3.0) se expone una API pública estable para extraer
el skeleton/patrón como string, se puede:
1. Poblar `FormatSpec.input_mask` dinámicamente en `init_format_map()` para los códigos `DATE_*`
2. El campo `icu_skeleton: Option<&'static str>` ya está listo para ese caso
3. No cambia ninguna interfaz externa — el cliente sigue recibiendo `"99/99/9999"` como string

---

## Resumen ejecutivo de decisiones

| GAP | Decisión | Impacto en Cargo.toml | Módulo principal |
|---|---|---|---|
| GAP-01 | MVP: `bi18n.toml` estático → producción: bAuth envía `regional_config` en request | Sin cambios | `locale/resolver.rs` |
| GAP-02 | TOML locales por país en `country-rules/{iso}.toml` — sin PostgreSQL | **`sqlx` NO se agrega** | `country/mod.rs` |
| GAP-03 | SIGHUP recarga todos los TOML thread-safe con garantía de atomicidad y rollback | Sin cambios | `signal.rs` |
| GAP-04 | Patrones de máscara fijos en `format_map.rs` — ICU4X solo formatea valores | Sin cambios | `format/format_map.rs` |

**Consecuencia global:** bi18n es genuinamente stateless — no hay conexión a BD, no hay
estado global mutable entre requests (solo lectura del caché cargado al iniciar), y la única
mutación permitida es el swap atómico de `RwLock` en SIGHUP. El `Cargo.toml` no necesita
`sqlx`, `tokio-postgres` ni ningún driver de BD.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-16 | Documento inicial. 4 gaps identificados, sin resolver. |
| 2.0.0 | 2026-07-16 | Todos los gaps resueltos con evidencia técnica. Structs, traits y convenciones definidas. Impacto en Cargo.toml documentado. Rutas de migración y evolución incluidas. |
