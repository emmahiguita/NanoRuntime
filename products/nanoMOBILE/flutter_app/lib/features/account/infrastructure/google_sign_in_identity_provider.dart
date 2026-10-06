import 'package:google_sign_in/google_sign_in.dart';

import '../domain/account_exceptions.dart';

/// Datos que Google entrega después de autenticar una cuenta real.
class GoogleIdentity {
  const GoogleIdentity({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
}

/// Encapsula el SDK oficial; exige Client ID web para obtener un ID token.
class GoogleSignInIdentityProvider {
  GoogleSignInIdentityProvider({GoogleSignIn? client})
    : _client = client ?? GoogleSignIn.instance;

  static const _serverClientId = String.fromEnvironment(
    'NANO_GOOGLE_SERVER_CLIENT_ID',
  );
  static Future<void>? _initialization;

  final GoogleSignIn _client;

  /// Inicializa una sola vez y convierte la cuenta elegida en identidad verificada.
  Future<GoogleIdentity> authenticate() async {
    if (_serverClientId.trim().isEmpty) {
      throw const GoogleSignInNotConfiguredException();
    }
    try {
      _initialization ??= _client.initialize(serverClientId: _serverClientId);
      await _initialization;
      final account = await _client.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty || account.email.trim().isEmpty) {
        throw const GoogleSignInFailedException();
      }
      return GoogleIdentity(
        id: account.id,
        email: account.email,
        // Google permite cuentas sin nombre visible; el correo da un nombre estable de respaldo.
        displayName: account.displayName ?? account.email.split('@').first,
        photoUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCancelledException();
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        throw const GoogleSignInNotConfiguredException();
      }
      throw const GoogleSignInFailedException();
    }
  }
}
