# S03-identityserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Identidad central (IdP) + seguridad (SIEM, service mesh).

## Criticidad
**MÁXIMA**

## Unidad de migración
Al crecer, `S03-identityserver/` se lleva entero a un VPS dedicado (`tipo=identityserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: authserver + securityserver (BASE 8200).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Keycloak HTTP | 8080→8200 | ✅ existe | IdP central — SSO de las 65+ apps |
| Keycloak HTTPS | 8443→8201 | ✅ existe | TLS |
| Keycloak Management | 9000→8202 | ✅ existe | Health/métricas (interno) |
| Linkerd | (mesh) | ✅ existe | Service mesh mTLS (4140/4143/4191/8086) |
| kyverno | — | ✅ existe | Admission policies (su daemon la reubica si procede) |
| Wazuh Manager | 1514→8210 | ⬜ falta | SIEM — ingesta de eventos |
| Wazuh Dashboard | 443→8211 | ⬜ falta | Panel SIEM |
| Wazuh API | 55000→8214 | ⬜ falta | API Wazuh |
| OpenVAS/Greenbone | 9390→8220 | ⬜ falta | Escaneo de vulnerabilidades |
| LDAP/AD Federation | (Keycloak) | ⬜ falta | Federación de identidades externas |

## Fichas existentes ratificadas
`Keycloak HTTP`, `Keycloak HTTPS`, `Keycloak Management`, `Linkerd`, `kyverno`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
