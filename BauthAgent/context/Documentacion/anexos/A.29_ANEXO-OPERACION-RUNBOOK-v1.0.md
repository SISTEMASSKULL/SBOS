# Anexo A.29 — Operación: systemd, runbook y alta disponibilidad
## Documento de respaldo de sustentación (tipo D+B)

**Versión:** 1.0.0 · **Fecha:** 2026-07-11 · **Respalda a:** MANUAL-OPERACION (6.01) · MANUAL-SEGURIDAD (2.09)
**Verificación de código:** `BauthAgent/bauth.service` — leída 2026-07-11
**Normas:** systemd · NIST 800-53 CP (contingencia) · SRE (HA, runbook)

## 1. El estado real — servicio systemd
`bauth.service` verificado: **`Type=notify`** (arranque con readiness), `Restart=on-failure`,
`RestartSec=5s`. El daemon corre en el host (no pods — SBOS). El binario es MUSL estático
(A.40). Base operativa presente.

## 2. Lo que FALTA — específico
| # | Brecha | Exigencia | Prioridad |
|---|---|---|:---:|
| OP1 | **`WatchdogSec` no verificado** — el CLAUDE declara `WatchdogSec=30` pero el .service no lo evidencia; sin watchdog el Type=notify no detecta cuelgues | systemd watchdog · 2.09 | P2 |
| OP2 | **Runbook operativo** (arranque, diagnóstico, recuperación, upgrade sin corte) | NIST CP · 6.01 | P1 |
| OP3 | **HA verificada** — failover, réplica, backup/restore probados | NIST CP-9/CP-10 | P2 |
| OP4 | Health checks operativos (`bauth.health.*` — existe, verificar cobertura) | SRE | P2 |

## 3. Verificación de completitud
systemd Type=notify ✅ · WatchdogSec ⚠️ (OP1) · runbook ❌ (OP2 P1) · HA ⏳ (OP3). Coherente con 0.00 §8 pilar VII ("HA verificada, operación/runbook" pendientes).

**Industria:** [systemd Type=notify](https://www.freedesktop.org/software/systemd/man/systemd.service.html) · [NIST 800-53 CP](https://csrc.nist.gov/publications/detail/sp/800/53/rev-5/final)

| Ver. | Fecha | Descripción |
|---|---|---|
| 1.0.0 | 2026-07-11 | Operación: bauth.service real (Type=notify, Restart=on-failure/5s); brechas OP1 WatchdogSec sin evidenciar (CLAUDE dice 30, .service no), OP2 runbook (P1), OP3 HA verificada, OP4 health checks. |
