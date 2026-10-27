import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/account/domain/auth_user.dart';
import 'package:nanoai/features/account/infrastructure/firebase_auth_adapter.dart';
import 'package:nanoai/features/account/infrastructure/local_account_storage.dart';
import 'package:nanoai/features/account/infrastructure/google_auth_adapter.dart';

class _Storage extends Fake implements LocalAccountStorage {
  final initial = Completer<AuthUser?>();
  AuthUser? saved;
  @override
  Future<AuthUser?> getUser() => initial.future;
  @override
  Future<void> saveUser(AuthUser user) async => saved = user;
}

class _Google extends Fake implements GoogleAuthAdapter {
  int calls = 0;
  @override
  Future<AuthUser> signIn() async {
    calls++;
    return const AuthUser(
      uid: 'goog_new',
      email: 'new@example.com',
      displayName: 'Nueva',
    );
  }
}

void main() {
  test(
    'Restauración tardía no sobrescribe la sesión nueva de Google',
    () async {
      final storage = _Storage(), google = _Google();
      final adapter = LocalAuthAdapter(
        localStorage: storage,
        googleAuth: google,
      );
      final pending = adapter.signInWithGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(google.calls, 0);
      storage.initial.complete(
        const AuthUser(
          uid: 'old',
          email: 'old@example.com',
          displayName: 'Anterior',
        ),
      );
      final user = await pending;
      expect(user.uid, 'goog_new');
      expect(storage.saved?.uid, 'goog_new');
      expect((await adapter.getCurrentUser())?.uid, 'goog_new');
    },
  );
}
