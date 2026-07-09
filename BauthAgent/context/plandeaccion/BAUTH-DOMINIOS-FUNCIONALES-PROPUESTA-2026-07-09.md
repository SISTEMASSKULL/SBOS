# BAUTH — Propuesta: Dominios Funcionales para idn_role_template
**Fecha:** 2026-07-09 · **Autor:** bauth-developer · **Estado:** PENDIENTE APROBACIÓN HITL

---

## Problema

El campo `scope` actual es texto libre de granularidad variable (sector CAEB, módulo, área).
Un rol puede pertenecer a **más de un dominio funcional** — por ejemplo:

- ROL-CFO → Gerencia + Finanzas + Tributación
- ROL-AUDITOR-INTERNO → Legal + Finanzas
- ROL-JEFE-LOGISTICA → Logística + Operaciones + Comercial

`scope TEXT` (un solo valor) no captura esta realidad. Se propone agregar:

```sql
domains JSONB NOT NULL DEFAULT '[]'
```

Con un array de códigos: `["FINANZAS","TRIBUTACION"]`

Ventajas del JSONB:
- Multi-dominio sin tabla de intersección
- Filtrado eficiente con índice GIN: `WHERE domains @> '["FINANZAS"]'`
- Reporte por dominio con `jsonb_array_elements_text()`
- Evoluciona sin ALTER TABLE adicionales

---

## Taxonomía propuesta: 20 dominios funcionales

| Código | Nombre | Tiers principales | Descripción |
|--------|--------|-------------------|-------------|
| `SISTEMA` | Sistema & Plataforma | SU, M2M | SU, M2M y roles técnicos de infraestructura SBOS (bAuth, BOS, bKernel, biedata, NEXUS, Kong, Vault) |
| `GERENCIA` | Alta Gerencia & Dirección | BIZ_N1, BIZ_N2, BIZ_N3 | CEO, Presidentes, Directores ejecutivos, Junta Directiva, Gerentes Generales |
| `FINANZAS` | Finanzas & Contabilidad | BIZ_N3, BIZ_N4, BIZ_N5 | Contabilidad, Tesorería, Planificación Financiera, CFO, Balances, cierre fiscal |
| `TRIBUTACION` | Tributación & Facturación | BIZ_N3, BIZ_N4, BIZ_N5 | SIN, Impuestos, Facturación electrónica, NIT, Crédito y Cobranza, NITEX |
| `BANCA` | Banca & Servicios Financieros | BIZ_N2–N5, EXT_N0 | Banca, Seguros, AFP, Valores, ASFI, intermediación financiera |
| `RRHH` | Recursos Humanos | BIZ_N3, BIZ_N4, BIZ_N5 | Contratación, Nómina, Relaciones Laborales, Capacitación, Clima laboral |
| `COMERCIAL` | Comercial & Ventas | BIZ_N3–N5, EXT_N0 | Ventas, Marketing, CRM, Comercio al por menor/mayor, Exportaciones |
| `OPERACIONES` | Operaciones & Manufactura | BIZ_N3, BIZ_N4, BIZ_N5 | Producción, Manufactura industrial, Control de calidad, MRP |
| `LOGISTICA` | Logística & Cadena de Suministro | BIZ_N3–N5 | Almacén, Inventarios, Transporte, Distribución, Compras |
| `TECNOLOGIA` | Tecnología & Ciberseguridad | BIZ_N2–N5, EXT_N0 | TI, Sistemas, Soporte, Infraestructura, Seguridad informática |
| `LEGAL` | Legal, Auditoría & Compliance | BIZ_N3–N5, EXT_N0 | Legal, Auditoría interna/externa, Riesgo, Notaría, Registro |
| `SALUD` | Salud & Asistencia Social | BIZ_N3–N5, EXT_N0 | Médico, Clínico, Farmacéutico, Laboratorio, Asistencia Social |
| `EDUCACION` | Educación & Formación | BIZ_N2, BIZ_N4–N5, EXT_N0 | Docencia, Academia, Investigación, Formación técnica, Biblioteca |
| `AGRO` | Agro & Medio Ambiente | BIZ_N3–N5, EXT_N0 | Agricultura, Ganadería, Pesca, Forestal, Agua y Saneamiento |
| `CONSTRUCCION` | Construcción & Inmobiliaria | BIZ_N4, BIZ_N5, EXT_N0 | Inmobiliaria, Arquitectura, Ingeniería Civil, Obras y proyectos |
| `MINERIA` | Minería & Energía | BIZ_N4, BIZ_N5, EXT_N0 | Minería, Hidrocarburos, Electricidad, Gas, Vapor y Energías |
| `HOTELERIA` | Hotelería, Turismo & Arte | BIZ_N2–N5, EXT_N0 | Hospedaje, Restaurantes, Turismo, Eventos, Arte y Recreación |
| `PUBLICO` | Sector Público & Gobierno | EXT_N0 | Gobierno, Administración Pública, Defensa, Electoral |
| `EXTERNO` | Externo & Visitantes | EXT_N0, VISITANTE | Proveedores, Contratistas, Visitantes, Organizaciones internacionales |
| `HOGAR` | Hogar & Familia | EXT_N0 | Hogar, Familia, Empleado doméstico, Familiar de paciente |

---

## Distribución preliminar (por heurística de scope — pre-UPDATE)

> Nota: estimación basada en mapeo de `scope` → dominio. El UPDATE real asignará dominios
> múltiples y corregirá los valores subestimados (RRHH solo capta 3 por heurística porque
> sus roles tienen scope='Administración Empresarial').

| Dominio | Roles (estimado) | Barra |
|---------|-----------------|-------|
| COMERCIAL | 46 | ████████████████████████████████████████████ |
| SISTEMA | 40 | ███████████████████████████████████████ |
| LOGISTICA | 29 | █████████████████████████████ |
| TRIBUTACION | 25 | █████████████████████████ |
| TECNOLOGIA | 22 | ██████████████████████ |
| HOTELERIA | 20 | ████████████████████ |
| OPERACIONES | 20 | ████████████████████ |
| SALUD | 18 | ██████████████████ |
| CONSTRUCCION | 17 | █████████████████ |
| BANCA | 17 | █████████████████ |
| AGRO | 16 | ████████████████ |
| FINANZAS | 16 | ████████████████ |
| EXTERNO | 16 | ████████████████ |
| EDUCACION | 15 | ███████████████ |
| LEGAL | 14 | ██████████████ |
| GERENCIA | 14 | ██████████████ |
| MINERIA | 10 | ██████████ |
| PUBLICO | 6 | ██████ |
| RRHH | 3* | ███ |
| HOGAR | 3 | ███ |

*RRHH subestimado por heurística — en el UPDATE real se asignarán correctamente.

**Total asignaciones (rol puede tener 1–3 dominios):** estimado ~520 asignaciones para 367 roles.

---

## Ejemplos de roles multi-dominio

| ID del Rol | Nombre | Dominios propuestos |
|-----------|--------|---------------------|
| ROL-CFO | Director Financiero | `GERENCIA`, `FINANZAS`, `TRIBUTACION` |
| ROL-AUDITOR-INTERNO | Auditor Interno | `LEGAL`, `FINANZAS` |
| ROL-JEFE-LOGISTICA | Jefe de Logística | `LOGISTICA`, `OPERACIONES`, `COMERCIAL` |
| ROL-M2M-BAUTH-ADMIN | M2M bAuth Admin | `SISTEMA`, `TECNOLOGIA` |
| ROL-GERENTE-HOTEL | Gerente de Hotel | `GERENCIA`, `HOTELERIA`, `COMERCIAL` |
| ROL-CONTADOR | Contador | `FINANZAS`, `TRIBUTACION` |
| ROL-JEFE-RRHH | Jefe de RRHH | `RRHH`, `LEGAL`, `GERENCIA` |
| ROL-EXT-TECNICO-SERVICIO | Técnico de Servicio | `EXTERNO`, `CONSTRUCCION`, `LOGISTICA` |
| ROL-EXT-FAMILIAR-PACIENTE | Familiar de Paciente | `HOGAR`, `SALUD` |
| ROL-ASESOR-LEGAL | Asesor Legal Externo | `LEGAL`, `EXTERNO` |
| ROL-INSPECTOR-CALIDAD | Inspector de Calidad | `OPERACIONES`, `LEGAL`, `EXTERNO` |
| ROL-DIRECTOR-COLEGIO | Director de Colegio | `GERENCIA`, `EDUCACION` |
| ROL-MEDICO-EMPRESA | Médico de Empresa | `SALUD`, `RRHH` |
| ROL-JEFE-CONTABILIDAD | Jefe de Contabilidad | `FINANZAS`, `TRIBUTACION`, `GERENCIA` |
| ROL-SYS-BAUTH-DAEMON | bAuth Daemon | `SISTEMA` |

---

## Propuesta técnica: columna `domains JSONB`

### ALTER TABLE (requiere aprobación HITL)

```sql
-- Columna
ALTER TABLE bauth.idn_role_template
  ADD COLUMN domains JSONB NOT NULL DEFAULT '[]';

COMMENT ON COLUMN bauth.idn_role_template.domains IS
  'Array JSONB de códigos de dominio funcional. Ej: ["FINANZAS","TRIBUTACION"].
   Norma: ISO 24760-2:2025 §6 · NIST SP 800-53 AC-2. Taxonomía SBOS v1.0 (20 dominios).';

-- Índice GIN para filtrado eficiente
CREATE INDEX idx_idn_role_template_domains
  ON bauth.idn_role_template USING gin(domains);
```

### Consultas de reporte

```sql
-- Reporte: roles por dominio
SELECT domain_code, COUNT(*) AS n
FROM bauth.idn_role_template
  CROSS JOIN LATERAL jsonb_array_elements_text(domains) AS domain_code
GROUP BY domain_code
ORDER BY n DESC;

-- Filtrar roles de un dominio específico
SELECT id, role_name, tier
FROM bauth.idn_role_template
WHERE domains @> '["FINANZAS"]'
ORDER BY tier, role_name;

-- Roles multi-dominio (más de 1 dominio)
SELECT id, role_name, jsonb_array_length(domains) AS n_dominios, domains
FROM bauth.idn_role_template
WHERE jsonb_array_length(domains) > 1
ORDER BY n_dominios DESC;
```

---

## Pendiente de aprobación (HITL)

- [ ] **¿Aprueba la taxonomía de 20 dominios?** ¿Agregar, quitar o renombrar alguno?
- [ ] **¿Aprueba el ALTER TABLE** `ADD COLUMN domains JSONB DEFAULT '[]'`?
- [ ] **¿Aprueba el índice GIN** `idx_idn_role_template_domains`?

Una vez aprobado:
1. Ejecutar ALTER TABLE + índice GIN en VPS
2. Ejecutar UPDATEs masivos para los 367 roles con sus dominios correctos
3. Regenerar el seed `bauth_48__idn_role_template.sql`
4. Registrar la columna en `BAUTH-ALTER-TABLE-IDN-ROLE-TEMPLATE-2026-07-09.md`
