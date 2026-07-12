// ============================================================
// bauth_desktop · test/widget_test.dart
//
// Propósito: pruebas del dominio del Dashboard — el catálogo de motores y
//   los valores iniciales de Theme Options (base Slate · acento Cyan).
// Estándar: ADR-013 (7 motores) · Theme Options.
// ============================================================

import 'package:flutter_test/flutter_test.dart';

import 'package:bauth_desktop/core/theme/sbos_tokens.dart';
import 'package:bauth_desktop/models/motor.dart';

void main() {
  test('el catálogo tiene los 7 motores de capacidad (ADR-013)', () {
    expect(catalogoMotores.length, 7);
    expect(catalogoMotores.first.nombre, 'BitMask');
  });

  test('base inicial es Slate y acento inicial es Cyan', () {
    expect(TokensSbos.baseInicial, 'Slate');
    expect(TokensSbos.acentoInicial, TokensSbos.acentosDisponibles['Cyan']);
  });
}
