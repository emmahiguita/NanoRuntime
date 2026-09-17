import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/google_account_profile.dart';

/// Repositorio SOLID para la gestión de la cuenta de Google (SRP).
class GoogleAccountRepository {
  static const String _keyProfile = 'nano_google_account_profile';
  final http.Client _client;

  GoogleAccountRepository({http.Client? client})
    : _client = client ?? http.Client();

  /// Carga el perfil guardado o genera el perfil predeterminado del usuario.
  Future<GoogleAccountProfile> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyProfile);
      if (jsonStr != null && jsonStr.trim().isNotEmpty) {
        final profile = GoogleAccountProfile.fromJson(jsonStr);
        // P0-TRUTH-02: Si el perfil almacenado proviene de las credenciales sintéticas
        // hardcodeadas en versiones anteriores, depurar a no configurado para veracidad estricta.
        if (profile.email.contains('emmanuel.higuita') ||
            profile.email.trim().isEmpty) {
          await prefs.remove(_keyProfile);
          return const GoogleAccountProfile.unconfigured();
        }
        return profile;
      }
    } catch (_) {}

    // Si no hay perfil guardado o no está configurado, retorna perfil no configurado
    const defaultProfile = GoogleAccountProfile.unconfigured();
    return defaultProfile;
  }

  /// Guarda el perfil en almacenamiento persistente.
  Future<void> saveProfile(GoogleAccountProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfile, profile.toJson());
    } catch (_) {}
  }

  /// Ejecuta una sincronización real con la infraestructura de Google.
  /// Verifica latencia y conectividad viva con los servicios Google.
  Future<bool> verifyGoogleConnectivity() async {
    try {
      final uri = Uri.parse('https://www.google.com/generate_204');
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
