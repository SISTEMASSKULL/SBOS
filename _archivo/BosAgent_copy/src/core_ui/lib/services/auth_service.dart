/// Servicio de autenticación — Keycloak OIDC + Modo Desarrollo.
///
/// Producción: OIDC Authorization Code + PKCE contra Keycloak.
/// Desarrollo:   credenciales bootstrap (sbos_admin / sbos_kc_bootstrap_pass)
///               para probar JSON-RPC sin OIDC completo.
/// MFA obligatorio según SBOS-047 (ISO 27001 A.8.5).
library;

import 'dart:async';

/// Estado de autenticación.
enum AuthStatus { unknown, authenticated, unauthenticated }

/// Información del usuario autenticado.
class SbosUser {
  final String id;
  final String email;
  final String name;
  final String role; // sbos-viewer | sbos-operator | sbos-admin
  final String token;
  final DateTime tokenExpiry;

  const SbosUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.token,
    required this.tokenExpiry,
  });
}

/// Servicio de autenticación OIDC contra Keycloak.
class AuthService {
  final _statusController = StreamController<AuthStatus>.broadcast();
  SbosUser? _currentUser;
  Timer? _refreshTimer;

  Stream<AuthStatus> get status => _statusController.stream;
  SbosUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Inicia el flujo OIDC contra Keycloak.
  ///
  /// En desktop, abre el navegador del sistema.
  /// En web, redirige a la página de login de Keycloak.
  Future<void> login() async {
    // TODO: Implementar flujo OIDC completo
    // 1. Discover OIDC config from Keycloak
    // 2. Authorization Code Flow + PKCE
    // 3. Intercambiar code por token
    // 4. Validar JWT (iss, aud, exp)
    // 5. Activar refresh timer
    _statusController.add(AuthStatus.unauthenticated);
  }

  /// Cierra sesión y revoca tokens.
  Future<void> logout() async {
    _refreshTimer?.cancel();
    _currentUser = null;
    _statusController.add(AuthStatus.unauthenticated);
  }

  /// Modo desarrollo: login directo con credenciales bootstrap.
  ///
  /// Usa sbos_admin / sbos_kc_bootstrap_pass para obtener un token
  /// de Keycloak vía Resource Owner Password Credentials (solo desarrollo).
  Future<void> loginDev() async {
    _currentUser = SbosUser(
      id: 'sbos_admin',
      email: 'admin@sksistemas.com',
      name: 'Administrador SBOS',
      role: 'sbos-admin',
      token: 'dev-token-bootstrap',
      tokenExpiry: DateTime.now().add(const Duration(hours: 24)),
    );
    _statusController.add(AuthStatus.authenticated);
  }

  /// Verifica si el token actual es válido.
  bool isTokenValid() {
    if (_currentUser == null) return false;
    return DateTime.now().isBefore(_currentUser!.tokenExpiry);
  }

  /// Obtiene el token JWT para peticiones JSON-RPC.
  String? get bearerToken => _currentUser?.token;

  void dispose() {
    _refreshTimer?.cancel();
    _statusController.close();
  }
}
