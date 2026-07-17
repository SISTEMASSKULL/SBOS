# A.06 — bi18n como Daemon Oficial de Traducciones: Edición y Actualización sin Fricción

**Tipo:** G — guía de implementación, ejecutable ahora
**Versión del anexo:** 1.1.0
**Fecha:** 2026-07-16
**Respalda a:** [1.01 (bi18n Arquitectura)](../1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) · [A.05 (Cierre de gaps)](A.05_ANEXO-BI18N-CIERRE-GAPS-v1.0.md)

---

## §1 El problema real

Editar `translations/*.toml`/`.ftl` a mano y redeployar para que un texto cambie tiene dos
fricciones separadas que hay que resolver por separado:

1. **Edición:** un cambio de texto lo termina haciendo un desarrollador editando un archivo,
   no la persona de negocio que sabe cómo debería decir el mensaje.
2. **Publicación:** aunque el archivo se edite fácil, hoy el cambio no es visible hasta el
   próximo redeploy del daemon.

Se resuelven con dos piezas independientes: una **plataforma de edición** (reemplaza el
"editar TOML a mano") y un **hot-reload en bi18nd** (reemplaza el "redeploy para que se note").

---

## §2 Plataforma de edición — Weblate, self-hosteado

Investigué las dos opciones open source maduras para esto: **Weblate** y **Tolgee**.

| | Weblate | Tolgee |
|---|---|---|
| Madurez | 14 años, usado por Debian, Fedora, LibreOffice | 6 años, más nuevo |
| Integración | Git nativo — el traductor edita en la web, Weblate commitea automáticamente al repo | También self-hosteable, integra CI/CD |
| Licencia self-hosted | GPLv3+, sin límite de proyectos/usuarios | Free tier limitado a 500 claves — revisar precio del tier self-hosted antes de escalar |
| Diferencial | Integración VCS más directa, checks de calidad, glosario incorporado | Edición *in-context*: alguien de negocio hace clic sobre el texto dentro de la app corriendo y lo edita ahí mismo |

**Recomendación para SBOS:** **Weblate**, por el modelo de licencia sin límites (relevante para
un ERP con muchos módulos y países) y porque tu flujo ya es Git-céntrico (CI/CD con GitHub
Actions). Tolgee queda como opción a evaluar después específicamente para las pantallas donde
el equipo de negocio quiera editar mirando la app en vivo — no es necesario para resolver el
problema ahora.

**Despliegue:** Weblate se levanta con Docker Compose (3 contenedores: la app, PostgreSQL,
Redis-compatible) — en tu VPS de STAGING o uno dedicado, apuntando al repo donde ya viven
`translations/` y `country-rules/` (o solo `translations/`, ver gobernanza en §5).

---

## §3 Flujo completo

```
1. Persona de negocio entra a Weblate (web UI), busca la clave "factura.monto.error_negativo"
2. Edita el texto en es-BO, pt-BR, lo que corresponda — sin tocar TOML/Fluent a mano
3. Weblate commitea el cambio directo al repo (rama de traducciones o main, según política)
4. CI corre el check de paridad de claves (ya definido en A.05 §3) sobre ese commit
5. Si pasa CI → merge (automático o con aprobación liviana, ver §5)
6. Pipeline de deploy sincroniza translations/ actualizado al path que lee bi18nd en el VPS
7. Pipeline llama a bi18n.admin.reload_translations (RPC nuevo, ver §4)
8. bi18nd recarga en memoria sin reiniciar — el texto está disponible en segundos,
   sin redeploy del binario, sin downtime
```

---

## §4 Hot-reload en bi18nd — técnica exacta

**Problema a evitar:** si el reload lee el archivo mientras se está escribiendo a mitad de un
`rsync`, un lector podría ver un TOML corrupto a medio escribir.

**Técnica: `arc-swap` (crate real, ampliamente usado — 143M+ descargas, el estándar de facto
para este problema en Rust) en vez de `RwLock`.**

- Las traducciones en memoria viven detrás de un `ArcSwap<Translations>`.
- Los requests de lectura (`attr.pipeline`, `enum.display`, etc.) hacen `load()` — sin bloqueo,
  sin contención, cada request ve una versión consistente completa (nunca un estado a medio
  reconstruir).
- El reload construye la estructura `Translations` **completa** en memoria a partir de los
  archivos en disco, y recién cuando terminó de construirla exitosamente hace `store()` —
  swap atómico de la versión vieja por la nueva. Si el parseo falla a mitad de camino, la
  versión vieja sigue sirviendo tráfico; nunca hay un estado intermedio visible.

**Disparo del reload — dos mecanismos, no mutuamente excluyentes:**

| Mecanismo | Cuándo usarlo |
|---|---|
| **RPC explícito** `bi18n.admin.reload_translations`, llamado por el pipeline de CI/deploy justo después de sincronizar los archivos | Determinista, es el disparador primario — se sabe exactamente cuándo ocurre |
| **File watcher con `notify`** (crate estándar del ecosistema, usado por rust-analyzer, deno, mdBook, etc.) sobre el directorio de traducciones | Red de seguridad — cubre el caso de que alguien actualice los archivos por fuera del pipeline (ej. debugging manual en el VPS) |

El RPC es el mecanismo principal porque es determinista; el watcher es un respaldo, no el
disparador de producción.

**Este RPC debe agregarse al catálogo de A.02 §4.3, restringido a llamadas internas** (no
expuesto en la ruta pública de Kong que usan los frontends — solo accesible desde el pipeline
de CI/deploy o el socket Unix local).

---

## §5 Ajuste de gobernanza (reconcilia con A.05 §2)

A.05 §2 puso `CODEOWNERS` + aprobación obligatoria sobre **todo** `country-rules/` y
`translations/` por igual. Con Weblate en el medio, conviene separar el riesgo real:

| Contenido | Riesgo | Política |
|---|---|---|
| `country-rules/*.toml` (regex de validación fiscal/legal) | Alto — un regex mal cambiado puede aceptar/rechazar documentos fiscales inválidos | Mantiene aprobación obligatoria de `CODEOWNERS` (sin cambios respecto a A.05 §2) |
| `translations/*.ftl`/`.toml` (textos de UI, `enum_display`) | Bajo — es texto de presentación | Puede fluir de Weblate a `main` con solo el gate de CI de paridad de claves (A.05 §3), **sin aprobación humana obligatoria** — el costo de un typo es mínimo y corregirlo es igual de rápido que aprobarlo |

Esto es lo que realmente destraba la fricción: la gobernanza pesada se queda donde el riesgo
es real (reglas fiscales), no en cada texto de botón.

---

## §6 Orden de ejecución

1. Levantar Weblate en Docker en un VPS (STAGING sirve para el piloto), conectado al repo
   donde vive `translations/`.
2. Implementar `bi18n.admin.reload_translations` en bi18nd usando `ArcSwap<Translations>`
   (reemplaza cualquier `RwLock` que hoy envuelva las traducciones en memoria, si existe).
3. Agregar el paso de CI que llama a ese RPC después de sincronizar archivos al VPS
   (mismo pipeline donde ya corre el check de paridad de A.05 §3). **Si `bi18nd` corre en
   más de una réplica (A.05 §4), este paso debe llamar al RPC contra cada instancia por
   separado — nunca solo a través de la ruta balanceada de Kong**, o las réplicas quedan
   con traducciones desincronizadas entre sí hasta su próximo reinicio.
4. Ajustar `CODEOWNERS` para que **no** exija aprobación en `translations/`, solo en
   `country-rules/` (§5).
5. Migrar las claves existentes de `translations/` a Weblate (import inicial, una vez).

---

## §7 Checklist de hecho

- [ ] Weblate corriendo, con al menos un usuario de negocio (no desarrollador) editando una
      clave real de principio a fin sin tocar Git ni TOML directamente.
- [ ] `bi18n.admin.reload_translations` implementado con `ArcSwap`, probado con recarga en
      caliente mientras hay requests concurrentes en curso (sin errores ni estado corrupto).
- [ ] El ciclo completo (editar en Weblate → commit → CI → deploy → reload) medido de punta
      a punta — debería ser minutos, no un ciclo de release.
- [ ] Si `bi18nd` corre en más de una réplica, el reload se confirma en **todas**, no solo en una.
- [ ] `CODEOWNERS` diferenciando `country-rules/` (con aprobación) de `translations/` (sin
      aprobación obligatoria, solo gate de CI).

---

## Historial

| Versión | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-16 | Anexo inicial. Investigación de Weblate vs Tolgee (recomendado: Weblate, self-hosted, sin límite de licencia). Técnica de hot-reload con `arc-swap` (crate real verificado, patrón de swap atómico sin bloqueo) + `notify` como watcher de respaldo. Nuevo RPC `bi18n.admin.reload_translations`. Ajuste de gobernanza: `translations/` se libera de aprobación obligatoria, `country-rules/` la mantiene. |
| 1.1.0 | 2026-07-16 | Reconciliado con A.05 §4 (HA): el RPC de recarga debe llamarse contra cada réplica de `bi18nd` individualmente, no a través de la ruta balanceada de Kong, o las réplicas quedan desincronizadas entre sí. |
