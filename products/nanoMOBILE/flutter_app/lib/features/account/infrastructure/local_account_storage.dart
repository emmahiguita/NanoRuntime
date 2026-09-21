import 'package:shared_preferences/shared_preferences.dart';
import '../domain/account_profile.dart';
import '../domain/auth_user.dart';


/// QUÉ HACE:
/// Persiste y recupera el perfil y la sesión del usuario en almacenamiento local.
///
/// CÓMO FUNCIONA:
/// Almacena representaciones JSON de [AuthUser] y [AccountProfile] en [SharedPreferences]
/// para que el Session Gate pueda hidratar la sesión instantáneamente sin depender de la red.
///
/// POR QUÉ:
/// Soporte Local-First estricto: Nano Mobile funciona aunque no haya conexión a Internet.
/// Una sesión previa válida no debe destruirse si los servidores de Firebase no responden.
class LocalAccountStorage {
  static const String _keyUser = 'nano_account_user';
  static const String _keyProfile = 'nano_account_profile';
  static const String _keyDeviceId = 'nano_device_unique_id';

  final SharedPreferences? _prefsInstance;

  LocalAccountStorage({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  Future<void> saveUser(AuthUser user) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyUser, user.toJson());
  }

  Future<AuthUser?> getUser() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthUser.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(AccountProfile profile) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyProfile, profile.toJson());
  }

  Future<AccountProfile?> getProfile() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_keyProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AccountProfile.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await _getPrefs();
    String? id = prefs.getString(_keyDeviceId);
    if (id == null || id.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      id = 'dev-$now';
      await prefs.setString(_keyDeviceId, id);
    }
    return id;
  }

  Future<void> clearSession() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyUser);
    await prefs.remove(_keyProfile);
  }
}
