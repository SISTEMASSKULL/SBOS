// ============================================================
// bauth_desktop · nucleo/api/rutas/tokens.dart
//
// Rutas: bauth.token.*
// Part of bauth_api.dart — usa _rpc (conexión banexus de BauthApi).
// ============================================================

part of '../bauth_api.dart';

extension BauthApiTokens on BauthApi {
  /// Emite un JWT con los claims indicados.
  Future<Map<String, dynamic>> emitirToken(Map<String, dynamic> claims) async =>
      _rpc.llamar('bauth.token.issue', {'claims': claims});

  /// Valida un JWT y retorna los claims verificados.
  Future<Map<String, dynamic>> validarToken(String token) async =>
      _rpc.llamar('bauth.token.validate', {'token': token});
}
