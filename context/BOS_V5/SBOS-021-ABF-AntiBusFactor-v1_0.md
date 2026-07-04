# SBOS-021-ABF — Plan Anti-Bus-Factor y Continuidad de Conocimiento
## Sección para insertar en SBOS-021 (Onboarding)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-021-ABF (sección complementaria de SBOS-021)
**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Gobierno Organizacional
**Complementa:** SBOS-021-Onboarding-v1_0.md (sección complementaria anti bus-factor)
**Insertar en:** SBOS-021 — Onboarding, como nueva sección al final del documento

---

## §ABF — Plan Anti-Bus-Factor y Continuidad de Conocimiento

El Bus Factor de un componente es la cantidad mínima de personas cuya salida simultánea dejaría ese componente sin nadie capaz de mantenerlo, evolucionarlo u operarlo ante un fallo. Un Bus Factor = 1 significa que una sola persona concentra el conocimiento crítico.

SBOS tiene componentes con alta complejidad técnica especializada: daemons Rust con lógica de replicación WAL, un IAM Installer con Sagas de compensación, y configuraciones de PostgreSQL que si se alteran rompen silenciosamente la sincronización de datos del sistema. El objetivo de este plan es elevar el Bus Factor a ≥ 2 en todos los componentes críticos antes de Q3 2026.

---

### §ABF.1 — Tabla de propiedad de componentes críticos

| Componente | Descripción técnica | Propietario Principal | Co-Propietario | Nivel Doc (1–5) | Riesgo si propietario sale | Fecha límite transferencia |
|---|---|---|---|---|---|---|
| **bKernel** | Binario Rust. Lee WAL via replicación lógica pgoutput. Rule Engine YAML declarativo. Checkpoints LSN en bkernel_db. Sin puerto. Hot-reload via SIGHUP. | — | — | 2 | **Crítico:** ninguna evolución de reglas ni fix de bugs. El daemon sigue operativo pero no puede mejorarse ni depurarse. | Q3 2026 |
| **SBOS Data Integration** | Binario Rust. Cajas .so por país (SIAT Bolivia, AFIP Argentina, SAT México). Hot-reload via SIGUSR1. Credenciales desde Vault. | — | — | 2 | **Alto:** integraciones tributarias no se pueden evolucionar. Las cajas existentes siguen funcionando pero no se pueden corregir. | Q3 2026 |
| **SBOS AI Tools** | Binario Go. Rutas .so (agent, flow, analyst, report). LLM local via Ollama. Protocolo SIGUSR2 → SBOS VDI. Sin puerto. | — | — | 2 | **Alto:** rutas de IA no se pueden extender. Funcionalidades AI del sistema se congelan. | Q3 2026 |
| **IAM Installer Core** | 4 archivos maestros Bash + 16 módulos Python (6 Dominio, 8 Orquestación). Sagas de instalación con compensación. API REST FastAPI + WebSocket. | — | — | 3 | **Crítico:** nuevas fichas no se pueden integrar, drift detection no evoluciona, onboarding de nuevos clientes se bloquea. | Q2 2026 |
| **Sistema de Fichas** | `manifest.yml` + `yaml_engine.yml` + `resources/`. FICHA_LINTER.py valida contratos. Pipeline CI/CD en GitLab. | — | — | 3 | **Medio:** fichas existentes operan, nuevas fichas requieren conocimiento del formato y el linter. | Q2 2026 |
| **Slots replicación PostgreSQL** | Slots pgoutput por BD: `bkernel_tryton`, `bkernel_orangehrm`, `bkernel_saleor`, etc. WAL level=logical en postgresql.conf. | — | — | 2 | **Alto:** administrador sin conocimiento puede eliminar un slot accidentalmente. El bKernel deja de procesar eventos de esa app sin error visible inmediato. | Q2 2026 |
| **Keycloak SPIs y H-RBAC** | 5 SPIs custom: SkbosBehavioralScoreAuthenticator, role_calculator y otros. Realms multi-tenant. H-RBAC con atributos de realm. | — | — | 3 | **Medio:** autenticación sigue funcionando, pero SPIs custom no evolucionan y configuraciones avanzadas de realm quedan sin soporte. | Q3 2026 |
| **Pipeline CI/CD y Release Plane** | GitLab CI en S14. Firma Ed25519 de artefactos. Canales canary/early/stable. `make release` como punto de entrada unificado. | — | — | 3 | **Alto:** releases del stack se bloquean. Parches críticos no llegan a clientes. | Q2 2026 |

**Leyenda de Nivel de Documentación:**

| Nivel | Descripción |
|-------|-------------|
| **1** | Solo en la cabeza del propietario. Sin documentación escrita. |
| **2** | Notas informales, comentarios en código, conversaciones de Slack. |
| **3** | Documento técnico básico existe (como los actuales SBOS-0XX). |
| **4** | Documentación con ejercicios prácticos verificables por un tercero. |
| **5** | Cualquier ingeniero mid-level puede operar el componente de forma independiente siguiendo la documentación. |

---

### §ABF.2 — Plan de transferencia por componente (Bus Factor = 1)

Para cada componente con Bus Factor = 1, el plan de transferencia define la sesión mínima viable, el ejercicio de validación que confirma la transferencia exitosa, y el timeline comprometido.

---

#### bKernel

**Riesgo específico:** la combinación de Rust + replicación lógica WAL de PostgreSQL + semántica del Rule Engine YAML es la habilidad técnica más especializada del stack. No hay sustitutos disponibles en el mercado sin un período de onboarding de 2–3 meses.

**Perfil de complejidad Rust para bkernel/biedata:** un desarrollador experimentado en C/C++ o Go necesita 2–4 semanas de ramp-up antes de ser productivo en Rust. Las habilidades críticas son: (1) modelo de ownership y borrow checker — especialmente en el manejo de referencias al LSN y al estado del WAL; (2) programación async con tokio — los handlers de eventos WAL son futures encadenados; (3) C ABI para los `.so` de reglas/cajas — el unsafe block debe ser explícito y documentado. Una vez dominado el borrow checker, el compilador previene exactamente las clases de bugs más costosas en CDC: use-after-free, data races y null pointers que en Go o Python solo se descubren en producción bajo carga.

**Sesión mínima viable:** 16 horas en 4 bloques de 4 horas cada uno.

| Bloque | Tema | Objetivo concreto |
|--------|------|-------------------|
| 1 | Arquitectura WAL y replicación lógica | Entender cómo funciona un slot pgoutput, qué es el LSN y cómo el bKernel lo checkpointa en bkernel_db |
| 2 | Rule Engine YAML | Leer las reglas existentes en `/etc/bos/blibs/bkernel/rules/`, entender la sintaxis forward-chaining, escribir una regla nueva sencilla |
| 3 | Writer Pool e idempotencia | Entender la tabla `bkernel_db.processed_events`, el mecanismo de deduplicación por event_id, leer `writer_pool.rs` |
| 4 | Operación diaria | Monitoreo de `bkernel_wal_lag_seconds` en Grafana, rotación de configuración con SIGHUP, interpretación del DLQ |

**Ejercicio de validación (ejecutar sin ayuda del propietario):**
1. Añadir una regla YAML nueva en `/etc/bos/blibs/bkernel/rules/test_rule.yaml` que capture un evento de `tryton_db` y escriba un registro en una tabla de prueba.
2. Ejecutar `sudo kill -SIGHUP $(pidof bkernel)` para hot-reload sin reinicio.
3. Generar el evento WAL (insertar un registro en la tabla monitoreada).
4. Verificar en la tabla de prueba que el bKernel procesó el evento.
5. En Grafana, confirmar que `bkernel_wal_lag_seconds` está por debajo de 500ms.
6. Simular un alerta de `bkernel_dlq_size > 0` y diagnosticar la causa.

**Timeline:** sesiones completadas en Q2 2026. Ejercicio de validación ejecutado con observador en Q3 2026.

---

#### SBOS Data Integration

**Riesgo específico:** el conocimiento de los formatos XML de SIAT (Bolivia), los endpoints WSFE de AFIP (Argentina) y el flujo PAC para SAT (México) es regulatorio-técnico. Si el propietario sale durante el período de homologación de un nuevo país, el proceso debe reiniciarse desde cero con la autoridad tributaria.

**Sesión mínima viable:** 12 horas en 3 bloques de 4 horas.

| Bloque | Tema | Objetivo concreto |
|--------|------|-------------------|
| 1 | Arquitectura de cajas .so | Cómo cargar/recargar una caja, cómo funciona el Redis Stream como trigger desde el bKernel, gestión de credenciales en Vault |
| 2 | Bolivia SIAT | Formato XML del SIN, sandbox vs producción, códigos de error, certificados digitales requeridos |
| 3 | Argentina AFIP + México SAT | Overview de cada integración, diferencias de flujo, gestión de CSD, proceso con PAC (México) |

**Ejercicio de validación:** ejecutar un ciclo completo de facturación en el sandbox de Bolivia (SIAT) desde la inserción en Tryton hasta el número de autorización retornado, sin consultar al propietario. Verificar en `biedata_db` que el resultado fue almacenado correctamente.

**Timeline:** Q3 2026.

---

#### SBOS AI Tools

**Sesión mínima viable:** 8 horas en 2 bloques.

| Bloque | Tema | Objetivo concreto |
|--------|------|-------------------|
| 1 | Arquitectura de rutas .so | Cómo se carga una ruta, el protocolo SIGUSR2 → SBOS VDI, cómo SBOS AI Tools usa Ollama local, hot-reload de prompts via SIGUSR1 |
| 2 | Crear y depurar rutas | Crear una ruta `flow` desde el template, depurar con logs, ejecutar rollback de una ruta |

**Ejercicio de validación:** crear una ruta `flow` nueva que tome datos de Tryton via PostgreSQL y genere un reporte en texto plano usando Ollama. Ejecutar la ruta, verificar el output, y ejecutar rollback a la versión anterior.

**Timeline:** Q3 2026.

---

#### IAM Installer Core

**Riesgo específico:** la separación entre Capa de Dominio (STATE_MANAGER, DEPENDENCY_RESOLVER, HEALTH_CHECKER, FICHA_LINTER, FICHA_PROBE, GROWTH_DETECTOR) y Capa de Orquestación (8 módulos Python) con Sagas de compensación es arquitectura no trivial. Una modificación incorrecta del flujo de compensación puede dejar una instalación a medias sin capacidad de rollback automático.

**Sesión mínima viable:** 16 horas en 4 bloques.

| Bloque | Tema | Objetivo concreto |
|--------|------|-------------------|
| 1 | 4 archivos maestros Bash | Cuándo se usa cada archivo maestro, cómo funciona el `.sbos_state.json` como árbitro de estado |
| 2 | 6 módulos de Dominio | Qué hace cada módulo, cuándo se invoca, cómo debuggear |
| 3 | Sagas y compensación | Cómo funcionan las Sagas, cómo escribir un paso nuevo, cómo funciona la compensación si falla un paso intermedio |
| 4 | Recuperación de instalaciones | Depurar una instalación atascada, recover manual de un estado inconsistente, uso de `make rollback` |

**Ejercicio de validación:** simular un fallo en el paso 4 de una instalación de staging y verificar que la compensación revierte los pasos anteriores limpiamente, dejando el sistema en estado inicial conocido.

**Timeline:** Q2 2026 (prioritario — es bloqueante para onboarding de nuevos clientes).

---

#### Slots de replicación PostgreSQL

**Riesgo específico:** este es el componente con mayor probabilidad de fallo accidental. Un DBA o administrador que no conoce los slots puede eliminarlos creyendo que son recursos huérfanos. La consecuencia es que el bKernel deja de sincronizar los datos de la aplicación afectada **sin emitir un error inmediato** — el fallo se descubre días o semanas después cuando se notan inconsistencias de datos.

**Sesión mínima viable:** 4 horas (1 bloque).
- Qué son los slots de replicación lógica y por qué existen en SBOS.
- Listar y entender los slots activos: `SELECT * FROM pg_replication_slots WHERE plugin='pgoutput'`.
- Por qué NO se deben eliminar manualmente y cuáles son las consecuencias.
- Cómo recrear un slot eliminado accidentalmente con el comando correcto.
- El parámetro `max_slot_wal_keep_size` y el riesgo de invalidación automática.

**Ejercicio de validación:** dado un slot invalidado en staging, recrearlo correctamente, reiniciar el bKernel, y verificar en Grafana que `bkernel_wal_lag_seconds` baja a < 500ms.

**Timeline:** Q2 2026. Este es el componente con menor barrera de aprendizaje y mayor riesgo de fallo accidental — debe priorizarse primero.

---

### §ABF.3 — Proceso de onboarding para clientes TI

Al completar la instalación de SBOS en el servidor del cliente, el administrador TI del cliente recibe el siguiente kit de onboarding.

#### Kit mínimo entregado post-instalación (5 documentos)

| # | Documento | Por qué lo necesita |
|---|-----------|---------------------|
| 1 | **SBOS-026** — Guía de Backup, Restore y DR | Para entender qué pasa si el servidor falla y cómo recuperarlo. Los runbooks RK-011/012/013 son su referencia de emergencia. |
| 2 | **SBOS-024** — Operaciones y Runbooks | Los runbooks RK-001 a RK-010 cubren los incidentes más comunes: bKernel caído, Keycloak no responde, disco lleno, lag WAL elevado. |
| 3 | **SBOS-021** — Onboarding (este documento) | El plan anti-bus-factor, qué puede operar solo vs. qué escala a SKULL, y los slots de replicación PostgreSQL que no debe tocar. |
| 4 | **SBOS-023** — Seguridad | Las políticas de seguridad: gestión de accesos, rotación de contraseñas, qué hacer ante un incidente de seguridad. |
| 5 | **Checklist de Operaciones Diarias** *(entregado en formato de 1 página)* | 10 ítems de verificación diaria: estado del bKernel, backup reciente en MinIO, alertas activas en Grafana, salud de Keycloak, espacio en disco. |

#### Qué puede operar el cliente sin soporte SKULL

- Gestionar usuarios y roles en el Core UI.
- Revisar alertas en Grafana y ejecutar los runbooks RK-001 a RK-010 de SBOS-024.
- Modificar reglas YAML del bKernel en `/etc/bos/blibs/bkernel/rules/` y hacer hot-reload con SIGHUP *(solo después de completar la sesión de capacitación del §ABF.2)*.
- Ejecutar el script de validación post-restore: `/usr/local/bin/sbos-restore-validate.sh`.
- Verificar el estado del backup: `pgbackrest --stanza=sbos info`.
- Gestionar el realm de Keycloak: configurar flows de autenticación, gestionar clientes OAuth2, gestionar usuarios y roles.
- **Listar** los slots de replicación y **verificar** su estado — pero NO eliminarlos.

#### Qué requiere soporte SKULL obligatoriamente

| Situación | Por qué requiere SKULL |
|-----------|----------------------|
| Fallo del IAM Installer que no recupera RK-008 | Arquitectura de Sagas no trivial |
| Cambios en daemons soberanos (binarios, configuración) | Requiere conocimiento Rust + protocolo WAL |
| Instalación de fichas fuera del catálogo estándar | Requiere conocimiento del FICHA_LINTER y el Release Plane |
| Slot de replicación invalidado que no se puede recrear | Riesgo de pérdida de sincronización de datos |
| Incidente de seguridad con severidad critical en Wazuh | Puede requerir revocar el Release Plane o rotar claves Ed25519 |
| Actualización de versión mayor de PostgreSQL | Proceso formal de 4 pasos (ver SBOS CP-08) |

**Canal de escalación:** `soporte@skull.systems`
**SLA de respuesta:** P1 (sistema caído) → 4 horas hábiles · P2 (degradado) → 8 horas hábiles

---

### §ABF.4 — Cronograma de transferencia 2026

| Trimestre | Componentes a transferir | Meta Bus Factor |
|-----------|--------------------------|----------------|
| Q2 2026 | Slots PostgreSQL, IAM Installer Core, Sistema de Fichas, Pipeline CI/CD | ≥ 2 en los 4 componentes |
| Q3 2026 | bKernel, SBOS Data Integration, SBOS AI Tools, Keycloak SPIs | ≥ 2 en los 4 componentes |
| Q4 2026 | Revisión y re-ejecución de todos los ejercicios de validación | Confirmar Bus Factor ≥ 2 en toda la tabla |

**Medición:** en cada revisión trimestral del OKR-4 (SBOS-001), el Arquitecto Lead actualiza la columna "Nivel Doc" y registra qué ejercicios de validación han sido completados. El KR-4.2 (*Bus Factor ≥ 2 en todos los daemons soberanos al Q3 2026*) se considera cumplido cuando los tres ejercicios de validación de bKernel, SBOS Data Integration y SBOS AI Tools han sido ejecutados con éxito por los co-propietarios sin asistencia del propietario principal.

---

*SKULL · SBOS · SBOS-021-ABF · v1.0 · Marzo 2026*
*Sección para insertar en SBOS-021 (Onboarding)*
*Complementa: SBOS-024 (Runbooks), SBOS-026 (DR), SBOS-001 (OKRs KR-4.2)*
