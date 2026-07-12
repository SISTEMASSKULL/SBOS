# Anexo A.19 — La superficie JSON-RPC real: los métodos verificados contra el código
## Documento de respaldo de sustentación: qué métodos existen de verdad, cuáles son huérfanos, y una colisión que NO existe

**Tipo:** ANEXO — respaldo de sustentación (tipo **D** verificación de código)
**Versión del anexo:** 1.0.0 · **Fecha:** 2026-07-11
**Respalda a:** MANUAL-REFERENCIA-API (9.02 §2, §14, §17-§18) · A.16 (los protocolos)
**Verificación de código:** `src/main.rs` (registros) + `src/server/handlers/` — leída 2026-07-11
**Corrige:** 9.02 §17-R3 (la "colisión token.validate")

---

## 1. Propósito

Verificar contra el código la superficie real de métodos JSON-RPC, refinar la cifra y **corregir
un hallazgo del propio manual 9.02**: la colisión `token.validate` declarada como brecha P2 es
un **falso positivo**. **Cómo citarlo:** `A.19 §3` (la corrección) · `A.19 §2` (el conteo real).

## 2. El conteo real — verificado (2026-07-11)

| Componente | Evidencia | Métodos |
|---|---|:---:|
| Registros inline | `grep -c 'dispatcher.register("' src/main.rs` | **114** |
| Familias inline | 29 planos (`policy` 14 · `idp` 12 · `role` 9 · `org` 9 · `domain` 9 · `user` 7 · `tenant` 6 · `ctx` 6 · `blockchain` 6 · `webauthn` 4 · `token` 4 · `product` 4 · `oidc` 4 · …) | — |
| Lote `dashboard_panels` | main.rs 610+ | 10 |
| Lote `role_lifecycle` (montado 2026-07-11) | main.rs 623 | 7 |
| Lote `scim_server` | main.rs 610 | 5 |
| Lote `self_service` | main.rs 614 | 5 |
| Lote `device_identity` | main.rs 618 | 4 |
| Lote `token_protocols` (DPoP/exchange/introspect) | main.rs 629 | 3 |
| Lote `kong_oauth` (KongPep, Oauth2Proxy, RateLimit) | main.rs 634 — **3, sin colisión (§3)** | 3 |
| **Total registrado** | | **≈151 únicos** |

La cifra **≈151** de 9.02 §2 es correcta y reproducible. Este anexo la confirma y añade la
descomposición por familia.

## 3. ⚠️ CORRECCIÓN a 9.02 §17-R3 — la colisión `token.validate` NO existe

**9.02 §17-R3 (y §2 nota) declaran** como brecha P2: *"`bauth.token.validate` se registra dos
veces (inline + lote kong); el segundo pisa al primero en silencio"*.

**Verificación en código — es un falso positivo:**

```
grep 'bauth.token.validate' src/server/handlers/kong_oauth.rs:
  línea 38:  "token_validation_endpoint": "bauth.token.validate"   ← STRING de configuración
```

`all_kong_handlers()` (kong_oauth.rs:79-85) registra exactamente **3 handlers**: `KongPepHandler`,
`Oauth2ProxyHandler`, `RateLimitHandler`. **Ninguno se llama `bauth.token.validate`.** La
aparición del nombre es el valor de un campo JSON (`token_validation_endpoint`) dentro de la
respuesta de configuración que `Oauth2ProxyHandler` entrega a oauth2-proxy — le dice *a qué
método debe llamar oauth2-proxy*, no registra ese método.

**Conclusión:** `bauth.token.validate` se registra **una sola vez** (inline, main.rs:176). No
hay doble registración, no hay pisado silencioso. **La brecha R3 de 9.02 se cierra como
inexistente** — el grep que la originó confundió un string de config con un registro.

**Lo que SÍ queda (refinado):** la recomendación de A.16-F2 sigue válida como *mejora
preventiva* — que `dispatcher.register` **falle ruidosamente** si algún día se registra un
nombre duplicado (fail-closed en el arranque). Pero no hay colisión activa que resolver hoy.

## 4. Los huérfanos — estado real

| Archivo | Métodos | Estado verificado |
|---|---|---|
| `role_lifecycle.rs` | `bauth.role.{batch,bulk_assign,impact,lifecycle,rollback,search,temporal_assign}` | ✅ **MONTADO** (main.rs:623 `all_role_lifecycle_handlers`) — 9.02 §14 ya lo registró |
| `domain_remaining.rs` (3 consultas BD) | sin strings de método propios detectados | ⚠️ **único huérfano restante** — código con BD sin puerta; confirmar naturaleza y montar o retirar |

## 5. Lo que FALTA — contra la industria

| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| S1 | **Especificación OpenRPC** de los ≈151 métodos (params/result por método) | La industria publica superficie machine-readable (A.16-F1) | **P1** |
| S2 | Resolver `domain_remaining.rs` (montar o retirar) | Sin código muerto ni brecha de gobierno | P2 |
| S3 | `dispatcher.register` fail-closed ante duplicado (preventivo) | Robustez del arranque | P2 |
| S4 | Gate de `bauth.debug.methods` en producción | No exponer enumeración de superficie | P2 |

## 6. Verificación de completitud

| Verificación | Resultado |
|---|---|
| Cifra ≈151 reproducible | ✅ confirmada + descompuesta por familia |
| Colisión token.validate | ❌ **NO existe** — corrige 9.02 §17-R3 (falso positivo) |
| Huérfanos | 1 restante (`domain_remaining`); role_lifecycle ya montado |
| SDK sin promesas rotas | ✅ (9.02 §15) |

## 7. Referencias e historial

**Del código:** `src/main.rs` · `src/server/handlers/kong_oauth.rs` · 29 familias inline.
**Del proyecto:** 9.02 · A.16.

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Anexo inicial (tipo D): conteo real ≈151 con descomposición por 29 familias, y **corrección verificada a 9.02 §17-R3: la colisión `token.validate` es un falso positivo** — `all_kong_handlers` registra 3 handlers (KongPep/Oauth2Proxy/RateLimit), ninguno es token.validate; el nombre aparece solo como string de configuración (`token_validation_endpoint`) que le dice a oauth2-proxy a qué método llamar. La brecha R3 se cierra como inexistente; queda como mejora preventiva el register fail-closed. Estado de huérfanos (role_lifecycle montado, domain_remaining pendiente) y brechas (OpenRPC P1). |
