// ============================================================
// bauth_desktop · core/theme/theme_provider.dart
//
// Propósito: **Theme Options** — el estado CONFIGURABLE del tema (nada
//   estático). El usuario elige en runtime: modo (oscuro/claro/sistema),
//   base neutra (Slate inicial), color de acento (Cyan inicial) y radio de
//   esquinas. El ThemeData se reconstruye desde estas opciones.
// Dependencias: flutter_riverpod, tf_shadcn_flutter (ThemeMode), sbos_tokens.
// Estándar: Riverpod 3.x (Notifier) · shadcn_flutter theme system.
// ============================================================

import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tf_shadcn_flutter/shadcn_flutter.dart' show ThemeMode;

import 'sbos_tokens.dart';

/// Opciones de tema elegidas por el usuario (value object inmutable).
class OpcionesTema {
  final ThemeMode modo;
  final String base; // clave de TokensSbos.basesDisponibles
  final Color acento; // color primario/acento
  final double radio; // factor de radio de esquinas (0.0–1.5)

  const OpcionesTema({
    required this.modo,
    required this.base,
    required this.acento,
    required this.radio,
  });

  OpcionesTema copyWith({
    ThemeMode? modo,
    String? base,
    Color? acento,
    double? radio,
  }) =>
      OpcionesTema(
        modo: modo ?? this.modo,
        base: base ?? this.base,
        acento: acento ?? this.acento,
        radio: radio ?? this.radio,
      );
}

/// Notifier de Theme Options. Inicial: oscuro · Slate · Cyan · radio 0.5.
class OpcionesTemaNotifier extends Notifier<OpcionesTema> {
  @override
  OpcionesTema build() => const OpcionesTema(
        modo: ThemeMode.dark,
        base: TokensSbos.baseInicial, // Slate
        acento: TokensSbos.acentoInicial, // Cyan
        radio: 0.5,
      );

  void alternarModo() => state = state.copyWith(
      modo: state.modo == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  void fijarModo(ThemeMode m) => state = state.copyWith(modo: m);
  void fijarBase(String b) => state = state.copyWith(base: b);
  void fijarAcento(Color c) => state = state.copyWith(acento: c);
  void fijarRadio(double r) => state = state.copyWith(radio: r);
}

/// Provider de Theme Options — lo observa `ShadcnApp` para reconstruir el tema.
final opcionesTemaProvider =
    NotifierProvider<OpcionesTemaNotifier, OpcionesTema>(
        OpcionesTemaNotifier.new);
