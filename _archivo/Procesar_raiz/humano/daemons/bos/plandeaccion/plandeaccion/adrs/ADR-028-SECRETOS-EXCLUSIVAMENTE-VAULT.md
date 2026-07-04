# ADR-028 — Secretos Exclusivamente vía Vault — Nunca en Variables de Entorno

**Estado:** Aceptado  
**Fecha:** 2026-06-13  
**Origen:** §18 Regla 6 + §17.1 Reglas de Oro Go del Master v2.1  
**Relacionado:** ADR-017 (Vault 2.0.1), ADR-022, ISO 27001 A.8.12

---

## Contexto y problema

Las variables de entorno son la forma más común de filtrar secretos: aparecen en logs, en `ps aux`, en dumps de pods, en CI/CD pipelines que no sanitizan el output. Los archivos de configuración con secretos en texto claro aparecen en git history, en backups, en snapshots de disco. Ambas prácticas son incompatibles con el nivel de seguridad que SBOS requiere.

## La Decisión

**Todo secreto (contraseña, token, certificado, API key, connection string) vive en HashiCorp Vault 2.0.1 y se lee al inicio del daemon. Nunca en variables de entorno, nunca en archivos de configuración en texto claro, nunca en el código.**

```
CÓMO LEER UN SECRETO EN GO:
  ✅ Al arrancar el daemon: secretos := vault.ReadPath("secret/bos/postgresql")
  ✅ Dynamic credentials: vault.GetCredential("database/creds/bos-role")
  ✅ Certificate lease: vault.GetCertificate("pki/issue/bos-daemon")

VETADO:
  ❌ os.Getenv("DB_PASSWORD")
  ❌ cfg.DatabasePassword = "hardcoded"
  ❌ connection_string: "postgres://user:pass@localhost" en manifest.yml
  ❌ Secretos en ConfigMaps de K8s en texto claro
  ❌ Secretos en git (aunque sea en repositorio privado)
```

## Estructura de Paths en Vault por Tenant

```
secret/
  sbos/                    ← secretos del plano de control
    bos/                   ← secretos del daemon bos
    bauth/
    bkernel/
    ...
  tenants/
    {tenant_id}/           ← secretos por tenant
      postgresql/
      keycloak/
      tryton/
```

Cada tenant tiene su propio AppRole en Vault. El bos crea estos paths en el Paso 4 de la saga de ciclo de vida de tenant (ADR-010 futuro / F10.C).

## Política para Fichas

En `task_catalog.sh` de una ficha, la contraseña de la BD se obtiene:
```bash
# ✅ CORRECTO: leer de Vault
DB_PASS=$(vault kv get -field=password secret/sbos/postgresql/admin)

# ❌ VETADO: nunca así
DB_PASS="${POSTGRES_PASSWORD}"  # variable de entorno
```

## Consecuencias

**Positivas:**
- Rotación automática de credenciales vía dynamic secrets de Vault
- Ningún secreto aparece en logs ni en git history
- Cumple ISO 27001 A.8.12 (gestión de información secreta)
- `vault audit` registra cada acceso a secretos con ctx_id

**Negativas/Riesgos:**
- Vault es ahora una dependencia crítica del arranque
- Mitigación: Vault HA con Raft (3 nodos), ficha vault con 18 estados, unseal automático vía bos

## Normas relacionadas

- SBOS-050 P6 (BDs nunca externalizadas — aplica el mismo principio a secretos)
- ISO/IEC 27001:2022 A.8.12 (gestión de información secreta)
- NIST SP 800-57 (gestión del ciclo de vida de claves criptográficas)
- §17.1 Reglas de Oro Go: "Leer secretos de Vault al inicio — nunca de variables de entorno"
