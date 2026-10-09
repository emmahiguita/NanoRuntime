/// Describe requisitos estables de compatibilidad para sitios concretos.
///
/// La decisión vive fuera de la UI para no repartir excepciones de dominio
/// entre menús, pestañas y callbacks del WebView.
class BrowserSiteProfile {
  const BrowserSiteProfile._();

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
