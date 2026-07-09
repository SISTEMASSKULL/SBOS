# Reporte bAuth → Bibliotecario
## Fecha: 2026-07-07 00:10 UTC
## Asunto: Biblioteca de políticas cfg_policy_library — ciclo completo cerrado

### Qué se hizo en esta sesión

**Problema raíz resuelto (sesión anterior):**
- FASE 5.1 de `bauth_20__framework_politicas.sql` usaba nombres snake_case
  (`'authentication_framework'`, `'policies_framework'`) en lugar de camelCase reales
  (`'authenticationFramework'`, `'policiesAuthenticationFramework'`).
  Resultado: 8,024 de 9,142 registros quedaban con `domain_map = {SEC}`.
- Bug secundario: el JSON de ambos frameworks tiene wrapping extra — las secciones reales
  están en depth=2, no depth=1. FASE 5.1 clasificaba depth=1 (el wrapper) y propagaba
  dominio incorrecto a todos los hijos.

**Correcciones aplicadas:**
- `bauth_20__framework_politicas.sql` — FASE 2 idempotente, FASE 3 ON CONFLICT, FASE 5.1
  con nombres corregidos, FASE 5.1b nueva para depth=2, FASE 5.2 corregida.
- D5 biométrico limpiado (tenía contenido FIDO2/NIST incorrecto) y repoblado con
  ISO/IEC 30107-3, ISO/IEC 29794-1, NIST SP 800-76-2 (9 configs + 10 políticas).

**Seeds incrementales (42 políticas nuevas en dominios escasos):**
- bauth_71: D3 Financiero (Bolivia SIN, PCI DSS 4.0, ISO 20022, SWIFT CSP, SOX, Basel III)
- bauth_72: D4 Temporal (RFC 6238/4226, JWT, PAM JIT, break-glass, NIST SP 800-57)
- bauth_73: D6 Geoespacial (Bolivia Ley 164, GDPR Cap.V, NIS2, FATF, impossible travel)
- bauth_74: D10 Delegación (RFC 8693 ABAC, SoD, OAuth2 Token Exchange, COBIT 2019)
- bauth_75: D12 Blockchain (Besu 24.x, EIP-712, EIP-4361 SIWE, OWASP SC Top 10:2023)

**Seed master canónico:**
- `bauth_76__cfg_policy_library_master.sql` — 9,184 registros, 11MB
- TRUNCATE CASCADE + COPY FROM stdin + setval(18326)
- Validado en VPS: COPY 9184, 0 errores, 0 NULL domain_map
- Reemplaza: framework_raw + bauth_fw_01-16 + bauth_20 CTE pipeline

### Estado final verificado en VPS (2026-07-07)
```
cfg_policy_library: 9,184 registros | 21 fuentes | 0 sin dominio | 9,184 activos
ath_policy_dN: D1=48 D2=94 D3=24 D4=20 D5=16 D6=16 D7=302 D8=52 D9=95 D10=18 D11=168 D12=31
```

### Evidencia AA-1
```
Timestamp:    2026-07-07T00:08:17Z
SHA256(cmd):  af6a4d0a08f746573aa502677e0ca291ea19f3d75c10134bf907eb2884e613be
SHA256(out):  03e03a89a9e8c6eb47f765deb6b1e1dbd0f47ea8eb6f80af5fb59655c7f2e42d
```

### Commit
`df7a8ce` en `main` — 7 archivos, +9,958 líneas, -30 líneas

### Solicitudes al Bibliotecario
1. **Revisión de código** (Revisor): verificar bauth_20__ corregido + seeds 71-76
2. **Registro en SKDATA** (Planificador): estado final de cfg_policy_library con conteos
3. **Pendiente HITL** (sin tocar en esta sesión):
   - T1.1/T1.2: CHECK constraint + D0 en privilege_domain
   - T1.3: idn_atributo columnas canónicas
   - T1.4: Decisión numeración D4/D5
   - T2.1-T2.3: ALTER tables + seeds correspondientes
