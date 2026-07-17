# A.08.12 — Inventario de Exposición: regex 1.13.1

**Crate:** `regex`
**Versión en Cargo.toml:** 1.13.1
**Archivo handler:** `src/server/handlers/lib_regex.rs`
**Categoría:** Expresiones regulares — motor NFA sin backtracking catastrófico
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/regex-1.13.1/src/`

---

## Inventario completo de exposición

### Struct `Regex`

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `Regex::new(pat)?.is_match(text)` | `bi18n.text.regex_match` | 2 | 📋 Fase 2 |
| 2 | `re.captures(text)` → grupos nombrados | `bi18n.text.regex_extract` | 2 | 📋 Fase 2 |
| 3 | `re.find_iter(text).collect()` | `bi18n.text.regex_extract_all` | 2 | 📋 Fase 2 |
| 4 | `re.replace_all(text, replacement)` / `re.replace(text, rep)` | `bi18n.text.regex_replace` | 2 | 📋 Fase 2 |
| 5 | `re.split(text).collect()` | `bi18n.text.regex_split` | 2 | 📋 Fase 2 |
| 6 | `re.is_match_at(text, start)` | — | — | 🔮 Futuro |
| 7 | `re.find(text)` → primera coincidencia | — | — | 🔮 Futuro |
| 8 | `re.find_at(text, start)` | — | — | 🔮 Futuro |
| 9 | `re.shortest_match(text)` | — | — | 🔮 Futuro |
| 10 | `re.captures_iter(text)` | — | — | 🔮 Futuro |
| 11 | `re.replacen(text, limit, rep)` | — | — | 🔮 Futuro |
| 12 | `re.splitn(text, limit)` | — | — | 🔮 Futuro |
| 13 | `re.capture_names()` | — | — | ❌ Infra interna |
| 14 | `re.captures_len()` / `static_captures_len()` | — | — | ❌ Infra interna |
| 15 | `re.as_str()` | — | — | ❌ Infra interna |

### Struct `RegexSet`

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 16 | `RegexSet::new(patterns)?.matches(text)` → índices que hicieron match | `bi18n.text.regex_match_set` | 2 | 📋 Fase 2 |
| 17 | `RegexSet::is_match(text)` | — | — | ❌ Infra interna |
| 18 | `RegexSet::len()` / `is_empty()` / `patterns()` | — | — | ❌ Infra interna |
| 19 | `RegexSet::matches_at(text, start)` | — | — | 🔮 Futuro |

### Struct `Match<'h>` y `Captures<'h>`

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 20 | `caps.name("group")` / `caps.get(i)` / `caps.extract::<N>()` | — | — | ❌ Infra interna |
| 21 | `m.start()` / `m.end()` / `m.as_str()` / `m.range()` | — | — | ❌ Infra interna |
| 22 | `caps.expand(replacement, dst)` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- `bi18n.text.regex_match` acepta `case_insensitive?: false` — el handler construye `RegexBuilder::new(pat).case_insensitive(true).build()` cuando se activa.
- `bi18n.text.regex_extract` retorna `{"groups": {"year": "2026", "month": "07"}, "full": "2026-07"}` — los grupos son nombrados via `(?P<name>...)`.
- `bi18n.text.regex_extract_all` retorna `{"matches": ["...", "..."]}` — todas las coincidencias del patrón en el texto.
- `bi18n.text.regex_replace` acepta `all?: true` (default) para `replace_all`, `false` para `replace` (solo primera ocurrencia).
- `bi18n.text.regex_match_set` retorna `{"any": bool, "matched_indices": [0, 2]}` — qué patrones del set hicieron match.
- Los handlers deben **cachear** los `Regex` compilados por patrón (thread-local o DashMap) — compilar un regex es costoso, aplicarlo es O(n).

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md Bloque M · src/server/handlers/lib_regex.rs*
