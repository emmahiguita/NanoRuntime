/// QUÉ HACE:
/// Puerto para la gestión de aportes voluntarios y apoyo a Nano (DonationPort).
///
/// CÓMO FUNCIONA:
/// Gestiona la visualización respetuosa del banner de apoyo (cooldowns, dismisses)
/// y el procesamiento de contribuciones 100% voluntarias.
///
/// POR QUÉ:
/// Cumplimiento estricto de Google Play: un aporte voluntario NO debe otorgar
/// funciones Pro, insignias ni contenido digital ventajoso. Permanece completamente
/// desacoplado del módulo de suscripciones.
abstract class DonationRepository {
  /// Determina si el banner de apoyo puede mostrarse según el cooldown y dismiss count.
  Future<bool> shouldShowSupportBanner();

  /// Registra que el usuario descartó el banner ("Ahora no"), aplicando cooldown de 7 días.
  Future<void> recordBannerDismissed();

  /// Registra que el usuario abrió el flujo de apoyo voluntario.
  Future<void> recordSupportActionTriggered();

  /// Inicia el flujo de aporte voluntario externo autorizado.
  Future<bool> launchVoluntaryDonationFlow();
}
