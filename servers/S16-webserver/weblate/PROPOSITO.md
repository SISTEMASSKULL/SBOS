# PROPOSITO — Weblate (S16)

**Ficha:** `weblate` · **Servidor:** S16-webserver · **Versión:** 2026.x
**Criticidad:** ALTA · **Namespace:** sbos-web · **Tipo:** Deployment K8s (pod)
**URL referencia:** https://weblate.org/en/ · https://docs.weblate.org/en/latest/formats/fluent.html

> **Aclaración de rol:** Weblate es una herramienta web de apoyo al daemon `bi18nd` —
> NO es el daemon. El daemon soberano es `bi18nd` (systemd en el host, ficha en
> `S01-dataserver/bi18n/`). Weblate es la interfaz web que permite editar los archivos
> FTL que bi18nd sirve. Son dos fichas distintas en dos servidores distintos.

## Qué es

Plataforma web de gestión de traducciones self-hosted: permite a personas no técnicas
(equipo de negocio, redactores, responsables de país) editar los textos de UI del
ecosistema SBOS desde el navegador, sin tocar archivos FTL ni Git.

Weblate es la interfaz de edición — bi18nd (Bi18nAgent) es el servidor que sirve
las traducciones al resto del sistema. Son dos piezas distintas con roles distintos.

## Por qué existe

Sin Weblate, cambiar un texto de UI requiere que un desarrollador edite un archivo
FTL, haga un commit y espere un deploy. Con Weblate, el responsable del negocio
abre el navegador, edita el texto y en minutos está visible en el sistema — sin
intervención de desarrollo.

## Para qué sirve

- Interfaz web para editar archivos FTL (Fluent) y TOML de traducciones
- Soporta FTL/Fluent de forma nativa (confirmado Weblate 2026.7)
- Escribe los archivos de traducción directamente en el disco del VPS
- bi18nd detecta los cambios automáticamente (file watcher) y recarga sin redeploy
- Git/Gitea se usa como **respaldo** del historial de cambios — no como origen ni intermediario
- Proporciona historial de quién cambió qué clave y cuándo (trazabilidad)

## Flujo de operación

```
Traductor abre https://weblate.miempresa.com
        │
        │ Edita la clave "bauth.login.error-credenciales" en es-BO
        │ Guarda
        ▼
Weblate escribe en disco:
  /etc/bos/bi18n/translations/es-BO/bauth.ftl  ← directo, sin intermediarios
        │
        │ bi18nd file watcher (notify crate) detecta el cambio
        ▼
Hot-reload atómico (ArcSwap) — texto nuevo visible en segundos
        │
        │ Opcionalmente (respaldo):
        ▼
Gitea (si está instalado) recibe el commit como registro histórico
```

## Modos de integración con Git

| Modo | Git | Cuándo |
|------|-----|--------|
| **Directo al disco** (por defecto) | No requerido | Producción soberana — el más común |
| **Con Gitea local** (opcional) | Gitea en el mismo VPS | Si el cliente quiere auditoría de cambios |
| **Con GitHub** | GitHub externo | Solo SKULL en desarrollo — nunca en producción cliente |

Git es respaldo, no origen. La fuente de verdad de las traducciones es el disco del VPS.

## Cómo escribe en el host — hostPath K8s

Weblate corre como pod K8s pero escribe en el host mediante un volumen `hostPath`.
Este es el mecanismo estándar de K8s en nodo único para compartir un directorio
entre un pod y el filesystem del VPS.

```yaml
# Fragmento del Deployment de Weblate en K8s
volumes:
  - name: translations
    hostPath:
      path: /etc/bos/bi18n/translations   # directorio real en el host
      type: DirectoryOrCreate
containers:
  - name: weblate
    volumeMounts:
      - name: translations
        mountPath: /app/translations       # cómo lo ve Weblate dentro del pod
```

Cuando el traductor guarda un cambio en la UI, Weblate escribe el FTL en
`/app/translations/` — que en el host es `/etc/bos/bi18n/translations/`.
bi18nd (que corre directamente en el host) detecta el cambio con el file watcher
y recarga en caliente. **Weblate nunca llama a bi18nd por RPC — solo escribe archivos.**

### Consecuencia directa de esta arquitectura

Si el pod de Weblate se cae o se apaga, **bi18nd no se entera y sigue sirviendo
traducciones normalmente** — los archivos FTL siguen en disco, el watcher no necesita
a Weblate, el hot-reload sigue funcionando. Weblate solo importa cuando alguien
quiere editar traducciones desde la UI web.

## Quién la declara

`bos` (IAM Installer) la instala como **Deployment K8s** en el namespace `sbos-web`.
Accesible como virtual host de nginx en S16: `https://weblate.miempresa.com`.

## Dependencias

| Dependencia | Servidor | Por qué |
|-------------|----------|---------|
| `nginx` (S16) | S16 | Sirve la UI web de Weblate como virtual host |
| `certbot` (S16) | S16 | Certificado TLS para `weblate.miempresa.com` |
| `postgresql` | S01-dataserver | Base de datos de Weblate: usuarios, historial, proyectos, sugerencias, estadísticas |
| `redis` | S01-dataserver | Cola de tareas Celery (procesa commits en background) + caché de sesiones |
| `bi18nd` (ficha S01) | S01 — host | Lee en disco los archivos FTL que Weblate escribe — Weblate no llama a bi18nd, solo escribe archivos |

**bi18nd no depende de Weblate** — la relación es unidireccional: Weblate escribe → bi18nd lee.
bi18nd funciona perfectamente sin Weblate (los archivos FTL se pueden editar a mano o por CI/CD).

## Servidor y motivo

Vive en S16-webserver porque es una aplicación web de gestión accesible por
navegador, con su propio dominio y certificado. No vive en S06-appsserver
(apps de negocio del ERP) ni en S14-opsserver (herramientas de operación de
infraestructura) — su función es la gestión de contenido de traducción.
