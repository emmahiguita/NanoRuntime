/// Traduce hechos reportados por WebView sin diagnosticar una red que no medimos.
class BrowserLoadErrorDescription {
  const BrowserLoadErrorDescription._();

  /// HTTP, DNS, certificado y desconexión tienen mensajes diferentes.
  static String describe(String? message, int? code) {
    final error = (message ?? '').toLowerCase();
    if (code != null && code >= 400) {
      return 'El servidor respondió con el error HTTP $code. '
          'Puedes reintentar o comprobar si la dirección sigue disponible.';
    }
    if (error.contains('name_not_resolved')) {
      return 'No se pudo encontrar el servidor. Revisa la dirección y tu conexión.';
    }
    if (error.contains('internet_disconnected') || error.contains('offline')) {
      return 'No se pudo acceder a la red. Comprueba Wi-Fi o datos móviles.';
    }
    if (error.contains('timed_out') || error.contains('timeout')) {
      return 'La carga tardó demasiado. El servidor o la conexión pueden estar demorados.';
    }
    if (error.contains('connection_refused')) {
      return 'El servidor rechazó la conexión. Comprueba la dirección e inténtalo de nuevo.';
    }
    if (error.contains('ssl') || error.contains('cert')) {
      return 'No se pudo establecer una conexión segura. '
          'No introduzcas datos personales hasta verificar el sitio.';
    }
    return 'No se pudo completar la carga. Revisa la dirección o vuelve a intentarlo.';
  }
}
