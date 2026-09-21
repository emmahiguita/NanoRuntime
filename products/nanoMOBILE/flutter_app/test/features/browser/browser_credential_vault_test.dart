import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/features/browser/domain/browser_credential_model.dart';
import 'package:nanoai/features/browser/infrastructure/browser_credential_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrowserCredentialVault', () {
    late SharedPreferences prefs;
    late BrowserCredentialVault vault;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      vault = BrowserCredentialVault(prefs);
    });

    test('cifra y descifra contraseñas manteniendo integridad HMAC', () {
      const plain = 'ContraseñaSuperSecreta!2026';
      final encrypted = vault.encryptPassword(plain);

      // La contraseña cifrada no debe contener el texto plano
      expect(encrypted.contains(plain), isFalse);
      expect(encrypted, isNotEmpty);

      // Al descifrar debe coincidir exactamente
      final decrypted = vault.decryptPassword(encrypted);
      expect(decrypted, equals(plain));
    });

    test('almacena, recupera y lista credenciales en la bóveda', () async {
      final cred1 = BrowserCredential(
        id: 'cred_1',
        domain: 'google.com',
        username: 'usuario@gmail.com',
        password: 'passGoogle123',
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );

      await vault.saveCredential(cred1);

      final all = await vault.getAllCredentials();
      expect(all.length, equals(1));
      expect(all.first.domain, equals('google.com'));
      expect(all.first.username, equals('usuario@gmail.com'));
      expect(all.first.password, equals('passGoogle123'));
    });

    test('busca credenciales por dominio exacto y subdominios', () async {
      await vault.saveCredential(
        BrowserCredential(
          id: 'c1',
          domain: 'accounts.google.com',
          username: 'admin@google.com',
          password: 'pass1',
          createdAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        ),
      );
      await vault.saveCredential(
        BrowserCredential(
          id: 'c2',
          domain: 'github.com',
          username: 'dev_octocat',
          password: 'pass2',
          createdAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        ),
      );

      final googleCreds = await vault.getCredentialsForDomain('google.com');
      expect(googleCreds.length, equals(1));
      expect(googleCreds.first.username, equals('admin@google.com'));

      final githubCreds = await vault.getCredentialsForDomain('https://github.com/login');
      expect(githubCreds.length, equals(1));
      expect(githubCreds.first.username, equals('dev_octocat'));

      final unknown = await vault.getCredentialsForDomain('sitiodesconocido.com');
      expect(unknown, isEmpty);
    });

    test('elimina credenciales y actualiza existentes sin duplicar', () async {
      await vault.saveCredential(
        BrowserCredential(
          id: 'c1',
          domain: 'netflix.com',
          username: 'user@netflix.com',
          password: 'oldPassword',
          createdAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        ),
      );

      // Actualizar con misma cuenta en el mismo dominio
      await vault.saveCredential(
        BrowserCredential(
          id: 'c1_new',
          domain: 'netflix.com',
          username: 'user@netflix.com',
          password: 'newPassword2026',
          createdAt: DateTime.now(),
          lastUsedAt: DateTime.now(),
        ),
      );

      final list = await vault.getAllCredentials();
      expect(list.length, equals(1));
      expect(list.first.password, equals('newPassword2026'));

      // Eliminar
      await vault.deleteCredential(list.first.id);
      final emptyList = await vault.getAllCredentials();
      expect(emptyList, isEmpty);
    });
  });
}
