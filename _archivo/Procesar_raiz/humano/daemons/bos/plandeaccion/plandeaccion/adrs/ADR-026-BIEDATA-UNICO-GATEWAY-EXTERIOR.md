# ADR-026 — biedata como Único Gateway hacia APIs Externas

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 4 + §10 Daemon biedata del Master v2.1  
**Relacionado:** ADR-022, DAEMON-BIEDATA, §7 Data Plane

---

## Contexto y problema

El SBOS procesa datos de negocio sensibles: facturas, inventarios, datos de empleados, transacciones financieras. Si cada daemon o ficha puede conectarse directamente a APIs externas (SIAT Bolivia, correo SMTP, SMS, pagos), los datos del cliente se dispersan por múltiples canales sin trazabilidad ni control. Esto viola GDPR-equivalente, ISO 27001 A.8.28, y el principio de soberanía.

## La Decisión

**biedata (Data Gateway — Orquestador JSON-RPC 2.0) es el ÚNICO componente del ecosistema que puede establecer conexiones de salida hacia APIs externas.**

```
PERMITIDO:
  ✅ biedata → SIAT Bolivia (SFE/SIAT) — emisión de facturas
  ✅ biedata → SMTP/SES — notificaciones vía bNotify
  ✅ biedata → Pasarelas de pago (PCI-DSS, tokenized)
  ✅ biedata → APIs de organismos gubernamentales (NIT, registro civil)
  ✅ biedata → Servicios de geolocalización (datos anonimizados)

VETADO para todos los demás daemons y fichas:
  ❌ bAuth llamando directamente a APIs de SMS para MFA → usa bNotify via biedata
  ❌ Tryton llamando directamente a SIAT → solicita via biedata
  ❌ pos-service enviando datos de pago directo a pasarela → via biedata
  ❌ Cualquier ficha con `curl` externo en su task_catalog.sh
```

## Arquitectura de Salida Controlada

```
Daemon / Ficha
      │
      ▼  Unix socket JSON-RPC
   biedata ← único punto de salida
      │
      ▼  HTTPS + ctx_id en headers
  API Externa (SIAT, SMTP, Pago)
```

biedata garantiza:
1. `ctx_id` registrado en todo request de salida (trazabilidad forense)
2. Datos del cliente enmascarados según la política del tenant
3. Reintentos con backoff exponencial
4. DLQ (Dead Letter Queue) para requests fallidos — nunca se pierden

## Consecuencias

**Positivas:**
- Auditoría completa de qué datos salieron, a dónde, con qué ctx_id
- Un solo punto para gestionar credenciales de APIs externas (via Vault)
- Cumple ISO 27001 A.8.28 (Secure Coding) y A.5.14 (Information Transfer)

**Negativas/Riesgos:**
- biedata es un punto de fallo para integraciones externas
- Mitigación: biedata tiene su propia ficha con 18 estados, watchdog y DLQ

## Normas relacionadas

- SBOS-024-DAEMON-BIEDATA (doctrina completa)
- ISO/IEC 27001:2022 A.5.14 (transferencia de información)
- SBOS-050 P9 (HTTP vetado entre daemons — biedata usa Unix socket hacia el interior)
