# BAUTH — Reporte de Roles por Dominio Funcional
**Fecha:** 2026-07-09 · **Actualizado:** 2026-07-09 · **Fuente:** `bauth.idn_role_template` (VPS 13.140.128.230)
**Total roles:** 548 (+181 añadidos 2026-07-09) · **Total dominios:** 20 · **Columna:** `domains JSONB`

> **AA-1 EVIDENCIA:** `SELECT COUNT(*) FROM bauth.idn_role_template` → **548** | Timestamp: 2026-07-09T04:00:00Z
> Inserción 1 (2026-07-09T02:50): +111 roles (D2 D3 D5 D6 D7 D10 D12) → total 478
> Inserción 2 (2026-07-09T04:00): +70 roles (D2 D3 D7 ampliación) → total **548**

---

## Taxonomía de Dominios (D01–D20)

| Código | Nombre | Aplica a |
|--------|--------|----------|
| **D01** | Sistema & Plataforma | SU, M2M, Módulos técnicos SBOS |
| **D02** | Alta Gerencia & Dirección | CEO, Presidentes, Directores, Gerentes Generales |
| **D03** | Finanzas & Contabilidad | Contabilidad, Tesorería, Planificación Financiera |
| **D04** | Tributación & Facturación | SIN, Impuestos, Facturación electrónica, Cobranza |
| **D05** | Banca & Servicios Financieros | Banca, Seguros, AFP, Valores, ASFI |
| **D06** | Recursos Humanos | Contratación, Nómina, Relaciones Laborales |
| **D07** | Comercial & Ventas | Ventas, Marketing, CRM, Comercio, Exportaciones |
| **D08** | Operaciones & Manufactura | Producción, Manufactura, Control de calidad |
| **D09** | Logística & Cadena de Suministro | Almacén, Inventarios, Transporte, Compras |
| **D10** | Tecnología & Ciberseguridad | TI, Sistemas, Soporte, Infraestructura, Seguridad |
| **D11** | Legal, Auditoría & Compliance | Legal, Auditoría, Riesgo, Compliance, Notaría |
| **D12** | Salud & Asistencia Social | Médico, Clínico, Farmacéutico, Laboratorio |
| **D13** | Educación & Formación | Docencia, Academia, Investigación, Formación |
| **D14** | Agro & Medio Ambiente | Agricultura, Ganadería, Pesca, Forestal, Agua |
| **D15** | Construcción & Inmobiliaria | Inmobiliaria, Arquitectura, Ingeniería Civil |
| **D16** | Minería & Energía | Minería, Hidrocarburos, Electricidad, Gas |
| **D17** | Hotelería, Turismo & Arte | Hospedaje, Restaurantes, Turismo, Entretenimiento |
| **D18** | Sector Público & Gobierno | Gobierno, Administración Pública, Defensa |
| **D19** | Externo & Visitantes | Proveedores, Contratistas, Visitantes, Internacional |
| **D20** | Hogar & Familia | Hogar, Familia, Doméstico, Acompañante |

> **Nota:** El campo `domains` es `JSONB`. Un rol puede pertenecer a **1 o más dominios**.
> Índice GIN activo: `idx_idn_role_template_domains` (búsqueda eficiente).
> Ejemplo: `WHERE domains @> '["D03"]'` retorna todos los roles de Finanzas.

---

## Distribución de Roles por Dominio

> Fuente real: `SELECT domain_code, COUNT(*) FROM bauth.idn_role_template CROSS JOIN LATERAL jsonb_array_elements_text(domains) AS domain_code GROUP BY domain_code`.
> Ejecutado 2026-07-09T02:50:00Z · 478 roles · Total de asignaciones ≈ 630.

| Código | Dominio | Roles (v2) | Δ vs v1 | Barra (v2) |
|--------|---------|----------:|:-------:|------------|
| D10 | Tecnología & Ciberseguridad | **122** | +61 | ████████████████████████████████████████████████████████████ |
| D11 | Legal, Auditoría & Compliance | **61** | +35 | ██████████████████████████████ |
| D01 | Sistema & Plataforma | **55** | +15 | ███████████████████████████ |
| D07 | Comercial & Ventas | **50** | +3 | █████████████████████████ |
| D03 | Finanzas & Contabilidad | **42** | +22 | █████████████████████ |
| D09 | Logística & Cadena de Suministro | **40** | +9 | ████████████████████ |
| D05 | Banca & Servicios Financieros | **36** | +20 | ██████████████████ |
| D02 | Alta Gerencia & Dirección | **33** | +14 | ████████████████ |
| D04 | Tributación & Facturación | **29** | +1 | ██████████████ |
| D08 | Operaciones & Manufactura | **26** | +4 | █████████████ |
| D12 | Salud & Asistencia Social | **22** | +4 | ███████████ |
| D15 | Construcción & Inmobiliaria | **22** | +2 | ███████████ |
| D19 | Externo & Visitantes | **20** | +3 | ██████████ |
| D18 | Sector Público & Gobierno | **16** | +10 | ████████ |
| D13 | Educación & Formación | **15** | 0 | ███████ |
| D14 | Agro & Medio Ambiente | **17** | +1 | ████████ |
| D16 | Minería & Energía | **11** | +1 | █████ |
| D17 | Hotelería, Turismo & Arte | **21** | 0 | ██████████ |
| D06 | Recursos Humanos | **7** | +4 | ███ |
| D20 | Hogar & Familia | **5** | 0 | ██ |

**D10 escala a 122** por los 20 nuevos roles SOC/NOC/firewall/VPN/IoT/DNS + D11 sube por roles de auditoría y compliance.
**D18 salta de 6 a 16** por los nuevos roles de inspectores externos, control migratorio y bomberos.
**D06 RRHH sube de 3 a 7** por los roles de control de asistencia biométrica y supervisión de personal.

---

## Estadística Multi-Dominio

| Categoría | v1 (367 roles) | v2 (478 roles) |
|-----------|:-----:|:-----:|
| Roles con **1 dominio** | 291 (79%) | ~380 (79%) |
| Roles con **2 dominios** | 74 (20%) | ~93 (19%) |
| Roles con **3 dominios** | 2 (1%) | ~5 (1%) |
| **Total roles** | **367** | **478** |
| Total asignaciones (suma) | **461** | ~630 |

---

## Roles Multi-Dominio (selección)

| ID del Rol | Nombre | Dominios |
|-----------|--------|----------|
| ROL-SYS-SUPERUSUARIO | Superusuario SBOS | `D01` `D02` `D10` |
| ROL-EXT-TECNICO-INSTALADOR | Técnico Instalador | `D19` `D15` `D10` |
| ROL-DIRECTOR-COLEGIO | Director de Escuela / Colegio | `D02` `D13` |
| ROL-GERENTE-BANCO | Gerente de Sucursal Bancaria | `D02` `D05` |
| ROL-GERENTE-HOTEL | Gerente de Hotel | `D02` `D17` |
| ROL-SYS-ADMIN-BAUTH | Administrador de bAuth | `D01` `D10` |
| ROL-SYS-ADMIN-BOS | Administrador de BOS | `D01` `D10` |
| ROL-SYS-ADMIN-KONG | Administrador de Kong (API Gateway) | `D01` `D10` |
| ROL-SYS-ADMIN-VAULT | Administrador de Vault (Secretos) | `D01` `D10` |
| ROL-JEFE-CONTABILIDAD | Jefe de Contabilidad | `D03` `D04` |
| ROL-JEFE-FACTURACION-CREDITO | Jefe de Facturación y Crédito | `D04` `D03` |
| ROL-JEFE-INVENTARIOS | Jefe de Inventarios | `D08` `D09` |
| ROL-JEFE-LOGISTICA | Jefe de Logística | `D09` `D08` |
| ROL-JEFE-PRODUCCION | Jefe de Producción | `D08` `D09` |
| ROL-JEFE-RRHH | Jefe de Recursos Humanos | `D06` `D11` |
| ROL-JEFE-SEGURIDAD | Jefe de Seguridad | `D10` `D11` |
| ROL-TESORERO | Tesorero | `D03` `D05` |
| ROL-ADMIN-CLINICA | Administrador de Clínica | `D02` `D12` |
| ROL-AUDITOR-INTERNO | Auditor Interno | `D11` `D03` |
| ROL-CONTADOR | Contador / Contable | `D03` `D04` |
| ROL-CONTADOR-IMPOSITIVO | Contador Impositivo | `D03` `D04` |
| ROL-SUPERVISOR-BANCO | Supervisor de Sucursal Bancaria | `D05` `D11` |
| ROL-SUPERVISOR-SEGURIDAD | Supervisor de Seguridad | `D10` `D11` |
| ROL-PORTERO | Portero / Guardia de Seguridad | `D10` `D11` |
| ROL-OPERADOR-CCTV | Operador de CCTV | `D10` `D11` |
| ROL-SERENO | Sereno / Vigilante Nocturno | `D10` `D11` |
| ROL-FLOOR-WALKER | Supervisor de Piso / Floor Walker | `D07` `D11` |
| ROL-EXT-TECNICO-SERVICIO | Técnico de Servicio / Contratista | `D19` `D15` |
| ROL-EXT-CONTRATISTA-OBRA | Contratista de Obra Menor | `D19` `D15` |
| ROL-EXT-FAMILIAR-PACIENTE | Familiar / Acompañante de Paciente | `D20` `D12` |
| ROL-EXT-CLIENTE-FUNERARIA | Cliente de Servicios Funerarios | `D20` `D19` |
| ROL-EXT-TUTOR-EDUCATIVO | Padre / Madre / Tutor Legal | `D13` `D20` |
| ROL-EXT-VISITANTE-AUDITOR | Visitante Auditor / Inspector | `D19` `D11` |
| ROL-EXT-VISITANTE-PROVEEDOR | Visitante Proveedor | `D19` `D09` |

---

## Ejemplos de Roles por Dominio

### D01 — Sistema & Plataforma (40 roles)
| ID | Nombre |
|----|--------|
| ROL-SYS-ADMIN-BAUTH | Administrador de bAuth (Identidad) |
| ROL-SYS-ADMIN-BOS | Administrador de BOS (IAM Installer) |
| ROL-SYS-ADMIN-BKERNEL | Administrador de bKernel (Datos) |
| ROL-SYS-ADMIN-BIEDATA | Administrador de biedata (Integración) |

### D02 — Alta Gerencia & Dirección (19 roles)
| ID | Nombre |
|----|--------|
| ROL-GERENTE-GENERAL | Gerente General / Director |
| ROL-SYS-ADMIN-INFRA | Administrador de Infraestructura SBOS |
| ROL-GERENTE-BANCO | Gerente de Sucursal Bancaria |
| ROL-DIRECTOR-COLEGIO | Director de Escuela / Colegio |

### D03 — Finanzas & Contabilidad (20 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-CONTABILIDAD | Jefe de Contabilidad |
| ROL-JEFE-FACTURACION-CREDITO | Jefe de Facturación y Crédito |
| ROL-TESORERO | Tesorero |
| ROL-ANALISTA-CONTROL-INTERNO | Analista de Control Interno |

### D04 — Tributación & Facturación (28 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-CONTABILIDAD | Jefe de Contabilidad |
| ROL-ANALISTA-CREDITO-COBRANZA | Analista de Crédito y Cobranza |
| ROL-CONCILIADOR-FACTURACION | Conciliador de Facturación |
| ROL-CONTADOR-IMPOSITIVO | Contador Impositivo |

### D05 — Banca & Servicios Financieros (16 roles)
| ID | Nombre |
|----|--------|
| ROL-GERENTE-BANCO | Gerente de Sucursal Bancaria |
| ROL-TESORERO | Tesorero |
| ROL-ANALISTA-RIESGOS | Analista de Riesgos |
| ROL-OFICIAL-CUMPLIMIENTO | Oficial de Cumplimiento |

### D06 — Recursos Humanos (3 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-RRHH | Jefe de Recursos Humanos |
| ROL-ANALISTA-RRHH | Analista de RRHH |
| ROL-ENCARGADO-NOMINA | Encargado de Nómina / Sueldos |

### D07 — Comercial & Ventas (47 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-LOCAL | Jefe de Local |
| ROL-COMPRADOR | Comprador / Jefe de Compras |
| ROL-ENCARGADO-CAJA | Encargado de Caja Central |
| ROL-ENCARGADO-INVENTARIO | Encargado de Inventario |

### D08 — Operaciones & Manufactura (22 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-INVENTARIOS | Jefe de Inventarios |
| ROL-JEFE-LOGISTICA | Jefe de Logística |
| ROL-JEFE-PRODUCCION | Jefe de Producción |
| ROL-CONTROL-CALIDAD | Control de Calidad |

### D09 — Logística & Cadena de Suministro (31 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-INVENTARIOS | Jefe de Inventarios |
| ROL-JEFE-LOGISTICA | Jefe de Logística |
| ROL-JEFE-PRODUCCION | Jefe de Producción |
| ROL-ANALISTA-MERMAS | Analista de Control de Mermas |

### D10 — Tecnología & Ciberseguridad (61 roles)
| ID | Nombre |
|----|--------|
| ROL-SYS-ADMIN-BAUTH | Administrador de bAuth (Identidad) |
| ROL-SYS-ADMIN-BOS | Administrador de BOS (IAM Installer) |
| ROL-JEFE-SEGURIDAD | Jefe de Seguridad |
| ROL-SUPERVISOR-SEGURIDAD | Supervisor de Seguridad |

### D11 — Legal, Auditoría & Compliance (26 roles)
| ID | Nombre |
|----|--------|
| ROL-JEFE-RRHH | Jefe de Recursos Humanos |
| ROL-AUDITOR-INTERNO | Auditor Interno |
| ROL-JEFE-SEGURIDAD | Jefe de Seguridad |
| ROL-FLOOR-WALKER | Supervisor de Piso / Floor Walker |

### D12 — Salud & Asistencia Social (18 roles)
| ID | Nombre |
|----|--------|
| ROL-ADMIN-CLINICA | Administrador de Clínica |
| ROL-ENFERMERO | Enfermero/a |
| ROL-JEFE-FARMACIA | Jefe de Farmacia |
| ROL-MEDICO-GENERAL | Médico General |

### D13 — Educación & Formación (15 roles)
| ID | Nombre |
|----|--------|
| ROL-DIRECTOR-COLEGIO | Director de Escuela / Colegio |
| ROL-DOCENTE | Docente / Profesor |
| ROL-AUXILIAR-DOCENTE | Auxiliar Docente |
| ROL-BIBLIOTECARIO | Bibliotecario |

### D14 — Agro & Medio Ambiente (16 roles)
| ID | Nombre |
|----|--------|
| ROL-ADMIN-ESTANCIA | Administrador de Estancia / Hacienda |
| ROL-CAPATAZ | Capataz / Encargado de Campo |
| ROL-VETERINARIO | Veterinario de Campo |
| ROL-ENCARGADO-RIEGO | Encargado de Riego |

### D15 — Construcción & Inmobiliaria (20 roles)
| ID | Nombre |
|----|--------|
| ROL-ELECTRICISTA | Electricista |
| ROL-INGENIERO-CIVIL | Ingeniero Civil / Arquitecto |
| ROL-MAESTRO-OBRA | Maestro de Obra |
| ROL-PLOMERO | Plomero / Gasista |

### D16 — Minería & Energía (10 roles)
| ID | Nombre |
|----|--------|
| ROL-EXT-COMPRADOR-MINERO | Comprador de Minerales / Commodities |
| ROL-EXT-COMPRADOR-ORO | Comprador de Oro / Joyería |
| ROL-EXT-COMUNIDAD-MINERA | Comunidad / Junta Vecinal Minera |
| ROL-EXT-CONTRATISTA-MINERO | Contratista Minero |

### D17 — Hotelería, Turismo & Arte (21 roles)
| ID | Nombre |
|----|--------|
| ROL-GERENTE-HOTEL | Gerente de Hotel |
| ROL-CHEF | Chef / Jefe de Cocina |
| ROL-BARTENDER | Bartender / Barman |
| ROL-RECEPCIONISTA | Recepcionista |

### D18 — Sector Público & Gobierno (6 roles)
| ID | Nombre |
|----|--------|
| ROL-EXT-ADMINISTRADO | Administrado / Solicitante de Trámite |
| ROL-EXT-BENEFICIARIO-SOCIAL | Beneficiario de Programa Social |
| ROL-EXT-CIUDADANO | Ciudadano / Contribuyente |
| ROL-EXT-CONSCRIPTO | Recluta / Conscripto |

### D19 — Externo & Visitantes (17 roles)
| ID | Nombre |
|----|--------|
| ROL-EXT-AFILIADO-SINDICAL | Afiliado Sindical / Gremial |
| ROL-EXT-TECNICO-SERVICIO | Técnico de Servicio / Contratista |
| ROL-EXT-VISITANTE | Visitante General |
| ROL-EXT-VISITANTE-AUDITOR | Visitante Auditor / Inspector |

### D20 — Hogar & Familia (5 roles)
| ID | Nombre |
|----|--------|
| ROL-EXT-CLIENTE-FUNERARIA | Cliente de Servicios Funerarios |
| ROL-EXT-EMPLEADOR-DOMESTICO | Empleador Doméstico |
| ROL-EXT-FAMILIAR-PACIENTE | Familiar / Acompañante de Paciente |
| ROL-EXT-TRABAJADOR-HOGAR | Trabajador del Hogar |

---

## Referencia Técnica

### Consultas útiles

```sql
-- Todos los roles de un dominio
SELECT id, role_name, tier, domains
FROM bauth.idn_role_template
WHERE domains @> '["D03"]'
ORDER BY tier, id;

-- Roles que pertenecen a D03 Y D04 al mismo tiempo
SELECT id, role_name, domains
FROM bauth.idn_role_template
WHERE domains @> '["D03","D04"]';

-- Reporte: total roles por dominio
SELECT domain_code, COUNT(*) AS n
FROM bauth.idn_role_template
  CROSS JOIN LATERAL jsonb_array_elements_text(domains) AS domain_code
GROUP BY domain_code ORDER BY n DESC;

-- Roles multi-dominio
SELECT id, role_name, jsonb_array_length(domains) AS n_dominios, domains
FROM bauth.idn_role_template
WHERE jsonb_array_length(domains) > 1
ORDER BY n_dominios DESC, id;
```

### Extensión del catálogo de dominios

El campo `domains` es JSONB extensible. Para agregar un dominio nuevo (ej. geolocalización):

```sql
-- No requiere ALTER TABLE — solo agregar el código nuevo en los roles
UPDATE bauth.idn_role_template
SET domains = domains || '["D21"]'
WHERE id = 'ROL-DISPOSITIVO-GPS';

-- Actualizar el COMMENT de la columna para documentar el nuevo dominio
COMMENT ON COLUMN bauth.idn_role_template.domains IS '... D21=Geolocalización & IoT ...';
```

---

---

## Dominios Arquitecturales bAuth (D00–D13)

> Estos son los **planos de control** de la arquitectura de bAuth — distintos de los dominios
> funcionales D01–D20 de la columna `domains`. Cada plano define QUÉ tipo de control aplica
> al rol: lógico, físico, financiero, temporal, etc.
> Fuente: `BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md` · `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md`

### Tabla maestra: 14 planos de control

| Código | Nombre | Estándar principal | Estado |
|--------|--------|--------------------|--------|
| **D00** | Identidad Organizacional | ISO 24760-2:2025 | 🟡 PARCIAL |
| **D1** | Acceso Lógico | NIST 800-63B-4, RFC 9470, CAEP | 🔴 INCOMPLETO |
| **D2** | Acceso Físico | IEC 60839-11-5, OSDP v2.2.2, NIST SP 800-116 | 🔴 INCOMPLETO |
| **D3** | Financiero | PCI DSS 4.0.1, SOX §404, COSO, ISO 20022 | 🔴 INCOMPLETO |
| **D4** | Temporal | GTRBAC, RFC 5545, ISO 8601 | 🟡 PARCIAL |
| **D5** | Biométrico | ISO/IEC 30107-3, NIST SP 800-63B-4 §5.2.3 | 🟡 PARCIAL |
| **D6** | Geoespacial | OGC GeoFence, BeyondCorp | 🟡 PARCIAL |
| **D7** | Red / Network | NIST SP 800-207 ZTA, IEEE 802.1X, CAEP | 🔴 INCOMPLETO |
| **D8** | Contexto / Sesión | SBOS-049, W3C Trace Context, CAEP | 🟡 PARCIAL |
| **D9** | Credenciales | NIST 800-63B-4 AAL1-3, FIDO2 L2, WebAuthn | 🔴 INCOMPLETO |
| **D10** | Delegación | ANSI/INCITS 359-2004 DSD, NIST AC-5 | 🟡 PARCIAL |
| **D11** | Auditoría | ISO 27001 A.8.15, PCI DSS 10.3.2, NIST AU-2/3 | 🟡 PARCIAL |
| **D12** | Blockchain / Anclaje | NIST IR 8202, EIP-725/735, W3C DID Core | 🔴 INCOMPLETO |
| **D13** | Firma Digital Externa | Ley 164 Bolivia, ADSIB-FD-POLT-015 v2.3 | ✅ DISEÑADO |

---

### Roles por plano de control

#### D00 — Identidad Organizacional (478 roles — UNIVERSAL)
Todos los roles requieren contexto organizacional. D00 provee el árbol: `tenant → bdomain → bsubdomain → pos_logico`.

| Tier | v1 | v2 |
|------|---:|---:|
| SU | 1 | 1 |
| M2M | 29 | 29 |
| BIZ_N1–N5 | 191 | 289 |
| EXT_N0 | 142 | 155 |
| VISITANTE | 4 | 4 |
| **TOTAL** | **367** | **478** |

---

#### D1 — Acceso Lógico (221 roles — SU + M2M + BIZ)
Controla autenticación digital: sesiones, tokens, step-up (RFC 9470), métodos MFA.

| Tier | n | LOA | MFA | Ejemplos |
|------|--:|:---:|:---:|---------|
| SU | 1 | 3 | ✅ | ROL-SYS-SUPERUSUARIO |
| M2M | 29 | 2 | ✅ | ROL-M2M-BOS-CORE, ROL-M2M-BAUTH-READ |
| BIZ_N1 | 5 | 3 | ✅ | ROL-GERENTE-GENERAL, ROL-SYS-ADMIN-INFRA |
| BIZ_N2 | 13 | 2 | ✅ | ROL-SYS-ADMIN-BAUTH, ROL-GERENTE-BANCO |
| BIZ_N3 | 18 | 2 | ✅ | ROL-JEFE-CONTABILIDAD, ROL-JEFE-SEGURIDAD |
| BIZ_N4 | 72 | 1 | ❌ | ROL-AUDITOR-INTERNO, ROL-ANALISTA-RIESGOS |
| BIZ_N5 | 83 | 1 | ❌ | ROL-CAJERO, ROL-PORTERO, ROL-CHOFER-CAMION |
| **TOTAL** | **221** | | | |

---

#### D2 — Acceso Físico (~30 roles — NIST SP 800-116 / IEC 60839-11-5 / OSDP v2.2.2)
Controla ingreso a zonas físicas: PACS, OSDP, anti-passback, credencial temporal.
**Estado: 🟢 COMPLETADO** — De ~16 a ~30 roles (+14 nuevos 2026-07-09)

**Roles originales:**
| Rol | Nombre | Tier |
|-----|--------|------|
| ROL-JEFE-SEGURIDAD | Jefe de Seguridad | BIZ_N3 |
| ROL-SUPERVISOR-SEGURIDAD | Supervisor de Seguridad | BIZ_N4 |
| ROL-CONTROL-VEHICULAR | Controlador de Acceso Vehicular | BIZ_N5 |
| ROL-OPERADOR-CCTV | Operador de CCTV | BIZ_N5 |
| ROL-PORTERO | Portero / Guardia de Seguridad | BIZ_N5 |
| ROL-SERENO | Sereno / Vigilante Nocturno | BIZ_N5 |
| ROL-EXT-VISITANTE | Visitante General | VISITANTE |

**Nuevos roles añadidos (2026-07-09):**
| Rol | Nombre | Tier |
|-----|--------|------|
| ROL-ADMINISTRADOR-PACS | Administrador de Control de Acceso Físico | BIZ_N3 |
| ROL-ADMINISTRADOR-CREDENCIALES-FISICAS | Administrador de Credenciales PIV/RFID | BIZ_N3 |
| ROL-JEFE-DATACENTER | Jefe de Centro de Datos | BIZ_N3 |
| ROL-CONTROLADOR-ZONA-CRITICA | Controlador de Zona Crítica | BIZ_N4 |
| ROL-SUPERVISOR-BOVEDA | Supervisor de Bóveda Bancaria | BIZ_N4 |
| ROL-SUPERVISOR-DATACENTER | Supervisor de Centro de Datos | BIZ_N4 |
| ROL-SUPERVISOR-ZONA-MEDICA | Supervisor de Acceso a Zona Médica Restringida | BIZ_N4 |
| ROL-TECNICO-ALARMAS | Técnico de Sistemas de Alarmas e Intrusión | BIZ_N4 |
| ROL-CUSTODIO-BOVEDA | Custodio de Bóveda y Valores | BIZ_N5 |
| ROL-OPERADOR-CONTROL-INDUSTRIAL | Operador de Panel de Control Industrial | BIZ_N5 |
| ROL-OPERADOR-DATACENTER | Operador de Centro de Datos | BIZ_N5 |
| ROL-OPERADOR-PACS | Operador de Control de Acceso Físico | BIZ_N5 |
| ROL-EXT-INSPECTOR-SEGURIDAD-AEROPORTUARIA | Inspector de Seguridad Aeroportuaria (AASANA) | EXT_N0 |
| ROL-EXT-OFICIAL-ACCESO-ADUANERO | Oficial de Acceso Aduanero | EXT_N0 |

---

#### D3 — Financiero (~115 roles — PCI DSS 4.0.1 / SOX §404 / COSO / ISO 20022)
Controla límites transaccionales, autorizaciones de pago, SoD financiero.
**Estado: 🟢 MEJORADO** — De ~95 a ~115 roles (+20 nuevos 2026-07-09)

| Tier | Descripción | Ejemplos clave nuevos |
|------|------------|----------------------|
| BIZ_N2 | Directivos con P&L | ROL-GERENTE-BANCO |
| BIZ_N3 | Jefes financieros | ROL-JEFE-TESORERIA · ROL-GERENTE-MICROFINANZAS · ROL-OFICIAL-CUMPLIMIENTO-FINANCIERO · ROL-SUPERVISOR-CREDITOS · ROL-GESTOR-CARTERA-INVERSION · ROL-APROBADOR-GASTOS · ROL-AUDITOR-FINANCIERO |
| BIZ_N4 | Analistas / especialistas | ROL-ANALISTA-INVERSIONES · ROL-OPERADOR-PASARELA-PAGOS · ROL-ANALISTA-RIESGO-FINANCIERO · ROL-CONTROLADOR-EFECTIVO · ROL-OPERADOR-SWIFT · ROL-ANALISTA-COSTOS · ROL-ANALISTA-PRESUPUESTO · ROL-OPERADOR-FONDOS-MUTUOS · ROL-ANALISTA-FLUJO-CAJA · ROL-ESPECIALISTA-FACTORING · ROL-OPERADOR-CASA-CAMBIOS |
| BIZ_N5 | Operativos con caja | ROL-CAJERO · ROL-ENCARGADO-CAJA · ROL-OPERADOR-POS · ROL-GESTOR-COBROS |
| EXT_N0 | Clientes con factura | ROL-EXT-CLIENTE-BANCARIO · ROL-EXT-COMPRADOR-RETAIL |

---

#### D4 — Temporal (155 roles — BIZ_N4 + BIZ_N5)
Controla horarios de acceso, turnos, GTRBAC: un cajero accede solo en su turno de 08:00–16:00.

| Tier | n | Descripción |
|------|--:|------------|
| BIZ_N4 | 72 | Técnicos con horario laboral fijo |
| BIZ_N5 | 83 | Operativos con turnos rotativos |
| **TOTAL** | **155** | |

Ejemplos: ROL-CAJERO, ROL-OPERARIO, ROL-CHOFER-CAMION, ROL-ENFERMERO, ROL-DOCENTE

---

#### D5 — Biométrico (~34 roles — ISO/IEC 30107-3 / NIST SP 800-63B-4 §5.2.3)
Roles que gestionan o usan autenticación biométrica: huella, facial, iris, anti-spoofing, FIDO2.
**Estado: 🟢 COMPLETADO** — De 19 a ~34 roles (+15 nuevos 2026-07-09)

| Tier | n | LOA | Ejemplos originales + nuevos |
|------|--:|:---:|------------------------------|
| SU | 1 | 3 | ROL-SYS-SUPERUSUARIO |
| BIZ_N1 | 5 | 3 | ROL-GERENTE-GENERAL, ROL-SYS-ADMIN-SEGURIDAD |
| BIZ_N2 | 13 | 2 | ROL-SYS-ADMIN-BAUTH, ROL-GERENTE-BANCO |
| BIZ_N3 | +3 | 2 | **ROL-SUPERVISOR-ENROLAMIENTO-BIOMETRICO** · **ROL-AUDITOR-SISTEMAS-BIOMETRICOS** · **ROL-ADMINISTRADOR-BIOMETRIA** · **ROL-INGENIERO-BIOMETRIA** |
| BIZ_N4 | +5 | 1 | **ROL-OFICIAL-ENROLAMIENTO-BIOMETRICO** · **ROL-ANALISTA-HUELLA-DACTILAR** · **ROL-SUPERVISOR-CONTROL-ASISTENCIA** · **ROL-OPERADOR-RECONOCIMIENTO-FACIAL** · **ROL-ESPECIALISTA-ANTISPOOFING** · **ROL-COORDINADOR-BIOMETRIA** |
| BIZ_N5 | +3 | 1 | **ROL-VERIFICADOR-IDENTIDAD-BIOMETRICA** · **ROL-OPERADOR-TERMINAL-ASISTENCIA** · **ROL-OPERADOR-IRIS** |
| EXT_N0 | +2 | 1 | **ROL-EXT-VERIFICADOR-MIGRACION** (PAS Bolivia) · **ROL-EXT-VERIFICADOR-SEGIP** |
| **TOTAL** | **~34** | | |

---

#### D6 — Geoespacial (~54 roles — OGC GeoFence / BeyondCorp / Bolivia)
Controla acceso por ubicación GPS: geofencing de zonas, telemetría, despacho, emergencias.
**Estado: 🟢 MEJORADO** — De ~40 a ~54 roles (+14 nuevos 2026-07-09)

**Roles originales (muestra):** ROL-CAPATAZ · ROL-CHOFER-CAMION · ROL-DESPACHADOR-CHOFER · ROL-PEON-RURAL · ROL-EXT-TECNICO-SERVICIO

**Nuevos roles añadidos (2026-07-09):**
| Rol | Nombre | Tier |
|-----|--------|------|
| ROL-ADMINISTRADOR-GEOFENCING | Administrador de Reglas de Geofencing | BIZ_N3 |
| ROL-GERENTE-FLOTA | Gerente de Flota Vehicular | BIZ_N3 |
| ROL-ANALISTA-SIG | Analista de SIG/GIS | BIZ_N4 |
| ROL-ANALISTA-GEOLOCALIZACION | Analista de Geolocalización y Telemetría | BIZ_N4 |
| ROL-COORDINADOR-LOGISTICA-CAMPO | Coordinador de Logística de Campo | BIZ_N4 |
| ROL-OPERADOR-DRON | Operador Certificado de Dron / UAV (DGAC Bolivia) | BIZ_N4 |
| ROL-SUPERVISOR-FLOTA | Supervisor de Flota y Logística | BIZ_N4 |
| ROL-DESPACHADOR-FLOTA | Despachador de Flota Vehicular | BIZ_N5 |
| ROL-TECNICO-CAMPO-SERVICIOS-BASICOS | Técnico de Campo de Servicios Básicos (EPSAS/Gas) | BIZ_N5 |
| ROL-EXT-BOMBERO | Bombero Operativo de Campo | EXT_N0 |
| ROL-EXT-INSPECTOR-MEDIOAMBIENTAL | Inspector Medioambiental de Campo | EXT_N0 |
| ROL-EXT-INSPECTOR-URBANISMO | Inspector de Urbanismo y Ordenamiento | EXT_N0 |
| ROL-EXT-OPERADOR-EMERGENCIAS | Operador de Centro de Emergencias / 911 | EXT_N0 |
| ROL-EXT-PARAMEDICO | Paramédico / Técnico en Emergencias Médicas | EXT_N0 |

---

#### D7 — Red / Network (~55 roles — NIST SP 800-207 ZTA / IEEE 802.1X / CAEP)
Controla acceso por contexto de red: Zero Trust, firewall, SOC, VPN, IoT, 802.1X.
**Estado: 🟢 COMPLETADO** — De ~35 a ~55 roles (+20 nuevos 2026-07-09)

| Tier | n orig. | n v2 | Nuevos roles clave |
|------|------:|------:|---------------------|
| SU | 1 | 1 | ROL-SYS-SUPERUSUARIO |
| M2M | 29 | 29 | ROL-SYS-BHNEXUS-DAEMON, ROL-SYS-BAUTH-DAEMON |
| BIZ_N2 | ~5 | 6 | ROL-SYS-ADMIN-BAUTH · **ROL-ARQUITECTO-SEGURIDAD-RED** |
| BIZ_N3 | 0 | 6 | **ROL-ANALISTA-SOC-N3** · **ROL-INGENIERO-ZERO-TRUST** · **ROL-SUPERVISOR-NOC** · **ROL-ESPECIALISTA-PENTEST** · **ROL-COORDINADOR-INCIDENTES-CYBER** |
| BIZ_N4 | 0 | 12 | **ROL-ADMINISTRADOR-RED** · **ROL-ANALISTA-SOC-N2** · **ROL-ADMINISTRADOR-FIREWALL** · **ROL-OPERADOR-SIEM** · **ROL-ADMINISTRADOR-VPN** · **ROL-ADMINISTRADOR-IOT** · **ROL-ADMINISTRADOR-DNS** · **ROL-ANALISTA-VULNERABILIDADES** · **ROL-ANALISTA-TRAFICO-RED** · **ROL-ADMINISTRADOR-IDENTIDAD-NUBE** · **ROL-ANALISTA-THREAT-INTELLIGENCE** · **ROL-ADMINISTRADOR-802-1X** |
| BIZ_N5 | 0 | 2 | **ROL-ANALISTA-SOC-N1** · **ROL-OPERADOR-NOC** |
| **TOTAL** | **~35** | **~55** | |

---

#### D8 — Contexto / Sesión (367 roles — UNIVERSAL)
El `ctx_id` es obligatorio en toda operación (SBOS-049). Aplica a todos los roles sin excepción.

`ctx_id = {tenant}.{bdomain}.{bsubdomain}.{pos_logico}` — 6 capas, W3C Trace Context + OpenTelemetry Baggage.

---

#### D9 — Credenciales (367 roles — UNIVERSAL)
Toda identidad tiene política de credenciales. El nivel AAL varía por tier:

| Tier | AAL | Método requerido |
|------|:---:|-----------------|
| SU | AAL3 | WebAuthn Hardware Key + Biométrico |
| BIZ_N1 | AAL3 | WebAuthn + MFA |
| BIZ_N2, M2M | AAL2 | TOTP o WebAuthn |
| BIZ_N3 | AAL2 | TOTP o WebAuthn |
| BIZ_N4, BIZ_N5 | AAL1 | Password NIST 800-63B |
| EXT_N0, VISITANTE | AAL1 | Password o credencial temporal |

---

#### D10 — Delegación (~50 roles — ANSI/INCITS 359-2004 DSD / NIST AC-5)
Roles con capacidad de delegación temporal de permisos o que ejercen representación legal/institucional.
**Estado: 🟢 MEJORADO** — De 36 a ~50 roles (+14 nuevos 2026-07-09)

| Tier | n orig. | n v2 | Descripción |
|------|------:|------:|------------|
| BIZ_N1 | 5 | 5 | Pueden delegar a BIZ_N2 |
| BIZ_N2 | 13 | 16 | Pueden delegar a BIZ_N3 · **ROL-AUTORIDAD-SUSTITUTA** · **ROL-DELEGADO-DIRECTORIO** · **ROL-DIRECTOR-ENCARGADO** |
| BIZ_N3 | 18 | 27 | **ROL-APODERADO-LEGAL** · **ROL-SUPLENTE-GERENTE** · **ROL-GERENTE-INTERINO** · **ROL-COORDINADOR-CONTINUIDAD-NEGOCIO** · **ROL-MANDATARIO-COMERCIAL** · **ROL-COORDINADOR-EMERGENCY-MGMT** · **ROL-FISCAL-INTERNO** · **ROL-COORDINADOR-RESPUESTA-INCIDENTES** |
| BIZ_N4 | 0 | 1 | **ROL-DELEGADO-FIRMA** |
| EXT_N0 | 0 | 2 | **ROL-EXT-REPRESENTANTE-LEGAL** · **ROL-EXT-DELEGADO-GREMIAL** |
| **TOTAL** | **36** | **~50** | |

---

#### D11 — Auditoría (66 roles con `audit_level=full` + 155 con `basic`)
Genera eventos WORM en `aud_event`. Nivel determinado por `audit_level` del rol.

| audit_level | Tiers | n | Descripción |
|-------------|-------|--:|------------|
| `full` | SU, BIZ_N1, BIZ_N2, M2M | 44 | Cada operación → evento inmutable |
| `basic` | BIZ_N3, BIZ_N4, BIZ_N5, VISITANTE | 173 | Operaciones críticas → evento |
| `none` | EXT_N0 | 142 | Sin evento de auditoría (acceso externo) |
| **TOTAL auditado** | | **217** | |

---

#### D12 — Blockchain / Anclaje (~35 roles — NIST IR 8202 / EIP-725/735 / W3C DID Core)
Roles para operaciones en cadena de bloques, DID/VC, contratos inteligentes y trazabilidad.
**Estado: 🟢 COMPLETADO** — De ~20 a ~35 roles (+15 nuevos 2026-07-09)

**Roles originales de anclaje:**
| Rol | Nombre | Tier | Motivo |
|-----|--------|------|--------|
| ROL-SYS-SUPERUSUARIO | Superusuario SBOS | SU | Toda operación SU anclada |
| ROL-SYS-ADMIN-BAUTH | Administrador de bAuth | BIZ_N2 | Cambios de política IAM |
| ROL-SYS-ADMIN-DATOS | Administrador de Datos (DBA) | BIZ_N2 | Cambios de esquema |
| ROL-SYS-ADMIN-VAULT | Administrador de Vault | BIZ_N2 | Rotación de secretos |
| ROL-GERENTE-BANCO | Gerente de Sucursal Bancaria | BIZ_N2 | Aprobaciones financieras mayores |
| ROL-TESORERO | Tesorero | BIZ_N3 | Transferencias bancarias |
| ROL-M2M-BLOCKCHAIN | M2M Blockchain Anchor | M2M | Servicio de anclaje on-chain |

**Nuevos roles de gestión blockchain (2026-07-09):**
| Rol | Nombre | Tier | Norma |
|-----|--------|------|-------|
| ROL-DESPLEGADOR-CONTRATO-INTELIGENTE | Desplegador de Contratos Inteligentes | BIZ_N3 | EIP-1967 Proxy |
| ROL-ADMINISTRADOR-DID | Administrador de Identidad Descentralizada DID | BIZ_N3 | W3C DID Core 1.0 |
| ROL-COORDINADOR-DID-ORGANIZACIONAL | Coordinador de Identidad Organizacional DID | BIZ_N3 | VC Data Model 2.0 |
| ROL-NOTARIO-DIGITAL-BLOCKCHAIN | Notario Digital Blockchain | BIZ_N3 | Ley 164 Bolivia |
| ROL-AUDITOR-CONTRATO-INTELIGENTE | Auditor de Contratos Inteligentes | BIZ_N3 | SWC Registry |
| ROL-GESTOR-CADENA-SUMINISTRO-BLOCKCHAIN | Gestor de Trazabilidad Cadena de Suministro | BIZ_N3 | GS1 + Hyperledger |
| ROL-EMISOR-TOKEN-DIGITAL | Emisor de Tokens Digitales / NFT | BIZ_N4 | EIP-20/721/1155 |
| ROL-VERIFICADOR-BLOCKCHAIN | Verificador de Transacciones Blockchain | BIZ_N4 | EIP-712 |
| ROL-ANALISTA-TRAZABILIDAD-FARMACEUTICA | Analista Trazabilidad Farmacéutica Blockchain | BIZ_N4 | MediLedger |
| ROL-OPERADOR-NODO-BLOCKCHAIN | Operador de Nodo de Red Blockchain | BIZ_N4 | Besu Admin API |
| ROL-DESARROLLADOR-CONTRATO-INTELIGENTE | Desarrollador de Contratos Inteligentes | BIZ_N4 | OpenZeppelin |
| ROL-ADMINISTRADOR-CARTERA-DIGITAL | Administrador de Cartera Digital / Custodia Cripto | BIZ_N4 | CCSS |
| ROL-ANALISTA-COMPLIANCE-BLOCKCHAIN | Analista de Compliance Blockchain / DeFi | BIZ_N4 | FATF Travel Rule |
| ROL-EXT-OFICIAL-REGISTRO-INMOBILIARIO-BLOCKCHAIN | Oficial de Registro Inmobiliario Blockchain | EXT_N0 | Derechos Reales Bolivia |
| ROL-EXT-VALIDADOR-BLOCKCHAIN | Validador Externo de Red Blockchain | EXT_N0 | IBFT/QBFT consensus |

---

#### D13 — Firma Digital Externa (~10 roles — ADSIB + Besu)
Roles autorizados a firmar documentos con validez legal (Ley 164 Bolivia, ADSIB RSA-SHA256).

| Rol | Nombre | Tier | Uso |
|-----|--------|------|-----|
| ROL-SYS-SUPERUSUARIO | Superusuario SBOS | SU | Firma certificados del sistema |
| ROL-SYS-ADMIN-BAUTH | Administrador de bAuth | BIZ_N2 | Firma políticas IAM |
| ROL-GERENTE-GENERAL | Gerente General / Director | BIZ_N1 | Firma contratos corporativos |
| ROL-TESORERO | Tesorero | BIZ_N3 | Firma órdenes de pago |
| ROL-JEFE-CONTABILIDAD | Jefe de Contabilidad | BIZ_N3 | Firma estados financieros |
| ROL-AUDITOR-INTERNO | Auditor Interno | BIZ_N4 | Firma informes de auditoría |
| ROL-M2M-FACTURACION | M2M Facturación SIN | M2M | Firma electrónica facturas SIN |

---

### Resumen cruzado: Planos × Tiers

> **v2 — 478 roles** (actualizado 2026-07-09 tras inserción de 111 nuevos roles).
> Los planos D8/D9 actualizan a 478 (aplican a todos los roles).

| Plano | SU | M2M | N1 | N2 | N3 | N4 | N5 | EXT | VIS | TOTAL v1 | TOTAL v2 | Δ |
|-------|----|-----|----|----|----|----|----|----|-----|:--------:|:--------:|:---:|
| D00 Identidad | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 367 | **548** | +181 |
| D1 Lógico | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | — | 221 | **~340** | +119 |
| D2 Físico 🟢🟢 | — | — | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | ~16 | **~50** | +34 |
| D3 Financiero 🟢🟢 | ✅ | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | — | ~95 | **~140** | +45 |
| D4 Temporal | — | — | — | — | — | ✅ | ✅ | — | — | 155 | **155** | 0 |
| D5 Biométrico 🟢 | ✅ | — | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | 19 | **~34** | +15 |
| D6 Geoespacial 🟢 | — | — | — | — | ✅ | ✅ | ✅ | ✅ | ✅ | ~40 | **~54** | +14 |
| D7 Red 🟢🟢 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ~35 | **~80** | +45 |
| D8 Contexto | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 367 | **548** | +181 |
| D9 Credenciales | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 367 | **548** | +181 |
| D10 Delegación 🟢 | ✅ | — | ✅ | ✅ | ✅ | ✅ | — | ✅ | — | 36 | **~50** | +14 |
| D11 Auditoría | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ | 217 | **~310** | +93 |
| D12 Blockchain 🟢 | ✅ | ✅ | — | ✅ | ✅ | ✅ | — | ✅ | — | ~20 | **~35** | +15 |
| D13 Firma Digital | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | — | — | ~10 | **~10** | 0 |

> 🟢 = Plano reforzado en esta sesión (2026-07-09).

---

## Pendientes

### Inmediatos (aprobación HITL requerida)
- [ ] Regenerar seed `bauth_48__idn_role_template.sql` con los 478 roles + columna `domains` incluida
- [ ] Integrar 10 columnas nuevas en `CREATE TABLE bauth.idn_role_template` de `sbos_00__esquema_base.sql` (líneas 2449-2495)

### Calidad de datos
- [ ] Poblar `applies_to_size` para roles que solo aplican a empresas grandes o multinacionales
- [ ] Asignar `parent_id` correctos para árbol de organigrama (§3/§4)
- [ ] Evaluar columna `control_planes JSONB` para asignación de planos D1-D13 por rol (distinto de `domains` D01-D20)

### Planos aún incompletos (para próxima iteración)
- [ ] **D1 Acceso Lógico** — ampliar roles de sesión, step-up RFC 9470 y PAP/PEP
- [ ] **D9 Credenciales** — agregar roles específicos de gestión WebAuthn/FIDO2
- [ ] **D13 Firma Digital** — agregar roles ADSIB Bolivia y notaría pública

### Completados esta sesión (2026-07-09) — 2 inserciones

**Inserción 1 (+111 roles → total 478):**
- [x] +14 roles D2 Acceso Físico — NIST SP 800-116 / OSDP v2.2.2 / AASANA
- [x] +20 roles D3 Financiero — PCI DSS 4.0 / SOX §404 / ASFI Bolivia
- [x] +15 roles D5 Biométrico — ISO/IEC 30107-3 / SEGIP / PAS Bolivia
- [x] +14 roles D6 Geoespacial — OGC GeoFence / DGAC Bolivia / EPSAS
- [x] +20 roles D7 Red — NIST SP 800-207 ZTA / IEEE 802.1X / CAEP
- [x] +14 roles D10 Delegación — ANSI/INCITS 359-2004 DSD / NIST AC-5
- [x] +15 roles D12 Blockchain — NIST IR 8202 / EIP-725/735 / W3C DID Core / Ley 164
- [x] `INSERT 0 111` confirmado

**Inserción 2 (+70 roles → total 548):**
- [x] +20 roles D2 Acceso Físico ampliado (total: ~50) — BMS/BAS · Clean Room · HSE · Transporte Valores · Bomberos · Ley 264 Bolivia
- [x] +25 roles D3 Financiero ampliado (total: ~140) — CISO Financiero · Actuario · AML/CFT SEPLADE · AFP · Remesas · FX Desk · Fintech QR BCB · Cooperativas · Perito Avaluador
- [x] +25 roles D7 Red ampliado (total: ~80) — CISO · NOC Manager · SD-WAN · PKI/CA · CSIRT · CloudSec · DLP · MDM · EDR · NAC · DevSecOps · Microsegmentación · OSINT/CTI · Forense DFIR · WAF · ISP
- [x] `INSERT 0 70` confirmado

**TOTAL ACUMULADO: +181 roles en VPS** (367 → **548**) — `SELECT COUNT(*) → 548` verificado
