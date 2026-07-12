// ============================================================
// bauth_desktop · core/theme/sbos_theme.dart
//
// Propósito: construye el `ThemeData` de tf_shadcn_flutter DINÁMICAMENTE
//   desde las Theme Options: toma una base neutra (Slate/Zinc/…) de los
//   ColorSchemes de la librería y le **inyecta el acento** (Cyan inicial) en
//   `primary`/`ring` con `copyWith`, más el radio elegido. Nada estático.
// Dependencias: tf_shadcn_flutter (ColorSchemes, ColorScheme, ThemeData),
//   sbos_tokens, theme_provider (OpcionesTema).
// Estándar: shadcn_flutter theme system · SBOS Dark · WCAG (contraste auto).
// ============================================================

import 'package:google_fonts/google_fonts.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

import 'sbos_tokens.dart';
import 'theme_provider.dart';

/// Resuelve la base neutra elegida a un ColorScheme de la librería.
ColorScheme _baseScheme(String base, ThemeMode modo) {
  switch (base) {
    case 'Zinc':
      return ColorSchemes.zinc(modo);
    case 'Gray':
      return ColorSchemes.gray(modo);
    case 'Neutral':
      return ColorSchemes.neutral(modo);
    case 'Stone':
      return ColorSchemes.stone(modo);
    case 'Slate':
    default:
      return ColorSchemes.slate(modo);
  }
}

/// Construye el tema para un brillo (claro/oscuro) desde las Theme Options.
/// El acento se inyecta en `primary`/`ring`; el texto sobre el acento se
/// calcula por luminancia para garantizar contraste.
ThemeData construirTema(OpcionesTema o, Brightness brillo) {
  final modo = brillo == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  final base = _baseScheme(o.base, modo);
  final foregroundAcento =
      o.acento.computeLuminance() > 0.45 ? TokensSbos.negro : TokensSbos.blanco;

  // tf_shadcn ColorScheme.copyWith usa ValueGetter (funciones) por campo.
  final esquema = base.copyWith(
    primary: () => o.acento,
    primaryForeground: () => foregroundAcento,
    ring: () => o.acento,
  );

  // Inter como fuente sans-serif (UI) y JetBrains Mono para código/monoespaciado.
  // Garantiza el mismo render tipográfico en Windows, Linux y macOS.
  final tipografia = Typography.geist(
    sans: GoogleFonts.inter(),
    mono: GoogleFonts.jetBrainsMono(),
  );

  return ThemeData(colorScheme: esquema, radius: o.radio, typography: tipografia);
}
