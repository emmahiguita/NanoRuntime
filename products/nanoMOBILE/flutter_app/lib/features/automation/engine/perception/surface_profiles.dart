/// Perfiles declarativos para resolver superficies observadas.
///
/// Un perfil solo aporta vocabulario y restricciones estructurales. No observa,
/// no decide navegación, no ejecuta acciones y no concede autoridad.
library;

import 'semantic/semantic_role.dart';

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
      terms: ['mensaje', 'message', 'escribe', 'type', 'compose'],
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
      ],
    ),
    SurfaceElementKind.sendAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton},
      terms: ['enviar', 'send', 'enviar mensaje', 'send message'],
    ),
    SurfaceElementKind.searchAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton},
      terms: ['buscar', 'search', 'busca', 'busqueda', 'búsqueda', 'find'],
    ),
    SurfaceElementKind.navigationBackAction => const SurfaceElementProfile(
      roles: {SemanticRole.button, SemanticRole.iconButton},
      terms: [
        'atrás',
        'atras',
        'volver',
        'navegar hacia arriba',
        'back',
        'navigate up',
        'up navigation',
      ],
    ),
    SurfaceElementKind.navigationDismissAction => const SurfaceElementProfile(
      roles: {
        SemanticRole.button,
        SemanticRole.iconButton,
        SemanticRole.menuItem,
      },
      terms: ['cerrar', 'cancelar', 'descartar', 'close', 'cancel', 'dismiss'],
    ),
    SurfaceElementKind.navigationOverflowAction => const SurfaceElementProfile(
      roles: {
        SemanticRole.button,
        SemanticRole.iconButton,
        SemanticRole.menuItem,
      },
      terms: ['más opciones', 'mas opciones', 'more options', 'menú', 'menu'],
    ),
    SurfaceElementKind.conversationHomeAction => const SurfaceElementProfile(
      roles: {
        SemanticRole.tab,
        SemanticRole.button,
        SemanticRole.iconButton,
        SemanticRole.menuItem,
        SemanticRole.text,
      },
      terms: [
        'chats',
        'mensajes',
        'conversaciones',
        'messages',
        'conversations',
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
      packageNames: {'com.whatsapp'},
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
          roles: {SemanticRole.button, SemanticRole.iconButton},
          terms: ['enviar mensaje', 'send message'],
        ),
        SurfaceElementKind.searchAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton},
          terms: ['buscar', 'search'],
          allowClickableContainer: true,
        ),
        SurfaceElementKind.navigationBackAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton},
          terms: ['atrás', 'atras', 'volver', 'navegar hacia arriba', 'back'],
        ),
        SurfaceElementKind.navigationDismissAction: SurfaceElementProfile(
          roles: {SemanticRole.button, SemanticRole.iconButton},
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
