# Anexo A.07 — Vault PKI, AppRole y Gestión de Secretos en SBOS
## Cómo el BOS configura Vault para que cada ficha obtenga sus secretos sin hardcodeos

**Versión:** 1.0.0 · **Fecha:** 2026-07-17 · **Autor:** bos-developer — SBOS
**Fortalece al motor:** ① IAM Installer
**Referencia:** [1.01 — IAM Installer](../1.01_MANUAL-IAM-INSTALLER.md) §10.4

---

## 1. Arquitectura PKI — CA intermedia

En producción, Vault actúa como **CA intermedia**, no raíz. La CA raíz permanece offline
(air-gapped). Si Vault es comprometido, solo se revoca la intermedia.

```
CA Raíz (offline, air-gapped)
  └── CA Intermedia (Vault PKI)
       ├── certs para :9443 (BOS Context API)
       ├── certs para *.sbos.app (nginx S16)
       ├── certs para mTLS entre daemons
       └── certs para bhnexus WebSocket :9444
```

---

## 2. AppRole por ficha

Cada ficha recibe un AppRole con políticas de acceso mínimo:

```hcl
# Política Vault para postgresql
path "secret/tenants/{{identity.entity.aliases.approle.metadata.tenant}}/postgresql/*" {
  capabilities = ["read"]
}
```

- `role_id`: no es secreto, puede ir en el manifest.yml
- `secret_id`: entregado vía wrapping token de un solo uso (TTL corto)
- TTL del AppRole: 24h, renovable

---

## 3. Flujo de obtención de secretos

```
1. BOS instala ficha postgresql
2. BOS crea AppRole en Vault: vault write auth/approle/role/postgresql
3. BOS entrega wrapping token a la ficha (único uso)
4. Ficha desenvuelve el token → obtiene secret_id
5. Ficha autentica con role_id + secret_id → obtiene token Vault
6. Ficha lee sus secretos: vault read secret/tenants/skull/postgresql/creds
7. Token Vault expira en 24h → ficha re-autentica con nuevo secret_id
```

---

## 4. Modo bootstrap (Pasada 1 — sin Vault)

En la primera pasada (ADR-040), Vault aún no existe. Las credenciales son bootstrap (temporales).
La segunda pasada las migra a Vault vía `ficha_repair()`.

---

## 5. Referencias

- [Vault vs Sealed Secrets 2026](https://lucaberton.com/blog/vault-vs-sealed-secrets-2026/)
- [HashiCorp Vault Deep Dive](https://pub.towardsai.net/hashicorp-vault-deep-dive-28f2fa00a610)
- [GitOps Secret Management with Vault + ESO + ArgoCD](https://www.deviqon.com/blog/post/gitops-secret-management-vault-eso-argocd)
- [ADR-040 — Mínimo Viable Progresivo](../../../context/BOS_V8/ADR-040-MINIMO-VIABLE-PROGRESIVO.md)

---

*SKULL · SBOS · BosAgent · Julio 2026*
