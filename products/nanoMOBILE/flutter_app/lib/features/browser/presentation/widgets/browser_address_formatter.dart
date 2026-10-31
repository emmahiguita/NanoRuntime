// QUÉ: Formateador semántico de URL y analizador de seguridad para Nano Browser.
// CÓMO: Extrae esquema (HTTPS/HTTP), dominio legible y protocolo para visualización nítida estilo Safari.
// POR QUÉ: Evita malformaciones de texto, recortes toscos y clarifica el estado de seguridad (< 120 líneas).

class BrowserAddressSecurityInfo {
  final bool isSecure;
  final bool isInsecureHttp;
  final String schemePrefix;
  final String displayHost;
  final String fullUrl;

  const BrowserAddressSecurityInfo({
    required this.isSecure,
    required this.isInsecureHttp,
    required this.schemePrefix,
    required this.displayHost,
    required this.fullUrl,
  });
}

class BrowserAddressFormatter {
  /// Analiza la URL y retorna información de seguridad y host legible.
  static BrowserAddressSecurityInfo parse(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const BrowserAddressSecurityInfo(
        isSecure: false,
        isInsecureHttp: false,
        schemePrefix: '',
        displayHost: '',
        fullUrl: '',
      );
    }

    final isHttps = trimmed.startsWith('https://');
    final isHttp = trimmed.startsWith('http://');
    final uri = Uri.tryParse(trimmed);
    final host = uri?.host ?? '';

    // Si tiene dominio, se limpia el prefijo www. para ahorrar espacio en vista compacta.
    String displayHost = host;
    if (displayHost.startsWith('www.')) {
      displayHost = displayHost.substring(4);
    }

    // Si no hay host válido (p. ej. búsqueda o página interna), se usa el texto disponible.
    if (displayHost.isEmpty) {
      displayHost = trimmed;
    }

    return BrowserAddressSecurityInfo(
      isSecure: isHttps,
      isInsecureHttp: isHttp,
      schemePrefix: isHttp ? 'http://' : (isHttps ? 'https://' : ''),
      displayHost: displayHost,
      fullUrl: trimmed,
    );
  }
}
