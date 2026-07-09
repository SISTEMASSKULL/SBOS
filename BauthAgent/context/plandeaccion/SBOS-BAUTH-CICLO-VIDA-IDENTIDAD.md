# SBOS — Motor Administrador del Ciclo de Vida de Identidad
## Investigación Profesional: JML, Recertificación, Privilege Creep, SoD Continuo
### SKULL · SBOS · Junio 2026 · v1.0

**Propósito:** Documentar estándares y arquitectura para el motor centralizado de ciclo de vida de identidad (IGA — Identity Governance & Administration) que administra Joiner-Mover-Leaver, recertificación de accesos, detección de privilege creep, cuentas huérfanas, y segregación de funciones continua.

**Código:** SBOS-BAUTH-CICLO-VIDA-IDENTIDAD-v1.0
**Complementa:** B10 (Roles), B11 (Usuarios), B17 (Delegación/SoD), B22 (Tokens), B27 (Registro), B28 (Revocación), B35 (Métodos de Autenticación)

---

## 1. ¿Qué es el Motor de Ciclo de Vida de Identidad?

Es el **motor IGA (Identity Governance & Administration)** integrado en bAuth que orquesta el ciclo de vida completo de toda entidad de identidad en el ecosistema: usuarios, roles, tokens, credenciales, sesiones, delegaciones y cuentas de servicio. Implementa el patrón **Joiner-Mover-Leaver (JML)** con recertificación periódica automatizada.

### 1.1 ¿Por qué es necesario?

| Sin IGA Centralizado | Con IGA Centralizado |
|----------------------|---------------------|
| Usuarios desactivados en RRHH pero activos en KC (37% ghost accounts según ISACA) | Detección semanal automática de cuentas huérfanas |
| Roles acumulados a lo largo de años sin revisión (privilege creep) | Recertificación trimestral: "¿este usuario aún necesita estos roles?" |
| Sin visibilidad de quién tiene acceso a qué | Dashboard: usuario → roles → átomos → última revisión |
| Offboarding manual (olvidos, retrasos) | Automático: HR webhook → revocar sesiones + desactivar + archivar PII |
| Sin registro de decisiones de acceso | Auditoría completa: quién aprobó, cuándo, por qué |
| Tokens expirados sin renovar | Inventario de tokens por usuario con alertas de expiración |

---

## 2. Arquitectura JML (Joiner-Mover-Leaver)

```
┌─────────────────────────────────────────────────────────────────┐
│              MOTOR DE CICLO DE VIDA DE IDENTIDAD                 │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    JOILER (Onboarding)                     │    │
│  │  HR trigger → verify identity → assign roles → provision  │    │
│  │  credentials → sync KC+Tryton → verify access → audit     │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    MOVER (Role Change)                     │    │
│  │  Role change trigger → SoD check → recalculate BitMask   │    │
│  │  → adjust KC+Tryton → notify user → audit                │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                    LEAVER (Offboarding)                    │    │
│  │  HR termination → revoke all sessions → revoke tokens     │    │
│  │  → deactivate KC → soft-delete Tryton → archive PII       │    │
│  │  → export audit → notify manager → audit                  │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │         RECERTIFICACIÓN PERIÓDICA (Access Review)         │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │    │
│  │  │ Privilegiado │  │ Moderado     │  │ Bajo riesgo  │   │    │
│  │  │ Trimestral   │  │ Semestral    │  │ Anual        │   │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘   │    │
│  └──────────────────────────────────────────────────────────┘    │
│                              │                                    │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │         DETECCIÓN CONTINUA (Riesgo + Anomalías)           │    │
│  │  Ghost accounts | Privilege creep | SoD violations       │    │
│  │  Unused accounts > 90d | Excessive permissions           │    │
│  └──────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Recertificación de Accesos (ISO 27001 A.9.2.5)

### 3.1 Frecuencia por Nivel de Riesgo

| Nivel de Riesgo | Roles | Frecuencia | Gatillos Adicionales |
|----------------|-------|-----------|---------------------|
| **Crítico** | SU (S001), N1 (S002-S005), D3 financiero >$10K | **Trimestral** | Cambio de rol, incidente de seguridad |
| **Alto** | N2 (S006-S015), D12-B liquidación | **Semestral** | Promoción, transferencia |
| **Medio** | N3 (S016-S019), BIZ N4-N5 | **Semestral** | Cambio de departamento |
| **Bajo** | BIZ N1-N3, EXT N0 | **Anual** | — |

### 3.2 Flujo de Recertificación

```
1. Sistema inicia campaña de recertificación automáticamente
2. Manager recibe notificación: "Revisa los accesos de tu equipo"
3. Dashboard de revisión muestra:
   - Usuario, roles asignados, átomos efectivos (herencia)
   - Último uso de cada rol (fecha)
   - Justificación original de asignación
   - Riesgo del rol
4. Manager decide: APPROVE (mantener) / REVOKE (remover) / MODIFY (ajustar)
5. Si REVOKE: sistema ejecuta revocación inmediata
6. Si no responde en 14 días: escala al superior
7. Auditoría: quién revisó, qué decidió, cuándo
```

### 3.3 Métricas de Salud IGA (ProofID 2026)

| Métrica | Objetivo |
|---------|---------|
| Tasa de certificación on-time | >95% |
| Privilege creep detectado (roles no usados >90 días) | <5% del total |
| Ghost accounts (desactivado en HR, activo en KC) | 0 |
| Decisiones automatizadas vs manuales | >60% automatizadas |
| Tiempo desde HR termination hasta revocación total | <30 minutos |

---

## 4. Detección de Privilege Creep y Cuentas Huérfanas

### 4.1 Privilege Creep

**Definición:** Acumulación gradual de permisos que un usuario ya no necesita porque cambió de rol pero conserva los accesos anteriores.

**Detección automática (semanal):**
```
SELECT user_id, role_id, COUNT(*) as days_unused
FROM bos_user_role_assignment
WHERE last_used < NOW() - INTERVAL '90 days'
  AND role_id NOT IN (SELECT role_id FROM bos_role WHERE tier = 'N0')
GROUP BY user_id, role_id;
```

**Acción:** Notificar al manager: "El usuario X tiene el rol Y sin usar hace 120 días. ¿Revocar?"

### 4.2 Cuentas Huérfanas (Ghost Accounts)

**Definición:** Usuario desactivado en el sistema de RRHH (OrangeHRM) pero aún activo en Keycloak/Tryton.

**Detección automática (diaria):**
```
1. Comparar OrangeHRM (active=false / termination_date < NOW()) vs KC (enabled=true)
2. Si ghost detectado → revocar sesiones + desactivar KC + notificar
3. Auditoría: ghost_account_detected event
```

**Estadística ISACA 2025:** 37% de organizaciones tienen ghost accounts no detectadas.

### 4.3 SoD Continuo

**Diferente de SoD estático (B1.T16) y dinámico (B17.T20):**
- **SoD estático:** al ASIGNAR roles (no pueden coexistir)
- **SoD dinámico:** al ACTIVAR roles en sesión (no pueden coexistir)
- **SoD continuo:** auditoría periódica — "¿hay usuarios que tienen ambos roles asignados pero por error de sync?"

---

## 5. Automatización de Ciclo de Vida

### 5.1 Integración con RRHH (OrangeHRM)

```
OrangeHRM webhook → bAuth
  ├── employee.hired       → trigger JOILER flow (B11.T17-T21)
  ├── employee.promoted     → trigger MOVER flow (recalculate roles)
  ├── employee.transferred  → trigger MOVER flow (change department)
  ├── employee.terminated   → trigger LEAVER flow (B11.T22-T24)
  └── employee.leave_start  → trigger SUSPEND flow (B11.T27)
```

### 5.2 Integración SCIM 2.0 (RFC 7644)

Para interoperabilidad con sistemas externos de RRHH que usen SCIM:
- `POST /Users` — crear usuario
- `PATCH /Users/{id}` — actualizar atributos
- `PUT /Users/{id}` — reemplazar
- `DELETE /Users/{id}` — desactivar (nunca eliminar)

### 5.3 Non-Human Identities (NHIs)

**71% de las credenciales de servicio no se rotan en los plazos recomendados (NHIMG 2026).**

Aplicar JML a identidades M2M:
- **Joiner:** alta de service account (S020-S048) con justificación + dueño + fecha expiración
- **Mover:** cambio de permisos requiere aprobación
- **Leaver:** desactivar service account cuando el proyecto termina
- **Recertificación:** trimestral para cuentas M2M privilegiadas

---

## 6. Integración con B10, B11, B17, B22, B27, B28, B35

| Gate | Responsabilidad | Cómo se integra con B36 |
|------|----------------|------------------------|
| **B10** | CRUD de roles | B36 orquesta el ciclo de vida: crear, modificar, deprecar, retirar |
| **B11** | CRUD de usuarios | B36 ejecuta JML: crear (joiner), modificar (mover), desactivar (leaver) |
| **B17** | Delegación, SoD, operaciones runtime | B36 detecta SoD violado en recertificación, privilege creep |
| **B22** | Tokens de autenticación | B36 gestiona ciclo de vida de tokens: emitir, rotar, revocar, expirar |
| **B27** | Registro de usuarios | B36 ejecuta onboarding completo: identidad → roles → credenciales → verificación |
| **B28** | Revocación de accesos | B36 ejecuta offboarding: revocar sesiones, tokens, desactivar, archivar |
| **B35** | Gestor de métodos de autenticación | B36 orquesta qué métodos se asignan en onboarding y se revocan en offboarding |

---

## 7. Dashboard de Gobernanza (Core UI)

### 7.1 Vistas del Administrador IGA

1. **Panel JML:** usuarios onboarded/offboarded este mes, tiempo promedio de onboarding
2. **Campañas de Recertificación:** activas, completadas, pendientes, overdue
3. **Privilege Creep:** roles no usados >90 días, usuarios con más roles que el promedio
4. **Ghost Accounts:** detectadas esta semana, resueltas, pendientes
5. **SoD Violations:** detectadas en última recertificación, corregidas, pendientes
6. **Non-Human Identities:** service accounts próximas a expirar, sin dueño, sin uso

---

## 8. Referencias

- [ISO 27001:2022 A.9.2.5 — Review of User Access Rights](https://www.iso.org/standard/27001)
- [NIST SP 800-53 AC-2 — Account Management](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final)
- [IDPro Body of Knowledge — Optimizing Access Recertifications (2025)](https://bok.idpro.org/article/119/)
- [Gartner — Innovation Insight: Light IGA (Jan 2025)](https://www.gartner.com/en/documents/innovation-insight-light-iga)
- [Veza — What is Light IGA? (2025)](https://veza.com/blog/light-iga/)
- [NHIMG — Non-Human Identity Governance (May 2026)](https://nhimg.org/)
- [ProofID — 7 Signs Your IGA Programme Matters (2026)](https://proofid.com/resources/blog/understanding-the-value-of-your-iga-programme-7-signs-that-matter)
- [Netwrix — Complete Buyer's Guide to IGA Solutions (2026)](https://netwrix.com/en/resources/blog/top-4-iga-tools/)
- [SCIM 2.0 RFC 7644](https://datatracker.ietf.org/doc/html/rfc7644)
- [ISACA — Ghost Accounts Statistics (2025)](https://www.isaca.org/)

---

*SKULL · SBOS · SBOS-BAUTH-CICLO-VIDA-IDENTIDAD-v1.0 · Junio 2026*
*Confidencial — Propiedad de SKULL Desarrollo de Software*
