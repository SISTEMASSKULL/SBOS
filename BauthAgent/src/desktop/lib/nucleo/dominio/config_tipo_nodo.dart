// ============================================================
// bauth_desktop · nucleo/dominio/config_tipo_nodo.dart
//
// Propósito: representación Dart del catálogo bauth.idn_policy_node_type.
//   ConfigTipoNodo es un objeto de datos cargado desde la BD —
//   NO un enum hardcodeado. Cada instancia proviene de una fila
//   de idn_policy_node_type y es inmutable una vez construida.
//
//   resolverColor() traduce color_key → Color usando el ColorScheme
//   activo (único switch permitido: sobre nombres de paleta, no tipos).
//   Esto garantiza que cambiar de theme adapta todos los colores sin
//   tocar código Dart.
//
//   diagnostico: tipo virtual del linter Dart, nunca en BD.
//   Se proporciona como kConfigDiagnostico (constante de fallback).
//
// Dependencias: flutter (Color, ColorScheme, TextStyle).
// Estándar: DDL T-161b · DOC-SBOS-001 N3.
// ============================================================

import 'package:tf_shadcn_flutter/shadcn_flutter.dart';

// ── Paleta semántica fija (independiente del tema) ────────────
// Usadas para tipos con color propio que no viene del ColorScheme.
// Se ven bien en modo claro Y oscuro.
const _kAmbar   = Color(0xFFFFB300); // amber.shade600
const _kTeal    = Color(0xFF4DB6AC); // teal.shade400
const _kViolet  = Color(0xFFAB47BC); // violet.shade400
const _kRed     = Color(0xFFEF5350); // red.shade400
const _kGreen   = Color(0xFF66BB6A); // green.shade400

/// Resuelve un color_key de la BD al Color concreto del tema activo.
/// Switch sobre NOMBRES DE PALETA, nunca sobre tipos de nodo.
Color resolverColor(String key, ColorScheme cs) => switch (key) {
  'primary'     => cs.primary,
  'foreground'  => cs.foreground,
  'muted'       => cs.mutedForeground,
  'destructive' => cs.destructive,
  'amber'       => _kAmbar,
  'teal'        => _kTeal,
  'violet'      => _kViolet,
  'red'         => _kRed,
  'green'       => _kGreen,
  _             => cs.mutedForeground,
};

/// Resolución de font_size_token → tamaño en puntos lógicos.
double resolverFontSize(String token, double scaling) => switch (token) {
  'xs'   => 10.0 * scaling,
  'sm'   => 11.0 * scaling,
  'base' => 11.5 * scaling,
  'md'   => 12.0 * scaling,
  _      => 11.5 * scaling,
};

// ── Clase de datos ────────────────────────────────────────────

/// Configuración visual de un tipo de nodo cargada desde bauth.idn_policy_node_type.
/// Inmutable. Construida por BauthApi.cargarCatalogoTipos().
class ConfigTipoNodo {
  final String code;
  final String abbreviation;
  final String nameEs;
  final String nameEn;
  final String colorKey;
  final String colorKeyValor;
  final int fontWeight;
  final String fontSizeToken;
  final bool monospace;
  final double letterSpacing;
  final bool showBadge;
  final bool expandedDefault;

  const ConfigTipoNodo({
    required this.code,
    required this.abbreviation,
    required this.nameEs,
    required this.nameEn,
    required this.colorKey,
    required this.colorKeyValor,
    required this.fontWeight,
    required this.fontSizeToken,
    required this.monospace,
    required this.letterSpacing,
    required this.showBadge,
    required this.expandedDefault,
  });

  factory ConfigTipoNodo.fromJson(Map<String, dynamic> j) => ConfigTipoNodo(
    code:           j['code']              as String? ?? '?',
    abbreviation:   j['abbreviation']      as String? ?? '?',
    nameEs:         j['name_es']           as String? ?? '?',
    nameEn:         j['name_en']           as String? ?? '?',
    colorKey:       j['color_key']         as String? ?? 'muted',
    colorKeyValor:  j['color_key_valor']   as String? ?? 'muted',
    fontWeight:     (j['font_weight']      as int?)   ?? 600,
    fontSizeToken:  j['font_size_token']   as String? ?? 'base',
    monospace:      j['monospace']         as bool?   ?? false,
    letterSpacing:  (j['letter_spacing'] as num?)?.toDouble() ?? 0.0,
    showBadge:      j['show_badge']        as bool?   ?? true,
    expandedDefault: j['expanded_default'] as bool?   ?? false,
  );

  /// Color del badge y acento del nodo.
  Color colorAcentoDe(ColorScheme cs) => resolverColor(colorKey, cs);

  /// Color del texto del campo 'valor' del nodo.
  Color colorValorDe(ColorScheme cs) => resolverColor(colorKeyValor, cs);

  /// Estilo de texto para la clave del nodo.
  TextStyle estiloTextoDe(bool activo, ColorScheme cs, double scaling) {
    if (activo) {
      return TextStyle(
        fontSize: resolverFontSize(fontSizeToken, scaling),
        fontWeight: FontWeight.w700,
        color: cs.primary,
      );
    }
    return TextStyle(
      fontSize:      resolverFontSize(fontSizeToken, scaling),
      fontWeight:    FontWeight.values.firstWhere(
        (w) => w.value == fontWeight,
        orElse: () => FontWeight.w600,
      ),
      fontFamily:    monospace ? 'monospace' : null,
      letterSpacing: letterSpacing * scaling,
      color:         colorAcentoDe(cs),
    );
  }
}

// ── Fallback para tipos no presentes en el catálogo ──────────

/// Config de emergencia para tipos desconocidos o no cargados aún.
const kConfigDesconocido = ConfigTipoNodo(
  code: '?', abbreviation: '?', nameEs: 'Desconocido', nameEn: 'Unknown',
  colorKey: 'muted', colorKeyValor: 'muted',
  fontWeight: 600, fontSizeToken: 'base',
  monospace: false, letterSpacing: 0, showBadge: true, expandedDefault: false,
);

/// Config del tipo virtual 'diagnostico' (linter Dart — nunca en BD).
const kConfigDiagnostico = ConfigTipoNodo(
  code: 'diagnostico', abbreviation: 'ERR', nameEs: 'Diagnóstico', nameEn: 'Diagnostic',
  colorKey: 'red', colorKeyValor: 'red',
  fontWeight: 700, fontSizeToken: 'xs',
  monospace: true, letterSpacing: 0, showBadge: true, expandedDefault: false,
);
