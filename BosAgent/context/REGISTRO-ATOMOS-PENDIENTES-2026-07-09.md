# REGISTRO DE ÁTOMOS PENDIENTES — BOS-REPAIR
## Organizado según categorías V2 · 2026-07-09

---

## ① BOS IAM Installer
> Bootstrap del sistema, despliegue del stack de identidad (Keycloak, Vault, Kong, bAuth), ciclo de vida de tenants, sagas de instalación, hardening de red.

### Stack Alpha + Bootstrap

- **M2.2** 🔴 — Stack Alpha en VPS: PG 18.4 + Redis 8.6.2 instalados via Ficha Engine. C-03..C-04 verificados.
- **M2.3** 🟡 — bosctl bootstrap verify funcional: 8 criterios verificables, salida estado real VPS (0/8). Stack no instalado → 0/8. Pasará a OK cuando PG+Redis+Vault+KC+Kong estén desplegados.
- **M2.4** 🟡 — bosctl deploy: saga 7 pasos. Paso 1-2 OK, paso 3 Redis falla (falta adaptación k3s). Compensación automática funciona. 9 BDs creadas, Realm KC, Namespace K8s, Vault paths, Redis DB1. Bloqueado por M2.2.
- **M6.2** 🔴 — Tenant deploy < 30s P50 · < 90s P99 verificado con k6. SLO duro SBOS-PERF-001.
- **M6.4** 🔴 — FAPI 2.0 test suite contra KC staging (PAR, DPoP, PKCE, algoritmos). SBOS-CERT-001 §3.

### Integración bAuth (M7)

- **M7.1** 🔴 — DDL bAuth completa (155 tablas): migrar 46 tablas del DDL antiguo + crear 57 nuevas + seeds para 103 tablas. 12 dominios D1-D12. El DDL final debe estar en BauthAgent/db/migrations/DDL_skSBOS_db.sql.
- **M7.2** 🔴 — Templates de rol por dominio: 12 tablas idn_role_d*. Herramienta de merge. Tablas T-400 a T-411.
- **M7.3** 🔴 — Políticas por dominio: 12 tablas ath_policy_d*. Colección de políticas seleccionables. Tablas T-350 a T-361.
- **M7.4** 🔴 — Configuraciones por dominio: 12 tablas ath_config_d*. Configuraciones por defecto. Tablas T-370 a T-381.
- **M7.6** 🔴 — Mover menu_* de bauth a bglobal: T-090, T-091, T-092. bauth.menu_* → bglobal.menu_*. Actualizar FKs y seeds.
- **M7.7** 🔴 — ath_method con domain_classification: columna JSONB para clasificar método por dominios aplicables. T-065.
- **M7.8** 🔴 — Context Plane → bAuth integration: bos.ctx.resolve → /run/bos/bauth.sock → bAuth evalúa 12 dominios contra RolTemplate → BOS cachea resultado en Redis DB1 (TTL 30s).

### Capa 4: Identidad y Gateway (FASE 13)

- **F13.1** 🔴 — Ficha keycloak 26.6.2: realm {tenant} + import 5 SPIs custom → C-07. BosRolTemplate, FinancialDomain, PhysicalDomain, LogicalDomain, TemporalContext.
- **F13.2** 🔴 — JWT con claim bos_domains[] + bos_ctx_id + bos_tenant_id + bos_bitmask. Validado por Kong Plugin.
- **F13.3** 🔴 — Keycloak FAPI 2.0: security-profile=fapi2, PKCE, PAR. ⛔ gate: riesgo lockout.
- **F13.4** 🔴 — Keycloak Step-Up RFC 9470: políticas LoA 1-4 configuradas. bitmask 0x0→0x7 por LoA.
- **F13.5** 🔴 — Ficha kong 3.9.x LTS: database.reachable + rutas base api.{tenant} + TLS Vault PKI → C-08.
- **F13.6** 🔴 — Kong Plugin SBOS-Context (Lua): GET /api/v1/context/{ctx_id} en O(1) → rechaza si inválido. Crítico para todo el stack.
- **F13.7** 🔴 — Headers X-SBOS-Tenant, X-SBOS-Empresa, X-SBOS-Ctx-Id, X-SBOS-Bitmask inyectados por Kong a cada upstream.
- **F13.8** 🔴 — Linkerd mTLS inyectado en todos los namespaces sbos-*. SBOS-050 P9 compliance.
- **F13.9** 🔴 — bos↔Keycloak: validación JWT en JSON-RPC. bos.ficha.status requiere JWT válido.
- **F13.10** 🔴 — Kyverno policies: Docker vetado + imágenes firmadas Ed25519 obligatorias.
- **F13.11** 🔴 — Kong rutas: POST /api/v1/rpc recibe JSON-RPC 2.0 → traduce a gRPC → servicio destino → respuesta JSON-RPC 2.0.
- **F13.12** 🔴 — Mapeo errores gRPC → JSON-RPC en Kong: NotFound→-32005, PermissionDenied→-32001, Unauthenticated→-32002.
- **F13.13** 🔴 — Certificación Capa 4: C-07, C-08 ✓ + login OIDC e2e + ctx_id propagado + JSON-RPC→gRPC e2e. Kong rechaza request sin ctx_id válido.

### Capa 5: Daemons Soberanos Stubs (FASE 14)

- **F14.1** 🔴 — bauth-stub: Unix socket /run/bos/bauth.sock + JSON-RPC 2.0 + escenarios SAM-128 (granted/AUTH_003/AUTH_004/SRV_002). Habilita F11.5.
- **F14.2** 🔴 — bhnexus-stub: WebSocket mTLS :9444 (hardware bridge) + Unix socket + push context.promoted/expired a bos. ⛔ gate.
- **F14.3** 🔴 — banexus-stub: Unix socket + flujo soberano (auth_request HMAC → SAM <50ms). Sin HTTP. Interceptor en edge.
- **F14.4** 🔴 — bkernel-stub: Unix socket /run/bos/bkernel.sock + :9460 (solo Prometheus metrics) + DDL bkernel_db. Sin API REST.
- **F14.5** 🔴 — biedata-stub: Unix socket /run/bos/biedata.sock + JSON-RPC 2.0. :9470 ClusterIP K8s. Único gateway externo autorizado.
- **F14.6** 🔴 — bsearch-stub: Unix socket /run/bos/bsearch.sock + WebSocket wss:// :9493 exclusivo. Sin REST. PostgreSQL 18+ nativo.
- **F14.7** 🔴 — bcompass-stub: Unix socket /run/bos/bcompass.sock + :9480 (métricas) + HITL event simulado.
- **F14.8** 🔴 — Certificación Capa 5: suite e2e bos contra 7 stubs sin bloqueos. dctx pre-auth <2s. 0 llamadas HTTP entre daemons.

### Hardening de Red (FASE 21)

- **F21.1** 🔴 — NetworkPolicy Calico: deny-all ingress por defecto. Solo puertos declarados abiertos (NRS-01 Zero Trust).
- **F21.2** 🔴 — TLS 1.3 obligatorio en todos los endpoints externos 0.0.0.0:9443 (NRS-05). Cipher suites ECDHE+AES-256-GCM+SHA384. NIST SP 800-52 Rev 2.
- **F21.3** 🔴 — mTLS entre daemons via Linkerd o certs Vault (NRS-07).
- **F21.4** 🔴 — Wazuh agente instalado + reglas SBOS: alertas en acceso no autorizado a sockets (ISO 27001 A.8.16).
- **F21.A.1** 🔴 — Implementar TLS 1.3 en :9443. Modificar internal/server/api.go:ListenAndServe. Sin TLS 1.2, sin SSL.
- **F21.A.2** 🔴 — mTLS Kong→BOS: BOS requiere certificado cliente de Kong. CA interna Vault PKI.
- **F21.A.3** 🔴 — NetworkPolicy hardening: template YAML deny-all por namespace con allowlist explícita.
- **F21.B.1** 🔴 — internal/sanitize/: paquete centralizado validación. UUIDv4, Slug, Email, IPAddr, FilePath, JSONPayload, HeaderValidate, truncate. Tests ≥90% coverage.
- **F21.B.2** 🔴 — Integrar sanitize en todos handlers JSON-RPC. json.Decoder.DisallowUnknownFields(). Anti-mass-assignment SAN-10.
- **F21.B.3** 🔴 — Validación headers HTTP en Context API: X-SBOS-Source: kong obligatorio. Sin header → 403.
- **F21.B.4** 🔴 — Response mínimo enforcement: DTOs separados de domain models. Nunca retornar objeto completo.
- **F21.B.5** 🔴 — Sanitización logs: nunca loguear session_kc, user_id completo, tokens, secretos. logSanitize() wrapper.
- **F21.C.1** 🔴 — Rate Limiter Context API: token bucket 100 req/s por IP. Response 429 con retry_after_s.
- **F21.C.2** 🔴 — Endurecimiento WebSocket: CheckOrigin estricto, frame max 64KB, max 50 conexiones/IP, idle timeout 60s.
- **F21.C.3** 🔴 — Anti-enumeración: respuesta idéntica para ctx_id no encontrado y expirado. Mismo status, mismo mensaje.
- **F21.D.1** 🔴 — CI security scanning: gosec + govulncheck + gitleaks. Bloqueante en PR.
- **F21.D.2** 🔴 — Prometheus security metrics: bos_context_validations_total, validation_duration_seconds, rate_limit_exceeded_total.
- **F21.D.3** 🔴 — Audit log seguridad: audit_event por cada validación ctx_id, error 404/429, TLS handshake.
- **F21.D.4** 🔴 — Dependency check: Go 1.25+, sin CVEs Critical/High, licencias OSI-approved. CI bloqueante.
- **F21.D.5** 🔴 — HTTP prohibition CI check: ningún daemon importa net/http para servidores. Solo bos :9443.

### Golden Path e2e

- **F22.1** 🔴 — bosctl setup instala TODO desde cero sin intervención manual (R1-R4 ADR-022 verificados e2e).
- **F22.4** 🔴 — bosctl deploy --seed ./seed.yml completa 7 fases sin error en VPS limpio (golden path e2e).

### Soberanía de Fichas (FASE 22)

- **F22.A.1** 🔴 — Auditoría comandos manuales en VPS staging. Historial ssh. docs/SOV-GAP-ANALYSIS.md. SOV-07.
- **F22.A.2** 🔴 — Auditoría install.sh: ≤25 líneas, sin apt-get/useradd/mkdir/openssl/systemctl. SOV-05.
- **F22.A.3** 🔴 — Auditoría recursos sistema: cada archivo/directorio creado por ficha. SOV-02, SOV-08.
- **F22.A.4** 🔴 — Auditoría paquetes instalados vs declarados: dpkg -l vs manifest.yml. SOV-01.
- **F22.B.1** 🔴 — CI check SOV-05: install.sh sin comandos sistema. grep → PR rechazado.
- **F22.B.2** 🔴 — CI check SOV-01: todo system_packages declarado tiene task_catalog.sh.
- **F22.B.3** 🔴 — CI check SOV-02/03: documentación sin comandos manuales.
- **F22.B.4** 🔴 — CI check idempotencia: ficha_install 2 veces = mismo resultado.
- **F22.C.1** 🔴 — Ficha bos-certs: generación y renovación certificados TLS :9443.
- **F22.C.2** 🔴 — Ficha bos-firewall: UFW/nftables. Deny-all + allowlist. NSA/CISA K8s Hardening.
- **F22.C.3** 🔴 — Ficha bos-logrotate: rotación logs /var/log/bos/. ISO 27001 A.8.15.
- **F22.C.4** 🔴 — Ficha bos-ntp: sincronización reloj. systemd-timesyncd o chrony.
- **F22.D.1** 🔴 — docs/SOV-COMPLIANCE.md: guía desarrolladores, template task_catalog.sh, checklist.
- **F22.D.2** 🔴 — Actualizar INSTRUCCIONES-DE-USO.md y MAPA-NAVEGACION.md con SBOS-055.

### Ciclo de Vida de Tenants (10.C pendientes)

- **F10.C.11** 🟡 — bosctl tenant suspend X: invalida todos los ctx_id + pausa fichas. cmdTenant("suspend") esqueleto listo, falta invalidación real.
- **F10.C.12** 🟡 — bosctl tenant remove X: saga inversa de 7 pasos. cmdTenant("remove") con gate HITL. Falta implementar remove real.
- **F10.C.13** 🔴 — bosctl product install <producto> --tenant=X: agregar fichas a tenant existente. Pasos 3+4+7.
- **F10.C.14** 🔴 — Validación e2e: primer tenant real provisionado en VPS staging. bosctl deploy seed-skull.yml.

### Instalador Funcional (10.B pendientes)

- **F10.B.9** 🔴 — TUI ScreenInstalling (3 columnas) recibe eventos del daemon y muestra progreso real.
- **F10.B.10** ✅ — bos-preflight se ejecuta durante ScreenWelcome (progress bar). install_ui_impl.go: startPreflightCmd + awaitPreflight. (Marcado ✅ en registro.)

---

## ② BOS SO Observable
> Observar el estado de Ubuntu, Kubernetes y el propio BOS en tiempo real. Detectar drift de configuración, errores físicos y lógicos. Medir y proyectar capacidad. Reparar automáticamente. Auditar seguridad.

### Modelo de Capacidad

- **M1.CAP** 🟡 — Modelo capacidad dinámico: wizard P3B + bos-preflight real + observer + admisión JSON-RPC. Código listo + build + race×3 ✅ — pendiente prueba en vivo por operador (pantalla P3B, capacity.yaml, bos.capacity.check).

### 4 Motores de Capacidad (M5)

- **M5.1** 🔴 — Motor Observación: recolección 60s de 30+ métricas (Redis, PG, bKernel, Kong, bAuth, K8s). internal/capacity/collector.go. SBOS-BOS-CAP-001 §3.
- **M5.2** 🔴 — Motor Proyección: regresión lineal + horizonte 7/30/90 días + intervalo confianza. internal/capacity/forecaster.go. SBOS-BOS-CAP-001 §4.
- **M5.3** 🔴 — Motor Políticas: evaluación declarativa YAML cada 60s (autonomous/recommend/block_and_alert). internal/capacity/policy_engine.go. SBOS-BOS-CAP-001 §5.
- **M5.4** 🔴 — Motor Acción: scaling HPA + alertas graduadas + control admisión. internal/capacity/action_engine.go.
- **M5.5** 🔴 — bosctl capacity forecast: proyección 7/30/90 días con confianza. Salida: componente, valor actual, tendencia/h, tiempo a WARNING, tiempo a CRITICAL.

### SLOs y Certificación (M6)

- **M6.1** 🔴 — k6 Escenario 2 Beta (50 tenants, 5K RPS): todos los SLOs de SBOS-PERF-001. JSON-RPC P99<150ms, ctx_id P99<5ms, WAL<50ms P99.
- **M6.5** 🔴 — Evidencia técnica ISO 27001: audit_events, ctx_id en logs, Vault secretos, Wazuh alertas. 15 controles con artefacto verificado. SBOS-CERT-001 §2.2.

### Observabilidad y Seguridad Operativa

- **M4.2** 🔴 — bos.query.system con K8s real + Ubuntu real (kubectl no-stub). Pods, nodos, estado fichas reales.
- **F21.5** 🔴 — bosctl security scan + bosctl security audit funcionales contra daemon real. Salida estructurada verificable.

---

## ③ BOS Server FICHAS
> Motor administrador de fichas (aplicaciones/servicios). Instala, actualiza, repara y remueve fichas en el cluster K8s con sagas compensadas. Gestiona el ciclo de vida de cada aplicación del ecosistema.

### Ficha Engine — Estados (FASE 11)

- **F11.A.2** 🟡 — Parser de manifest.yml estricto: validar campos obligatorios (name, version, ports.metrics, ports.health). Rechazar sin dashboard.json. Licencias OSI-approved. validateManifestStrict() es stub.
- **F11.A.3** 🟡 — DEPENDENCY_RESOLVER: grafo dirigido + detección ciclos (Kahn) + orden topológico. bosctl ficha plan muestra DAG. Falta integración con Plan() en FichaService.
- **F11.B.1** 🔴 — Estados base (5): PENDIENTE → LISTA → INSTALADA. Transiciones manuales: PAUSADA, DESINSTALADA. State machine con 18 valores.
- **F11.B.2** 🔴 — Estados de instalación (3): INSTALANDO → INSTALADA / FALLA_INSTALACION. Timeout 30min. Rollback → LIMPIEZA.
- **F11.B.3** 🔴 — Estados de actualización (4): ACTUALIZACION_DISPONIBLE → ACTUALIZACION_APROBADA → ACTUALIZANDO → INSTALADA / FALLA_ACTUALIZACION. Timeout 15min. Rollback N-1.
- **F11.B.4** 🔴 — Estados de error (3): ERROR_FISICO → REPARANDO → INSTALADA / ERROR_NO_CORREGIBLE. ERROR_LOGICO → REPARANDO → INSTALADA / ERROR_NO_CORREGIBLE. 3 reintentos → HITL.
- **F11.B.5** 🔴 — Estados de transición (3): REPARANDO (timeout 10min), ROLLBACK (restaurar backup), LIMPIEZA (eliminar artefactos).

### Ficha Engine — Operaciones (FASE 11)

- **F11.C.1** 🟡 — bosctl ficha install <name>. Saga 5 fases. Timeout 30min. Idempotente. Falta ejecutor 5 fases.
- **F11.C.2** 🟡 — bosctl ficha update <name> --version=X.Y.Z. Backup → SQL migration → install → health verify. Timeout 15min. Rollback N-1. CLI no implementado aún.
- **F11.C.3** 🟡 — bosctl ficha repair <name>. Diagnóstico → ficha_repair() → verify. Timeout 10min. 3 reintentos. CLI funcional.
- **F11.C.4** 🟡 — bosctl ficha remove <name>. Saga inversa. Timeout 10min. CLI no implementado aún.
- **F11.C.6** 🟡 — bosctl ficha scale <name> --replicas=N. Stub, requiere integración K8s F9.

### Ficha Engine — Capacidades (FASE 11)

- **F11.E.3** 🔴 — Capacidades automáticas inyectadas por BOS: SSO (Keycloak client), ctx_id (OTel Baggage), mTLS (Linkerd sidecar), métricas (Prometheus endpoint), secretos (Vault AppRole).
- **F11.E.4** 🔴 — resources/netpolicies/: NetworkPolicy Calico generada por ficha. Deny-all default + allowlist explícita.
- **F11.F.2** 🟡 — bosctl ficha logs <name>. Visualizar FICHA_LOG en tiempo real (tail -f). --tail, --follow. CLI stub funcional.
- **F11.F.3** 🔴 — bosctl ficha describe <name>. Detalle completo: manifest, dependencias, recursos, health, drift, eventos, audit log.
- **F11.F.4** 🔴 — Matriz administración: docs/FICHAS-ADMIN-MATRIX.md. Operaciones × 24 fichas.
- **F11.F.5** 🔴 — Governance Dual-Control: operaciones cat.3 (remove, scale a 0) requieren 2 admins + ventana 60min + texto confirmación. ⛔ GATE.

### Fichas Declarativas — Capa 3 Datos (FASE 12)

- **F12.1** 🔴 — Ficha postgresql 18.4: wal_level=logical + slot bkernel_slot + partman + pgcrypto → C-04.
- **F12.2** 🔴 — 9 bases de datos provisionadas: keycloak_db, bkernel_db, bauth_db, tryton_db, minio_meta, bsearch_catalog, bcompass_db, bnotify_db, audit_db.
- **F12.3** 🔴 — Ficha redis 8.6.2: DB0 (Streams/cache) + DB1 (Context Registry TTL=KC) + DB2 (Rate Limiting) + AOF → C-05.
- **F12.4** 🔴 — Ficha vault 2.0.1: init + unseal Shamir (3/5 al operador) → C-06. ⛔ GATE: llaves JAMÁS en logs/repo.
- **F12.5** 🔴 — Vault PKI: CA interna + AppRole por ficha (TTL 24h) + paths secret/tenants/{realm}/.
- **F12.6** 🔴 — bkernel_db: DDL Context Plane (context_sessions, device_contexts particionado) aplicado + \dt verificado.
- **F12.7** 🔴 — WAL verificado: wal_level=logical + slot bkernel_slot + max_replication_slots≥5.
- **F12.8** 🔴 — Backups pg_dump programado + snapshot .sbos_state.json. ADR-016.
- **F12.9** 🔴 — bos.query.system refleja Capa 3: semáforos verdes reales.
- **F12.10** 🔴 — Certificación Capa 3: C-01..C-06 ✓ + datos sobreviven reinicio de pod.

### Fichas Declarativas — Bootstrap k3s (FASE 12.B)

- **F12.B.4** 🔴 — Health check Capa 2: PG Running + Redis Running + Minio Running. bosctl bootstrap verify --only=C-04,C-05 verde.
- **F12.B.13** 🔴 — Documentar regla "sin Capa N completa no se avanza a Capa N+1" en ADR-040 y SKILL.md.
- **F12.B.14** 🟡 — Instalar kubeadm + Calico real en VPS vía sbos-bootstrap-k8s. kubeadm v1.32.13, containerd 2.2.4.
- **F12.B.15** 🔴 — bosctl ficha install sbos-bootstrap-k8s → kubeadm Ready, Calico CNI operativo. C-01, C-02.
- **F12.B.16** 🔴 — bosctl ficha install sbos-bootstrap-cni → Calico 3.32.0 pods Running, NetworkPolicy funcional. C-02.
- **F12.B.17** 🔴 — Verificar Calico: calico-node + calico-kube-controllers Running. NetworkPolicy default-deny.
- **F12.B.18** 🔴 — Adaptar sbos-bootstrap-storage a k3s: _k() PATH, StorageClass local-path, default.
- **F12.B.19** 🔴 — bosctl ficha install sbos-bootstrap-storage → StorageClass local-path default. PVCs funcionales.
- **F12.B.20** 🔴 — Adaptar sbos-notifier a k3s: _k() PATH, PV opcional, deployment simple. Sin Redis streams.
- **F12.B.21** 🔴 — bosctl ficha install sbos-notifier → pod Running. C-09 funcional.
- **F12.B.22** 🔴 — Limpiar pods huérfanos de PASADA 2: etcd, pgbouncer, prometheus.
- **F12.B.23** 🔴 — bosctl bootstrap verify --full → C-01..C-08 todos ✅ con K8s+Calico verificados.
- **F12.B.24** 🔴 — bosctl deploy seed-skull.yml → tenant completo < 30s, todos pasos OK, sin compensación.
- **F12.B.25** 🔴 — Documentar FASE 12.B completa: Bootstrap PASADA 1 terminado, lecciones, gaps PASADA 2.

### Fichas Declarativas — Daemons (FASE 14)

- **F14.2** 🔴 — Ficha sbos-biedata: manifest.yml + task_catalog.sh. /run/bos/biedata.sock. health: biedata.health.check.
- **F14.3** 🔴 — Ficha sbos-bsearch: manifest.yml + task_catalog.sh. /run/bos/bsearch.sock. health: bsearch.health.check.
- **F14.4** 🔴 — Ficha sbos-bnotify: manifest.yml + task_catalog.sh. /run/bos/bnotify.sock. health: bnotify.health.check.
- **F14.5** 🔴 — Ficha sbos-bhnexus: manifest.yml + task_catalog.sh. Unix socket + TCP :9444. health: bhnexus.health.check.

### Ficha Engine — PostGIS y SLOs

- **F12.4** 🔴 — Ficha postgis: servers/S01/postgis/. CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;. Crítico para D6 geoespacial.
- **M6.3** 🔴 — Ficha install < 60s P50 · < 180s P99 verificado en VPS. SLO duro SBOS-PERF-001.

### Infraestructura de Eventos y Logs

- **F3.C.2** 🔴 — Redis Streams event bus: internal/eventbus/redis_streams.go. Stream bos:saga:{tenant_id}. Max len 10K. Consumer groups. Eventos persistentes. DTC-04.
- **F3.C.3** 🔴 — Log rotation: /etc/logrotate.d/bos-fichas (10MB × 5 archivos) en bos-preflight task_catalog.sh. Reader ya existe en ficha/logs.go. Falta logrotate config.

### Verificación y SLOs

- **F8.2** 🔴 — Test integración: daemon bos real + bosctl client + ciclo completo install/verify/remove ficha postgresql en VPS.

---

## ④ BOS Context Plane
> Administrar, observar, proveer y validar el ctx_id. Registrar dispositivos, promover contextos de dispositivo a sesión autenticada, cachear en Redis, integrar con bAuth para evaluación de 12 dominios.

### Context Plane Real (M3)

- **M3.1** 🔴 — bos.ctx.device.register < 2s con PG+Redis reales. dctx_id en Redis DB1. Depende M2.2.
- **M3.2** 🔴 — ctx_id lookup Redis < 1ms P50 · < 5ms P99 (SLO SBOS-PERF-001). k6: 50 disp, 10 prom.
- **M3.3** 🔴 — context.promoted end-to-end < 15ms P50 · < 40ms P99. dctx → ctx_id vía bAuth → bos.ctx.promote.
- **M3.4** 🔴 — bosctl ctx list muestra ctx_id y dctx_id reales del tenant skull. Validación CLI completa.

### Seguridad del Context Plane (FASE 5.D)

- **F5.B.2** 🔴 — dctx_id heartbeat: renovar TTL del dispositivo. Sin heartbeat 30min → EXPIRADO. bos.ctx.device.heartbeat.
- **F5.B.3** 🔴 — dctx_id TTL enforcement: Kong verifica dctx_id antes de servir contenido. Expirado → nuevo dctx_id. Cookie __sbos_dctx.
- **F5.B.4** 🔴 — dctx_id → ctx_id promotion precondición login. Validar no expirado ni ya promovido. Un dctx_id se promueve UNA vez.
- **F5.C.5** 🔴 — bos.ctx.invalidate_all_by_tenant: invalidar TODOS ctx_id de un tenant. Redis: eliminar keys. bkernel_db: UPDATE state=INVALIDADO.
- **F5.D.1** 🔴 — UUID v4 estricto en ctx_id: validar formato en TODOS los endpoints. Regex. SAN-09. Anti-injection.
- **F5.D.2** 🔴 — Anti-enumeration: respuesta idéntica para ctx_id "no encontrado" y "expirado". Mismo HTTP status, mismo mensaje, misma latencia.
- **F5.D.3** 🔴 — dctx_id pre-auth security: bitmask=0x0 NO autoriza acceso. Kong verifica bitmask > 0. bAuth rechaza bitmask=0x0.
- **F5.D.4** 🔴 — ctx_id cross-tenant validation: verificar tenant_id del request coincide con tenant_id del ctx_id. Prevenir escalación.
- **F5.D.5** 🔴 — Sanitización ctx_id en logs: nunca loguear completo. Solo primeros 8 chars + hash. Nunca session_kc.
- **F5.D.6** 🔴 — Rate limiting Context API :9443: 100 req/s por IP. Response 429 retry_after_s. Timeout 2s.

### Propagación (FASE 5.E)

- **F5.E.1** 🔴 — Propagación Kong→servicios: headers X-SBOS-Tenant, X-SBOS-Empresa, X-SBOS-Sucursal, X-SBOS-Ctx-Id, X-SBOS-Bitmask. Kong Plugin SBOS-Context (Lua).
- **F5.E.2** 🔴 — Propagación gRPC: RequestContext campo 1 en todos los mensajes (ADR-033). ctx_id + tenant_id obligatorios. Interceptor.
- **F5.E.3** 🔴 — Propagación WAL→bKernel: ctx_id en cada evento CDC. bkernel_db.audit_events con columna ctx_id.
- **F5.E.4** 🔴 — Propagación logs (Loki): ctx_id como atributo vía OTel Baggage Processor. Cero invasión a fichas.

### Auditoría y Cumplimiento (FASE 5.F)

- **F5.F.1** 🔴 — audit_event por cada operación Context Plane: device.register, promote, switch, invalidate, get, validate. ISO 27001 A.8.15.
- **F5.F.2** 🔴 — Métricas Prometheus Context Plane: bos_context_validations_total{result}, validation_duration_seconds, active_contexts, expired_contexts.
- **F5.F.3** 🔴 — Retención audit_events: 90 días online (bkernel_db), 7 años offline. Particionado por mes. pg_partman. SBOS-044-FISCAL-CONTABLE-LATAM.

### Performance y SLOs (FASE 5.G)

- **F5.G.1** 🔴 — ctx_id lookup P99 < 5ms (Redis cache). k6: 50 disp, 10 prom, 100 validaciones/s. SBOS-PERF-001 SLO.
- **F5.G.2** 🔴 — device.register < 2s P99 (C-13). PostgreSQL+Redis reales. Timeout máximo 5s.
- **F5.G.3** 🔴 — Context Plane bajo carga: 500 dispositivos concurrentes, 100 promociones/s, 50 switch/s ×60s. Zero bitmask_cero_count.

### Operación y Recuperación (FASE 5.H)

- **F5.H.1** 🔴 — Runbook RB-03: diagnóstico y reparación Context Plane caído. 5 casos: Redis down, PG down, bug, TTL expirado. 5-20 min resolución.
- **F5.H.2** 🔴 — Health check C-13: bosctl bootstrap verify --only=C-13. device.register < 2s. Redis DB1 + PostgreSQL responden.
- **F5.H.3** 🔴 — Recuperación post-crash: reconstruir cache Redis desde PostgreSQL al reiniciar bos.service. <30s para 10K ctx_id.

### Context API + bAuth Integration (M7)

- **M7.5** 🔴 — Context API :9443 — bos.GetContext(): GET /api/v1/context/{ctx_id} → JSON unificado con 9 dimensiones. P99 < 5ms Redis cache. Invalidación por eventos.
- **M7.8** 🔴 — Context Plane → bAuth integration: bos.ctx.resolve → /run/bos/bauth.sock → bAuth evalúa 12 dominios → BOS cachea en Redis DB1 (TTL 30s).

### Cierre bAuth — PostGIS + Widgets (FASE 24)

- **F24.A.1** 🔴 — Ficha postgis: servers/S01/postgis/. CREATE EXTENSION postgis; CREATE EXTENSION postgis_topology;. Sin esto, 5 tablas D6 no pueden usar POINT/POLYGON.
- **F24.B.1** 🔴 — Widget MapPointPicker + MapPolygonDrawer: flutter_map + OpenStreetMap en Core UI. Tocar punto, dibujar polígono, buscar dirección.
- **F24.B.2** 🔴 — Widgets temporales: DatePicker, TimePicker, DateTimeZonePicker, RecurrencePicker (RFC 5545).
- **F24.B.3** 🔴 — Widgets seguridad: BiometricEnrollment, CertificateUpload (x509), SignaturePad, DocumentScanner (google_mlkit).
- **F24.B.4** 🔴 — Poblar menu_context con entradas widget: 12+ entradas mapeando entity_type → widget_type.

---

## ⑤ BOS Dashboard
> Dotar al dashboard GUI (Flutter) de toda la información del BOS para control y monitoreo. Exponer métodos JSON-RPC especializados para el dashboard. Proveer la infraestructura de comunicación (WebSocket, Interface Dual, contratos de eventos).

### Dashboard API

- **M4.3** 🔴 — Implementar bos.dashboard.*: bos.dashboard.metrics, bos.dashboard.fichas, bos.dashboard.tenants, bos.dashboard.health, bos.dashboard.capacity. API para Flutter via /run/bos/bos.sock. No es TUI, es API.
- **M4.1** 🔴 — Todos los métodos JSON-RPC probados contra daemon real → RPC-CATALOG.md. 50+ métodos verificados. Auth, timeouts, batch.
- **M4.4** 🔴 — JSON-RPC P99 < 150ms bajo carga Alpha (5 tenants, 500 RPS). k6 Escenario 1 SBOS-PERF-001.

### Infraestructura de Comunicación (FASE 3.C)

- **F3.C.1** 🔴 — WebSocket sobre Unix socket: internal/server/ws.go. Upgrade HTTP→WS en /run/bos/bos.sock. Frame max 64KB. CheckOrigin solo localhost. Max 50 conexiones. Idle timeout 60s. Heartbeat 5s. ADR-020 mismo socket JSON-RPC.
- **F3.C.4** 🔴 — Interface Dual: registro central internal/server/rpc_registry.go. Auth por método. Timeout por categoría. Batch paralelo. Errores estándar JSON-RPC 2.0.
- **F3.C.5** 🔴 — Paquete contracts/events/: tipos puros compartidos entre daemon y clientes. seed_params.go + saga_event.go + command.go + snapshot.go. Sin imports externos. DTC-11.

### Catálogo Completo de Eventos Daemon→TUI (FASE 3.C.2)

- **F3.C.6** 🔴 — SAGA_STARTED: saga_id, saga_type, total_steps, tenant_id, ctx_id. TUI → ScreenInstalling.
- **F3.C.7** 🔴 — STEP_STARTED: saga_id, step, step_total, ficha, ctx_id. TUI spinner + "Instalando {ficha}...".
- **F3.C.8** 🔴 — STEP_COMPLETED: saga_id, step, duration_ms, detail. TUI ✅ checkmark.
- **F3.C.9** 🔴 — STEP_FAILED: saga_id, step, error, exit_code, detail. TUI ❌ + diagnóstico 3-partes. Dispara compensación.
- **F3.C.10** 🔴 — STEP_SKIPPED: saga_id, step, reason. TUI ⏭️ + reason.
- **F3.C.11** 🔴 — COMPENSATION_STARTED: saga_id, failed_step, steps_to_compensate[]. TUI "↩️ Revirtiendo...".
- **F3.C.12** 🔴 — COMPENSATION_COMPLETED: saga_id, compensated_steps[], duration_ms. TUI ✅ "Rollback completado".
- **F3.C.13** 🔴 — SAGA_COMPLETED: saga_id, total_duration_ms. TUI → ScreenDone + health checks.
- **F3.C.14** 🔴 — SAGA_SNAPSHOT: current_step, steps_completed[], steps_failed[], active_compensations[], ctx_id. DC-03. DTC-06 + DTC-13. Event Sourcing Snapshot pattern.
- **F3.C.15** 🔴 — HEARTBEAT: uptime_s, memory_mb cada 5s. Timeout 15s → TUI "reconectando...". Backoff 1→2→4→8→30s.
- **F3.C.16** 🔴 — LOG_LINE: level, message, ficha, timestamp. TUI panel log. Auto-scroll con Ctrl+F.
- **F3.C.17** 🔴 — DASHBOARD_DATA: fichas_ok, fichas_degraded, health_score, uptime cada 30s. DC-10. DTC-13.

### Catálogo Completo de Comandos TUI→Daemon (FASE 3.C.3)

- **F3.C.18** 🔴 — START_SAGA: payload seed_params (≡ seed.yml schema). Rol B → Rol A. Daemon persiste en bkernel_db ANTES de lanzar saga. DTC-09, DTC-12.
- **F3.C.19** 🔴 — RETRY_STEP: saga_id, step. Daemon valida estado=FAIL, sin compensación activa, step ≤ current_step. DTC-07.
- **F3.C.20** 🔴 — ABORT_SAGA: saga_id, reason. Compensación inversa completa → LIMPIEZA. DTC-07.
- **F3.C.21** 🔴 — GET_SNAPSHOT: ?saga_id opcional. Idempotente. Daemon consulta bkernel_db. DTC-06.
- **F3.C.22** 🔴 — GET_DASHBOARD: ?tenant_id opcional. State manager + health checker. DTC-13.
- **F3.C.23** 🔴 — SUBSCRIBE_LOGS: ficha opcional. TUI recibe LOG_LINE. Unsubscribe al desconectar. DTC-08.

### Parámetros Pre-Saga (FASE 3.C.4)

- **F3.C.24** 🔴 — SEED_PARAMS: payload parámetros instalación. Schema idéntico seed.yml. enterprise_tenant, identity, infrastructure, databases, vault, redis, context_plane, fichas, users. DTC-11, SAN-10.
- **F3.C.25** 🔴 — Persistencia pre-saga: SEED_PARAMS → bkernel_db.seed_params + materializar seed.yml en disco. Write-ahead pattern. DC-07. DTC-12.
- **F3.C.26** 🔴 — VALIDATE_SEED: validar seed_params sin ejecutar. Errores de validación o "valid". DTC-09.

### Tres Momentos de Conexión (FASE 3.C.5)

- **F3.C.27** 🔴 — Pre-instalación: TUI detecta daemon idle → presenta wizard (Rol B). GET_SNAPSHOT sin saga → ScreenWizardP1. internal/tui/model/preflight.go. DTC-13.
- **F3.C.28** 🔴 — Durante instalación: TUI detecta saga activa → recibe SAGA_SNAPSHOT → muestra progreso real → Rol A (solo observar). internal/tui/model/ws.go:onConnect(). DC-03. DTC-06, DTC-13.
- **F3.C.29** 🔴 — Post-instalación: TUI conecta 24h después → daemon idle → dashboard (Rol A). GET_DASHBOARD. Sin wizard. DC-10. DTC-13.

### Pruebas de Desacoplamiento (FASE 3.C.6)

- **F3.C.30** 🔴 — DC-01: Instalación sin TUI. bosctl deploy seed.yml completa 7/7 sin TUI abierta. DTC-01.
- **F3.C.31** 🔴 — DC-02 + DC-03: kill -9 TUI paso 3/7, daemon completa, reconectar → snapshot 7/7. DTC-05, DTC-06.
- **F3.C.32** 🔴 — DC-04: 2 TUIs simultáneas → mismo progreso, sin interferencia. DTC-04.
- **F3.C.33** 🔴 — DC-05: Comando inválido → rechazo explícito. TUI reconectada 7/7 envía RETRY_STEP 3 → daemon rechaza. DTC-07.
- **F3.C.34** 🔴 — DC-06: Secreto no transita por TUI. Inspeccionar payloads WS, zero secretos. Vault única fuente. DTC-10.
- **F3.C.35** 🔴 — DC-07: Parámetros persisten. Confirmar P4, kill TUI antes paso 1, daemon completa saga. DTC-12.
- **F3.C.36** 🔴 — DC-08: Equivalencia wizard vs seed.yml. Instalar 2× (wizard y CLI) → diff vacío. DTC-09.
- **F3.C.37** 🔴 — DC-09: Modo híbrido. bosctl setup --seed partial.yml → wizard defaults + campos faltantes. DTC-09, DTC-11.
- **F3.C.38** 🔴 — DC-10: Conexión post-instalación. TUI conecta 24h después, muestra dashboard, no wizard. DTC-13.

### Anti-Patrones Prohibidos (FASE 3.C.7)

- **F3.C.39** 🔴 — CI check: go list -deps ./cmd/bos/ | grep tui → CERO matches. Bos NUNCA importa tui/. SBOS-053 §10.
- **F3.C.40** 🔴 — CI check: grep -r "tui.InstallFicha\|tui.ExecuteStep" → CERO matches. TUI NUNCA ejecuta lógica saga.
- **F3.C.41** 🔴 — CI check: grep -r "select {.*tuiConfirmChan\|<-.*tuiReady" → CERO matches. Daemon NUNCA bloquea esperando TUI. DTC-02.
- **F3.C.42** 🔴 — CI check: grep -r "sagaInUse\|lock.*saga\|exclusive.*tui" → CERO matches. Sin lock exclusivo TUI. DC-04. DTC-04.
- **F3.C.43** 🔴 — CI check: grep -E '(password|token|secret|key|shamir)' en test dumps → CERO matches. DTC-10. ISO 27001 A.8.12.

### Calidad y Cobertura

- **F8.1** 🔴 — Cobertura mínima 70% en internal/. go test -race -coverprofile=coverage.out ./internal/...
- **F8.3** 🔴 — Test carga: k6 contra JSON-RPC. 100 usuarios concurrentes. 5 min. P99 < 150ms.
- **F8.5** 🔴 — Benchmarks: BenchmarkCtxCreate + BenchmarkFichaInstall + BenchmarkJSONRPC. go test -bench=. -benchmem.

### Banco de Pruebas

- **BOS-BANCO-PRUEBAS** 🔴 — Documento vivo de pruebas verificables. Cada prueba con Vía 1 (bosctl CLI WebSocket) y Vía 2 (JSON-RPC 2.0 Unix socket). Ambas obligatorias. Este átomo nunca se cierra, es permanente 🟡 mientras el BOS evolucione.

---

## APÉNDICE: Fases Adicionales (no categorizadas en V2 original)

### FASE 17 — Estándares Internacionales + Certificación (17 átomos 🔴)

- **F17.1** 🔴 — CIS Kubernetes Benchmark v1.12: kube-bench en CI. L1 ≥95%. 🔴 gate: flags API server.
- **F17.2** 🔴 — CIS benchmark host Ubuntu 26.04 (Lynis/CIS-CAT).
- **F17.3** 🔴 — NIST SP 800-190: imágenes trivy+cosign, registry TLS, digest, seccomp.
- **F17.4** 🔴 — NIST SSDF 800-218: mapeo PO/PS/PW/RV + gosec + govulncheck en CI. docs/compliance/SSDF-MAP.md.
- **F17.5** 🔴 — SLSA L2: provenance firmada Ed25519 (bos/bosctl/sbos-client/imagen/iso). Release Plane SKULL.
- **F17.6** 🔴 — SBOM automático por release (syft → CycloneDX JSON).
- **F17.7** 🔴 — ISO 27001:2022: matriz de controles técnicos. A.8.15 ✓ (F1.1), A.9 ✓ (F5), A.10 ✓ (F12.4).
- **F17.8** 🔴 — ISO 25010: 7 gates de calidad medibles en CI (disponibilidad/MTTR/cobertura/latencias).
- **F17.9** 🔴 — OTel Collector con Baggage Processor: ctx_id como atributo en todos los spans + logs.
- **F17.10** 🔴 — Wazuh DaemonSet en todos los namespaces sbos-* (HIDS/SIEM). ISMS control A.8.16.
- **F17.11** 🔴 — .proto como fuente de verdad: ANTES de cualquier línea de Go, se escribe el .proto. RequestContext campo 1 siempre.
- **F17.12** 🔴 — buf lint + buf breaking en CI: ningún cambio .proto rompe contratos existentes.
- **F17.13** 🔴 — gRPC interceptors chain: Recovery→Context→Auth→Logging→Tracing→Metrics en TODOS los servicios.
- **F17.14** 🔴 — Kyverno policies: Docker vetado, imágenes firmadas, no-root obligatorio.
- **F17.15** 🔴 — Verificación §18 reglas inquebrantables en CI: 12 reglas → 12 checks automatizados.
- **F17.16** 🔴 — bosctl bootstrap verify --full → 14/14 ✓ + reporte certificación.
- **F17.17** 🔴 — Informe final del proyecto + actualización documentación completa.

### FASE 15 — Capa 6: Fichas de Aplicación (7 átomos 🔴)

- **F15.1** 🔴 — Ficha bnotify (sbos-notifier): push MFA + notificaciones — puerto :28200-:28205 (S06). ⛔ CRÍTICO sin bnotify no hay MFA real.
- **F15.2** 🔴 — Ficha Tryton (ERP base) para validación del ciclo de negocio C-14. BD tryton_db.
- **F15.3** 🔴 — Ficha pos-service (Punto de Venta SBOS): seed → install → health. Usa biedata como gateway.
- **F15.4** 🔴 — Ficha inventario-service: stock, almacenes, movimientos.
- **F15.5** 🔴 — Ficha facturacion-service SIAT: DTE Bolivia + firma electrónica. §44 FISCAL-CONTABLE-LATAM.
- **F15.6** 🔴 — Verificación DAG en vivo: DEPENDENCY_RESOLVER ordenó instalación correcta.
- **F15.7** 🔴 — Certificación Capa 6: seed completo INSTALADA + probe ✓ × todas las fichas. bNotify push real ✓, Tryton login ✓.

### FASE 16 — Capa 7: VDI Layer (13 átomos 🔴, 1 🟡)

- **F16.1** 🔴 — Ficha nextcloud: db + OIDC + PVC 500Gi + carpetas + Kong files.{tenant} → C-09.
- **F16.2** 🟡 — Ficha guacamole: db + OIDC + pool VNC + Kong vdi.{tenant} → C-10. Ficha YAML creada, falta despliegue real e integración OIDC en cluster.
- **F16.3** 🔴 — Imagen fedora-logico (Fedora 42 + GNOME + TigerVNC + nextcloud-client) en CI. Registry interno.
- **F16.4** 🔴 — Ficha fedora-logico: HPA min=2/max=20 + mTLS Vault PKI.
- **F16.5** 🔴 — sbos-client en el MONOREPO: src/cmd/sbos-client/ + internal/sbosclient/. Reutiliza wslib/paths/audit. 3 modos autodetectados.
- **F16.6** 🔴 — identity: WS mTLS :9444 → device_register → dctx_id pre-auth (bitmask 0x0) + heartbeat 30s + backoff 1→60s. Fail-secure.
- **F16.7** 🔴 — session: PUSH context.promoted → dconf (apps por BitMask) + montar home Nextcloud + env ctx_id. noexec/nosuid.
- **F16.8** 🔴 — ciclo: context.expired → limpiar dconf + desmontar (disco local VACÍO) + pool. TTL sin conexión = fail-secure. systemd + supervisor pod.
- **F16.9** 🔴 — tests: modos PHYSICAL/LOGICAL/WSL + promoted/expired + reconexión + fail-secure (bhnexus stub WS). 6 tests.
- **F16.10** 🔴 — Pods fedora-logico ≥2 Running + registrados → C-11.
- **F16.11** 🔴 — Home montado (ls ~/Documentos) → C-12. device.register <2s → C-13.
- **F16.12** 🔴 — sbos-fedora.iso CON datos del tenant: kickstart + lorax CI + SHA256 + firma Ed25519. Descargable via bosctl iso download. 🔴 gate clave privada.
- **F16.13** 🔴 — bosctl vdi verify --tenant=skull → 6/6 contra fichas REALES. Reemplaza probe stubs F9.9.
- **F16.14** 🔴 — C-14 e2e: test-user → login web → Keycloak → GNOME <10s → archivo persiste en Nextcloud. ✦ LA CÚSPIDE: "El SBOS está instalado".

### FASE 18 — Web Platform Soberana (10 átomos 🔴)

- **F18.1** 🔴 — Diseño routing table Kong: reglas host-based por tenant/empresa/sucursal → docs/WEB-PLATFORM-ROUTING.md.
- **F18.2** 🔴 — Domain Resolver: tabla web_domains en bkernel_db + bos.web.domain.resolve JSON-RPC. O(1).
- **F18.3** 🔴 — CTX Resolver: crea dctx_id anónimo vía bos.ctx.device.register si no hay ctx_id activo.
- **F18.4** 🔴 — Cookie __sbos_dctx: HttpOnly + Secure + SameSite=Strict + TTL 30min.
- **F18.5** 🔴 — Website Engine: cluster pods por tenant (HPA min=2), sirve contenido YAML-declarado.
- **F18.6** 🔴 — Ficha website-engine: manifest.yml + rutas Kong + health + métricas + dashboard.json.
- **F18.7** 🔴 — context.promoted event: dctx_id queda enlazado al ctx_id en context_sessions (FK no-destrucción).
- **F18.8** 🔴 — Flujo completo e2e: visita anónima → dctx_id → login → ctx_id → contenido autorizado.
- **F18.9** 🔴 — bosctl web domain add {dominio} --tenant=X --empresa=Y --sucursal=Z.
- **F18.10** 🔴 — Certificación Web Platform: 3 dominios → 3 tenants → contenidos distintos. ctx_id correcto en cada sesión.

### FASE 19 — bSearch + bCompass (7 átomos 🔴)

- **F19.1** 🔴 — bSearch: diseño índice GIN universal busqueda_universal en PostgreSQL 18+. Particionado por tenant_id. pg_trgm + tsvector.
- **F19.2** 🔴 — bSearch: ficha declarativa con Redis Stream bkernel:index_queue. bkernel alimenta vía WAL.
- **F19.3** 🔴 — bSearch: WebSocket exclusivo wss:// :9493 + Unix socket /run/bos/bsearch.sock. Sin HTTP REST (SBOS-050 P9).
- **F19.4** 🔴 — bSearch: search-as-you-type con ranking por tenant (GIN score). Latencia P99 < 50ms para 1M registros.
- **F19.5** 🔴 — bCompass: Unix socket /run/bos/bcompass.sock + :9480-:9481 + HITL event loop.
- **F19.6** 🔴 — bCompass: integración con LLM (modelo configurable, no hardcodeado). ADR anti-alucinación obligatorio.
- **F19.7** 🔴 — Certificación bSearch: query 3 tenants distintos → resultados aislados ✓.

### FASE 20 — Desacoplamiento + Certificación Continua (19 átomos 🔴)

- **F20.A.1** 🔴 — contracts/events/: paquete compartido tipos puros. seed_params.go + saga_event.go. DTC-11.
- **F20.A.2** 🔴 — SAGA_SNAPSHOT: mensaje resync al reconectar TUI. DTC-06 + DC-03. Event Sourcing Snapshot.
- **F20.A.3** 🔴 — Command validation en daemon: comandos TUI validados por daemon, no por UI. DTC-07 + DC-05. Patrón CQRS.
- **F20.A.4** 🔴 — Test DTC-05 automatizado: kill -9 TUI paso 3/7 → daemon completa saga. DTC-05 + DC-02.
- **F20.A.5** 🔴 — Verificación DTC-10: inspección payloads WebSocket. Secretos nunca en tránsito. ISO 27001 A.8.15.
- **F20.A.6** 🔴 — Persistencia pre-saga: seed_params → bkernel_db ANTES de lanzar saga. DTC-12 + DC-07. Transactional outbox.
- **F20.A.7** 🔴 — TUI post-instalación: snapshot real del daemon. DTC-13 + DC-10.
- **F20.B.1** 🔴 — Suite DC-01 a DC-05: 5 tests automatizados en internal/decoupling/. DC-01 sin TUI, DC-02 kill TUI, DC-03 reconexión, DC-04 multi-observador, DC-05 comando rechazado.
- **F20.B.2** 🔴 — Suite DC-06 a DC-10: 5 tests. DC-06 scan payloads, DC-08 diff wizard/seed, DC-09 wizard pre-rellenado, DC-10 TUI post 24h.
- **F20.C.1** 🔴 — bosctl setup --seed seed.yml: wizard pre-rellenado desde seed.yml. DTC-09 + DC-09.
- **F20.C.2** 🔴 — Materialización seed.yml desde wizard: al confirmar P4, generar seed.yml con parámetros.
- **F20.D.1** 🔴 — Gate 2 automatizado: lint de diseño en CI. golangci-lint + gocyclo (max 15) + funlen (100 líneas) + dupl (<3%).
- **F20.D.2** 🔴 — Gate 4 automatizado: ADR requerido para decisiones de diseño. CI check.
- **F20.D.3** 🔴 — Dashboard métricas de código en CI: cobertura, complejidad, duplicación.
- **F20.D.4** 🔴 — Monitor señales de alarma (Roja/Amarilla/Azul) en CI. Alarma Roja: tests rotos, deps cíclicas, secretos.
- **F20.E.1** 🔴 — Verificación formal DTC-01: deploy sin TUI en CI automatizado.
- **F20.E.2** 🔴 — Verificación DTC-02: daemon no bloquea por ausencia de TUI.
- **F20.E.3** 🔴 — Verificación DTC-04: pub/sub con N suscriptores simultáneos.
- **F20.E.4** 🔴 — Verificación DTC-08: FICHA_LOG legible sin TUI. bosctl ficha logs postgresql.

### FASE 23 — Servidor S12 Blockchain (12 átomos 🔴)

- **F23.A.1** 🔴 — Servidor lógico S12/blockchain: crear estructura en servers/. Red Besu QBFT privada.
- **F23.A.2** 🔴 — NetworkPolicy S12: aislamiento red blockchain. Solo p2p:30303, rpc:8545, métricas Besu.
- **F23.B.1** 🔴 — besu-genesis/manifest.yml: Job único. 4 validadores QBFT, blockperiod=2s.
- **F23.B.2** 🔴 — besu-genesis/task_catalog.sh: ejecuta job K8s, almacena ConfigMap besu-genesis.
- **F23.C.1** 🔴 — besu-validator/manifest.yml: StatefulSet 4 réplicas. hyperledger/besu:24.12. 2000m CPU, 4Gi RAM, 50Gi storage.
- **F23.C.2** 🔴 — besu-validator/task_catalog.sh: crear StatefulSet, esperar 4 pods Ready. QBFT consensus check.
- **F23.C.3** 🔴 — besu-validator/keys/: gestión claves ECDSA secp256k1 en Vault. Rotación 180 días. NIST SP 800-57.
- **F23.D.1** 🔴 — besu-rpc/manifest.yml: Deployment 2 réplicas. Sin participación consenso. Solo lectura y envío tx.
- **F23.D.2** 🔴 — besu-rpc/task_catalog.sh: crear Deployment, Service ClusterIP. eth_blockNumber test.
- **F23.E.1** 🔴 — bauth-blockchain-config/manifest.yml: Tipo Config. Inyecta [blockchain] en bauth.toml.
- **F23.E.2** 🔴 — bauth-blockchain-config/task_catalog.sh: leer genesis.json, extraer dirección contrato, escribir bauth.toml.
- **F23.F.1** 🔴 — StorageClass bos-blockchain: 50Gi persistentes. Provisioner local-path. Retain policy.
- **F23.F.2** 🔴 — Monitoreo Besu: Prometheus metrics + Grafana dashboard. AnchorDown (P1), ValidatorDown (P1), GasBalanceCritical (P1).
