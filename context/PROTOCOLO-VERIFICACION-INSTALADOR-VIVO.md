> **Procedencia (2026-07-03):** este protocolo vivía en la doctrina de la fábrica como
> ORQUESTA-047 v2.0. Al ser específico del proyecto SBOS (nspawn sbos-test-001, daemons,
> criterios C-01…C-08), se reubicó aquí según el Lote 4 de la actualización doctrinal.
> El patrón genérico quedó en la fábrica: doctrina/ORQUESTA-047 v3.0.
> Ejecutor actual: el rol Operador SBOS fue absorbido por el **Testeador** (ORQUESTA-040 v2.0).

# ORQUESTA-047 — Verificación del Instalador SBOS en Vivo, Reporte de Ayuda HITL y Certificación

**Versión:** 2.0  
**Fecha:** 2026-05-30  
**Estado:** ACTIVO  
**Categoría:** Protocolo Operacional — Testing y Certificación  
**Depende de:** ORQUESTA-040 (AA), ORQUESTA-046 (Observabilidad), ORQUESTA-031 (Checkpointing)  
**Aplica a:** Operador SBOS (puerto 8096), sbos-operador agent, HITL  

---

## Problema que resuelve

El instalador SBOS despliega 8 daemons interdependientes. Sin este protocolo ocurren tres fallos:

| Fallo | Síntoma | Consecuencia |
|---|---|---|
| Loop de corrección | Agente corrige A, rompe B, corrige B, rompe A | Tiempo infinito, código degradado |
| Silencio del agente | Se detiene pero no explica qué pasó | HITL no sabe qué hacer, proyecto bloqueado |
| Certificación sin evidencia | Reporta "exitoso" sin prueba verificable | Alucinación de resultado |

Este protocolo establece ocho mecanismos integrados:

| ID | Mecanismo | Qué resuelve |
|---|---|---|
| V-01 | 4 terminales en vivo | HITL ve el instalador en tiempo real |
| V-02 | Log ERRORS estructurado | Cada error documentado con correcciones propuestas |
| V-03 | Gate MAX_CORR | El agente no corrige indefinidamente |
| V-04 | Detección de loop | El mismo error no se repite más de MAX_LOOP veces |
| V-05 | Reporte de ayuda HITL | Cuando no puede resolver, redacta el problema con sugerencias |
| V-06 | Entorno nspawn-host-Calico | Pruebas reales con red Calico funcional |
| V-07 | Rutina falla-limpia-reinstala | Ciclo formal de prueba desde cero |
| V-08 | Certificación | SHA256 + Operador + Documentador integrado al instalador |

---

## Rutas canónicas (PFI Categoria A — el agente las crea)

```
compositor-agent/observabilidad/
├── instalador-MASTER.log          <- progreso general paso a paso
├── instalador-ERRORS.log          <- errores + correcciones + reportes ayuda HITL
├── instalador-DAEMON-STATUS.md    <- tabla de estado por daemon (watch -n 3)
├── instalador-LOOP-DETECTOR.json  <- historial de errores para deteccion de loop
└── instalador-AYUDA-HITL.md       <- reporte lenguaje natural cuando el agente no puede resolver
```

---

## V-01 — Las 4 terminales del HITL

El HITL abre estas terminales ANTES de iniciar cualquier ciclo de prueba:

```bash
# Terminal 1 — MASTER: progreso paso a paso
tail -f /opt/skull/orquestador/proyectos/fabrica/compositor-agent/observabilidad/instalador-MASTER.log

# Terminal 2 — ERRORS: errores, correcciones y reportes de ayuda
tail -f /opt/skull/orquestador/proyectos/fabrica/compositor-agent/observabilidad/instalador-ERRORS.log

# Terminal 3 — DAEMON STATUS: tabla actualizada cada 3 segundos
watch -n 3 'cat /opt/skull/orquestador/proyectos/fabrica/compositor-agent/observabilidad/instalador-DAEMON-STATUS.md'

# Terminal 4 — STREAM: actividad del agente (ORQUESTA-046)
tail -f /opt/skull/orquestador/proyectos/fabrica/compositor-agent/observabilidad/ACTIVIDAD-STREAM.md
```

### Formato del log MASTER

```
[2026-05-30 07:05:00] === INSTALADOR SBOS - CICLO 001 - nspawn sbos-test-001 ===
[2026-05-30 07:05:01] PASO 01/15 -> Verificar pre-requisitos del host
[2026-05-30 07:05:03] PASO 01/15 OK -- kernel 6.8.0, nspawn disponible, Calico activo en host
[2026-05-30 07:09:11] PASO 07/15 FALLO -- bkernel: WAL slot conflict
                       CORRECCIONES CONSUMIDAS: 2/3
                       LOOPS DETECTADOS: 2/2 AGOTADO
                       ACCION: Ver instalador-AYUDA-HITL.md -- esperando HITL
```

Regla AA-6: El agente nunca escribe OK sin output bash real + exit code 0.

---

## V-02 — Log ERRORS: errores con correcciones propuestas

```
[2026-05-30 07:09:11] == ERROR E-007 ===========================================
DAEMON:      bkernel
PASO:        07/15 -- configuracion WAL replication slot
CICLO:       001
ERROR EXACTO:
  ERROR: replication slot "bkernel_slot" already exists
COMANDO:     psql -U postgres -c "SELECT pg_create_logical_replication_slot(...)"
EXIT_CODE:   1
LOG EN DISCO: trazas/test-bkernel-20260530_070911.log
SHA256:      9a3f1c2e...
VECES VISTO: 3 (E-003 @ 07:12, E-005 @ 07:31, E-007 @ 07:45)

AGOTADO: LOOP CONFIRMADO (MAX_LOOP=2) + MAX_CORR=3 agotado
ACCION: Ver instalador-AYUDA-HITL.md -- agente detenido, esperando HITL
=============================================================
```

---

## V-03 — Gate de correccion: MAX_CORR

| Parametro | Valor | Descripcion |
|---|---|---|
| MAX_CORR_AUTO | 3 | Correcciones auto-aplicables por daemon por ciclo |
| MAX_CORR_TOTAL | 9 | Correcciones totales en un ciclo completo |
| MAX_LOOP | 2 | Veces que el mismo patron de error puede repetirse |
| MAX_ITER_CODIGO | 3 | Veces que se puede modificar codigo fuente del instalador |

### Tabla de decision por tipo de correccion

| Tipo de correccion | Auto-aplicar | Condicion |
|---|---|---|
| Instalar dependencia del SO (apt, dnf) | Auto | No modifica codigo |
| Cambiar variable de entorno o config | Auto | No modifica codigo |
| Reiniciar daemon | Auto | Reversible |
| Modificar codigo fuente (.go, .rs, .sh) | Siempre HITL | Puede causar regresion en cadena |
| DROP de recurso (slot, BD, tabla, volumen) | Siempre HITL | Destructivo |
| Rollback de paso | Siempre HITL | Destructivo |
| Modificar NetworkPolicy de Calico | Siempre HITL | Afecta conectividad de toda la red |

---

## V-04 — Deteccion de loop

El agente mantiene instalador-LOOP-DETECTOR.json y ejecuta este algoritmo
ANTES de cada correccion:

```bash
PATRON=$(extraer_patron_error "$ERROR_ACTUAL")
OCURRENCIAS=$(jq --arg p "$PATRON" \
  '[.errores[] | select(.patron == $p)] | length' \
  instalador-LOOP-DETECTOR.json)

if [ "$OCURRENCIAS" -ge "$MAX_LOOP" ]; then
  # NO CORREGIR -- redactar reporte de ayuda y detener
  generar_reporte_ayuda_hitl "$DAEMON" "$ERROR_ACTUAL" "$OCURRENCIAS"
  exit 0
fi
```

---

## V-05 — Reporte de ayuda HITL (mecanismo anti-silencio)

Cuando el agente no puede resolver, NUNCA se queda en silencio.
Redacta instalador-AYUDA-HITL.md con seis secciones obligatorias.

### Plantilla del reporte

```
# REPORTE DE AYUDA AL HITL
Generado:        2026-05-30 08:47:00
Agente:          sbos-operador
Sesion:          ses-20260530-001
Daemon afectado: bkernel
Ciclo:           001
Estado:          DETENIDO -- no puedo resolver sin tu ayuda

---

## 1. Que estaba intentando hacer (lenguaje natural)

Estaba instalando bkernel, el daemon que escucha el WAL de PostgreSQL
y propaga cambios entre los daemons. Para funcionar necesita crear un
"replication slot" en PostgreSQL -- un canal exclusivo para leer cambios.
El paso que fallo fue crear ese slot llamado "bkernel_slot".

---

## 2. Que paso exactamente

El error recibido es:
  ERROR: replication slot "bkernel_slot" already exists

Esto significa que el slot ya existe desde una instalacion anterior
(probablemente el ciclo 000 que fue interrumpido). Lo intente resolver
3 veces borrando y recreando el slot. Las 3 veces parecio funcionar
pero al avanzar al siguiente paso reaparecio el mismo error.

Esto indica que el problema NO es el slot en si, sino que el instalador
tiene un bug: no verifica si el slot existe antes de crearlo, y tampoco
limpia recursos entre ciclos de prueba.

Lo que intente y no funciono:
- Intento 1 (C-003): DROP slot + recrear -> OK aparente
- Intento 2 (C-005): DROP slot + recrear -> OK aparente
- Intento 3: igual -> mismo resultado -> detenido

---

## 3. Por que no puedo resolverlo solo

Para resolver esto correctamente necesito modificar el codigo fuente
del instalador. Segun AA-8, no puedo hacerlo sin tu aprobacion porque
una modificacion incorrecta puede romper los otros 7 daemons que
dependen de esta secuencia de instalacion.

---

## 4. Sugerencias para que investigues

Sugerencia principal (mas probable):
  El instalador necesita verificacion condicional antes de crear el slot.
  En PostgreSQL esto se hace asi:

    SELECT pg_create_logical_replication_slot('bkernel_slot', 'pgoutput')
    WHERE NOT EXISTS (
      SELECT 1 FROM pg_replication_slots WHERE slot_name = 'bkernel_slot'
    );

Terminos para buscar si quieres investigar mas:
  - "PostgreSQL logical replication slot idempotent creation"
  - "pg_create_logical_replication_slot IF NOT EXISTS"
  - "PostgreSQL WAL slot already exists installer"
  Documentacion: https://www.postgresql.org/docs/current/functions-admin.html

Causa alternativa (menos probable):
  Si el slot existe con el plugin incorrecto, borrar y recrear no es
  suficiente. Verificar con:
    SELECT slot_name, plugin FROM pg_replication_slots;

---

## 5. Lo que necesito que me digas

Elige una opcion y escribela en HITL-ALERTA.md:

  Opcion A: "Corrige el instalador con verificacion condicional"
  -> Modificare el script con el patron IF NOT EXISTS

  Opcion B: "Primero muestrame el diagnostico completo"
  -> Ejecutare SELECT * FROM pg_replication_slots y te muestro

  Opcion C: "Limpia todo y empieza el ciclo desde cero"
  -> Ejecutare la rutina falla-limpia-reinstala (V-07)

  Opcion D: Dame tu la solucion directamente
  -> La aplico exactamente como me la indiques

---

## 6. Estado actual del sistema

Ejecute esto para darte contexto:

  SELECT slot_name, plugin, active, restart_lsn FROM pg_replication_slots;
  RESULTADO: bkernel_slot | pgoutput | f | 0/1A3F200
  (slot existe, plugin correcto, NO activo -- slot huerfano confirmado)

  systemctl -M sbos-test-001 status bkernel
  RESULTADO: Unit bkernel.service not found (no llego a instalarse)

Checkpoints disponibles para rollback:
  cp-20260530_070500 -- inicio ciclo 001 (antes de cualquier instalacion)
  cp-20260530_071200 -- despues de postgresql y redis (estado limpio)
  Recomiendo rollback a: cp-20260530_071200 si eliges opcion C o D

Reporte generado por sbos-operador segun ORQUESTA-047 V-05
Para responder: escribe en compositor-agent/observabilidad/HITL-ALERTA.md
```

### Cuando se genera el reporte

| Situacion | Trigger |
|---|---|
| Loop confirmado (MAX_LOOP agotado) | Automatico al detectar 3ra ocurrencia del mismo patron |
| MAX_CORR agotado para un daemon | Automatico al llegar a correccion 3/3 |
| Correccion requiere modificar codigo | Antes de proponer cualquier cambio de codigo fuente |

---

## V-06 — Entorno nspawn-host-Calico para pruebas reales

### Por que nspawn y no contenedor comun

Calico CNI NO puede instalarse dentro de un contenedor Docker/Podman porque:
- Requiere acceso directo a interfaces de red del kernel del host
- Necesita instalar CNI plugins en /opt/cni/bin/ del host
- Requiere CAP_NET_ADMIN y CAP_SYS_ADMIN a nivel de nodo real
- Gestiona iptables/eBPF del kernel del host -- imposible desde contenedor aislado

La solucion: nspawn con red compartida con el host via --network-bridge.
El nspawn comparte el stack de red del host donde Calico ya esta instalado.

### Arquitectura del entorno de prueba

```
HOST (144.91.76.130)
├── Calico CNI instalado y activo (bird, felix, confd)
├── Kubernetes con Calico como CNI (si aplica)
└── nspawn: sbos-test-001
    ├── Ubuntu 26 limpio (rootfs en /var/lib/machines/sbos-test-001)
    ├── Red: --network-bridge=sbos-br0 (comparte red Calico del host)
    ├── Ve la red Calico del host como si fuera un nodo real del cluster
    ├── Instalador SBOS corre aqui
    └── Los daemons usan la red Calico del host directamente
```

### Preparacion del host (una sola vez)

```bash
# Verificar Calico activo en el host
calicoctl node status
# Debe mostrar: Calico process is running + BGP state

# Crear bridge para el nspawn
ip link add sbos-br0 type bridge 2>/dev/null || true
ip link set sbos-br0 up
ip addr add 10.89.0.1/24 dev sbos-br0 2>/dev/null || true

echo "Host preparado para nspawn con Calico"
```

### Verificacion de red Calico dentro del nspawn

```bash
# Verificar que el nspawn ve la red del host
systemd-nspawn --register=no --keep-unit \
  -M sbos-test-001 \
  -D /var/lib/machines/sbos-test-001 \
  --network-bridge=sbos-br0 \
  -- ip route show

# Debe mostrar las rutas de Calico del host
# La NetworkPolicy default-deny de Calico aplica al trafico del nspawn
```

### Tabla DAEMON-STATUS con estado de Calico

```
## ESTADO INSTALADOR SBOS -- 2026-05-30 09:15:33 -- CICLO 002

| Daemon      | Estado       | Paso   | Correcciones | Loops | Healthcheck  |
|-------------|-------------|--------|--------------|-------|--------------|
| pre-req     | OK           | 01/15  | 0/3          | 0     | N/A          |
| ubuntu-26   | OK           | 02/15  | 0/3          | 0     | N/A          |
| postgresql  | OK           | 03/15  | 0/3          | 0     | OK :5432     |
| redis       | OK           | 04/15  | 0/3          | 0     | OK PONG      |
| bos-core    | OK           | 05/15  | 1/3          | 0     | OK :8080     |
| bkernel     | EN CURSO     | 07/15  | 1/3          | 0     | pendiente    |
| bauth       | Esperando    | --     | 0/3          | 0     | --           |
| bhnexus     | Esperando    | --     | 0/3          | 0     | --           |
| banexus     | Esperando    | --     | 0/3          | 0     | --           |
| calico-net  | ACTIVO HOST  | N/A    | --           | --    | bird+felix   |

CICLO: 002 | CORRECCIONES TOTALES: 1/9 | LOOPS: 0
ESTADO GENERAL: EN PROGRESO
```

---

## V-07 — Rutina formal: falla -> limpia -> reinstala

Esta es la rutina canonica de prueba. Se ejecuta al inicio de cada ciclo
y cuando el HITL ordena REVERTIR o el agente detecta fallo irrecuperable.

### Paso 1 — FALLA: documentar antes de limpiar

```bash
CICLO_ANTERIOR=${1:-"001"}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ESTADO_LOG="compositor-agent/trazas/ciclo-${CICLO_ANTERIOR}-estado-final.log"

echo "=== ESTADO FINAL CICLO ${CICLO_ANTERIOR} ===" | tee "$ESTADO_LOG"

# Estado de cada daemon
for daemon in bos-core bkernel bauth bhnexus postgresql redis; do
  echo "--- ${daemon} ---" >> "$ESTADO_LOG"
  systemd-nspawn --register=no --keep-unit \
    -M sbos-test-001 -D /var/lib/machines/sbos-test-001 \
    -- systemctl status $daemon 2>&1 >> "$ESTADO_LOG" || true
done

# Logs de los ultimos 100 errores
journalctl -M sbos-test-001 --since "2 hours ago" -p err \
  >> "$ESTADO_LOG" 2>/dev/null || true

SHA256_ESTADO=$(sha256sum "$ESTADO_LOG" | cut -d' ' -f1)
echo "SHA256 estado final: ${SHA256_ESTADO}" | tee -a instalador-MASTER.log
```

### Paso 2 — LIMPIA: destruir el contenedor completamente

```bash
# Detener el nspawn
machinectl stop sbos-test-001 2>/dev/null || true
sleep 3
machinectl kill sbos-test-001 2>/dev/null || true

# Destruir rootfs completamente
ROOTFS=/var/lib/machines/sbos-test-001
if [ -d "$ROOTFS" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Eliminando rootfs: ${ROOTFS}" | tee -a instalador-MASTER.log
  rm -rf "$ROOTFS"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] rootfs eliminado" | tee -a instalador-MASTER.log
fi

# Limpiar slots de replicacion huerfanos
psql "postgresql://root@localhost:5402/SKDATA" << 'EOSQL'
DO $$
DECLARE slot_rec RECORD;
BEGIN
  FOR slot_rec IN
    SELECT slot_name FROM pg_replication_slots
    WHERE slot_name LIKE 'bkernel%' AND active = false
  LOOP
    PERFORM pg_drop_replication_slot(slot_rec.slot_name);
    RAISE NOTICE 'Dropped slot: %', slot_rec.slot_name;
  END LOOP;
END $$;
EOSQL

# Limpiar logs del ciclo anterior
echo "" > compositor-agent/observabilidad/instalador-MASTER.log
echo "" > compositor-agent/observabilidad/instalador-ERRORS.log
echo '{"errores":[],"loops_activos":[]}' \
  > compositor-agent/observabilidad/instalador-LOOP-DETECTOR.json

echo "[$(date '+%Y-%m-%d %H:%M:%S')] LIMPIEZA COMPLETA -- listo para nuevo ciclo" \
  | tee -a instalador-MASTER.log
```

### Paso 3 — REINSTALA: Ubuntu 26 limpio + instaladores

```bash
NUEVO_CICLO=${1:-"002"}
ROOTFS=/var/lib/machines/sbos-test-001
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "[${TIMESTAMP}] === CICLO ${NUEVO_CICLO} -- INICIO INSTALACION LIMPIA ===" \
  | tee -a instalador-MASTER.log

# 3.1 -- Ubuntu 26 limpio
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instalando Ubuntu 26 base..." | tee -a instalador-MASTER.log
debootstrap --arch=amd64 oracular "$ROOTFS" http://archive.ubuntu.com/ubuntu/

# 3.2 -- Configuracion minima
systemd-nspawn --register=no --keep-unit \
  -M sbos-test-001 -D "$ROOTFS" --network-bridge=sbos-br0 \
  -- bash -c "
    echo 'sbos-test-001' > /etc/hostname
    echo 'root:sbos-test' | chpasswd
    apt-get update -qq
    apt-get install -y -qq systemd systemd-resolved curl wget gnupg2 \
      libssl3 libssl-dev postgresql-client redis-tools jq
    systemctl enable systemd-resolved
  "
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ubuntu 26 base instalado" | tee -a instalador-MASTER.log

# 3.3 -- Copiar instaladores SBOS
INSTALADORES_SRC=/opt/skull/orquestador/proyectos/desarrollo/sbos/instalador
cp -r "$INSTALADORES_SRC" "$ROOTFS/opt/sbos-install/"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instaladores copiados" | tee -a instalador-MASTER.log

# 3.4 -- Registrar ciclo en SKDATA
psql "postgresql://root@localhost:5402/SKDATA" -c "
  INSERT INTO trazas.prueba_bos (ciclo_id, resultado)
  VALUES ('ciclo-${NUEVO_CICLO}', 'en-progreso');"

# 3.5 -- Ejecutar instalador dentro del nspawn (el HITL ve en Terminal 1)
systemd-nspawn --register=no --keep-unit \
  -M sbos-test-001 -D "$ROOTFS" --network-bridge=sbos-br0 \
  -- bash /opt/sbos-install/install-sbos.sh \
  2>&1 | tee compositor-agent/trazas/ciclo-${NUEVO_CICLO}-instalacion-${TIMESTAMP}.log

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Instalador completado -- ver log arriba" \
  | tee -a instalador-MASTER.log
```

---

## V-08 — Certificacion del instalador

### Criterios de certificacion (todos deben ser verdaderos)

| ID | Criterio | Verificacion | Evidencia |
|---|---|---|---|
| C-01 | Todos los daemons levantan | systemctl is-active = active | Log bash con exit 0 |
| C-02 | Healthchecks responden | curl /health retorna 200 | Output curl con codigo HTTP |
| C-03 | ctx_id se propaga | bos crea ctx_id, bkernel lo recibe, bauth lo valida | Log context.promoted |
| C-04 | Red Calico funcional | NetworkPolicy activa + daemons se alcanzan entre si | calicoctl + curl entre daemons |
| C-05 | WAL slot activo | bkernel_slot active=true en pg_replication_slots | SELECT active=true |
| C-06 | Redis responde | PING -> PONG en DB0, DB1, DB2 | redis-cli output |
| C-07 | Instalacion idempotente | Ejecutar instalador 2 veces = mismo resultado | Log de segunda ejecucion |
| C-08 | Rutina limpieza funciona | falla-limpia-reinstala sin errores | Log del ciclo de limpieza |

### Suite de certificacion (el Operador SBOS la ejecuta)

```bash
CICLO="002"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CERT_LOG="compositor-agent/trazas/certificacion-ciclo-${CICLO}-${TIMESTAMP}.log"
CERT_FALLO=false

echo "=== CERTIFICACION INSTALADOR SBOS -- CICLO ${CICLO} ===" | tee "$CERT_LOG"

# C-01: Todos los daemons activos
for daemon in bos-core bkernel bauth bhnexus postgresql redis; do
  STATUS=$(systemd-nspawn --register=no --keep-unit \
    -M sbos-test-001 -D /var/lib/machines/sbos-test-001 \
    -- systemctl is-active $daemon 2>&1)
  if [ "$STATUS" = "active" ]; then
    echo "C-01 OK ${daemon}: active" | tee -a "$CERT_LOG"
  else
    echo "C-01 FALLO ${daemon}: ${STATUS}" | tee -a "$CERT_LOG"
    CERT_FALLO=true
  fi
done

# C-02: Healthchecks
for spec in "bos-core:8080" "bkernel:8081" "bauth:8082"; do
  D=$(echo $spec | cut -d: -f1)
  P=$(echo $spec | cut -d: -f2)
  CODE=$(systemd-nspawn --register=no --keep-unit \
    -M sbos-test-001 -D /var/lib/machines/sbos-test-001 \
    -- curl -s -o /dev/null -w "%{http_code}" "http://localhost:${P}/health")
  if [ "$CODE" = "200" ]; then
    echo "C-02 OK ${D}/health: 200" | tee -a "$CERT_LOG"
  else
    echo "C-02 FALLO ${D}/health: ${CODE}" | tee -a "$CERT_LOG"
    CERT_FALLO=true
  fi
done

# C-03: ctx_id se propaga
CTX=$(systemd-nspawn --register=no --keep-unit \
  -M sbos-test-001 -D /var/lib/machines/sbos-test-001 \
  -- curl -s -X POST http://localhost:8080/api/v1/context/test \
     -H "Content-Type: application/json" -d '{"test":true}')
if echo "$CTX" | jq -e '.ctx_id' > /dev/null 2>&1; then
  echo "C-03 OK ctx_id: $(echo $CTX | jq -r '.ctx_id')" | tee -a "$CERT_LOG"
else
  echo "C-03 FALLO ctx_id no encontrado: ${CTX}" | tee -a "$CERT_LOG"
  CERT_FALLO=true
fi

# C-05: WAL slot activo
WAL=$(psql "postgresql://root@localhost:5432/postgres" -t -c \
  "SELECT active FROM pg_replication_slots WHERE slot_name='bkernel_slot';" \
  | tr -d ' ')
if [ "$WAL" = "t" ]; then
  echo "C-05 OK WAL slot bkernel_slot: activo" | tee -a "$CERT_LOG"
else
  echo "C-05 FALLO WAL slot: ${WAL}" | tee -a "$CERT_LOG"
  CERT_FALLO=true
fi

# C-06: Redis DB0, DB1, DB2
for db in 0 1 2; do
  PONG=$(redis-cli -n $db PING 2>/dev/null)
  if [ "$PONG" = "PONG" ]; then
    echo "C-06 OK Redis DB${db}: PONG" | tee -a "$CERT_LOG"
  else
    echo "C-06 FALLO Redis DB${db}: ${PONG}" | tee -a "$CERT_LOG"
    CERT_FALLO=true
  fi
done

# Resultado final con SHA256
SHA256_CERT=$(sha256sum "$CERT_LOG" | cut -d' ' -f1)
echo "SHA256: ${SHA256_CERT}" | tee -a "$CERT_LOG"

if [ "${CERT_FALLO}" = "true" ]; then
  RESULTADO="FALLIDO"
  echo "=== CERTIFICACION FALLIDA -- ver detalles arriba ===" | tee -a "$CERT_LOG"
else
  RESULTADO="CERTIFICADO"
  echo "=== INSTALADOR CERTIFICADO ===" | tee -a "$CERT_LOG"
fi

# Registrar en SKDATA
psql "postgresql://root@localhost:5402/SKDATA" -c "
  UPDATE trazas.prueba_bos
  SET resultado = '${RESULTADO}', sha256_master_log = '${SHA256_CERT}'
  WHERE ciclo_id = 'ciclo-${CICLO}';"
```

### Gate de certificacion

```
Si RESULTADO = CERTIFICADO:
  -> Operador SBOS invoca al Documentador con sha256_evidencia = SHA256_CERT
  -> Documentador genera los 3 manuales del instalador

Si RESULTADO = FALLIDO:
  -> Operador SBOS genera reporte de ayuda HITL (V-05)
  -> HITL decide: nueva iteracion PGE o rollback
  -> Documentador NO se invoca -- sin certificacion no hay documentacion
```

---

## Reglas AA-8 y AA-9 (anadir a ORQUESTA-040)

| Regla | Contenido |
|---|---|
| AA-8 | El agente NUNCA modifica codigo fuente sin aprobacion HITL. Una correccion de codigo sin aprobacion es equivalente a alucinacion -- el agente no puede garantizar que no introduce regresiones en los otros 7 daemons de SBOS. |
| AA-9 | El agente NUNCA se queda en silencio cuando no puede resolver. Si MAX_CORR o MAX_LOOP se agotan, genera inmediatamente instalador-AYUDA-HITL.md con: (1) que intentaba hacer, (2) que paso exactamente, (3) por que no puede resolverlo solo, (4) sugerencias con terminos de busqueda, (5) opciones concretas para que el HITL decida. El silencio del agente es un fallo de protocolo tan grave como la alucinacion. |

---

## DDL -- Extensiones a SKDATA (PFI Categoria B)

```sql
ALTER TABLE trazas.prueba_bos
  ADD COLUMN IF NOT EXISTS ciclo_id               TEXT,
  ADD COLUMN IF NOT EXISTS daemons_instalados      TEXT[],
  ADD COLUMN IF NOT EXISTS daemons_certificados    TEXT[],
  ADD COLUMN IF NOT EXISTS errores_encontrados     INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS correcciones_aplicadas  INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS loops_detectados        INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ayudas_hitl_generadas   INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS sha256_errors_log       TEXT,
  ADD COLUMN IF NOT EXISTS sha256_cert_log         TEXT;

CREATE TABLE IF NOT EXISTS trazas.error_instalador (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  prueba_bos_id         UUID REFERENCES trazas.prueba_bos(id),
  ciclo_id              TEXT NOT NULL,
  error_id              TEXT NOT NULL,
  daemon                TEXT NOT NULL,
  paso                  TEXT NOT NULL,
  patron_error          TEXT NOT NULL,
  comando_ejecutado     TEXT,
  output_error          TEXT,
  correccion_id         TEXT,
  correccion_tipo       TEXT CHECK (correccion_tipo IN ('auto','hitl','rollback','ninguna')),
  correccion_desc       TEXT,
  resultado             TEXT CHECK (resultado IN ('OK-real','OK-aparente','ESCALADO-HITL','PENDIENTE')),
  es_loop               BOOLEAN DEFAULT FALSE,
  ocurrencia_numero     INTEGER DEFAULT 1,
  ayuda_hitl_generada   BOOLEAN DEFAULT FALSE,
  timestamp             TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_error_instalador_patron ON trazas.error_instalador(patron_error, daemon);
CREATE INDEX idx_error_instalador_ciclo ON trazas.error_instalador(ciclo_id, timestamp DESC);
```

---

## Protocolo de autocorreccion -- como el agente aplica este documento

### Paso 1 -- Crear rutas (PFI Categoria A -- autonomo)
```bash
BASE=/opt/skull/orquestador/proyectos/fabrica
mkdir -p $BASE/compositor-agent/observabilidad
touch $BASE/compositor-agent/observabilidad/instalador-MASTER.log
touch $BASE/compositor-agent/observabilidad/instalador-ERRORS.log
touch $BASE/compositor-agent/observabilidad/instalador-DAEMON-STATUS.md
touch $BASE/compositor-agent/observabilidad/instalador-AYUDA-HITL.md
echo '{"errores":[],"loops_activos":[]}' \
  > $BASE/compositor-agent/observabilidad/instalador-LOOP-DETECTOR.json
```

### Paso 2 -- Actualizar RUTAS-CANONICAS.md (PFI Categoria A)
Anadir las 5 rutas nuevas del instalador.

### Paso 3 -- Actualizar sbos-operador.md (PFI Categoria B -- requiere confirmacion HITL)
Anadir al agente: flujo de escritura en los 4 logs, algoritmo de deteccion
de loop, tabla de decision por tipo de correccion, plantilla del reporte
de ayuda HITL, rutina falla-limpia-reinstala, suite de certificacion C-01 a C-08.

### Paso 4 -- Anadir AA-8 y AA-9 a ORQUESTA-040 (PFI Categoria B)
Mostrar diff antes de aplicar.

### Paso 5 -- Ejecutar DDL (PFI Categoria B -- requiere confirmacion HITL)
Mostrar el ALTER TABLE y CREATE TABLE al HITL antes de ejecutar.

### Paso 6 -- Actualizar ORQUESTA-000-INDEX.md (PFI Categoria B)
Anadir ORQUESTA-047 al grupo 9 (Especializacion -- Testing).

### Paso 7 -- Commit (PFI Categoria A -- tras pasos B completados)
```bash
git add compositor-agent/observabilidad/
git add context-fabrica/doctrina/ORQUESTA-047-VERIFICACION-INSTALADOR-VIVO.md
git add context-fabrica/protocolos/RUTAS-CANONICAS.md
git commit -m "feat(orquesta-047): instalador en vivo + ayuda HITL + nspawn-Calico + certificacion"
git push
```

---

## Resumen de cambios

| Cambio | PFI | Documentos afectados |
|---|---|---|
| 5 archivos en observabilidad/ | A | RUTAS-CANONICAS.md |
| Flujo completo en sbos-operador.md | B | .claude/agents/sbos-operador.md |
| AA-8 y AA-9 | B | ORQUESTA-040 |
| DDL error_instalador + ALTER prueba_bos | B | SKDATA schemas |
| ORQUESTA-047 en indice maestro | B | ORQUESTA-000-INDEX.md |
| Commit | A (tras B) | git |

---
Para detalles normativos base: ORQUESTA-040 (AA), ORQUESTA-046 (Observabilidad),
ORQUESTA-031 (Checkpointing), ORQUESTA-042 (PFI), SBOS-MANUAL-ACOPLAMIENTO v2.0.
