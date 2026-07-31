# Anexo A.17 — Certificación FAPI 2.0
## Procedimiento de certificación Financial-grade API Profile 2.0 para SBOS

**Versión:** 1.0.0 · **Fecha:** 2026-07-31 · **Autor:** bos-developer — SBOS
**Motor:** ①④⑥ IAM Installer · Context Plane · Banco de Pruebas
**Fortalece:** 1.05 (Estándares) · 4.05 (Integración bAuth)
**Norma base:** OpenID Foundation FAPI 2.0 Security Profile · FAPI 2.0 Message Signing

---

## 1. Qué es FAPI 2.0 y por qué SBOS lo adopta

**FAPI 2.0** (Financial-grade API Profile 2.0) es el perfil de seguridad OAuth 2.1 más
exigente que existe. Fue diseñado para APIs bancarias y de pagos pero se ha convertido en
el estándar de facto para cualquier sistema de identidad que maneje datos sensibles.

**Por qué SBOS lo adopta:** el SBOS maneja datos de RRHH, ERP, correo corporativo y
escritorio de empleados. Un sistema que aspira a ser "IAM Enterprise" debe cumplir el
estándar más alto de identidad disponible.

**FAPI 2.0 vs OAuth 2.1 estándar:**

| Característica | OAuth 2.1 | FAPI 2.0 |
|----------------|-----------|----------|
| PKCE | Recomendado | OBLIGATORIO |
| PAR | Opcional | OBLIGATORIO |
| DPoP | Opcional | OBLIGATORIO |
| Algoritmos | RS256 + ES256 | Solo PS256/ES256 |
| mTLS client auth | Opcional | OBLIGATORIO |
| Response Mode | code | jwt (JARM) |

---

## 2. Requisitos de pre-configuración en Keycloak 26.6.2

Antes de ejecutar la Conformance Test Suite, el realm SBOS debe estar configurado:

### 2.1 Configuración del realm

```bash
# Via KC Admin CLI (kcadm.sh) o API REST
kcadm.sh update realms/skull \
  --set "attributes.require-pushed-authorization-requests=true" \
  --set "attributes.dpop-bound-access-tokens=true" \
  --set "defaultSignatureAlgorithm=PS256" \
  --set "accessTokenLifespan=300" \
  --set "ssoSessionIdleTimeout=43200" \
  --set "offlineSessionIdleTimeout=2592000"
```

### 2.2 Perfil de clientes FAPI 2.0

```bash
# Crear cliente de certificación
kcadm.sh create clients -r skull -f - <<EOF
{
  "clientId": "fapi2-conformance-client",
  "protocol": "openid-connect",
  "publicClient": false,
  "clientAuthenticatorType": "client-jwt",
  "attributes": {
    "token.endpoint.auth.signing.alg": "PS256",
    "request.object.signature.alg": "PS256",
    "authorization.signed.response.alg": "PS256",
    "require.pushed.authorization.requests": "true",
    "dpop.bound.access.tokens": "true",
    "tls.client.certificate.bound.access.tokens": "true"
  },
  "redirectUris": ["https://www.certification.openid.net/test/a/sbos/*"]
}
EOF
```

### 2.3 Deshabilitar algoritmos inseguros

```bash
# En KC Admin Console: Realm Settings → Tokens → Default Signature Algorithm
# → Cambiar a PS256
# → En Client Scopes: deshabilitar RS256/HS256 en profile, email, roles
```

---

## 3. Infraestructura requerida para la certificación

La Conformance Test Suite de OpenID Foundation necesita:
- **Dominio público verificable** (no localhost)
- **TLS válido** (cert de CA reconocida o Let's Encrypt)
- **JWKS accesible** desde internet

Opciones para el entorno de staging:
```
Opción A: VPS de prueba con dominio temporal
  → subdomain: fapi.staging.sbos.app (a configurar en A.03 S16-webserver)
  → cert: Let's Encrypt vía certbot
  → KC: https://fapi.staging.sbos.app/realms/skull

Opción B: ngrok temporal (solo para la prueba)
  → ngrok http 8080 --domain fapi-sbos.ngrok.io
  → No recomendado para producción, ok para certificación puntual
```

---

## 4. Procedimiento de ejecución de la Conformance Test Suite

### 4.1 Registrar perfil de prueba

1. Ir a: `https://www.certification.openid.net/`
2. Crear cuenta con email de skull.app
3. New Test Plan → **FAPI2-Security-Profile-ID1**
4. Configurar:
   - Server Issuer: `https://fapi.staging.sbos.app/realms/skull`
   - Client ID: `fapi2-conformance-client`
   - PAR endpoint: `https://fapi.staging.sbos.app/realms/skull/protocol/openid-connect/ext/par/request`
   - Token endpoint: `https://fapi.staging.sbos.app/realms/skull/protocol/openid-connect/token`
   - JWKS URI: `https://fapi.staging.sbos.app/realms/skull/protocol/openid-connect/certs`
   - Response type: `code`
   - Response mode: `jwt`

### 4.2 Plans de certificación a ejecutar

| Plan | Descripción | Tests |
|------|-------------|:-----:|
| `FAPI2-Security-Profile-ID1` | Core security profile | ~45 tests |
| `FAPI2-Security-Profile-ID2` | With PAR + DPoP | ~38 tests |
| `FAPI2-Message-Signing-ID1` | JARM (JWT Auth Response Mode) | ~22 tests |

### 4.3 Interpretar resultados

```
PASSED  → test aprobado
WARNING → implementación parcial pero funcional
FAILED  → bloqueante — debe corregirse antes de certificar
SKIPPED → no aplicable a la configuración
```

**Objetivo:** 0 FAILED en los 3 planes de certificación.

---

## 5. Fallos comunes y correcciones

| Fallo frecuente | Causa | Corrección en KC |
|----------------|-------|-----------------|
| `par_required` FAILED | PAR no obligatorio en realm | `require-pushed-authorization-requests=true` |
| `dpop_proof_invalid` FAILED | KC no valida prueba DPoP | `dpop-bound-access-tokens=true` en cliente |
| `token_algorithm_invalid` FAILED | RS256 aún activo | Deshabilitar RS256 en Client Scope |
| `redirect_uri_mismatch` FAILED | redirect_uri no exacto | Verificar lista exacta en cliente KC |
| `jarm_signature_invalid` FAILED | JARM mal configurado | `authorization.signed.response.alg=PS256` |
| `mtls_cert_required` FAILED | mTLS no configurado en token endpoint | Activar mTLS en KC realm + cert Kong→KC |

---

## 6. Integración FAPI 2.0 con el Context Plane

Una vez que KC pasa FAPI 2.0, el Context Plane integra:

### 6.1 LoA derivado del flujo FAPI 2.0

```go
// internal/context/service.go — tras device.register exitoso
// El LoA se deriva del nivel de autenticación utilizado:
func loaFromIDToken(claims map[string]interface{}) int {
    acr := claims["acr"].(string)
    switch acr {
    case "urn:mace:incommon:iap:silver":    return 2  // MFA básico
    case "urn:mace:incommon:iap:gold":      return 3  // Hardware token
    case "https://refeds.org/profile/mfa":  return 3  // REFEDS MFA
    default:                                 return 1  // Password solo
    }
}
```

### 6.2 DPoP thumbprint en ctx_id

Para sesiones LoA 3-4, el ctx_id incluye el thumbprint DPoP del token:

```json
// bos.ctx_context_session (T-396) — campos FAPI 2.0
{
  "ctx_id": "01923ac7-...",
  "loa": 3,
  "dpop_jkt": "0ZcOCORZNYy-DWpqq30jZyJGHTN0d2HglBV3uiguA4I",
  "acr": "urn:mace:incommon:iap:gold",
  "auth_time": "2026-07-31T14:00:00Z"
}
```

Kong verifica el `dpop_jkt` en cada request de sesiones LoA 3-4, garantizando que
el token no puede ser usado por un atacante aunque lo intercepte (el atacante no tiene
la clave privada correspondiente al thumbprint).

---

## 7. Documento de evidencia de certificación

Al completar la certificación (Fase VII), generar:

```
INFORME-CERTIFICACION-IAM-ENTERPRISE-v1.0.md
├── §1 — Resultado FAPI 2.0 (plan IDs + resultados + fecha)
├── §2 — Tabla ISO 27001:2022 (cada control con artefacto de evidencia)
├── §3 — Resultados k6 (P99 latencias + RPS + error rate)
├── §4 — Reporte kube-bench CIS K8s Benchmark (% controls passed)
├── §5 — Reporte gosec + govulncheck (0 HIGH CVEs)
└── §6 — Attestation SLSA L2 (cosign verify output)
```

---

*SKULL · SBOS · BosAgent · Julio 2026*
