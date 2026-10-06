import 'dart:async';
import '../domain/account_exceptions.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_credentials_helper.dart';
import 'google_auth_adapter.dart';
import 'local_account_storage.dart';
import 'secure_storage_adapter.dart';

/// QUÉ HACE:
/// Adaptador local de correo y sesión; Google se delega al adaptador OAuth.
class LocalAuthAdapter implements AuthRepository {
  final LocalAccountStorage _localStorage;
  final SecureStorageAdapter _secureStorage;
  final GoogleAuthAdapter _googleAuth;
  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;

  LocalAuthAdapter({
    LocalAccountStorage? localStorage,
    SecureStorageAdapter? secureStorage,
    GoogleAuthAdapter? googleAuth,
  }) : _localStorage = localStorage ?? LocalAccountStorage(),
       _secureStorage = secureStorage ?? SecureStorageAdapter(),
       _googleAuth = googleAuth ?? GoogleAuthAdapter() {
    _init();
  }

  Future<void> _init() async {
    _currentUser = await _localStorage.getUser();
    _authStateController.add(_currentUser);
  }

  @override
  Stream<AuthUser?> get authStateChanges => _authStateController.stream;

  @override
  Future<AuthUser?> getCurrentUser() async {
    _currentUser ??= await _localStorage.getUser();
    return _currentUser;
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final clean = email.trim().toLowerCase();
    if (!clean.contains('@'))
      throw const InvalidCredentialsException('invalid-email');
    if (password.length < 6)
      throw const InvalidCredentialsException('wrong-password');

    final storedHash = await _secureStorage.read('pwd_$clean');
    final incomingHash = AuthCredentialsHelper.hashPassword(password);
    if (storedHash != null && storedHash != incomingHash) {
      throw const InvalidCredentialsException('wrong-password');
    }

    final user = AuthUser(
      uid: AuthCredentialsHelper.deriveUserUid(clean),
      email: clean,
      displayName: clean.split('@').first,
      isEmailVerified: true,
    );

    await _secureStorage.write('pwd_$clean', incomingHash);
    await _localStorage.saveUser(user);
    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<AuthUser> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final clean = email.trim().toLowerCase();
    if (!AuthCredentialsHelper.isValidEmail(clean)) {
      throw const InvalidCredentialsException('invalid-email');
    }
    if (password.length < 8) throw const WeakPasswordException();

    final existing = await _secureStorage.read('pwd_$clean');
    if (existing != null) throw const EmailAlreadyInUseException();

    await _secureStorage.write(
      'pwd_$clean',
      AuthCredentialsHelper.hashPassword(password),
    );
    final user = AuthUser(
      uid: AuthCredentialsHelper.deriveUserUid(clean),
      email: clean,
      displayName: displayName.trim().isNotEmpty
          ? displayName.trim()
          : clean.split('@').first,
      isEmailVerified: false,
    );

    await _localStorage.saveUser(user);
    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    // OAuth entrega la cuenta; este adaptador solo guarda la sesión de Nano local.
    final user = await _googleAuth.signIn();
    _currentUser = user;
    await _localStorage.saveUser(user);
    _authStateController.add(user);
    return user;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    if (!email.trim().toLowerCase().contains('@')) {
      throw const InvalidCredentialsException('invalid-email');
    }
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<AuthUser> reloadUser() async {
    final current = await getCurrentUser();
    if (current == null) throw const UserNotFoundException();
    final updated = current.copyWith(isEmailVerified: true);
    await _localStorage.saveUser(updated);
    _currentUser = updated;
    _authStateController.add(updated);
    return updated;
  }

  @override
  Future<void> signOut() async {
    await _localStorage.clearSession();
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    if (_currentUser != null) {
      await _secureStorage.delete('pwd_${_currentUser!.email}');
    }
    await signOut();
  }
}

/// Mantiene compatibilidad con importadores antiguos; el adaptador ya no usa Firebase.
@Deprecated(
  'Use LocalAuthAdapter; this repository has no Firebase Auth backend.',
)
typedef FirebaseAuthAdapter = LocalAuthAdapter;
