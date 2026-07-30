# Análisis — Potencial del Sistema de Identidad de bAuth

## Lo que descubrimos: un catálogo universal, flexible, multi-tenant, gobernable y trazable

**Versión:** 1.0
**Fecha:** 2026-07-15

---

## 1. La arquitectura en una frase

**Dos tablas. Un lenguaje. Infinitas posibilidades.**

- `idn_entidad` — 5 niveles jerárquicos con `tipo` variable. 37 tipos documentados. Extensible.
- `idn_atributo` — EAV con `type` explícito, `dominio_origen`, `atom_code`, `value_data` JSONB. 18 display formats. Sin límite de atributos por entidad.
- AtomLang — mismo lenguaje para validar datos (motor de identidad) y gobernar acceso (BitMask).

---

## 2. Lo que puede hacer

### 2.1 Almacenar cualquier cosa, sin tocar el DDL

| Sector | Qué registra | Atributos por entidad |
|---|---|---|
| RRHH | Empleados, estructura org | 60+ (nombre, CI, cargo, salario, historial laboral...) |
| Inventario | Productos, almacenes, estantes | 10-30 (código, stock, precio, lote, vencimiento...) |
| Flota | Vehículos, patios | 10-20 (placa, marca, modelo, GPS, combustible...) |
| TI | Servidores, racks, switches | 15-40 (serial, IP, RAM, CPU, storage, SO...) |
| Catálogo | Marcas, modelos, rubros | 5-10 (nombre, país, website...) |
| Salud | Pacientes, médicos, habitaciones | 10-50 (historia clínica, diagnóstico, alergias...) |
| Educación | Alumnos, profesores, aulas | 10-30 (matrícula, carrera, notas...) |
| Construcción | Obras, máquinas, operarios | 10-20 |
| Agricultura | Cultivos, fincas, silos | 10-15 |
| Logística | Paquetes, centros de distribución | 10-15 |

**Mismas 2 tablas. Mismas 4 queries. Cero ALTER TABLE.**

### 2.2 Adaptarse a las necesidades del usuario — no al revés

Un código de farol puede tener 2 atributos o 100. El sistema no impone un esquema fijo.
Cada entidad define SUS propios atributos según quién la crea y para qué la usa.

```
Farol DEPO 212-1112-L:
  DEPO define:     código, tipo, posición, voltaje, tipo_conexión,
                   material_lente, temperatura_operación, certificación
                   = 8 atributos

  BOSCH define:    código, tipo, posición, voltaje, tipo_conexión,
                   garantía_horas, luminosidad_lumen, eficiencia_energética,
                   resistencia_impacto, norma_ECE, país_origen
                   = 11 atributos

  Tiendita agrega: stock, precio, ubicación, proveedor, fecha_ingreso,
                   color_disponible, cliente_objetivo
                   = 7 atributos propios + 8 referenciados = 15 atributos
```

**Cada cual define lo que necesita. Sin conflicto. Sin esquema compartido.**

### 2.3 Relacionar entidades sin que los dueños se conozcan (N-to-N)

```
Farol DEPO → compatible con 4 sistemas de Toyota + 2 de Nissan + 1 de Honda
Farol BOSCH → compatible con 2 sistemas de Toyota (compite con DEPO)

Mantequilla María → distribuida por Frila X, Frila Y, Frila Z
Chocolate Juan → custodiado en Punto Norte, Punto Centro

Toyota NO sabe que DEPO y BOSCH fabrican para sus sistemas.
DEPO NO sabe que BOSCH también fabrica.
La Tiendita NO sabe quién más vende faroles.
```

**N-to-N resuelto con múltiples filas en `idn_atributo`. Si es 1, será 1. Si crece, solo se agregan filas.**

### 2.4 Controlar quién ve qué (visibilidad + BitMask)

```
Privacidad:
  Tiendita usa códigos de Toyota → visibilidad PRIVADA
  Toyota NO sabe que la Tiendita existe

  Tiendita quiere ser recomendada → cambia a COMPARTIDA
  Toyota ve: "Tiendita Barrio vende faroles para Carina 92"

Gobernanza:
  CI de Juan Pérez → atom_code = 5826
  Vendedor consulta: UserBitMask[5826]? → 0 → "****567 LP" (enmascarado)
  Gerente RRHH consulta: UserBitMask[5826]? → 1 → "1234567 LP" (completo)
```

### 2.5 Trazabilidad completa — auditoría de quién usa qué

```
¿Quién está usando los códigos de Toyota?
  → DEPO (visibilidad COMPARTIDA): farol 212-1112-L
  → BOSCH (visibilidad COMPARTIDA): farol B-9876-L
  → Tiendita (visibilidad COMPARTIDA): vende faroles en ANDINA

¿Quién está usando los códigos de DEPO?
  → Tiendita (visibilidad PRIVADA): no aparece si DEPO consulta
  → Solo la Tiendita sabe que usa códigos de DEPO

¿Cuánto debe pagar la Tiendita a Toyota por usar sus códigos?
  → value_data.porcentaje: 5%
  → Auditoría: 3 faroles vendidos × $85 × 5% = $12.75 para Toyota
```

### 2.6 Aislar tenants — cada uno en su corral

```
t-toyota:    ve sus modelos, sus sistemas. No ve a DEPO. No ve a la Tiendita.
t-depo:      ve sus partes. No ve a BOSCH. No ve a la Tiendita (si es PRIVADA).
t-bosch:     ve sus partes. No ve a DEPO.
t-tiendita:  ve su inventario. Sabe qué códigos usa de quién.
             Pero los dueños no saben que ella existe (PRIVADA).

ctx_id en cada request → WHERE tenant_id = $ctx_tenant
```

### 2.7 Escalar de 1 a N sin cambiar nada

```
1 persona con 3 atributos       → funciona
1 empresa con 500 empleados     → funciona
1 catálogo con 50,000 partes    → funciona
1 marketplace con 1,000 tiendas → funciona

El mismo código. Las mismas tablas. Solo crece el número de filas.
```

---

## 3. Lo que el sistema NO es

| NO es | Es |
|---|---|
| Un ERP | Un catálogo universal que los ERPs pueden consultar |
| Un CRM | Un registro de entidades que el CRM puede usar |
| Un inventario | Una base de datos de productos que el inventario referencia |
| Una base de datos SQL tradicional | Un EAV gobernado por políticas AtomLang y BitMask |
| Una tabla con columnas fijas | Dos tablas con esquema flexible y sin ALTER TABLE |
| Un sistema aislado | Un sistema multi-tenant con ctx_id en cada request |

---

## 4. Los 37 dominios de identidad documentados

| Tipo de ente | Dominios disponibles | Total |
|---|---|---|
| PERSONA | civil, familiar, educativo, laboral, autenticacion, cliente, proveedor, productor, independiente, propietario, inquilino, paciente, fiscal, financiero, viajero, asegurado | 16 |
| ORGANIZACION | civil, cliente, proveedor, productor, empleador, fiscal, propietario, inquilino, importador, exportador, franquiciado, franquiciante, financiero | 13 |
| COSAS | origen, comercial, propiedad, alquilado, operativo, asegurado, siniestrado, desactivado | 8 |

Cada dominio es una capa de atributos que se agrega y se quita durante el ciclo de vida.
La historia se preserva. Nada se borra.

---

## 5. Resumen: lo que hace único a este sistema

1. **Catálogo universal** — cualquier cosa jerárquica con atributos. Sin DDL.
2. **Flexibilidad por registro** — un farol puede tener 2 atributos, otro 100. Sin esquema fijo.
3. **N-to-N nativo** — múltiples filas en EAV. Sin tablas pivote. Sin JOINs extra.
4. **Multi-tenant real** — cada tenant en su corral. ctx_id en cada request.
5. **Visibilidad controlada** — PRIVADA por defecto. Nadie sabe que existes.
6. **Gobernanza BitMask** — quién ve/edita cada atributo. Enmascaramiento PII.
7. **Trazabilidad** — quién referencia qué. Auditoría de uso de códigos.
8. **Motor de validación** — mismo lenguaje AtomLang para datos y para acceso.
9. **Historial preservado** — atributos de capa no se borran, se archivan.
10. **Dos tablas** — `idn_entidad` + `idn_atributo`. Eso es todo.
