# Análisis — Agrupación de Sectores de Identidad por Compatibilidad de Ciclo de Vida

## No se agrupan por ISIC. Se agrupan por cómo nacen, viven y mueren.

**Versión:** 1.0
**Fecha:** 2026-07-14

---

## 1. El error: agrupar por sector económico

ISIC Rev.5 clasifica actividades económicas. Pero en un sistema de identidad, lo que
importa no es si una entidad pertenece a "Agricultura" o "Manufactura" — importa si su
**ciclo de vida** es compatible. Una vaca y un tractor están ambos en Agricultura, pero
uno nace, crece y muere; el otro se compra, se deprecia y se da de baja. No comparten
ciclo de vida. No deberían estar en el mismo grupo.

## 2. Los 6 tipos de ciclo de vida

Cada entidad en `idn_entidad` sigue uno de 6 ciclos de vida fundamentales. Dos entidades
son **compatibles** si comparten el mismo ciclo.

### Tipo A — Ser Humano (registro civil)

```
NACE ──→ ACTIVO ──→ FALLECIDO
         │
         └──→ (nunca se elimina, retención legal permanente)
```

**Estados:** REGISTRADO, ACTIVO, FALLECIDO
**Entidades:** cualquier actor HUMAN (empleado, cliente, paciente, alumno, jubilado)
**Atributos:** given_name, family_name, CI, birth_date, nationality, gender
**Independiente de:** RRHH, autenticación, relación comercial
**Regla:** la identidad civil NUNCA se desactiva por evento laboral. Un empleado
terminado sigue siendo una persona viva con CI válido.

### Tipo B — Relación Laboral (RRHH)

```
CONTRATADO ──→ ACTIVO ──→ SUSPENDIDO ──→ TERMINADO
                │            │
                └──→ ACTIVO ←┘
```

**Estados:** PENDING, ACTIVE, SUSPENDED, TERMINATED
**Entidades:** empleado, contratista, pasante
**Atributos:** employee_code, job_title, department, hire_date, termination_date, manager_uuid
**Depende de:** Tipo A (necesita una identidad civil primero)
**Regla:** al terminar, la persona sigue existiendo en Tipo A. Sus beneficios pueden
continuar (jubilación). Su autenticación (Tipo C) se revoca.

### Tipo C — Acceso al Sistema (autenticación)

```
ENROLADO ──→ ACTIVO ──→ BLOQUEADO ──→ REVOCADO
              │            │
              └──→ ACTIVO ←┘
```

**Estados:** ENROLLED, ACTIVE, LOCKED, REVOKED
**Entidades:** cualquier actor HUMAN, SERVICE o DEVICE que necesite login
**Depende de:** Tipo A (para HUMAN), Tipo E (para DEVICE)
**Regla:** revocar autenticación no afecta RRHH (jubilado sin acceso pero con beneficios).
Un SERVICE revocado no desaparece — solo deja de poder llamar APIs.

### Tipo D — Relación Comercial (cliente/proveedor)

```
PROSPECTO ──→ ACTIVO ──→ INACTIVO ──→ RESCINDIDO
```

**Estados:** PROSPECT, ACTIVE, INACTIVE, TERMINATED
**Entidades:** cliente (bDomain empresa/persona), proveedor (bDomain empresa)
**Atributos:** customer_since, credit_limit, payment_terms, category
**Depende de:** Tipo A (para persona), Tipo B (si es empleado que también es cliente interno)
**Regla:** un cliente inactivo no pierde su identidad civil ni su récord de compras.

### Tipo E — Activo Físico (cosas que se poseen)

```
ADQUIRIDO ──→ OPERATIVO ──→ MANTENIMIENTO ──→ DADO_DE_BAJA
                │               │
                └──→ OPERATIVO ←┘
```

**Estados:** ACQUIRED, OPERATIONAL, MAINTENANCE, DECOMMISSIONED
**Entidades:** vehiculo, servidor, maquinaria, edificio, equipo, mobiliario
**Atributos:** fecha_adquisicion, valor_compra, depreciacion, ubicacion, responsable
**Regla:** un activo dado de baja no desaparece — queda en registros contables.
No tiene "fecha de nacimiento", tiene "fecha de adquisición".

### Tipo F — Producto (cosas que se venden)

```
EN_STOCK ──→ RESERVADO ──→ VENDIDO ──→ DEVUELTO
              │               │
              └──→ EN_STOCK ←─┘
```

**Estados:** IN_STOCK, RESERVED, SOLD, RETURNED
**Entidades:** producto, artículo, insumo, mercadería
**Atributos:** codigo, precio, stock, lote, vencimiento
**Regla:** un producto vendido sale del inventario pero queda en historial de ventas.
Distinto a Tipo E: un activo se USA, un producto se VENDE.

---

## 3. Mapeo de sectores ISIC a tipo de ciclo de vida

| Sector ISIC | ¿Qué entidades tiene? | Tipo de ciclo |
|---|---|---|
| A (Agricultura) | cultivo → F, maquinaria → E, agricultor → A+B+C |
| B (Minería) | maquinaria → E, minero → A+B+C |
| C (Manufactura) | producto → F, máquina → E, operario → A+B+C |
| D+E (Electricidad, agua) | equipo → E, sensor → E, técnico → A+B+C |
| F (Construcción) | máquina → E, operario → A+B+C |
| G (Comercio) | producto → F, local → E, vendedor → A+B+C |
| H (Transporte) | vehículo → E, paquete → F, conductor → A+B+C |
| I (Hotelería) | habitación → E, huésped → A+D |
| J+K (TI) | servidor → E, software → F, desarrollador → A+B+C |
| L (Finanzas) | oficina → E, empleado → A+B+C |
| M (Inmobiliario) | edificio → E |
| N (Profesionales) | profesional → A+B+D |
| O (Administrativos) | empleado → A+B+C |
| P (Admin pública) | funcionario → A+B+C |
| Q (Educación) | alumno → A, profesor → A+B+C, aula → E |
| R (Salud) | paciente → A, médico → A+B+C, equipo_médico → E |
| S (Arte) | artista → A+D |
| T (Otros servicios) | prestador → A+D |
| U (Hogares) | residente → A, vivienda → E |
| V (Extraterritorial) | funcionario → A+B+C |

---

## 4. La agrupación correcta: 6 tipos, no 23 sectores

El sistema de identidad NO necesita 23 códigos de sector. Necesita **6 tipos de ciclo
de vida**. Cada entidad en `idn_entidad` declara su `ciclo_vida`:

```sql
ALTER TABLE bauth.idn_entidad ADD COLUMN ciclo_vida TEXT NOT NULL
  CHECK (ciclo_vida IN ('humano', 'laboral', 'autenticacion', 'comercial', 'activo', 'producto'));
```

| ciclo_vida | Ejemplos de entidades | Estados |
|---|---|---|
| `humano` | Juan Pérez, María Gómez, paciente, alumno | REGISTRADO, ACTIVO, FALLECIDO |
| `laboral` | empleado, contratista, pasante | PENDING, ACTIVE, SUSPENDED, TERMINATED |
| `autenticacion` | login de Juan, SAP-BOT, sensor IoT | ENROLLED, ACTIVE, LOCKED, REVOKED |
| `comercial` | cliente, proveedor | PROSPECT, ACTIVE, INACTIVE, TERMINATED |
| `activo` | vehículo, servidor, edificio, maquinaria | ACQUIRED, OPERATIONAL, MAINTENANCE, DECOMMISSIONED |
| `producto` | laptop en stock, cereal, medicamento | IN_STOCK, RESERVED, SOLD, RETURNED |

**Un empleado (Juan Pérez) tiene 3 ciclos de vida simultáneos:**
- `humano`: Juan Pérez como persona (REGISTRADO → ACTIVO → FALLECIDO)
- `laboral`: Juan Pérez como empleado (ACTIVE → SUSPENDED → TERMINATED)
- `autenticacion`: login de Juan (ACTIVE → REVOKED)

Cada ciclo es independiente. Revocar la autenticación no termina la relación laboral.
Terminar la relación laboral no elimina a la persona.

---

## 5. Conclusión

**No necesitamos D00-I01 al D00-I23.** Eso era un error — copiar ISIC sin entender
que los sectores económicos no definen ciclos de vida.

Necesitamos **6 tipos de ciclo de vida** en `idn_entidad.ciclo_vida`. Gobernados por
D93. Cada tipo define sus estados válidos, sus atributos requeridos, y sus reglas de
transición. Extensible sin tocar el DDL.
