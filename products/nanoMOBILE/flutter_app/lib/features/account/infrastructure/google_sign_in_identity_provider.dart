import 'package:google_sign_in/google_sign_in.dart';
import '../domain/account_exceptions.dart';
import 'google_oauth_configuration.dart';

/// Identidad devuelta por el SDK oficial, nunca por un correo escrito a mano.
class GoogleIdentity {
  const GoogleIdentity({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });
  final String id, email, displayName;
  final String? photoUrl;
}

/// Inicializa Google una vez por cliente y permite reintentar una inicialización
/// fallida. Una Future rechazada no debe dejar el acceso bloqueado hasta reiniciar.
class GoogleSignInIdentityProvider {
  GoogleSignInIdentityProvider({GoogleSignIn? client, String? serverClientId})
    : _client = client ?? GoogleSignIn.instance,
      _serverClientId =
          (serverClientId ??
                  const String.fromEnvironment(
                    'NANO_GOOGLE_SERVER_CLIENT_ID',
                    defaultValue: GoogleOAuthConfiguration.webClientId,
                  ))
              .trim();
  final GoogleSignIn _client;
  final String _serverClientId;
  static final _initializations = Expando<Future<void>>();

  Future<void> _initialize() async {
    final pending = _initializations[_client] ??= _client.initialize(
      serverClientId: _serverClientId,
    );
    try {
      await pending;
    } catch (_) {
      if (identical(_initializations[_client], pending)) {
        _initializations[_client] = null;
      }
      rethrow;
    }
  }

  Future<GoogleIdentity> authenticate() async {
    // El Client ID es público. No se sustituye por una API key ni uno de muestra.
    if (!RegExp(
      r'^[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$',
    ).hasMatch(_serverClientId)) {
      throw const GoogleSignInNotConfiguredException();
    }
    try {
      await _initialize();
      if (!_client.supportsAuthenticate()) {
        throw const GoogleSignInFailedException();
      }
      final account = await _client.authenticate();
      final token = account.authentication.idToken;
      if (token == null ||
          token.isEmpty ||
          account.id.trim().isEmpty ||
          account.email.trim().isEmpty) {
        throw const GoogleSignInFailedException();
      }
      return GoogleIdentity(
        id: account.id,
        email: account.email,
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
