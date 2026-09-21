import 'account_profile.dart';
import 'auth_user.dart';

/// QUÉ HACE:
/// Puerto para gestión del perfil de cuenta en Firestore/Local (AccountPort).
///
/// CÓMO FUNCIONA:
/// Define operaciones para obtener, crear (de forma idempotente), actualizar
/// y sincronizar datos del perfil de usuario (`users/{uid}`).
///
/// POR QUÉ:
/// Desacopla la persistencia remota (Firestore) y local (SharedPreferences/SQLite),
/// permitiendo una experiencia local-first que no bloquea la app en ausencia de red.
abstract class AccountRepository {
  /// Obtiene el perfil del usuario asociado a su UID único.
  Future<AccountProfile?> getProfile(String uid);

  /// Inicializa el documento de perfil de forma IDEMPOTENTE:
  /// si ya existe no sobreescribe campos existentes; si no existe, lo crea.
  Future<AccountProfile> bootstrapProfile(AuthUser user);

  /// Actualiza campos permitidos del perfil del usuario.
  Future<void> updateProfile(AccountProfile profile);

  /// Actualiza el plan y la fuente de entitlement tras validación de compra.
  Future<void> updatePlanTier({
    required String uid,
    required String planTier,
    required String entitlementSource,
  });

  /// Elimina los datos del perfil de cuenta del usuario en Firestore.
  Future<void> deleteProfile(String uid);
}
