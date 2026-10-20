# PROPOSITO — Stalwart Mail Server

**Ficha:** `stalwart` - **Servidor:** S10-commsserver - **Version:** 1.0
**Criticidad:** True - **Namespace:** sbos-comms - **Tipo:** StatefulSet
**Orden de instalacion:** 160

## Que es
Mail server unificado (SMTP + IMAP + POP3 + anti-spam). Reemplaza postfix/dovecot/spamassassin.

## Dependencias
nginx

## Bitacora
- Consolidada al catalogo canonico servers/ (doctrina servers/servers.yml). Manifest: manifest.yml.
- Cambios en esta ficha -> consulta al humano (recurso compartido, ORQUESTA-051).
