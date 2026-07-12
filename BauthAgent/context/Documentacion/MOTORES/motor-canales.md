# Motor de Canales Protegidos — *transportar*

**Verbo:** transportar · **Frontera:** `src/transport/` *(no existe)* · **Estado:** ⬜ PLT-17 · **Rige:** ADR-013 · **Decisión:** ADR-011

---

## 1. Propósito
Frontera **única** de todo canal de comunicación, entrante y saliente (NIST 800-63B «authenticated
protected channel»). Ningún módulo abre conexiones: **solicita un canal al motor**, que lo establece
protegido (cifrado aprobado, mTLS donde la norma lo exige) o lo **rechaza**. Además **normaliza**:
demodula cualquier protocolo (HTTP/REST/gRPC/webhook) → canon interno (JSON-RPC/socket), sanitiza, y
modula de vuelta al salir. El núcleo es **agnóstico de transporte**.

## 2. El contrato del motor
- **Fachada:** `solicitar_canal(canal_id, ctx_id) → CanalProtegido` + `demodular_a_canon` / `modular_desde_canon` (A.42 §10.bis).
- **Frontera:** `src/transport/` — todo cliente (`reqwest`/`tonic`) y el listener del socket viven aquí.
- **Fail-closed:** cifrado no aprobado / cert no verificable / mTLS requerido ausente ⇒ `Err` (jamás degradar a claro).
- **Política por canal** (catálogo, no hardcode): dirección, protocolo, cifrado, mTLS, red, resiliencia.

## 3. Los códigos que se juntan (frontera destino: `src/transport/` — hoy DISPERSO)
| Disperso hoy | Se centraliza como |
|--------------|--------------------|
| `reqwest` (HTTP saliente, ~4 archivos) | `solicitar_canal` (HTTP mínimo, solo HIBP) |
| `tonic`/gRPC (~3 archivos — cliente CAEP) | canal gRPC sobre socket |
| listener del Unix socket + dispatcher | entrante normalizado |
| clientes con su propio TLS/cifrado | política de canal única |

> **Minimizar HTTP/REST** (2.12 §5.bis): jerarquía 1 Unix socket · 2 gRPC sobre socket · 3 HTTP
> saliente mínimo · 4 REST solo en frontera externa (OIDC/SCIM/webhooks), siempre `via_gateway`.

## 4. Manuales de referencia
- **2.12** Canales Protegidos — **madre** (§4 arquitectura, §4.bis normalización, §5.bis jerarquía de protocolos).
- **SBOS-054** (seguridad de red) · ADR-020 (Interface Dual — el entrante ya centralizado).

## 5. Anexos y contratos
- **A.42 §10.bis** — ficha `solicitar_canal` + `demodular/modular_a_canon` (firma + cuerpo 9 pasos + fail-closed).
- **A.16** — por qué JSON-RPC 2.0 + WebSocket y no REST/gRPC/GraphQL.
- **ADR-011** — la decisión · **A.43 PLT-17** — el contrato y estado (⬜).

## 6. Estado real (verificado en código)
- ✅ El **entrante** ya está centralizado (Interface Dual, Unix socket — ADR-020).
- 🔄 El **saliente** disperso: `reqwest` (~4) + `tonic` (~3), cada uno con su config.
- ⬜ **No existe `src/transport/`** — sin fachada, sin normalización, sin auditoría de canal.

## 7. Plan para completarlo
1. Crear `src/transport/` con `solicitar_canal` + el catálogo declarativo de canales.
2. Implementar la **normalización** (demodular/modular ↔ canon interno, sanitizar — CWE-180).
3. **Migrar** los clientes `reqwest`/`tonic` a solicitar canal — progresivo, canal por canal.
4. Habilitar mTLS-bound tokens (AM-11) y la política de red D7 desde el motor.

*Portada de motor · ADR-013 · 2026-07-12*
