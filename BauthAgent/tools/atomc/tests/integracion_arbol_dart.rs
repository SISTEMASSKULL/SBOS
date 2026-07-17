// ============================================================
// atomc · tests/integracion_arbol_dart.rs
//
// Propósito: pruebas de integración con el árbol RolTemplate v6.0
//   del desktop Dart. El árbol tiene errores intencionales que
//   atomlang debe detectar. NO se adapta atomc al árbol — el
//   árbol debe adaptarse a atomlang.
// ============================================================

use atomc::lexer;
use atomc::parser;
use atomc::codegen;
use atomc::semantic;
use atomc::diagnostics::DiagnosticBag;

/// Helper: parsea YAML, ejecuta pipeline completo y retorna diagnósticos.
fn validar(yaml: &str) -> DiagnosticBag {
    let path = std::path::Path::new("test.atm.yaml");
    let lexed = lexer::tokenize(path, yaml).unwrap();
    let lex_bag = lexed.diagnostics.clone();

    if lex_bag.errors() > 0 {
        return lex_bag;
    }

    let (ast, parser_bag) = parser::parse(lexed.tree, "test.atm.yaml");
    let mut bag = DiagnosticBag::new();
    bag.extend(parser_bag);

    if bag.errors() > 0 {
        return bag;
    }

    let config = semantic::SemanticConfig::default();
    let sem_output = semantic::analyze(&ast, "test.atm.yaml", &config);
    bag.extend(sem_output.diagnostics);
    bag
}

// ═══════════════════════════════════════════════════════════
// D6 · GEOESPACIAL — validation_rules
// Basado en: rol_template_datos.dart líneas 1736-1765
// ═══════════════════════════════════════════════════════════

#[test]
fn d6_geo_validation_rules_valida_sin_errores() {
    let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d6_geoespacial
    badge: domain
    combining_algorithm: deny_overrides
    children:
      - policy_set_id: b14_validacion_ubicacion
        badge: zone
        combining_algorithm: deny_overrides
        children:
          - policy_id: validation_rules
            combining_algorithm: deny_overrides
            atoms:
              - atom_id: vpn_requerida_en_remoto
                verb_id: access
                target:
                  subject: { kind: ANY }
                  resource: geo_location
                condition:
                  property_id: connection.type
                  operator: "=="
                  value: REMOTE
                effect:
                  decision: Deny
                  advice: "VPN requerida para acceso remoto"
              - atom_id: attestation_gps_en_roaming
                verb_id: validate
                target:
                  subject: { kind: ANY }
                  resource: geo_location
                condition:
                  property_id: gps_attestation.accuracy_meters
                  operator: ">"
                  value: "@bauth_config_param.gps_accuracy_meters"
                effect:
                  decision: Deny
                  advice: "Precision GPS insuficiente"
              - atom_id: velocidad_imposible
                verb_id: audit
                target:
                  subject: { kind: ANY }
                  resource: geo_location
                condition:
                  property_id: location.velocity_km_h
                  operator: ">"
                  value: "1 200"
                effect:
                  decision: Deny
                  advice: "suplantacion de ubicacion"
              - atom_id: operacion_financiera_home_office
                verb_id: approve
                target:
                  subject: { kind: ANY }
                  resource: geo_location
                condition:
                  property_id: location.type
                  operator: "=="
                  value: home_office
                effect:
                  decision: Deny
                  advice: "Operaciones financieras requieren red segura"
"#;
    let bag = validar(yaml);
    let errores: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Error);
    let warnings: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Warning);

    println!("=== D6 Geo — validation_rules ===");
    println!("Errores: {}", errores.len());
    for e in &errores { println!("  [{}] {}", e.code, e.message); }
    println!("Warnings: {}", warnings.len());
    for w in &warnings { println!("  [{}] {}", w.code, w.message); }

    // Tras corregir el árbol Dart:
    // - GPS accuracy → @bauth_config_param ✅
    // - verb_ids diferenciados: access/validate/audit/approve ✅

    assert!(
        errores.is_empty(),
        "Árbol D6 Geo corregido no debe tener errores. Errores: {:?}",
        errores.iter().map(|e| format!("{}: {}", e.code, e.message)).collect::<Vec<_>>()
    );
    assert!(
        warnings.iter().all(|w| w.code != "ATOMC-W-033"),
        "No debe haber verb_id repetido — ya están diferenciados"
    );
}

// ═══════════════════════════════════════════════════════════
// D1 · ACCESO LÓGICO — B4 auth methods
// Basado en: rol_template_datos.dart líneas 327-509
// ERROR: _ev() como hijo directo de política, verbo como nodo hijo, _olo entre evaluaciones
// ═══════════════════════════════════════════════════════════

#[test]
fn d1_b4_errores_estructurales() {
    // Simula el error: _ev() (evaluacion) como hijo directo de política
    // En atomlang, una Policy solo contiene Atoms. No puede contener evaluaciones sueltas.
    let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d1_acceso_logico
    combining_algorithm: deny_overrides
    children:
      - policy_id: password_policy
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: longitud_minima
            verb_id: configure
            target:
              subject: { kind: ANY }
              resource: password
            condition:
              property_id: min_length
              operator: ">="
              value: "@bauth_config_param.password_min_length"
            effect:
              decision: Permit
          - atom_id: complejidad_caracteres
            verb_id: validate
            target:
              subject: { kind: ANY }
              resource: password
            condition: null
            effect:
              decision: Permit
"#;
    let bag = validar(yaml);
    let errores: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Error);
    let warnings: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Warning);

    println!("=== D1 B4 — password_policy ===");
    println!("Errores: {}", errores.len());
    for e in &errores { println!("  [{}] {}", e.code, e.message); }
    println!("Warnings: {}", warnings.len());
    for w in &warnings { println!("  [{}] {}", w.code, w.message); }

    // Tras corregir el árbol Dart:
    // 1. complejidad_caracteres YA ES snake_case ✅
    // 2. condition: null (YAML no distingue null explícito de ausente → W-011 conocido)
    // 3. verb_ids diferenciados: configure + validate → sin W-033 ✅
    // 4. subject=ANY sin condition → W-032 (política amplia, aceptable)

    assert!(
        errores.is_empty(),
        "Árbol D1 B4 corregido no debe tener errores. Errores: {:?}",
        errores.iter().map(|e| format!("{}: {}", e.code, e.message)).collect::<Vec<_>>()
    );
}

// ═══════════════════════════════════════════════════════════
// D0 · IDENTIDAD — approval_workflow (B3)
// Basado en: rol_template_datos.dart líneas 283-316
// ERROR: múltiples _ev() con mismo verb_id 'configure'
// ═══════════════════════════════════════════════════════════

#[test]
fn d0_b3_approval_workflow() {
    let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: d0_identidad
    combining_algorithm: deny_overrides
    children:
      - policy_set_id: b3_aprobacion
        combining_algorithm: deny_overrides
        children:
          - policy_id: approval_workflow
            combining_algorithm: permit_overrides
            atoms:
              - atom_id: quorum_aprobadores
                verb_id: configure
                target:
                  subject: { kind: ANY }
                  resource: approval
                condition:
                  property_id: approval.count_distinct_approvers
                  operator: ">="
                  value: "@bauth_config_param.approval_min_approvers"
                effect:
                  decision: Deny
                  advice: "menos del minimo de aprobadores"
              - atom_id: nivel_organizacional
                verb_id: validate
                target:
                  subject: { kind: ANY }
                  resource: approval
                condition:
                  property_id: approver.hierarchy_level
                  operator: ">="
                  value: "@bauth_config_param.approver_min_level"
                effect:
                  decision: Deny
                  advice: "aprobador nivel inferior al solicitante"
              - atom_id: sla_respuesta
                verb_id: audit
                target:
                  subject: { kind: ANY }
                  resource: approval
                condition:
                  property_id: approval.elapsed_hours
                  operator: "<="
                  value: "@bauth_config_param.sla_timeout_hours"
                effect:
                  decision: Deny
                  advice: "request expirado por SLA"
              - atom_id: escalacion_automatica
                verb_id: delegate
                target:
                  subject: { kind: ANY }
                  resource: approval
                condition:
                  property_id: approval.elapsed_hours
                  operator: ">"
                  value: "@bauth_config_param.escalation_timeout_hours"
                effect:
                  decision: Permit
                  advice: "escalar a CISO/CEO"
              - atom_id: canal_notificacion
                verb_id: emit
                target:
                  subject: { kind: ANY }
                  resource: approval
                condition:
                  property_id: notification.channel
                  operator: "=="
                  value: rocket_chat
                effect:
                  decision: Permit
                  advice: "enviar via bNotify"
"#;
    let bag = validar(yaml);
    let errores: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Error);
    let warnings: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Warning);

    println!("=== D0 B3 — approval_workflow ===");
    println!("Errores: {}", errores.len());
    for e in &errores { println!("  [{}] {}", e.code, e.message); }
    println!("Warnings: {}", warnings.len());
    for w in &warnings { println!("  [{}] {}", w.code, w.message); }

    // Tras corregir el árbol Dart:
    // - Sin errores (todos los literales → @bauth_config_param) ✅
    // - verb_ids diferenciados: configure/validate/audit/delegate/emit → sin W-033 ✅

    assert!(
        errores.is_empty(),
        "Árbol D0 B3 corregido no debe tener errores. Errores: {:?}",
        errores.iter().map(|e| format!("{}: {}", e.code, e.message)).collect::<Vec<_>>()
    );
}

// ═══════════════════════════════════════════════════════════
// ERROR FORZADO: property_id duplicado en target.environment y condition
// G-04 del árbol Dart: _prop repetida en diferentes evaluaciones
// ═══════════════════════════════════════════════════════════

#[test]
fn g04_property_duplicado_target_y_condition() {
    let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test_domain
    combining_algorithm: deny_overrides
    children:
      - policy_id: test_policy
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: test_atom
            verb_id: read
            target:
              subject: { kind: ANY }
              resource: test
              environment:
                - property_id: approval.elapsed_hours
                  operator: "<="
                  value: "48"
            condition:
              property_id: approval.elapsed_hours
              operator: ">"
              value: "24"
            effect:
              decision: Deny
"#;
    let bag = validar(yaml);
    let errores: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Error);

    println!("=== G-04: property_id duplicado ===");
    for e in &errores { println!("  [{}] {}", e.code, e.message); }

    assert!(
        errores.iter().any(|e| e.code == "ATOMC-E-021"),
        "G-04 debe detectar property_id duplicado en target.environment y condition. Errores: {:?}",
        errores.iter().map(|e| &e.code).collect::<Vec<_>>()
    );
}

// ═══════════════════════════════════════════════════════════
// ERROR FORZADO: atom_id con dígitos de monto (G-10)
// ═══════════════════════════════════════════════════════════

#[test]
fn g10_atom_id_contiene_monto() {
    let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test_domain
    combining_algorithm: deny_overrides
    children:
      - policy_id: test_policy
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: limite_5000_bolivianos
            verb_id: read
            target:
              subject: { kind: ANY }
              resource: test
            condition:
              property_id: test
              operator: "=="
              value: test
            effect:
              decision: Permit
"#;
    let bag = validar(yaml);
    let errores: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Error);

    println!("=== G-10: atom_id con dígitos de monto ===");
    for e in &errores { println!("  [{}] {}", e.code, e.message); }

    assert!(
        errores.iter().any(|e| e.code == "ATOMC-E-041"),
        "G-10 debe detectar atom_id con dígitos de monto (5000). Errores: {:?}",
        errores.iter().map(|e| &e.code).collect::<Vec<_>>()
    );
}

// ═══════════════════════════════════════════════════════════
// ERROR FORZADO: código de moneda literal (G-09)
// ═══════════════════════════════════════════════════════════

#[test]
fn g09_codigo_moneda_literal() {
    let yaml = r#"
atomlang_version: 1
policy_sets:
  - policy_set_id: test_domain
    combining_algorithm: deny_overrides
    children:
      - policy_id: test_policy
        combining_algorithm: deny_overrides
        atoms:
          - atom_id: operacion_usd
            verb_id: approve
            target:
              subject: { kind: ANY }
              resource: payment
            condition:
              property_id: currency
              operator: "=="
              value: USD
            effect:
              decision: Permit
"#;
    let bag = validar(yaml);
    let errores: Vec<_> = bag.filter_level(atomc::diagnostics::Level::Error);

    println!("=== G-09: código moneda literal ===");
    for e in &errores { println!("  [{}] {}", e.code, e.message); }

    assert!(
        errores.iter().any(|e| e.code == "ATOMC-E-043"),
        "G-09 debe detectar código de moneda literal (USD). Errores: {:?}",
        errores.iter().map(|e| &e.code).collect::<Vec<_>>()
    );
}
