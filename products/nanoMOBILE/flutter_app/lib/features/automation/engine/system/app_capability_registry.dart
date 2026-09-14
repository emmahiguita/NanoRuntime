/// AppCapabilityRegistry — registro formal de capacidades de aplicaciones.
///
/// Principio: "Añadir un package no es soportar una app".
/// Define el modelo de madurez de 6 niveles:
/// DISCOVERED → LAUNCHABLE → OBSERVABLE → INTERACTABLE → VERIFIABLE → AUTOMATABLE.
///
/// Desacoplado: no ejecuta Intents ni toques (SRP); define qué capacidades,
/// esquemas de URI/Intent y nivel de madurez existen para cada aplicación,
/// validando contra el catálogo factual de apps instaladas.
library;

import 'installed_app_catalog.dart';
import 'system_models.dart';

/// Niveles formales de madurez para la integración de una aplicación en Nano.
enum AppMaturityLevel {
  /// 1. App detectada en el dispositivo (PackageManager).
  discovered,

  /// 2. Dispone de Launch Intent o Deep Link verificable con resolveActivity.
  launchable,

  /// 3. El árbol de accesibilidad u OCR puede leer su estado sin bloqueos.
  observable,

  /// 4. Sus nodos admiten acciones de entrada verificadas (click, input, scroll).
  interactable,

  /// 5. Las transiciones post-acción se comprueban por eventos de ventana.
  verifiable,

  /// 6. Flujo multi-paso documentado, guiado y resiliente de extremo a extremo.
  automatable,
}

/// Tipos de capacidades estandarizadas que una app puede exponer.
enum AppCapabilityType {
  /// Apertura general de la app.
  launch,

  /// Búsqueda interna o parametrizada.
  search,

  /// Abrir recurso específico (URL, video, mapa).
  openContent,

  /// Redacción o envío directo de mensaje/correo.
  composeMessage,

  /// Navegación a destino o coordenadas.
  navigation,

  /// Deep Link específico verificado.
  deepLink,
}

/// Definición tipada de una capacidad soportada por una aplicación.
class AppCapability {
  final AppCapabilityType type;
  final String description;
  final String? intentAction;
  final String? uriTemplate;
  final Map<String, String> defaultExtras;
  final AppMaturityLevel maturity;

  const AppCapability({
    required this.type,
    required this.description,
    this.intentAction,
    this.uriTemplate,
    this.defaultExtras = const {},
    required this.maturity,
  });

  /// Construye la URI final sustituyendo variables de plantilla `{var}`.
  String? buildUri(Map<String, String> parameters) {
    if (uriTemplate == null) return null;
    var uri = uriTemplate!;
    parameters.forEach((key, value) {
      uri = uri.replaceAll('{$key}', Uri.encodeComponent(value));
    });
    return uri;
  }
}

/// Perfil de capacidades de una aplicación conocida o descubierta.
class AppProfile {
  final String packageName;
  final String displayName;
  final AppMaturityLevel overallMaturity;
  final List<AppCapability> capabilities;

  const AppProfile({
    required this.packageName,
    required this.displayName,
    required this.overallMaturity,
    required this.capabilities,
  });

  /// Comprueba si la app cuenta con una capacidad específica.
  bool hasCapability(AppCapabilityType type) =>
      capabilities.any((c) => c.type == type);

  /// Obtiene la primera capacidad del tipo solicitado.
  AppCapability? getCapability(AppCapabilityType type) {
    for (final c in capabilities) {
      if (c.type == type) return c;
    }
    return null;
  }
}

/// Registro central de capacidades de aplicaciones con resolución contra
/// [InstalledAppCatalog] y catálogos semánticos de Intents.
class AppCapabilityRegistry {
  AppCapabilityRegistry({InstalledAppCatalog? catalog})
      : _catalog = catalog;

  final InstalledAppCatalog? _catalog;

  /// Catálogo de perfiles estándar con capacidades y madurez comprobadas.
  static final Map<String, AppProfile> _standardProfiles = {
    // WhatsApp: soporte observable, interactable y flujos de mensajería
    'com.whatsapp': const AppProfile(
      packageName: 'com.whatsapp',
      displayName: 'WhatsApp',
      overallMaturity: AppMaturityLevel.automatable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Iniciar WhatsApp en pantalla principal',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.composeMessage,
          description: 'Enviar mensaje a contacto o número telefónico',
          intentAction: 'android.intent.action.VIEW',
          uriTemplate: 'https://api.whatsapp.com/send?phone={phone}&text={text}',
          maturity: AppMaturityLevel.automatable,
        ),
        AppCapability(
          type: AppCapabilityType.search,
          description: 'Buscar chat o contacto en lista',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),

    // Telegram
    'org.telegram.messenger': const AppProfile(
      packageName: 'org.telegram.messenger',
      displayName: 'Telegram',
      overallMaturity: AppMaturityLevel.interactable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Iniciar Telegram',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.openContent,
          description: 'Abrir canal o chat por username',
          intentAction: 'android.intent.action.VIEW',
          uriTemplate: 'tg://resolve?domain={username}',
          maturity: AppMaturityLevel.interactable,
        ),
        AppCapability(
          type: AppCapabilityType.composeMessage,
          description: 'Compartir texto en Telegram',
          intentAction: 'android.intent.action.SEND',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),

    // Google Chrome
    'com.android.chrome': const AppProfile(
      packageName: 'com.android.chrome',
      displayName: 'Chrome',
      overallMaturity: AppMaturityLevel.interactable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Abrir Google Chrome',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.openContent,
          description: 'Navegar a URL específica',
          intentAction: 'android.intent.action.VIEW',
          uriTemplate: '{url}',
          maturity: AppMaturityLevel.interactable,
        ),
        AppCapability(
          type: AppCapabilityType.search,
          description: 'Buscar en la web con Google',
          intentAction: 'android.intent.action.WEB_SEARCH',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),

    // Google Maps
    'com.google.android.apps.maps': const AppProfile(
      packageName: 'com.google.android.apps.maps',
      displayName: 'Google Maps',
      overallMaturity: AppMaturityLevel.interactable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Abrir Google Maps',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.navigation,
          description: 'Navegar hacia dirección o coordenadas',
          intentAction: 'android.intent.action.VIEW',
          uriTemplate: 'google.navigation:q={query}',
          maturity: AppMaturityLevel.interactable,
        ),
        AppCapability(
          type: AppCapabilityType.search,
          description: 'Buscar lugares cercanos',
          intentAction: 'android.intent.action.VIEW',
          uriTemplate: 'geo:0,0?q={query}',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),

    // YouTube
    'com.google.android.youtube': const AppProfile(
      packageName: 'com.google.android.youtube',
      displayName: 'YouTube',
      overallMaturity: AppMaturityLevel.interactable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Abrir YouTube',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.openContent,
          description: 'Reproducir video por ID',
          intentAction: 'android.intent.action.VIEW',
          uriTemplate: 'vnd.youtube:{id}',
          maturity: AppMaturityLevel.interactable,
        ),
        AppCapability(
          type: AppCapabilityType.search,
          description: 'Buscar videos en YouTube',
          intentAction: 'android.intent.action.SEARCH',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),

    // Gmail
    'com.google.android.gm': const AppProfile(
      packageName: 'com.google.android.gm',
      displayName: 'Gmail',
      overallMaturity: AppMaturityLevel.interactable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Abrir Gmail',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.composeMessage,
          description: 'Redactar nuevo correo electrónico',
          intentAction: 'android.intent.action.SENDTO',
          uriTemplate: 'mailto:{to}?subject={subject}&body={body}',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),

    // Teléfono / Marcador
    'com.google.android.dialer': const AppProfile(
      packageName: 'com.google.android.dialer',
      displayName: 'Teléfono',
      overallMaturity: AppMaturityLevel.interactable,
      capabilities: [
        AppCapability(
          type: AppCapabilityType.launch,
          description: 'Abrir teclado telefónico',
          maturity: AppMaturityLevel.launchable,
        ),
        AppCapability(
          type: AppCapabilityType.composeMessage,
          description: 'Marcar número telefónico',
          intentAction: 'android.intent.action.DIAL',
          uriTemplate: 'tel:{phone}',
          maturity: AppMaturityLevel.interactable,
        ),
      ],
    ),
  };

  /// Resuelve el perfil de capacidades para una aplicación por nombre o package.
  /// Si la app está en el catálogo factual del dispositivo, devuelve su perfil
  /// adaptado a su presencia real.
  Future<AppProfile?> resolveProfile(String query) async {
    final clean = query.trim().toLowerCase();

    // 1. Coincidencia directa por package en estándares
    if (_standardProfiles.containsKey(clean)) {
      return _standardProfiles[clean];
    }

    // 2. Coincidencia por nombre en estándares
    for (final profile in _standardProfiles.values) {
      if (profile.displayName.toLowerCase() == clean ||
          profile.packageName.toLowerCase() == clean) {
        return profile;
      }
    }

    // 3. Resolución contra InstalledAppCatalog si está disponible
    if (_catalog != null) {
      final match = await _catalog.findApp(clean);
      if (match is AppMatchResolved) {
        final app = match.app;
        return _buildDiscoveredProfile(app);
      }
    }

    return null;
  }

  /// Construye un perfil mínimo honesto (DISCOVERED / LAUNCHABLE) para
  /// cualquier app instalada no registrada en los estándares.
  AppProfile _buildDiscoveredProfile(InstalledApp app) {
    final maturity = app.launchable
        ? AppMaturityLevel.launchable
        : AppMaturityLevel.discovered;

    return AppProfile(
      packageName: app.packageName,
      displayName: app.label.isNotEmpty ? app.label : app.packageName,
      overallMaturity: maturity,
      capabilities: [
        if (app.launchable)
          AppCapability(
            type: AppCapabilityType.launch,
            description: 'Lanzar ${app.label}',
            maturity: AppMaturityLevel.launchable,
          ),
      ],
    );
  }

  /// Lista todos los perfiles estándar registrados.
  List<AppProfile> get standardProfiles =>
      List.unmodifiable(_standardProfiles.values);
}
