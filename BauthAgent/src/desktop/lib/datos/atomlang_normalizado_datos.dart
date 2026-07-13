// ============================================================
// bauth_desktop · datos/atomlang_normalizado_datos.dart
//
// Propósito: árbol SOURCE traducido al lenguaje AtomLang v1.
//   Misma estructura que arbolRolTemplate pero con identificadores
//   canónicos snake_case, verbo como enum de bos_verb, condiciones
//   tipadas (propiedad FK · operador cerrado · valor tipado) y
//   combining_algorithm explícito. Es la salida del autómata de
//   control de calidad — lo que el árbol DEBERÍA ser en AtomLang.
//   D1 completo. D2..D12 marcados como pendientes de normalización.
// Dependencias: datos/rol_template_datos (NodoTemplate + TipoNodo).
// Estándar: AtomLang-especificacion-completa.md § EBNF + Gap Analysis D1.
// ============================================================

import 'rol_template_datos.dart';

// ──── atajos ─────────────────────────────────────────────────

NodoTemplate _a(String c, String v, {String? help}) =>
    NodoTemplate(c, TipoNodo.atributo, valor: v, help: help);

NodoTemplate _en(String c, String v, List<String> ops, {String? help}) =>
    NodoTemplate(c, TipoNodo.enumerado, valor: v, opciones: ops, help: help);

NodoTemplate _obj(String c, {String? help, List<NodoTemplate> hijos = const []}) =>
    NodoTemplate(c, TipoNodo.objeto, help: help, hijos: hijos);

NodoTemplate _pol(String c, {String? help, List<NodoTemplate> hijos = const []}) =>
    NodoTemplate(c, TipoNodo.politica, help: help, hijos: hijos);

NodoTemplate _bloque(String c, {String? help, List<NodoTemplate> hijos = const []}) =>
    NodoTemplate(c, TipoNodo.bloque, help: help, hijos: hijos);

/// Átomo normalizado: atom_id canónico + verbo + target + condition + effect.
NodoTemplate _atom(
  String atomId,
  String verbo, {
  required List<NodoTemplate> target,
  required List<NodoTemplate> condition,
  required List<NodoTemplate> effect,
  String? help,
}) =>
    NodoTemplate(atomId, TipoNodo.evaluacion, help: help, hijos: [
      _en('verbo', verbo,
          const ['read', 'write', 'create', 'delete', 'approve', 'execute',
            'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
          help: 'Action XACML. FK a bos_verb.verb_id. snake_case obligatorio.'),
      _obj('target', help: 'Target-gate XACML — evaluado ANTES que condition.', hijos: target),
      _obj('condition', help: 'Predicado tipado. null = siempre True.', hijos: condition),
      _obj('effect', help: 'Resultado + obligations tipadas para el PEP.', hijos: effect),
    ]);

/// condition: null explícito (átomo sin predicado adicional).
const List<NodoTemplate> _condNull = [
  NodoTemplate('condition', TipoNodo.atributo, valor: 'null',
      help: 'Sin condición adicional — el Target-gate es el único criterio.\n'
          'Declarar null explícitamente (ATOMC-E-022 si se omite).'),
];

/// Target estándar: ANY · recurso dado.
List<NodoTemplate> _targetAny(String resource) => [
  _en('subject', 'ANY', const ['ANY', 'ROL(id)', 'SET(id)'],
      help: 'El átomo aplica a cualquier sujeto autenticado.'),
  _a('resource', resource, help: 'FK a bos_resource_catalog.'),
];

/// Condición simple: propiedad + operador + valor.
List<NodoTemplate> _cond(String prop, String op, String val) => [
  _a('propiedad', prop, help: 'FK a bos_attribute_catalog.'),
  _en('operador', op, const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
  _a('valor', val, help: 'Tipado según data_type del atributo en catálogo.'),
];

/// Efecto Permit con obligations tipadas.
List<NodoTemplate> _permit(Map<String, String> obligations) => [
  _en('decision', 'Permit', const ['Permit', 'Deny']),
  _obj('obligation', hijos: obligations.entries
      .map((e) => _a(e.key, e.value))
      .toList()),
];

/// Efecto Deny con obligations tipadas.
List<NodoTemplate> _deny(Map<String, String> obligations) => [
  _en('decision', 'Deny', const ['Permit', 'Deny']),
  _obj('obligation', hijos: obligations.entries
      .map((e) => _a(e.key, e.value))
      .toList()),
];

/// combining_algorithm enum.
NodoTemplate _algo(String v) => _en(
    'combining_algorithm', v,
    const ['deny-overrides', 'permit-overrides', 'first-applicable',
      'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
    help: 'Algoritmo de combinación. OBLIGATORIO en Policy con 2+ átomos (ATOMC-E-020).');

/// Nodo HITL — requiere decisión humana antes de normalizar.
NodoTemplate _hitl(String atomId, String razon) =>
    NodoTemplate('⚠ $atomId', TipoNodo.atributo,
        valor: 'HITL',
        help: 'Este átomo no puede normalizarse automáticamente.\n\n'
            'Razón: $razon\n\n'
            'Acción requerida: consultar con el humano antes de continuar.\n'
            'Clasificación gap: SIN_EQUIVALENTE (ATOMLANG-GAP-ANALYSIS-D1 §2).');

/// Dominio pendiente de normalización.
NodoTemplate _pendiente(String dominio) =>
    NodoTemplate(dominio, TipoNodo.bloque,
        help: 'Normalización pendiente — aplicar autómata AtomLang cuando se '
            'complete el análisis de gaps de este dominio.',
        hijos: [
          _a('estado', 'PENDIENTE',
              help: 'Aplicar el mismo proceso que D1: identificar gaps, mapear '
                  'nombres humanos a IDs canónicos, tipar condiciones.'),
        ]);

// ──── ÁRBOL NORMALIZADO ───────────────────────────────────────

/// Árbol SOURCE traducido al lenguaje AtomLang v1.
/// D1 completamente normalizado. D2..D12 pendientes.
final List<NodoTemplate> arbolNormalizado = [
  _d1(),
  _pendiente('d2_acceso_fisico'),
  _pendiente('d3_red_perimetral'),
  _pendiente('d4_criptografia_pki'),
  _pendiente('d5_auditoria_logs'),
  _pendiente('d6_gestion_identidad_ciclo_vida'),
  _pendiente('d7_federacion_sso'),
  _pendiente('d8_riesgo_confianza'),
  _pendiente('d9_m2m_apis'),
  _pendiente('d10_blockchain_adsib'),
  _pendiente('d11_multitenant'),
  _pendiente('d12_compliance'),
  _pendiente('d98_registro_estructural'),
];

// ──── D1 · Acceso Lógico (normalizado) ──────────────────────

NodoTemplate _d1() => NodoTemplate(
  'd1_acceso_logico',
  TipoNodo.dominio,
  help: 'Dominio D1 · Acceso Lógico — normalizado a AtomLang v1.\n\n'
      'Badge: [POLICYSET]. Contiene bloques B4..B7 del RolTemplate v6.0.\n'
      'Todos los nombres de nodo son ahora snake_case canónicos.\n'
      'Condiciones tipadas — sin texto libre.\n'
      'combining_algorithm explícito en toda Policy con 2+ átomos.',
  hijos: [
    _b4(),
    _b5(),
    _b6(),
    _b7(),
  ],
);

// ──── B4 · Dominio lógico (autenticación) ────────────────────

NodoTemplate _b4() => _bloque(
  'b4_dominio_logico_autenticacion',
  help: 'Bloque B4 — Dominio lógico de autenticación. Badge: [POLICY].\n'
      'Contiene: primary_auth_policy · mfa_auth_policy · '
      'session_binding_policy · step_up_triggers.',
  hijos: [
    _primaryAuthPolicy(),
    _mfaAuthPolicy(),
    _sessionBindingPolicy(),
    _stepUpTriggersPolicy(),
  ],
);

NodoTemplate _primaryAuthPolicy() => _pol(
  'primary_auth_policy',
  help: 'Política de autenticación primaria.\n'
      'combining_algorithm: deny-unless-permit (fail-closed).\n'
      'Nombre SOURCE: "primary_auth{}" → ID canónico: primary_auth_policy.',
  hijos: [
    _algo('deny-unless-permit'),
    _atom('low_risk_password_grant', 'login',
        target: _targetAny('sesion'),
        condition: [
          _a('propiedad', 'risk_score',
              help: 'FK bos_attribute_catalog. SOURCE: "riesgo bajo".'),
          _en('operador', '<=', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
          _a('valor', '0.50'),
          NodoTemplate('op_lógico', TipoNodo.enumerado, valor: 'AND',
              opciones: const ['AND', 'OR', 'NOT']),
          _a('propiedad_2', 'zone_sensitivity',
              help: 'FK bos_attribute_catalog. SOURCE: "zona no sensible".'),
          _en('operador_2', 'NOT_IN', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
          _a('valor_2', '[HIGH, CRITICAL]'),
        ],
        effect: _permit({'required_loa': '1'}),
        help: 'SOURCE: "riesgo bajo + zona normal → contraseña"\n'
            'Gap resuelto: NOMBRE_DIFERENTE → low_risk_password_grant.'),
    _atom('sensitive_zone_hardware_grant', 'login',
        target: _targetAny('sesion'),
        condition: [
          _a('propiedad', 'zone_sensitivity',
              help: 'SOURCE: "zona sensible o acción privilegiada → hardware".'),
          _en('operador', 'IN', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
          _a('valor', '[HIGH, CRITICAL]'),
        ],
        effect: _permit({'required_loa': '2'}),
        help: 'Gap resuelto: NOMBRE_DIFERENTE → sensitive_zone_hardware_grant.'),
    _atom('mtls_cert_x509_grant', 'login',
        target: _targetAny('sesion'),
        condition: [
          _a('propiedad', 'auth_cert_present',
              help: 'SOURCE: "certificado mTLS presente → x509".'),
          _en('operador', '==', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
          _a('valor', 'true'),
        ],
        effect: _permit({'required_loa': '3', 'acr': 'aal3'}),
        help: 'Gap resuelto: NOMBRE_DIFERENTE → mtls_cert_x509_grant.'),
  ],
);

NodoTemplate _mfaAuthPolicy() => _pol(
  'mfa_auth_policy',
  help: 'Política MFA — métodos de segundo factor por nivel AAL.\n'
      'combining_algorithm: deny-unless-permit (fail-closed).\n'
      'SOURCE: "mfa_auth{}".',
  hijos: [
    _algo('deny-unless-permit'),
    _atom('aal2_totp_or_hotp', 'login',
        target: _targetAny('sesion'),
        condition: [
          _a('propiedad', 'auth_method'),
          _en('operador', 'IN', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
          _a('valor', '[TOTP, HOTP]'),
        ],
        effect: _permit({'required_loa': '2'}),
        help: 'SOURCE: "AAL2 con TOTP o HOTP".'),
    _pol('aal3_hardware_or_biometric',
        help: 'Sub-política AAL3: WebAuthn · FIDO2 · biométrico platform.\n'
            'combining_algorithm: permit-overrides (basta con un método AAL3).',
        hijos: [
          _algo('permit-overrides'),
          _atom('webauthn_passwordless_aal3', 'login',
              target: _targetAny('sesion'),
              condition: [
                _a('propiedad', 'auth_method'),
                _en('operador', '==', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
                _a('valor', 'WEBAUTHN_PASSWORDLESS'),
              ],
              effect: _permit({'required_loa': '3', 'acr': 'aal3'})),
          _atom('fido2_hardware_aal3', 'login',
              target: _targetAny('sesion'),
              condition: [
                _a('propiedad', 'auth_method'),
                _en('operador', '==', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
                _a('valor', 'FIDO2_HARDWARE'),
              ],
              effect: _permit({'required_loa': '3', 'acr': 'aal3'})),
          _atom('biometric_platform_aal3', 'login',
              target: _targetAny('sesion'),
              condition: [
                _a('propiedad', 'auth_method'),
                _en('operador', '==', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN']),
                _a('valor', 'BIOMETRIC_PLATFORM'),
              ],
              effect: _permit({'required_loa': '3', 'acr': 'aal3'})),
        ]),
  ],
);

NodoTemplate _sessionBindingPolicy() => _pol(
  'session_binding_policy',
  help: 'Política de binding de sesión.\n'
      'SOURCE: "session_binding{}" con required_binding.',
  hijos: [
    _algo('deny-unless-permit'),
    _obj('session_binding_config', hijos: [
      _en('bind_ip', 'strict', const ['strict', 'relaxed', 'none'],
          help: 'Binding por IP de cliente.'),
      _en('bind_ua', 'strict', const ['strict', 'relaxed', 'none'],
          help: 'Binding por User-Agent.'),
      _en('bind_geo', 'zone', const ['strict', 'zone', 'none'],
          help: 'Binding por zona geográfica.'),
      _a('geo_drift_tolerance_km', '50'),
      _en('session_bind_strength', 'high', const ['low', 'medium', 'high']),
    ]),
  ],
);

NodoTemplate _stepUpTriggersPolicy() => _pol(
  'step_up_triggers',
  help: 'Política de triggers de step-up de autenticación.\n\n'
      'combining_algorithm: aggregate-strictest (extensión bAuth).\n'
      'Todos los Permit concurrentes se fusionan: max(required_loa) · min(max_age_seconds).\n\n'
      'SOURCE: combining_algorithm era "first-applicable" — DEFECTO §2.1 #3 corregido.\n'
      'SSOT: RolTemplate v6.0 §step_up_rules.',
  hijos: [
    _algo('aggregate-strictest'),
    _atom('financial_approve', 'execute',
        target: _targetAny('transaccion'),
        condition: _cond('transaction_amount_bob', '>', '10000'),
        effect: _permit({'required_loa': '3', 'max_age_seconds': '300', 'acr': 'aal3'}),
        help: 'SOURCE: "monto de transacción alto (>10 000 BOB)"\n'
            'Gap resuelto: NOMBRE_DIFERENTE → financial_approve.\n'
            'SSOT: RolTemplate §step_up_rules[0].'),
    _hitl('zona_alta_seguridad',
        'El trigger "zona de alta seguridad" NO existe en el SSOT RolTemplate v6.0. '
        'Fue inventado por un agente anterior. '
        'Decisión pendiente: (a) añadir zone_security_critical al SSOT, '
        'o (b) eliminar este átomo. '
        'Ver ATOMLANG-GAP-ANALYSIS-D1 §2.'),
    _atom('system_config_change', 'configure',
        target: _targetAny('sistema_auth'),
        condition: _condNull,
        effect: _permit({'required_loa': '3', 'max_age_seconds': '0'}),
        help: 'SOURCE: "verbo CONFIGURE o ADMIN"\n'
            'Gap resuelto: NOMBRE_DIFERENTE → system_config_change.\n'
            'condition: null — el verbo "configure" en el Target-gate es '
            'el único criterio (defecto §2.1 #2 corregido: sin atributo duplicado).\n'
            'SSOT: RolTemplate §step_up_rules[1].'),
  ],
);

// ──── B5 · Ciclo de vida de credenciales ─────────────────────

NodoTemplate _b5() => _bloque(
  'b5_ciclo_vida_credenciales',
  help: 'Bloque B5 — Ciclo de vida de credenciales.\n'
      'NIST SP 800-63B Rev.4 · OWASP ASVS v5.0 §2.',
  hijos: [
    _pol('password_policy',
        help: 'Política de contraseñas NIST 800-63B-4.',
        hijos: [
          _a('pwd_min_length', '15',
              help: 'Mínimo 15 caracteres (NIST 800-63B-4 §5.1.1).'),
          _a('pwd_max_length', '128'),
          _a('pwd_require_entropy_bits', '40'),
          _en('pwd_screening', 'have_i_been_pwned',
              const ['have_i_been_pwned', 'internal_blocklist', 'both'],
              help: 'Screening contra listas de contraseñas comprometidas.'),
          _en('pwd_hash_algorithm', 'argon2id',
              const ['argon2id', 'bcrypt', 'scrypt'],
              help: 'Argon2id obligatorio (NIST 800-63B-4 §5.1.1.2).'),
        ]),
    _pol('account_lockout_policy',
        help: 'Política de bloqueo de cuenta por intentos fallidos.\n'
            'NIST 800-53 Rev.5 AC-7.',
        hijos: [
          _algo('first-applicable'),
          _atom('lockout_range_1_3', 'login',
              target: _targetAny('sesion'),
              condition: _cond('login_failed_attempts_in_window', 'BETWEEN', '[1, 3]'),
              effect: _permit({}),
              help: 'SOURCE: "intentos 1-3: sin penalización".'),
          _atom('lockout_range_4_6', 'login',
              target: _targetAny('sesion'),
              condition: _cond('login_failed_attempts_in_window', 'BETWEEN', '[4, 6]'),
              effect: _deny({'delay_seconds': 'progressive'}),
              help: 'SOURCE: "intentos 4-6: retardo progresivo".'),
          _atom('lockout_range_7_10', 'login',
              target: _targetAny('sesion'),
              condition: _cond('login_failed_attempts_in_window', 'BETWEEN', '[7, 10]'),
              effect: _deny({'lockout_type': 'temporal'}),
              help: 'SOURCE: "intentos 7-10: bloqueo temporal".'),
          _atom('lockout_overflow', 'login',
              target: _targetAny('sesion'),
              condition: _cond('login_failed_attempts_in_window', '>', '10'),
              effect: _deny({'lockout_type': 'admin_required'}),
              help: 'SOURCE: "intentos > 10: bloqueo hasta administrador".'),
        ]),
  ],
);

// ──── B6 · Gestión de sesiones ────────────────────────────────

NodoTemplate _b6() => _bloque(
  'b6_gestion_sesiones',
  help: 'Bloque B6 — Gestión de sesiones.\n'
      'RFC 6749 · RFC 9449 (DPoP) · NIST 800-63B §7.',
  hijos: [
    _pol('session_management_policy', hijos: [
      _a('session_max_duration_minutes', '480',
          help: 'Duración máxima de sesión: 8 h.'),
      _a('session_idle_timeout_minutes', '30'),
      _en('session_concurrent_policy', 'single',
          const ['single', 'limited', 'unlimited']),
      _a('session_max_concurrent', '3'),
      _en('session_token_rotation', 'on_use',
          const ['on_use', 'on_refresh', 'never']),
      _a('session_absolute_expiry_minutes', '1440',
          help: 'Expiración absoluta: 24 h independiente de actividad.'),
      _a('session_revocation_latency_ms', '500',
          help: 'Latencia máxima de revocación: < 30 s (NIST).'),
    ]),
  ],
);

// ──── B7 · PrivilegeEngine (5 capas) ─────────────────────────

NodoTemplate _b7() => _bloque(
  'b7_privilege_engine',
  help: 'Bloque B7 — Motor algebraico NIST RBAC Nivel 3 (Constrained).\n\n'
      'TIPO_DIFERENTE gap: en SOURCE estas capas son TipoNodo.objeto.\n'
      'En AtomLang normalizado deben ser TipoNodo.politica con evaluaciones.\n'
      'Reestructuración HITL requerida (ver ATOMLANG-GAP-ANALYSIS-D1 §3.4).',
  hijos: [
    _hitl('b7_capa1_rol_directo',
        'En SOURCE es objeto de datos. Debe convertirse a Policy con evaluaciones '
        'de consulta directa al bitmask. Reestructuración HITL requerida.'),
    _hitl('b7_capa2_herencia_dag',
        'En SOURCE es objeto de datos. Debe convertirse a Policy con evaluaciones '
        'de traversal del DAG de herencia OR. Reestructuración HITL requerida.'),
    _hitl('b7_capa3_restriccion_sod',
        'En SOURCE es objeto de datos. Debe convertirse a Policy con la '
        'matriz SoD como evaluaciones de exclusión. Reestructuración HITL requerida.'),
    _hitl('b7_capa4_condicion_contextual',
        'En SOURCE es objeto de datos. Debe convertirse a Policy con condiciones '
        'contextuales (temporal, geoespacial, step-up). HITL requerida.'),
    _hitl('b7_capa5_politica_global',
        'En SOURCE es objeto de datos. Debe convertirse a PolicySet raíz '
        'que agrupe las 4 capas anteriores. HITL requerida.'),
  ],
);
