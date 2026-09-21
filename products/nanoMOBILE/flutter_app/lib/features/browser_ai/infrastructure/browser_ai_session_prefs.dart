import 'package:shared_preferences/shared_preferences.dart';

/// QUÉ HACE:
/// Persiste y recupera el tabId asociado a cada proveedor AI entre reinicios.
///
/// CÓMO FUNCIONA:
/// Usa SharedPreferences con claves prefijadas para guardar/leer el tabId de
/// cada proveedor. Si el tab ya no existe en memoria, el session manager crea uno nuevo.
///
/// POR QUÉ:
/// Sin esto, cada reinicio de la app crea una nueva pestaña sin cookies → login perdido.
class BrowserAiSessionPrefs {
  static const _prefix = 'nano_ai_tab_';

  /// Guarda el tabId para un providerId.
  static Future<void> saveTabId(String providerId, String tabId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$providerId', tabId);
  }

  /// Recupera el tabId guardado para un providerId, o null si no existe.
  static Future<String?> loadTabId(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$providerId');
  }

  /// Elimina el tabId persistido (cuando la sesión se invalida).
  static Future<void> clearTabId(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$providerId');
  }
}
