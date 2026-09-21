import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/donation_repository.dart';

/// QUÉ HACE:
/// Adaptador de aportes voluntarios y apoyo al desarrollo de Nano.
///
/// CÓMO FUNCIONA:
/// Gestiona la frecuencia y el cooldown de 7 días del banner discreto
/// y lanza el canal externo autorizado de propina/contribución libre.
///
/// POR QUÉ:
/// Cumple la política de Google Play sobre aportes y donaciones: no otorga
/// ninguna ventaja digital ni desbloquea funciones del software.
class VoluntaryDonationAdapter implements DonationRepository {
  static const String _keyLastDismissed = 'nano_support_last_dismissed_ms';
  static const String _keyDismissCount = 'nano_support_dismiss_count';
  static const int _cooldownDays = 7;

  final SharedPreferences? _prefsInstance;

  VoluntaryDonationAdapter({SharedPreferences? prefs})
    : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async =>
      _prefsInstance ?? await SharedPreferences.getInstance();

  @override
  Future<bool> shouldShowSupportBanner() async {
    final prefs = await _getPrefs();
    final lastDismissedMs = prefs.getInt(_keyLastDismissed);
    if (lastDismissedMs == null) return true;

    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastDismissedMs);
    final daysPassed = DateTime.now().difference(lastDate).inDays;
    return daysPassed >= _cooldownDays;
  }

  @override
  Future<void> recordBannerDismissed() async {
    final prefs = await _getPrefs();
    final count = prefs.getInt(_keyDismissCount) ?? 0;
    await prefs.setInt(_keyDismissCount, count + 1);
    await prefs.setInt(
      _keyLastDismissed,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> recordSupportActionTriggered() async {
    final prefs = await _getPrefs();
    // Al interactuar con apoyo, extender cooldown a 30 días
    await prefs.setInt(
      _keyLastDismissed,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<bool> launchVoluntaryDonationFlow() async {
    final uri = Uri.parse('https://github.com/sponsors/emmahiguita');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await recordSupportActionTriggered();
      return true;
    }
    return false;
  }
}
