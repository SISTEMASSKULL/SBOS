// ============================================================
// bauth_desktop · datos/rol_template_datos.dart
//
// Propósito: árbol COMPLETO y ATOMIZADO del contrato RolTemplate v6.0.
//   TODA POLÍTICA → EVALUACIONES con propiedad/operador/valor[/efecto].
//   TODA REGLA     → EVALUACIONES con propiedad/operador/valor/efecto.
//   TODA LISTA de reglas/condiciones → hijos EVALUACIONES.
//   TODA LISTA de datos → hijos OBJETOS con atributos.
//   EFECTO obligatorio en todas las REGLAS; recomendado en POLÍTICAS.
//   Nuevos bloques: password_policy (NIST 800-63B-4), account_lockout
//   (AC-7), session_binding (DPoP RFC 9449), oauth_scopes (RFC 6749).
// Estándar: Anexo A.01 v6.0 · NIST 800-63B-4 · 800-53 R5 · 800-207
//           · ISO 24760-2:2025 · RFC 9449 · RFC 6749 · DOC-SBOS-001 N3.
// ============================================================

/// Naturaleza de un nodo del árbol.
enum TipoNodo {
  dominio,    // cabecera de dominio de control
  bloque,     // bloque dentro del dominio
  objeto,     // estructura JSONB de datos (entidad, no lógica)
  lista,      // array de ítems homogéneos (datos, no lógica)
  politica,   // conjunción de condiciones gobernantes
  regla,      // una o más evaluaciones + efecto. Patrón: eval [op_lógico eval]* efecto.
  evaluacion, // evaluación atómica: propiedad / operador / valor / efecto
  atributo,   // hoja: clave → valor libre
  enumerado,  // hoja: clave → valor de conjunto fijo (menú contextual clic derecho)
}

class NodoTemplate {
  final String clave;
  final TipoNodo tipo;
  final String? valor;
  final String? help;
  final List<NodoTemplate> hijos;
  /// Valores posibles — sólo para TipoNodo.enumerado.
  final List<String> opciones;
  const NodoTemplate(this.clave, this.tipo,
      {this.valor, this.help, this.hijos = const [], this.opciones = const []});
}

// ──── atajos ────────────────────────────────────────────────

NodoTemplate _a(String c, String v, {String? help}) =>
    NodoTemplate(c, TipoNodo.atributo, valor: v, help: help);

/// Nodo ENUMERADO: valor actual + lista de opciones para menú contextual.
NodoTemplate _en(String c, String v, List<String> ops, {String? help}) =>
    NodoTemplate(c, TipoNodo.enumerado, valor: v, opciones: ops, help: help);

NodoTemplate _ev(String nombre, List<NodoTemplate> props, {String? verbo, String? help}) =>
    NodoTemplate(nombre, TipoNodo.evaluacion, help: help, hijos: [
      if (verbo != null)
        NodoTemplate('verbo', TipoNodo.enumerado, valor: verbo,
            opciones: const ['read', 'write', 'create', 'delete', 'approve', 'execute',
                'export', 'delegate', 'configure', 'audit', 'login', 'emit', 'void', 'ANY'],
            help: 'Acción (Action) del Target XACML — §7 del manual de estructuración. Obligatorio en todo átomo.'),
      ...props,
    ]);

/// Operador lógico entre evaluaciones dentro de una regla.
/// Se sitúa ENTRE dos evaluaciones contiguas: _ev → _olo('AND'|'OR') → _ev → _ef.
/// Permite menú contextual para cambiar el operador.
NodoTemplate _olo(String op) => NodoTemplate(
    'op_lógico', TipoNodo.enumerado, valor: op,
    opciones: const ['AND', 'OR', 'NOT', 'MATCH_ALL', 'FIRST_APPLICABLE'],
    help: 'Conector lógico entre evaluaciones. AND = todas deben cumplirse · OR = basta con una.');

NodoTemplate _prop(String v, {String? help}) =>
    NodoTemplate('propiedad', TipoNodo.atributo, valor: v, help: help);

/// Operador lógico: SIEMPRE enumerado con el conjunto canónico de operadores.
NodoTemplate _op(String v) => NodoTemplate('operador', TipoNodo.enumerado, valor: v,
    opciones: const [
      '==', '!=', '>', '<', '>=', '<=',
      'IN', 'NOT_IN', 'BETWEEN',
      'SUBSET_OF', 'INTERSECT', 'NOT_INCLUDES_ALL', 'INCLUDES_ALL',
      'STARTS_WITH', 'IS_SET',
      'visible_to_role', 'max_access',
    ]);

NodoTemplate _val(String v, {String? help}) =>
    NodoTemplate('valor', TipoNodo.atributo, valor: v, help: help);

NodoTemplate _ef(String v, {String? help}) =>
    NodoTemplate('efecto', TipoNodo.atributo, valor: v, help: help);

/// Algoritmo de combinación — primer hijo de toda TipoNodo.politica.
/// Determina qué pasa cuando varias reglas evalúan simultáneamente.
NodoTemplate _algo(String v) => NodoTemplate('combining_algorithm', TipoNodo.enumerado, valor: v,
    opciones: const [
      'deny-overrides', 'permit-overrides', 'first-applicable',
      'only-one-applicable', 'deny-unless-permit', 'permit-unless-deny',
      'aggregate-strictest',
    ],
    help: 'XACML 3.0 §7.14. deny-overrides=un DENY bloquea todo · first-applicable=primer match gana · deny-unless-permit=silencio→DENY. aggregate-strictest (ext. bAuth)=todos los Permit concurrentes se fusionan eligiendo el valor más estricto campo a campo (max required_loa, min max_age_seconds) — resuelve el problema de atoms simultáneos en step_up_triggers.');

// ════════════════════════════════════════════════════════════
final List<NodoTemplate> arbolRolTemplate = [

// ══════════════════════════════════════════════
// D0 · IDENTIDAD ORGANIZACIONAL
// ══════════════════════════════════════════════
NodoTemplate('D0 · IDENTIDAD ORGANIZACIONAL', TipoNodo.dominio,
    help: 'Pre-condición estructural (ctx_id). ISO 24760-2 §5.', hijos: [

  NodoTemplate('B1 · Identificación y metadatos', TipoNodo.bloque,
      help: 'Identidad canónica, versionado semántico, H-RBAC. ANSI/INCITS 359 §4 · SemVer 2.0.', hijos: [
    _a('id', 'RGV-001', help: 'INMUTABLE post-creación. uuidv7 (RFC 9562). Formato {SIGLA}-{NNN}.'),
    _a('parent_id', 'VEN-BASE-001', help: 'Padre H-RBAC. null = raíz. DAG — NUNCA circular.'),
    _en('type_id', 'TYPE-GERENCIA-REGIONAL',
        ['INDIVIDUAL', 'EXTERNAL', 'GUEST', 'GROUP', 'SYSTEM', 'SERVICE', 'M2M', 'EMERGENCY', 'TEMPORARY', 'DEVELOPER'],
        help: '10 tipos de rol. EMERGENCY = 72h máx. M2M = machine-to-machine.'),
    _en('hierarchy_level', '2', ['1', '2', '3', '4', '5'],
        help: '1=C-Level · 2=Director · 3=Gerente · 4=Supervisor · 5=Operativo.'),
    _a('path_ids', '["VEN-BASE-001","RGV-001"]', help: 'Cadena de ancestros. Solo lectura.'),
    _a('version', '3.1.0', help: 'SemVer. MAJOR = breaking en permisos.'),
    _en('status', 'ACTIVE',
        ['DRAFT', 'REVIEW', 'ACTIVE', 'SUSPENDED', 'DEPRECATED', 'ARCHIVED'],
        help: 'Ciclo de vida del rol. ARCHIVED = inmutable permanente.'),
    NodoTemplate('name', TipoNodo.objeto, help: 'Nombre multilenguaje (i18n obligatorio).', hijos: [
      _a('es', 'Gerente Regional de Ventas — Región Norte'),
      _a('en', 'Regional Sales Manager — Northern Region'),
      _a('pt', 'Gerente Regional de Vendas — Região Norte'),
    ]),
    NodoTemplate('description', TipoNodo.objeto, hijos: [
      _a('es', 'Responsable de operaciones comerciales región norte. Aprueba ventas ≤50 000 BOB.'),
    ]),
    NodoTemplate('metadata', TipoNodo.objeto, help: 'ISO 24760-2 §5.', hijos: [
      _a('department', 'Ventas'),
      _a('cost_center', 'VEN-NORTE'),
      _a('region', 'NORTH'),
      _a('territory_code', 'VEN-NORTH-001'),
      _a('job_family', 'Sales'),
      _a('job_level', 'M2', help: 'Escala: I1-I5 individual · M1-M5 manager · D1-D3 director.'),
      _a('max_subordinates', '10'),
      _a('required_certifications', '["SALES_CERT_A","MANAGEMENT_CERT_B"]'),
      _en('classification', 'CONFIDENTIAL',
          ['PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'],
          help: 'ISO A.5.12. Determina controles de manejo y distribución.'),
    ]),
    NodoTemplate('audit', TipoNodo.objeto, help: 'Trazabilidad del artefacto. ISO A.8.15.', hijos: [
      _a('created_by', 'ADMIN.SISTEMA'),
      _a('created_at', '2024-01-01T00:00:00Z'),
      _a('updated_by', 'DGV.CARLOS.RUIZ'),
      _a('version_number', '7'),
      NodoTemplate('change_history[]', TipoNodo.lista,
          help: '{version, date, changed_by, approved_by, changes[], reason, security_impact}.', hijos: [
        _a('changes', '["Incremento límite L1 de 40k a 50k BOB"]'),
        _a('change_reason', 'Ajuste por inflación — Resolución DIR-2026-003'),
        _en('security_impact', 'LOW', ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']),
      ]),
    ]),
    NodoTemplate('digital_signature', TipoNodo.objeto, help: 'Firma del contrato. Ley 164 · ADSIB.', hijos: [
      _en('algorithm', 'EdDSA_Ed25519',
          ['EdDSA_Ed25519', 'RSA-SHA256', 'CRYSTALS-Dilithium'],
          help: 'NIST 800-186 §3.2.1. Dilithium = post-cuántico planeado 2027-2028.'),
      _a('post_quantum_planned', 'CRYSTALS-Dilithium', help: 'Híbrido planeado 2027-2028.'),
      _a('validity', 'not_before … not_after (1 año)'),
    ]),
  ]),

  NodoTemplate('B3 · Flujo de aprobación', TipoNodo.bloque,
      help: 'Gobernanza de cambios del contrato del rol. ISO 27001 A.5.2 · CM-3/AC-5.', hijos: [
    NodoTemplate('approval_workflow', TipoNodo.politica,
        help: 'Condiciones de aprobación de cambios MAJOR del contrato.', hijos: [
      _ev('quórum de aprobadores', [
        _prop('approval.count_distinct_approvers'),
        _op('>='),
        _val('2', help: 'AC-5 — aprobadores distintos.'),
        _ef('DENY si < 2 aprobadores distintos firman'),
      ]),
      _ev('nivel organizacional de aprobadores', [
        _prop('approver.hierarchy_level'),
        _op('>='),
        _val('hierarchy_level del solicitante', help: 'PCI DSS 7.2.5.1.'),
        _ef('DENY si aprobador tiene nivel inferior al solicitante'),
      ]),
      _ev('SLA de respuesta', [
        _prop('approval.elapsed_hours'),
        _op('<='),
        _val('48 h', help: 'ISO A.5.18b.'),
        _ef('expiración automática del request si supera 48 h'),
      ]),
      _ev('escalación automática', [
        _prop('approval.elapsed_hours'),
        _op('>'),
        _val('24 h'),
        _ef('escalar a [CISO, CEO] · notify vía bNotify'),
      ]),
      _ev('canal de notificación', [
        _prop('notification.channel'),
        _op('=='),
        _val('rocket_chat', help: 'Enviado vía bNotify (nunca directo desde bAuth).'),
        _ef('bNotify.send(rocket_chat, destinatarios, payload)'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D1 · ACCESO LÓGICO
// ══════════════════════════════════════════════
NodoTemplate('D1 · ACCESO LÓGICO', TipoNodo.dominio,
    help: 'Autenticación digital y autorización lógica. Fast-Path <0.5 ns. NIST 800-63B-4 · FIDO2 · RFC 9470.', hijos: [

  NodoTemplate('B4 · Dominio lógico (autenticación)', TipoNodo.bloque,
      help: 'Métodos, flujos, LoA, lockout, session binding y scopes.', hijos: [

    // ── Rama metodos D1 (§11.6 Manual-Metodos v1.1.0) ───────────
    NodoTemplate('metodos', TipoNodo.bloque,
        help: 'Rama de autenticación digital de D1. 3 sub-ramas: available_methods, required_methods (4 grupos), alternative_methods. Solo D1 y D2 tienen esta rama. Manual-Metodos §11.6.', hijos: [

      // ── available_methods[] — pool de autenticadores ─────
      NodoTemplate('available_methods[]', TipoNodo.lista, valor: '9 métodos',
          help: 'Pool de autenticadores habilitados para el rol en D1. amr_value según RFC 8176. sms_otp DEPRECADO.', hijos: [
        NodoTemplate('username_password', TipoNodo.objeto, help: 'MEMORIZED_SECRET. 800-63B-4 §5.1.1. amr=pwd.', hijos: [
          _a('tipo', 'MEMORIZED_SECRET'),
          _a('amr_value', 'pwd'),
          _a('min_length', '15 caracteres (solo factor) · 8 (con MFA adicional)', help: '800-63B-4 §5.1.1.1.'),
          _a('max_length', '64+ (soporte de passphrases)'),
          _en('breach_check', 'true', ['true', 'false'],
              help: 'Screening obligatorio contra listas comprometidas.'),
          _a('composition_rules', 'NINGUNA — eliminadas (800-63B-4)'),
          _en('hints', 'PROHIBIDOS', ['PROHIBIDOS', 'permitidos'],
              help: 'NIST 800-63B-4 §5.1.1.2 prohíbe hints de contraseña.'),
          _en('paste_allowed', 'true', ['true', 'false']),
          _en('loa', '1', ['1', '2', '3', '4'],
              help: '1=conocimiento solo · acompañar con mfa_auth para AAL2+.'),
        ]),
        NodoTemplate('totp', TipoNodo.objeto, help: 'Time-based OTP. RFC 6238. amr=otp.', hijos: [
          _a('tipo', 'OTP'),
          _a('amr_value', 'otp'),
          _a('algoritmo', 'HMAC-SHA1 · 6 dígitos'),
          _a('time_step', '30 s'),
          _a('max_clock_drift', '±1 período (60 s total)'),
          _a('issuer', 'bAuth — etiqueta en app autenticadora'),
          _en('loa', '2', ['1', '2', '3', '4']),
        ]),
        NodoTemplate('webauthn_platform', TipoNodo.objeto, help: 'WebAuthn plataforma. FIDO2 L2. amr=fpt.', hijos: [
          _a('tipo', 'WEBAUTHN'),
          _a('amr_value', 'fpt'),
          _a('authenticator_attachment', 'platform (Touch ID, Windows Hello, Face ID)'),
          _en('resident_key', 'required', ['required', 'preferred', 'discouraged']),
          _en('user_verification', 'required', ['required', 'preferred', 'discouraged']),
          _en('attestation', 'direct', ['direct', 'indirect', 'none'],
              help: 'direct = verificar FIDO MDS · none = sin verificar fabricante.'),
          _en('loa', '3', ['1', '2', '3', '4']),
        ]),
        NodoTemplate('webauthn_roaming', TipoNodo.objeto, help: 'Llave de seguridad física. FIDO2 L1. amr=hwk.', hijos: [
          _a('tipo', 'HARDWARE_BOUND'),
          _a('amr_value', 'hwk'),
          _en('authenticator_attachment', 'cross-platform', ['platform', 'cross-platform'],
              help: 'cross-platform = llave física YubiKey/Titan.'),
          _en('resident_key', 'preferred', ['required', 'preferred', 'discouraged']),
          _en('user_verification', 'required', ['required', 'preferred', 'discouraged']),
          _en('loa', '3', ['1', '2', '3', '4']),
        ]),
        NodoTemplate('passkey', TipoNodo.objeto, help: 'Passkey sincronizado (FIDO2 + cloud). amr=hwk.', hijos: [
          _a('tipo', 'WEBAUTHN'),
          _a('amr_value', 'hwk'),
          _en('synced', 'true', ['true', 'false'],
              help: 'true = iCloud Keychain / Google PM · false = device-bound.'),
          _en('user_verification', 'required', ['required', 'preferred', 'discouraged']),
          _en('loa', '2', ['1', '2', '3', '4'],
              help: '2=sincronizado (riesgo sync cloud) · 3=device-bound.'),
          _a('nota', 'Passkey sincronizado = LoA 2 por riesgo de sync cloud'),
        ]),
        NodoTemplate('x509_smartcard', TipoNodo.objeto, help: 'mTLS + certificado de cliente. RFC 8705. amr=sc.', hijos: [
          _a('tipo', 'HARDWARE_BOUND'),
          _a('amr_value', 'sc'),
          _a('key_storage', 'hardware (smartcard / HSM)'),
          _a('certificate_policy', 'ADSIB-FD-POLT-015 | CA interna bAuth'),
          _en('pin_required', 'true', ['true', 'false']),
          _en('loa', '3', ['1', '2', '3', '4'],
              help: '3 = hardware · 4 = hardware + PIN + biométrico.'),
        ]),
        NodoTemplate('backup_codes', TipoNodo.objeto, help: 'Códigos de recuperación. RFC 6238 §5. amr=otp.', hijos: [
          _a('tipo', 'OTP'),
          _a('amr_value', 'otp'),
          _a('count', '10 códigos de un solo uso'),
          _a('format', 'XXXX-XXXX-XXXX (12 hex chars)'),
          _a('entropy_bits', '48'),
          _a('uso', 'ÚLTIMO RECURSO — regenera el conjunto completo al usarse uno'),
          _en('loa', '2', ['1', '2', '3', '4']),
        ]),
        NodoTemplate('email_otp', TipoNodo.objeto, help: 'OTP por correo. amr=otp.', hijos: [
          _a('tipo', 'OTP'),
          _a('amr_value', 'otp'),
          _a('ttl_minutes', '10'),
          _a('digits', '6'),
          _a('channel', 'SMTP cifrado — entrega vía bNotify'),
          _en('loa', '1', ['1', '2', '3', '4'],
              help: 'Canal fuera de control directo — LoA débil.'),
        ]),
        NodoTemplate('push_notification', TipoNodo.objeto, help: 'Aprobación push (app móvil). amr=mfa.', hijos: [
          _a('tipo', 'MULTI_FACTOR'),
          _a('amr_value', 'mfa'),
          _a('ttl_seconds', '60'),
          _a('numero_intent', 'número aleatorio en pantalla para anti-fatiga MFA'),
          _en('loa', '2', ['1', '2', '3', '4']),
        ]),
      ]),

      // ── required_methods{} — 4 sub-grupos ordenados ──────
      NodoTemplate('required_methods{}', TipoNodo.objeto,
          help: '4 sub-grupos en orden estricto 1→2→3→4. Fallo en grupo activo detiene la cadena. §11.7.', hijos: [

        NodoTemplate('primary_auth{}', TipoNodo.objeto,
            help: 'Orden=1. Factor primario — SIEMPRE ejecuta. NIST 800-63B-4 §4.1 · RFC 8176 pwd/hwk/sc.', hijos: [
          _a('method_id', 'username_password | x509_smartcard | webauthn_platform | passkey'),
          _en('min_loa', '1', ['1', '2', '3', '4']),
          NodoTemplate('condiciones', TipoNodo.regla,
              help: 'OR: cualquiera de estas sub-reglas puede aplicar su efecto independientemente. NIST 800-63B-4 §4.1.', hijos: [
            NodoTemplate('verbo', TipoNodo.enumerado, valor: 'login',
                opciones: const ['read', 'write', 'create', 'delete', 'approve', 'execute',
                    'export', 'delegate', 'configure', 'audit', 'login', 'emit', 'void', 'ANY'],
                help: 'Acción (Action) del Target XACML. §7 del manual de estructuración. Obligatorio en todo átomo.'),
            NodoTemplate('riesgo bajo + zona normal → contraseña', TipoNodo.regla,
                help: 'AND: ambas deben cumplirse. 800-63B-4 §4.1 — riesgo bajo Y zona no sensible habilitan contraseña.', hijos: [
              NodoTemplate('verbo', TipoNodo.enumerado, valor: 'login',
                  opciones: const ['read', 'write', 'create', 'delete', 'approve', 'execute',
                      'export', 'delegate', 'configure', 'audit', 'login', 'emit', 'void', 'ANY'],
                  help: 'Acción (Action) del Target XACML. §7 del manual de estructuración. Obligatorio en todo átomo.'),
              _ev('riesgo bajo', [_prop('risk.score'), _op('<='), _val('0.50')]),
              _olo('AND'),
              _ev('zona no sensible', [_prop('zone.sensitivity'), _op('!='), _val('HIGH')]),
              _ef('method = username_password · amr = [pwd]'),
            ]),
            _olo('OR'),
            NodoTemplate('zona sensible o acción privilegiada → hardware', TipoNodo.regla,
                help: 'OR: basta con una condición para escalar a hardware. 800-53 AC-6 least privilege.', hijos: [
              NodoTemplate('verbo', TipoNodo.enumerado, valor: 'login',
                  opciones: const ['read', 'write', 'create', 'delete', 'approve', 'execute',
                      'export', 'delegate', 'configure', 'audit', 'login', 'emit', 'void', 'ANY'],
                  help: 'Acción (Action) del Target XACML. §7 del manual de estructuración. Obligatorio en todo átomo.'),
              _ev('zona sensible', [_prop('zone.sensitivity'), _op('IN'), _val('[HIGH, CRITICAL]')]),
              _olo('OR'),
              _ev('verbo privilegiado', [_prop('action.verb'), _op('IN'), _val('[CONFIGURE, ADMIN, DELETE]')]),
              _ef('method = webauthn_platform | x509_smartcard · amr = [fpt | sc]'),
            ]),
            _olo('OR'),
            _ev('certificado mTLS presente → x509', [
              _prop('connection.client_cert_present'),
              _op('=='),
              _val('true'),
              _ef('method = x509_smartcard · amr = [sc]'),
            ], verbo: 'login'),
          ]),
        ]),

        NodoTemplate('mfa_auth{}', TipoNodo.objeto,
            help: 'Orden=2. Factor adicional si role.level_of_assurance >= 2. NIST 800-63B-4 §4.2-4.3.', hijos: [
          _en('required_if', 'role.level_of_assurance >= 2',
              ['role.level_of_assurance >= 2', 'role.level_of_assurance >= 3', 'siempre', 'nunca']),
          NodoTemplate('eligible_methods[]', TipoNodo.lista, hijos: [
            _a('1 · totp', 'preferido AAL2 · amr=otp'),
            _a('2 · webauthn_platform', 'preferido AAL3 · amr=fpt'),
            _a('3 · webauthn_roaming', 'alternativa hardware AAL3 · amr=hwk'),
            _a('4 · push_notification', 'push con number matching (verify_number) · amr=mfa'),
            _a('5 · backup_codes', 'ÚLTIMO RECURSO — solo emergencia · amr=otp'),
          ]),
          _en('min_additional_loa', '2', ['1', '2', '3', '4']),
          NodoTemplate('condiciones', TipoNodo.regla,
              help: 'OR: cualquiera de estas sub-reglas puede aplicar su efecto independientemente. Pueden coincidir varias (ej: LoA 3 + monto grande). NIST 800-63B-4 §4.2-4.3.', hijos: [
            NodoTemplate('verbo', TipoNodo.enumerado, valor: 'login',
                opciones: const ['read', 'write', 'create', 'delete', 'approve', 'execute',
                    'export', 'delegate', 'configure', 'audit', 'login', 'emit', 'void', 'ANY'],
                help: 'Acción (Action) del Target XACML. §7 del manual de estructuración. Obligatorio en todo átomo.'),
            _ev('login AAL2 estándar → TOTP o Push', [
              _prop('role.level_of_assurance'),
              _op('=='),
              _val('2'),
              _ef('eligible_mfa = [totp, push_notification] · min_loa_mfa = 2'),
            ], help: 'NIST 800-63B-4 AAL2.'),
            _olo('OR'),
            NodoTemplate('login AAL3 (zona crítica) → WebAuthn hardware', TipoNodo.regla,
                help: 'OR: basta con una condición para activar WebAuthn hardware. NIST 800-63B-4 AAL3.', hijos: [
              NodoTemplate('verbo', TipoNodo.enumerado, valor: 'login',
                  opciones: const ['read', 'write', 'create', 'delete', 'approve', 'execute',
                      'export', 'delegate', 'configure', 'audit', 'login', 'emit', 'void', 'ANY'],
                  help: 'Acción (Action) del Target XACML. §7 del manual de estructuración. Obligatorio en todo átomo.'),
              _ev('LoA del rol es 3', [_prop('role.level_of_assurance'), _op('=='), _val('3')]),
              _olo('OR'),
              _ev('contexto requiere AAL3', [_prop('context.requires_aal3'), _op('=='), _val('true')]),
              _ef('eligible_mfa = [webauthn_platform, webauthn_roaming] · min_loa_mfa = 3'),
            ]),
            _olo('OR'),
            _ev('financiero > 25 000 BOB → triple factor', [
              _prop('transaction.amount_bob'),
              _op('>'),
              _val('25 000 BOB'),
              _ef('primary + webauthn_platform + totp_fresh(max_age=0) → JWT LoA 3 · PCI Req 8'),
            ], verbo: 'login'),
          ]),
        ]),

        NodoTemplate('step_up_triggers', TipoNodo.politica,
            help: 'Orden=3. Elevación mid-session — NO cierra sesión, añade factor. RFC 9470 · acr_values. aggregate-strictest: cuando varios atoms aplican simultáneamente (ej. monto alto EN zona crítica), se fusionan tomando max(required_loa) y min(max_age_seconds) — nunca first-applicable (que perdería el requisito más estricto por orden de declaración).', hijos: [
          _algo('aggregate-strictest'),
          _ev('monto de transacción alto (>10 000 BOB)', [
            _prop('transaction.amount_bob'),
            _op('>'),
            _val('10000'),
            _ef('required_loa = 3 · max_age_seconds = 300 · acr = aal3'),
          ], verbo: 'execute'),
          _ev('zona de alta seguridad', [
            _prop('zone.security_level'),
            _op('=='),
            _val('critical'),
            _ef('required_loa = 3 · max_age_seconds = 600'),
          ], verbo: 'ANY'),
          _ev('verbo administrativo (configure)', [
            _ef('required_loa = 3 · max_age_seconds = 0 (fresca siempre)'),
          ], verbo: 'configure',
            help: 'Target-gate = verbo configure. Condición eliminada (defecto §2.1 #2): el verbo en el Target-gate es el único discriminador — una condición secundaria sobre action.verb sería redundante y causaría case-sensitivity bugs.'),
        ]),

        NodoTemplate('re_auth_policy{}', TipoNodo.objeto,
            help: 'Orden=4. Re-autenticación periódica sin nueva sesión — actualiza iat en JWT. NIST 800-63B-4 §7.2 · PCI DSS 4.0 Req 8.3.9.', hijos: [
          _a('max_session_minutes', '480', help: 'NIST §7.2: AAL2/AAL3 = 12h máximo de sesión activa.'),
          _a('idle_minutes', '15', help: 'Lock tras 15 min inactividad — no cierre de sesión.'),
          _a('reauth_interval_mins', '240', help: 'Re-verificación MFA a las 4h — sin cerrar sesión.'),
          NodoTemplate('method_eligible[]', TipoNodo.lista, hijos: [
            _a('1 · totp', 'preferido — rápido y no intrusivo'),
            _a('2 · webauthn_platform', 'biométrico plataforma — sin fricciones'),
            _a('3 · push_notification', 'push con number matching'),
          ]),
        ]),
      ]),

      // ── alternative_methods[] — sustitutos ───────────────
      NodoTemplate('alternative_methods[]', TipoNodo.lista,
          help: 'Sustitutos si el método primario no está disponible. loa_change = none|degraded|elevated. alert_on_use = CAEP event.', hijos: [
        NodoTemplate('alt_totp_por_email_otp', TipoNodo.objeto,
            help: 'Sustitución temporal degradada — requiere aprobación.', hijos: [
          _a('replaces', 'totp'),
          _a('with', 'email_otp'),
          _a('loa_change', 'degraded: LoA 2 → LoA 1'),
          _en('requires_approval', 'true', ['true', 'false']),
          _a('max_uses', '3 consecutivos antes de bloqueo'),
          _en('alert_on_use', 'true', ['true', 'false']),
        ]),
        NodoTemplate('alt_webauthn_roaming_por_platform', TipoNodo.objeto,
            help: 'Llave física en lugar de biométrico plataforma — mismo LoA.', hijos: [
          _a('replaces', 'webauthn_platform'),
          _a('with', 'webauthn_roaming'),
          _a('loa_change', 'none — mismo LoA 3'),
          _en('requires_approval', 'false', ['true', 'false']),
          _en('alert_on_use', 'false', ['true', 'false']),
        ]),
        NodoTemplate('alt_backup_codes_emergencia', TipoNodo.objeto,
            help: 'Solo si todos los factores MFA fallan. AC-2(2) emergency access.', hijos: [
          _a('replaces', 'totp | webauthn'),
          _a('with', 'backup_codes'),
          _a('loa_change', 'degraded: LoA 3 → LoA 2 (temporal)'),
          _en('requires_approval', 'true', ['true', 'false']),
          _en('notify_security', 'true', ['true', 'false']),
          _en('one_time_only', 'true', ['true', 'false']),
          _en('alert_on_use', 'true', ['true', 'false']),
        ]),
      ]),
    ]),

    _en('level_of_assurance', '2', ['1', '2', '3', '4'],
        help: '1=pwd · 2=MFA · 3=MFA fuerte · 4=WebAuthn+quórum. LoA(hijo) ≥ LoA(padre).'),

    // ── Bloqueo de cuenta (NUEVO — NIST 800-53 AC-7) ────────
    NodoTemplate('account_lockout_policy', TipoNodo.politica,
        help: 'Bloqueo progresivo tras intentos fallidos. NIST 800-53 R5 AC-7 · 800-63B-4.', hijos: [
      _algo('first-applicable'),
      _ev('intentos 1-3: sin penalización', [
        _prop('login.failed_attempts_in_window'),
        _op('BETWEEN'),
        _val('[1, 3]'),
        _ef('acceso normal — registrar intento en audit_log'),
      ], verbo: 'login'),
      _ev('intentos 4-6: retardo progresivo', [
        _prop('login.failed_attempts_in_window'),
        _op('BETWEEN'),
        _val('[4, 6]'),
        _ef('delay = (attempt - 3) × 60 s · notify usuario'),
      ], verbo: 'login'),
      _ev('intentos 7-10: bloqueo temporal', [
        _prop('login.failed_attempts_in_window'),
        _op('BETWEEN'),
        _val('[7, 10]'),
        _ef('lockout_duration = 15 min · notify role_owner + security_team'),
      ], verbo: 'login'),
      _ev('intentos > 10: bloqueo hasta administrador', [
        _prop('login.failed_attempts_in_window'),
        _op('>'),
        _val('10'),
        _ef('status = LOCKED · require admin_unlock + MFA verify · alert CISO'),
      ], verbo: 'login'),
      _ev('ventana de conteo de intentos', [
        _prop('login.attempt_window_minutes'),
        _op('=='),
        _val('60', help: 'El contador se reinicia cada 60 min si no hubo bloqueo.'),
        _ef('reset counter después de 60 min sin bloqueo'),
      ], verbo: 'login'),
    ]),

    // ── Gestión de sesión ────────────────────────────────────
    NodoTemplate('session_management', TipoNodo.politica,
        help: 'NIST 800-63B §7: timeout total + inactividad + reautenticación + concurrencia.', hijos: [
      _algo('deny-overrides'),
      _ev('duración máxima absoluta', [
        _prop('session.duration_minutes'),
        _op('>'),
        _val('480', help: '8 h — sesión absoluta.'),
        _ef('force_logout · require_reauth para nueva sesión'),
      ], verbo: 'access'),
      _ev('inactividad máxima', [
        _prop('session.idle_minutes'),
        _op('>'),
        _val('15', help: 'NIST 800-63B-4 §7.2.'),
        _ef('session_lock · require_reauth (no nueva sesión, solo reactivación)'),
      ], verbo: 'access'),
      _ev('reautenticación periódica', [
        _prop('session.minutes_since_last_auth'),
        _op('>'),
        _val('240', help: '4 h — reautenticar sin cerrar sesión.'),
        _ef('prompt_reauth (no logout, solo verificación MFA)'),
      ], verbo: 'access'),
      _ev('sesiones concurrentes', [
        _prop('session.concurrent_active_count'),
        _op('>'),
        _val('1'),
        _ef('revocar sesión más antigua · notify usuario · audit_event'),
      ], verbo: 'access'),
      _ev('dispositivo AC-2(3) — inactividad de cuenta', [
        _prop('account.days_since_last_login'),
        _op('>'),
        _val('90', help: 'NIST AC-2(3) — deshabilitar cuentas inactivas.'),
        _ef('status = SUSPENDED · notify role_owner · require reactivación manual'),
      ], verbo: 'access'),
    ]),

    // ── Vinculación de tokens de sesión (NUEVO — DPoP RFC 9449) ──
    NodoTemplate('session_binding', TipoNodo.politica,
        help: 'Vinculación criptográfica de tokens para prevenir token replay y session hijacking. DPoP RFC 9449.', hijos: [
      _algo('deny-overrides'),
      _ev('DPoP requerido en API calls', [
        _prop('api_request.dpop_header_present'),
        _op('=='),
        _val('true', help: 'RFC 9449 — prueba de posesión de clave privada en cada request.'),
        _ef('DENY request sin DPoP header válido · HTTP 401'),
      ], verbo: 'execute'),
      _ev('PKCE requerido en auth code flow', [
        _prop('auth_request.code_challenge_method'),
        _op('=='),
        _val('S256 (SHA-256)', help: 'RFC 7636 — PKCE previene CSRF e intercepción de código.'),
        _ef('DENY auth code request sin code_challenge · HTTP 400'),
      ], verbo: 'login'),
      _ev('huella de dispositivo obligatoria', [
        _prop('session.device_fingerprint_valid'),
        _op('=='),
        _val('true', help: 'Combinación: user-agent + TLS fingerprint + screen props.'),
        _ef('flag anomaly si fingerprint cambia mid-session · step-up LoA 3'),
      ], verbo: 'access'),
      _ev('token binding (RFC 8471) — DEPRECADO', [
        _prop('connection.token_binding_status'),
        _op('=='),
        _val('NOT_REQUIRED', help: 'RFC 8471 sin soporte en navegadores modernos. DPoP es el sucesor.'),
        _ef('ignorar — usar DPoP en su lugar'),
      ], verbo: 'access'),
    ]),

    // ── Scopes OAuth 2.0 / OIDC (NUEVO — RFC 6749) ──────────
    NodoTemplate('oauth_scopes', TipoNodo.objeto,
        help: 'Scopes que el servidor OIDC de bAuth emite para este rol. RFC 6749 §3.3 · OIDC Core §5.4.', hijos: [
      NodoTemplate('system_scopes', TipoNodo.lista, help: 'Scopes estándar OIDC.', hijos: [
        _a('openid', 'siempre presente — identificación del sujeto'),
        _a('profile', 'nombre, cargo, foto, organización'),
        _a('email', 'correo corporativo verificado'),
        _a('roles', 'lista de rol(es) activos del usuario'),
        _a('bauth:token_info', 'metadata del JWT (loa, ctx_id, domain_mask)'),
      ]),
      NodoTemplate('business_scopes', TipoNodo.lista,
          help: 'Scopes de negocio derivados de zonas y verbos (B6). Prefijo: sbos:{zona}:{verbo}.', hijos: [
        _a('sbos:ventas:read', 'lectura de oportunidades y pedidos'),
        _a('sbos:ventas:write', 'crear y modificar pedidos propios'),
        _a('sbos:ventas:approve', 'aprobar ventas ≤50 000 BOB (tier 2)'),
        _a('sbos:clientes:read', 'lectura de ficha de cliente (PII)'),
        _a('sbos:clientes:write', 'modificar datos de cliente'),
        _a('sbos:financial:read', 'consulta de límites y transacciones propias'),
      ]),
      NodoTemplate('denied_scopes', TipoNodo.lista,
          help: 'Scopes explícitamente denegados — no se emiten aunque se soliciten.', hijos: [
        _a('sbos:admin:*', 'administración del sistema — DENY'),
        _a('sbos:financial:configure', 'configurar parámetros financieros — DENY'),
        _a('sbos:audit:delete', 'borrar registros de auditoría — DENY permanente'),
      ]),
    ]),

    // ── Referencias a otros dominios ─────────────────────────
    NodoTemplate('geospatial_control', TipoNodo.politica, valor: 'ref → B15/D6',
        help: 'Única fuente en D6/B15. Aquí solo la referencia.', hijos: [
      _algo('deny-overrides'),
      _ev('referencia al dominio geoespacial', [
        _prop('d6_geospatial_ref'),
        _op('=='),
        _val('D6.B15.allowed_locations[]'),
        _ef('evaluar condiciones de acceso desde D6 — no duplicar aquí'),
      ], verbo: 'ANY'),
    ]),
    NodoTemplate('temporal_control', TipoNodo.politica, valor: 'ref → D4',
        help: 'Enlaza a D4 para horarios de autenticación.', hijos: [
      _algo('deny-overrides'),
      _ev('referencia al dominio temporal', [
        _prop('d4_temporal_ref'),
        _op('=='),
        _val('D4.B2.validity_period + D8.B17.context_signals'),
        _ef('evaluar vigencia temporal desde D4 — no duplicar aquí'),
      ], verbo: 'ANY'),
    ]),
  ]),

  // ── B6 Zonas de negocio ───────────────────────────────────
  NodoTemplate('B6 · Zonas de negocio', TipoNodo.bloque,
      help: 'Zonas abstractas + verbos autorizados. XACML 3.0 · NIST 800-162.', hijos: [
    NodoTemplate('zones{}', TipoNodo.objeto,
        help: 'Clave = zona abstracta. Verbos: READ/WRITE/DELETE/APPROVE/EXECUTE/CONFIGURE/AUDIT/EMIT.', hijos: [
      NodoTemplate('zone_logical/ventas', TipoNodo.objeto, hijos: [
        _a('verbs', '["READ","WRITE","APPROVE","EXECUTE"]'),
        _en('scope', 'REGIONAL', ['GLOBAL', 'REGIONAL', 'LOCAL', 'PERSONAL']),
        _a('max_record_limit', '1000'),
      ]),
      NodoTemplate('zone_logical/clientes', TipoNodo.objeto, hijos: [
        _a('verbs', '["READ","WRITE"]'),
        _en('pii_access', 'true', ['true', 'false'],
            help: 'Logging extra + masking_policy(lastFourVisible). RGPD Art. 5.'),
        _a('masking_policy', 'lastFourVisible (DNI, teléfono, email parcial)'),
      ]),
      NodoTemplate('zone_financial/ventas', TipoNodo.objeto, hijos: [
        _a('limit_tier', '2', help: '0=sin ops · 1=1k · 2=10k · 3=50k · 4=200k · 5=sin límite.'),
        _a('sod_cannot_also', 'zone_financial/ventas:AUDIT'),
        _a('requires_dual_approval_above', '10 000 BOB'),
        _a('currency', 'BOB'),
      ]),
    ]),
  ]),

  // ── B7 Privilegios ERP (5 capas) ─────────────────────────
  NodoTemplate('B7 · Privilegios ERP (5 capas)', TipoNodo.bloque,
      help: 'Enforcement nativo (BitMask+PolicyEngine). NIST AC-3/AC-6(10) · PCI 7.3.', hijos: [

    NodoTemplate('model_access', TipoNodo.politica, valor: 'CAPA 1 · CRUD por modelo',
        help: 'read:false = modelo completamente invisible.', hijos: [
      _algo('deny-overrides'),
      _ev('aislamiento de usuarios (res.user)', [
        _prop('model.res_user.read'),
        _op('=='),
        _val('false'),
        _ef('modelo res.user invisible — DENY todo acceso (aislamiento multi-tenant)'),
      ], verbo: 'read'),
      _ev('acceso CRUD por zona declarada (B6)', [
        _prop('model.{nombre}.crud_mask'),
        _op('SUBSET_OF'),
        _val('verbos de zones{} (B6)'),
        _ef('DENY verbo no declarado en B6 · HTTP 403'),
      ], verbo: 'execute'),
    ]),

    NodoTemplate('visible_actions', TipoNodo.politica, valor: 'CAPA 2 · menús visibles',
        help: 'Deny-all implícito: solo lo listado es visible. AC-6(10).', hijos: [
      _algo('deny-overrides'),
      _ev('menú ventas — visible', [
        _prop('ui.menu_id'),
        _op('IN'),
        _val('[ventas.lista, ventas.nueva_venta, ventas.aprobar, ventas.reportes_propios]'),
        _ef('render = VISIBLE'),
      ], verbo: 'read'),
      _ev('menú clientes — visible (solo lectura/edición)', [
        _prop('ui.menu_id'),
        _op('IN'),
        _val('[clientes.lista, clientes.ficha, clientes.editar]'),
        _ef('render = VISIBLE'),
      ], verbo: 'read'),
      _ev('acciones financieras (dentro del tier)', [
        _prop('ui.action_id'),
        _op('IN'),
        _val('[pagos.nueva_≤10k, pagos.aprobar_≤50k, facturas.emitir]'),
        _ef('render = VISIBLE · badge con límite de monto'),
      ], verbo: 'execute'),
      _ev('menú administración — oculto', [
        _prop('ui.menu_id'),
        _op('STARTS_WITH'),
        _val('admin.'),
        _ef('render = HIDDEN — no enviar al cliente (AC-6(10))'),
      ], verbo: 'read'),
    ]),

    NodoTemplate('field_restrictions', TipoNodo.politica, valor: 'CAPA 3 · campos individuales',
        help: 'Masking y ocultamiento por campo. ISO A.8.11.', hijos: [
      _algo('deny-overrides'),
      _ev('campo margin — oculto', [
        _prop('field.sale_order.margin'),
        _op('visible_to_role'),
        _val('false'),
        _ef('omitir de respuesta JSON · campo omitido en SELECT'),
      ], verbo: 'read'),
      _ev('campo cost_price — oculto', [
        _prop('field.product.cost_price'),
        _op('visible_to_role'),
        _val('false'),
        _ef('omitir de respuesta JSON'),
      ], verbo: 'read'),
      _ev('campo credit_limit — solo lectura', [
        _prop('field.res_partner.credit_limit'),
        _op('max_access'),
        _val('READ'),
        _ef('DENY write · HTTP 403 si intenta modificar'),
      ], verbo: 'write'),
    ]),

    NodoTemplate('button_rules', TipoNodo.politica, valor: 'CAPA 4 · botones con PYSON',
        help: 'PCI 7.3.1 — users_required + condition_pyson + sod_cannot_also + step_up_loa.', hijos: [
      _algo('first-applicable'),
      _ev('venta ≤ 10 000 BOB — aprobación simple', [
        _prop('sale.amount_total'),
        _op('<='),
        _val('10 000 BOB'),
        _ef('users_required = 1 · sin step-up'),
      ], verbo: 'approve'),
      _ev('venta 10 001–50 000 BOB — doble + WebAuthn', [
        _prop('sale.amount_total'),
        _op('BETWEEN'),
        _val('[10 001, 50 000] BOB'),
        _ef('users_required = 2 · step_up_loa = 3 (WebAuthn)'),
      ], verbo: 'approve'),
      _ev('pago > 5 000 BOB — SoD', [
        _prop('payment.amount'),
        _op('>'),
        _val('5 000 BOB'),
        _ef('sod_cannot_also: CREADOR ≠ APROBADOR · enforce en validación'),
      ], verbo: 'approve'),
      _ev('venta > 50 000 BOB — fuera del tier 2', [
        _prop('sale.amount_total'),
        _op('>'),
        _val('50 000 BOB'),
        _ef('DENY · HTTP 403 · "supera límite del rol" · no mostrar botón'),
      ], verbo: 'approve'),
    ]),

    NodoTemplate('record_rules', TipoNodo.politica, valor: 'CAPA 5 · filtros de fila',
        help: 'NIST 800-162 — filtro automático en CADA consulta.', hijos: [
      _algo('deny-overrides'),
      _ev('solo registros de su región', [
        _prop('record.territory_code'),
        _op('=='),
        _val('user.territory_code (VEN-NORTH-001)'),
        _ef('WHERE territory_code = :user_territory_code (inyectado automáticamente)'),
      ], verbo: 'read'),
      _ev('solo sus oportunidades propias', [
        _prop('record.owner_id'),
        _op('=='),
        _val('user.id'),
        _ef('WHERE owner_id = :user_id (inyectado automáticamente)'),
      ], verbo: 'read'),
      _ev('ventas del equipo (modo manager)', [
        _prop('record.salesperson_team_id'),
        _op('IN'),
        _val('user.managed_team_ids[]'),
        _ef('WHERE salesperson_team_id IN (:managed_teams) — combinado con OR anterior'),
      ], verbo: 'read'),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D2 · ACCESO FÍSICO
// ══════════════════════════════════════════════
NodoTemplate('D2 · ACCESO FÍSICO', TipoNodo.dominio,
    help: 'Acceso a espacios físicos, actuadores, hardware. ISO 27001 A.7 · NIST 800-116 · OSDP v2.2.', hijos: [
  NodoTemplate('B5 · Dominio físico', TipoNodo.bloque, hijos: [

    // ── Rama metodos D2 (§11.6 Manual-Metodos v1.1.0) ───────────
    NodoTemplate('metodos', TipoNodo.bloque,
        help: 'Rama de autenticación física de D2. Protocolos hardware: OSDP 2.2, ISO 14443, BLE 5.x. Traducción a JSON-RPC por bhnexus. Manual-Metodos §11.6.', hijos: [

      NodoTemplate('available_methods[]', TipoNodo.lista, valor: '5 métodos hardware',
          help: 'Pool de autenticadores físicos del rol. Todos operan vía bhnexus → OSDP 2.2. amr_value según RFC 8176.', hijos: [
        NodoTemplate('nfc_desfire', TipoNodo.objeto, help: 'NFC/RFID tap. ISO 14443-A/B MIFARE DESFire EV3. amr=hwk.', hijos: [
          _a('tipo', 'HARDWARE_BOUND'),
          _a('amr_value', 'hwk'),
          _a('protocolo', 'ISO 14443-A/B · MIFARE DESFire EV3'),
          _a('cifrado', 'AES-128 · mutua autenticación'),
          _en('loa', '2', ['1', '2', '3', '4']),
        ]),
        NodoTemplate('fingerprint_hash', TipoNodo.objeto, help: 'Sensor biométrico OSDP hardware. amr=fpt.', hijos: [
          _a('tipo', 'BIOMETRIC'),
          _a('amr_value', 'fpt'),
          _a('almacenamiento', 'Argon2id hash — NUNCA biométrico crudo'),
          _en('liveness', 'passive PAD', ['passive PAD', 'active PAD'],
              help: 'ISO 30107-3. passive = sin interacción del usuario.'),
          _a('fmr', '1:10 000 mínimo'),
          _en('loa', '3', ['1', '2', '3', '4'],
              help: 'Biométrico + posesión (sensor integrado en lector OSDP).'),
        ]),
        NodoTemplate('qr_dynamic', TipoNodo.objeto, help: 'QR dinámico acceso físico TTL=30s. amr=hwk.', hijos: [
          _a('tipo', 'HARDWARE_BOUND'),
          _a('amr_value', 'hwk'),
          _a('ttl_seconds', '30 (rotación automática — más corto que D1=10min)'),
          _a('binding', 'user_id + timestamp + HMAC-SHA256'),
          _en('loa', '2', ['1', '2', '3', '4']),
        ]),
        NodoTemplate('smartcard_x509', TipoNodo.objeto, help: 'SmartCard física PKCS#11 APDU local. amr=sc.', hijos: [
          _a('tipo', 'HARDWARE_BOUND'),
          _a('amr_value', 'sc'),
          _a('key_storage', 'hardware smartcard (PKCS#11)'),
          _a('protocolo', 'APDU ISO 7816 — diferente a mTLS TLS de D1'),
          _en('pin_required', 'true', ['true', 'false']),
          _en('loa', '4', ['1', '2', '3', '4'],
              help: 'hardware + conocimiento (PIN).'),
        ]),
        NodoTemplate('pin_pad', TipoNodo.objeto, help: 'PIN pad teclado de membrana OSDP. NUNCA factor único.', hijos: [
          _a('tipo', 'MEMORIZED_SECRET'),
          _a('amr_value', 'pin'),
          _a('min_digits', '6'),
          _a('nota', 'NUNCA factor único — combinar con nfc_desfire o fingerprint_hash'),
          _en('loa', '1', ['1', '2', '3', '4'],
              help: 'Conocimiento solo — factor débil en acceso físico.'),
        ]),
      ]),

      NodoTemplate('required_methods{}', TipoNodo.objeto,
          help: '4 sub-grupos ordenados para acceso físico. Eventos OSDP vía bhnexus. Manual-Metodos §11.7.', hijos: [

        NodoTemplate('primary_auth{}', TipoNodo.objeto,
            help: 'Orden=1. Factor primario físico — SIEMPRE ejecuta. Lector OSDP presenta credencial a bhnexus.', hijos: [
          _a('method_id', 'nfc_desfire | smartcard_x509 | qr_dynamic'),
          _en('min_loa', '2', ['1', '2', '3', '4'],
              help: 'AAL2 mínimo — acceso físico siempre requiere posesión verificada.'),
          NodoTemplate('condiciones', TipoNodo.politica,
              help: 'Cada eval selecciona el método físico primario según el nivel de seguridad de la zona.', hijos: [
            _ev('zonas estándar (security_level 1-2) → NFC', [
              _prop('zone.physical_security_level'),
              _op('BETWEEN'),
              _val('[1, 2]'),
              _ef('method = nfc_desfire · badge access · LoA 2'),
            ]),
            _ev('kiosco sin lector NFC → QR dinámico', [
              _prop('device.has_nfc_reader'),
              _op('=='),
              _val('false'),
              _ef('method = qr_dynamic · LoA 2 · TTL = 30 s'),
            ]),
          ]),
        ]),

        NodoTemplate('mfa_auth{}', TipoNodo.objeto,
            help: 'Orden=2. Factor adicional para zonas restringidas/críticas. security_level >= 3.', hijos: [
          _en('required_if', 'zone.physical_security_level >= 3',
              ['zone.physical_security_level >= 3', 'zone.physical_security_level >= 4', 'siempre']),
          NodoTemplate('eligible_methods[]', TipoNodo.lista, hijos: [
            _a('1 · fingerprint_hash', 'biométrico OSDP · security_level 3 · amr=fpt'),
            _a('2 · smartcard_x509', 'PKCS#11 físico · security_level 4 · amr=sc'),
            _a('3 · pin_pad', 'PIN OSDP · SOLO como 2.º factor (conocimiento) · amr=pin'),
          ]),
          NodoTemplate('condiciones', TipoNodo.politica,
              help: 'Cada eval selecciona el segundo factor físico según el nivel crítico de la zona.', hijos: [
            _ev('zona restringida (security_level 3) → biométrico', [
              _prop('zone.physical_security_level'),
              _op('=='),
              _val('3'),
              _ef('method = nfc_desfire + fingerprint_hash · LoA 3'),
            ]),
            _ev('zona crítica (security_level 4) → SmartCard + biométrico', [
              _prop('zone.physical_security_level'),
              _op('=='),
              _val('4'),
              _ef('method = smartcard_x509 + fingerprint_hash · LoA 4'),
            ]),
          ]),
        ]),

        NodoTemplate('step_up_triggers', TipoNodo.politica,
            help: 'Orden=3. Elevación física en tiempo real — alarma del controlador OSDP.', hijos: [
          _ev('anti-passback detectado → step-up biométrico', [
            _prop('event.dual_badge_sequence_detected'),
            _op('=='),
            _val('true'),
            _ef('required_additional = fingerprint_hash · alert CISO · log anti-passback'),
          ]),
          _ev('nivel de alerta AMBER o superior → máxima seguridad', [
            _prop('facility.alert_level'),
            _op('>='),
            _val('AMBER'),
            _ef('required_method = smartcard_x509 + fingerprint_hash · LoA 4'),
          ]),
        ]),

        NodoTemplate('re_auth_policy{}', TipoNodo.objeto,
            help: 'Orden=4. Re-verificación para sesiones físicas largas (visitas de proveedor, turno). NIST 800-116 §6.', hijos: [
          _a('max_session_minutes', '480', help: 'Sesión física máxima: 8h (turno laboral).'),
          _a('idle_minutes', '0', help: 'En acceso físico no aplica idle — la persona entra o sale.'),
          _a('reauth_interval_mins', '240', help: 'Re-verificación a las 4h para visitantes y proveedores.'),
          NodoTemplate('method_eligible[]', TipoNodo.lista, hijos: [
            _a('1 · nfc_desfire', 're-tap de tarjeta en torniquete de salida/entrada'),
            _a('2 · qr_dynamic', 'nuevo QR generado con TTL=30s'),
          ]),
        ]),
      ]),

      NodoTemplate('alternative_methods[]', TipoNodo.lista,
          help: 'Sustitutos físicos si el método primario falla (lector NFC sin red, sensor biométrico sucio).', hijos: [
        NodoTemplate('alt_nfc_por_qr', TipoNodo.objeto,
            help: 'Si el lector NFC no está disponible → QR dinámico de respaldo.', hijos: [
          _a('replaces', 'nfc_desfire'),
          _a('with', 'qr_dynamic'),
          _a('loa_change', 'none — mismo LoA 2'),
          _a('trigger', 'reader_offline OR nfc_hardware_fault'),
          _en('requires_approval', 'false', ['true', 'false']),
          _en('alert_on_use', 'true', ['true', 'false']),
          _a('max_uses', '5 consecutivos — luego requiere aprobación supervisor'),
        ]),
        NodoTemplate('alt_fingerprint_por_push', TipoNodo.objeto,
            help: 'Si sensor biométrico falla → Push desde app móvil como 2.º factor.', hijos: [
          _a('replaces', 'fingerprint_hash'),
          _a('with', 'push_notification_d1',
              help: 'Cruza a D1 para la verificación — bAuth coordina entre dominios.'),
          _a('loa_change', 'none — mismo LoA 3 (posesión del móvil + number matching)'),
          _a('trigger', 'biometric_sensor_fault OR finger_unreadable'),
          _en('requires_approval', 'true', ['true', 'false']),
          _en('alert_on_use', 'true', ['true', 'false']),
          _a('max_uses', '3 consecutivos — luego requiere mantenimiento del sensor'),
        ]),
        NodoTemplate('alt_emergencia_override', TipoNodo.objeto,
            help: 'Override de emergencia (evacuación, fallo de energía). AC-2(2) · ISO 27001 A.7.4.', hijos: [
          _a('replaces', 'todos los métodos'),
          _a('with', 'emergency_override_code'),
          _a('loa_change', 'degraded — LoA forzado · requiere doble autorización'),
          _en('requires_approval', 'true', ['true', 'false']),
          _a('max_uses', '1 (genera reporte automático a CISO)'),
          _en('alert_on_use', 'true', ['true', 'false']),
        ]),
      ]),
    ]),

    NodoTemplate('zones_access_rules', TipoNodo.politica,
        help: 'Decisión de acceso por zona. Default DENY implícito.', hijos: [
      _ev('zona ventas — acceso completo', [
        _prop('zone.id'),
        _op('=='),
        _val('PHY_ZONE_VENTAS'),
        _ef('access = FULL · audit_level = NORMAL · log entrada/salida'),
      ]),
      _ev('zona almacén — acceso temporizado', [
        _prop('zone.id'),
        _op('=='),
        _val('PHY_ZONE_ALMACEN'),
        _ef('access = TIMED · max_duration = 30 min · alert si supera tiempo'),
      ]),
      _ev('sala de servidores — denegado explícito', [
        _prop('zone.id'),
        _op('=='),
        _val('PHY_ROOM_SERVIDOR'),
        _ef('access = DENY · alert CISO · anula cualquier herencia del padre'),
      ]),
      _ev('cualquier zona no listada — default deny', [
        _prop('zone.id'),
        _op('NOT_IN'),
        _val('zones_access_rules[] (lista anterior)'),
        _ef('access = DENY · log intento · no alert (ruido)'),
      ]),
    ]),

    NodoTemplate('physical_security_controls', TipoNodo.politica,
        help: 'Controles físicos de seguridad presencial. NIST 800-116 §5.', hijos: [
      _ev('anti-passback — doble badge detectado', [
        _prop('event.dual_badge_sequence_detected'),
        _op('=='),
        _val('true'),
        _ef('DENY acceso + alert + log · reset anti-passback en 24 h'),
      ]),
      _ev('regla de dos personas — bóvedas', [
        _prop('zone.type'),
        _op('=='),
        _val('VAULT'),
        _ef('require concurrent_verified_presence >= 2 · DENY con solo 1'),
      ]),
      _ev('mantrap requerido', [
        _prop('zone.type'),
        _op('IN'),
        _val('[DATACENTER, VAULT, SERVER_ROOM]'),
        _ef('mantrap_required = true · DENY si mantrap no confirma salida anterior'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D3 · FINANCIERO
// ══════════════════════════════════════════════
NodoTemplate('D3 · FINANCIERO', TipoNodo.dominio,
    help: 'Operaciones económicas, límites, aprobaciones. PCI DSS 4.0 · ISO A.5.3 · NIST AC-5 · COBIT.', hijos: [
  NodoTemplate('B8 · Dominio financiero', TipoNodo.bloque, hijos: [

    NodoTemplate('requiredMethods_financial', TipoNodo.politica,
        help: 'Autenticación adicional para operaciones financieras. PCI DSS Req 8.', hijos: [
      _ev('operación financiera estándar (≤ 10 000 BOB)', [
        _prop('transaction.amount_bob'),
        _op('<='),
        _val('10 000 BOB'),
        _ef('flujo: LoA 2 existente suficiente · no step-up'),
      ]),
      _ev('operación financiera alto valor (> 10 000 BOB)', [
        _prop('transaction.amount_bob'),
        _op('>'),
        _val('10 000 BOB'),
        _ef('step-up: + webauthn_platform → LoA 3 · max_age = 300 s'),
      ]),
      _ev('operación financiera máxima (> 25 000 BOB)', [
        _prop('transaction.amount_bob'),
        _op('>'),
        _val('25 000 BOB'),
        _ef('step-up: + webauthn + totp_fresh(max_age=0) → LoA 3 + 2 aprobadores'),
      ]),
    ]),

    NodoTemplate('transaction_schedule', TipoNodo.politica,
        help: 'Ventanas horarias para transacciones financieras.', hijos: [
      _ev('días hábiles autorizados', [
        _prop('date.day_of_month'),
        _op('IN'),
        _val('[13,14,15,28,29,30,31]'),
        _ef('permitir transacción · DENY fuera de estos días (salvo override)'),
      ]),
      _ev('horario de operación', [
        _prop('time.hour_local'),
        _op('BETWEEN'),
        _val('[09:00, 16:00]'),
        _ef('permitir transacción · DENY fuera de ventana (salvo override)'),
      ]),
      _ev('fuera de ventana — DENY por defecto', [
        _prop('schedule.in_authorized_window'),
        _op('=='),
        _val('false'),
        _ef('DENY · "Fuera de ventana financiera" · log intento'),
      ]),
      _ev('override de emergencia', [
        _prop('override.requested_by_role'),
        _op('IN'),
        _val('[FINANCE_DIRECTOR, CEO]'),
        _ef('ventana +2 h · audit_level = CRITICAL · doble firma requerida'),
      ]),
    ]),

    NodoTemplate('transaction_limits', TipoNodo.objeto, help: 'PCI 7.3.1 · SOX §302.', hijos: [
      _a('currency', 'BOB'),
      _a('single_transaction_limit', '10 000'),
      _a('daily_limit', '50 000'),
      _a('monthly_limit', '200 000'),
      _a('requires_dual_approval_above', '10 000', help: '2 aprobadores distintos.'),
    ]),

    NodoTemplate('sod_rules', TipoNodo.politica, help: 'AC-5 · INCITS 359 SSD. Evaluado ANTES de guardar.', hijos: [
      _ev('crear venta ⊥ aprobar venta', [
        _prop('user.active_roles'),
        _op('INTERSECT'),
        _val('[ROL_CREADOR_VENTA, ROL_APROBADOR_VENTA]'),
        _ef('severity CRITICAL → DENY · alerta CISO · registro en audit_violations'),
      ]),
      _ev('crear pago ⊥ aprobar pago', [
        _prop('user.active_roles'),
        _op('INTERSECT'),
        _val('[ROL_CREADOR_PAGO, ROL_APROBADOR_PAGO]'),
        _ef('severity CRITICAL → DENY'),
      ]),
      _ev('facturar ⊥ auditar factura', [
        _prop('user.active_roles'),
        _op('INTERSECT'),
        _val('[ROL_FACTURADOR, ROL_AUDITOR_FACTURA]'),
        _ef('severity HIGH → DENY'),
      ]),
    ]),

    NodoTemplate('facturación Bolivia', TipoNodo.objeto,
        help: 'SIN RND 102100000011 §4-5 · Ley 164 Art. 78.', hijos: [
      _a('rnnd_emisor', 'NIT + código emisor SIN'),
      _en('modalidad', 'EN_LINEA', ['EN_LINEA', 'COMPUTARIZADA', 'MASIVA'],
        help: 'SIN RND 102100000011 §4-5.'),
      _en('firma_electronica_required', 'true', ['true', 'false'],
          help: 'Ley 164 Art. 78 — obligatoria para documentos legales.'),
      _a('contingencia_plan', 'modo offline + sincronización diferida ≤24 h'),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D4 · TEMPORAL
// ══════════════════════════════════════════════
NodoTemplate('D4 · TEMPORAL', TipoNodo.dominio,
    help: 'Ejes de tiempo del rol. GTRBAC · RFC 5545 · ISO 8601.', hijos: [
  NodoTemplate('B2 · Vigencia y ciclo de vida', TipoNodo.bloque, hijos: [
    NodoTemplate('validity_period', TipoNodo.objeto, help: 'ENUM role_validity_type.', hijos: [
      _en('type', 'FIXED',
          ['INDEFINITE', 'FIXED', 'PROJECT_BASED', 'TEMPORARY', 'EMERGENCY'],
          help: 'TEMPORARY = inextensible · EMERGENCY = 72h fijas AC-2(2).'),
      _a('start_date', '2026-01-01T00:00:00Z'),
      _a('end_date', '2027-12-31T23:59:59Z', help: 'null para INDEFINITE.'),
      _a('review_date', '2026-07-01T00:00:00Z', help: 'Alerta 30 días antes al role_owner.'),
    ]),
    NodoTemplate('renewal_settings', TipoNodo.politica,
        help: 'Anti privilege-creep. PCI 7.2.4.', hijos: [
      _ev('máximo de renovaciones', [
        _prop('role_assignment.renewal_count'),
        _op('>'),
        _val('2'),
        _ef('DENY renovación · "máximo de renovaciones alcanzado" · escalar a compliance'),
      ]),
      _ev('renovación automática — prohibida', [
        _prop('renewal.auto_renewal'),
        _op('=='),
        _val('true'),
        _ef('DENY configuración · auto_renewal siempre false para este rol'),
      ]),
      _ev('aprobadores válidos de renovación', [
        _prop('renewal.approver_role'),
        _op('NOT_IN'),
        _val('[DIRECTOR_VENTAS, COMPLIANCE_OFFICER]'),
        _ef('DENY renovación · "aprobador no autorizado"'),
      ]),
    ]),
    NodoTemplate('early_termination', TipoNodo.politica,
        help: 'Terminación anticipada. NIST AC-2i.', hijos: [
      _ev('aprobación requerida', [
        _prop('termination.approval_count'),
        _op('<'),
        _val('1'),
        _ef('DENY terminación · "requiere aprobación explícita"'),
      ]),
      _ev('aprobadores válidos', [
        _prop('termination.approver_role'),
        _op('NOT_IN'),
        _val('[DIRECTOR_VENTAS, HR_DIRECTOR]'),
        _ef('DENY · "aprobador no autorizado para terminación"'),
      ]),
      _ev('preaviso mínimo', [
        _prop('termination.notice_period_days'),
        _op('<'),
        _val('5'),
        _ef('DENY terminación inmediata · programar para fecha válida'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D5 · BIOMÉTRICO
// ══════════════════════════════════════════════
NodoTemplate('D5 · BIOMÉTRICO', TipoNodo.dominio,
    help: 'External-Path. ISO 30107-3 (PAD) · NIST 800-76-2.', hijos: [
  NodoTemplate('B5 · biometric_enrollment_policy', TipoNodo.politica, hijos: [
    _ev('modo de enrolamiento', [
      _prop('enrollment.mode'),
      _op('NOT_IN'),
      _val('[hybrid]',
          help: 'Único modo válido: hybrid — usuario registra biométrico, admin aprueba.'),
      _ef('DENY enrolamiento · require modo hybrid: usuario registra + admin aprueba'),
    ]),
    _ev('detección de vida requerida', [
      _prop('enrollment.liveness_check'),
      _op('=='),
      _val('false'),
      _ef('DENY enrolamiento sin liveness · ISO 30107-3 PAD nivel 2'),
    ]),
    _ev('algoritmo de hash biométrico', [
      _prop('credential.hash_algorithm'),
      _op('NOT_IN'),
      _val('[Argon2id(t>=3,m>=64MB,p>=2)]'),
      _ef('DENY enrolamiento · algoritmo no conforme (OWASP ASVS 2.4.3)'),
    ]),
    _ev('umbral FMR LoA 2', [
      _prop('biometric.false_match_rate'),
      _op('>'),
      _val('1:10 000'),
      _ef('DENY enrolamiento para LoA 2 · recalibrar sensor'),
    ]),
    _ev('umbral FMR LoA 3', [
      _prop('biometric.false_match_rate'),
      _op('>'),
      _val('1:100 000'),
      _ef('DENY uso en zona security_level >= 3 · sensor insuficiente'),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D6 · GEOESPACIAL
// ══════════════════════════════════════════════
NodoTemplate('D6 · GEOESPACIAL', TipoNodo.dominio,
    help: 'Única fuente de verdad geoespacial. NIST 800-207 §3.2 · 800-162 · LBAC.', hijos: [
  NodoTemplate('B15 · geospatial_policy', TipoNodo.bloque, hijos: [

    NodoTemplate('allowed_locations[]', TipoNodo.lista,
        help: 'Lista única de ubicaciones autorizadas (consolida B4+B8).', hijos: [
      NodoTemplate('office', TipoNodo.objeto, hijos: [
        _a('cidr', '192.168.1.0/24'),
        _en('security_level', '2', ['1', '2', '3', '4'],
            help: '1=público · 2=interno · 3=restringido · 4=crítico.'),
        _en('vpn_required', 'false', ['true', 'false']),
        _en('gps_attestation_required', 'false', ['true', 'false']),
      ]),
      NodoTemplate('vpn_remoto', TipoNodo.objeto, hijos: [
        _a('cidr', '10.8.0.0/16'),
        _en('security_level', '2', ['1', '2', '3', '4']),
        _en('vpn_required', 'true', ['true', 'false']),
        _en('gps_attestation_required', 'false', ['true', 'false']),
      ]),
      NodoTemplate('home_office', TipoNodo.objeto, hijos: [
        _a('cidr', 'any (sin restricción de red)'),
        _en('security_level', '1', ['1', '2', '3', '4']),
        _en('vpn_required', 'true', ['true', 'false']),
        _en('gps_attestation_required', 'true', ['true', 'false'],
            help: 'Precisión GPS requerida: ≤ 500 m.'),
        _en('financial_ops', 'DENY', ['PERMIT', 'DENY'],
            help: 'Operaciones financieras solo desde office/vpn.'),
      ]),
    ]),

    NodoTemplate('validation_rules', TipoNodo.politica, hijos: [
      NodoTemplate('VPN requerida en remoto', TipoNodo.regla, hijos: [
        _ev('conexión remota', [_prop('connection.type'), _op('=='), _val('REMOTE')]),
        _olo('AND'),
        _ev('VPN inactiva', [_prop('connection.vpn_active'), _op('=='), _val('false')]),
        _ef('DENY acceso · "VPN requerida para acceso remoto"'),
      ]),
      NodoTemplate('attestation GPS en roaming', TipoNodo.regla, hijos: [
        _ev('usuario en roaming', [_prop('location.roaming'), _op('=='), _val('true')]),
        _olo('AND'),
        _ev('precisión GPS insuficiente', [
          _prop('gps_attestation.accuracy_meters'),
          _op('>'),
          _val('500', help: 'Tolerancia: ≤500 m requeridos para attestation válida.'),
        ]),
        _ef('DENY · "Precisión GPS insuficiente (requerido: ≤500 m)"'),
      ]),
      _ev('velocidad imposible (suplantación de ubicación)', [
        _prop('location.velocity_km_h'),
        _op('>'),
        _val('1 200', help: 'Tolerancia 10 km. Físicamente imposible.'),
        _ef('DENY + alert CISO + session.revoke (CAEP session-revoked)'),
      ]),
      NodoTemplate('operación financiera desde home_office', TipoNodo.regla, hijos: [
        _ev('acceso desde home_office', [_prop('location.type'), _op('=='), _val('home_office')]),
        _olo('AND'),
        _ev('zona financiera', [_prop('action.zone'), _op('STARTS_WITH'), _val('zone_financial')]),
        _ef('DENY · "Operaciones financieras requieren red segura"'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D7 · RED
// ══════════════════════════════════════════════
NodoTemplate('D7 · RED', TipoNodo.dominio,
    help: 'External-Path (vía gateway Kong). NIST 800-207 §2.2 · IEEE 802.1X · RFC 8705.', hijos: [
  NodoTemplate('B16 · network_access', TipoNodo.bloque, hijos: [
    _en('zero_trust_mode', 'true', ['true', 'false'],
        help: 'Nunca confiar, siempre verificar. NIST 800-207.'),
    _en('device_compliance_required', 'true', ['true', 'false'],
        help: 'Postura verificada por PEP del gateway en cada request.'),
    NodoTemplate('device_compliance_checks', TipoNodo.politica,
        help: 'Postura del dispositivo evaluada en cada request. NIST 800-207 §3.3.', hijos: [
      _ev('sistema operativo parcheado', [
        _prop('device.os_patch_status'),
        _op('=='),
        _val('CURRENT', help: 'Parches del OS actualizados.'),
        _ef('DENY acceso desde dispositivo desactualizado · "Device compliance failed"'),
      ]),
      _ev('antivirus activo', [
        _prop('device.antivirus_active'),
        _op('=='),
        _val('true'),
        _ef('DENY si antivirus inactivo o sin actualizar'),
      ]),
      _ev('cifrado en reposo', [
        _prop('device.storage_encrypted'),
        _op('=='),
        _val('true', help: 'BitLocker / FileVault / LUKS.'),
        _ef('DENY si disco no cifrado'),
      ]),
      _ev('firewall de host activo', [
        _prop('device.host_firewall_active'),
        _op('=='),
        _val('true'),
        _ef('DENY si firewall local inactivo'),
      ]),
      _ev('dispositivo gestionado (MDM)', [
        _prop('device.mdm_enrolled'),
        _op('=='),
        _val('true'),
        _ef('DENY dispositivo no gestionado para acceso a zonas CONFIDENTIAL'),
      ]),
    ]),
    NodoTemplate('allowed_ranges[]', TipoNodo.lista, hijos: [
      _a('office', '192.168.1.0/24'),
      _a('vpn', '10.8.0.0/16'),
      _a('datacenter_internal', '172.16.0.0/12'),
    ]),
    _en('mtls_required', 'true', ['true', 'false'],
        help: 'Certificado de cliente por request. RFC 8705.'),
    NodoTemplate('api_gateway_rules', TipoNodo.politica, hijos: [
      _ev('rate limit por minuto', [
        _prop('request.rate_per_minute'),
        _op('>'),
        _val('300'),
        _ef('HTTP 429 Too Many Requests · Retry-After header'),
      ]),
      _ev('origen no autorizado', [
        _prop('request.source_cidr'),
        _op('NOT_IN'),
        _val('allowed_ranges[]'),
        _ef('HTTP 403 Forbidden · log intento'),
      ]),
      _ev('mTLS inválido o ausente', [
        _prop('connection.client_cert_valid'),
        _op('=='),
        _val('false'),
        _ef('HTTP 401 Unauthorized · "Client certificate required (RFC 8705)"'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D8 · CONTEXTO / SESIÓN
// ══════════════════════════════════════════════
NodoTemplate('D8 · CONTEXTO / SESIÓN', TipoNodo.dominio,
    help: 'Pre-BitMask (¿ctx_id vivo?). Evaluación continua. NIST 800-207 §2.1 · RFC 9470 · CAEP 1.0.', hijos: [
  NodoTemplate('B17 · adaptive_context', TipoNodo.bloque, hijos: [

    NodoTemplate('risk_engine', TipoNodo.politica, hijos: [
      _ev('modo de evaluación continua', [
        _prop('risk.evaluation_mode'),
        _op('=='),
        _val('CONTINUOUS', help: 'No solo en login — cada N segundos o en cada request.'),
        _ef('evaluar risk.score en cada request crítico'),
      ]),
      _ev('revocar sesión en anomalía', [
        _prop('risk.anomaly_detected'),
        _op('=='),
        _val('true'),
        _ef('CAEP: session-revoked · session.revoke · notify usuario'),
      ]),
    ]),

    NodoTemplate('context_signals', TipoNodo.lista,
        help: 'Señales de contexto evaluadas por el motor de riesgo. NIST 800-207 §3.3 · CAEP 1.0.', hijos: [
      NodoTemplate('device_posture', TipoNodo.objeto, help: 'Estado del dispositivo.', hijos: [
        _a('propiedad', 'device.patch_status, device.antivirus_active, device.storage_encrypted'),
        _a('evaluación', 'NIST 800-207 §3.3 — todos deben ser true/CURRENT'),
        _a('peso_riesgo', '+0.20 al score si alguno falla'),
      ]),
      NodoTemplate('user_behavior', TipoNodo.objeto, help: 'Comportamiento inusual del usuario.', hijos: [
        _a('propiedad', 'request.hour_local, request.volume_per_hour, typing_pattern'),
        _a('evaluación', 'desviación > 2σ respecto a baseline del usuario'),
        _a('peso_riesgo', '+0.15 al score'),
      ]),
      NodoTemplate('threat_intel', TipoNodo.objeto, help: 'Inteligencia de amenazas.', hijos: [
        _a('propiedad', 'request.source_ip, credential.hash'),
        _a('evaluación', 'IP en lista negra MISP/STIX · credential en HaveIBeenPwned'),
        _a('peso_riesgo', '+0.40 al score (muy alto)'),
      ]),
      NodoTemplate('impossible_travel', TipoNodo.objeto, help: 'Viaje físicamente imposible.', hijos: [
        _a('propiedad', 'session.location_delta_km / session.time_delta_hours'),
        _a('evaluación', 'velocidad > 1 200 km/h (tolerancia 10 km)'),
        _a('peso_riesgo', '+0.50 al score (crítico)'),
      ]),
      NodoTemplate('new_device', TipoNodo.objeto, help: 'Dispositivo no visto antes.', hijos: [
        _a('propiedad', 'device.fingerprint IN user.known_devices[]'),
        _a('evaluación', 'false = dispositivo nuevo'),
        _a('peso_riesgo', '+0.25 al score'),
      ]),
      NodoTemplate('credential_change_event', TipoNodo.objeto, help: 'Señal CAEP: credential-change.', hijos: [
        _a('propiedad', 'caep.event_type'),
        _a('evaluación', 'credential-change detectado en otro sistema federado'),
        _a('peso_riesgo', '+0.35 al score'),
      ]),
    ]),

    NodoTemplate('adaptive_policies', TipoNodo.politica, hijos: [
      _ev('riesgo moderado — step-up', [
        _prop('risk.score'),
        _op('BETWEEN'),
        _val('[0.50, 0.70]'),
        _ef('require step-up LoA 3 · continuar si pasa'),
      ]),
      _ev('riesgo alto — step-up + reducción de privilegios', [
        _prop('risk.score'),
        _op('BETWEEN'),
        _val('[0.70, 0.90]'),
        _ef('required_loa = 3 · scope_reduction = [quitar APPROVE, CONFIGURE] · notify role_owner'),
      ]),
      _ev('riesgo crítico — bloqueo', [
        _prop('risk.score'),
        _op('>'),
        _val('0.90'),
        _ef('DENY + session.revoke + alert CISO + account.flag_for_review'),
      ]),
    ]),

    NodoTemplate('emergency_access', TipoNodo.politica, help: 'Break-glass. Auditoría crítica.', hijos: [
      _ev('doble aprobación requerida', [
        _prop('emergency.distinct_approvals'),
        _op('<'),
        _val('2'),
        _ef('DENY acceso de emergencia · "Requiere 2 aprobaciones distintas"'),
      ]),
      _ev('duración máxima', [
        _prop('emergency.session_duration_hours'),
        _op('>'),
        _val('4'),
        _ef('force_logout automático · no renovable'),
      ]),
      _ev('nivel de auditoría', [
        _prop('audit.event_level'),
        _op('=='),
        _val('CRITICAL'),
        _ef('TODA acción registrada con ctx_id · syslog Wazuh · retención 7 años'),
      ]),
      _ev('notificación inmediata', [
        _prop('emergency.notification_sent'),
        _op('=='),
        _val('false'),
        _ef('bNotify.send([CISO, CEO, COMPLIANCE]) inmediatamente al activar'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D9 · CREDENCIALES
// ══════════════════════════════════════════════
NodoTemplate('D9 · CREDENCIALES', TipoNodo.dominio,
    help: 'Pre-BitMask (¿LoA suficiente?). NIST 800-63B-4 §6 · ISO 24760-2 §7 · OWASP ASVS §2.', hijos: [
  NodoTemplate('B18 · credential_lifecycle', TipoNodo.bloque, hijos: [

    // ── Política de contraseña (NUEVO — NIST 800-63B-4) ──────
    NodoTemplate('password_policy', TipoNodo.politica,
        help: 'Política de contraseñas conforme NIST SP 800-63B-4 (2024). Sin complejidad forzada.', hijos: [
      _ev('longitud mínima (factor único)', [
        _prop('password.length'),
        _op('<'),
        _val('15', help: 'NIST 800-63B-4 §5.1.1.1 — 15 chars si es el único factor.'),
        _ef('DENY · "Mínimo 15 caracteres (contraseña única)"'),
      ]),
      NodoTemplate('longitud mínima (con MFA adicional)', TipoNodo.regla, hijos: [
        _ev('MFA enrollado', [_prop('session.mfa_enrolled'), _op('=='), _val('true')]),
        _olo('AND'),
        _ev('contraseña muy corta', [
          _prop('password.length'),
          _op('<'),
          _val('8', help: 'Con MFA adicional el mínimo baja a 8 chars según 800-63B-4.'),
        ]),
        _ef('DENY · "Mínimo 8 caracteres (con MFA presente)"'),
      ]),
      _ev('longitud máxima', [
        _prop('password.length'),
        _op('>'),
        _val('64 (máximo aceptado)',
            help: 'Sistema DEBE soportar ≥64 chars para passphrases (800-63B-4).'),
        _ef('DENY · "Máximo 64 caracteres" — ampliar si el sistema lo soporta'),
      ]),
      _ev('contraseña comprometida (breach check)', [
        _prop('password.in_breached_list'),
        _op('=='),
        _val('true', help: 'Screening contra listas HIBP o equivalente. Obligatorio (800-63B-4).'),
        _ef('DENY · "Contraseña encontrada en base de datos de filtraciones — elige otra"'),
      ]),
      _ev('historial — reutilización prohibida', [
        _prop('password.in_history_last_N'),
        _op('=='),
        _val('true (últimas 5 contraseñas)'),
        _ef('DENY · "No reutilices contraseñas recientes"'),
      ]),
      _ev('reglas de complejidad forzada — PROHIBIDAS', [
        _prop('password_policy.complexity_rules_enforced'),
        _op('=='),
        _val('true'),
        _ef('DENY configuración · NIST 800-63B-4 eliminó complejidad forzada'),
      ]),
      _ev('rotación periódica forzada — PROHIBIDA', [
        _prop('password_policy.periodic_rotation_days'),
        _op('IS_SET'),
        _val('(cualquier valor periódico)'),
        _ef('DENY configuración · NIST 800-63B-4 eliminó rotación periódica'),
      ]),
      NodoTemplate('hints y preguntas de seguridad — PROHIBIDOS', TipoNodo.regla, hijos: [
        _ev('hints habilitados', [_prop('password_policy.hints_enabled'), _op('=='), _val('true')]),
        _olo('OR'),
        _ev('preguntas de seguridad habilitadas', [
          _prop('password_policy.security_questions_enabled'),
          _op('=='),
          _val('true'),
        ]),
        _ef('DENY configuración · NIST 800-63B-4 §5.1.1.2 los prohíbe'),
      ]),
    ]),

    NodoTemplate('enrollment_policy', TipoNodo.politica, help: 'Condiciones de enrolamiento. 800-63B-4 §6.1.2.', hijos: [
      _ev('nivel de proofing de identidad', [
        _prop('identity_proofing.level'),
        _op('NOT_IN'),
        _val('[IAL1, IAL2, IAL3]'),
        _ef('DENY enrolamiento · nivel IAL inválido'),
      ]),
      _ev('aprobación requerida', [
        _prop('enrollment.approval_count'),
        _op('<'),
        _val('1'),
        _ef('DENY enrolamiento · requiere aprobación explícita del administrador'),
      ]),
      _ev('tipo de binding válido', [
        _prop('credential.binding_type'),
        _op('NOT_IN'),
        _val('[PASSKEY, X509_SMARTCARD, TOTP, WEBAUTHN]'),
        _ef('DENY · tipo de binding no reconocido'),
      ]),
    ]),

    NodoTemplate('rotation_policy', TipoNodo.politica, help: 'NIST 800-63B-4: sin rotación periódica.', hijos: [
      _ev('rotación por brecha detectada', [
        _prop('credential.breach_detected'),
        _op('=='),
        _val('true'),
        _ef('rotación inmediata obligatoria · notify usuario · invalidar sesiones activas'),
      ]),
      _ev('vigencia X.509 vencida', [
        _prop('cert.days_until_expiry'),
        _op('<='),
        _val('30', help: 'Renovar 30 días antes de expirar.'),
        _ef('alert role_owner · bloquear operaciones requirentes de X.509 si expira'),
      ]),
      _ev('vigencia X.509 expirada', [
        _prop('cert.is_expired'),
        _op('=='),
        _val('true'),
        _ef('DENY uso del certificado · renovación obligatoria antes de continuar'),
      ]),
    ]),

    NodoTemplate('revocation_policy', TipoNodo.politica, hijos: [
      _ev('tiempo máximo de propagación', [
        _prop('revocation.propagation_elapsed_seconds'),
        _op('>'),
        _val('30'),
        _ef('alert SRE · "Revocación no propagada en tiempo (SLA 30 s)"'),
      ]),
      _ev('período de gracia', [
        _prop('revocation.grace_period_days'),
        _op('>'),
        _val('7'),
        _ef('DENY configuración · gracia máxima 7 días'),
      ]),
      _ev('propagación a todos los sistemas', [
        _prop('revocation.propagated_to'),
        _op('NOT_INCLUDES_ALL'),
        _val('[vault, gateway_kong, cache_redis, session_store]'),
        _ef('alert SRE · "Propagación incompleta" · reintento automático cada 5 s'),
      ]),
    ]),

    NodoTemplate('privilege_creep_detection', TipoNodo.politica, hijos: [
      _ev('período de revisión vencido', [
        _prop('permission.days_since_last_review'),
        _op('>'),
        _val('90'),
        _ef('alert role_owner + compliance · programar revisión obligatoria'),
      ]),
      _ev('umbral de permisos no usados', [
        _prop('permission.unused_ratio'),
        _op('>='),
        _val('0.30', help: '30 % de permisos sin uso en 90 días → privilege creep.'),
        _ef('alert role_owner + compliance_officer · flag account.privilege_creep_suspected'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D10 · DELEGACIÓN
// ══════════════════════════════════════════════
NodoTemplate('D10 · DELEGACIÓN', TipoNodo.dominio,
    help: 'Policy-Path (reducción AND). INCITS 359 §4.2 · NIST AC-6(3) · RFC 8693.', hijos: [
  NodoTemplate('B10 · Delegación (DSD)', TipoNodo.bloque, hijos: [
    _en('can_delegate', 'true', ['true', 'false']),
    _a('max_duration_days', '21', help: 'Jamás permanente. auto_revoke_on_expiry (ISO A.5.17).'),
    _a('max_concurrent_delegations', '1', help: 'Máx. profundidad 2 encadenada.'),
    _a('delegable_to_roles[]', '["VEN-JUNIOR-001","VEN-TRAINEE-001"]',
        help: 'Solo roles inferiores — jamás hacia arriba (AC-6(3)).'),

    NodoTemplate('non_delegable_permissions', TipoNodo.politica,
        help: 'Lista negra absoluta de delegación (AC-6(3)). Ninguna excepción.', hijos: [
      _ev('aprobación de ventas — no delegable', [
        _prop('delegation.permission'),
        _op('=='),
        _val('zone_financial/ventas:APPROVE'),
        _ef('DENY delegación · alert si intento · severity HIGH · log en audit_violations'),
      ]),
      _ev('administración de usuarios — no delegable', [
        _prop('delegation.permission'),
        _op('=='),
        _val('zone_admin/usuarios:CONFIGURE'),
        _ef('DENY delegación · "Permiso no delegable"'),
      ]),
      _ev('configuración de reportes — no delegable', [
        _prop('delegation.permission'),
        _op('=='),
        _val('zone_admin/reportes:CONFIGURE'),
        _ef('DENY delegación'),
      ]),
      _ev('delegación hacia rol superior — prohibida', [
        _prop('delegation.target_role.hierarchy_level'),
        _op('<'),
        _val('hierarchy_level del delegante'),
        _ef('DENY · "No se puede delegar a roles de nivel superior (anti-escalada)"'),
      ]),
    ]),
  ]),

  NodoTemplate('B11 · Grupos y jerarquías (RBAC1)', TipoNodo.bloque,
      help: 'Herencia y grupos. INCITS 359 §3.2 RBAC1.', hijos: [
    NodoTemplate('role_hierarchy', TipoNodo.objeto, hijos: [
      _a('hierarchy_level', '2'),
      _a('parent_role', 'VEN-BASE-001'),
      _a('child_roles', '["VEN-JUNIOR-001","VEN-TRAINEE-001"]'),
      _a('bits_removed_from_parent', '["APPROVE_HIGH_VALUE","CONFIGURE_SYSTEM","AUDIT_FINANCIAL"]',
          help: 'hijo = padre BitMask AND NOT(removidos). NUNCA hijo obtiene más que padre.'),
      _en('inheritance_mode', 'AND_NOT', ['AND_NOT', 'AND', 'OR'],
        help: 'INCITS 359 §4.1. AND_NOT = hijo = padre BitMask AND NOT(removidos).'),
    ]),
    NodoTemplate('role_groups[]', TipoNodo.lista, hijos: [
      NodoTemplate('VENTAS_REGIONALES', TipoNodo.objeto, hijos: [
        _a('tipo', 'FUNCTIONAL'),
        _a('quorum_required', '2-de-N para alto valor'),
        _a('members_scope', 'todos los VEN-RGV del tenant'),
      ]),
      NodoTemplate('COMITE_VENTAS', TipoNodo.objeto, hijos: [
        _a('tipo', 'POLICY'),
        _a('quorum_required', '3-de-N para cambios de política'),
        _a('base', 'AC-2g · PCI 7.2.5 — aprobación k-de-n'),
      ]),
    ]),
  ]),

  NodoTemplate('B12 · Gestión de conflictos (SSD/SoD)', TipoNodo.bloque,
      help: 'INCITS 359 SSD · AC-5.', hijos: [
    NodoTemplate('incompatible_roles', TipoNodo.politica, hijos: [
      _ev('gerente ventas ⊥ auditor financiero', [
        _prop('user.concurrent_roles'),
        _op('INTERSECT'),
        _val('[ROL_GERENTE_VENTAS, ROL_AUDITOR_FINANCIERO]'),
        _ef('severity CRITICAL → DENY + alerta CISO + log audit_violations'),
      ]),
      _ev('creador venta ⊥ aprobador venta', [
        _prop('user.concurrent_roles'),
        _op('INTERSECT'),
        _val('[ROL_CREADOR_VENTA, ROL_APROBADOR_VENTA]'),
        _ef('severity CRITICAL → DENY'),
      ]),
    ]),
    NodoTemplate('conflict_validation', TipoNodo.politica, hijos: [
      _ev('tiempo de evaluación', [
        _prop('conflict.evaluation_timing'),
        _op('!='),
        _val('REAL_TIME'),
        _ef('DENY configuración · evaluación batch nocturna no aceptada — debe ser REAL_TIME'),
      ]),
      _ev('alcance de verificación incompleto', [
        _prop('conflict.check_scope'),
        _op('NOT_INCLUDES_ALL'),
        _val('[DIRECT, INHERITED, DELEGATED]'),
        _ef('DENY configuración · alcance incompleto detectado'),
      ]),
    ]),
    NodoTemplate('interest_conflicts', TipoNodo.politica, help: 'SOX §302.', hijos: [
      _ev('parentesco prohibido', [
        _prop('user.supervisor_relationship_degree'),
        _op('<='),
        _val('2', help: '1=padres/hijos · 2=hermanos/abuelos/nietos.'),
        _ef('alert compliance_officer · bloquear subordinación directa · declaración obligatoria'),
      ]),
      _ev('declaración de conflicto vencida', [
        _prop('conflict_declaration.days_since_last_submitted'),
        _op('>'),
        _val('365'),
        _ef('alert role_owner + compliance · suspender acceso a zonas financial hasta renovar'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D11 · AUDITORÍA
// ══════════════════════════════════════════════
NodoTemplate('D11 · AUDITORÍA', TipoNodo.dominio,
    help: 'Post-hoc (registra, no decide). ISO A.8.15 · RGPD Art. 30 · SOX §404 · PCI Req 10.', hijos: [
  NodoTemplate('B13 · Cumplimiento y auditoría', TipoNodo.bloque, hijos: [
    _en('review_frequency', 'QUARTERLY',
        ['MONTHLY', 'QUARTERLY', 'SEMIANNUAL', 'ANNUAL'],
        help: 'PCI 7.2.4. Frecuencia de revisión de accesos del rol.'),
    NodoTemplate('review_scope[]', TipoNodo.lista, hijos: [
      _a('accesos_logicos', 'entradas/salidas · intentos fallidos'),
      _a('uso_permisos_efectivos', 'qué permisos se usaron realmente (vs asignados)'),
      _a('delegaciones_activas', 'delegaciones vigentes y su uso'),
      _a('violaciones_sod', 'intentos bloqueados por Conflict Matrix'),
      _a('transacciones_financieras', 'todas las ops financieras con monto y aprobador'),
      _a('cambios_de_rol', 'altas/bajas/modificaciones de asignaciones'),
    ]),
    NodoTemplate('reviewers[]', TipoNodo.lista, help: 'Tres líneas de defensa.', hijos: [
      _a('linea_1_negocio', 'DIRECTOR_VENTAS'),
      _a('linea_2_compliance', 'COMPLIANCE_OFFICER'),
      _a('linea_3_auditoria', 'INTERNAL_AUDITOR'),
    ]),
    NodoTemplate('regulatory_frameworks', TipoNodo.objeto, hijos: [
      _a('PCI_DSS_4_0', 'Req 7/8/10 · revisión anual certificación QSA'),
      _a('RGPD', 'Art. 30 registro actividades · retention 365 d · DPO notificación'),
      _a('SOX', '§302 CEO/CFO · §404 control interno · evidencia 7 años'),
      _a('ISO_27001_2022', 'A.8.15 logging · A.5.15 access control · revisión semestral'),
      _a('Ley_164_Bolivia', 'firma digital · registros electrónicos · validez jurídica'),
    ]),
    NodoTemplate('change_tracking', TipoNodo.politica, hijos: [
      _ev('eventos de auditoría obligatorios', [
        _prop('audit.event_type'),
        _op('IN'),
        _val('[PERMISSIONS, AUTH_METHODS, DELEGATIONS, FINANCIAL_LIMITS, ROLE_ASSIGNMENT, LOGIN_FAILED, SoD_VIOLATION]'),
        _ef('log inmutable WORM · syslog Wazuh · no purga sin aprobación CISO'),
      ]),
      _ev('retención de registros', [
        _prop('audit.retention_years'),
        _op('<'),
        _val('7', help: 'ISO 27001 + SOX §404.'),
        _ef('DENY purga · "Retención mínima 7 años"'),
      ]),
      _ev('integridad del log (hash-chain)', [
        _prop('audit_log.hash_chain_valid'),
        _op('=='),
        _val('false'),
        _ef('ALERT CISO · "Posible manipulación de logs" · investigación forense'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D12 · BLOCKCHAIN / ANCLAJE
// ══════════════════════════════════════════════
NodoTemplate('D12 · BLOCKCHAIN / ANCLAJE', TipoNodo.dominio,
    help: 'External-Path. Besu QBFT · ECDSA secp256k1 · EIP-155.', hijos: [
  NodoTemplate('B19 · blockchain_access', TipoNodo.bloque, hijos: [
    _en('enabled', 'false', ['true', 'false'],
        help: 'Default cerrado — habilitado solo para roles con operaciones blockchain.'),
    _a('network', 'Besu QBFT · chain_id configurable', help: 'Acceso SIEMPRE vía daemon bnexus.'),
    NodoTemplate('signing_config', TipoNodo.politica, hijos: [
      _ev('algoritmo de firma', [
        _prop('signing.algorithm'),
        _op('=='),
        _val('ECDSA secp256k1', help: 'EIP-155 · estándar Besu QBFT.'),
        _ef('DENY firma con algoritmo no conforme · usar solo secp256k1'),
      ]),
      _ev('almacenamiento de clave', [
        _prop('signing.key_storage_location'),
        _op('NOT_IN'),
        _val('[vault_kv_path_por_rol]'),
        _ef('DENY · "Clave no encontrada en Vault para este rol"'),
      ]),
      _ev('acceso directo a nodo blockchain', [
        _prop('signing.direct_node_access'),
        _op('=='),
        _val('true'),
        _ef('DENY · "Acceso SIEMPRE vía daemon bnexus — jamás directo al nodo"'),
      ]),
    ]),
    NodoTemplate('smart_contract_permissions', TipoNodo.politica, hijos: [
      _ev('método no autorizado', [
        _prop('contract.method_name'),
        _op('NOT_IN'),
        _val('[AuditLog.appendEntry]', help: 'Solo append-only — WORM.'),
        _ef('DENY · "Método de contrato no autorizado para este rol"'),
      ]),
      _ev('modo write que no sea append', [
        _prop('contract.access_mode'),
        _op('!='),
        _val('APPEND_ONLY'),
        _ef('DENY · "Solo se permite append-only — no modificar ni borrar entradas"'),
      ]),
    ]),
    NodoTemplate('wallet_policy', TipoNodo.politica, hijos: [
      _ev('wallet comprometida', [
        _prop('wallet.compromised_flag'),
        _op('=='),
        _val('true'),
        _ef('rotación inmediata en Vault · invalidar todas las txs pendientes · alert CISO'),
      ]),
      _ev('valor de transacción blockchain', [
        _prop('blockchain.transaction_value'),
        _op('>'),
        _val('B8.transaction_limits.single_transaction_limit (enlace a D3)'),
        _ef('DENY · supera límite financiero del rol — requiere tier superior'),
      ]),
    ]),
  ]),
]),

// ══════════════════════════════════════════════
// D13 · FIRMA DIGITAL EXTERNA
// ══════════════════════════════════════════════
NodoTemplate('D13 · FIRMA DIGITAL EXTERNA', TipoNodo.dominio,
    help: 'Firma legal SIN blockchain (ADSIB). Ley 164 Art. 78 · ADSIB-FD-POLT-015 v2.3.', hijos: [
  NodoTemplate('B20 · legal_signature_policy', TipoNodo.bloque, hijos: [
    _en('enabled', 'false', ['true', 'false'],
        help: 'Default cerrado — habilitado solo cuando la operación requiere firma legal.'),
    NodoTemplate('operations_requiring_legal_signature[]', TipoNodo.lista, hijos: [
      NodoTemplate('aprobacion_venta_alto_valor', TipoNodo.objeto, hijos: [
        _a('zona', 'zone_financial/ventas:APPROVE'),
        _a('umbral', '> 25 000 BOB'),
        _a('motor_firma', 'EXTERNAL_ADSIB (RSA-SHA256)'),
      ]),
      NodoTemplate('firma_contratos_legales', TipoNodo.objeto, hijos: [
        _a('zona', 'zone_legal/contratos:SIGN'),
        _a('umbral', 'siempre (todo contrato)'),
        _a('motor_firma', 'EXTERNAL_ADSIB (RSA-SHA256)'),
      ]),
      NodoTemplate('emision_facturas_criticas', TipoNodo.objeto, hijos: [
        _a('zona', 'zone_financial/facturas:EMIT'),
        _a('umbral', '> 50 000 BOB'),
        _a('motor_firma', 'INTERNAL (EdDSA Ed25519) + sello_tiempo'),
      ]),
    ]),
    _en('required_engine', 'INTERNAL',
        ['INTERNAL', 'EXTERNAL_ADSIB', 'INTERNAL+SELLO_TIEMPO'],
        help: 'INTERNAL=Ed25519/Vault · EXTERNAL_ADSIB=RSA-SHA256/Ley164.'),
    NodoTemplate('certificate_requirements', TipoNodo.politica, hijos: [
      _ev('tipo de certificado', [
        _prop('cert.policy_type'),
        _op('NOT_IN'),
        _val('[ADSIB-FD-POLT-015 v2.3, CA_TRUSTED_LIST_BOLIVIA]'),
        _ef('DENY firma · "Certificado emitido por CA no reconocida en Bolivia"'),
      ]),
      NodoTemplate('vigencia del certificado', TipoNodo.regla, hijos: [
        _ev('certificado expirado', [_prop('cert.is_expired'), _op('=='), _val('true')]),
        _olo('OR'),
        _ev('certificado revocado', [_prop('cert.revoked'), _op('=='), _val('true')]),
        _ef('DENY firma · validar contra OCSP/CRL de ADSIB en tiempo real'),
      ]),
      _ev('emisor autorizado', [
        _prop('cert.issuer'),
        _op('NOT_IN'),
        _val('[ADSIB, CA_TRUSTED_LIST_BOLIVIA]'),
        _ef('DENY firma · "Emisor no reconocido"'),
      ]),
    ]),
    _a('signature_evidence', 'hash SHA-256 del documento + sello de tiempo RFC 3161 + aud_event'),
  ]),
]),

// ══════════════════════════════════════════════
// D99 · ADMINISTRATIVO GLOBAL
// ══════════════════════════════════════════════
NodoTemplate('D99 · ADMINISTRATIVO GLOBAL', TipoNodo.dominio,
    help: 'Fuera del BitMask (garante) — piso irrenunciable. Bloques CALCULADOS (READONLY).', hijos: [
  NodoTemplate('B9 · SAM-128 + BitMask (calculado)', TipoNodo.bloque,
      help: 'READONLY: jamás se edita a mano. ADR-009.', hijos: [
    _a('bitmask_64_ref', 'capa 1 [31:0] sistema · capa 2 [63:32] negocio',
        help: 'Efectiva = propia OR junior (DAG). One-hot.'),
    _a('*_domain_mask_hex Q1-Q4', 'lógico/físico/financiero/gobernanza (32 bits c/u)',
        help: 'SAM-128. G-B09: pendiente cálculo.'),
    _a('computed_at / computed_by', 'sello del PrivilegeEngine + ctx_id'),
  ]),
  NodoTemplate('B14 · Estado de sincronización (calculado)', TipoNodo.bloque,
      help: 'READONLY del reconcile loop.', hijos: [
    _en('sync_status', 'SYNCED',
        ['PENDING', 'SYNCING', 'SYNCED', 'ERROR', 'DRIFT'],
        help: 'DRIFT = estado declarado ≠ materializado → autocorrección.'),
    _a('last_sync_at', 'timestamp ISO 8601'),
    _en('drift_detected', 'false', ['true', 'false'],
        help: 'true → autocorrección automática o alert SRE.'),
    _a('drift_details', 'null | {campo, valor_declarado, valor_materializado}'),
  ]),
]),

]; // fin arbolRolTemplate
