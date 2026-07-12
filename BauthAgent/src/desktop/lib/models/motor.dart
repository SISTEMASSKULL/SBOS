// ============================================================
// bauth_desktop · models/motor.dart
//
// Propósito: modelo de un motor de capacidad (ADR-013) y el catálogo de los 7.
//   El estado se expresa como NIVEL (enum); el color lo resuelve la UI desde
//   el tema (acento/destructive/base) — sin colores hardcodeados aquí.
// Dependencias: ninguna.
// Estándar: ADR-013 · DOC-SBOS-001 N3 (sin hardcode de color).
// ============================================================

/// Nivel de estado de un motor. La UI lo mapea a un color del tema.
enum EstadoMotor { listo, enProceso, defecto, porDesarrollar }

/// Un motor de capacidad: verbo + estado (etiqueta y nivel).
class Motor {
  final String nombre;
  final String verbo;
  final String estado;
  final EstadoMotor nivel;

  const Motor({
    required this.nombre,
    required this.verbo,
    required this.estado,
    required this.nivel,
  });
}

/// Los 7 motores de capacidad de bAuth (ADR-013).
const List<Motor> catalogoMotores = [
  Motor(nombre: 'BitMask', verbo: 'calcular privilegios', estado: '✅ robusto', nivel: EstadoMotor.listo),
  Motor(nombre: 'Métodos', verbo: 'autenticar', estado: '🔄 9/18', nivel: EstadoMotor.enProceso),
  Motor(nombre: 'Políticas (PDP)', verbo: 'autorizar', estado: '🔄 fail-open', nivel: EstadoMotor.defecto),
  Motor(nombre: 'Canales', verbo: 'transportar', estado: '⬜ por crear', nivel: EstadoMotor.porDesarrollar),
  Motor(nombre: 'Criptográfico', verbo: 'cifrar', estado: '⬜ por crear', nivel: EstadoMotor.porDesarrollar),
  Motor(nombre: 'Firma', verbo: 'firmar documentos', estado: '🔄 interno✅', nivel: EstadoMotor.enProceso),
  Motor(nombre: 'Auditoría', verbo: 'auditar (WORM)', estado: '🔄 esqueleto', nivel: EstadoMotor.enProceso),
];
