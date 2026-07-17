# Despliegue en Alta Disponibilidad — bi18n daemon (10.4)

**Versión:** 1.0.0 · **Fecha:** 2026-07-17
**Criterio de done:** `systemctl stop bi18nd-1` → Kong redirige sin error; al
restaurarla re-entra al pool automáticamente en < 15s.

---

## §1 Artefacto inmutable — country-rules/ en binario

`country-rules/` se embebe en el binario en tiempo de compilación (`include_dir`).
Las réplicas no leen reglas de país de disco en producción; el artefacto es
autocontenido e idéntico en todas las instancias.

Recarga dinámica (vía SIGHUP o `bi18n.admin.reload`) sí lee de disco — para actualizar
reglas de país sin redeploy del binario.

**Verificación:**
```bash
strings target/release/bi18nd | grep '"iso_alpha2"' | head -3
# Salida esperada: "iso_alpha2" aparece con "BO", "AR", "BR" — datos embebidos
```

---

## §2 Volumen compartido para locales/ (traducciones FTL)

Las traducciones FTL no se embeben — se leen de disco en arranque y en recarga.
Todas las réplicas DEBEN apuntar al mismo volumen para que SIGHUP produzca estado
consistente.

```toml
# bi18n.toml de cada réplica
[rutas]
fluent_dir = "/srv/sbos/bi18n/locales"   # montaje NFS compartido
```

**Montaje NFS** (agregar a `/etc/fstab` en cada nodo):
```
nfs-server:/exports/sbos/bi18n/locales  /srv/sbos/bi18n/locales  nfs  ro,soft,timeo=30  0  0
```

Las réplicas montan el volumen en modo solo lectura (`ro`). Solo el pipeline de CI
escribe al volumen desde el servidor NFS.

---

## §3 Arquitectura de réplicas detrás de Kong

```
Cliente (cualquier plataforma)
        │  wss://bi18n.dominio.com/ws  (TLS — Kong)
        ▼
  Kong API Gateway  ──────────────────────────────────────
        │  ws://127.0.0.1:9454  (round-robin, health check)
        ├──────────────────► bi18nd réplica-1  (9454)
        └──────────────────► bi18nd réplica-2  (9455)
                              │
                     /srv/sbos/bi18n/locales/  (NFS compartido)
```

---

## §4 Configuración Kong — upstream con health check activo

```yaml
# kong-bi18n.yml — Kong declarativo (formato 3.0)
_format_version: "3.0"

upstreams:
  - name: bi18n-upstream
    algorithm: round-robin
    healthchecks:
      passive:
        healthy:
          successes: 2
        unhealthy:
          http_failures: 3
      active:
        http_path: /health
        interval: 5
        healthy:
          interval: 5
          successes: 2
        unhealthy:
          interval: 5
          http_failures: 3
    targets:
      - target: 127.0.0.1:9454   # bi18nd réplica-1
        weight: 100
      - target: 127.0.0.1:9455   # bi18nd réplica-2
        weight: 100

services:
  - name: bi18n-ws
    url: ws://bi18n-upstream
    routes:
      - name: bi18n-ws-route
        paths: ["/ws"]
        protocols: ["ws", "wss"]
```

---

## §5 Unidades systemd para múltiples réplicas

```ini
# /etc/systemd/system/bi18nd@.service — plantilla parametrizada
[Unit]
Description=bi18n daemon — réplica %i
After=network.target

[Service]
Type=notify
Environment=BI18N_CONFIG=/etc/bos/bi18n-%i.toml
ExecStart=/usr/local/bin/bi18nd
Restart=on-failure
RestartSec=5s
WatchdogSec=30s
NotifyAccess=main

[Install]
WantedBy=multi-user.target
```

Iniciar ambas réplicas:
```bash
systemctl enable bi18nd@1 bi18nd@2
systemctl start  bi18nd@1 bi18nd@2
```

Cada réplica tiene su propio `.toml` con `ws_bind` en puerto diferente:
```toml
# /etc/bos/bi18n-1.toml
[servidor]
ws_bind = "127.0.0.1:9454"

# /etc/bos/bi18n-2.toml
[servidor]
ws_bind = "127.0.0.1:9455"
```

---

## §6 Recarga coordinada de traducciones

Cuando el pipeline CI actualiza `locales/` en el volumen NFS, cada réplica recibe
la señal de recarga individualmente — nunca a través de Kong (no se garantiza que
el balance alcance todas las réplicas).

```bash
# Script de recarga coordinada — ejecutar desde el pipeline CI
i18nctl --socket /run/bos/bi18n-1.sock recargar
i18nctl --socket /run/bos/bi18n-2.sock recargar
```

---

## §7 Verificación del criterio de done

```bash
# 1. Detener réplica-1
systemctl stop bi18nd@1

# 2. Verificar que Kong redirige a réplica-2 (sin error visible)
for i in $(seq 1 5); do
  i18nctl --socket /tmp/bi18n-test-ws.sock estado 2>&1
done

# 3. Restaurar réplica-1
systemctl start bi18nd@1

# 4. Verificar que réplica-1 vuelve al pool en < 15s (health check Kong: 5s × 2 = 10s)
sleep 15
# Kong debe balancear de nuevo entre ambas réplicas
```
