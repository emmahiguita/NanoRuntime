import 'auth_user.dart';
import 'account_profile.dart';

/// QUÉ HACE:
/// Define los estados explícitos de la máquina de estados de sesión de Nano.
///
/// CÓMO FUNCIONA:
/// Cada estado representa un punto inequívoco en el ciclo de vida de la cuenta,
/// eliminando booleanos concurrentes contradictorios (como isLoading, isLogged).
///
/// POR QUÉ:
/// Evita flashes de pantalla (mostrar Login antes de saber si hay sesión válida),
/// y soporta el modo local-first offlineAuthenticated cuando Firebase no está disponible.
enum AuthStatus {
  unknown,
  initializing,
  authenticated,
  offlineAuthenticated,
  unauthenticated,
  emailVerificationRequired,
  accountDisabled,
  error,
}

class AuthState {
  final AuthStatus status;
  final AuthUser user;
  final AccountProfile profile;
  final String? errorMessage;
  final bool isOperationInProgress;

  const AuthState({
    required this.status,
    required this.user,
    required this.profile,
    this.errorMessage,
    this.isOperationInProgress = false,
  });

  /// Estado inicial de arranque de la aplicación.
  factory AuthState.initial() => const AuthState(
    status: AuthStatus.unknown,
    user: AuthUser.empty,
    profile: AccountProfile.empty,
  );

  /// Estado de inicialización activa (hidratando sesión local/remota).
  factory AuthState.initializing() => const AuthState(
    status: AuthStatus.initializing,
    user: AuthUser.empty,
    profile: AccountProfile.empty,
  );

  /// Sesión activa validada en línea.
  factory AuthState.authenticated({
    required AuthUser user,
    required AccountProfile profile,
  }) => AuthState(
    status: AuthStatus.authenticated,
    user: user,
    profile: profile,
  );

  /// Sesión activa validada localmente (modo offline / local-first).
  factory AuthState.offlineAuthenticated({
    required AuthUser user,
    required AccountProfile profile,
  }) => AuthState(
    status: AuthStatus.offlineAuthenticated,
    user: user,
    profile: profile,
  );

  /// Usuario sin sesión activa (debe mostrar flujo de Login/Registro).
  factory AuthState.unauthenticated() => const AuthState(
    status: AuthStatus.unauthenticated,
    user: AuthUser.empty,
    profile: AccountProfile.empty,
  );

  /// Usuario registrado pero con correo pendiente de validación.
  factory AuthState.emailVerificationRequired({
    required AuthUser user,
    required AccountProfile profile,
  }) => AuthState(
    status: AuthStatus.emailVerificationRequired,
    user: user,
    profile: profile,
  );

  /// Cuenta deshabilitada por el backend.
  factory AuthState.accountDisabled({
    required AuthUser user,
    required AccountProfile profile,
  }) => AuthState(
    status: AuthStatus.accountDisabled,
    user: user,
    profile: profile,
  );

  /// Error en la autenticación o verificación.
  factory AuthState.error(String message) => AuthState(
    status: AuthStatus.error,
    user: AuthUser.empty,
    profile: AccountProfile.empty,
    errorMessage: message,
  );

  bool get isAuthenticated =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.offlineAuthenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    AccountProfile? profile,
    String? errorMessage,
    bool? isOperationInProgress,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      errorMessage: errorMessage ?? this.errorMessage,
      isOperationInProgress:
          isOperationInProgress ?? this.isOperationInProgress,
    );
  }
}
