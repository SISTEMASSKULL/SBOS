# Gobernanza del Proyecto

**Generado por:** Compositor S-29 (reprocesamiento SBOS)
**Fecha:** 2026-05-18
**Proyecto:** SBOS
**Fuentes:** SBOS-010-GOVERNANCE (v6), SBOS-BAUTH-CONCEPTUALIZACION-v5_0 (bauth)
**Jerarquia aplicada:** bauth > v6 > v5 > humano

## HITL (Human in the Loop)

| Rol | Persona | Responsabilidades |
|---|---|---|
| CTO / Arquitecto Lead | Ivan Villanueva | Decisiones arquitectonicas finales, ADRs, aprobacion de cambios |
| Administrador de Dominios | Juan Perez | Operacion del sistema, diagnostico, mantenimiento |

## Normas y estandares aplicados

| Norma | Ambito | Como se aplica |
|---|---|---|
| ISO 27001:2022 | Seguridad de la informacion | A.5.3 SoD, A.8.15 audit log, A.8.24 cifrado, A.8.26 transito |
| NIST SP 800-63B-4 | Autenticacion | AAL definidos, metodos auth, passkeys, restricciones SMS/email |
| NIST SP 800-207 | Zero Trust | Linkerd mTLS, JWT por sesion, politicas dinamicas |
| NIST SP 800-53 | Controles de seguridad | AC-5 SoD, AC-6 minimo privilegio |
| FIPS 203/204/205 | Criptografia post-cuantica | ML-KEM, ML-DSA, SLH-DSA (bauth) |
| ANSI/INCITS 359-2004 | H-RBAC | Herencia jerarquica con AND NOT |
| PCI-DSS v4.0 | Pagos | SoD financiero, auditoria de pagos |
| ISO 9001:2015 | Gestion de calidad | Trazabilidad, mejora continua (fabrica ORQUESTA) |
| ISO/IEC 25010:2023 | Calidad de producto | Criterios de evaluacion |
| OWASP Top 10 LLM | Seguridad LLM | Riesgos de sistemas agentivos |

## Ciclos PDCA

| Proyecto | Frecuencia |
|---|---|
| Fabrica ORQUESTA | Sesiones del Compositor (diarias en construccion) |
| SBOS | Sprints (semanales), sesiones de construccion de nodos |

## Politica de aprobaciones

| Tipo de cambio | Quien aprueba |
|---|---|
| ADR arquitectonico | ARB (3 miembros, 5 dias) |
| Cambio de version KC | ARB + ADR formal |
| Nueva ficha en catalogo | Arquitecto Lead |
| Modificacion de doctrina fabrica | HITL (48 horas) |
| Rollback a checkpoint | HITL (1 hora) |
| Commit a main | Automatico (TBD) |

## Metricas de salud

| Metrica | Frecuencia | Umbral de alerta |
|---|---|---|
| Gasto diario LLM | Cada invocacion | 70% de DAILY_BUDGET_USD |
| Hit rate cache | Cada invocacion | < 60% |
| Tasa aprobacion PGE | Por ciclo | < 70% en ultimos 10 |
| Conexion SKDATA | Cada operacion | Timeout > 3 segundos |
| Salud nodos K8s | Cada minuto | Pods no READY |
