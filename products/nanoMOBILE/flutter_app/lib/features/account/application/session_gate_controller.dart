import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/account_profile.dart';
import '../domain/account_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_state.dart';
import '../domain/auth_user.dart';

/// QUÉ HACE:
/// Controlador central de la sesión en el ciclo de vida de la aplicación.
///
/// CÓMO FUNCIONA:
/// Al iniciar Nano, hidrata la sesión persistente local. Si existe sesión,
/// arranca de inmediato sin mostrar pantallas de login (Session Gate real).
/// Valida si se requiere verificación de correo o si la cuenta está deshabilitada.
///
/// POR QUÉ:
/// Regla 2 del sistema: evitar flashes y no inferir estados con booleanos sueltos.
class SessionGateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final AccountRepository _accountRepository;
  StreamSubscription<AuthUser?>? _authSubscription;

  SessionGateNotifier({
    required AuthRepository authRepository,
    required AccountRepository accountRepository,
  }) : _authRepository = authRepository,
       _accountRepository = accountRepository,
       super(AuthState.initial()) {
    _init();
  }

  Future<void> _init() async {
    state = AuthState.initializing();
    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null && user.isNotEmpty) {
        await _resolveAuthenticatedUser(user);
      } else {
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      state = AuthState.unauthenticated();
    }

    _authSubscription = _authRepository.authStateChanges.listen((user) {
      if (user == null || user.isEmpty) {
        state = AuthState.unauthenticated();
      } else {
        _resolveAuthenticatedUser(user);
      }
    });
  }

  Future<void> _resolveAuthenticatedUser(AuthUser user) async {
    try {
      final profile = await _accountRepository.bootstrapProfile(user);

      if (profile.status == 'disabled') {
        state = AuthState.accountDisabled(user: user, profile: profile);
        return;
      }

      if (!user.isEmailVerified && !user.isAnonymous) {
        state = AuthState.emailVerificationRequired(
          user: user,
          profile: profile,
        );
        return;
      }

      state = AuthState.authenticated(user: user, profile: profile);
    } catch (_) {
      // Fallback a autenticación offline local-first
      state = AuthState.offlineAuthenticated(
        user: user,
        profile: AccountProfile.empty.copyWith(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
        ),
      );
    }
  }

  /// Actualiza los datos del perfil tanto en almacenamiento como en la máquina de estado.
  Future<void> updateProfile(AccountProfile updated) async {
    await _accountRepository.updateProfile(updated);
    if (state.status == AuthStatus.authenticated) {
      state = AuthState.authenticated(user: state.user, profile: updated);
    } else {
      state = AuthState.offlineAuthenticated(user: state.user, profile: updated);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
