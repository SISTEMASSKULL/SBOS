# MEMORIA-SESION-RETOMA — Punto de Retorno

**Sesión:** 2026-06-22 · **Hora:** 09:30 CEST  
**Proyecto:** bAuth (SBOS Identity Core v3.0) · **Daemon:** bauth.service  

---

## 1. Cómo retomar en 30 segundos

```bash
# 1. Leer la especificación profesional (acabada de actualizar)
cat context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-B10-ESPECIFICACION-CRUD-PROFESIONAL.md

# 2. Verificar conectividad VPS
sshpass -p '12345678ubuntu' ssh root@13.140.128.230 "echo OK"

# 3. Ver BD
sshpass -p '12345678ubuntu' ssh root@13.140.128.230 "KUBECONFIG=/etc/bos/.kube/config kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db -c 'SELECT count(*) FROM bos_privilege.bos_atom_catalog;'"
```

---

## 2. LO ÚLTIMO — Auditoría BD + Especificación CRUD Profesional v4.0.0

### Hallazgos de auditoría en VPS:

| Hallazgo | Severidad | Acción requerida |
|----------|-----------|-----------------|
| `bauth.bos_verbo` tabla huérfana (0 registros) | 🟡 MEDIA | DROP TABLE — la activa es `bos_privilege.bos_verb` |
| `rol_closure` sin FK a `bos_rol_template` | 🔴 ALTA | Agregar 2 FKs |
| `bos_rol_template.parent_id` sin FK | 🟡 MEDIA | Agregar FK |
| `bos_rol_template` tiene 0 registros | — | A poblar con 66 plantillas |
| Estructura real: 12 columnas (no 47) | — | Diseño simplificado con JSONB `plantilla_json` |
| 88 tablas totales en BD | — | Sin duplicados de políticas detectados |

### Documento creado:

**`BAUTH-B10-ESPECIFICACION-CRUD-PROFESIONAL.md` v4.0.0** — 13 secciones:
- §1: Auditoría de BD real (tablas, constraints, integridad, duplicados)
- §2: Esquema JSONB de 14 bloques en `plantilla_json`
- §3: Componente UI de árbol jerárquico (React + react-arborist)
- §4: Catálogo CRUD de 9 tablas con 54 handlers
- §5: 9 handlers JSON-RPC para RolTemplate (contratos completos)
- §6: Motor de 30 validaciones (8 estructurales + 12 negocio + 7 clonación + 3 update)
- §7: Modelo de clonación con reglas multi-tenant
- §8: Sincronización bAuth → KC + Tryton (saga con compensación)
- §9: Plan 8 fases (~62 horas)
- §10: Estructura de archivos
- §11: Correcciones SQL inmediatas (Fase 0)

### Plan de 8 Fases:

| Fase | Qué | Horas |
|------|-----|-------|
| **F0** | 🔴 Correcciones integridad (FKs + DROP huérfana) | 2h |
| F1 | CRUD tablas base (verb, app, group, atom, policy) | 10h |
| F2 | Roles base + role_atom + closure | 8h |
| F3 | RolTemplate core (create/read/update/clone/validate/approve) | 12h |
| F4 | RolTemplate consultas (revoke/list/tree) | 4h |
| F5 | Seed 66 plantillas base | 8h |
| F6 | Sincronización KC + Tryton | 16h |
| F7 | Encriptación + Vault + UI Árbol | 10h |
| F8 | Tests regresión | 4h |

---

## 3. VPS

```
IP:      13.140.128.230
Acceso:  sshpass -p '12345678ubuntu' ssh root@13.140.128.230
K8s:     KUBECONFIG=/etc/bos/.kube/config
PostgreSQL: kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db
```

---

## 4. Primer comando al retomar

```bash
# FASE 0: Ejecutar correcciones de integridad en VPS
sshpass -p '12345678ubuntu' ssh root@13.140.128.230 "KUBECONFIG=/etc/bos/.kube/config kubectl exec -n sbos-data postgresql-0 -- psql -U postgres -d bauth_db" << 'SQL'
ALTER TABLE bauth.rol_closure ADD CONSTRAINT fk_closure_ancestro FOREIGN KEY (ancestro_id) REFERENCES bauth.bos_rol_template(id) ON DELETE CASCADE;
ALTER TABLE bauth.rol_closure ADD CONSTRAINT fk_closure_descendiente FOREIGN KEY (descendiente_id) REFERENCES bauth.bos_rol_template(id) ON DELETE CASCADE;
ALTER TABLE bauth.bos_rol_template ADD CONSTRAINT fk_rt_parent FOREIGN KEY (parent_id) REFERENCES bauth.bos_rol_template(id) ON DELETE SET NULL;
DROP TABLE IF EXISTS bauth.bos_verbo;
SQL

# FASE 1: Crear src/server/handlers/foundation_crud.rs
# con los 21 handlers de tablas base
```

---

*Fin de sesión 2026-06-22 09:30. Documento v4.0.0 listo para implementación.*
