# A.08.18 — Inventario de Exposición: arc-swap 1.9.2

**Crate:** `arc-swap`
**Versión en Cargo.toml:** 1.9.2
**Archivo handler:** (infra interna — ya implementado en Fase 1)
**Categoría:** Infra interna — swap atómico de `Arc<T>` sin bloqueo (hot-reload de traducciones)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/arc-swap-1.9.2/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `ArcSwap<T>::new(arc)` / `.load()` / `.store(arc)` / `.swap(arc)` | — | — | ✅ Fase 1 (infra) |
| 2 | `ArcSwap<T>::rcu(f)` — read-copy-update | — | — | ✅ Fase 1 (infra) |
| 3 | `ArcSwap<T>::compare_and_swap(old, new)` | — | — | ✅ Fase 1 (infra) |
| 4 | `ArcSwap<T>::load_full()` → `Arc<T>` (sin Guard) | — | — | ✅ Fase 1 (infra) |
| 5 | `Guard<T,S>` — acceso temporal sin clonar Arc | — | — | ✅ Fase 1 (infra) |
| 6 | `Cache<A,T>::new(arc_swap)` / `.load()` / `.arc_swap()` | — | — | ❌ Infra interna |
| 7 | `ArcSwapOption<T>` — variante para `Arc<Option<T>>` | — | — | ❌ Infra interna |
| 8 | `ArcSwapWeak<T>` — variante con `Weak<T>` | — | — | ❌ Infra interna |
| 9 | `IndependentArcSwap<T>` — sin dependencias externas | — | — | ❌ Infra interna |
| 10 | `Access<T>` trait / `DynAccess<T>` / `Constant<T>` | — | — | ❌ Infra interna |
| 11 | `Map<A,T,F>` / `MapCache` | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- arc-swap es **infraestructura interna pura** — no genera ni generará métodos RPC.
- Ya implementado en Fase 1 (`c92e20b`): `ArcSwap<BundleFluent>` en `src/domain/translations.rs` para hot-reload atómico de bundles Fluent sin bloquear lectores.
- El método RPC `bi18n.admin.reload_translations` (ya implementado) usa `translations.store(Arc::new(nuevo_bundle))` internamente — es la única interfaz pública que expone el resultado del swap.
- `Cache<A,T>` marcado ❌ en esta fase: útil para lectores frecuentes que cachean la generación del Guard — candidato si hay problemas de contención en el futuro.

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md (arc-swap — ya implementado Fase 1) · src/domain/translations.rs · commit `c92e20b`*
