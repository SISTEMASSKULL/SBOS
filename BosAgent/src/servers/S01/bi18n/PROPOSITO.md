# PROPOSITO — bi18n (Bi18nAgent)

**Ficha:** `bi18n` · **Servidor:** S01-dataserver · **Versión:** compilada desde `Bi18nAgent/`
**Criticidad:** ALTA · **Namespace:** sbos-data · **Tipo:** systemd service (host, fuera de K8s)
**Orden de instalación:** 210
**Binario:** `bi18nd` (Rust 1.85+ MUSL, LTO, tokio)
**Socket:** `/run/bos/bi18n.sock` (0660, grupo bosagent)
**Puerto TCP:** 9454 (WebSocket — 127.0.0.1 únicamente, sin exposición externa)
**Código fuente:** `Bi18nAgent/` — crate `i18n-orchestrator`
**Documentación:** `Bi18nAgent/context/Documentacion/INDICE.md`

## Qué es

Daemon soberano de internacionalización y localización del ecosistema SBOS.
Servidor canónico de traducciones de lenguajes: cualquier texto de UI, mensaje de error,
etiqueta de campo, opción de enum o notificación que el sistema muestre al usuario
pasa por bi18n — sin excepción.

**bi18n NO es un motor de i18n propio** — orquesta las mejores librerías del ecosistema
Rust (ICU4X, jiff, fluent-bundle, phonenumber, etc.) y las expone como una API
unificada JSON-RPC 2.0 para todo el ecosistema.

## Por qué vive en S01-dataserver

bi18n es un daemon de datos en el sentido amplio: gestiona y sirve datos de localización
(traducciones, reglas de país, formatos regionales) del mismo modo que otros daemons
del servidor sirven datos de negocio. Su ciclo de vida está ligado a S01:
- Lee `country-rules/*.toml` y `translations/*.ftl` desde disco (datos en S01)
- Carga configuración regional de tenants desde PostgreSQL (S01)
- Escribe logs a Loki/Wazuh (S12) vía el pipeline estándar

Los daemons de datos de SBOS comparten servidor para minimizar latencia de red entre
ellos — bkernel, biedata, bsearch y bi18n se comunican en el mismo VPS.

## Capacidades que instala

| Capacidad | Librerías | Fase |
|-----------|-----------|------|
| Servidor JSON-RPC 2.0 + WebSocket + gRPC | tokio, tonic | Fase 1 ✅ |
| Formato de fechas/horas (CLDR) | icu_datetime, jiff | Fase 1 ✅ |
| Formato de números y monedas (CLDR) | icu_decimal | Fase 1 ✅ |
| Resolución de locale BCP 47 | icu_locale_core | Fase 1 ✅ |
| Validación telefónica E.164 | phonenumber | Fase 1 ✅ |
| Validación de email | validator | Fase 1 ✅ |
| Enmascaramiento PII | mask-pii, veil, universal_mask | Fase 1 ✅ |
| Pipeline de atributos (validate→transform→format→mask) | valida, AttrBuilder | Fase 1 ✅ |
| Traducciones FTL/Fluent con hot-reload | fluent-bundle, arc-swap | Fase 1 ✅ |
| Validación de documentos nacionales (CI, NIT, placa) | regex + country-rules TOML | Fase 1 ✅ |
| Reglas de país: Bolivia, Argentina, Brasil | country-rules/*.toml | Fase 1 ✅ |
| CLI `bi18nctl` | clap | Fase 1 ✅ |
| Exposición de 108 métodos RPC adicionales | 22 librerías Cargo.toml | Fase 2 📋 |

## Interfaces expuestas (Interface Triple C11)

| Vía | Socket / Dirección | Protocolo |
|-----|--------------------|-----------|
| JSON-RPC 2.0 + WebSocket | `/run/bos/bi18n.sock` | JSON-RPC 2.0 newline-delimited |
| gRPC | `/run/bos/bi18n-grpc.sock` | gRPC sobre Unix domain socket |
| WebSocket TCP (frontends remotos) | `127.0.0.1:9454` | WebSocket — solo loopback, Kong lo expone |
| CLI | `bi18nctl` (binario local) | Llamada directa al core |

**NUNCA HTTP/TCP entre daemons** — SBOS-050 P9. Kong actúa como proxy para frontends remotos.

## Datos propios del daemon — viven en el host

Las traducciones son datos de bi18n. Viven en el host junto al daemon, no en ningún pod.
Si Weblate (S16) se cae, bi18nd sigue sirviendo todas las traducciones sin interrupción.

```
/etc/bos/bi18n/                         ← propiedad de bi18nd en el host
├── bi18n.toml                          # configuración del daemon
├── translations/                       # archivos FTL — FUENTE DE VERDAD
│   ├── es-BO/                          # locale base — todas las claves deben estar aquí
│   │   ├── common.ftl
│   │   ├── bauth.ftl
│   │   ├── btax.ftl
│   │   └── ...
│   └── en-US/                          # fallback universal
│       └── ...
└── country-rules/                      # reglas nacionales por país (TOML)
    ├── bo.toml                         # Bolivia: CI, NIT, postal, placa, moneda
    ├── ar.toml                         # Argentina
    └── br.toml                         # Brasil
```

**Regla:** nadie escribe en `/etc/bos/bi18n/translations/` salvo:
1. `bos` (instalación inicial y actualizaciones de sistema)
2. Weblate (S16) — vía `hostPath` K8s que monta este directorio en el pod

Weblate llega a escribir aquí cuando está disponible. Su indisponibilidad no afecta a bi18nd.
bi18nd monitorea `translations/` con file watcher (notify crate) — cualquier cambio en disco
dispara hot-reload atómico (ArcSwap) sin redeploy.

## Proceso de compilación e instalación

```bash
# bos compila el binario desde el código fuente en el VPS
cd Bi18nAgent/
cargo build --release --target x86_64-unknown-linux-musl

# Instala el binario y el servicio systemd
install -m 755 target/x86_64-unknown-linux-musl/release/bi18nd /usr/local/bin/
install -m 755 target/x86_64-unknown-linux-musl/release/bi18nctl /usr/local/bin/
systemctl enable --now bi18nd
```

**No hay imagen Docker para bi18nd** — corre en el host con systemd (SBOS-050 P9).
La compilación MUSL produce un binario estático sin dependencias de sistema.

## Dependencias de instalación

| Dependencia | Tipo | Por qué |
|-------------|------|---------|
| `network-validator` (S00) | Infraestructura | Socket de red disponible antes de arrancar |
| `postgresql` (S01) | Dato | Configuración de tenants (`idn_tenant`) |
| `redis` (S01) | Dato | Caché de bundles Fluent y configuración regional |
| `bos` (S00) | Motor | Instala, supervisa y gestiona el ciclo de vida |
| Rust toolchain + MUSL target | Build | Compilación del binario estático |

## Servicio systemd

```ini
# /etc/systemd/system/bi18nd.service
[Unit]
Description=bi18n — Orquestador de Internacionalización SBOS
After=network.target postgresql.service redis.service

[Service]
Type=notify
ExecStart=/usr/local/bin/bi18nd --config /etc/bos/bi18n/bi18n.toml
WatchdogSec=30
Restart=on-failure
User=bosagent
Group=bosagent

[Install]
WantedBy=multi-user.target
```

## Consumidores del daemon

| Daemon / App | Cómo consume bi18n | Qué obtiene |
|---|---|---|
| bAuth (S03) | JSON-RPC sobre `/run/bos/bi18n.sock` | Textos de error, validación de atributos de identidad |
| btax (S01) | JSON-RPC o crate directo | Validación de NIT, formato de montos fiscales |
| bpay (S01) | JSON-RPC o crate directo | Formato de moneda, validación de IBAN/CBU |
| website-engine / Weblate (S16) | JSON-RPC | Todos los textos de UI del portal web del cliente |
| Frontends web/móvil | WebSocket TCP 9454 vía Kong | Textos de UI, máscaras de campos, validación |
| bi18nctl (CLI) | Binario local | Administración, recarga, diagnóstico |

## Bitácora

- Ficha declarada 2026-07-17. Implementación Fase 1 completa y certificada (commit `0d507b4`).
- 18 métodos RPC activos. Interface Triple C11 (JSON-RPC + gRPC + WebSocket TCP).
- Fase 2: 108 métodos RPC adicionales planificados (REGISTRO-ESTADO-DOS v3.0.0).
- Cambios en esta ficha → consulta al humano (recurso compartido, ORQUESTA-051).
