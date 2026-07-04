# PLAN DE IMPLEMENTACIÓN — Orquestación de Agentes IA (Fábrica SBOS)

**Base de trabajo:** `/opt/projects-ia`
**Componentes:** amux (mixpeek) + guild (mathomhaus) + postgres-mcp (crystaldba)
**Fecha de creación del plan:** 2026-07-01
**Estado:** por ejecutar

---

## Contexto y decisión

Problema a resolver: los agentes de Fábrica SBOS pierden estado entre reinicios de sesión,
la documentación crece sin control (ver caso real: `REGISTRO-ESTADO.md` de bauth llegó a
2254 líneas, 33 de 52 bloques ya cerrados pero seguían leyéndose enteros cada sesión), y no
hay coordinación real entre los 12 agentes especializados. Hay trabajo atrasado — se
implementan los tres componentes desde el día 1, en paralelo, sin fase de espera.

Herramientas elegidas y su rol, sin solaparse:

| Herramienta | Resuelve | No resuelve |
|---|---|---|
| **amux** (`mixpeek/amux`) | Visibilidad + control remoto de agentes, memoria compartida básica, API REST agente-a-agente | Búsqueda semántica de documentación grande |
| **guild** (`mathomhaus/guild`) | Memoria/coordinación con búsqueda híbrida (keyword + semántica), evita releer documentos enteros | Esquema real de base de datos |
| **postgres-mcp** (`crystaldba/postgres-mcp`) | Introspección del esquema real (300+ tablas) bajo demanda | Coordinación entre agentes |

> **Nota de madurez — leer antes de depender de esto para trabajo urgente:** `guild` tiene
> 1 star en GitHub y un solo release (v0.1.0). No es software con historial de producción.
> Se implementa igual desde el día 1 por decisión del usuario, pero bajo la regla dura de la
> Fase 1B: **guild nunca es la única copia de nada.** Los documentos fuente originales se
> versionan en git ANTES de indexarlos, así un fallo de guild (corrupción de la base SQLite,
> bug de búsqueda, lo que sea) es una molestia recuperable, no una pérdida de información.

---

## Estructura de carpetas objetivo

```
/opt/projects-ia/
│
├── _sistema/                                 ← LAS HERRAMIENTAS (no proyectos)
│   ├── amux/                                 ← clon + binario de mixpeek/amux
│   ├── guild/                                ← binario guild
│   └── postgres-mcp/                         ← servidor MCP de introspección Postgres
│
├── _docs-globales/                           ← CONTEXTO GENERAL DE TODA LA FÁBRICA
│   ├── PROJECTS-INDEX.md                     ← todo agente, de cualquier proyecto, lee esto primero
│   ├── GLOSARIO.md                           ← conceptos esenciales (BitMask, daemon soberano, etc.)
│   └── PRINCIPIOS-ARQUITECTURA.md            ← decisiones transversales (Docker prohibido, PAM/sudoers, etc.)
│
├── bauth/                                    ← RAÍZ REAL DEL PROYECTO — código YA desarrollado + TODO su contexto
│   ├── src/...                               ← el código existente de bauth (hoy en /opt/skull/.../BauthAgent)
│   └── context/                              ← TODO el contexto de bauth, un solo lugar, nada disperso
│       ├── general/                          ← CONTEXTO GENERAL DEL PROYECTO — todo agente que toque bauth lee esto
│       │   ├── REGISTRO-ESTADO.md            ← estado vivo del PROYECTO (no de un agente puntual)
│       │   ├── SPEC-XXX.md
│       │   ├── ADR/
│       │   └── _archivo/                     ← bloques cerrados, histórico, solo consulta
│       └── agentes/                          ← DOCS PROPIAS DE CADA AGENTE — no se mezclan entre sí
│           ├── dev/BITACORA.md               ← solo el agente "dev" de bauth lee/escribe esto
│           ├── test/BITACORA.md              ← solo el agente "test" de bauth
│           └── docs/BITACORA.md              ← el Bibliotecario de bauth
│
├── bsign/                                    ← MISMO PATRÓN EXACTO, repetido por cada daemon
│   ├── src/...
│   └── context/
│       ├── general/
│       └── agentes/{dev,test,docs}/BITACORA.md
│
├── bos/                                      ← ídem
├── bkernel/                                  ← ídem
└── ...                                       ← un directorio por cada daemon activo de Fábrica SBOS
```

> Cambio de diseño respecto a la iteración anterior: en vez de `docs/` y `.agentes/` como
> dos carpetas separadas en la raíz del proyecto, ahora TODO el contexto (general + por
> agente) vive dentro de una única carpeta `context/`, junto al código, dentro del mismo
> directorio del proyecto. Un solo lugar por daemon para todo lo que no es código ejecutable.

### Regla de qué va en cada lugar (sin ambigüedad)

| Ubicación | Quién la lee | Quién la escribe | Contenido |
|---|---|---|---|
| `_docs-globales/` | TODOS los agentes, de cualquier proyecto | Solo el Bibliotecario general | Conceptos y decisiones que cruzan proyectos |
| `<proyecto>/context/general/` | Todos los agentes de ESE proyecto (dev, test, docs) | Solo el Bibliotecario de ese proyecto | Spec, ADRs, estado del proyecto completo |
| `<proyecto>/context/agentes/<nombre>/BITACORA.md` | Solo ese agente específico | Solo ese agente específico | Su propio progreso puntual: qué hizo, dónde quedó, qué le falta a ÉL |
| `<proyecto>/src/` | Todos los agentes de ese proyecto (según permisos de escritura por rol) | dev (principalmente) | El código real, ya existente, del daemon |

La diferencia entre `context/general/REGISTRO-ESTADO.md` y `context/agentes/dev/BITACORA.md`: el primero
dice **"qué le pasa al proyecto bauth"** (estado compartido entre agentes), el segundo dice
**"qué venía haciendo yo, el agente dev, la última vez que trabajé"** — son dos preguntas
distintas, por eso dos archivos distintos, nunca mezclados en uno solo.

---

## Fase 0B — Ubicación del código ya existente

Cada proyecto (bauth, bsign, bos, etc.) ya tiene código desarrollado en alguna ruta actual
del VPS. Hay dos formas válidas de que ese código quede dentro de `/opt/projects-ia/<proyecto>/`
— elegir una por proyecto, no mezclar ambas para el mismo repo:

**Opción A — Mover el repo real (recomendada si el código no tiene rutas absolutas hardcodeadas hacia su ubicación actual):**
```bash
# ejemplo real con bauth, ruta actual confirmada:
mv /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent /opt/projects-ia/bauth
cd /opt/projects-ia/bauth
mkdir -p context/general/_archivo context/agentes/{dev,test,docs}
git status   # confirmar que el historial de git sigue intacto tras el move
```

**Opción B — Symlink (recomendada si otros servicios, systemd units, scripts de deploy, etc. ya referencian la ruta actual y romperla es riesgoso):**
```bash
ln -s /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent /opt/projects-ia/bauth
cd /opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent
mkdir -p context/general/_archivo context/agentes/{dev,test,docs}
```
Con symlink, `context/` se crea en la ubicación REAL del repo — el symlink en
`/opt/projects-ia/` es solo el punto de entrada unificado para amux/guild, el código y el
contexto siguen viviendo donde ya estaban.

- [ ] Decidido por proyecto: mover o symlink (completar tabla abajo)
- [ ] `context/general/` y `context/agentes/{dev,test,docs}/` creados en cada proyecto migrado

| Proyecto | Ruta actual del código | Opción (mover/symlink) | Hecho |
|---|---|---|---|
| bauth | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent` | | [ ] |
| bcms | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BcmsAgent` | | [ ] |
| bos | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent` | | [ ] |
| biedata | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BiedataAgent` | | [ ] |
| bintelligence | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BintelligenceAgent` | | [ ] |
| bkernel-common | `/opt/skull/orquestador/proyectos/desarrollo/sbos/bkernel-common` | | [ ] |
| bkernel | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent` | | [ ] |
| bnexus | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BnexusAgent` | | [ ] |
| bnotify | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BnotifyAgent` | | [ ] |
| bpay | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BpayAgent` | | [ ] |
| brate | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BrateAgent` | | [ ] |
| btax | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BtaxAgent` | | [ ] |

> Nota sobre `bkernel-common`: por el nombre, probablemente es una librería compartida
> consumida por otros daemons (no un daemon con agentes propios). Confirmar antes de
> migrar si necesita su propia carpeta `context/` con `agentes/{dev,test,docs}`, o si
> alcanza con `context/general/` únicamente (sin bitácoras por agente, porque nadie
> trabaja "dentro" de una librería compartida de la misma forma que en un daemon).

---

## Fase 0 — Permisos base

`/opt` normalmente requiere sudo. Ejecutar una sola vez:

```bash
sudo mkdir -p /opt/projects-ia/{_sistema,_docs-globales}
sudo chown -R $USER:$USER /opt/projects-ia
cd /opt/projects-ia
```

- [ ] Confirmado: usuario tiene permisos de escritura en `/opt/projects-ia`

---

## Fase 1 — amux (primero, solo)

```bash
cd /opt/projects-ia/_sistema
git clone https://github.com/mixpeek/amux
cd amux
./install.sh
amux --version
```

Registrar el primer proyecto real (bauth), **sin `--yolo` al principio** — aprobar
manualmente las primeras sesiones antes de automatizar del todo. Una sesión por CADA
AGENTE del proyecto, no una sola sesión genérica:

```bash
amux register bauth-dev  --dir /opt/projects-ia/bauth
amux register bauth-test --dir /opt/projects-ia/bauth
amux register bauth-docs --dir /opt/projects-ia/bauth

amux start bauth-dev
amux start bauth-test
amux start bauth-docs

amux serve   # dashboard en localhost:8822, las tres sesiones visibles por separado
```

### Hook `SessionStart` — carga las tres capas de contexto, no solo una

Cada agente necesita su propio `.claude/settings.json` (o variable de entorno al arrancar
la sesión) para que el hook cargue SU bitácora, no la de otro agente del mismo proyecto:

```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "cat /opt/projects-ia/_docs-globales/PROJECTS-INDEX.md && echo '---' && cat /opt/projects-ia/bauth/context/general/REGISTRO-ESTADO.md && echo '---' && cat /opt/projects-ia/bauth/context/agentes/dev/BITACORA.md"
      }]
    }]
  }
}
```

El último `cat` cambia según el agente: `test` carga `context/agentes/test/BITACORA.md`,
`docs` carga `context/agentes/docs/BITACORA.md`. Las dos primeras rutas (general de
fábrica + general de proyecto) son iguales para los tres.

> Si `dev` y `test` van a escribir código al mismo tiempo sobre el mismo repo y preocupa que
> se pisen archivos, sumar git worktrees por agente (`bauth/.worktrees/dev/`,
> `bauth/.worktrees/test/`) como aislamiento extra — evaluar según el caso, no es obligatorio
> si `test` solo lee y corre tests sin modificar código fuente.

Acceso remoto desde laptop Windows (túnel SSH, sin exponer el puerto a internet):

```bash
ssh -L 8822:localhost:8822 usuario@vps-dev
# luego abrir https://localhost:8822 en el navegador de Windows
```

- [ ] `amux --version` corre sin errores
- [ ] `bauth-dev`, `bauth-test`, `bauth-docs` registrados y visibles en el dashboard
- [ ] Hook `SessionStart` configurado por agente (cada uno carga su propia `BITACORA.md`)
- [ ] Túnel SSH probado desde la laptop

---

## Fase 2 — Red de seguridad ANTES de tocar guild (obligatoria, no saltear)

Dado que guild es la pieza menos probada del stack, esta fase es lo que hace que su uso
sea "robusto" pese a su madurez: garantiza que nada vive únicamente dentro de guild.

```bash
cd /opt/projects-ia/bauth
git init            # si el repo no está ya versionado
git add context/
git commit -m "Snapshot pre-guild: fuente de verdad versionada antes de indexar"
```

Regla operativa permanente: **todo documento se escribe primero en el filesystem
(versionado en git), y RECIÉN DESPUÉS se indexa en guild.** Guild es un índice de
búsqueda sobre esa fuente, nunca el único lugar donde vive la información. Si guild
se corrompe o falla, se reinstala y se reindexa desde los `.md` en git — cero pérdida.

- [ ] Documentación de bauth versionada en git antes de instalar guild
- [ ] Regla "escribir en filesystem primero, indexar después" comunicada a todos los agentes (vía `AGENTS.md` / `CLAUDE.md`)

---

## Fase 3 — guild (día 1, en paralelo con amux)

```bash
curl -fsSL https://github.com/mathomhaus/guild/releases/latest/download/install.sh | sh
guild --version
```

Inicializar sobre un proyecto real:

```bash
cd /opt/projects-ia/bauth
guild init
```

**Smoke test antes de depender de esto (5 minutos, no saltear):**

```bash
guild lore inscribe "Prueba de humo: si esto aparece en la búsqueda, guild funciona" --kind principle
guild lore appraise "prueba de humo"
```

Si la búsqueda no devuelve la entrada, hay un problema de instalación/config que hay
que resolver ANTES de migrar contenido real — no después.

- [ ] Smoke test ejecutado y confirmado funcionando

Migración de contenido existente (no migrar los 52 bloques de una — empezar acotado,
aunque el objetivo final sea migrar todo, hacerlo en tandas verificables):

| Origen | Destino en guild | Comando base |
|---|---|---|
| Decisiones transversales / principios | `Lore` tipo `principle` | `guild lore inscribe "..." --kind principle` |
| Bloques ya cerrados (histórico) | `Lore` tipo `decision` / `observation` | `guild lore inscribe "..." --kind decision` |
| Bloques activos/en progreso | `Quest` | `guild quest create "..." --priority ...` |

> Antes de migrar: resolver la colisión de IDs detectada en el `REGISTRO-ESTADO.md` real
> (B35, B36, B37, B38 duplicados, cada uno usado dos veces con contenido distinto). No
> migrar el ID duplicado tal cual.

- [ ] `guild --version` corre sin errores
- [ ] `guild init` ejecutado sobre bauth
- [ ] IDs duplicados resueltos antes de indexar
- [ ] Migración piloto: solo bloques activos + 3-4 decisiones cerradas (no los 52 bloques)

---

## Fase 4 — postgres-mcp (día 1, en paralelo)

Prerrequisito: usuario de PostgreSQL de **solo lectura** dedicado (no reutilizar el usuario
de la aplicación):

```sql
CREATE USER mcp_readonly WITH PASSWORD '...';
GRANT CONNECT ON DATABASE bauth TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;
```

Instalación:

```bash
cd /opt/projects-ia/_sistema
git clone https://github.com/crystaldba/postgres-mcp
cd postgres-mcp
# completar según README del proyecto — confirmar método exacto al llegar a esta fase
```

- [ ] Usuario `mcp_readonly` creado, permisos verificados (solo SELECT)
- [ ] postgres-mcp instalado y conectando con el DSN de solo lectura

---

## Fase 5 — Conexión a Claude Code (MCP)

- amux: se opera vía dashboard web (no es un servidor MCP), túnel SSH.
- guild: se registra como servidor MCP (lo hace `guild init` automáticamente si detecta
  Claude Code).
- postgres-mcp: se registra manualmente en la config MCP de Claude Code con el DSN de
  solo lectura.

- [ ] guild aparece en la lista de servidores MCP de Claude Code
- [ ] postgres-mcp aparece en la lista de servidores MCP de Claude Code

---

## Fase 6 — Replicar a los demás proyectos SBOS

Una vez validado el flujo completo con bauth, repetir Fases 1, 3 (si aplica) y 5 para
cada daemon activo (bsign, bos, bkernel, etc.), registrando cada uno en
`_docs-globales/PROJECTS-INDEX.md`.

- [ ] bsign
- [ ] bos
- [ ] (agregar según corresponda)

---

## Registro de ejecución (completar a medida que se avanza)

| Fecha | Fase | Resultado | Notas |
|---|---|---|---|
| | | | |
