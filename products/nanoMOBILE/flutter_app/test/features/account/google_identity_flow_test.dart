import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart' hide GoogleIdentity;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/account/infrastructure/google_sign_in_identity_provider.dart';
import 'package:nanoai/features/account/infrastructure/google_auth_adapter.dart';
import 'package:nanoai/features/account/domain/account_exceptions.dart';
import 'package:nanoai/features/account/data/google_account_repository.dart';

class _Account extends Fake implements GoogleSignInAccount {
  @override
  String get id => 'unit-google-id';
  @override
  String get email => 'unit@example.com';
  @override
  String? get displayName => 'Cuenta de prueba';
  @override
  String? get photoUrl => null;
  @override
  GoogleSignInAuthentication get authentication =>
      const GoogleSignInAuthentication(idToken: 'unit-token-not-real');
}

class _Sdk extends Fake implements GoogleSignIn {
  int initializations = 0, authentications = 0;
  bool failOnce = false, cancel = false;
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializations++;
    if (failOnce && initializations == 1) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );
    }
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    authentications++;
    if (cancel) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    }
    return _Account();
  }
}

class _VerifiedIdentity extends GoogleSignInIdentityProvider {
  @override
  Future<GoogleIdentity> authenticate() async => const GoogleIdentity(
    id: 'verified-test-id',
    email: 'unit.emmanuel.higuita@example.com',
    displayName: 'Cuenta verificada',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('No abre SDK sin Client ID válido ni inventa una cuenta', () async {
    final sdk = _Sdk();
    final provider = GoogleSignInIdentityProvider(
      client: sdk,
      serverClientId: '',
    );
    await expectLater(
      provider.authenticate(),
      throwsA(isA<GoogleSignInNotConfiguredException>()),
    );
    expect(sdk.initializations, 0);
    expect(sdk.authentications, 0);
  });
  test(
    'Inicialización fallida permite reintento y luego reutiliza SDK',
    () async {
      final sdk = _Sdk()..failOnce = true;
      final provider = GoogleSignInIdentityProvider(
        client: sdk,
        serverClientId: '123-unit.apps.googleusercontent.com',
      );
      await expectLater(
        provider.authenticate(),
        throwsA(isA<GoogleSignInNotConfiguredException>()),
      );
      expect((await provider.authenticate()).id, 'unit-google-id');
      await provider.authenticate();
      expect(sdk.initializations, 2);
      expect(sdk.authentications, 2);
    },
  );
  test(
    'Cancelación nativa conserva su significado, sin convertirla en éxito',
    () async {
      final sdk = _Sdk()..cancel = true;
      final provider = GoogleSignInIdentityProvider(
        client: sdk,
        serverClientId: '123-unit.apps.googleusercontent.com',
      );
      await expectLater(
        provider.authenticate(),
        throwsA(isA<GoogleSignInCancelledException>()),
      );
    },
  );
  test(
    'Perfil autenticado no se borra por coincidir con un correo heredado',
    () async {
      final repository = GoogleAccountRepository();
      final adapter = GoogleAuthAdapter(
        identityProvider: _VerifiedIdentity(),
        accountRepository: repository,
      );
      final user = await adapter.signIn();
      final profile = await repository.loadProfile();
      expect(profile.email, user.email);
      expect(profile.identityVerified, isTrue);
      expect(profile.isConnected, isTrue);
      expect(profile.cloudSyncEnabled, isFalse);
      expect(
        profile.copyWith(displayName: 'Otro nombre').identityVerified,
        isTrue,
      );
    },
  );
}
