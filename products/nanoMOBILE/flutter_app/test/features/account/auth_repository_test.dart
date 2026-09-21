import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/account/domain/account_exceptions.dart';
import 'package:nanoai/features/account/infrastructure/firebase_auth_adapter.dart';
import 'package:nanoai/features/account/infrastructure/local_account_storage.dart';
import 'package:nanoai/features/account/infrastructure/secure_storage_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseAuthAdapter adapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    adapter = FirebaseAuthAdapter(
      localStorage: LocalAccountStorage(prefs: prefs),
      secureStorage: SecureStorageAdapter(prefs: prefs),
    );
  });

  group('FirebaseAuthAdapter Tests', () {
    test('Registro exitoso con contraseña válida', () async {
      final user = await adapter.registerWithEmailAndPassword(
        email: 'nuevo@nano.ai',
        password: 'PasswordSegura123',
        displayName: 'Emmanuel H',
      );

      expect(user.uid, isNotEmpty);
      expect(user.email, equals('nuevo@nano.ai'));
      expect(user.displayName, equals('Emmanuel H'));
      expect(user.isEmailVerified, isFalse);
    });

    test('Registro falla si la contraseña tiene menos de 8 caracteres', () async {
      expect(
        () => adapter.registerWithEmailAndPassword(
          email: 'corto@nano.ai',
          password: '123',
          displayName: 'Test',
        ),
        throwsA(isA<WeakPasswordException>()),
      );
    });

    test('Registro rechaza correos duplicados', () async {
      await adapter.registerWithEmailAndPassword(
        email: 'duplicado@nano.ai',
        password: 'PasswordSegura123',
        displayName: 'Primero',
      );

      expect(
        () => adapter.registerWithEmailAndPassword(
          email: 'duplicado@nano.ai',
          password: 'PasswordSegura123',
          displayName: 'Segundo',
        ),
        throwsA(isA<EmailAlreadyInUseException>()),
      );
    });

    test('Login con credenciales correctas retorna usuario', () async {
      await adapter.registerWithEmailAndPassword(
        email: 'login@nano.ai',
        password: 'PasswordSegura123',
        displayName: 'Usuario Login',
      );

      final user = await adapter.signInWithEmailAndPassword(
        email: 'login@nano.ai',
        password: 'PasswordSegura123',
      );

      expect(user.email, equals('login@nano.ai'));
      expect(user.displayName, equals('login'));
    });

    test('Login con contraseña incorrecta arroja InvalidCredentialsException', () async {
      await adapter.registerWithEmailAndPassword(
        email: 'login@nano.ai',
        password: 'PasswordSegura123',
        displayName: 'Usuario Login',
      );

      expect(
        () => adapter.signInWithEmailAndPassword(
          email: 'login@nano.ai',
          password: 'PasswordIncorrecta99',
        ),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });

    test('Google Sign-In genera sesión válida e idempotente', () async {
      final u1 = await adapter.signInWithGoogle();
      final u2 = await adapter.signInWithGoogle();

      expect(u1.uid, equals(u2.uid));
      expect(u1.email, equals(u2.email));
      expect(u1.isEmailVerified, isTrue);
    });

    test('SignOut limpia la sesión activa', () async {
      await adapter.signInWithGoogle();
      expect(await adapter.getCurrentUser(), isNotNull);

      await adapter.signOut();
      expect(await adapter.getCurrentUser(), isNull);
    });

    test('deleteAccount revoca credenciales y limpia sesión', () async {
      await adapter.registerWithEmailAndPassword(
        email: 'borrar@nano.ai',
        password: 'PasswordSegura123',
        displayName: 'Borrar',
      );

      await adapter.deleteAccount();
      expect(await adapter.getCurrentUser(), isNull);
    });
  });
}
