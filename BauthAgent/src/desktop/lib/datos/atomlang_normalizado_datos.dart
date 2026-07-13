// ============================================================
// bauth_desktop · datos/atomlang_normalizado_datos.dart
//
// Propósito: árbol SOURCE completo traducido al lenguaje AtomLang v1.
//   Toma arbolRolTemplate y aplica el autómata de normalización:
//     1. Nombres de nodo → snake_case canónico (tabla de mapeo + conversión genérica)
//     2. Verbos ENUM → valor del vocabulario cerrado bauth.privilege_verb
//     3. Clave "propiedad" → snake_case del atributo
//   MISMO árbol, MISMA estructura, MISMO contenido — solo el lenguaje cambia.
//   No es compilación para el autenticador (eso es Tab 2).
// Dependencias: datos/rol_template_datos (NodoTemplate + TipoNodo + arbolRolTemplate).
// Estándar: A.46 §3 EBNF · A.47 §6 (diagnóstico D1) · DOC-SBOS-001 N3.
// ============================================================

import 'rol_template_datos.dart';

// ──── Tabla de mapeo: nombre SOURCE → ID AtomLang canónico ───
// Para todo lo que no está en la tabla se aplica _toSnakeCase genérico.
// Nota: verbos en mayúsculas en esta tabla representan el texto libre SOURCE
// que se normaliza a slug — los verbos válidos en atomc son siempre minúsculas.

const Map<String, String> _mapa = {
  // ── Dominios ──
  'D1 · Acceso Lógico':                    'd1_acceso_logico',
  'D2 · Acceso Físico':                    'd2_acceso_fisico',
  'D3 · Red y Perímetro':                  'd3_red_perimetral',
  'D4 · Criptografía y PKI':               'd4_criptografia_pki',
  'D5 · Auditoría y Logs':                 'd5_auditoria_logs',
  'D6 · Gestión de Identidad (Ciclo Vida)': 'd6_gestion_identidad_ciclo_vida',
  'D7 · Federación y SSO':                 'd7_federacion_sso',
  'D8 · Riesgo y Confianza':               'd8_riesgo_confianza',
  'D9 · M2M y APIs':                       'd9_m2m_apis',
  'D10 · Blockchain y ADSIB':              'd10_blockchain_adsib',
  'D11 · Multi-Tenant':                    'd11_multitenant',
  'D12 · Compliance':                      'd12_compliance',
  'D13 · Firma Digital Externa':           'd13_firma_digital_externa',
  'D98 · Registro Estructural':            'd98_registro_estructural',
  'D99 · Administrativo Global':           'd99_administrativo_global',

  // ── Bloques ──
  'B1 · Identificación':                   'b1_identificacion',
  'B2 · Credenciales':                     'b2_credenciales',
  'B3 · Autorización':                     'b3_autorizacion',
  'B4 · Dominio lógico (autenticación)':   'b4_dominio_logico_autenticacion',
  'B5 · Ciclo de vida de credenciales':    'b5_ciclo_vida_credenciales',
  'B6 · Zonas de negocio':                'b6_aplicaciones',
  'B6 · Gestión de sesiones':             'b6_gestion_sesiones',
  'B7 · Privilegios ERP (5 capas)':                'b7_privilege_engine',
  'B7 · Privilegios de Aplicaciones (5 capas)':   'b7_privilege_engine',
  'B7 · 5 capas de evaluación (PrivilegeEngine)':  'b7_privilege_engine',
  'B8 · Registro y auditoría':             'b8_registro_auditoria',
  'B9 · Federación externa':               'b9_federacion_externa',
  'B10 · Acceso físico biométrico':        'b10_acceso_fisico_biometrico',
  'B11 · Cifrado en reposo':               'b11_cifrado_en_reposo',
  'B12 · Firma digital':                   'b12_firma_digital',
  'B13 · Riesgo adaptativo':               'b13_riesgo_adaptativo',
  'B14 · Gobernanza de acceso':            'b14_gobernanza_acceso',

  // ── Átomos D1 (Gap Analysis D1) ──
  'monto de transacción alto (> @bauth_config_param.approval_threshold_tier2)': 'financial_approve',
  'zona de alta seguridad':                   'zona_alta_seguridad',
  'verbo CONFIGURE o ADMIN':                  'system_config_change',
  'verbo CONFIGURE':                          'system_config_change',
  'riesgo bajo + zona normal → contraseña':   'low_risk_password_grant',
  'zona sensible o acción privilegiada → hardware': 'sensitive_zone_hardware_grant',
  'certificado mTLS presente → x509':         'mtls_cert_x509_grant',
  'AAL2 con TOTP o HOTP':                     'aal2_totp_or_hotp',
  'AAL3 con hardware o biométrico':           'aal3_hardware_or_biometric',
  'WebAuthn Passwordless → AAL3':             'webauthn_passwordless_aal3',
  'FIDO2 hardware → AAL3':                    'fido2_hardware_aal3',
  'biométrico platform → AAL3':               'biometric_platform_aal3',
  'intentos 1-3: sin penalización':           'lockout_range_1_3',
  'intentos 4-6: retardo progresivo':         'lockout_range_4_6',
  'intentos 7-10: bloqueo temporal':          'lockout_range_7_10',
  'intentos > 10: bloqueo hasta administrador': 'lockout_overflow',
  'ventana de conteo de intentos':            'lockout_attempt_window',

  // ── Nombres de campos comunes ──
  'propiedad':              'property_id',
  'operador':               'operator',
  'op_lógico':              'op_logico',
  'combining_algorithm':    'combining_algorithm',
  'verbo':                  'verbo',
  'efecto':                 'effect',
  'condiciones':            'conditions',
  'primary_auth{}':         'primary_auth_policy',
  'mfa_auth{}':             'mfa_auth_policy',
  'session_binding{}':      'session_binding_policy',
  'step_up_triggers{}':     'step_up_triggers',
  'password_policy{}':      'password_policy',
  'account_lockout_policy{}': 'account_lockout_policy',
  'session_management{}':   'session_management_policy',
};

// ──── Conversión genérica snake_case ─────────────────────────

/// Convierte texto libre al snake_case canónico de AtomLang.
/// Elimina acentos, puntuación especial y caracteres no alfanuméricos.
String _toSnakeCase(String texto) {
  final sinAcentos = texto
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u')
      .replaceAll('ñ', 'n').replaceAll('Á', 'a').replaceAll('É', 'e')
      .replaceAll('Í', 'i').replaceAll('Ó', 'o').replaceAll('Ú', 'u')
      .replaceAll('Ü', 'u').replaceAll('Ñ', 'n');
  return sinAcentos
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Normaliza un nombre de nodo: primero busca en la tabla de mapeo,
/// luego aplica la conversión genérica snake_case.
String _normalizar(String clave) => _mapa[clave] ?? _toSnakeCase(clave);

// ──── Transformador recursivo ─────────────────────────────────

/// Transforma un NodoTemplate aplicando el lenguaje AtomLang:
/// nombres → snake_case canónico; el resto de campos se preserva íntegro.
NodoTemplate _aplicarLenguaje(NodoTemplate n) => NodoTemplate(
      _normalizar(n.clave),
      n.tipo,
      valor: n.valor,
      help: n.help,
      opciones: n.opciones,
      hijos: n.hijos.map(_aplicarLenguaje).toList(),
    );

// ──── Árbol normalizado ───────────────────────────────────────

/// El mismo árbol SOURCE con lenguaje AtomLang aplicado.
/// Generado en tiempo de compilación aplicando _aplicarLenguaje a cada nodo.
final List<NodoTemplate> arbolNormalizado =
    arbolRolTemplate.map(_aplicarLenguaje).toList();
