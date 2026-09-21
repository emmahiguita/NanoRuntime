import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/account/domain/account_profile.dart';
import 'package:nanoai/features/account/domain/auth_state.dart';
import 'package:nanoai/features/account/domain/auth_user.dart';

void main() {
  group('AuthState & Session Machine Tests', () {
    test('Estado inicial es unknown', () {
      final state = AuthState.initial();
      expect(state.status, equals(AuthStatus.unknown));
      expect(state.isAuthenticated, isFalse);
      expect(state.user.isEmpty, isTrue);
    });

    test('Estado initializing representa carga de sesión', () {
      final state = AuthState.initializing();
      expect(state.status, equals(AuthStatus.initializing));
      expect(state.isAuthenticated, isFalse);
    });

    test('authenticated representa sesión verificada', () {
      const user = AuthUser(
        uid: 'usr_123',
        email: 'test@nano.ai',
        displayName: 'Emmanuel Higuita',
        isEmailVerified: true,
      );
      const profile = AccountProfile(
        uid: 'usr_123',
        email: 'test@nano.ai',
        planTier: 'pro',
      );
      final state = AuthState.authenticated(user: user, profile: profile);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.isAuthenticated, isTrue);
      expect(state.profile.isPro, isTrue);
      expect(state.user.initials, equals('EH'));

    });

    test('offlineAuthenticated mantiene operatividad local-first', () {
      const user = AuthUser(
        uid: 'usr_456',
        email: 'offline@nano.ai',
        displayName: 'Offline User',
        isEmailVerified: true,
      );
      const profile = AccountProfile(
        uid: 'usr_456',
        email: 'offline@nano.ai',
        planTier: 'free',
      );
      final state = AuthState.offlineAuthenticated(user: user, profile: profile);
      expect(state.status, equals(AuthStatus.offlineAuthenticated));
      expect(state.isAuthenticated, isTrue);
    });

    test('emailVerificationRequired detiene avance hasta verificar', () {
      const user = AuthUser(
        uid: 'usr_789',
        email: 'unverified@nano.ai',
        isEmailVerified: false,
      );
      const profile = AccountProfile(
        uid: 'usr_789',
        email: 'unverified@nano.ai',
      );
      final state = AuthState.emailVerificationRequired(
        user: user,
        profile: profile,
      );
      expect(state.status, equals(AuthStatus.emailVerificationRequired));
      expect(state.isAuthenticated, isFalse);
    });

    test('accountDisabled bloquea acceso', () {
      const user = AuthUser(uid: 'usr_000', email: 'blocked@nano.ai');
      const profile = AccountProfile(
        uid: 'usr_000',
        email: 'blocked@nano.ai',
        status: 'disabled',
      );
      final state = AuthState.accountDisabled(user: user, profile: profile);
      expect(state.status, equals(AuthStatus.accountDisabled));
      expect(state.isAuthenticated, isFalse);
    });
  });
}
