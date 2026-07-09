---
codigo: BNOTIFY-070
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D9, D14]
criterio_implementado: >
  El pipeline k6 se ejecuta sin errores y produce un informe JSON.
  El informe muestra que el núcleo bNotify alcanza 1.000 dispatches/segundo
  con p99 < 50ms en un entorno de carga sostenida de 5 minutos.
  Los resultados se publican en el artefacto de CI.
---

# BNOTIFY-070 — Capacidad y Pruebas de Carga
## Objetivos numéricos por componente y pipeline k6 en CI (D9)

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.2 (D9: nunca escalar sin medir), Anexo A (metas de escala)

**D9 — El principio de este documento:**
> Ningún componente se declara listo para producción sin un modelo de capacidad
> publicado. Los objetivos son absolutos, no relativos a "funciona en mi máquina".
> Si el objetivo no se alcanza, el componente no pasa al siguiente gate.

---

## 1. Objetivos de capacidad por componente y gate

### Gate G1 — bNotify núcleo

| Componente | Métrica | Objetivo G1 | Objetivo G3 |
|-----------|---------|:-----------:|:-----------:|
| `NotifyDispatcher.Dispatch` | Throughput | 1.000 req/s | 5.000 req/s |
| `NotifyDispatcher.Dispatch` | Latencia p99 | < 50ms | < 20ms |
| `NotifyDispatcher.Dispatch` | Error rate | < 0.1% | < 0.01% |
| Worker clase A | Entregas/segundo | 500 msg/s | 2.000 msg/s |
| Worker clase B | Entregas/segundo | 200 msg/s | 1.000 msg/s |
| Rate limiter (Redis) | Decisiones/segundo | 10.000 ops/s | 50.000 ops/s |
| Deduplicación (Redis) | Ops/segundo | 10.000 ops/s | 50.000 ops/s |

### Gate G2 — bChat motor

| Componente | Métrica | Objetivo G2 | Objetivo G3 |
|-----------|---------|:-----------:|:-----------:|
| Conexiones WS concurrentes | Concurrencia | 10.000 | 50.000 |
| `bchat.message.send` | Throughput | 2.000 msg/s | 10.000 msg/s |
| `bchat.message.send` | Latencia p99 | < 100ms | < 50ms |
| Fan-out de mensaje (sala N miembros) | Latencia p99 para N=100 | < 200ms | < 100ms |
| `bchat.sync` (reconexión) | Latencia p99 (100 eventos) | < 500ms | < 200ms |

### Gate G3 — bChat a escala

| Componente | Métrica | Objetivo G3 |
|-----------|---------|:-----------:|
| Conexiones WS concurrentes | Concurrencia | 100.000 |
| Validaciones ctx_id/segundo (Redis) | Throughput | 50.000 ops/s |
| Eventos auditados clase B (Merkle) | Throughput | 5.000 eventos/s |
| Pipeline Merkle | Latencia lote | < 60s por lote |

### Gate G5 — Consumo masivo

| Componente | Métrica | Objetivo G5 |
|-----------|---------|:-----------:|
| Conexiones WS concurrentes | Concurrencia | 500.000 |
| Mensajes/segundo total | Throughput | 100.000 msg/s |
| Throughput Merkle clase B | Pipeline | ≥ pico de mensajes |

---

## 2. Estructura del pipeline k6

```
BnotifyAgent/
└── load-tests/
    ├── scenarios/
    │   ├── dispatch_baseline.js     # G1: 1000 req/s dispatch
    │   ├── rate_limiter.js          # G1: verificar rechazo correcto
    │   ├── dedup_check.js           # G1: idempotencia bajo carga
    │   ├── bchat_connections.js     # G2: 10.000 WS concurrentes
    │   ├── bchat_message_flood.js   # G2: 2.000 msg/s en sala grande
    │   ├── bchat_fanout.js          # G2: fan-out en sala de 100 miembros
    │   ├── ctx_id_validation.js     # G3: 50.000 ops/s Redis
    │   └── merkle_pipeline.js       # G3: throughput auditoría clase B
    ├── lib/
    │   ├── auth.js                  # Helper: obtener JWT de bAuth
    │   └── grpc.js                  # Helper: llamadas gRPC (k6 xk6-grpc)
    └── thresholds.json              # Umbrales de éxito/falla por gate
```

### 2.1 Ejemplo: escenario dispatch_baseline.js

```javascript
// k6 0.55.x
import grpc from 'k6/net/grpc';
import { check } from 'k6';

const client = new grpc.Client();
client.load(['proto/'], 'bnotify.proto');

export const options = {
  scenarios: {
    dispatch_ramp: {
      executor: 'ramping-arrival-rate',
      startRate: 100,
      timeUnit: '1s',
      preAllocatedVUs: 200,
      stages: [
        { duration: '60s', target: 1000 },  // Ramp to 1000 req/s
        { duration: '300s', target: 1000 }, // Sustain 5 min
        { duration: '30s', target: 0 },     // Ramp down
      ],
    },
  },
  thresholds: {
    'grpc_req_duration{method:Dispatch}': ['p(99)<50'],
    'grpc_req_failed{method:Dispatch}': ['rate<0.001'],
  },
};

export default function () {
  client.connect('unix:///run/bos/bnotify.sock', { plaintext: true });
  const resp = client.invoke('bnotify.v1.NotifyDispatcher/Dispatch', {
    intent_id: uuidv4(),
    ctx_id: uuidv4(),
    tenant_id: 'tenant-test',
    emitter: 'load-test',
    event_type: 'system.load_test',
    destination: { type: 0, id: 'user-test-1' },
    priority: 3,  // PRIORITY_C
  });
  check(resp, { 'status is accepted': (r) => r.message.status === 0 });
  client.close();
}
```

---

## 3. CI Integration — GitHub Actions / pipeline

```yaml
# .github/workflows/load-test.yml  (o equivalente CI del ecosistema)
name: Load Tests
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 4 * * 1'  # Lunes a las 4am UTC

jobs:
  load-test-g1:
    runs-on: staging-vps
    steps:
      - uses: actions/checkout@v4
      - name: Run k6 dispatch baseline
        run: |
          k6 run load-tests/scenarios/dispatch_baseline.js \
            --out json=results/dispatch_baseline.json
      - name: Check thresholds
        run: |
          python3 scripts/check_thresholds.py results/dispatch_baseline.json \
            load-tests/thresholds.json
      - uses: actions/upload-artifact@v4
        with:
          name: load-test-results
          path: results/
```

---

## 4. Modelos de capacidad publicados

Cada gate debe publicar un archivo `capacity-model-G{N}.json` en el repositorio:

```json
{
  "gate": "G1",
  "measured_at": "2026-08-01T10:00:00Z",
  "environment": "staging-vps",
  "results": {
    "dispatch_throughput_rps": 1247,
    "dispatch_p99_ms": 32,
    "dispatch_error_rate": 0.0003,
    "worker_a_eps": 623,
    "redis_rate_limit_ops": 12450
  },
  "thresholds_met": true,
  "sha256_binary": "abc123..."
}
```

El SHA256 del binario testeado es obligatorio — verifica que los resultados corresponden
al código que se va a desplegar.

---

*BNOTIFY-070 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Un objetivo sin número es una opinión. Un número sin pipeline automatizado es una anécdota. Ambos son obligatorios.*
