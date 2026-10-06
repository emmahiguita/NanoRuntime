import '../data/google_account_repository.dart';
import '../domain/auth_user.dart';
import '../domain/google_account_profile.dart';
import 'google_sign_in_identity_provider.dart';

/// Traduce la identidad autenticada por Google al modelo de dominio Nano.
class GoogleAuthAdapter {
  GoogleAuthAdapter({
    GoogleSignInIdentityProvider? identityProvider,
    GoogleAccountRepository? accountRepository,
  }) : _identityProvider = identityProvider ?? GoogleSignInIdentityProvider(),
       _accountRepository = accountRepository ?? GoogleAccountRepository();

  final GoogleSignInIdentityProvider _identityProvider;
  final GoogleAccountRepository _accountRepository;

  /// Usa el ID estable de Google; no acepta correos escritos ni cuentas de muestra.
  Future<AuthUser> signIn() async {
    final identity = await _identityProvider.authenticate();
    final user = AuthUser(
      uid: 'goog_${identity.id}',
      email: identity.email,
      displayName: identity.displayName,
      photoUrl: identity.photoUrl,
      isEmailVerified: true,
    );
    await _accountRepository.saveProfile(
      GoogleAccountProfile(
        email: identity.email,
        displayName: identity.displayName,
        avatarUrl: identity.photoUrl,
        isConnected: true,
        syncStatus:
            'Cuenta autenticada; los permisos de Google se conceden aparte',
      ),
    );
    return user;
  }
}
