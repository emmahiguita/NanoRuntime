/// UNI-01 — MessagingPackage: punto ÚNICO de verdad para los paquetes de apps
/// de mensajería conocidas. Antes de este sprint cada paquete vivía repetido
/// en dos lugares factuales (surface_profiles.dart y conversation_key.dart);
/// ahora ambos anclan aquí.
///
/// División de responsabilidades (sin duplicación de contratos):
/// - MessagingPackage ......... QUÉ paquetes se conocen (este archivo).
/// - channelForPackage ........ CÓMO paquete → canal lógico (conversation_key.dart,
///   única autoridad; es el ChannelAdapter de facto).
/// - ConversationIdentity ..... identidad lógica del mensaje (conversation_key.dart;
///   es la NotificationIdentity universal).
/// - ConversationSurfaceProfile + SurfaceProfileRegistry — perfil declarativo de
///   superficie conversacional (perception/surface_profiles.dart; es el
///   MessagingSurfaceProfile, y solo describe, jamás ejecuta gestos).
///
/// Este archivo no tiene lógica de ejecución ni de identidad: solo nombres.
library;

/// Paquetes de mensajería conocidos. Añadir una app nueva = añadir su
/// constante aquí Y su canal en [channelForPackage]; el registry de perfiles
/// de superficie la referencia desde aquí.
abstract final class MessagingPackage {
  static const String whatsapp = 'com.whatsapp';
  static const String whatsappBusiness = 'com.whatsapp.w4b';
  static const String telegram = 'com.telegram.messenger';
  static const String telegramOrg = 'org.telegram.messenger';

  /// Todos los paquetes de mensajería conocidos.
  static const Set<String> known = {
    whatsapp,
    whatsappBusiness,
    telegram,
    telegramOrg,
  };
}

/// true si el paquete pertenece a una app de mensajería conocida.
/// Comparación normalizada: los nombres de paquete publicados por Android
/// llegan a veces con mayúsculas o espacios.
bool isKnownMessagingPackage(String packageName) =>
    MessagingPackage.known.contains(packageName.trim().toLowerCase());
