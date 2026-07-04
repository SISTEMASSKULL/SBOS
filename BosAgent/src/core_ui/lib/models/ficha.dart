/// Modelos del catálogo de fichas (18 estados ADR-021).
library;

/// Estado canónico de una ficha (máquina de 18 estados).
enum FichaState {
  pendiente,
  lista,
  instalando,
  instalada,
  actualizacionDisponible,
  actualizacionAprobada,
  actualizando,
  degradada,
  errorFisico,
  errorLogico,
  reparando,
  errorNoCorregible,
  fallaInstalacion,
  fallaActualizacion,
  rollback,
  limpieza,
  pausada,
  desinstalada,
}

/// Información resumida de una ficha.
class FichaInfo {
  final String id;
  final String state;
  final String version;
  final String health;
  final String server;
  final DateTime? installedAt;
  final DateTime? updatedAt;

  const FichaInfo({
    required this.id,
    required this.state,
    required this.version,
    required this.health,
    required this.server,
    this.installedAt,
    this.updatedAt,
  });

  factory FichaInfo.fromJson(Map<String, dynamic> json) => FichaInfo(
        id: json['id'] as String? ?? '',
        state: json['state'] as String? ?? 'pendiente',
        version: json['version'] as String? ?? '0.0.0',
        health: json['health'] as String? ?? '?',
        server: json['server'] as String? ?? '',
        installedAt: json['installed_at'] != null
            ? DateTime.tryParse(json['installed_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
      );

  /// Color semáforo según estado.
  int get semaphoreColor {
    switch (state) {
      case 'INSTALADA':
        return 0xFF00D4AA; // verde SBOS
      case 'INSTALANDO':
      case 'ACTUALIZANDO':
      case 'REPARANDO':
      case 'ROLLBACK':
      case 'LIMPIEZA':
        return 0xFFFFB300; // amarillo
      case 'DEGRADADA':
      case 'ERROR_FISICO':
      case 'ERROR_LOGICO':
      case 'ERROR_NO_CORREGIBLE':
      case 'FALLA_INSTALACION':
      case 'FALLA_ACTUALIZACION':
        return 0xFFFF5252; // rojo
      default:
        return 0xFF666666; // gris
    }
  }
}

/// Detalle extendido de una ficha (con dependencias).
class FichaDetail extends FichaInfo {
  final bool autoInstall;
  final int executionOrder;
  final List<String> dependencies;

  const FichaDetail({
    required super.id,
    required super.state,
    required super.version,
    required super.health,
    required super.server,
    super.installedAt,
    super.updatedAt,
    required this.autoInstall,
    required this.executionOrder,
    required this.dependencies,
  });

  factory FichaDetail.fromJson(Map<String, dynamic> json) => FichaDetail(
        id: json['id'] as String? ?? '',
        state: json['state'] as String? ?? 'pendiente',
        version: json['version'] as String? ?? '0.0.0',
        health: json['health'] as String? ?? '?',
        server: json['server'] as String? ?? '',
        installedAt: json['installed_at'] != null
            ? DateTime.tryParse(json['installed_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'] as String)
            : null,
        autoInstall: json['auto_install'] as bool? ?? false,
        executionOrder: json['execution_order'] as int? ?? 0,
        dependencies: (json['dependencies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}
