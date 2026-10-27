import '../domain/account_profile.dart';
import '../domain/account_repository.dart';
import '../domain/auth_user.dart';
import 'local_account_storage.dart';

/// QUÉ HACE:
/// Perfil de cuenta persistido en este dispositivo. El nombre Firestore se
/// conserva por compatibilidad; esta clase no realiza sincronización de nube.
///
/// CÓMO FUNCIONA:
/// Gestiona [AccountProfile] mediante LocalAccountStorage, con acceso por uid.
///
/// POR QUÉ:
/// Garantiza idempotencia estricta en el bootstrap de la cuenta: crear la cuenta
/// múltiples veces no reemplaza el perfil existente ni su plan registrado.
class FirestoreAccountAdapter implements AccountRepository {
  final LocalAccountStorage _localStorage;

  FirestoreAccountAdapter({LocalAccountStorage? localStorage})
    : _localStorage = localStorage ?? LocalAccountStorage();

  @override
  Future<AccountProfile?> getProfile(String uid) async {
    final cached = await _localStorage.getProfile();
    if (cached != null && cached.uid == uid) {
      return cached;
    }
    return null;
  }

  @override
  Future<AccountProfile> bootstrapProfile(AuthUser user) async {
    final existing = await getProfile(user.uid);
    if (existing != null) {
      final updated = existing.copyWith(
        email: user.email,
        displayName: user.displayName.isNotEmpty
            ? user.displayName
            : existing.displayName,
        lastLoginAt: DateTime.now(),
      );
      await _localStorage.saveProfile(updated);
      return updated;
    }

    final newProfile = AccountProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName.isNotEmpty
          ? user.displayName
          : user.email.split('@').first,
      photoUrl: user.photoUrl,
      status: 'active',
      planTier: 'free',
      entitlementSource: 'none',
      syncEnabled: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await _localStorage.saveProfile(newProfile);
    return newProfile;
  }

  @override
  Future<void> updateProfile(AccountProfile profile) async {
    final updated = profile.copyWith(updatedAt: DateTime.now());
    await _localStorage.saveProfile(updated);
  }

  @override
  Future<void> updatePlanTier({
    required String uid,
    required String planTier,
    required String entitlementSource,
  }) async {
    final current = await getProfile(uid);
    if (current != null) {
      final updated = current.copyWith(
        planTier: planTier,
        entitlementSource: entitlementSource,
        updatedAt: DateTime.now(),
      );
      await _localStorage.saveProfile(updated);
    }
  }

  @override
  Future<void> deleteProfile(String uid) async {
    await _localStorage.clearSession();
  }
}
