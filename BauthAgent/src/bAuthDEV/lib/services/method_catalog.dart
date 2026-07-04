/// Catalogo de los 47+ metodos JSON-RPC de bAuth
/// Cada metodo incluye: nombre, descripcion, parametros, ejemplo y tags

class MethodInfo {
  final String name;
  final String category;
  final String description;
  final Map<String, String> params;
  final Map<String, dynamic> exampleParams;
  final List<String> tags;
  final bool hasMaskVariant;
  final bool hasBlockchainVariant;
  final bool hasLegacyVariant;

  const MethodInfo({
    required this.name, required this.category, required this.description,
    required this.params, required this.exampleParams, this.tags = const [],
    this.hasMaskVariant = false, this.hasBlockchainVariant = false,
    this.hasLegacyVariant = false,
  });
}

class MethodCatalog {
  static const testUsers = {
    'test_cajero': '019f06db-62a9-73ab-a85a-f5d12f20233d',
    'test_contador': '019f06db-62a9-7323-90a3-1c8b2880408f',
    'test_gerente': '019f06db-62a9-729c-89ea-1a2fcc714c12',
    'test_superadmin': '019f06db-62a6-77b1-b581-4c37e3aeee9f',
    'test_cliente': '019f06db-62a9-7551-b33c-12583be0ed1f',
  };

  final List<MethodInfo> methods = [
    // ── TOKENS ─────────────────────────────────
    const MethodInfo(
      name: 'bauth.token.issue', category: 'Tokens',
      description: 'Emite un JWT Ed25519 con claims de identidad. Token liviano de ~1.1 KB. 4 variantes disponibles.',
      params: {'user_uuid': 'string (UUIDv7 del usuario)', 'include_mask': 'bool? (cookie offline)', 'anchor': 'bool? (blockchain)', 'algorithm': 'string? ("Ed25519"|"RS256")'},
      exampleParams: {'user_uuid': '019f06db-62a9-73ab-a85a-f5d12f20233d'},
      tags: ['jwt', 'token', 'identidad'], hasMaskVariant: true, hasBlockchainVariant: true, hasLegacyVariant: true,
    ),
    const MethodInfo(
      name: 'bauth.token.validate', category: 'Tokens',
      description: 'Valida un JWT emitido por bAuth. Devuelve los claims decodificados y verifica la firma Ed25519.',
      params: {'jwt': 'string (token a validar)'},
      exampleParams: {'jwt': '<pegar JWT del token.issue>'},
      tags: ['jwt', 'validacion'],
    ),
    const MethodInfo(
      name: 'bauth.token.jwks', category: 'Tokens',
      description: 'Devuelve la clave publica Ed25519 en formato JWKS (RFC 7517) para verificacion externa del JWT.',
      params: {},
      exampleParams: {},
      tags: ['jwks', 'clave publica', 'rfc7517'],
    ),
    // ── ACCESO ─────────────────────────────────
    const MethodInfo(
      name: 'bauth.access.evaluate', category: 'Acceso',
      description: 'Evalua si un usuario puede ejecutar un atomo. FastPath <0.5ns + PolicyPath. EL METODO PRINCIPAL.',
      params: {'atom_slug': 'string (tryton.g1.d1.nuevo)', 'user_uuid': 'string (UUIDv7)'},
      exampleParams: {'atom_slug': 'tryton.g1.d1.nuevo', 'user_uuid': '019f06db-62a9-73ab-a85a-f5d12f20233d'},
      tags: ['fastpath', 'evaluacion', 'acceso', 'd1'],
    ),
    const MethodInfo(
      name: 'bauth.context.evaluate', category: 'Acceso',
      description: 'Evalua los 12 dominios completos para un ctx_id. Retorna el veredicto de cada dominio.',
      params: {'ctx_id': 'string', 'atom_slug': 'string'},
      exampleParams: {'ctx_id': 'ctx-019f06db-...', 'atom_slug': 'sistema.sesion.activa'},
      tags: ['contexto', '12-dominios', 'ctx_id'],
    ),
    const MethodInfo(
      name: 'bauth.ctx.validate', category: 'Acceso',
      description: 'Valida que un ctx_id este activo y pertenezca al usuario correcto.',
      params: {'ctx_id': 'string'},
      exampleParams: {'ctx_id': 'ctx-019f06db-...'},
      tags: ['contexto', 'validacion'],
    ),
    // ── DOMINIOS ───────────────────────────────
    const MethodInfo(name: 'bauth.domain.logical', category: 'Dominios', description: 'D1 - Acceso logico (apps, modulos, verbos, atomos)', params: {'atom_position': 'int', 'ctx_id': 'string?'}, exampleParams: {'atom_position': 1}, tags: ['d1', 'logico']),
    const MethodInfo(name: 'bauth.domain.physical', category: 'Dominios', description: 'D2 - Acceso fisico (edificios, pisos, zonas, dispositivos)', params: {'atom_position': 'int', 'ctx_id': 'string?'}, exampleParams: {'atom_position': 1}, tags: ['d2', 'fisico']),
    const MethodInfo(name: 'bauth.domain.financial', category: 'Dominios', description: 'D3 - Control financiero (limites, SoD, aprobaciones duales)', params: {'atom_position': 'int', 'amount': 'decimal?', 'ctx_id': 'string?'}, exampleParams: {'atom_position': 43, 'amount': 5000}, tags: ['d3', 'financiero']),
    const MethodInfo(name: 'bauth.domain.temporal', category: 'Dominios', description: 'D4 - Control temporal (horarios, turnos, feriados)', params: {'atom_position': 'int', 'ctx_id': 'string?'}, exampleParams: {'atom_position': 1}, tags: ['d4', 'temporal']),
    const MethodInfo(name: 'bauth.domain.biometric', category: 'Dominios', description: 'D5 - Control biometrico (LoA, Step-Up, FIDO2)', params: {'atom_position': 'int', 'loa_required': 'int?'}, exampleParams: {'atom_position': 1, 'loa_required': 2}, tags: ['d5', 'biometrico']),
    const MethodInfo(name: 'bauth.domain.geospatial', category: 'Dominios', description: 'D6 - Control geoespacial (paises, geo-fences)', params: {'atom_position': 'int', 'ip': 'string?'}, exampleParams: {'atom_position': 1}, tags: ['d6', 'geoespacial']),
    const MethodInfo(name: 'bauth.domain.network', category: 'Dominios', description: 'D7 - Control de red (CIDR, ZTNA, trust score)', params: {'atom_position': 'int'}, exampleParams: {'atom_position': 1}, tags: ['d7', 'red']),
    const MethodInfo(name: 'bauth.domain.audit', category: 'Dominios', description: 'D11 - Auditoria (WORM, revisiones trimestrales)', params: {'from': 'ISO', 'to': 'ISO', 'limit': 'int?'}, exampleParams: {'limit': 100}, tags: ['d11', 'auditoria']),
    const MethodInfo(name: 'bauth.blockchain.panel', category: 'Dominios', description: 'D12 - Blockchain (Besu QBFT, lotes, Merkle proofs, liquidaciones)', params: {'action': 'string?', 'batch_id': 'string?'}, exampleParams: {}, tags: ['d12', 'blockchain']),
    // ── ROLES Y USUARIOS ───────────────────────
    const MethodInfo(name: 'bauth.role.template.list', category: 'Roles/Usuarios', description: 'Lista plantillas de rol con filtros por tier y status', params: {'tier': 'string?', 'status': 'string?', 'limit': 'int?'}, exampleParams: {'limit': 20}, tags: ['roles', 'templates']),
    const MethodInfo(name: 'bauth.role.template.get', category: 'Roles/Usuarios', description: 'Obtiene template completo con las 14 secciones JSONB', params: {'id': 'string (UUID)'}, exampleParams: {'id': '<uuid>'}, tags: ['roles', 'jsonb']),
    const MethodInfo(name: 'bauth.role.compute.mask', category: 'Roles/Usuarios', description: 'Calcula el RolBitMask (one-hot) para un rol', params: {'template_id': 'string'}, exampleParams: {'template_id': '<uuid>'}, tags: ['bitmask', 'fastpath']),
    const MethodInfo(name: 'bauth.role.list', category: 'Roles/Usuarios', description: 'Lista todos los roles del tenant', params: {}, exampleParams: {}, tags: ['roles']),
    const MethodInfo(name: 'bauth.inheritance.compute', category: 'Roles/Usuarios', description: 'Calcula herencia DAG transitiva (Closure Table)', params: {'role_id': 'string'}, exampleParams: {'role_id': '<uuid>'}, tags: ['herencia', 'dag']),
    const MethodInfo(name: 'bauth.inheritance.check', category: 'Roles/Usuarios', description: 'Verifica si un rol hereda de otro', params: {'role_id': 'string', 'child_id': 'string'}, exampleParams: {'role_id': '<uuid>', 'child_id': '<uuid>'}, tags: ['herencia', 'dag']),
    const MethodInfo(name: 'bauth.sod.check', category: 'Roles/Usuarios', description: 'Verifica Conflict Matrix - SoD estatico y dinamico', params: {'atom_positions': 'int[]', 'role_id': 'string?'}, exampleParams: {'atom_positions': [427, 891]}, tags: ['sod', 'conflicto']),
    const MethodInfo(name: 'bauth.template.validate', category: 'Roles/Usuarios', description: 'Valida hardening del template contra 260+ reglas NIST/OWASP/FIDO2', params: {'template': 'object (JSONB)'}, exampleParams: {'template': {}}, tags: ['validacion', 'hardening']),
    const MethodInfo(name: 'bauth.merge.templates', category: 'Roles/Usuarios', description: 'Merge de secciones JSONB en RolTemplate v6.0', params: {'role_id': 'string', 'domain_sections': 'object'}, exampleParams: {'role_id': '<uuid>', 'domain_sections': {}}, tags: ['merge', 'jsonb']),
    const MethodInfo(name: 'bauth.user.list', category: 'Roles/Usuarios', description: 'Lista usuarios del tenant con filtros', params: {'limit': 'int?', 'offset': 'int?', 'tenant_id': 'string?'}, exampleParams: {'limit': 50}, tags: ['usuarios']),
    const MethodInfo(name: 'bauth.tenant.list', category: 'Roles/Usuarios', description: 'Lista tenants del desarrollador (sus empresas cliente)', params: {}, exampleParams: {}, tags: ['tenant', 'empresas']),
    // ── POLITICAS/SYNC/FIRMA ───────────────────
    const MethodInfo(name: 'bauth.policy.evaluate', category: 'Politicas/Sync', description: 'Evalua una politica contra un usuario/rol', params: {'user_id': 'string', 'resource': 'string', 'action': 'string'}, exampleParams: {'user_id': '<uuid>', 'resource': 'factura', 'action': 'emitir'}, tags: ['politicas']),
    const MethodInfo(name: 'bauth.sync.reconcile', category: 'Politicas/Sync', description: 'Fuerza reconciliacion entre bAuth y Keycloak+Tryton', params: {'tenant_id': 'string?', 'force': 'bool?'}, exampleParams: {'force': true}, tags: ['sync', 'reconciliacion']),
    const MethodInfo(name: 'bauth.sync.status', category: 'Politicas/Sync', description: 'Estado de sincronizacion KC+Tryton por tenant', params: {'tenant_id': 'string?'}, exampleParams: {}, tags: ['sync', 'drift']),
    const MethodInfo(name: 'bauth.sign.internal', category: 'Politicas/Sync', description: 'Firma digital - Motor Interno (Ed25519 Vault) o Externo (RSA ADSIB)', params: {'payload': 'string', 'key_id': 'string?', 'engine': 'string?'}, exampleParams: {'payload': 'documento de prueba'}, tags: ['firma', 'ed25519', 'adsib']),
    const MethodInfo(name: 'bauth.framework.crud', category: 'Politicas/Sync', description: 'CRUD para 6 tablas del framework de politicas', params: {'table': 'string', 'action': 'string', 'data': 'object?'}, exampleParams: {'table': 'ath_policy_d1', 'action': 'list'}, tags: ['framework', 'crud']),
    // ── EXTERNOS ───────────────────────────────
    const MethodInfo(name: 'bauth.commercial', category: 'Externos', description: 'Productos comerciales D12 (anclaje, liquidacion, wallet)', params: {'product': 'string', 'action': 'string'}, exampleParams: {'product': 'anchor', 'action': 'list'}, tags: ['comercial', 'd12']),
    const MethodInfo(name: 'bauth.idp.external', category: 'Externos', description: 'Configuracion de IdP externo (OIDC Discovery, SAML, SCIM)', params: {'provider': 'string?', 'action': 'string'}, exampleParams: {'action': 'list'}, tags: ['idp', 'oidc', 'saml']),
    const MethodInfo(name: 'bauth.saga.execute', category: 'Externos', description: 'Ejecuta una saga con compensacion (install, repair, update)', params: {'saga_id': 'string', 'params': 'object?'}, exampleParams: {'saga_id': '<uuid>'}, tags: ['saga']),
    const MethodInfo(name: 'bauth.saga.list', category: 'Externos', description: 'Lista sagas disponibles y su estado', params: {}, exampleParams: {}, tags: ['saga']),
    // ── SISTEMA ────────────────────────────────
    const MethodInfo(name: 'bauth.health.check', category: 'Sistema', description: 'Health check del daemon. Estado, version, PostgreSQL, Redis.', params: {}, exampleParams: {}, tags: ['health', 'sistema']),
  ];

  List<MethodInfo> search(String query) {
    final q = query.toLowerCase();
    return methods.where((m) =>
      m.name.toLowerCase().contains(q) ||
      m.description.toLowerCase().contains(q) ||
      m.tags.any((t) => t.contains(q)) ||
      m.category.toLowerCase().contains(q)
    ).toList();
  }

  List<MethodInfo> byCategory(String category) => methods.where((m) => m.category == category).toList();
  List<String> get categories => ['Tokens', 'Acceso', 'Dominios', 'Roles/Usuarios', 'Politicas/Sync', 'Externos', 'Sistema'];
}
