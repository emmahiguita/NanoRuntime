/// Describe requisitos estables de compatibilidad para sitios concretos.
///
/// La decisión vive fuera de la UI para no repartir excepciones de dominio
/// entre menús, pestañas y callbacks del WebView.
class BrowserSiteProfile {
  const BrowserSiteProfile._();

  static const _mobileHostSuffixes = <String>{
    'tiktok.com',
    'tiktokv.com',
    'tiktokcdn.com',
    'tiktokcdn-us.com',
    'ttwstatic.com',
  };

  static bool _matchesHost(String host, String suffix) =>
      host == suffix || host.endsWith('.$suffix');

  static bool isTikTokWebUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    return _mobileHostSuffixes.any((suffix) => _matchesHost(host, suffix));
  }

  /// TikTok móvil usa Chrome Android; el modo escritorio conserva su identidad
  /// propia y solo adapta el viewport al ancho físico disponible.
  static bool requiresMobileIdentity(
    String rawUrl, {
    bool userDesktopMode = false,
  }) => isTikTokWebUrl(rawUrl) && !userDesktopMode;

  static bool usesAdaptiveDesktop({
    required String url,
    required bool userDesktopMode,
  }) => userDesktopMode && isTikTokWebUrl(url);

  /// Ambos perfiles de TikTok usan el ancho del dispositivo. La diferencia
  /// funcional proviene de la identidad HTTP móvil o desktop, no de encoger un
  /// canvas fijo de 1280 px.
  static bool usesDeviceWidthLayout(String rawUrl) => isTikTokWebUrl(rawUrl);

  /// WhatsApp Web solo entrega su aplicación completa con identidad desktop.
  static bool requiresDesktopIdentity(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    return uri?.scheme == 'https' &&
        uri?.host.toLowerCase() == 'web.whatsapp.com';
  }

  /// Respeta la preferencia del usuario y fuerza desktop solo donde es requisito.
  static bool usesDesktop({
    required String url,
    required bool userDesktopMode,
  }) => userDesktopMode || requiresDesktopIdentity(url);
}
