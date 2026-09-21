import 'auth_user.dart';

/// QUÉ HACE:
/// Puerto de autenticación oficial del sistema Nano Mobile (AuthPort).
///
/// CÓMO FUNCIONA:
/// Define el contrato abstracto para interactuar con proveedores de identidad
/// (Firebase Auth, Google Sign-In, etc.). Ninguna pantalla interactúa directamente con SDKs.
///
/// POR QUÉ:
/// Principio de Inversión de Dependencias (DIP) de SOLID: la capa de dominio
/// define la interfaz y la capa de infraestructura provee la implementación.
abstract class AuthRepository {
  /// Emite cambios en el estado del usuario autenticado.
  Stream<AuthUser?> get authStateChanges;

  /// Obtiene el usuario actual en memoria/caché.
  Future<AuthUser?> getCurrentUser();

  /// Inicia sesión con correo y contraseña.
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Registra una nueva cuenta con correo y contraseña de forma idempotente.
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  });

  /// Autenticación unificada mediante Credential Manager / Google Sign-In.
  Future<AuthUser> signInWithGoogle();

  /// Envía correo de recuperación de contraseña.
  Future<void> sendPasswordResetEmail(String email);

  /// Envía correo de verificación al usuario actual.
  Future<void> sendEmailVerification();

  /// Refresca los datos del usuario actual para validar emailVerified.
  Future<AuthUser> reloadUser();

  /// Cierra la sesión activa sin borrar los datos locales de Nano.
  Future<void> signOut();

  /// Elimina la cuenta y revoca credenciales de forma atómica.
  Future<void> deleteAccount();
}
