---
codigo: BNOTIFY-036
version: 1.0.0
estado: BORRADOR
gate: G3
depende_de: [BNOTIFY-032, BNOTIFY-033]
doctrina_que_ejerce: [D7, D13, D14]
criterio_implementado: >
  El script de migración ejecuta sin errores en staging.
  Los usuarios migrados pueden autenticarse en bChat con el mismo JWT bAuth.
  El historial de mensajes está accesible en bChat (mensajes migrados a bchat.message).
  bRocket responde 503 con mensaje claro de migración completada.
  bNotify ya no usa el adaptador REST de bRocket — usa el gRPC de bChat.
  Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-036 — Migración bRocket → bChat
## Usuarios, historial, doble-corrida, corte y apagado de bRocket

**Versión:** 1.0.0 · **Gate:** G3 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §B.2 (bRocket es interino) · BNOTIFY-003 (despliegue bRocket) · ADR-003 (bRocket frozen)

---

## 1. Principios de la migración

- **Gate G3 es la condición de activación:** la migración no inicia hasta que bChat (motor Rust + cliente Flutter) pasa el gate G3 — demostración en vivo, no promesa de fecha (D13)
- **Migración de datos, no de código:** bRocket no se "adapta" a bChat — los datos de bRocket se exportan y se importan en el schema `bchat`. bRocket se apaga.
- **Doble-corrida:** durante la transición de 72 horas, bRocket y bChat coexisten. Los usuarios nuevos van a bChat. Los usuarios existentes ven el aviso de migración en bRocket.
- **El historial va con el usuario:** cada mensaje de bRocket se migra al schema `bchat.message` con sus metadatos — el usuario ve su historial completo en bChat
- **bAuth es el puente de identidad:** los usuarios ya tienen bauth_user_id — la migración los mapea directamente, sin reinscripción

---

## 2. Inventario de datos a migrar

### Desde MongoDB (bRocket) → PostgreSQL (bChat)

| Colección MongoDB | Tabla destino | Mapeo clave |
|-------------------|--------------|-------------|
| `rocketchat_rooms` | `bchat.room` | `_id` → `UUID` nuevo, `t` → `type`, `fname` → `name` |
| `rocketchat_subscription` | `bchat.room_member` | Membresías por usuario/sala |
| `rocketchat_message` | `bchat.message` | `_id` → UUID, `msg` → `text`, `ts` → `created_at` |
| `rocketchat_uploads` | `bchat.media_object` | URL de archivo → copia a MinIO, hash SHA256 |

### Datos que NO se migran

- Workflows de Livechat → el módulo de atención al cliente (BNOTIFY-042) reemplaza esta funcionalidad
- Configuración de integraciones de bRocket → reemplazadas por bNotify adaptadores
- Datos de sesión activa → todos los usuarios deben hacer login en bChat

---

## 3. Proceso de migración paso a paso

### Fase 1: Preparación (pre-G3, antes del corte)

```bash
# 1. Exportar dump completo de MongoDB
mongodump --uri "mongodb://mongodb-0.mongodb:27017/?replicaSet=rs0" \
  --db rocketchat --out /migration/dump_$(date +%Y%m%d)/

# 2. Contar usuarios y mensajes a migrar
mongo rocketchat --eval "db.users.countDocuments({})"
mongo rocketchat --eval "db.rocketchat_message.countDocuments({})"
```

### Fase 2: Migración inicial (sin corte)

El script de migración se ejecuta **sin apagar bRocket** — migra una snapshot inicial:

```bash
# Script: scripts/migrate_brocket_to_bchat.sh
# Ejecuta en staging primero, verifica con verificar_afirmacion.sh, luego en prod.

python3 scripts/brocket_to_bchat.py \
  --mongo-uri "mongodb://mongodb-0.mongodb:27017/?replicaSet=rs0" \
  --pg-url "postgresql://bchat_rw:${BCHAT_DB_PASS}@postgres.infra:5432/SBOS_db" \
  --minio-endpoint "minio.infra:9000" \
  --tenant-id "${TENANT_ID}" \
  --dry-run         # Primera ejecución: solo validar sin escribir
```

### Fase 3: Ventana de corte (72 horas de doble-corrida)

```
T=0h:  Activar banner en bRocket: "Este servicio cierra en 72h. Tu historial estará en bChat."
T=0h:  bChat abierto para usuarios nuevos.
T=24h: Segunda ejecución del script (migra mensajes nuevos desde T=0h).
T=48h: Tercera ejecución del script (migra mensajes nuevos desde T=24h).
T=72h: CORTE:
       - bRocket responde 503 con página de migración (no se apaga aún)
       - Script final ejecuta (migra últimas horas)
       - bNotify conmuta adaptador: de REST-bRocket a gRPC-bChat
T=96h: Si no hay reportes críticos: apagar bRocket.
T+7d: Desinstalar MongoDB del clúster K8s.
```

### Fase 4: Verificación post-migración

```bash
# Verificar que todos los usuarios de bRocket existen en bchat.room_member
psql SBOS_db -c "SELECT COUNT(*) FROM bchat.room_member WHERE tenant_id = '${TENANT_ID}'"

# Verificar que el conteo de mensajes migrados es correcto
psql SBOS_db -c "SELECT COUNT(*) FROM bchat.message WHERE tenant_id = '${TENANT_ID}'"

# Verificar que bNotify ya no intenta conectar a bRocket
journalctl -u bnotify --since "1 hour ago" | grep -i "rocketchat" | grep -c "ERROR"
```

---

## 4. Conmutación del adaptador bNotify

El adaptador del canal chat en bNotify (BNOTIFY-011) tiene dos implementaciones:
- `BrocketAdapter` (G1): POST REST a Rocket.Chat API
- `BchatAdapter` (G3): llamada gRPC al motor bChat nativo

La conmutación se hace por configuración (sin recompilar):

```toml
# /etc/bnotify/config.toml
[adapter.chat]
backend = "bchat"    # Cambiar de "brocket" a "bchat" para el corte

[adapter.chat.bchat]
grpc_endpoint = "http://unix:///run/bos/bchat.sock"
```

El daemon bNotify recibe `SIGHUP` para recargar la configuración sin reiniciar.

---

## 5. Plan de rollback

Si durante las 72 horas de doble-corrida se detecta un problema crítico en bChat:

1. Revertir `config.toml` de bNotify a `backend = "brocket"`
2. Enviar SIGHUP a bNotify
3. Activar banner en bChat: "Rollback temporal — usar bRocket mientras se corrige el problema"
4. El historial en PostgreSQL queda intacto — la migración puede retomarse

El rollback **no recupera mensajes nuevos enviados en bChat durante las 72h** — estos quedan en PostgreSQL. Una vez estabilizado, el script de migración diferencial puede aplicarlos hacia atrás si se decide volver a bRocket (improbable).

---

## 6. Checklist de cierre definitivo de bRocket

- [ ] Script de migración ejecutó sin errores en staging con verificar_afirmacion.sh
- [ ] Script de migración ejecutó sin errores en producción con verificar_afirmacion.sh
- [ ] Todos los usuarios pueden autenticarse en bChat con JWT bAuth
- [ ] Historial completo accesible en bChat
- [ ] bNotify usa adaptador gRPC-bChat (sin llamadas REST a bRocket en logs)
- [ ] bRocket responde 503 durante 24h sin incidentes reportados
- [ ] StatefulSet rocketchat escalado a 0 réplicas
- [ ] MongoDB apagado y PVC eliminados
- [ ] Helm release bRocket desinstalado del namespace bns-messaging

---

*BNOTIFY-036 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*bRocket fue un interino que cumplió su misión. La migración no es un fracaso — es el plan desde el inicio.*
