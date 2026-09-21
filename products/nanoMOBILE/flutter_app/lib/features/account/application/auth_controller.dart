import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/account_exceptions.dart';
import '../domain/account_repository.dart';
import '../domain/auth_repository.dart';

/// QUÉ HACE:
/// Controlador de casos de uso de autenticación para la capa de presentación.
///
/// CÓMO FUNCIONA:
/// Ejecuta operaciones de login, registro, Google Sign-In, logout y borrado de cuenta.
/// Captura errores técnicos de infraestructura y los traduce a mensajes humanos legibles.
///
/// POR QUÉ:
/// Principio de Responsabilidad Única (SRP): la UI delega la orquestación a este
/// controlador sin acoplarse a repositorios ni SDKs.
class AuthController extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _authRepository;
  final AccountRepository? _accountRepository;

  AuthController(
    this._authRepository, {
    AccountRepository? accountRepository,
  })  : _accountRepository = accountRepository,
        super(const AsyncValue.data(null));

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = const AsyncValue.data(null);
      return null;
    } on AccountException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return e.message;
    } catch (_) {
      const msg = 'Error inesperado al iniciar sesión. Intenta nuevamente.';
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> register({
    required String email,
    required String password,
    required String displayName,
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
  }) async {
    state = const AsyncValue.loading();
    try {
      final effectiveName = displayName.isNotEmpty
          ? displayName
          : ('$firstName $lastName').trim();
      final user = await _authRepository.registerWithEmailAndPassword(
        email: email,
        password: password,
        displayName: effectiveName.isNotEmpty ? effectiveName : email.split('@').first,
      );
      if (_accountRepository != null) {
        final profile = await _accountRepository.bootstrapProfile(user);
        await _accountRepository.updateProfile(
          profile.copyWith(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            country: country,
            displayName: effectiveName.isNotEmpty ? effectiveName : profile.displayName,
          ),
        );
      }
      state = const AsyncValue.data(null);
      return null;
    } on AccountException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return e.message;
    } catch (_) {
      const msg = 'No se pudo crear la cuenta. Verifica tus datos.';
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> continueWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.signInWithGoogle();
      state = const AsyncValue.data(null);
      return null;
    } on AccountException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return e.message;
    } catch (_) {
      const msg = 'No se pudo completar el acceso con Google.';
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
      return null;
    } on AccountException catch (e) {
      state = AsyncValue.error(e.message, StackTrace.current);
      return e.message;
    } catch (_) {
      const msg = 'Error al enviar enlace de recuperación.';
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }

  Future<void> reloadUser() async {
    try {
      await _authRepository.reloadUser();
    } catch (_) {}
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _authRepository.signOut();
    state = const AsyncValue.data(null);
  }

  Future<String?> deleteAccount() async {
    state = const AsyncValue.loading();
    try {
      await _authRepository.deleteAccount();
      state = const AsyncValue.data(null);
      return null;
    } catch (_) {
      const msg = 'Error al eliminar la cuenta.';
      state = AsyncValue.error(msg, StackTrace.current);
      return msg;
    }
  }
}
