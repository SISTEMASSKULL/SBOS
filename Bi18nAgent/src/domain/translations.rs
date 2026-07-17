/// domain/translations.rs — Contenedor de traducciones Fluent con swap atómico (Bloque 11.2).
/// Propósito: envuelve un FluentBundle detrás de ArcSwap para recarga sin bloqueo de lectores.
///   - cargar() → Guard: puntero al bundle activo, O(1), sin lock de escritura.
///   - intercambiar(nuevo): reemplaza el bundle atómicamente tras construirlo completo en memoria.
///   - Si la construcción del nuevo bundle falla, el anterior sigue sirviendo (rollback implícito).
/// Dependencias: arc-swap, fluent-bundle (concurrent)
use arc_swap::ArcSwap;
use fluent_bundle::{concurrent::FluentBundle, FluentResource};
use std::sync::Arc;

/// Bundle Fluent thread-safe — variante concurrent (IntlLangMemoizer Send+Sync).
pub type BundleFluent = FluentBundle<FluentResource>;

/// Contenedor de traducciones con swap atómico de baja latencia.
/// No bloquea lectores en curso durante el swap — es seguro bajo alta concurrencia.
pub struct TranslationsBundle {
    inner: ArcSwap<BundleFluent>,
}

impl TranslationsBundle {
    /// Crea el contenedor con el bundle inicial.
    pub fn nuevo(bundle: BundleFluent) -> Self {
        Self { inner: ArcSwap::new(Arc::new(bundle)) }
    }

    /// Accede al bundle activo sin bloqueo.
    /// El Guard mantiene una referencia al Arc actual — libera automáticamente al salir de scope.
    pub fn cargar(&self) -> arc_swap::Guard<Arc<BundleFluent>> {
        self.inner.load()
    }

    /// Reemplaza el bundle atómicamente.
    /// DEBE llamarse SOLO después de construir el nuevo bundle completo (patrón build-then-swap).
    /// Los lectores que ya tienen un Guard siguen usando el bundle anterior hasta soltarlo.
    pub fn intercambiar(&self, nuevo: BundleFluent) {
        self.inner.store(Arc::new(nuevo));
    }
}
