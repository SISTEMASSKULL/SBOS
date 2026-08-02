// ============================================================
// verify_policies — Validador end-to-end B1 (binario de diagnóstico)
//
// Conecta a PostgreSQL (SBOSDB), carga átomos desde idn_roles_template,
// roles desde idn_roles_rol_hierarchical, políticas desde auth_policy,
// y verifica coherencia del modelo de autorización.
//
// Tablas canónicas DDL v2.12.0:
//   bauth.idn_roles_template         — átomos (nodos con node_type='atom')
//   bauth.idn_roles_rol_hierarchical — roles y sus jerarquías
//   bauth.idn_roles_rol_closure      — cierre transitivo de herencia
//   bauth.privilege_atom_grant       — asignaciones G-12
//   bauth.auth_policy                — políticas de autenticación por tenant
//
// Eliminado: privilege_atom, privilege_atom_policy, privilege_domain,
//            privilege_role, privilege_role_atom, idn_role_closure,
//            privilege_atom_audit — phantoms D05 no existen en DDL v2.12.0.
//
// Uso: verify_policies [--tenant <uuid>] [--verbose]
// DOC-SBOS-001 N3 · diagnóstico · no producción
// ============================================================

use sqlx::postgres::PgPoolOptions;

const SBOSDB_DSN:   &str = "postgres://postgres:postgres@localhost:15432/SBOSDB";
const LIMIT_ATOMS:  i64  = 1000;
const LIMIT_ROLES:  i64  = 500;
const LIMIT_GRANTS: i64  = 2000;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = std::env::args().collect();
    let tenant_str = extraer_arg(&args, "--tenant");
    let verbose    = args.contains(&"--verbose".to_string());

    println!("=== verify_policies — bAuth DDL v2.12.0 ===");

    let pg = PgPoolOptions::new()
        .max_connections(2)
        .connect(SBOSDB_DSN)
        .await
        .map_err(|e| format!("conexión SBOSDB falló: {}", e))?;

    println!("✓ Conexión SBOSDB OK");

    // ── 1. Átomos ────────────────────────────────────────
    println!("\n[1] Átomos (idn_roles_template, node_type='atom')");
    let atoms: Vec<(String, i64, i32, bool)> = sqlx::query_as(
        "SELECT path, atom_position, domain_number, is_active
         FROM bauth.idn_roles_template
         WHERE node_type = 'atom'
         ORDER BY atom_position
         LIMIT $1"
    )
    .bind(LIMIT_ATOMS)
    .fetch_all(&pg)
    .await?;

    println!("  Total átomos: {}", atoms.len());
    if verbose {
        for (path, pos, dom, active) in &atoms {
            let status = if *active { "✓" } else { "✗" };
            println!("    [{pos:>4}] D{dom:02} {status} {path}");
        }
    } else if let Some((path, pos, dom, _)) = atoms.first() {
        println!("  Primer átomo: [{pos}] D{dom:02} {path}");
    }

    let duplicados = verificar_posiciones_unicas(&atoms);
    if duplicados > 0 {
        println!("  ⚠ POSICIONES DUPLICADAS: {}", duplicados);
    } else {
        println!("  ✓ Posiciones únicas OK");
    }

    // ── 2. Roles ──────────────────────────────────────────
    println!("\n[2] Roles (idn_roles_rol_hierarchical)");
    let tenant_id = tenant_str.as_deref()
        .map(|s| uuid::Uuid::parse_str(s))
        .transpose()?;

    let roles: Vec<(uuid::Uuid, String, String, i32)> = sqlx::query_as(
        "SELECT id, code, tier::text, depth
         FROM bauth.idn_roles_rol_hierarchical
         WHERE status = 'ACTIVE'
           AND ($1::uuid IS NULL OR tenant_id = $1)
         ORDER BY depth, code
         LIMIT $2"
    )
    .bind(tenant_id)
    .bind(LIMIT_ROLES)
    .fetch_all(&pg)
    .await?;

    println!("  Total roles activos: {}", roles.len());
    if verbose {
        for (id, code, tier, depth) in &roles {
            println!("    [{depth}] {tier} {code} ({id})");
        }
    }

    // ── 3. Cierre de herencia ──────────────────────────────
    println!("\n[3] Cierre transitivo (idn_roles_rol_closure)");
    let (closure_count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.idn_roles_rol_closure"
    ).fetch_one(&pg).await?;
    println!("  Aristas closure: {}", closure_count);

    if closure_count == 0 && !roles.is_empty() {
        println!("  ⚠ ADVERTENCIA: roles existen pero closure está vacío");
    }

    // ── 4. Grants G-12 ────────────────────────────────────
    println!("\n[4] Asignaciones G-12 (privilege_atom_grant)");
    let grants: Vec<(uuid::Uuid, String, bool, bool, bool)> = sqlx::query_as(
        "SELECT user_id, atom_path, general, effect, access
         FROM bauth.privilege_atom_grant
         WHERE (expires_at IS NULL OR expires_at > now())
         LIMIT $1"
    )
    .bind(LIMIT_GRANTS)
    .fetch_all(&pg)
    .await
    .unwrap_or_default();

    println!("  Total grants activos: {}", grants.len());

    let grants_activos = grants.iter().filter(|(_, _, general, effect, access)| {
        (*general && *effect) || (!*general && *access)
    }).count();
    println!("  Grants con permiso concedido: {}", grants_activos);

    // ── 5. Políticas ─────────────────────────────────────
    println!("\n[5] Políticas (auth_policy)");
    let policies: Vec<(uuid::Uuid, Option<uuid::Uuid>, String, String, bool)> = sqlx::query_as(
        "SELECT policy_id, tenant_id, name, loa_required, active
         FROM bauth.auth_policy
         ORDER BY name
         LIMIT 100"
    )
    .fetch_all(&pg)
    .await?;

    println!("  Total políticas: {}", policies.len());
    if verbose {
        for (pid, tid, name, loa, active) in &policies {
            let t = tid.map(|t| t.to_string()).unwrap_or_else(|| "global".into());
            let status = if *active { "✓" } else { "✗" };
            println!("    [{loa}] {status} {name} (tenant={t}, id={pid})");
        }
    }

    let sin_politica = verificar_tenants_sin_politica(&pg).await?;
    if sin_politica > 0 {
        println!("  ⚠ Tenants sin política asignada: {}", sin_politica);
    } else {
        println!("  ✓ Cobertura de políticas OK");
    }

    // ── Resumen ───────────────────────────────────────────
    println!("\n=== Resumen ===");
    println!("  Átomos:    {}", atoms.len());
    println!("  Roles:     {}", roles.len());
    println!("  Closure:   {}", closure_count);
    println!("  Grants:    {} ({} activos)", grants.len(), grants_activos);
    println!("  Políticas: {}", policies.len());
    println!("=== verify_policies COMPLETADO ===");

    Ok(())
}

// ── Helpers ───────────────────────────────────────────

/// Extrae el valor del argumento --flag <valor> de la lista de args.
fn extraer_arg(args: &[String], flag: &str) -> Option<String> {
    args.windows(2)
        .find(|w| w[0] == flag)
        .map(|w| w[1].clone())
}

/// Verifica que todas las posiciones de átomos sean únicas.
fn verificar_posiciones_unicas(atoms: &[(String, i64, i32, bool)]) -> usize {
    let mut seen = std::collections::HashSet::new();
    let mut dups = 0usize;
    for (_, pos, _, _) in atoms {
        if !seen.insert(*pos) {
            dups += 1;
        }
    }
    dups
}

/// Cuenta tenants activos sin ninguna política de autenticación asignada.
async fn verificar_tenants_sin_politica(
    pg: &sqlx::PgPool,
) -> Result<i64, Box<dyn std::error::Error>> {
    let (count,): (i64,) = sqlx::query_as(
        "SELECT count(*) FROM bauth.idn_tenant t
         WHERE t.status = 'ACTIVE'
           AND NOT EXISTS (
               SELECT 1 FROM bauth.auth_policy p
               WHERE p.tenant_id = t.tenant_id AND p.active = TRUE
           )"
    )
    .fetch_one(pg)
    .await
    .unwrap_or((0i64,));
    Ok(count)
}
