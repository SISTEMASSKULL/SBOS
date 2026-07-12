# Anexo A.18 — El modelo de construcción del GUI/Frontend: decisión justificada, código real y divergencias
## Documento de respaldo de sustentación: Flutter desktop soberano — qué existe, qué diverge entre fuentes, qué falta

**Tipo:** ANEXO — respaldo de sustentación (tipo **C** justificación + **B** industria + **D** verificación de código)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-FRONTEND (2.11) · CLAUDE del daemon (§7 dashboard) · MANUAL-REFERENCIA-API (9.02 — el backend que consume)
**Verificación de código:** `src/bAuthDEV/` (646 líneas Dart, 8 archivos) + `pubspec.yaml` + `2.11 §3` + CLAUDE §7 — leída 2026-07-11
**Normas/base:** Flutter/Dart · WebSocket RFC 6455 · ADR-020 · WCAG 2.2 (accesibilidad) · responsive design

---

## 1. Propósito

Dar el modelo de construcción del frontend con sustentación completa y — lo más importante —
**exponer una divergencia crítica entre tres fuentes** sobre qué stack de UI usar, que hoy
bloquearía un desarrollo sin fricciones. **Cómo citarlo:** `A.18 §3` (la divergencia) · `A.18
§4` (código real).

## 2. La decisión de fondo justificada: Flutter desktop soberano (no web)

| Requisito | Por qué Flutter desktop |
|---|---|
| **Soberanía** (0.00 §5) | El Dashboard se **instala en la máquina del administrador**, no se sirve desde un servidor — coherente con "systemd en el host". Compila a binario nativo Linux/Windows/Mac |
| Interface Dual (ADR-020) | Consume el daemon por **WebSocket RPC** sobre el Unix socket — no HTTP; A.16 justifica el protocolo |
| Multiplataforma con una base | Flutter da las 6 plataformas desde un código; el CLAUDE §7 exige comportamiento idéntico en todas |
| Operación crítica | Un dashboard de control de seguridad prioriza densidad de información y estado de un vistazo (CLAUDE §7.5) |

**Contra la alternativa web:** una SPA servida exigiría un servidor HTTP (viola la superficie
mínima y la soberanía de "se instala, no se sirve"). Flutter Web queda como target adicional
opcional, no como la arquitectura.

## 3. ⚠️ DIVERGENCIA CRÍTICA — tres fuentes, tres stacks de UI (hallazgo que faltaba)

La verificación cruzada revela que **las tres fuentes del proyecto no coinciden en el stack de
componentes ni de estado** — una brecha que hay que resolver ANTES de escalar el frontend:

| Fuente | Componentes UI | Estado | Verificado |
|---|---|---|---|
| **CLAUDE del daemon §7** | **forUI** + Design System **Abyss** (Slate+Cyan) | — | doctrina del agente |
| **MANUAL-FRONTEND 2.11 §3** | **`tf_shadcn_flutter`** 0.0.53 + Design System **SBOS Dark** | **Riverpod** 2.6 | manual |
| **Código real `bAuthDEV/pubspec.yaml`** | **Material** (uses-material-design) — ni forUI ni shadcn | **`provider`** 6.1 — no Riverpod | `pubspec.yaml` |

**Tres nombres para el sistema de diseño** (forUI/Abyss vs tf_shadcn/SBOS Dark vs Material) y
**dos gestores de estado** (Riverpod declarado vs provider real). **Es la brecha P1 del
frontend:** ningún desarrollador puede continuar sin una decisión única. Recomendación (a
decidir HITL): **alinear las tres fuentes a lo que el código ya usa o migrar el código a lo que
el manual declara** — pero no dejar tres verdades. La más reciente y detallada (2.11 §3, con
`PLAN-DESKTOP-BAUTH.md` citado) sugiere que tf_shadcn+Riverpod+SBOS Dark es la dirección
querida; el CLAUDE §7 (forUI/Abyss) y el código (Material/provider) quedarían desactualizados.

### 3.1 ✅ RESOLUCIÓN (decisión del humano, 2026-07-12) — la divergencia P1 se cierra

La clave que disuelve el conflicto: **son DOS aplicaciones con propósitos muy diferentes**, no un
único frontend con tres stacks. Cada una tiene su stack justificado por su rol:

| App | Propósito | Stack definitivo |
|-----|-----------|------------------|
| **bAuth Desktop** | el **Dashboard producto** — el administrador gobierna bAuth (motores, roles, políticas, auditoría) | **Flutter desktop + `tf_shadcn_flutter` + Riverpod (scoped por módulo) + Design System SBOS Dark + WebSocket**. Se construye **limpio** (hoy solo existe la maqueta HTML) — dirección del manual 2.11. |
| **bAuthDEV** | el **RPC-tester** — herramienta interna para probar/desarrollar los métodos JSON-RPC del daemon | **se mantiene** en Material + `provider`. Su fin (probar RPC) es distinto del producto; no necesita el stack del Dashboard. |

- **`forUI` + `Abyss` (CLAUDE §7):** **descartado** — doctrina que nunca se materializó (no aparece
  ni en el manual ni en el código). El CLAUDE debe corregirse a `tf_shadcn`/SBOS Dark.
- **Resultado:** una sola verdad para el **producto** (bAuth Desktop) y una **herramienta** separada
  y justificada (bAuthDEV). La brecha **G1/P1 queda cerrada**; el frontend queda **desbloqueado**.

## 4. Lo que YA existe en código — verificado (`src/bAuthDEV/`, 646 líneas)

| Archivo | Líneas | Qué hace |
|---|:---:|---|
| `lib/main.dart` + `app.dart` | 86 | Entry point + shell de la app desktop (`window_manager`) |
| `lib/services/rpc_client.dart` | 90 | **Cliente WebSocket RPC hacia el daemon** — la conexión ADR-020 funciona |
| `lib/services/method_catalog.dart` | 126 | Catálogo de métodos (para invocar la superficie ≈151 de A.16) |
| `lib/widgets/cinta_bloques.dart` | 161 | Widget de bloques (visualización) |
| `lib/widgets/editor_rpc.dart` | 151 | **Editor de invocación RPC** — probar métodos del daemon |
| `lib/widgets/status_bar.dart` | 32 | Barra de estado |
| `lib/screens/catalogo/catalogo_screen.dart` | — | Pantalla de catálogo |
| Plataformas configuradas | — | **linux · macos · windows** (desktop); faltan android/ios/web |

**Veredicto:** existe un **prototipo desktop funcional** que ya conversa con el daemon por
WebSocket (rpc_client + editor_rpc) — es L1-L2 (0.00 §7). No es el Dashboard completo de 2.11:
es el andamiaje de conexión y prueba.

## 5. Lo que FALTA — específico, contra el manual y la industria

| # | Brecha | Qué exige 2.11 / la industria | Prioridad |
|---|---|---|:---:|
| **G1** | ✅ **RESUELTO (§3.1, 2026-07-12)** — dos apps, dos propósitos: **bAuth Desktop** (producto → tf_shadcn+Riverpod+SBOS Dark) · **bAuthDEV** (tester → Material/provider). forUI/Abyss descartado | Una sola verdad **por app** | ~~P1~~ **cerrado** |
| G2 | **Responsive de 3 rangos** (compacto/medio/expandido) — el código desktop no evidencia breakpoints | CLAUDE §7.2: layout por espacio disponible, no por plataforma | P1 |
| G3 | **Las 6 plataformas** — solo 3 desktop configuradas | CLAUDE §7.1: comportamiento idéntico en Windows/Linux/Mac/Web/Android/iOS | P2 |
| G4 | **Visualización del BitMask** (§8 árbol A.M.V, §9 widget de atributos) — no evidenciada en los 646 líneas | 2.11 §8-§9 · CLAUDE §7.6: representación compacta significativa del BitMask | P1 |
| G5 | **Design System como tokens** (SBOS Dark: variables de color/fuente/espacio) | 2.11 §4 (regla R1: todo es variable) | P2 |
| G6 | **Accesibilidad WCAG + i18n español** | 2.11 §10 · CLAUDE (español inmutable) | P2 |
| G7 | **State management scoped por módulo** — hoy `provider` global | 2.11 §3 (Riverpod scoped, evita rebuilds globales) | depende de G1 |

## 6. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Conexión al daemon | ✅ real (`rpc_client.dart` WebSocket) |
| Cobertura del Dashboard de 2.11 | ⚠️ prototipo (andamiaje + editor RPC); las pantallas operativas (roles, usuarios, políticas, 12 dominios) faltan |
| Coherencia de fuentes | ❌ **divergencia P1 (§3)** — el hallazgo principal de este anexo |
| Madurez declarada (0.00 §7: "L1-L2 diseño, sin Flutter") | **Corregida por código: SÍ hay Flutter** (bAuthDEV, 646 líneas) — L2 andamiaje; la carta rectora subestima el estado real |

## 7. Referencias e historial

**Del código:** `src/bAuthDEV/` (pubspec + 8 .dart) · **Del proyecto:** 2.11 · CLAUDE §7 · `PLAN-DESKTOP-BAUTH.md`/`DESIGN-DESKTOP-BAUTH.md` (citados por 2.11).
**Industria:** [Flutter desktop](https://docs.flutter.dev/platform-integration/desktop) · [Riverpod](https://riverpod.dev/) · [WCAG 2.2](https://www.w3.org/TR/WCAG22/) · [responsive design en Flutter](https://docs.flutter.dev/ui/adaptive-responsive)

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo C+B+D): la decisión Flutter-desktop-soberano justificada (se instala no se sirve — soberanía), **la divergencia crítica de tres fuentes** (CLAUDE forUI/Abyss vs 2.11 tf_shadcn/Riverpod/SBOS-Dark vs código Material/provider — brecha P1 G1), la verificación del código real (`bAuthDEV` 646 líneas: prototipo desktop con cliente WebSocket y editor RPC funcionales — corrige la carta rectora que lo daba "sin Flutter"), y 7 brechas específicas (unificar stack, responsive 3 rangos, 6 plataformas, visualización BitMask, tokens de diseño, WCAG/i18n, estado scoped). |
