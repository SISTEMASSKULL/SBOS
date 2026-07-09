# SBOS — Revocación y Eliminación de Accesos v1.0
## Políticas de Revocación Inmediata, Suspensión, Offboarding, Revisión Periódica y Detección de Privilege Creep
### SKULL · SBOS · Junio 2026 · Alineado con bAuth v2.0

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`. Para desarrollo, consultar los manuales actualizados.

| Campo | Valor |
|---|---|
| **Código** | SBOS-BAUTH-ACCESS-REVOCATION-v1_0 |
| **Versión** | 1.0 · BitMask Dual Jun 2026 |
| **Estado** | ACTIVO |
| **Propósito** | Definir políticas y procedimientos para revocación de accesos, suspensión temporal, offboarding, revisión periódica, detección de privilege creep, terminación de emergencia, y auditoría de ciclo de vida de acceso |
| **Estándares** | ISO 27001:2022 A.9.2 (User Access Management) · NIST SP 800-53 AC-2/6/7 · OWASP ASVS v5.0 §2.3 · ISACA COBIT 2019 · RGPD Art.17 |
| **Integra** | SBOS-USERTEMPLATE-v6_0 · Authentication_Framework_v3.json · BAUTH-CONTRATO-SYMBIOSIS · Policies_Authentication_Framework_v4.json |

---

## 1. PRINCIPIO ABSOLUTO

> **El acceso debe ser revocado tan rápido como fue concedido — si no más rápido.**
> La revocación inmediata (< 30 segundos) es un requisito de seguridad, no una optimización.
> Todo acceso no revisado en 90 días es un acceso potencialmente no autorizado.

---

## 2. REVOCACIÓN INMEDIATA DE ACCESO

### 2.1 Flujo de Revocación — ISO 27001 A.9.2.5

```
POST /bauth.access/revoke
Body: { user_uuid, reason, approver_role }

Flujo (objetivo: < 30 segundos):
  T+0s:  Validar autorización del solicitante (admin tenant o superior)
  T+1s:  Keycloak: POST /admin/realms/{realm}/users/{id}/logout — todas las sesiones
  T+2s:  Keycloak: DELETE /admin/realms/{realm}/users/{id}/role-mappings/realm
  T+3s:  Kong: invalidar cache de ctx_id para este usuario
  T+4s:  bAuth: ctx_id → StateInvalidado en BD + eliminar de Redis DB1
  T+5s:  Tryton: model.res.user.write(active=false)
  T+6s:  bhnexus: invalidar cache físico del usuario en todos los nodos
  T+7s:  banexus: si sesión shell activa → kill session
  T+10s: audit_event registrado con ctx_id, motivo, approver
  T+15s: notificación al usuario (email) y al admin (dashboard)
  T+30s: verificación: GET /bauth.access/status/{user_uuid} → active=false en KC+Tryton+NEXUS
```

### 2.2 Verificación Post-Revocación

```
Cada revocación dispara un check de verificación a los 30s:
  - KC: GET /admin/realms/{realm}/users/{id} → enabled=false, sessions=0
  - Tryton: model.res.user.search_read([('id','=',user_id)]) → active=false
  - NEXUS: bhnexus cache miss para user_id → confirmado
  - Kong: ctx_id validación → 401 Unauthorized
  Si cualquier check falla → alerta Wazuh (severity: HIGH) → reintento automático cada 30s hasta éxito
```

---

## 3. SUSPENSIÓN TEMPORAL DE ACCESO — ISO 27001 A.9.2.6

### 3.1 Casos de Uso

| Motivo | Duración Típica | Reactivación |
|--------|----------------|-------------|
| Vacaciones / licencia | 7-30 días | Automática en fecha |
| Investigación de seguridad | Indefinido (hasta resolución) | Manual por admin seguridad (S003) |
| Sanción administrativa | 1-90 días | Automática en fecha |
| Maternidad / paternidad | 90-180 días | Automática en fecha |

### 3.2 Flujo de Suspensión

```
POST /bauth.access/suspend
Body: { user_uuid, reason, suspend_until (ISO 8601), approver_role }

Flujo:
  1. Validar autorización (admin tenant + security cuando es investigación)
  2. KC: no logout — sessions se mantienen pero expiran naturalmente
  3. KC: user enabled=false (no nuevos logins)
  4. Tryton: user active=false
  5. Kong: ctx_id existentes siguen válidos hasta TTL (máx 24h)
  6. Cron job: al llegar suspend_until → reactivar automáticamente
  7. Reactivación: KC enabled=true, Tryton active=true, notificar usuario
  8. Audit: suspensión + reactivación registradas
```

---

## 4. OFFBOARDING COMPLETO (ELIMINACIÓN DE ACCESO) — NIST AC-2(3)

### 4.1 Flujo de Offboarding en 6 Pasos

```
P1 — Notificación RRHH (T-7 días):
  OrangeHRM webhook → bAuth: employee.termination_date = YYYY-MM-DD
  bAuth agenda offboarding automático para termination_date 23:59

P2 — Revocación de Sesiones (T+0, < 30s):
  Mismo flujo que §2.1 (revocación inmediata)

P3 — Desactivación KC (T+1 min):
  POST /admin/realms/{realm}/users/{id} → enabled=false
  NO eliminar usuario (preservar para auditoría)
  Mover a group: "Ex-employees" (sin roles)
  User attributes: termination_date, termination_reason

P4 — Desactivación Tryton (T+2 min):
  model.res.user.write(active=false)
  NO eliminar (NUNCA usar DELETE en Tryton)
  Desasignar todos los grupos (grupos = [])
  Archivar documentos creados por el usuario (read-only)

P5 — Archivo PII (T+1 día):
  Exportar datos personales del usuario (RGPD Art.20 portability)
  Almacenar en bucket S3/MinIO "ex-employees/{year}/{user_uuid}.json"
  Cifrado AES-256-GCM. Clave en Vault.
  Retention: según jurisdicción (BO: 8 años fiscal, EU: 5 años RGPD)

P6 — Notificación y Auditoría (T+1 día):
  Notificar RRHH: offboarding completado
  Notificar manager: empleado dado de baja del sistema
  Generar informe de offboarding: fecha, roles revocados, datos archivados
  Audit event: OFFBOARD_COMPLETE con todos los pasos ejecutados
```

### 4.2 Retención de Datos por Jurisdicción

| Jurisdicción | Retención Fiscal | Retención Laboral | Base Legal |
|-------------|-----------------|-------------------|-----------|
| Bolivia | 8 años (Código de Comercio Art.44) | 5 años (Ley General del Trabajo) | Ley 164, SIN |
| Unión Europea | 5 años (facturas) | 3 años (nómina) | RGPD Art.17 |
| Latinoamérica (general) | 5-10 años según país | 2-5 años según país | Leyes locales |

---

## 5. REVISIÓN PERIÓDICA DE ACCESOS (ACCESS REVIEW) — ISO 27001 A.9.2.1

### 5.1 Calendario de Revisiones

| Tipo de Cuenta | Frecuencia | Revisor | Acción si no responde |
|---------------|-----------|---------|----------------------|
| SU (S001) | Mensual | Admin Seguridad (S003) + CISO | Bloqueo inmediato |
| SYS (S002-S048) | Mensual | Admin Proyecto (S002) | Escalar a CISO |
| BIZ_N4-N5 (Gerencia/Dirección) | Trimestral | Admin Tenant (S016) | Auto-revocar acceso a 14 días |
| BIZ_N1-N3 (Operativo/Técnico) | Trimestral | Manager directo + Admin Sucursal | Notificar RRHH |
| M2M (S020-S048) | Semestral | Admin Módulo (N2) | Rotar credenciales automáticamente |
| EXT_N0 (Clientes) | Anual | Admin Tenant (S016) | Cuenta → inactiva (no eliminada) |

### 5.2 Proceso de Revisión

```
1. Sistema genera reporte de acceso: user, roles, último login, privilegios activos
2. Notifica al revisor: "Tienes N accesos para revisar. Deadline: DD/MM/YYYY."
3. Revisor accede a dashboard de revisión:
   - Aprueba (acceso sigue siendo necesario)
   - Revoca (acceso ya no necesario)
   - Modifica (reduce privilegios)
   - Escala (no estoy seguro — que revise seguridad)
4. Si revisor no responde en deadline:
   - 1er recordatorio: 7 días antes
   - 2do recordatorio: 1 día antes
   - Vencido: acción automática según tabla §5.1
5. Audit event por cada decisión del revisor
6. Informe trimestral al CISO con estadísticas de revisión
```

---

## 6. DETECCIÓN DE PRIVILEGE CREEP — NIST AC-6 (Least Privilege)

### 6.1 ¿Qué es Privilege Creep?

Acumulación gradual de permisos innecesarios debido a:
- Cambios de puesto (nuevo rol asignado, viejo no revocado)
- Promociones (hereda permisos del puesto anterior)
- Proyectos temporales (acceso concedido, nunca revocado)
- Delegaciones (delegación expirada pero permisos residuales)

**ISACA reporta que el 37% de organizaciones descubren cuentas con privilegios excesivos.**

### 6.2 Algoritmo de Detección

```
Job semanal (domingo 03:00 UTC):

1. Para cada usuario activo:
   a. Listar todos los roles asignados (bos_user_template.roles[])
   b. Calcular BitmaskBundle efectivo (OR de todos los roles)
   c. Comparar con el puesto actual del usuario (OrangeHRM job_title)
   d. Identificar bits de permisos que NO corresponden al puesto actual

2. Heurísticas de detección:
   - Usuario con ≥ 3 roles activos → revisar
   - Usuario con bits de sistema (capa 1) sin ser SYS → CRÍTICO
   - Usuario con bits financieros (Q3) + bits de compras → posible SoD
   - Delegación expirada hace > 7 días pero permisos aún presentes
   - Usuario sin login en > 90 días con privilegios activos

3. Scoring de riesgo (0-100):
   - bits_sistema_activos_sin_ser_SYS: +40
   - SoD_violado: +30
   - delegacion_expirada_no_revocada: +20
   - sin_login_90_dias: +10

4. Acciones según score:
   - 0-20: log + observación
   - 21-50: notificar manager para revisión
   - 51-80: ALERTA Wazuh (severity: MEDIUM) + revocación automática de bits sobrantes
   - 81-100: ALERTA Wazuh (severity: HIGH) + revocación TOTAL + investigación
```

---

## 7. TERMINACIÓN DE EMERGENCIA — ISO 27001 A.9.2.2

### 7.1 Gatillos de Emergencia

| Evento | Tiempo Máximo de Respuesta | Quién Ejecuta |
|--------|--------------------------|---------------|
| Despido con causa (brecha de seguridad) | < 5 minutos | Admin Seguridad (S003) + Admin Tenant (S016) |
| Acceso no autorizado detectado | < 5 minutos | Admin Seguridad (S003) |
| Orden judicial | < 2 horas | Admin Proyecto (S002) + Legal |
| Compromiso de credenciales confirmado | < 5 minutos | Admin Seguridad (S003) |

### 7.2 Flujo de Terminación de Emergencia

```
POST /bauth.access/emergency-terminate
Body: { user_uuid, reason, severity ("critical"), approver_role }

Flujo (< 5 minutos):
  T+0s:   Autenticación del aprobador (requiere MFA + justificación)
  T+10s:  Revocar TODAS las sesiones (KC, Kong, ctx_id, Redis)
  T+20s:  Bloquear acceso físico (bhnexus → todos los nodos → deny)
  T+30s:  Invalidar credenciales (KC disable, password scramble)
  T+60s:  Revocar todos los roles asignados
  T+90s:  Transferir propiedad de documentos al manager
  T+120s: Iniciar forense: snapshot de logs, sesiones, accesos (últimos 90 días)
  T+180s: Notificar: CISO, RRHH, Legal, manager directo
  T+240s: Auditoría post-evento: informe detallado de todo lo ejecutado

Post-evento (24-72h):
  - Forense completo: accesos, documentos, emails, patrones
  - Entrevista con seguridad si aplica
  - Informe final al CISO con recomendaciones
```

---

## 8. GHOST ACCOUNT DETECTION (CUENTAS HUÉRFANAS)

### 8.1 Detección Automática

```
Job diario (03:00 UTC):

Comparar fuentes de verdad:
  - OrangeHRM (empleados activos)
  - Keycloak (usuarios enabled=true)
  - Tryton (res.users active=true)
  - bos_user_template (status=ACTIVE)

Ghost accounts detectadas si:
  - Usuario activo en KC pero NO en OrangeHRM → posible ex-empleado no desactivado
  - Usuario activo en Tryton pero NO en KC → inconsistencia de sync
  - Usuario en bos_user_template sin KC user → error de provisioning
  - Usuario sin login en > 180 días con privilegios activos → cuenta abandonada

Acción automática:
  1. Ghost account detectada → ALERTA Wazuh (severity: MEDIUM)
  2. Auto-suspensión tras 7 días sin corrección
  3. Auto-revocación total tras 30 días sin corrección
  4. Notificación semanal al Admin Tenant con listado de ghost accounts
```

---

## 9. REGLAS NO NEGOCIABLES

| # | Regla | Fundamento |
|---|-------|-----------|
| R1 | Revocación de acceso completada en < 30 segundos | ISO 27001 A.9.2.5 |
| R2 | Offboarding: nunca DELETE físico — solo soft-delete + archivo | NIST AC-2(3), RGPD Art.17 |
| R3 | Revisión mensual de accesos privilegiados (SU/SYS) | ISO 27001 A.9.2.1 |
| R4 | Detección automática de privilege creep (semanal) | NIST AC-6 |
| R5 | Terminación de emergencia en < 5 minutos | ISO 27001 A.9.2.2 |
| R6 | Ghost account detection diaria | ISACA |
| R7 | Audit trail inmutable de cada revocación/suspensión/offboarding | ISO 27001 A.8.15 |
| R8 | Retención de PII post-offboarding según jurisdicción | RGPD Art.17 |
| R9 | Verificación post-revocación a los 30s — reintento hasta éxito | ISO 27001 A.9.2.5 |
| R10 | Notificación al usuario en cada cambio de estado de acceso | OWASP ASVS 2.2.3 |

---

*SKULL · SBOS · SBOS-BAUTH-ACCESS-REVOCATION-v1_0 · Junio 2026*
*Estándares: ISO 27001:2022 A.9.2 · NIST SP 800-53 AC-2/6/7 · OWASP ASVS v5.0 · ISACA COBIT 2019 · RGPD Art.17*
