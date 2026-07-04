# ObservabilidadSBOS
**Proyecto:** SBOS — Sovereign Business Operating System
**Árbol:** 26a83fa0-d71c-476b-b52c-4cb14bdd2929
**Nodo SKDATA:** Observabilidad-SBOS
**Perfil:** fundacional — monitoreo
**Materializado:** 2026-05-12
**Construido:** 2026-05-13 (S-21)
**Stack:** LGTM + Zabbix + Wazuh · Retención 90d · Scrape 30s

## Arquitectura

```
ObservabilidadSBOS/src/
├── prometheus/
│   ├── prometheus.yml          # Scrape: 6 agentes + PG + Redis + Keycloak
│   └── rules/
│       ├── slos.yml            # Recording rules: 4 SLOs + error budgets + burn rates
│       └── alerts.yml          # 13 alertas: CRITICAL(7) + HIGH(5) + MEDIUM(3)
├── alertmanager/
│   ├── alertmanager.yml        # Routes + inhibition + Slack/Wazuh receivers
│   └── templates/
│       └── cef.tmpl            # Wazuh CEF syslog template
├── grafana/
│   └── dashboards/
│       └── sbos-operacional.json  # 10 paneles: SLOs, agentes, bKernel, infra, error budgets
└── alloy/
    └── config.alloy            # Log collection: journald + files → Loki
```

## Decisiones de diseño

### Scraping
- **bkernel:9100 + biedata:9101**: métricas Prometheus nativas (`prometheus` crate Rust)
- **bhnexus:9445**: puerto de métricas definido en config, handler pendiente
- **bos:9443, bauth:8070, bintelligence:8080**: scrape a `/health` (IETF draft-inadarei-api-health-check). Solo genera métrica `up`. Requiere sidecar exporter para métricas completas (TODO)

### SLOs (SBOS-032-OPERATIONS §2)
| Componente | SLO | Error Budget/mes |
|---|---|---|
| Sistema | 99.9% | 43.8 min |
| PostgreSQL | 99.99% | 4.3 min |
| Keycloak | 99.99% | 4.3 min |
| bKernel | 99.95% | 21.9 min |

### Alertas (SBOS-032-OPERATIONS §4)
- 7 CRITICAL: 24/7, Wazuh CEF + Slack #sbos-alerts-critical
- 5 HIGH: laboral, Slack #sbos-alerts-high
- 3 MEDIUM: Slack #sbos-alerts-all
- Inhibición: PostgreSQLDown suprime KeycloakDown + bKernelDown + ErrorBudgetBurn

### Recolección de logs (Alloy)
- journald: bos, bkernel, biedata, bauth, bhnexus, banexus + infra
- Archivos: `/var/log/sbos/*/` (fallback)
- Parseo dual: zerolog JSON (Go) + regex tracing (Rust)

## Prerrequisitos de infraestructura

Los siguientes exporters deben estar desplegados (vía infra-agent):

| Exporter | Puerto | Job |
|---|---|---|
| postgres_exporter | 9187 | postgresql |
| redis_exporter | 9121 | redis |
| node_exporter | 9100 | node (métrica disk/RAM) |
| kube-state-metrics | — | kubernetes (métrica pods) |

## Referencias

- `SBOS-005-STACK.md` §S12 — monitorserver (Prometheus, Grafana, Alertmanager, Loki, Alloy, Tempo, Zabbix, Portainer)
- `SBOS-032-OPERATIONS.md` — SLOs, alertas, runbooks
- `ORQUESTA-042-BUILD-CACHE.md` — caché de builds Go/Rust con volúmenes Podman
- `arbol/manifests/observabilidad-sbos.yml` — manifest de construcción
