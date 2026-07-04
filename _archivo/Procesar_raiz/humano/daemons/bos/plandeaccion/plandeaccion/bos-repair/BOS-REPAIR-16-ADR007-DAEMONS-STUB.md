# BOS-REPAIR-16 — ADR-007: Daemons Hermanos como Stubs de Contrato
## Decisión arquitectónica: el bos se prueba contra dobles mínimos con contratos REALES
## SKULL · SBOS · Junio 2026 · Estado: APROBADO (Cuestionario-01, Bloque A)

---

## 1. Contexto y problema

El bos es la piedra fundamental del SBOS: sin él, nada se construye
(Cuestionario-01 §A7 — no existe código real de ningún daemon hermano).
Pero el bos no puede certificar sus propias capacidades sin interlocutores:
el Context Plane necesita quién registre dispositivos (bhnexus), el
governance necesita quién evalúe permisos (bAuth), el VDI necesita el
ciclo completo registro→promoción→expiración.

**Decisión del operador:** el agente desarrollador crea versiones mínimas
(stubs) de los daemons hermanos que devuelven datos ficticios pero VÁLIDOS
según los contratos canónicos, en diferentes escenarios, para que las
pruebas del bos nunca se bloqueen y produzcan informes reales. Cada daemon
recibirá su desarrollo completo después, sobre el bos ya robusto.

## 2. Decisión

### 2.1 Ubicación — los stubs son la SEMILLA de los repos definitivos

```
/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/    ← bauth-stub
/opt/skull/orquestador/proyectos/desarrollo/sbos/BkernelAgent/  ← bkernel-stub
/opt/skull/orquestador/proyectos/desarrollo/sbos/BnexusAgent/   ← bhnexus-stub + banexus-stub
/opt/skull/orquestador/proyectos/desarrollo/sbos/BiedataAgent/  ← biedata-stub
(bcompass/bsearch: stubs mínimos cuando una prueba del bos los requiera)
```

Cada repo nace con los estándares BOS-REPAIR: `src/go.mod`, `doc.go`
(ADR-003), CI con `-race -count=10`, SFP-01..06. Cuando llegue el
desarrollo real, el stub se archiva en su `_legacy/` — nunca se borra.

### 2.2 Regla de oro de los stubs

> **Un stub implementa el CONTRATO real con datos ficticios — jamás un
> contrato inventado con datos reales.** Los frames, sockets, campos y
> códigos de error son EXACTAMENTE los de la documentación canónica.
> Solo el contenido (usuarios, máscaras, latencias) es de escenario.

Cada stub se configura por archivo de escenarios:
`/etc/sbos/stubs/<daemon>-escenarios.yml` — cambiar de escenario NO
requiere recompilar.

## 3. Contratos por stub (extraídos de la documentación canónica)

### 3.1 bauth-stub — el evaluador de permisos
**Contrato fuente:** SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1.0 §C1-C3 ·
SBOS-ROLTEMPLATE-v5.0 §Bloque 9 · SBOS-BITMASK-SAM128 §2.2

```
Transporte: Unix socket /run/bos/bauth.sock
            RuntimeDirectoryMode=0750 · User=bauth · Group=bos
Framing:    length-prefix JSON — 4 bytes uint32 big-endian + payload UTF-8
            timeout request 1000ms · max payload 64KB · max 100 conexiones

Request (lo que bhnexus/bos envían):
{ "request_id":"uuid", "user_id":"...", "node_id":"Ventas-01",
  "query_type":"bitmask", "timestamp":"..." }

Response GRANTED (escenario admin / cajero):
{ "request_id":"uuid", "granted":true,
  "sam128":"0x...",                  ← del RolTemplate de escenario
  "bos_context":{
     "bos_physical_mask":"0x000000000003E627",
     "bos_logical_mask":"0x0000010900030052",
     "bos_financial_mask":"0x0000020900010000" },   ← BitmaskBundle v3
  "ttl_seconds":28800, "actuator_commands":[], "timestamp":"..." }

Response DENIED (escenarios de rechazo):
{ "granted":false, "error_code":"AUTH_003", "reason":"outside_schedule",
  "message":"Acceso fuera de horario autorizado (08:00–18:00 LPZ)" }
```

**Escenarios mínimos del YAML (bauth-escenarios.yml):**
```yaml
usuarios:
  admin-total:    { granted: true,  rol: SBOS-ADMIN,  masks: {...todo permitido} }
  cajero-limitado:{ granted: true,  rol: POS-CAJERO,  masks: {...solo zona caja} }
  fuera-horario:  { granted: false, error: AUTH_003 }
  limite-financiero: { granted: false, error: AUTH_004 }
  superusuario:   { granted: true,  masks: 0x0 }   # sin bits — AssumeTenantContext
fallos-simulados:
  sobrecarga:     { error: SRV_002, probabilidad: 0 }   # subir para chaos tests
  latencia-ms:    8
```

**Lo que habilita en el bos:** governance dual-control F11.5 (identidad de
los 2 sbos-admin — el break-glass G4 exige segundo admin), pruebas RBAC del
sbos-client, escenarios de rechazo en el VDI.

### 3.2 bhnexus-stub — el broker del Context Plane
**Contrato fuente:** SBOS-NEXUS-CONCEPTUALIZACION-v3.0 §6-8 ·
BOS-REPAIR-14 (sbos-client spec) §5

```
Transporte: WebSocket mTLS :9444 (métricas :9445)
            Headers verificados: X-Node-ID, X-Agent-Version,
            X-Agent-Cert-Fingerprint → 403 si inválidos
Frames JSON (canal bidireccional):
  ← device_register   (de sbos-client/banexus)
  → device_registered { dctx_id, status:"pre-auth", bitmask:"0x0",
                        heartbeat_interval_s:30 }
  ← heartbeat / → {ok}
  ← auth_request      (de banexus)
  → auth_response     { granted, sam128 }   ← consulta al bauth-stub
                        via /run/bos/bauth.sock (cache TTL 30s)
  → context.promoted  { ctx_id, bitmask, user_id, ttl_seconds }   PUSH
  → context.expired   { ctx_id, reason }                          PUSH
```

El stub LLAMA al bos real (`bos.ctx.device.register` — F5.4) para crear el
dctx_id: así el Context Plane del bos se prueba de verdad, no contra sí
mismo. Comando de escenario: `bhnexus-stub trigger-promoted --user=X`
simula el login Keycloak y dispara el push (hasta que Keycloak real de la
ficha F13.1 tome ese rol).

**Respuesta A4 del operador incorporada:** el stub además entrega el
archivo de configuración que el bos reconoce como válido para continuar
sus pruebas (registro del nodo, endpoint, tenant).

### 3.3 banexus-stub — el edge sentinel
**Contrato fuente:** SBOS-NEXUS-CONCEPTUALIZACION-v3.0 §3-5

Cliente WS contra bhnexus-stub que reproduce el Flujo Soberano: envía
`auth_request` firmado HMAC (QR de prueba `sbos://auth/{user}/{ts}/{hmac}`)
y verifica recibir `auth_response` con el SAM en <50ms (objetivo del flujo).
Topología invariable respetada: banexus JAMÁS habla con bAuth ni KC directo.

### 3.4 bkernel-stub — el dueño futuro de bkernel_db
**Respuesta A6 del operador:** el bos crea y usa `bkernel_db` directamente
si la necesita (DDL del Context Plane F5.x / F12.5); el DDL definitivo lo
implementará bkernel en su desarrollo. El stub solo expone health y
funciones de escenario (eventos de auditoría aceptados/registrados) para
que ninguna prueba del bos se bloquee.

### 3.5 biedata / bcompass / bsearch — stubs bajo demanda
Health endpoint + respuestas de escenario SOLO cuando una prueba del bos
los referencie (ej. `bos.query.system` esperando su semáforo). No se
construye nada que ninguna prueba pida.

## 4. Lo que los stubs NUNCA hacen

```
✗ Inventar frames, campos o códigos fuera del contrato canónico
✗ Persistir datos de negocio (son efímeros por diseño)
✗ Quedar en producción: el REGISTRO-ESTADO marca su reemplazo
✗ Saltarse la topología (banexus→bAuth directo está VETADO)
✗ Generar tráfico saliente desde staging (incidente Contabo —
  skill sbos-staging-security-monitor vigila; los stubs escuchan
  en localhost/red interna del cluster únicamente)
```

## 5. Átomos resultantes (FASE 14 del REGISTRO-ESTADO)

```
F14.1 — bauth-stub en BauthAgent (socket + framing + escenarios SAM-128)
F14.2 — bhnexus-stub en BnexusAgent (WS :9444 + push promoted/expired) ⛔ gate
F14.3 — banexus-stub en BnexusAgent (flujo soberano de prueba <50ms)
F14.4 — bkernel-stub en BkernelAgent + bkernel_db creada por el bos
F14.5 — biedata/bcompass/bsearch stubs bajo demanda en sus repos
F14.6 — Certificación: suite end-to-end del bos contra los 5 stubs
        sin bloqueos · escenarios denied/sobrecarga incluidos
```

## 6. Consecuencias

Positivas: el bos certifica TODO su contrato sin esperar a ningún daemon ·
cada repo hermano nace con estándares y su contrato ya validado · los
escenarios denied/chaos quedan listos para siempre. Negativas asumidas:
mantener los stubs sincronizados si un contrato canónico cambia (mitigación:
el contrato vive en UN documento fuente citado por sección).

---

## Trazabilidad

| Decisión | Fuente |
|---|---|
| Stubs en repos definitivos | Cuestionario-01 A3 (rutas confirmadas por el operador) |
| Contrato bauth socket/framing/errores | SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1.0 §C1-C3 |
| BitmaskBundle v3 / SAM-128 / superusuario 0x0 | SBOS-BITMASK-SAM128 §2.2 · SBOS-ROLTEMPLATE-v5.0 §B9 |
| Dual-control 2º sbos-admin | SBOS-BAUTH-DECISIONES G4 (break-glass) |
| Protocolo bhnexus WS :9444 | SBOS-NEXUS-CONCEPTUALIZACION-v3.0 §6-8 |
| Topología vetada | SBOS-NEXUS §4 · SBOS-MANUAL-ACOPLAMIENTO §18 |
| bkernel_db creada por el bos | Cuestionario-01 A6 |
| Restricción tráfico saliente staging | Incidente Contabo · skill sbos-staging-security-monitor |

*BOS-REPAIR-16 · ADR-007 · SKULL · SBOS · Junio 2026*
*Enrutar desde: BOS-REPAIR-INDEX.md · REGISTRO-ESTADO.md F14 · BOS-REPAIR-05 v3.0*
