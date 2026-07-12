// ============================================================
// bauth_desktop · core/theme/sbos_tokens.dart
//
// Propósito: catálogos de ELECCIÓN del tema — las bases neutras y los acentos
//   entre los que el usuario elige en Theme Options. Los colores de las
//   pantallas NO salen de aquí: se toman del ColorScheme del tema (base +
//   acento). Aquí solo viven las OPCIONES elegibles.
// Dependencias: dart:ui (Color).
// Estándar: SBOS Dark · shadcn_flutter theme system · DOC-SBOS-001 N3.
// ============================================================

import 'dart:ui' show Color;

/// Opciones de tema elegibles. Base inicial: Slate · Acento inicial: Cyan.
abstract final class TokensSbos {
  static const blanco = Color(0xFFFFFFFF);
  static const negro = Color(0xFF0A0A0A);

  /// Bases neutras disponibles (tf_shadcn ColorSchemes).
  static const List<String> basesDisponibles = [
    'Slate',
    'Zinc',
    'Gray',
    'Neutral',
    'Stone',
  ];
  static const String baseInicial = 'Slate';

  /// Acentos elegibles en Theme Options (Cyan es el inicial).
  static const Map<String, Color> acentosDisponibles = {
    'Cyan': Color(0xFF06B6D4),
    'Azul': Color(0xFF3B82F6),
    'Verde': Color(0xFF22C55E),
    'Violeta': Color(0xFF8B5CF6),
    'Naranja': Color(0xFFF97316),
    'Rosa': Color(0xFFF43F5E),
    'Ámbar': Color(0xFFEAB308),
    'Teal': Color(0xFF14B8A6),
  };
  static const Color acentoInicial = Color(0xFF06B6D4); // Cyan
}
