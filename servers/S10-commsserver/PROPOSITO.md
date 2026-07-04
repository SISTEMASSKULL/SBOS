# S10-commsserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Comunicaciones: correo, VoIP, chat, real-time.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S10-commsserver/` se lleva entero a un VPS dedicado (`tipo=commsserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: mailserver + commsserver (BASE 8650).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| Roundcube | 80→8660 | ⬜ falta | Webmail |
| Cypht | 80→8661 | ⬜ falta | Webmail multi-cuenta |
| PostfixAdmin | 80→8670 | ⬜ falta | Admin de dominios/buzones |
| Centrifugo WS | 8000→8680 | ⬜ falta | WebSocket real-time |
| Centrifugo gRPC | 8001→8681 | ⬜ falta | gRPC API |
| Mattermost | 8065→8690 | ✅ existe | Mensajería de equipo |
| Rocket.Chat | 3000→8700 | ⬜ falta | Chat corporativo |
| FreePBX | 80→8710 | ⬜ falta | Panel VoIP |
| Postfix MTA | 25 (ext) | ⬜ falta | SMTP MTA-to-MTA |
| Dovecot | 993 (ext) | ⬜ falta | IMAP/POP3 |
| FreePBX SIP | 5060 (ext) | ⬜ falta | SIP signaling |
| SpamAssassin/Amavis/ClamAV | — | ⬜ falta | Filtro y antivirus (in-line) |

## Fichas existentes ratificadas
`Mattermost`  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
