// ============================================================
// bauth_desktop · datos/atomlang_datos.dart
//
// Propósito: árbol del VOCABULARIO AtomLang v1 — palabras reservadas,
//   tipos de nodo, vocabularios cerrados, reglas léxicas, códigos de error
//   del compilador (atomc) y fases de compilación. Usado en Tab 2 del
//   contenedor del árbol SOURCE.
// Dependencias: datos/rol_template_datos (reutiliza NodoTemplate + TipoNodo).
// Estándar: AtomLang-especificacion-completa.md · DOC-SBOS-001 N3.
// ============================================================

import 'rol_template_datos.dart';

// ──── atajos locales ──────────────────────────────────────────

NodoTemplate _a(String c, String v, {String? help}) =>
    NodoTemplate(c, TipoNodo.atributo, valor: v, help: help);

NodoTemplate _en(String c, String v, List<String> ops, {String? help}) =>
    NodoTemplate(c, TipoNodo.enumerado, valor: v, opciones: ops, help: help);

NodoTemplate _obj(String c, {String? help, List<NodoTemplate> hijos = const []}) =>
    NodoTemplate(c, TipoNodo.objeto, help: help, hijos: hijos);

NodoTemplate _bloque(String c, {String? help, List<NodoTemplate> hijos = const []}) =>
    NodoTemplate(c, TipoNodo.bloque, help: help, hijos: hijos);

NodoTemplate _pol(String c, {String? help, List<NodoTemplate> hijos = const []}) =>
    NodoTemplate(c, TipoNodo.politica, help: help, hijos: hijos);

// ──── ÁRBOL PRINCIPAL ────────────────────────────────────────

/// Árbol de vocabulario del lenguaje AtomLang v1.
/// Organizado en 5 secciones: Estructura, Vocabularios cerrados,
/// Reglas léxicas, Códigos de error y Fases del compilador.
final List<NodoTemplate> arbolAtomLang = [
  NodoTemplate(
    'AtomLang v1 — Lenguaje de Átomos bAuth',
    TipoNodo.dominio,
    help: 'AtomLang es el lenguaje con el que se escribe el Árbol Fuente de bAuth.\n\n'
        '• No inventa sintaxis nueva — es YAML con gramática restringida y validación semántica.\n'
        '• atomc (Rust 1.85+ MUSL) compila el Árbol Fuente → Árbol Técnico (IR) que ejecuta el PDP.\n'
        '• Extensión de archivo fuente: .atm.yaml\n'
        '• Extensión del artefacto compilado: .atm.json\n'
        '• Principio: ningún string se compara por igualdad textual en runtime — todo es ID/enum/valor tipado.',
    hijos: [
      _seccionEstructura(),
      _seccionVocabularios(),
      _seccionReglasLexicas(),
      _seccionErroresCompilador(),
      _seccionFasesCompilador(),
    ],
  ),
];

// ──── Sección 1: Estructura del árbol ──────────────────────────

NodoTemplate _seccionEstructura() => _bloque(
  'ESTRUCTURA DEL ÁRBOL',
  help: 'Jerarquía de nodos válidos en AtomLang v1.\n\n'
      'Regla de dependencia: una entidad solo puede contener entidades del nivel inmediato inferior.\n'
      'Catálogos (bos_verb, bos_group) se REFERENCIAN por ID — nunca se copian inline.',
  hijos: [
    _nodoTipoDominio(),
    _nodoTipoBloque(),
    _nodoTipoPolitica(),
    _nodoTipoRegla(),
    _nodoTipoAtomo(),
  ],
);

NodoTemplate _nodoTipoDominio() => _pol(
  'dominio',
  help: 'PolicySet de nivel 1 (D1..D12 + D98).\n\n'
      'Agrupa bloques y políticas bajo un mismo dominio de control.\n'
      'Badge obligatorio: [POLICYSET].\n'
      'combining_algorithm: opcional (si no se declara, cada Policy hija tiene el suyo).',
  hijos: [
    _a('identificador', 'snake_case · ej: d1_acceso_logico',
        help: 'Identificador único del dominio. Patrón: [a-z][a-z0-9_]{2,63}.\n'
            'No admite mayúsculas, espacios ni guiones — el linter lo rechaza.'),
    _en('badge', '[POLICYSET]', const ['[POLICYSET]'],
        help: 'Badge obligatorio de tipo PolicySet. El compilador lo valida en Fase 2.'),
    _en('combining_algorithm', 'deny-overrides',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'Algoritmo de combinación a nivel dominio. Opcional — si no se declara, '
            'cada Policy hija declara el suyo.'),
    _a('contiene', 'bloques | políticas',
        help: 'Un dominio puede contener directamente bloques (PolicySet anidados) '
            'o políticas (Policy). No puede contener átomos directamente.'),
  ],
);

NodoTemplate _nodoTipoBloque() => _pol(
  'bloque',
  help: 'Policy o PolicySet anidado (B1..B14 del RolTemplate v6.0).\n\n'
      'Puede ser Policy ([POLICY]) si contiene políticas directamente,\n'
      'o PolicySet ([POLICYSET]) si agrupa más bloques.',
  hijos: [
    _a('identificador', 'snake_case · ej: b4_dominio_logico_autenticacion',
        help: 'Identificador único del bloque dentro del dominio.'),
    _en('badge', '[POLICY]', const ['[POLICY]', '[POLICYSET]'],
        help: '[POLICY] si el bloque contiene políticas directamente.\n'
            '[POLICYSET] si el bloque agrupa más bloques.'),
    _en('combining_algorithm', 'deny-overrides',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'OBLIGATORIO si el bloque contiene 2 o más políticas o bloques hermanos.\n'
            'El compilador emite ATOMC-E-020 si falta.'),
    _a('contiene', 'bloques | políticas',
        help: 'Un bloque puede anidar bloques (PolicySet) o contener políticas (Policy).'),
  ],
);

NodoTemplate _nodoTipoPolitica() => _pol(
  'politica',
  help: 'Policy XACML — conjunto de átomos con un combining_algorithm compartido.\n\n'
      'Es la unidad de evaluación visible para el PDP. '
      'Cada eval dentro de una política tiene su PROPIO efecto.',
  hijos: [
    _a('policy_id', 'snake_case · ej: step_up_triggers',
        help: 'Identificador único de la política. Inmutable una vez publicada.\n'
            'Se usa como clave en bos_atom_compiled.'),
    _a('application_id', 'FK bos_application | null',
        help: 'null = Guardrail Atom (política de autenticación, no de negocio).\n'
            'Si application_id != null, la política aplica solo a esa aplicación.'),
    _en('combining_algorithm', 'aggregate-strictest',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'OBLIGATORIO si la política tiene 2 o más átomos.\n'
            'aggregate-strictest: extensión bAuth — todos los Permit concurrentes '
            'se fusionan campo a campo eligiendo el valor más estricto (max loa, min age).'),
    _a('contiene', 'átomos (2+)',
        help: 'Una política contiene átomos. Cada átomo tiene su propio efecto.\n'
            'Si hay un solo átomo, combining_algorithm es opcional.'),
  ],
);

NodoTemplate _nodoTipoRegla() => _pol(
  'regla',
  help: 'Múltiples evaluaciones conectadas por op_lógico, con UN solo efecto compartido.\n\n'
      'Patrón canónico: evaluacion → op_lógico(AND|OR) → evaluacion → efecto.\n'
      'Si cada evaluacion necesita su propio efecto, usar politica en su lugar.',
  hijos: [
    _a('patrón', 'eval [op_lógico eval]* efecto_compartido',
        help: 'Las evaluaciones se conectan con AND u OR. '
            'El efecto al final aplica solo si la expresión booleana completa es True.'),
    _en('op_lógico', 'AND', const ['AND', 'OR', 'NOT'],
        help: 'AND: todas las condiciones deben cumplirse.\n'
            'OR: basta con una.\n'
            'NOT: negación de la condición siguiente.'),
    _a('efecto_compartido', 'Permit | Deny + Obligation',
        help: 'Un solo efecto al final de la regla — compartido por todas las evaluaciones.\n'
            'Si necesitas efectos distintos por caso, usa politica con evals independientes.'),
  ],
);

NodoTemplate _nodoTipoAtomo() => _pol(
  'atomo',
  help: 'Unidad de evaluación atómica (Rule XACML).\n\n'
      'El PDP evalúa en orden: Target-gate → Condition → Effect.\n'
      'La Condition NUNCA se evalúa si el Target-gate no cerró en Match.\n'
      'atom_id es inmutable una vez publicado en bos_atom_compiled.',
  hijos: [
    _a('atom_id', 'snake_case · ej: monto_transaccion_alto',
        help: 'Identificador único del átomo. Patrón: [a-z][a-z0-9_]{2,63}.\n'
            'Inmutable — si cambias el id, se crea un átomo nuevo, no se modifica el existente.'),
    _en('verbo', 'execute',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Action XACML del Target-gate. FK a bos_verb.verb_id.\n'
            'PROHIBIDO escribir el verbo como string libre (ej. "CONFIGURE" en mayúsculas).\n'
            'any_verb: comodín — el átomo aplica a cualquier acción.'),
    _obj('target', help: 'Target-gate XACML — filtra si el átomo aplica al contexto actual.\n'
        'Se evalúa SIEMPRE antes que la Condition. Si no matchea → NotApplicable.',
        hijos: [
          _en('subject', 'ANY', const ['ANY', 'ROL(id)', 'SET(id)'],
              help: 'Sujeto que ejecuta la acción.\n'
                  'ANY: cualquier rol.\n'
                  'ROL(id): rol específico por FK.\n'
                  'SET(id): conjunto de roles declarado en D98 (bos_group).'),
          _a('resource', 'FK bos_resource_catalog',
              help: 'Recurso al que aplica el átomo. FK al catálogo de modelos/campos.\n'
                  'Nunca un string libre como "sale.order.margin".'),
          NodoTemplate('environment', TipoNodo.lista,
              help: 'Lista de atributos de contexto exigidos como parte del Target.\n'
                  'Cada uno resuelto por el PIP (Policy Information Point) en runtime.',
              hijos: [
                _a('[ { propiedad, operador, valor } ]', '',
                    help: 'Array de predicados de entorno. Cada predicado usa el mismo '
                        'vocabulario de operadores cerrado que condition.'),
              ]),
        ]),
    _obj('condition', help: 'Predicado adicional — solo se evalúa si el Target hizo Match.\n'
        'condition: null explícito = siempre True (equivale a XACML "Condition vacía").\n'
        'PROHIBIDO omitir — el compilador exige que sea null o un predicado completo.',
        hijos: [
          _a('propiedad', 'FK bos_attribute_catalog',
              help: 'Atributo del contexto a evaluar. FK al catálogo de atributos.\n'
                  'Define también el tipo de dato esperado en "valor".'),
          _en('operador', '>', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
              help: 'Vocabulario cerrado de 9 operadores.\n'
                  'Cualquier símbolo fuera de esta lista → ATOMC-E-013.'),
          _a('valor', 'tipado según propiedad',
              help: 'Tipo dinámico determinado por propiedad.data_type en bos_attribute_catalog.\n'
                  'Si data_type == enum → valor DEBE resolverse contra el mismo enum.\n'
                  'Nunca comparado como string crudo en runtime.'),
        ]),
    _obj('effect', help: 'Resultado del átomo cuando Target + Condition son True.',
        hijos: [
          _en('decision', 'Permit', const ['Permit', 'Deny'],
              help: 'Decisión del átomo. Vocabulario cerrado: solo Permit o Deny.\n'
                  'Los matices (loa requerido, antigüedad) van en obligation, nunca en decision.'),
          _a('obligation', '{ clave: valor_tipado }*',
              help: 'Efectos secundarios OBLIGATORIOS para el PEP.\n'
                  'Claves canónicas: required_loa, max_age_seconds, acr, registrar_en_audit.\n'
                  'Tipados por clave — nunca texto libre concatenado.'),
          _a('advice', 'mensaje informativo | null',
              help: 'Mensaje que el PEP PUEDE ignorar. Nunca contiene lógica de decisión.\n'
                  'Si no hay advice, declarar null explícitamente.'),
        ]),
  ],
);

// ──── Sección 2: Vocabularios cerrados ─────────────────────────

NodoTemplate _seccionVocabularios() => _bloque(
  'VOCABULARIOS CERRADOS',
  help: 'Todo valor en AtomLang que puede tomar más de una forma pertenece a un vocabulario cerrado.\n\n'
      'El compilador (Fase 1 — Lexer) rechaza cualquier valor fuera del vocabulario.\n'
      'No existe "texto libre" en el Árbol Técnico compilado.',
  hijos: [
    _vocabularioCombining(),
    _vocabularioVerbos(),
    _vocabularioSubject(),
    _vocabularioOperadores(),
    _vocabularioDecision(),
    _vocabularioObligationKeys(),
    _vocabularioOpLogico(),
    _vocabularioBadges(),
  ],
);

NodoTemplate _vocabularioCombining() => _pol(
  'combining_algorithm',
  help: 'Algoritmos de combinación de resultados de múltiples átomos en una Policy.\n\n'
      'XACML 3.0 §7.14 define los primeros 5. aggregate-strictest es extensión bAuth.\n'
      'El compilador valida que combining_algorithm esté declarado en toda Policy con 2+ átomos.',
  hijos: [
    _en('deny-overrides', 'deny-overrides',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'Un solo Deny entre todos los resultados → Decision = Deny.\n'
            'Más conservador. Usar para control de acceso estricto.'),
    _en('permit-overrides', 'permit-overrides',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'Un solo Permit entre todos los resultados → Decision = Permit.\n'
            'Útil cuando se quiere conceder acceso si cualquier política lo permite.'),
    _en('first-applicable', 'first-applicable',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'Devuelve el primer resultado que no sea NotApplicable.\n'
            '⚠️ RIESGO: si múltiples átomos aplican simultáneamente, los demás se ignoran.\n'
            'Puede silenciar el requisito de seguridad más estricto (defecto §2.1 #3).\n'
            'Evitar en políticas de step-up — usar aggregate-strictest.'),
    _en('deny-unless-permit', 'deny-unless-permit',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'Si ningún átomo produce Permit explícito → Decision = Deny.\n'
            'Fail-closed por diseño. Recomendado para políticas de autenticación.'),
    _en('permit-unless-deny', 'permit-unless-deny',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: 'Si ningún átomo produce Deny explícito → Decision = Permit.\n'
            '⚠️ Fail-open por diseño. Usar solo en políticas de acceso muy permisivas.'),
    _en('aggregate-strictest', 'aggregate-strictest',
        const ['deny-overrides', 'permit-overrides', 'first-applicable',
          'deny-unless-permit', 'permit-unless-deny', 'aggregate-strictest'],
        help: '★ EXTENSIÓN bAuth (no en XACML 3.0 estándar).\n\n'
            'Cuando múltiples átomos producen Permit simultáneamente, fusiona sus Obligations '
            'eligiendo campo a campo el valor más estricto:\n'
            '  • required_loa → max(a, b) — exigir el nivel de garantía más ALTO\n'
            '  • max_age_seconds → min(a, b) — exigir la sesión más FRESCA\n\n'
            'Resuelve el defecto §2.1 #3: ningún requisito de seguridad se pierde '
            'por el orden de declaración de los átomos.\n\n'
            'Obligatorio en todas las políticas de step-up.'),
  ],
);

NodoTemplate _vocabularioVerbos() => _pol(
  'verbos (bos_verb)',
  help: 'Catálogo cerrado de verbos XACML (Actions) registrados en bos_verb.\n\n'
      'Todo verbo en un átomo DEBE estar en este catálogo — el Lexer (Fase 1) lo valida.\n'
      'Prohibido escribir el verbo como string libre (ej. "CONFIGURE") — '
      'el linter rechaza cualquier variante con mayúsculas.',
  hijos: [
    _en('read', 'read',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Leer datos o estado. Solo-lectura, sin efectos secundarios.'),
    _en('write', 'write',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Modificar datos existentes.'),
    _en('create', 'create',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Crear nuevos registros o recursos.'),
    _en('delete', 'delete',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Eliminar registros o recursos. Requiere step-up en dominios críticos.'),
    _en('approve', 'approve',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Aprobar flujos de trabajo (ej. facturas, solicitudes de acceso).'),
    _en('execute', 'execute',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Ejecutar operaciones (ej. procesos, transacciones financieras).'),
    _en('configure', 'configure',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Cambiar configuración del sistema o de la aplicación.\n'
            'Trigger canónico: system_config_change (§step_up_rules del RolTemplate).\n'
            'Siempre requiere required_loa=3 y max_age_seconds=0 (sesión siempre fresca).'),
    _en('audit', 'audit',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Leer logs y registros de auditoría. Lectura especial con trazabilidad.'),
    _en('emit', 'emit',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Emitir documentos electrónicos (facturas SIN, certificados).'),
    _en('login', 'login',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Acción de autenticación. Usado en políticas D1 (Acceso Lógico).'),
    _en('delegate', 'delegate',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Delegar permisos o representación a otro actor.'),
    _en('export', 'export',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Exportar datos fuera del sistema. Control especial por compliance (LGPD/GDPR).'),
    _en('void', 'void',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Anular documentos o transacciones.'),
    _en('any_verb', 'any_verb',
        const ['read', 'write', 'create', 'delete', 'approve', 'execute',
          'configure', 'audit', 'emit', 'login', 'delegate', 'export', 'void', 'any_verb'],
        help: 'Comodín — el átomo aplica independientemente de la acción.\n'
            'verb_id=0 en bos_verb. El Target-gate siempre matchea en cuanto a verbo.\n'
            'Usar con cuidado — el matching lo hace la Condition, no el Target.'),
  ],
);

NodoTemplate _vocabularioSubject() => _pol(
  'subject (Target.Subject)',
  help: 'Tipos de sujeto válidos en el Target de un átomo.\n\n'
      'Determina A QUIÉN aplica el átomo.\n'
      'ROL y SET resuelven contra catálogos (nunca texto libre inline).',
  hijos: [
    _en('ANY', 'ANY', const ['ANY', 'ROL(id)', 'SET(id)'],
        help: 'El átomo aplica a cualquier rol o sujeto autenticado.\n'
            'Default si no se especifica subject.'),
    _en('ROL(id)', 'ROL(id)', const ['ANY', 'ROL(id)', 'SET(id)'],
        help: 'El átomo aplica solo a un rol específico.\n'
            'id = rol_id de bos_rol_template. FK obligatoria.\n'
            'Si el mismo conjunto de roles aparece en 2+ átomos, '
            'el compilador emite ATOMC-W-030 sugiriendo declarar un SET en D98.'),
    _en('SET(id)', 'SET(id)', const ['ANY', 'ROL(id)', 'SET(id)'],
        help: 'El átomo aplica a un conjunto de roles declarado en D98 (bos_group).\n'
            'id = set_id de bos_group. FK obligatoria.\n'
            'Preferir SET sobre múltiples ROL cuando el grupo de roles es estable.'),
  ],
);

NodoTemplate _vocabularioOperadores() => _pol(
  'operador (Condition)',
  help: 'Vocabulario cerrado de 9 operadores para predicados de Condition y Environment.\n\n'
      'Cualquier símbolo fuera de esta lista → ATOMC-E-013.\n'
      'El tipo del valor debe ser compatible con el operador y el data_type del atributo.',
  hijos: [
    _en('==', '==', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'Igualdad. El valor debe coincidir exactamente (después de resolución de tipo).'),
    _en('!=', '!=', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'Desigualdad.'),
    _en('>', '>', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'Mayor que. Solo para atributos de data_type numérico.'),
    _en('<', '<', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'Menor que. Solo para atributos de data_type numérico.'),
    _en('>=', '>=', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'Mayor o igual que.'),
    _en('<=', '<=', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'Menor o igual que.'),
    _en('IN', 'IN', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'El valor del atributo está en la lista proporcionada.\n'
            'valor debe ser una lista: [CONFIGURE, ADMIN, DELETE].'),
    _en('NOT_IN', 'NOT_IN', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'El valor del atributo NO está en la lista.'),
    _en('BETWEEN', 'BETWEEN', const ['==', '!=', '>', '<', '>=', '<=', 'IN', 'NOT_IN', 'BETWEEN'],
        help: 'El valor está en el rango [min, max] (inclusivo).\n'
            'valor debe ser una lista de 2 elementos: [min, max].'),
  ],
);

NodoTemplate _vocabularioDecision() => _pol(
  'decision (Effect)',
  help: 'Vocabulario cerrado de decisiones de un átomo. Solo 2 valores posibles.',
  hijos: [
    _en('Permit', 'Permit', const ['Permit', 'Deny'],
        help: 'El átomo permite la acción. El PEP aplica las Obligations declaradas.'),
    _en('Deny', 'Deny', const ['Permit', 'Deny'],
        help: 'El átomo deniega la acción. El PEP aplica las Obligations (ej. registrar_en_audit).'),
  ],
);

NodoTemplate _vocabularioObligationKeys() => _pol(
  'obligation_keys',
  help: 'Claves canónicas del mapa obligation.\n\n'
      'Cada clave tiene una regla de "strictest()" definida en bos_attribute_catalog.\n'
      'aggregate-strictest usa estas reglas para fusionar Obligations de múltiples Permits.',
  hijos: [
    _a('required_loa', '1 | 2 | 3',
        help: 'Nivel de garantía de autenticación requerido (LoA — Level of Assurance).\n'
            'strictest() = max(a, b) — se exige el nivel MÁS ALTO entre todos los Permits.\n'
            '1=AAL1 · 2=AAL2 (TOTP/HOTP) · 3=AAL3 (WebAuthn/FIDO2 hardware).'),
    _a('max_age_seconds', 'entero ≥ 0',
        help: 'Antigüedad máxima de la sesión en segundos.\n'
            'strictest() = min(a, b) — se exige la sesión MÁS FRESCA.\n'
            '0 = siempre requiere sesión reciente (ej. configure, transacciones críticas).'),
    _a('acr', 'aal1 | aal2 | aal3',
        help: 'Authentication Context Reference (RFC 9470).\n'
            'Codifica el nivel de garantía como string para tokens OAuth2/OIDC.'),
    _a('registrar_en_audit', 'true | false',
        help: 'Fuerza un registro de auditoría ISO 27001 A.8.15 aunque la operación sea permitida.\n'
            'Útil para operaciones de alto impacto (approve, delete, configure).'),
  ],
);

NodoTemplate _vocabularioOpLogico() => _pol(
  'op_lógico (regla)',
  help: 'Conectores lógicos entre evaluaciones dentro de una regla.\n\n'
      'Se sitúa ENTRE dos evaluaciones contiguas: eval → op_lógico → eval → efecto.',
  hijos: [
    _en('AND', 'AND', const ['AND', 'OR', 'NOT'],
        help: 'Todas las evaluaciones conectadas deben ser True.'),
    _en('OR', 'OR', const ['AND', 'OR', 'NOT'],
        help: 'Basta con que una evaluación sea True.'),
    _en('NOT', 'NOT', const ['AND', 'OR', 'NOT'],
        help: 'Niega la siguiente evaluación.'),
  ],
);

NodoTemplate _vocabularioBadges() => _pol(
  'badges (nodos contenedores)',
  help: 'Marcadores de tipo obligatorios en todo nodo contenedor.\n\n'
      'El compilador valida en Fase 2 que todo dominio/bloque tenga badge.\n'
      'Sin badge → ATOMC-E-030 (defecto §2.1 #4 del problema detectado).',
  hijos: [
    _a('[POLICYSET]', 'dominio | bloque contenedor',
        help: 'Badge de PolicySet. Aplica a dominios (D1..D12) y bloques que agrupan más bloques.'),
    _a('[POLICY]', 'bloque hoja | política',
        help: 'Badge de Policy. Aplica a bloques que contienen políticas directamente.'),
    _a('[ATOM]', 'átomo',
        help: 'Badge de Atom/Rule. Aplica a las unidades de evaluación atómica.'),
    _a('[REGISTRO ESTRUCTURAL]', 'D98 — catálogo de sets',
        help: 'Badge especial del dominio D98. Contiene las declaraciones de SET (bos_group).\n'
            'Es el único dominio donde se declaran Sets de roles referenciables con SET(id).'),
  ],
);

// ──── Sección 3: Reglas léxicas ────────────────────────────────

NodoTemplate _seccionReglasLexicas() => _bloque(
  'REGLAS LÉXICAS',
  help: 'Reglas que el Lexer (Fase 1 del compilador) verifica ANTES de parsear el árbol.\n\n'
      'Una violación léxica es un error de compilación — el árbol no se procesa.\n'
      'No existe "corrección automática" — el autor debe corregir en el Árbol Fuente.',
  hijos: [
    _a('atomlang_version: 1', 'OBLIGATORIO — primera clave del archivo',
        help: 'Todo archivo .atm.yaml debe comenzar con atomlang_version: 1.\n'
            'Permite migraciones de gramática (v1→v2) sin ambigüedad de qué reglas aplicar.'),
    _a('snake_case obligatorio', 'todo identificador: [a-z][a-z0-9_]{2,63}',
        help: 'atom_id, policy_id, nombres de propiedad — todos en snake_case.\n'
            'El linter rechaza: MAYÚSCULAS, camelCase, espacios, guiones.\n'
            'Ejemplo válido: monto_transaccion_alto\n'
            'Ejemplo inválido: MontoTransaccionAlto (ATOMC-E-001)'),
    _a('condition: null explícito', 'nunca omitir',
        help: 'Si un átomo no necesita Condition adicional, declarar:\n'
            '  condition: null\n'
            'Omitirlo genera ATOMC-E-022 (ambigüedad entre "olvidé escribirlo" '
            'e "intencionalmente sin condición").'),
    _a('verbo en minúsculas', 'configure (✓) vs CONFIGURE (✗)',
        help: 'El verbo debe coincidir exactamente con el verb_id en bos_verb (minúsculas).\n'
            "Escribir CONFIGURE → ATOMC-E-014: verbo 'CONFIGURE' no está registrado "
            "(¿quisiste decir 'configure'?).\n\n"
            'Este era el defecto §2.1 #1 — ahora estructuralmente imposible.'),
    _a('un archivo = una Policy', 'prohibido mezclar Policies no relacionadas',
        help: 'Cada archivo .atm.yaml contiene una Policy (o un PolicySet con sus hijas inline).\n'
            'Esto garantiza que el diff de git sea legible por dominio de negocio.'),
    _a('condition ≠ target', 'mismo atributo no puede aparecer en ambos',
        help: 'Si property_id en condition es el mismo usado para resolver verb_id o '
            'target.subject → ATOMC-E-021 ("atributo duplicado entre Target y Condition").\n\n'
            'Este era el defecto §2.1 #2 — ahora detectado en Fase 2.'),
  ],
);

// ──── Sección 4: Códigos de error del compilador ──────────────

NodoTemplate _seccionErroresCompilador() => _bloque(
  'CÓDIGOS DEL COMPILADOR (atomc)',
  help: 'Catálogo de errores y warnings del compilador atomc.\n\n'
      'ATOMC-E-xxx = error — detiene la compilación (no se genera .atm.json).\n'
      'ATOMC-W-xxx = warning — compilación continúa pero se reporta.\n\n'
      'Comandos: atomc lint | atomc validate | atomc compile | atomc publish',
  hijos: [
    _pol('Errores de sintaxis (E-0xx)', help: 'Fase 1 — Lexer', hijos: [
      _a('ATOMC-E-001', 'sintaxis YAML inválida',
          help: 'El archivo no es YAML válido. Corregir con un linter YAML estándar.'),
      _a('ATOMC-E-002', 'atomlang_version faltante o no es 1',
          help: 'La primera clave del archivo debe ser atomlang_version: 1.'),
      _a('ATOMC-E-003', 'identificador viola snake_case',
          help: 'Un atom_id, policy_id u otro identificador contiene mayúsculas, '
              'espacios o guiones.'),
    ]),
    _pol('Errores de referencia (E-01x)', help: 'Fase 1 — resolución de catálogos', hijos: [
      _a('ATOMC-E-010', 'verbo no registrado en bos_verb',
          help: 'El verbo_ref no existe en bos_verb. Verificar el catálogo.'),
      _a('ATOMC-E-011', 'resource no registrado en bos_resource_catalog',
          help: 'El resource_ref no existe en el catálogo de recursos.'),
      _a('ATOMC-E-012', 'propiedad no registrada en bos_attribute_catalog',
          help: 'El property_id de condition o environment no existe en el catálogo.'),
      _a('ATOMC-E-013', 'operador fuera del vocabulario cerrado',
          help: 'Solo se permiten: ==, !=, >, <, >=, <=, IN, NOT_IN, BETWEEN.'),
      _a('ATOMC-E-014', 'verbo en mayúsculas',
          help: 'Ej.: "CONFIGURE" → "¿quisiste decir \'configure\'?"\n'
              'Este código resuelve estructuralmente el defecto §2.1 #1.'),
    ]),
    _pol('Errores semánticos (E-02x)', help: 'Fase 2 — validador semántico', hijos: [
      _a('ATOMC-E-020', 'Policy con 2+ átomos sin combining_algorithm',
          help: 'Toda Policy con 2 o más átomos hermanos debe declarar combining_algorithm.'),
      _a('ATOMC-E-021', 'atributo duplicado entre Target y Condition',
          help: 'El mismo property_id aparece en target.environment y en condition.\n'
              'Resuelve defecto §2.1 #2.'),
      _a('ATOMC-E-022', 'condition omitida (se exige null explícito)',
          help: 'Si el átomo no tiene condición, declarar: condition: null'),
      _a('ATOMC-E-030', 'nodo contenedor sin badge',
          help: 'Todo dominio y bloque debe llevar badge obligatorio.\n'
              'Resuelve defecto §2.1 #4.'),
    ]),
    _pol('Warnings (W-0xx)', help: 'No detienen la compilación', hijos: [
      _a('ATOMC-W-030', 'posible duplicación — considerar SET(id)',
          help: 'El mismo conjunto de roles aparece en 2+ átomos con ROL(id).\n'
              'Considerar declarar un SET en D98 y referenciar con SET(id).'),
      _a('ATOMC-W-031', 'first-applicable en política de step-up',
          help: 'Usar first-applicable en una política con múltiples átomos de step-up '
              'puede silenciar requisitos de seguridad. Considerar aggregate-strictest.'),
    ]),
  ],
);

// ──── Sección 5: Fases del compilador ─────────────────────────

NodoTemplate _seccionFasesCompilador() => _bloque(
  'FASES DEL COMPILADOR (atomc)',
  help: 'atomc es el compilador AtomLang escrito en Rust 1.85+ MUSL.\n\n'
      'Ubicación: BauthAgent/tools/atomc/\n'
      'Binario estático — mismo patrón de despliegue que el daemon bAuth.',
  hijos: [
    _pol('Fase 1 — Lexer / Tokenizer', help: 'Primera fase del compilador', hijos: [
      _a('entrada', 'archivo .atm.yaml',
          help: 'El archivo fuente AtomLang. Escrito por el humano o generado por la UI.'),
      _a('tokenización', 'parsea el YAML con serde_yaml',
          help: 'Convierte el YAML en tokens tipados (Rust structs).'),
      _a('normalización', 'snake_case en frontera de entrada',
          help: 'Normaliza identificadores a minúsculas. Rechaza (no corrige) variantes inválidas.'),
      _a('resolución de catálogos', 'bos_verb · bos_resource_catalog · bos_group',
          help: 'Cada string de verbo, resource, set_id se resuelve a su ID entero.\n'
              'Si no existe → error de compilación (ATOMC-E-010..012).'),
      _a('salida', 'AST parcialmente tipado',
          help: 'Árbol de tokens con IDs resueltos. Pasa a Fase 2.'),
    ]),
    _pol('Fase 2 — Parser / Validador semántico', help: 'Segunda fase del compilador', hijos: [
      _a('entrada', 'AST parcialmente tipado de Fase 1',
          help: 'El AST producido por el Lexer con IDs ya resueltos.'),
      _a('construcción de AST tipado', 'structs Rust: Policy, Atom, Target, Condition, Effect',
          help: 'Construye el AST completo con los tipos del dominio bAuth.'),
      _a('grafo de dependencias', 'ningún Atom fuera de Policy',
          help: 'Verifica la jerarquía: Dominio → Bloque → Policy → Atom.\n'
              'Un Atom directamente bajo un Bloque (sin Policy) → error.'),
      _a('combining_algorithm', 'obligatorio en Policy con 2+ Atoms',
          help: 'ATOMC-E-020 si falta.'),
      _a('atributos duplicados', 'Target ≠ Condition',
          help: 'ATOMC-E-021 si el mismo property_id aparece en ambos.'),
      _a('badges', 'todo contenedor con badge explícito',
          help: 'ATOMC-E-030 si un dominio o bloque no tiene badge.'),
      _a('salida', 'AST completamente validado',
          help: 'Árbol sin errores semánticos. Pasa a Fase 3.'),
    ]),
    _pol('Fase 3 — Generador de IR', help: 'Tercera fase: emisión del Árbol Técnico', hijos: [
      _a('entrada', 'AST validado de Fase 2',
          help: 'El AST semánticamente correcto.'),
      _a('emisión', 'serializa a .atm.json (Árbol Técnico)',
          help: 'El IR contiene SOLO IDs enteros, enums y valores tipados.\n'
              'Cero strings comparados por igualdad textual.'),
      _a('garantía', 'ningún string comparado en runtime',
          help: 'Todo verb_id, resource_id, property_id es de tipo entero (INTEGER FK).\n'
              'Esto hace estructuralmente imposible el defecto §2.1 #1.'),
      _a('publicación (atomc publish)', 'INSERT en bos_atom_compiled',
          help: 'atomc publish inserta el IR en bos_atom_compiled dentro de una transacción.\n'
              'También inserta una fila de auditoría en bos_atom_audit (quién, cuándo, source_hash).'),
      _a('salida', 'fila en bos_atom_compiled — lo ejecuta el PDP',
          help: 'El PDP (evaluador) lee SOLO bos_atom_compiled WHERE is_active=true.\n'
              'Nunca lee bos_atom_catalog (fuente humana) directamente.'),
    ]),
  ],
);
