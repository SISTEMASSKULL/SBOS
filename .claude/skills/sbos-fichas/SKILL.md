---
name: sbos-fichas
description: >
  Trabajar con las fichas de infraestructura y los servidores lógicos del proyecto SBOS.
  Úsala para declarar, ubicar o revisar una ficha: en qué servidor lógico (S00–S15) vive,
  su anatomía (manifest.yml + task_catalog.sh + resources/ + PROPOSITO.md), su puerto
  (SBOS-050 §12.3) y cómo consultar a un daemon hermano (bos, bkernel…) por su contrato.
---

# Skill — Fichas y Servidores Lógicos de SBOS

**Norma del proyecto (léela primero):** `servers/servers.yml`.
**Catálogo por servidor:** `servers/SNN-<nombre>/PROPOSITO.md`.
**Definición de apps:** `context/IAM_Enterprise_Stack_v5.md` · **Puertos:** `context/BOS_V8/BOS_V8_SBOS-050-PORT-CATALOG.md`.

## Reglas duras
- Una sola BD `SBOS_db`; cada microservicio = un schema. `servers/` es **público en lectura, soberano en escritura**.
- Cada ficha vive en `servers/SNN-<servidor>/<app>/` con `manifest.yml` + `task_catalog.sh` + `resources/` + **`PROPOSITO.md`** (sin él, se rechaza).
- Nombre de ficha = nombre canónico del catálogo, **no arbitrario**. La versión va en Git, no en el nombre.
- El **motor** (instalar/observar) es de `bos`; `task_catalog.sh` solo funciones `<app>_<verbo>`.

## Regla R7 — Todo daemon es una ficha (instalación universal)

**Solo el BOS instala. Y lo hace a través de una ficha.** Todo daemon del ecosistema SBOS
— bauth, bkernel, biedata, bsearch, bnotify, bnexus, bi18n, bpay, brate, btax, bcompass —
entra al sistema operativo empresarial como una ficha, exactamente igual que PostgreSQL,
Redis o Nextcloud. El BOS no distingue entre "daemon" y "aplicación": todo es una ficha
con el mismo ciclo de vida (`install → status → repair → update → remove`).

### Obligaciones del agente desarrollador del daemon

Cada daemon debe **generar y mantener actualizada su propia ficha** en el directorio
`servers/` del proyecto SBOS. El agente del daemon es el **único responsable** de que
su ficha esté completa y actualizada.

| # | Obligación | Verificación |
|:--|-----------|-------------|
| **O1** | **Crear el directorio de ficha** en el servidor lógico correcto según `servers/servers.yml → servidores_logicos` | `ls servers/SNN-<servidor>/<daemon>/` → existe |
| **O2** | **Escribir `PROPOSITO.md`** — qué es el daemon, por qué existe, para qué sirve | `cat PROPOSITO.md` → describe propósito, no implementación |
| **O3** | **Escribir `manifest.yml`** — identidad, servidor, dependencias, versión, health check, puertos (SBOS-050 §7.2 o §12.3) | `manifest.yml` válido contra el schema de ficha |
| **O4** | **Copiar el binario compilado** al directorio de la ficha | `file <daemon>` → ELF ejecutable, arquitectura correcta |
| **O5** | **Escribir `task_catalog.sh`** con las 5 funciones obligatorias: `<daemon>_install`, `<daemon>_verify`, `<daemon>_health`, `<daemon>_repair`, `<daemon>_remove` | `grep "^<daemon>_install()" task_catalog.sh` → existe |
| **O6** | **Escribir `<daemon>.service`** — unit de systemd que el BOS copiará a `/etc/systemd/system/` | `systemd-analyze verify <daemon>.service` → OK |
| **O7** | **Copiar todo lo necesario** — configuraciones, seeds SQL, recursos, assets — al directorio de la ficha. Nada debe faltar para que el daemon opere | `ls -R` muestra todos los archivos necesarios |
| **O8** | **Mantener la ficha actualizada** — cada nueva versión del daemon actualiza `manifest.yml` (versión), copia el nuevo binario, y si hubo cambios de configuración, actualiza el `task_catalog.sh` | `git log -- servers/SNN-<servidor>/<daemon>/` muestra commits del agente |

### Lo que el daemon NUNCA hace

- ❌ Instalarse a sí mismo con `systemctl start` o `cargo install`
- ❌ Copiar su binario manualmente a `/opt/skull/SBOS/bin/`
- ❌ Escribir su propio systemd unit directamente en `/etc/systemd/system/`
- ❌ Asumir que sus dependencias ya están instaladas (las declara en `manifest.yml`)
- ❌ Modificar la ficha de otro daemon (ORQUESTA-051: write soberano, read por contrato)

### Lo que el BOS hace con la ficha del daemon

```
bosctl ficha rescan              ← descubre la ficha nueva o actualizada
bosctl ficha install <daemon>    ← copia binario a /opt/skull/SBOS/bin/
                                    copia <daemon>.service a systemd
                                    ejecuta <daemon>_install del task_catalog.sh
                                    ejecuta <daemon>_verify
bosctl ficha status <daemon>     ← socket respondiendo, healthy, puerto OK
bosctl ficha repair <daemon>     ← ejecuta <daemon>_repair si se degrada
bosctl ficha update <daemon>     ← actualiza binario, re-ejecuta verify
bosctl ficha remove <daemon>     ← ejecuta <daemon>_remove, libera puertos
```

### Estructura canónica de la ficha de un daemon

```
servers/SNN-<servidor>/<daemon>/
├── PROPOSITO.md              ← qué es, por qué existe, para qué sirve
├── manifest.yml              ← identidad, dependencias, versión, health check, puertos
├── task_catalog.sh           ← 5 funciones: install, verify, health, repair, remove
├── <daemon>.service          ← unit systemd
├── <daemon>                  ← binario compilado (Rust MUSL o Go estático)
├── config/                   ← archivos de configuración (opcional)
├── seeds/                    ← seeds SQL si el daemon tiene schema propio (opcional)
└── resources/                ← assets, plantillas, certificados (opcional)
```

## Declarar una ficha
1. Ubica el servidor lógico (SNN) correcto en `servers/servers.yml → servidores_logicos`.
2. Revisa el `PROPOSITO.md` de ese servidor: ¿la app ya existe (✅) o falta (⬜)?
3. Crea `servers/SNN-<servidor>/<app>/` con los 4 archivos. Puerto `containerPort→ClusterIP` de SBOS-050 §12.3.
4. **Si es un daemon:** cumple las 8 obligaciones (O1-O8). Sin excepción.

## Consultar a un hermano (read-only)
Un daemon consulta a otro por su **contrato** (su `PROPOSITO.md`, `manifest.yml` o JSON-RPC), nunca su
código interno. La ruta del hermano se resuelve por `paths.yml` (`fabrica_core.rutas.ruta_hermano`).
**Nunca escribas en la ficha de otro daemon** (ORQUESTA-051: write soberano, read por contrato).
