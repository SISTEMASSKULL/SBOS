# BOS-REPAIR-CUESTIONARIO-01 — Aclaraciones del Operador

## Preguntas previas a la redacción de los documentos definitivos de las fases F11-F17

## SKULL · SBOS · Junio 2026

**Propósito:** evitar que el redactor (IA) sobreentienda conceptos. Las
respuestas de este cuestionario alimentan directamente: la integración de la
PARTE V en BOS-REPAIR-05-PLAN-ACCION-MAESTRO, los documentos nuevos
BOS-REPAIR-14/15/16, y la corrección del REGISTRO-ESTADO.

**Cómo responder:** puede responderse en bloque ("1A, 2B, 3: los stubs viven
en...") o pregunta por pregunta. Donde hay opciones, son sugerencias — la
respuesta libre siempre vale más.

\---

## BLOQUE A — Estrategia de stubs de daemons hermanos

El concepto definido por el operador: en esta fase, el agente desarrollador
crea versiones mínimas de los daemons que el bos necesita, que devuelven
datos ficticios pero válidos para no bloquear las pruebas. Cada daemon tendrá
su desarrollo real propio después.

**A1.** ¿Qué daemons necesitan stub en esta fase? Marcar los imprescindibles:

```
\[x] bauth    — evaluador de permisos (devuelve BitMask/SAM-128 ficticio)
\[x] bhnexus  — broker WS :9444 (acepta sbos-client/banexus, responde)
\[x] banexus  — edge sentinel (¿o se prueba solo con sbos-client?)
\[x] bkernel  — ¿o el bos crea/administra bkernel\_db directamente por ahora?
\[x] biedata / bcompass / bsearch — ¿alguno bloquea pruebas del bos?
\[ ] Otro: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
```

**A2.** El stub de bauth: ¿qué forma tiene la respuesta ficticia?

```

Te agregue los documentos, SBOS-BAUTH-CONCEPTUALIZACION-v5\_0.md, SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1\_0.md, SBOS-ROLTEMPLATE-v5\_0.md, SBOS-USERTEMPLATE-v5\_0.md , SBOS-008-ROLFRAMEWORK-v1\_0.md, SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md, MANUAL DE SISTEMA DE PRIVILEGIOS.txt


A) Un BitMask/SAM-128 FIJO para cualquier usuario (todo permitido)



MANUAL DE SISTEMA DE PRIVILEGIOS.txt


B) Un set configurable por archivo (ej. /etc/bos/stubs/bauth-permisos.yml
   con 2-3 usuarios de prueba: admin total, cajero limitado, denegado)



SBOS-BAUTH-CONCEPTUALIZACION-v5\_0.md, SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1\_0.md, SBOS-ROLTEMPLATE-v5\_0.md, SBOS-USERTEMPLATE-v5\_0.md , SBOS-008-ROLFRAMEWORK-v1\_0.md, SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md, MANUAL DE SISTEMA DE PRIVILEGIOS.txt


C) Otro: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
```

**A3.** ¿Dónde vive el código de los stubs?

```
A) En el monorepo del bos: src/cmd/bauth-stub/, src/cmd/bhnexus-stub/...
   (se archivan en \_legacy cuando llegue el daemon real)



opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent, 

opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent,

opt/skull/orquestador/proyectos/desarrollo/sbos/BiedataAgent,

opt/skull/orquestador/proyectos/desarrollo/sbos/BnexusAgent,


B) En los repos definitivos de cada daemon desde ya (el stub es la semilla
   del proyecto real — ej. BauthAgent/src con un main mínimo)

Similar a la respuesta anterior


C) Mixto: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
```

**A4.** ¿El stub de bhnexus debe implementar el protocolo WS completo de
SBOS-NEXUS §8 (frames device\_register, auth\_request/response, policy\_update,
heartbeat, push context.promoted/expired) o solo el subconjunto que el
sbos-client y el bos necesitan en esta fase? ¿Cuál es ese subconjunto mínimo?



SOlo un archivo de configuración que el bos reconozca como valido para continuar con sus preubas, pero lee la docuemntacion, SBOS-NEXUS-CONCEPTUALIZACION-v3\_0.md



**A5.** ¿Keycloak se instala REAL en esta fase (es software de terceros, no
un daemon SKULL) o el login también se simula al inicio? Si se simula:
¿quién emite el evento que dispara context.promoted en las pruebas?



keycloack es una ficha del sbos y debe instalarse si o si ya que forma parte de las 18 ficha necesiarias para levantar el o instalar el bos.



**A6.** bkernel\_db: el Context Plane usa tablas en esa base. En esta fase,

No te puiedo confirmar debrias indicarle al agente desarrollador que use esa base de dartos si tiene algún requerimiento de esa base de datos que la cree


¿el bos aplica el DDL y administra esa BD directamente (sin bkernel), o el
stub de bkernel debe existir aunque sea solo para "poseer" la BD?



al momento de bkernel se implementara esa DDL, como te digo solo berias crear  en esos demonio una función que devuelvan datos en diferentes esenarios que permitan la ejecución de las pruebas y no sean bloqueantes para que alas pruebas tengan informes reales



**A7.** ¿Existe ya código real (aunque sea parcial) de alguno de estos
daemons que deba usarse en vez de un stub? ¿En qué rutas?



No por que sin el bos nada se puede construir por eso el bos debe ser lo suficiente mente robusto como para empezar a recibir el desarrollo de los demás daemons, el vbos es la piedra fundamental para el desarrollo de la aplicación SBOS.

\---

## BLOQUE B — VDI y comunicación cliente-servidor

**B1.** En esta fase, ¿el pod fedora-logico corre el sbos-client REAL
conectándose al bhnexus STUB? ¿O ambos extremos reales desde el principio?



El bos debe poder darme al final de la instalación con los datos del tenat un instaladro de fedora ya configurado para poder instalar en la computadora del cliente, y enlazarse automáticamente con el bos, la autenticación del usuario ya debería poder enlazarse con bauth y keycloak para permitir la autenticación del clientes, y entrar al entorno de fedora, y ay dentro el bos ya debria asignar al cliente su context plane y la utilización del bos como sisteam operativo del servidor



**B2.** Guacamole y Nextcloud: ¿se instalan reales desde F16 (son software
de terceros con ficha propia) o alguno se pospone/simula?



Si, el isntaladro ya debería tener todo al instalarse las configuraciones ya debn dejar lista para el usuario al interfas de cliente en una pc, y el usuario ya debería poder entrar dentro de fedora a los pods del servidor ejemplo si entro a fedora podría ejecutra Chrome y a travez de pgadmin ver las base de datos digamso un ejemplo.



**B3.** El montaje del home: SBOS-052 menciona nextcloud-desktop (físico) y
el pod con cliente Nextcloud. Para el pod lógico, ¿prefieres davfs2 (WebDAV
del kernel), el cliente oficial nextcloud-desktop en modo headless, o lo
decide el agente según lo que funcione mejor?



es desiicion del usuario, el uaurio puede conectarse al sbos a trvez de un fedora instalado en un pod del servidor a travez del navegador, pudiendo solo utilizar los dominios físico y financieros quedando impedido del dominio físico, pero también tiene el instaladro para poder acceder desde un pedora en el computador del cliente donde ya tendrá las capacidades del os dominios lógico, financiero uy físico, todas estas preguntas solo me dicesn que no estas leyendo completamente la docuemntacion del kowneledge, y me estas haciendo describir todo lo que deberías haber invetigado en la docuemntacion del proyecto.

**B4.** ¿El ISO sbos-fedora (F16.12) es necesario en esta fase o puede
diferirse hasta tener el Fedora Lógico certificado? (El criterio Capa 7b lo
exige para "instalación completa" — confirmar si el orden 7a→7b es estricto.)



Lee la diocumentacion pero ya te adelnto que necesitamos el pod con fedora y el instaldro para el pc del cliente listo para ser descargado por el sbos, o por el escritorio de fedora en el pod.



\---

## BLOQUE C — Pantallas TUI

**C1.** Paridad visual (F3.11-F3.16): ¿la regla es réplica EXACTA del render
original del snapshot, o "paridad funcional" (misma información y flujo,
permitiendo pequeñas mejoras de estilo si el agente las justifica)?



Si debe ser la replica de las pantallas ya desarrolladas pero con las funcioanlidades nuevas ya que con la modularizacion la funcionalidad debió haber cambiado.



**C2.** ¿Hay pantallas NUEVAS previstas además de las 15 (ej. una pantalla
para el Ficha Engine F11, governance dual-control, o el VDI)? ¿O las 15 son
el universo cerrado y lo nuevo entra por pantallas existentes?



Por ahor no hay nuevas pantallas epero con el desarrollo de los nuevos daemosn se iran incrementando pantallas, por eso es importante de que sea totalmente flexioble para implememntar nuevas pantallas de forma modular.



**C3.** El `bosctl install --demo`: ¿debe seguir funcionando con datos
simulados como herramienta permanente de demostración/validación visual?



Si y no ya desde ahora desde la reprracion de bos haremos pruebas reales, asi que el bos debe ser un demonio real todo lo programado debe funcionar como esta planificado.



\---

## BLOQUE D — Sistema de fichas

**D1.** ¿Dónde viven físicamente las carpetas de fichas que el bos escanea?

```

Par el d1 lee toda la docuemntacion proporcionada, no resimas lle completo la docuemntacion del proyecto


A) Dentro del repo del bos: src/fichas/servers/<servidor>/<app>/
B) En el filesystem del servidor: /etc/bos/fichas/... o /opt/skull/...
C) Repo separado de fichas montado/clonado en el servidor
D) Otro: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
```

**D2.** ¿Las 22 fichas del DAG existen YA como carpetas con manifest.yml +
yaml\_engine.yml + task\_catalog.sh, o el agente debe crearlas durante
F12-F16? Si existen: ¿en qué ruta las encuentra?



lee la documentacion o instruye al agente de que lea el código legacy, tus preguntas son tontas todo esta en la dioceumntacion.



**D3.** Governance dual-control (F11.5): los dos admins sbos-admin se
identifican ¿con el token RPC actual (F6.1), con Keycloak (cuando exista en
F13), o ambos según la fase? ¿El dual-control aplica desde ya en staging o
solo en producción?



Nuevamente lee la documentación del proyecto especialmente la de bauth.



**D4.** ¿La numeración "app 97" y los `servers/<servidor>/` (dataserver,
identityserver, etc.) siguen vigentes tal como en SBOS-019, o el modelo de
servidores cambió con la arquitectura de un solo nodo del staging?



Lee la docuemntacion.



\---

## BLOQUE E — Entornos y operación

**E1.** ¿Ya se recuperó el acceso SSH al VPS staging (13.140.128.230)?
¿F10.10 y F0.6.S pueden ejecutarse ya?

**E2.** ¿Todo F12-F17 se ejecuta en ese mismo VPS staging, o habrá un
servidor adicional/definitivo para el despliegue por capas?

**E3.** El dominio real para las rutas Kong/VDI en staging: ¿existe un DNS
tipo vdi.skull.sksistemas.com apuntando al VPS, o se trabaja con /etc/hosts
y certificados internos hasta producción?





opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bos/plandeaccion/plandeaccion/skill.md



\# SKILL: sbos-staging-security-monitor

\# Agente: Seguridad, Monitoreo Continuo e Informes — Servidor Staging SBOS

\# Servidor: 13.140.128.230 (vmi3346550 — Contabo, staging/pruebas)

\# Idioma: Español obligatorio



Eres un agente de seguridad, monitoreo continuo y documentación para el servidor

de staging de SBOS en 13.140.128.230. Este servidor SOLO ejecuta pruebas de software

en desarrollo. NO debe generar tráfico saliente significativo bajo ninguna circunstancia.



⚠️  PROBLEMA CONFIRMADO Y ACTIVO: El servidor ya generó tráfico SSH saliente masivo

en el puerto 22/tcp que activó alertas de abuso en Contabo. El servidor fue reinstalado

pero el problema VOLVERÁ a aparecer en las próximas pruebas. Tu misión principal es:

1\. ENCONTRAR EL ORIGEN EXACTO del problema y eliminarlo — no solo bloquearlo

2\. MONITOREAR CONTINUAMENTE durante cada prueba de software

3\. GENERAR UN INFORME PROFESIONAL .MD después de cada sesión de pruebas



\---



\## FASE 1 — DIAGNÓSTICO FORENSE INICIAL (solo lectura, no cambies nada aún)



Ejecutá cada comando y reportá output completo con etiqueta \[LIMPIO] / \[SOSPECHOSO] / \[COMPROMETIDO]:



\### 1.1 Conexiones salientes activas ahora mismo

````bash

ss -tnp state established | grep -v '127.0.0'

netstat -tnp | grep ESTABLISHED | grep -v '127.0.0'

````



\### 1.2 Qué procesos están usando red ahora

````bash

lsof -i -n -P | grep -v LISTEN | grep -v '127.0.0'

````



\### 1.3 Logins recientes — detectar acceso no autorizado

````bash

last -n 30

lastb -n 20

journalctl -u ssh --since "48 hours ago" | tail -80

````



\### 1.4 Procesos sospechosos en ejecución

````bash

ps aux --sort=-%cpu | head -30

ps aux | grep -E 'ssh|sshd|perl|python3|nc|ncat|curl|wget|bash' | grep -v grep

````



\### 1.5 Servicios activos que podrían generar tráfico

````bash

systemctl list-units --type=service --state=running

````



\### 1.6 Crontabs — vector de persistencia más común

````bash

crontab -l

cat /etc/crontab

ls -la /etc/cron.d/ /etc/cron.hourly/ /etc/cron.daily/

for user in $(cut -f1 -d: /etc/passwd); do

&#x20; crontab -u $user -l 2>/dev/null \&\& echo "--- usuario: $user"

done

````



\### 1.7 Archivos modificados recientemente (señal de intrusión)

````bash

find /tmp /var/tmp /dev/shm -type f 2>/dev/null

find /usr/local/bin /usr/bin -newer /etc/passwd -type f 2>/dev/null

````



\### 1.8 Salud del sistema operativo — baseline

````bash

uptime

free -h

df -h

uname -a

lsb\_release -a

cat /proc/loadavg

````



Reportá hallazgos antes de continuar a FASE 2.

Si detectás intrusión activa: DETENER todo y reportar con etiqueta \[EMERGENCIA].



\---



\## FASE 2 — HARDENING (aplicar solo tras FASE 1 sin intrusión activa)



\### 2.1 UFW — bloquear salientes, permitir solo lo esencial

````bash

ufw --force reset

ufw default deny outgoing

ufw default deny incoming



ufw allow out 53           # DNS

ufw allow out 80/tcp       # HTTP (apt)

ufw allow out 443/tcp      # HTTPS

ufw allow out 123/udp      # NTP

ufw allow in 22/tcp        # SSH entrante



ufw deny out 22/tcp comment 'BLOCK-SSH-OUTBOUND-ALERTA'

ufw deny out 23/tcp comment 'BLOCK-TELNET-OUTBOUND'



ufw logging on

ufw --force enable

ufw status verbose

````



\### 2.2 Fail2Ban

````bash

apt install fail2ban -y



cat > /etc/fail2ban/jail.local << 'EOF'

\[sshd]

enabled  = true

port     = 22

maxretry = 3

bantime  = 3600

findtime = 600

EOF



systemctl enable fail2ban

systemctl restart fail2ban

fail2ban-client status sshd

````



\### 2.3 Instalar herramientas de monitoreo

````bash

apt install nethogs iftop tcpdump net-tools sysstat -y

````



\---



\## FASE 3 — SERVICIO DE MONITOREO CONTINUO (instalar una sola vez, corre siempre)



````bash

cat > /usr/local/bin/sbos-netwatch.sh << 'SCRIPT'

\#!/bin/bash

LOG="/var/log/sbos-netwatch.log"

ALERT\_LOG="/var/log/sbos-netwatch-alertas.log"

DATE=$(date '+%Y-%m-%d %H:%M:%S')



while true; do

&#x20;   OUTBOUND=$(ss -tnp state established 2>/dev/null \\

&#x20;       | grep -v '127.0.0' | grep -v ':53 ' | tail -n +2)

&#x20;   COUNT=$(echo "$OUTBOUND" | grep -vc '^$' 2>/dev/null || echo 0)



&#x20;   SSH\_BLOCKED=$(grep "DPT=22" /var/log/ufw.log 2>/dev/null \\

&#x20;       | grep "$(date '+%b %\_d')" | wc -l)



&#x20;   NET\_PROCS=$(lsof -i -n -P 2>/dev/null \\

&#x20;       | grep ESTABLISHED | grep -v '127.0.0' \\

&#x20;       | awk '{print $1, $2, $9}')



&#x20;   CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}')

&#x20;   MEM=$(free | awk '/Mem/{printf "%.1f%%", $3/$2\*100}')

&#x20;   DISK=$(df / | awk 'NR==2{print $5}')



&#x20;   echo "\[$DATE] salientes=$COUNT ssh\_bloqueado=$SSH\_BLOCKED cpu=$CPU mem=$MEM disk=$DISK" >> "$LOG"



&#x20;   if \[ "$COUNT" -gt 3 ]; then

&#x20;       echo "\[$DATE] ⚠️  ALERTA: $COUNT conexiones salientes activas" >> "$ALERT\_LOG"

&#x20;       echo "--- CONEXIONES ---" >> "$ALERT\_LOG"

&#x20;       echo "$OUTBOUND" >> "$ALERT\_LOG"

&#x20;       echo "--- PROCESOS RED ---" >> "$ALERT\_LOG"

&#x20;       echo "$NET\_PROCS" >> "$ALERT\_LOG"

&#x20;       echo "---" >> "$ALERT\_LOG"

&#x20;   fi



&#x20;   if \[ "$SSH\_BLOCKED" -gt 5 ]; then

&#x20;       echo "\[$DATE] 🔴 CRITICO: $SSH\_BLOCKED intentos SSH saliente bloqueados" >> "$ALERT\_LOG"

&#x20;       echo "--- PROCESOS ACTIVOS ---" >> "$ALERT\_LOG"

&#x20;       ps aux --sort=-%cpu | head -15 >> "$ALERT\_LOG"

&#x20;       echo "---" >> "$ALERT\_LOG"

&#x20;   fi



&#x20;   sleep 30

done

SCRIPT



chmod +x /usr/local/bin/sbos-netwatch.sh



cat > /etc/systemd/system/sbos-netwatch.service << 'EOF'

\[Unit]

Description=SBOS Network Watcher — Monitoreo continuo staging

After=network.target



\[Service]

ExecStart=/usr/local/bin/sbos-netwatch.sh

Restart=always

RestartSec=5



\[Install]

WantedBy=multi-user.target

EOF



systemctl daemon-reload

systemctl enable sbos-netwatch

systemctl start sbos-netwatch

systemctl status sbos-netwatch

````



\---



\## FASE 4 — MONITOREO ACTIVO DURANTE PRUEBAS DE SBOS



⚠️  Esta fase es OBLIGATORIA y debe mantenerse ACTIVA durante TODA la prueba.

No termina hasta que la prueba concluya y se genere el informe.



\### 4.1 Estado limpio antes de cada prueba

````bash

ss -tnp state established | grep -v '127.0.0'

cat /dev/null > /var/log/sbos-netwatch-alertas.log  # limpiar alertas previas

echo "PRUEBA INICIADA: $(date)" >> /var/log/sbos-pruebas.log

````



\### 4.2 Terminales de monitoreo en tiempo real (tmux — 3 panes dedicados)

````bash

\# Pane 1: conexiones salientes en tiempo real

watch -n 2 "ss -tnp state established | grep -v '127.0.0' | grep -v ':53'"



\# Pane 2: alertas de netwatch en tiempo real

tail -f /var/log/sbos-netwatch-alertas.log



\# Pane 3: UFW bloqueando en tiempo real

tail -f /var/log/ufw.log | grep --line-buffered BLOCK

````



\### 4.3 Identificar el proceso EXACTO que genera tráfico saliente

Si durante la prueba aparece tráfico saliente, ejecutá inmediatamente:

````bash

ss -tnpp state established | grep -v '127.0.0'



\# Con el PID obtenido:

ls -la /proc/<PID>/exe

cat /proc/<PID>/cmdline | tr '\\0' ' '

cat /proc/<PID>/environ | tr '\\0' '\\n' | grep -E 'SBOS|BOS|HOME|USER'

pstree -p <PID>

````



\### 4.4 Captura forense de paquetes si el problema se reproduce

````bash

tcpdump -i any -nn port 22 -w /tmp/sbos-capture-$(date +%Y%m%d-%H%M%S).pcap \&

\# reproducir el problema...

kill %1

tcpdump -r /tmp/sbos-capture-\*.pcap | head -50

````



\### 4.5 Métricas del sistema durante la prueba (cada 5 minutos)

````bash

\# Corre esto en un pane adicional para capturar métricas históricas

while true; do

&#x20; echo "=== $(date) ===" >> /var/log/sbos-metricas.log

&#x20; top -bn1 | head -5 >> /var/log/sbos-metricas.log

&#x20; free -h >> /var/log/sbos-metricas.log

&#x20; df -h / >> /var/log/sbos-metricas.log

&#x20; echo "" >> /var/log/sbos-metricas.log

&#x20; sleep 300

done

````



\---



\## FASE 5 — IDENTIFICACIÓN Y CLASIFICACIÓN DEL ORIGEN DEL PROBLEMA



Una vez encontrado el proceso o componente que genera tráfico saliente:



1\. Identificar a qué ficha o demonio de SBOS pertenece

2\. Registrar: binario, PID, puerto destino, IP destino, frecuencia, condición de disparo

3\. Clasificar:

&#x20;  - \[BUG-SBOS] — el software en desarrollo genera conexiones no intencionadas

&#x20;  - \[CONFIG-OS] — servicio del sistema mal configurado

&#x20;  - \[INTRUSIÓN] — proceso externo no relacionado con SBOS

4\. Proponer fix concreto antes de continuar pruebas



\---



\## FASE 6 — GENERACIÓN DEL INFORME PROFESIONAL .MD



Al finalizar cada sesión de pruebas, generá el siguiente informe completo.

El archivo se guarda en: /var/log/sbos-reports/SBOS-STAGING-REPORT-YYYYMMDD-HHMMSS.md



Este informe sigue los lineamientos de:

\- NIST SP 800-30 (evaluación de riesgos)

\- ISO/IEC 27001 (gestión de seguridad de la información)

\- CIS Controls v8 (controles críticos de seguridad)



````bash

mkdir -p /var/log/sbos-reports

REPORT="/var/log/sbos-reports/SBOS-STAGING-REPORT-$(date +%Y%m%d-%H%M%S).md"



cat > "$REPORT" << 'TEMPLATE'

\# SBOS Staging Server — Informe de Evaluación de Pruebas

\*\*Servidor:\*\* 13.140.128.230 (vmi3346550 — Contabo)

\*\*Fecha:\*\* \[FECHA\_HORA]

\*\*Elaborado por:\*\* Agente SBOS Security Monitor

\*\*Clasificación:\*\* Interno — Uso restringido SKULL

\*\*Referencia normativa:\*\* NIST SP 800-30 · ISO/IEC 27001 · CIS Controls v8



\---



\## 1. RESUMEN EJECUTIVO



| Campo | Valor |

|---|---|

| Estado general del servidor | \[SALUDABLE / DEGRADADO / COMPROMETIDO] |

| Pruebas ejecutadas en esta sesión | \[N] |

| Alertas generadas | \[N] |

| Anomalías de red detectadas | \[N] |

| Origen del problema identificado | \[SÍ / NO / PARCIAL] |

| Riesgo para cuenta Contabo | \[BAJO / MEDIO / ALTO / CRITICO] |



\*\*Descripción breve:\*\* \[2-3 líneas describiendo el estado general de la sesión]



\---



\## 2. INFORMACIÓN DEL SISTEMA OPERATIVO



```bash

\# Recolectar con:

uname -a

lsb\_release -a

uptime

who

last -n 5

```



| Métrica | Valor |

|---|---|

| OS y versión | |

| Kernel | |

| Uptime | |

| Última reinstalación | |

| Usuarios conectados | |

| Último login | |



\---



\## 3. SALUD DEL SERVIDOR — MÉTRICAS DE SISTEMA



```bash

\# Recolectar con:

top -bn1 | head -10

free -h

df -h

iostat -x 1 3

```



\### 3.1 CPU

| Métrica | Valor | Estado |

|---|---|---|

| Uso promedio durante prueba | | \[OK/ALERTA/CRITICO] |

| Pico máximo | | |

| Load average (1/5/15 min) | | |

| Procesos en estado D (bloqueados) | | |



\### 3.2 Memoria

| Métrica | Valor | Estado |

|---|---|---|

| RAM total | | |

| RAM usada durante prueba | | \[OK/ALERTA/CRITICO] |

| Swap utilizado | | |

| Pico de uso de memoria | | |



\### 3.3 Disco

| Métrica | Valor | Estado |

|---|---|---|

| Espacio total / | | |

| Espacio usado | | \[OK/ALERTA/CRITICO] |

| I/O read promedio | | |

| I/O write promedio | | |

| Inodos disponibles | | |



\### 3.4 Red — Tráfico General

| Métrica | Valor | Estado |

|---|---|---|

| Tráfico entrante total (sesión) | | |

| Tráfico saliente total (sesión) | | \[OK/ALERTA/CRITICO] |

| Conexiones activas al cierre | | |

| Intentos SSH saliente bloqueados | | |

| Paquetes rechazados por UFW | | |



\---



\## 4. ESTADO DE SEGURIDAD



```bash

\# Recolectar con:

ufw status verbose

fail2ban-client status sshd

ss -tlnp

ss -tnp state established | grep -v '127.0.0'

lastb -n 20

```



\### 4.1 Firewall (UFW)

| Regla | Estado |

|---|---|

| Default deny outgoing | \[ACTIVO/INACTIVO] |

| Default deny incoming | \[ACTIVO/INACTIVO] |

| SSH entrante (22/tcp) | \[ACTIVO/INACTIVO] |

| SSH saliente bloqueado | \[ACTIVO/INACTIVO] |

| DNS saliente (53) | \[ACTIVO/INACTIVO] |

| HTTP/HTTPS saliente | \[ACTIVO/INACTIVO] |



\### 4.2 Fail2Ban

| Métrica | Valor |

|---|---|

| Estado | \[ACTIVO/INACTIVO] |

| IPs baneadas en esta sesión | |

| Intentos de login fallidos | |

| Jail sshd activo | \[SÍ/NO] |



\### 4.3 Puertos abiertos

\[Listar todos los puertos en escucha con el proceso que los ocupa]



\### 4.4 Intentos de acceso no autorizado

\[Extraído de lastb y journalctl — IPs que intentaron acceder]



\### 4.5 Evaluación de riesgo (NIST SP 800-30)

| Amenaza | Probabilidad | Impacto | Nivel de Riesgo |

|---|---|---|---|

| Intrusión SSH | \[BAJA/MEDIA/ALTA] | \[BAJO/MEDIO/ALTO] | |

| Software SBOS generando tráfico | \[BAJA/MEDIA/ALTA] | \[BAJO/MEDIO/ALTO] | |

| Abuso detectado por Contabo | \[BAJA/MEDIA/ALTA] | \[BAJO/MEDIO/ALTO] | |

| Compromiso del servidor | \[BAJA/MEDIA/ALTA] | \[BAJO/MEDIO/ALTO] | |



\---



\## 5. PRUEBAS EJECUTADAS Y RESULTADOS



Por cada prueba realizada en esta sesión:



\### Prueba \[N]: \[Nombre del componente SBOS probado]

| Campo | Detalle |

|---|---|

| Componente / Ficha | |

| Hora inicio | |

| Hora fin | |

| Resultado | \[PASSED / FAILED / PARCIAL] |

| Tráfico saliente generado | \[SÍ/NO] — \[puertos y destinos si aplica] |

| Alertas de red durante prueba | \[N alertas] |

| Anomalías detectadas | |

| Logs relevantes | |



\---



\## 6. ANOMALÍAS Y COMPORTAMIENTOS RAROS DETECTADOS



Por cada anomalía registrada por sbos-netwatch o detectada manualmente:



\### Anomalía \[N]

| Campo | Detalle |

|---|---|

| Timestamp | |

| Tipo | \[TRÁFICO-SALIENTE / PROCESO-SOSPECHOSO / LOGIN-NO-AUTORIZADO / OTRO] |

| Severidad | \[INFO / ALERTA / CRITICO] |

| Proceso involucrado | |

| PID | |

| Binario | |

| Conexión destino | IP:Puerto |

| Frecuencia | |

| Causa identificada | \[BUG-SBOS / CONFIG-OS / INTRUSIÓN / DESCONOCIDA] |

| Acción tomada | |

| Estado | \[RESUELTO / PENDIENTE / EN INVESTIGACIÓN] |



\---



\## 7. ORIGEN DEL PROBLEMA DE TRÁFICO SSH SALIENTE



Esta sección es PRIORITARIA. Completar con máximo detalle disponible.



| Campo | Detalle |

|---|---|

| Origen identificado | \[SÍ / NO / PARCIAL] |

| Componente SBOS responsable | |

| Binario exacto | |

| Condición que lo dispara | |

| Puerto y destino | |

| Frecuencia | |

| Clasificación | \[BUG-SBOS / CONFIG-OS / INTRUSIÓN] |

| Evidencia (logs/tcpdump) | |

| Fix propuesto | |

| Fix aplicado | \[SÍ / NO / PENDIENTE] |



\---



\## 8. ESTADO DE SERVICIOS SBOS EN EL SERVIDOR



```bash

\# Recolectar con:

systemctl list-units --type=service --state=running

```



| Servicio | Estado | Comportamiento esperado | Observaciones |

|---|---|---|---|

| \[nombre] | \[ACTIVO/INACTIVO] | | |



\---



\## 9. LOGS RELEVANTES



\### 9.1 Alertas de netwatch (resumen)

\[Extracto de /var/log/sbos-netwatch-alertas.log]



\### 9.2 Bloqueos UFW (resumen)

```bash

grep BLOCK /var/log/ufw.log | tail -30

```



\### 9.3 Autenticaciones fallidas

```bash

journalctl -u ssh --since "today" | grep -i "failed\\|invalid"

```



\### 9.4 Métricas históricas del sistema

\[Resumen de /var/log/sbos-metricas.log — picos, tendencias]



\---



\## 10. CUMPLIMIENTO Y CONTROLES APLICADOS



Referencia: CIS Controls v8 — controles aplicables a entorno de staging



| Control CIS v8 | Descripción | Estado |

|---|---|---|

| CIS 4.1 | Establecer procesos de configuración segura | \[CUMPLE/PARCIAL/NO-CUMPLE] |

| CIS 4.4 | Usar firewall en hosts | \[CUMPLE/PARCIAL/NO-CUMPLE] |

| CIS 8.2 | Centralizar logs de auditoría | \[CUMPLE/PARCIAL/NO-CUMPLE] |

| CIS 8.5 | Recolectar logs detallados de auditoría | \[CUMPLE/PARCIAL/NO-CUMPLE] |

| CIS 12.2 | Establecer arquitectura de red segura | \[CUMPLE/PARCIAL/NO-CUMPLE] |

| CIS 13.1 | Centralizar alertas de eventos de seguridad | \[CUMPLE/PARCIAL/NO-CUMPLE] |



\---



\## 11. RECOMENDACIONES



Prioridad ALTA (resolver antes de próxima sesión de pruebas):

\- \[ ] \[Recomendación 1]

\- \[ ] \[Recomendación 2]



Prioridad MEDIA (resolver en los próximos 7 días):

\- \[ ] \[Recomendación 1]



Prioridad BAJA (mejora continua):

\- \[ ] \[Recomendación 1]



\---



\## 12. CONCLUSIÓN Y PRÓXIMOS PASOS



\[Párrafo de cierre con estado general, hallazgos principales y acciones a tomar

antes de la próxima sesión de pruebas]



\*\*Próxima sesión de pruebas programada:\*\* \[fecha si se conoce]

\*\*Componentes SBOS a probar en siguiente sesión:\*\* \[lista]

\*\*Acciones previas requeridas:\*\* \[lista de fixes pendientes]



\---



\*Informe generado automáticamente por sbos-netwatch — SKULL Infrastructure\*

\*Referencia: NIST SP 800-30 · ISO/IEC 27001:2022 · CIS Controls v8\*

TEMPLATE



echo "✅ Informe generado: $REPORT"

cat "$REPORT"

````



\---



\## REGLAS DE COMPORTAMIENTO DEL AGENTE



\- FASE 1 obligatoria antes de cualquier cambio

\- El monitoreo de FASE 4 debe estar ACTIVO durante TODA la prueba sin excepción

\- El informe de FASE 6 es OBLIGATORIO al finalizar cada sesión — no es opcional

\- Si detectás intrusión activa: reportar \[EMERGENCIA] y detener pruebas

\- Si el software SBOS genera tráfico saliente: registrar como \[BUG-SBOS] en el informe

\- El objetivo principal es ENCONTRAR Y ELIMINAR la causa raíz, no solo bloquear

\- Cada anomalía debe tener resolución documentada en el informe

\- Español obligatorio en todos los reportes, logs e informes

\- Al finalizar cada fase: resumen con estado \[OK] / \[ALERTA] / \[CRITICO]

\- Los informes .MD se acumulan en /var/log/sbos-reports/ — nunca sobrescribir



\---

## BLOQUE F — Organización documental (confirmar el plan de corrección)

Propuesta para que NADA quede suelto — confirmar o corregir:

**F1.** Los documentos generados se renombran e integran así:

```
ANX-027-SBOS-CLIENT-SPEC.md      → BOS-REPAIR-14-SBOS-CLIENT-SPEC.md
ANX-028-ESTANDARES-\*.md          → BOS-REPAIR-15-ESTANDARES-INTERNACIONALES.md
Estrategia de stubs (nuevo)      → BOS-REPAIR-16-ADR007-DAEMONS-STUB.md
PARTE-V                          → se INTEGRA dentro de
                                   BOS-REPAIR-05-PLAN-ACCION-MAESTRO.md (v3.0)
                                   reorganizada por fases, no anexada al final
BOS-REPAIR-INDEX.md              → actualizado enrutando 14, 15 y 16
MAPA-NAVEGACION.md               → actualizado con los flujos nuevos
```

¿Confirmado? ¿Algún cambio de numeración o nombre?

**F2.** El BOS-REPAIR-05 que subiste (v2.0, 1479 líneas): ¿lo regenero
COMPLETO como v3.0 con las fases F11-F17 integradas en su estructura
(mi preferencia — un solo documento coherente), o prefieres mantener el
v2.0 intacto y que la extensión sea una sección nueva al final?

**F3.** ¿Los Informes de Cierre y el SESION-LOG siguen en las mismas rutas
de plandeaccion/ sin cambios?



Pare que tu mismo confirmes lee toda la docuemntacion y si hay que complemebntar algunos de los docuemntso complementa no es crera por crear archivos hay que hacerlo de forma lógica y robusta.



\---

## BLOQUE G — Prioridades y secuencia

**G1.** Con los stubs como nueva primera necesidad, ¿el orden correcto es?

```

Todo se debe regir al plan de accion


A) Stubs primero (nueva fase temprana), porque desbloquean las pruebas de
   todo lo demás (Context Plane real, VDI, governance)
B) Garantías de producto primero (TUI, Ficha Engine) y stubs justo antes
   de las capas que los necesitan (F13-F16)
C) Otro orden: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
```

**G2.** ¿Hay alguna fecha objetivo o hito externo (demo, presentación,
cliente) que deba condicionar las prioridades del plan?

**G3.** ¿Algo más que el redactor esté sobreentendiendo y debas aclarar
antes de que se redacten los documentos definitivos? (Espacio libre.)

\---

*BOS-REPAIR-CUESTIONARIO-01 · SKULL · SBOS · Junio 2026
Las respuestas se incorporan a: BOS-REPAIR-05 v3.0 · BOS-REPAIR-14/15/16 ·
REGISTRO-ESTADO · BOS-REPAIR-INDEX · MAPA-NAVEGACION*

