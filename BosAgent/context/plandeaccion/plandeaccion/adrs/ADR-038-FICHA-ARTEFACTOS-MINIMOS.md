# ADR-038 — Ficha SBOS — Artefactos Mínimos Obligatorios

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §16 La Ficha SBOS del Master v2.1  
**Relacionado:** ADR-021 (18 estados), ADR-025 (licencias OSI), ADR-037 (observabilidad), ADR-029 (Podman/OCI)

---

## Contexto y problema

Una "ficha" sin dashboard es invisible para el operador: no puede saber si está sana. Una ficha sin NetworkPolicy es un agujero de seguridad (Calico por defecto tiene deny-all, pero sin la policy de la ficha, el pod no puede comunicarse correctamente). Una ficha sin `/health` no puede ser monitoreada por K8s probes (el pod no se reinicia cuando está degradado).

## La Decisión

**Toda ficha SBOS DEBE tener exactamente estos 4 artefactos en su directorio `resources/`. Una ficha sin alguno de ellos es rechazada por el Bibliotecario (gate de CI).**

```
servers/<servidor>/<nombre-ficha>/
  ├── manifest.yml           ← metadatos, versión, dependencias, puertos
  ├── yaml_engine.yml        ← configuración de la aplicación
  ├── task_catalog.sh        ← lógica install/update/repair/uninstall
  └── resources/
      ├── dashboard.json     ← ✅ OBLIGATORIO — Grafana dashboard
      ├── netpolicies/       ← ✅ OBLIGATORIO — NetworkPolicies Calico
      │   ├── ingress.yaml   ← tráfico entrante al pod
      │   └── egress.yaml    ← tráfico saliente del pod
      └── (opcionales: secrets/, configmaps/, pvc/)
```

## Especificación de Cada Artefacto

### 1. dashboard.json — Grafana (obligatorio)

```json
{
  "uid": "sbos-<nombre>-<servidor>",
  "title": "<Nombre> — <Servidor>",
  "tags": ["sbos", "<nombre>", "<servidor>"],
  "panels": [
    // Panel 1: <nombre>_up (stat) — 0=DOWN, 1=UP
    // Panel 2: Latencia timeseries
    // Panel 3: Requests/s timeseries
    // Panel 4: Tasa de errores timeseries
  ]
}
```

### 2. netpolicies/ — NetworkPolicies Calico (obligatorio)

```yaml
# ingress.yaml — tráfico entrante
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <nombre>-ingress
spec:
  podSelector:
    matchLabels:
      app: <nombre>
  policyTypes:
    - Ingress
  ingress:
    - from: [...]  # solo los pods que deben acceder
      ports: [...]  # solo los puertos necesarios
```

Si la ficha es un HOST process (como nginx — §8.4), el directorio `netpolicies/` contiene solo un `README.md` documentando por qué no aplica (ver nginx ficha).

### 3. Puertos Obligatorios en manifest.yml

```yaml
ports:
  http: <puerto-principal>       # servicio principal
  metrics: <puerto-metrics>      # /metrics para Prometheus — OBLIGATORIO
  health: <puerto-health>        # /health y /ready para K8s probes — OBLIGATORIO
```

Los puertos metrics y health son obligatorios incluso si el servicio no los expone al exterior. K8s readiness/liveness probes dependen de `/health`. El OTel Collector scrape `/metrics`.

### 4. Campo license en manifest.yml (ADR-025)

```yaml
license: "MIT"    # OSI-approved obligatorio (ADR-025)
# El Bibliotecario ejecuta license-checker en CI
```

## Gate de CI — Verificación Automática

El Bibliotecario ejecuta `bosctl ficha validate <nombre>` que verifica:
- [ ] `resources/dashboard.json` existe y tiene los 4 paneles mínimos
- [ ] `resources/netpolicies/` existe (con yamls o README.md explicativo)
- [ ] `manifest.yml` tiene `ports.metrics` y `ports.health`
- [ ] `manifest.yml` tiene `license` con valor OSI-approved
- [ ] `task_catalog.sh` tiene las 4 funciones: `install`, `update`, `repair`, `uninstall`

## Consecuencias

**Positivas:**
- Todas las fichas son observables desde el primer deploy
- NetworkPolicies definidas explícitamente — ningún pod tiene acceso implícito
- K8s siempre sabe si un pod es sano (liveness/readiness probes funcionales)
- El catálogo de fichas es consistente: todas tienen la misma estructura

**Negativas/Riesgos:**
- La creación de una ficha nueva requiere más trabajo inicial
- Mitigación: `bosctl ficha scaffold <nombre> --servidor=<S>` genera la estructura completa con placeholders

## Normas relacionadas

- ADR-021 (18 estados — el motor de fichas usa estos artefactos)
- ADR-025 (licencias OSI-approved — `license` en manifest.yml)
- ADR-037 (observabilidad — dashboard.json y /metrics son parte de esta norma)
- §16 La Ficha SBOS (Master v2.1 — spec completa)
- Calico NetworkPolicy documentation
