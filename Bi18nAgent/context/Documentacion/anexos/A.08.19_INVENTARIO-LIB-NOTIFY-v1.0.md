# A.08.19 — Inventario de Exposición: notify 6.1.1

**Crate:** `notify`
**Versión en Cargo.toml:** 6.1.1
**Archivo handler:** (infra interna — ya implementado en Fase 1)
**Categoría:** Infra interna — vigilancia de archivos del sistema (inotify/FSEvents/kqueue)
**Fuente verificada:** `~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/notify-6.1.1/src/`

---

## Inventario completo de exposición

| # | Función / Tipo fuente | Método RPC `bi18n.*` | Fase | Estado |
|---|----------------------|----------------------|------|--------|
| 1 | `recommended_watcher(handler)` → `impl Watcher` | — | — | ✅ Fase 1 (infra) |
| 2 | `Watcher::watch(path, RecursiveMode)` | — | — | ✅ Fase 1 (infra) |
| 3 | `Watcher::unwatch(path)` | — | — | ✅ Fase 1 (infra) |
| 4 | `Config::with_poll_interval(Duration)` | — | — | ✅ Fase 1 (infra) |
| 5 | `Config::with_compare_contents(bool)` | — | — | ❌ Infra interna |
| 6 | `Config::with_manual_polling(bool)` | — | — | ❌ Infra interna |
| 7 | `RecursiveMode::Recursive` / `NonRecursive` | — | — | ✅ Fase 1 (infra) |
| 8 | `trait EventHandler` — callback de eventos | — | — | ✅ Fase 1 (infra) |
| 9 | `Event` — tipo base de evento con kind, paths, attrs | — | — | ✅ Fase 1 (infra) |
| 10 | `EventKind` hierarchy — AccessKind, CreateKind, ModifyKind, RemoveKind | — | — | ✅ Fase 1 (infra) |
| 11 | `EventAttributes` — tracker, flag, info, source | — | — | ❌ Infra interna |
| 12 | `ErrorKind` enum — errores del watcher | — | — | ❌ Infra interna |

**Leyenda:**
- ✅ Implementado — en producción con commit
- 📋 Fase 2 — planificado, pendiente de implementación
- 🔮 Futuro — disponible en la librería, no en plan actual
- ❌ Infra interna — no se expone por RPC

---

## Notas de implementación

- notify es **infraestructura interna pura** — no genera ni generará métodos RPC.
- Ya implementado en Fase 1 (`c92e20b`): `src/domain/file_watcher.rs` vigila `locales/*/main.ftl` con inotify; ante cambio en `ModifyKind::Data` dispara recarga del bundle y swap atómico via ArcSwap (<100ms).
- El método RPC `bi18n.admin.reload_translations` (SIGHUP + RPC) es la interfaz pública — notify es el mecanismo automático que lo dispara sin intervención humana.
- `with_compare_contents` y `with_manual_polling` son útiles para sistemas de archivos remotos (NFS, FUSE) — no necesarios en el entorno SBOS (disco local).

---

*Fuente: MANUAL-METODOS-LIBRERIAS-SBOS.md v3.0.0 · Verificado desde `~/.cargo/registry/src/`*
*Relacionado: REGISTRO-ESTADO-DOS.md (notify — ya implementado Fase 1) · src/domain/file_watcher.rs · commit `c92e20b`*
