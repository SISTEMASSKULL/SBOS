# S05-devserver — PROPÓSITO

> Bitácora del servidor lógico. Norma: `servers/servers.yml`.
> Apps: `IAM_Enterprise_Stack_v5`. Puertos: `BOS_V8_SBOS-050-PORT-CATALOG` §12.

## Qué es
Apps propias SKULL (Smart*) + IAM Style + CMS.

## Criticidad
**ALTA**

## Unidad de migración
Al crecer, `S05-devserver/` se lleva entero a un VPS dedicado (`tipo=devserver`).

## Aplicaciones
Adecuación de v5 a este servidor. Absorbe: SmartApps SKULL — containerPort 281xx (BASE 8300).
Puerto = `containerPort → ClusterIP SBOS` (SBOS-050 §12.3). Nunca externos salvo NGINX/correo/SIP.

| App | Puerto (cont→ClusterIP) | Estado | Propósito |
|-----|:----------------------:|:------:|-----------|
| SmartTax | 28100→8300 | ⬜ falta | Facturación fiscal Bolivia |
| SmartReport | 28110→8310 | ⬜ falta | Reportes |
| SmartRates | 28120→8320 | ⬜ falta | Tarifas |
| SmartORC | 28130→8330 | ⬜ falta | Correspondencia |
| SmartVaultFlow | 28140→8340 | ⬜ falta | Flujo documental |
| SmartPortfolio | 28150→8350 | ⬜ falta | Catálogos |
| SmartPay | 28160→8360 | ⬜ falta | Pagos QR |
| SBOS IAM Style | 28170→8370 | ⬜ falta | Identidad visual |
| SBOS CMS | 28180→8380 | ⬜ falta | Gestor de contenidos |

## Fichas existentes ratificadas
_(ninguna todavía)_  
(se ratifican en su sitio, **sin cambiar de servidor**).

## Pendiente
Las fichas ⬜ las completa su daemon responsable bajo `servers.yml` (manifest + task_catalog + resources + PROPOSITO propio). El Bibliotecario solo garantiza la norma.
