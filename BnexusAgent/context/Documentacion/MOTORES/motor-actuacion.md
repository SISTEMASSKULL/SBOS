# Motor 6 — Actuación (Actuar-Hardware)
## Ejecución de AcctuatorCommands en relés, cerraduras OSDP, LED, buzzer

**Versión:** 1.0.0  
**Fecha:** 2026-08-04  
**Motor en MOTORES-INDEX:** `M-06`  
**Respalda:** `3.01_MANUAL-HAL.md` + `6.01_MANUAL-FLUJO-POLITICA.md` + `1.02_MANUAL-ARBOL-FISICO.md`

---

## Responsabilidad del motor

El Motor de Actuación **ejecuta en el hardware físico** las acciones dictadas por bAuth a través del SAM-128. Es el último eslabón de la cadena de autorización.

**Verbo central:** `Actuar` — convierte un `ActuatorCommand` en una acción hardware real.

## Qué hace

1. **Recibe** `ActuatorCommand[]` del Motor de Identidad bAuth (embebidos en el SAM-128 bundle)
2. **Despacha** cada comando al driver HAL correspondiente (según el target del actuador)
3. **Ejecuta** la acción en paralelo (tokio task por comando)
4. **Confirma** el resultado de la actuación al Motor de Identidad
5. **Registra** la actuación en el audit trail con ctx_id

## Tipos de actuadores soportados

| Tipo de actuador | Driver | Acción | Timing |
|-----------------|--------|--------|--------|
| Relé GPIO | WiegandDriver / GPIO | Open/Close/Pulse | < 1ms |
| Cerradura OSDP | OsdpDriver | `osdpCmd_OUT` Open/Pulse | 1-2ms |
| LED lector OSDP | OsdpDriver | `osdpCmd_LEDER` color/patrón | < 1ms |
| Buzzer OSDP | OsdpDriver | `osdpCmd_BUZZ` tono/duración | < 1ms |
| Display OSDP | OsdpDriver | `osdpCmd_TEXT` mensaje | < 1ms |
| Actuador MQTT | MqttDriver | Publish topic + payload | < 5ms |
| Actuador HTTP | HttpDriver | POST REST payload | < 10ms |

## Formato de ActuatorCommand

```rust
struct ActuatorCommand {
    target:      String,         // "RELAY_01", "DRAWER_01", "OSDP_LOCK_01"
    action:      ActuatorAction, // Open | Close | Pulse | Toggle | Alarm
    duration_ms: Option<u32>,    // para Pulse — cuánto tiempo abierto
    ctx_id:      String,         // trazabilidad — el mismo ctx_id del auth_request
    issued_by:   String,         // "bauth" — solo bAuth puede emitir comandos
}
```

## Invariante de seguridad más crítica

```
Solo bAuth puede emitir ActuatorCommands.
bhnexus ejecuta pero nunca genera comandos por su propia lógica.

Si bhnexus pudiera generar sus propios comandos → cualquier proceso
que comprometa bhnexus podría abrir puertas sin autorización.

Este invariante es verificable: audit trail contiene issued_by="bauth"
en CADA actuación registrada.
```

## fail-safe vs fail-secure en actuación

| Configuración zona | Comportamiento si falla software | Comportamiento mecánico |
|-------------------|----------------------------------|------------------------|
| `fail_secure` (default) | DENY — no envía comando de apertura | Cerradura permanece cerrada |
| `fail_safe` (evacuación) | DENY a nivel software | **El hardware falla abierto mecánicamente** (bimetálico o electromagnético) |

La distinción es hardware, no software. bNexus solo controla el lado software del `fail_safe` — el comportamiento físico de la cerradura es independiente del daemon.

---

*SKULL · SBOS · bNexus · MOTORES/motor-actuacion · v1.0.0 · Agosto 2026*
