# A.52 — Tipos y Dominios de Identidad
## Tipo B+C — Catálogo completo de tipos de entidad y dominios de capa, respaldado por SAP, Odoo e ISO 9001

**Versión:** 1.0.0
**Fecha:** 2026-07-15
**Tipo de anexo:** B (respaldo normativo/industria) + C (justificación de decisión técnica)
**Respalda a:** [1.06 D00 Identidad v2.1.0 §4, §5, §12](../1.06_MANUAL-D00-IDENTIDAD-v2.0.md) — tipos de entidad, dominios de capa, potencial del sistema
**Fuentes absorbidas:** `ANALISIS-TIPOS-DOMINIOS-IDENTIDAD-v1.0.md` · `ANALISIS-SECTORES-CICLO-VIDA-v1.0.md` · `ANALISIS-POTENCIAL-SISTEMA-IDENTIDAD-v1.0.md`
**Normas base:** ISO 9001:2015 §3.2.3-3.2.6 · ISO 24760-2:2025 · SCIM 2.0 RFC 7643
**Referencias industria:** SAP S/4HANA Business Partner · Odoo res.partner

---

## §1 Propósito

Este anexo cataloga los **37 dominios de identidad** y los **8 tipos base de entidad** del
motor de identidad de bAuth. Respalda las afirmaciones del Manual D00 v2.1.0 con investigación
de la industria (SAP, Odoo, ISO 9001).

**Cómo citarlo:** `A.52 §N`

---

## §2 Los 8 tipos base de entidad (inmutables)

| Tipo | Qué es | Ejemplos |
|---|---|---|
| **PERSONA** | Ser humano | Juan Pérez, María Gómez |
| **ORGANIZACION** | Entidad legal colectiva | SKULL SRL, DEPO SA |
| **DISPOSITIVO** | Máquina con electrónica | Servidor HP, Sensor IoT |
| **SERVICIO** | Proceso automatizado | SAP-BOT, Agente-Monitoreo |
| **VEHICULO** | Medio de transporte | Camión Volvo, Camioneta Toyota |
| **INMUEBLE** | Bien raíz | Edificio Torre, Casa-Juan |
| **PRODUCTO** | Bien de consumo/venta | Laptop Dell, Cereal Maíz |
| **ANIMAL** | Ser vivo no humano | Vaca, Perro guardián |

---

## §3 Los 37 dominios de identidad (capas que se agregan/quitan)

### PERSONA (16)

| Código | Dominio | Qué aporta |
|---|---|---|
| D00-ID01 | civil | nombre, CI, birth_date, nationality, gender, estado_civil |
| D00-ID02 | familiar | marital_status, conyuge, dependientes[] |
| D00-ID03 | educativo | matricula, carrera, titulo, institucion |
| D00-ID04 | laboral | employee_code, cargo, salary, empresa, fechas |
| D00-ID05 | autenticacion | username, MFA, account_status |
| D00-ID06 | cliente | customer_since, credit_limit, payment_method |
| D00-ID07 | proveedor | categoria, servicios[], factura_a |
| D00-ID08 | productor | tipo_producto, volumen, certificacion |
| D00-ID09 | independiente | razon_social, NIT, fecha_apertura |
| D00-ID10 | propietario | bien, escritura, valor |
| D00-ID11 | inquilino | direccion, canon, propietario |
| D00-ID12 | paciente | historia_clinica, diagnostico, medico |
| D00-ID13 | fiscal | NIT, regimen, obligaciones |
| D00-ID14 | financiero | banco, tipo_producto, saldo |
| D00-ID15 | viajero | destino, motivo, fechas |
| D00-ID16 | asegurado | aseguradora, poliza, cobertura |

### ORGANIZACION (13)

| Código | Dominio |
|---|---|
| D00-ID17 | civil (org) |
| D00-ID18 | cliente (org) |
| D00-ID19 | proveedor (org) |
| D00-ID20 | productor (org) |
| D00-ID21 | empleador |
| D00-ID22 | fiscal (org) |
| D00-ID23 | propietario (org) |
| D00-ID24 | inquilino (org) |
| D00-ID25 | importador |
| D00-ID26 | exportador |
| D00-ID27 | franquiciado |
| D00-ID28 | franquiciante |
| D00-ID29 | financiero (org) |

### COSAS (8)

| Código | Dominio |
|---|---|
| D00-ID30 | origen |
| D00-ID31 | comercial |
| D00-ID32 | propiedad |
| D00-ID33 | alquilado |
| D00-ID34 | operativo |
| D00-ID35 | asegurado |
| D00-ID36 | siniestrado |
| D00-ID37 | desactivado |

---

## §4 Respaldo de la industria

| bAuth | SAP S/4HANA | Odoo | ISO 9001 |
|---|---|---|---|
| Tipo de entidad | BP Category (Person/Org/Group) | res.partner (Individual/Company) | — |
| Dominios de capa | BP Roles (Customer, Supplier, Prospect...) | Contact Type + Tags | Customer (§3.2.4), Provider (§3.2.5) |
| Múltiples roles simultáneos | Un BP puede tener todos los roles a la vez | is_customer + is_vendor en mismo partner | Una organización puede ser ambas |

---

## §5 Mapa anexo → manuales

| Sección | Respalda a |
|---|---|
| §2 (tipos base) | 1.06 v2.1.0 §4 |
| §3 (37 dominios) | 1.06 v2.1.0 §5, §12 |
| §4 (industria) | 1.06 v2.1.0 §10 |

## §6 bi18n — variabilidad regional por dominio

Cada uno de los 37 dominios de identidad (§3) tiene reglas de validación, formato y
enmascaramiento que varían por país:

| Dominio | Qué varía por país | Dónde se define |
|---|---|---|
| `D00-ID07` (id_nacional) | Regex, máscara de entrada, máscara de presentación | `country-rules/{país}.toml` → `[national_id.CI]` |
| `D00-ID10` (teléfono) | Regex E.164, formato local, prefijos | `country-rules/{país}.toml` → `[phone]` |
| `D00-ID11` (dirección) | Formato postal, orden de nombre | `country-rules/{país}.toml` → `[postal]`, `[name]` |
| `D00-ID15` (vehículo) | Patrón de placa, formato | `country-rules/{país}.toml` → `[vehicle.plate]` |
| `D00-ID18` (bancario) | Formato de cuenta, códigos de banco | `country-rules/{país}.toml` → `[bank]` |

**bi18n** ([i18n-orchestrator](../i18n-orchestrator-rust.md)) es el servicio que el Motor de
Identidad invoca para aplicar estas reglas. Sin bi18n, cada país requeriría código hardcodeado
en bAuth. Con bi18n, agregar un país nuevo es agregar un archivo TOML — sin tocar código,
sin redeploy. La delegación del Motor de Identidad a bi18n está documentada en
[Manual 2.13 §5.4](../2.13_MANUAL-ATOMLANG-LENGUAJE-v2.0.md).

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-15 | Primera edición. Absorbe ANALISIS-TIPOS-DOMINIOS-IDENTIDAD, ANALISIS-SECTORES-CICLO-VIDA y ANALISIS-POTENCIAL-SISTEMA-IDENTIDAD. |
