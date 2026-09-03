/// Perfiles declarativos para resolver superficies observadas.
///
/// Un perfil solo aporta vocabulario y restricciones estructurales. No observa,
/// no decide navegación, no ejecuta acciones y no concede autoridad.
library;

import 'semantic/semantic_role.dart';
import '../messaging/messaging_package.dart';

enum SurfaceElementKind {
  anyInput,
  messageInput,
  searchInput,
  sendAction,
  searchAction,
  navigationBackAction,
  navigationDismissAction,
  navigationOverflowAction,
  conversationHomeAction,
  confirmAction,
  messageAction,
  skipAdAction,
}

/// Regla declarativa de un elemento de superficie.
final class SurfaceElementProfile {
  const SurfaceElementProfile({
    this.roles = const {},
    this.terms = const [],
    this.allowClickableContainer = false,
  });

  final Set<SemanticRole> roles;
  final List<String> terms;

  /// Excepción estructural explícita para controles que una app representa
  /// como contenedores accionables en lugar de button/iconButton.
  final bool allowClickableContainer;
}

/// Contrato de conocimiento de superficie. Deliberadamente no contiene
/// callbacks ni herramientas de ejecución.
abstract interface class SurfaceProfile {
  String get id;

  bool matchesPackage(String packageName);

  SurfaceElementProfile? element(SurfaceElementKind kind);
}

/// Semántica universal evaluada siempre antes de cualquier especialización.
final class GenericSurfaceProfile implements SurfaceProfile {
  const GenericSurfaceProfile();

  @override
  String get id => 'generic';

  @override
  bool matchesPackage(String packageName) => true;

  @override
  SurfaceElementProfile? element(SurfaceElementKind kind) => switch (kind) {
    SurfaceElementKind.anyInput => const SurfaceElementProfile(
      roles: {SemanticRole.textField, SemanticRole.searchField},
    ),
    SurfaceElementKind.messageInput => const SurfaceElementProfile(
      roles: {SemanticRole.textField},
      terms: [
        'mensaje',
        'message',
        'escribe',
        'type',
        'compose',
        'escribe un mensaje',
        'type a message',
        'escribir mensaje',
        'write a message',
        'escribir',
        'reply',
        'responder',
        'escribe un mensaje aquí',
        'type your message',
      ],
    ),
    SurfaceElementKind.searchInput => const SurfaceElementProfile(
      roles: {SemanticRole.searchField},
      terms: [
        'buscar',
        'search',
        'busca',
        'consulta',
        'find',
        'url_bar',
        'address_bar',
        'location_bar',
        'omnibox',
        'buscar en',
        'search in',
        'búsqueda',
        'busqueda',
        'buscar chats',
        'search chats',
        'buscar personas',
        'find people',
        'buscar contactos',
        'search contacts',
        'filtrar',
        'filter',
        'search or type',
        'busca o escribe',
        'buscar en youtube',
        'search youtube',
        'search on youtube',
        'youtube search',
        'buscar videos',
        'search videos',
      ],
    ),
    SurfaceElementKind.sendAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
      terms: [
        'enviar',
        'send',
        'enviar mensaje',
        'send message',
        'enviar ahora',
        'send now',
        'send message',
      ],
    ),
    SurfaceElementKind.searchAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
      terms: [
        'buscar',
        'search',
        'busca',
        'busqueda',
        'búsqueda',
        'find',
        'buscar en',
        'search in',
        'search icon',
        'buscar en youtube',
        'search youtube',
        'search on youtube',
        'youtube search',
        'search videos',
        'buscar videos',
        'lupa',
        'magnifier',
        'magnifying glass',
        'lens',
      ],
    ),
    SurfaceElementKind.navigationBackAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
      terms: [
        'atrás',
        'atras',
        'volver',
        'navegar hacia arriba',
        'back',
        'navigate up',
        'up navigation',
        'regresar',
        'retroceder',
        'navigate back',
        'go back',
        'navigate up button',
        'flecha atrás',
        'flecha hacia atrás',
        'arrow back',
        'back arrow',
        'back button',
      ],
    ),
    SurfaceElementKind.navigationDismissAction => const SurfaceElementProfile(
      roles: {
        SemanticRole.button,
        SemanticRole.iconButton,
        SemanticRole.menuItem,
        SemanticRole.image,
      },
      terms: [
        'cerrar',
        'cancelar',
        'descartar',
        'close',
        'cancel',
        'dismiss',
        'quitar',
        'remove overlay',
      ],
    ),
    SurfaceElementKind.navigationOverflowAction => const SurfaceElementProfile(
      roles: {
        SemanticRole.button,
        SemanticRole.iconButton,
        SemanticRole.menuItem,
        SemanticRole.image,
      },
      terms: [
        'más opciones',
        'mas opciones',
        'more options',
        'menú',
        'menu',
        'opciones',
        'options',
        'ver más',
        'see more',
      ],
    ),
    SurfaceElementKind.conversationHomeAction => const SurfaceElementProfile(
      roles: {
        SemanticRole.tab,
        SemanticRole.button,
        SemanticRole.iconButton,
        SemanticRole.menuItem,
        SemanticRole.text,
        SemanticRole.image,
      },
      terms: [
        'chats',
        'mensajes',
        'conversaciones',
        'messages',
        'conversations',
        'chat',
        'conversación',
        'conversacion',
        'inbox',
        'bandeja de entrada',
        'lista de chats',
        'chat list',
        'mensajes directos',
        'direct messages',
        'dm',
      ],
    ),
    SurfaceElementKind.confirmAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
      terms: [
        'siguiente',
        'next',
        'continuar',
        'continue',
        'hecho',
        'done',
        'confirmar',
        'confirm',
        'listo',
        'ok',
        'aceptar',
        'accept',
        'aplicar',
        'apply',
        'adelante',
        'proceed',
        'avanzar',
        'finalizar',
        'finish',
      ],
    ),
    SurfaceElementKind.messageAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
      terms: [
        'mensaje',
        'message',
        'enviar mensaje',
        'send message',
        'chat',
        'text',
        'texto',
        'sms',
        'write message',
        'escribir mensaje',
        'iniciar chat',
        'start chat',
        'burbuja de chat',
        'chat bubble',
        'nuevo mensaje',
        'new message',
      ],
    ),
    SurfaceElementKind.skipAdAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
      terms: [
        'saltar anuncio',
        'skip ad',
        'omitir anuncio',
        'skip ads',
        'saltar',
        'skip',
        'anuncio',
        'ad',
        'advertisement',
        'youtube ads',
      ],
    ),
  };
}

/// Perfil declarativo de una familia de superficies conversacionales.
///
/// Sus reglas se evalúan únicamente cuando el perfil genérico no resolvió la
/// superficie; nunca lo reemplazan ni eligen acciones por sí mismas.
final class ConversationSurfaceProfile implements SurfaceProfile {
  const ConversationSurfaceProfile({
    required this.id,
    required this.packageNames,
    required this.elements,
  });

  @override
  final String id;
  final Set<String> packageNames;
  final Map<SurfaceElementKind, SurfaceElementProfile> elements;

  @override
  bool matchesPackage(String packageName) =>
      packageNames.contains(packageName.trim().toLowerCase());

  @override
  SurfaceElementProfile? element(SurfaceElementKind kind) => elements[kind];
}

/// Regla resuelta con la identidad del perfil que la declaró.
final class ResolvedSurfaceProfile {
  ResolvedSurfaceProfile({
    required this.sourceProfileId,
    required Iterable<SemanticRole> roles,
    required Iterable<String> terms,
    required this.allowClickableContainer,
  }) : roles = Set.unmodifiable(roles),
       terms = List.unmodifiable(terms);

  final String sourceProfileId;
  final Set<SemanticRole> roles;
  final List<String> terms;
  final bool allowClickableContainer;

  bool matchesRole(SemanticRole role) => roles.contains(role);

  bool matchesTerms(String normalizedEvidence) =>
      terms.any(normalizedEvidence.contains);

  bool matchesExactTerm(String normalizedEvidence) =>
      terms.contains(normalizedEvidence.trim().toLowerCase());
}

abstract interface class SurfaceProfileSource {
  List<ResolvedSurfaceProfile> resolve(
    String packageName,
    SurfaceElementKind kind,
  );
}

/// Catálogo mínimo de producción. Mantiene el orden GenericProfile → perfil
/// específico y combina únicamente datos declarativos.
final class SurfaceProfileRegistry implements SurfaceProfileSource {
  const SurfaceProfileRegistry();

  static const _generic = GenericSurfaceProfile();

  static const _applicationProfiles = <ConversationSurfaceProfile>[
    ConversationSurfaceProfile(
      id: 'whatsapp-conversation',
      packageNames: {
        MessagingPackage.whatsapp,
        MessagingPackage.whatsappBusiness,
      },
      elements: {
        SurfaceElementKind.messageInput: SurfaceElementProfile(
          roles: {SemanticRole.textField},
          terms: ['escribe un mensaje', 'type a message'],
        ),
        SurfaceElementKind.searchInput: SurfaceElementProfile(
          roles: {SemanticRole.searchField},
          terms: ['buscar', 'search'],
        ),
        SurfaceElementKind.sendAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
          terms: ['enviar mensaje', 'send message'],
        ),
        SurfaceElementKind.searchAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
          terms: ['buscar', 'search'],
          allowClickableContainer: true,
        ),
        SurfaceElementKind.navigationBackAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
          terms: ['atrás', 'atras', 'volver', 'navegar hacia arriba', 'back'],
        ),
        SurfaceElementKind.navigationDismissAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton, SemanticRole.image},
          terms: ['cerrar', 'cancelar', 'close', 'cancel'],
        ),
        SurfaceElementKind.navigationOverflowAction: SurfaceElementProfile(
          roles: {
            SemanticRole.button,
            SemanticRole.iconButton,
            SemanticRole.menuItem,
          },
          terms: ['más opciones', 'mas opciones', 'more options'],
        ),
        SurfaceElementKind.conversationHomeAction: SurfaceElementProfile(
          roles: {SemanticRole.tab, SemanticRole.button, SemanticRole.text},
          terms: ['chats'],
        ),
      },
    ),
  ];

  @override
  List<ResolvedSurfaceProfile> resolve(
    String packageName,
    SurfaceElementKind kind,
  ) {
    final matchingProfiles = <SurfaceProfile>[
      _generic,
      for (final profile in _applicationProfiles)
        if (profile.matchesPackage(packageName)) profile,
    ];
    return List.unmodifiable([
      for (final profile in matchingProfiles)
        if (profile.element(kind) case final element?)
          ResolvedSurfaceProfile(
            sourceProfileId: profile.id,
            roles: element.roles,
            terms: element.terms,
            allowClickableContainer: element.allowClickableContainer,
          ),
    ]);
  }
}
