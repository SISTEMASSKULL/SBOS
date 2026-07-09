# ADR-008 — Simbiosis Trilateral bAuth-KC-Tryton: bauth_db como Única Fuente de Verdad

**Estado:** Aceptado · **Fecha:** 2026-06-20

---

## Contexto

En un sistema con tres componentes que gestionan identidad (bAuth, Keycloak, Tryton), debe existir UNA sola fuente de verdad. Si Keycloak y Tryton pueden modificar la identidad independientemente, se produce drift y corrupción de datos. La pregunta es: ¿quién es el dueño de la identidad?

## Decisión

**bauth_db (PostgreSQL) es la ÚNICA fuente de verdad. Keycloak y Tryton son réplicas operacionales que reflejan el estado definido en bauth_db.**

- bAuth declara el estado deseado (RolTemplate, UserTemplate)
- Sync Engine calcula el diff entre estado deseado (bauth_db) y real (KC, Tryton)
- Reconcile loop cada 60 segundos detecta y corrige drift automáticamente
- Si KC o Tryton son destruidos, bAuth los reconstruye desde cero (bootstrap simbiótico)
- Idempotencia absoluta: ejecutar sync 1 o 1000 veces produce el mismo resultado

## Alternativas

| Alternativa | Problema |
|------------|---------|
| Keycloak como fuente de verdad | KC no almacena estructura organizacional (departamentos, sucursales, zonas). Tryton quedaría incompleto. |
| Tryton como fuente de verdad | Tryton no maneja authentication flows, MFA, WebAuthn. KC quedaría incompleto. |
| Sincronización bidireccional sin dueño claro | Conflictos de merge. ¿Quién gana si KC y Tryton tienen valores diferentes para el mismo usuario? |

## Consecuencias

- Reconcile loop 60s: GET /roles + /users en KC, search_read en Tryton → comparar con bauth_db → corregir
- Degradación graciosa: KC caído → cache Redis responde. Tryton caído → sync encolado. Ambos caídos → identidad congelada (read-only). bauth_db caído → CRÍTICO.
- Bootstrap desde cero: con bauth_db intacto, bAuth reconstruye todo KC + Tryton sin intervención humana

## Referencias
- BAUTH-CONTRATO-SYMBIOSIS.md v1.0
- BAUTH-ARQUITECTURA-FRAMEWORK.md v1.0
